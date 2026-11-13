import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook_dialog.dart' show DialogTone;
import '../../../../core/widgets/skeleton.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';

/// The Split bill side of a receipt: people by name, each printed line's portions, the charges shared evenly, and the
/// server's exact shares with a paid tick each and the platform share sheet. Person 0 is "Me" (the calorie ticks follow
/// their lines); the server computes every amount, this only sends the state.
class SplitBill extends StatefulWidget {
  const SplitBill({
    super.key,
    required this.receipt,
    required this.share,
    required this.onStop,
  });

  final Receipt receipt;

  /// The platform share sheet ([origin] anchors the iPad popover).
  final Future<void> Function(String text, Rect? origin) share;

  /// Called after the split is deleted; the page goes back to Receipt.
  final VoidCallback onStop;

  @override
  State<SplitBill> createState() => _SplitBillState();
}

class _SplitBillState extends State<SplitBill> {
  late final _repo = context.read<ReceiptsRepository>();
  ReceiptSplit? _split;
  Object? _error;
  bool _started = false;
  bool _saving = false;
  bool _again = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final l = AppLocalizations.of(context);
    try {
      var split = await _repo.split(widget.receipt.id);
      // First time here: a draft with just Me (who pays it all), saved only on the first real change, so a look
      // at this side never touches the receipt's calorie ticks.
      if (!split.exists) {
        final r = widget.receipt;
        split = ReceiptSplit(
          people: [(name: l.splitMe, paid: false)],
          portions: const [],
          shares: [
            (
              person: 0,
              amountSen: r.totalSen ?? 0,
              lines: {
                for (final i in r.items)
                  if ((i.amountSen ?? 0) >= 0) i.name,
              }.toList(),
            ),
          ],
          totalSen: r.totalSen,
        );
      }
      if (mounted) {
        setState(() {
          _split = split;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Shows the change at once, then sends the whole state; a change during a save runs once more after it.
  Future<void> _save(
    List<SplitPerson> people,
    List<SplitPortion> portions,
  ) async {
    final split = _split;
    if (split == null) return;
    setState(() {
      _split = ReceiptSplit(
        people: people,
        portions: portions,
        shares: split.shares,
        totalSen: split.totalSen,
      );
    });
    if (_saving) {
      _again = true;
      return;
    }
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      do {
        _again = false;
        final current = _split!;
        final saved = await _repo.saveSplit(
          widget.receipt.id,
          people: current.people,
          portions: current.portions,
        );
        if (mounted) {
          setState(() {
            // A newer edit is waiting: keep it on screen (only its shares are stale until the next pass).
            _split = _again
                ? ReceiptSplit(
                    people: _split!.people,
                    portions: _split!.portions,
                    shares: saved.shares,
                    totalSen: saved.totalSen,
                  )
                : saved;
            _error = null;
          });
        }
      } while (_again && mounted);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(l, e))));
        await _load();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPerson() async {
    final l = AppLocalizations.of(context);
    final split = _split;
    if (split == null) return;
    final field = TextEditingController();
    final ok = await showBaseDialog(
      context,
      title: l.splitAddPerson,
      message: l.splitAddPersonBody,
      confirmLabel: l.save,
      content: TextField(
        key: const ValueKey('split-name'),
        controller: field,
        autofocus: true,
        maxLength: 40, // the server's limit
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l.splitPersonName),
      ),
    );
    final name = field.text.trim();
    if (!ok || !mounted || name.isEmpty) return;
    final people = [...split.people, (name: name, paid: false)];
    final names = people.map((p) => p.name.toLowerCase()).toSet();
    if (names.length != people.length) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.splitNameTaken)));
      return;
    }
    await _save(people, split.portions);
  }

  Future<void> _removePerson(int index) async {
    final l = AppLocalizations.of(context);
    final split = _split;
    if (split == null) return;
    final yes = await showBaseDialog(
      context,
      title: l.splitRemovePerson(split.people[index].name),
      message: l.splitRemovePersonBody,
      tone: DialogTone.danger,
      confirmLabel: l.splitRemove,
    );
    if (!yes || !mounted) return;
    final people = [
      for (var i = 0; i < split.people.length; i++)
        if (i != index) split.people[i],
    ];
    // A removed person's portions go; the later people move up one place.
    final portions = [
      for (final p in split.portions)
        if (p.person != index)
          (
            position: p.position,
            person: p.person > index ? p.person - 1 : p.person,
            quantity: p.quantity,
          ),
    ];
    await _save(people, portions);
  }

  Future<void> _paid(int index, bool paid) async {
    final split = _split;
    if (split == null) return;
    final people = [...split.people];
    people[index] = (name: people[index].name, paid: paid);
    await _save(people, split.portions);
  }

  Future<void> _assign(int position) async {
    final split = _split;
    if (split == null) return;
    final item = widget.receipt.items[position];
    final cap = item.quantity != null && item.quantity! > 0
        ? item.quantity!
        : 1.0;
    final current = {
      for (final p in split.portions)
        if (p.position == position) p.person: p.quantity,
    };
    final picked = await showModalBottomSheet<Map<int, double>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PortionSheet(
        item: item,
        people: split.people,
        current: current,
        cap: cap,
      ),
    );
    if (picked == null || !mounted) return;
    final portions = [
      for (final p in split.portions)
        if (p.position != position) p,
      for (final e in picked.entries)
        if (e.value > 0) (position: position, person: e.key, quantity: e.value),
    ];
    await _save(split.people, portions);
  }

  Future<void> _stop() async {
    final l = AppLocalizations.of(context);
    final yes = await showBaseDialog(
      context,
      title: l.splitStop,
      message: l.splitStopBody,
      tone: DialogTone.danger,
      confirmLabel: l.splitStop,
    );
    if (!yes || !mounted) return;
    try {
      await _repo.clearSplit(widget.receipt.id);
      if (mounted) widget.onStop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(l, e))));
      }
    }
  }

  SplitShare? _shareOf(int person) {
    for (final s in _split!.shares) {
      if (s.person == person) return s;
    }
    return null;
  }

  String _shareText() {
    final split = _split!;
    final rows = <String>[];
    for (var i = 0; i < split.people.length; i++) {
      final share = _shareOf(i);
      final amount = rm(share?.amountSen ?? 0);
      final lines = share?.lines ?? const <String>[];
      rows.add(
        lines.isEmpty
            ? '${split.people[i].name} $amount'
            : '${split.people[i].name} $amount: ${lines.join(', ')}',
      );
    }
    return rows.join('\n');
  }

  Future<void> _share(BuildContext button) async {
    final box = button.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await widget.share(_shareText(), origin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText(AppLocalizations.of(context), e))),
        );
      }
    }
  }

  /// Who has a line, one label each ("Ali", or "Ali ×2" on a line of several); nobody = empty (shared by everyone).
  List<String> _takers(int position) {
    final split = _split!;
    final several = (widget.receipt.items[position].quantity ?? 1) > 1;
    return [
      for (final p in split.portions)
        if (p.position == position)
          several
              ? '${split.people[p.person].name} ×${_qtyText(p.quantity)}'
              : split.people[p.person].name,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final split = _split;
    if (split == null) {
      if (_error == null) {
        return const SingleChildScrollView(child: SkeletonRows(rows: 4));
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 24, spaceM, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorText(l, _error!),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(l.tryAgain)),
            ],
          ),
        ),
      );
    }
    final figures = text.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // Only Me: nothing to choose yet, so the lines are not buttons and nobody is asked to pay.
    final alone = split.people.length < 2;
    final paid = split.people.where((p) => p.paid).length;
    // Tax, service, rounding and discounts: what the server shares evenly (never the subtotal).
    final chargesSen = widget.receipt.charges
        .where((c) => c.kind != 'subtotal')
        .fold(0, (sum, c) => sum + c.amountSen);
    // Who still owes comes first; the paid ones sink to the bottom (each group in the order they were added).
    final order = [
      for (final (i, p) in split.people.indexed)
        if (!p.paid) i,
      for (final (i, p) in split.people.indexed)
        if (p.paid) i,
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionHeader(l.splitPeople),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: spaceM),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (i, person) in split.people.indexed)
                InputChip(
                  key: ValueKey('split-person-$i'),
                  avatar: Icon(Icons.person, size: 18, color: nb.pandan),
                  label: Text(person.name),
                  deleteButtonTooltipMessage: l.splitRemove,
                  onDeleted: i == 0 ? null : () => _removePerson(i),
                ),
              if (split.people.length < 10)
                ActionChip(
                  key: const ValueKey('split-add-person'),
                  avatar: Icon(Icons.add, size: 18, color: nb.pandanDeep),
                  label: Text(l.splitAddPerson),
                  onPressed: _addPerson,
                ),
            ],
          ),
        ),
        InfoCard(
          icon: Icons.touch_app_outlined,
          text: alone ? l.splitHintStart : l.splitHintAssign,
        ),
        SectionHeader(l.receiptItems),
        if (widget.receipt.items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceM, 0),
            child: Text(
              l.splitNoItems,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          )
        else
          // In the receipt's printed order, so the two tabs read the same.
          for (final (position, item) in widget.receipt.items.indexed)
            BaseTile(
              key: ValueKey('split-line-$position'),
              dense: true,
              leading: _Badge(
                item.quantity == null ? null : '${_qtyText(item.quantity!)}×',
              ),
              title: item.name,
              tags: alone
                  ? const []
                  : [
                      for (final name in _takers(position))
                        TileTag(name, tone: TagTone.good),
                      if (_takers(position).isEmpty) TileTag(l.splitEveryone),
                    ],
              onTap: alone ? null : () => _assign(position),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.amountSen != null)
                    Text(rm(item.amountSen!), style: figures),
                  if (!alone)
                    Icon(Icons.chevron_right, size: 20, color: nb.inkSoft),
                ],
              ),
            ),
        if (chargesSen != 0)
          BaseTile(
            key: const ValueKey('split-charges'),
            dense: true,
            style: TileStyle.filled,
            leading: const _Badge(null, icon: Icons.call_split),
            title: l.splitChargesTitle,
            subtitle: l.splitChargesEven,
            trailing: Text(rm(chargesSen), style: figures),
          ),
        SectionHeader(l.splitShares),
        for (final i in order)
          _ShareTile(
            key: ValueKey('split-share-$i'),
            person: split.people[i],
            share: _shareOf(i),
            onPaid: alone ? null : (paid) => _paid(i, paid),
          ),
        if (split.totalSen != null)
          BaseTile(
            key: const ValueKey('split-total'),
            dense: true,
            style: TileStyle.filled,
            leading: const _Badge(null, icon: Icons.receipt_long_outlined),
            title: l.splitTotal,
            subtitle: alone
                ? null
                : l.splitPaidCount(paid, split.people.length),
            trailing: Text(
              rm(split.totalSen!),
              style: figures?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        if (!alone)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 16, spaceM, 0),
            child: Builder(
              builder: (button) => FilledButton.icon(
                key: const ValueKey('split-share-button'),
                onPressed: _saving ? null : () => _share(button),
                icon: const Icon(Icons.ios_share),
                label: Text(l.splitShare),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceM, 0),
          child: TextButton(
            key: const ValueKey('split-stop'),
            style: TextButton.styleFrom(foregroundColor: nb.margin),
            onPressed: _saving ? null : _stop,
            child: Text(l.splitStop),
          ),
        ),
      ],
    );
  }
}

/// A tile's round lead: a short text ("2×", a person's initial) or an icon.
class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.icon = Icons.restaurant});

  final String? text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return CircleAvatar(
      radius: 18,
      backgroundColor: nb.pandanDeep.withValues(alpha: 0.12),
      child: text == null
          ? Icon(icon, size: 18, color: nb.pandanDeep)
          : Text(
              text!,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: nb.pandanDeep, fontWeight: FontWeight.w700),
            ),
    );
  }
}

/// One person's share: their initial, name, what they had, the amount and a Paid tick (the whole tile toggles it).
class _ShareTile extends StatelessWidget {
  const _ShareTile({
    super.key,
    required this.person,
    required this.share,
    required this.onPaid,
  });

  final SplitPerson person;
  final SplitShare? share;

  /// null = no paid tick (only Me on the bill).
  final ValueChanged<bool>? onPaid;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final done = onPaid != null && person.paid;
    return BaseTile(
      dense: true,
      muted: done,
      leading: _Badge(person.name.characters.first.toUpperCase()),
      title: person.name,
      subtitle: share?.lines.join(', '),
      tags: [if (done) TileTag(l.splitPaid, tone: TagTone.good)],
      onTap: onPaid == null ? null : () => onPaid!(!person.paid),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rm(share?.amountSen ?? 0),
            style: text.titleSmall?.copyWith(
              color: done ? nb.inkSoft : null,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (onPaid != null)
            Tooltip(
              message: l.splitPaid,
              child: Checkbox(
                value: person.paid,
                onChanged: (paid) => onPaid!(paid ?? false),
              ),
            ),
        ],
      ),
    );
  }
}

/// The portions sheet: a checkbox per person for one serving (several = shared evenly), or − / + counts for a line of
/// several. What nobody takes is shared by everyone (the server's math).
class _PortionSheet extends StatefulWidget {
  const _PortionSheet({
    required this.item,
    required this.people,
    required this.current,
    required this.cap,
  });

  final ReceiptItem item;
  final List<SplitPerson> people;
  final Map<int, double> current;
  final double cap;

  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  late final Map<int, double> _qty = {
    for (var i = 0; i < widget.people.length; i++) i: widget.current[i] ?? 0,
  };

  double get _total => _qty.values.fold(0, (a, b) => a + b);
  bool get _oneServing => widget.cap <= 1;

  void _toggle(int index, bool on) {
    setState(() {
      final picked = [
        for (var i = 0; i < widget.people.length; i++)
          if (i == index ? on : (_qty[i] ?? 0) > 0) i,
      ];
      final each = picked.isEmpty ? 0.0 : widget.cap / picked.length;
      for (var i = 0; i < widget.people.length; i++) {
        _qty[i] = picked.contains(i) ? each : 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final left = _total < widget.cap - 1e-9;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        ListTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.splitPortions,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                widget.item.quantity == null
                    ? widget.item.name
                    : '${_qtyText(widget.item.quantity!)} × ${widget.item.name}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _oneServing ? l.splitPortionsHint : l.splitPortionsCount,
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ],
          ),
        ),
        for (final (i, person) in widget.people.indexed)
          ListTile(
            key: ValueKey('portion-$i'),
            onTap: _oneServing ? () => _toggle(i, (_qty[i] ?? 0) <= 0) : null,
            leading: _oneServing
                ? Checkbox(
                    value: (_qty[i] ?? 0) > 0,
                    onChanged: (on) => _toggle(i, on ?? false),
                  )
                : null,
            trailing: _oneServing
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        tooltip: '−',
                        icon: const Icon(Icons.remove),
                        onPressed: (_qty[i] ?? 0) > 0
                            ? () => setState(() {
                                _qty[i] = math.max(0, (_qty[i] ?? 0) - 1);
                              })
                            : null,
                      ),
                      Text(_qtyText(_qty[i] ?? 0)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        tooltip: '+',
                        icon: const Icon(Icons.add),
                        onPressed: _total + 1 <= widget.cap + 1e-9
                            ? () => setState(() {
                                _qty[i] = (_qty[i] ?? 0) + 1;
                              })
                            : null,
                      ),
                    ],
                  ),
            title: Text(person.name),
          ),
        if (left)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 4, spaceM, 0),
            child: Text(
              l.splitShared,
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 12, spaceM, 0),
          child: FilledButton(
            key: const ValueKey('portion-done'),
            onPressed: () => Navigator.pop(context, {
              for (var i = 0; i < widget.people.length; i++)
                if ((_qty[i] ?? 0) > 0) i: _qty[i]!,
            }),
            child: Text(l.save),
          ),
        ),
      ],
    );
  }
}

/// 2, 0.5, 1.25: a whole number without a decimal point; otherwise up to two places.
String _qtyText(double q) {
  if (q == q.roundToDouble()) return q.toInt().toString();
  final fixed = q.toStringAsFixed(2);
  return fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed;
}
