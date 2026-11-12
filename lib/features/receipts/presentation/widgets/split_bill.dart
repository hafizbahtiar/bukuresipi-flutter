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

  String _assignment(int position) {
    final split = _split!;
    final parts = [
      for (final p in split.portions)
        if (p.position == position)
          '${split.people[p.person].name} ${_qtyText(p.quantity)}',
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    if (split.people.length == 1) {
      final cap = widget.receipt.items[position].quantity ?? 1;
      return '${split.people.first.name} ${_qtyText(cap > 0 ? cap : 1)}';
    }
    return AppLocalizations.of(context).splitShared;
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListTile(
          minTileHeight: 56,
          leading: Icon(Icons.people_outline, color: nb.pandan),
          title: Text(
            l.splitPeople,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final (i, person) in split.people.indexed)
          ListTile(
            key: ValueKey('split-person-$i'),
            leading: i == 0
                ? Icon(Icons.person_outline, size: 20, color: nb.inkSoft)
                : null,
            trailing: i == 0
                ? null
                : IconButton(
                    tooltip: l.splitRemove,
                    icon: Icon(Icons.close, size: 20, color: nb.inkSoft),
                    onPressed: () => _removePerson(i),
                  ),
            title: Text(person.name),
          ),
        if (split.people.length < 10)
          ListTile(
            key: const ValueKey('split-add-person'),
            leading: Icon(Icons.add, size: 20, color: nb.pandanDeep),
            onTap: _addPerson,
            title: Text(
              l.splitAddPerson,
              style: text.bodyMedium?.copyWith(
                color: nb.pandanDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ListTile(
          minTileHeight: 56,
          leading: Icon(
            Icons.receipt_long_outlined,
            size: 20,
            color: nb.pandan,
          ),
          title: Text(
            l.receiptItems,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (widget.receipt.items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceM, 0),
            child: Text(
              l.splitNoItems,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          )
        else
          for (final (position, item) in widget.receipt.items.indexed)
            ListTile(
              key: ValueKey('split-line-$position'),
              onTap: () => _assign(position),
              trailing: item.amountSen == null
                  ? null
                  : Text(rm(item.amountSen!), style: figures),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.quantity == null
                        ? item.name
                        : '${_qtyText(item.quantity!)} × ${item.name}',
                    style: text.bodyMedium,
                  ),
                  Text(
                    _assignment(position),
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                ],
              ),
            ),
        if (widget.receipt.charges.any(
          (c) => c.kind != 'subtotal' && c.amountSen != 0,
        ))
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 10, spaceM, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.call_split, size: 16, color: nb.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.splitChargesEven,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 20, spaceM, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.splitShares,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (split.totalSen != null)
                Text(
                  rm(split.totalSen!),
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        for (final (i, person) in split.people.indexed)
          _ShareRow(
            key: ValueKey('split-share-$i'),
            person: person,
            share: _shareOf(i),
            onPaid: (paid) => _paid(i, paid),
          ),
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

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    super.key,
    required this.person,
    required this.share,
    required this.onPaid,
  });

  final SplitPerson person;
  final SplitShare? share;
  final ValueChanged<bool> onPaid;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return ListTile(
      trailing: Tooltip(
        message: l.splitPaid,
        child: Checkbox(
          value: person.paid,
          onChanged: (paid) => onPaid(paid ?? false),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(person.name, style: text.titleSmall)),
              Text(
                rm(share?.amountSen ?? 0),
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (share != null && share!.lines.isNotEmpty)
            Text(
              share!.lines.join(', '),
              style: text.bodySmall?.copyWith(color: nb.inkSoft),
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
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ],
          ),
        ),
        for (final (i, person) in widget.people.indexed)
          ListTile(
            key: ValueKey('portion-$i'),
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
