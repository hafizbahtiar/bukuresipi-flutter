import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/places_controller.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';

/// One receipt: waits while the server reads it, then the user checks the place, time and total and saves.
/// Saved = the place is in their book; "Rate your visit" opens its page (the star rating lives there).
class ReceiptPage extends StatefulWidget {
  const ReceiptPage({
    super.key,
    required this.id,
    this.poll = const Duration(seconds: 3),
  });

  final String id;
  final Duration poll;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  late final _repo = context.read<ReceiptsRepository>();
  Receipt? _r;
  Object? _error;
  Timer? _timer;
  final _total = TextEditingController();
  DateTime? _at;
  String? _branchId; // a place picked by the user, when the read found none
  String? _branchName;
  bool _saving = false;
  Future<Uint8List?>? _photo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _total.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _repo.get(widget.id);
      if (!mounted) return;
      setState(() {
        _r = r;
        _error = null;
        if (r.inReview && _at == null) {
          _at = r.visitedAt ?? DateTime.now();
          if (r.totalSen case final sen?) _total.text = rm(sen).substring(3);
          if (r.hasImage) {
            _photo = _repo.image(r.id).catchError((Object _) => null);
          }
        }
      });
      if (r.reading) _timer = Timer(widget.poll, _load);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pickPlace() async {
    final l = AppLocalizations.of(context);
    final places = context
        .read<PlacesController>()
        .places
        .where((p) => p.mine && p.savedBranch != null)
        .toList();
    final picked = await showModalBottomSheet<({String id, String name})>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                l.receiptChoosePlace,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final p in places)
              ListTile(
                title: Text(p.restaurant.name),
                subtitle: p.savedBranch!.label == null
                    ? null
                    : Text(p.savedBranch!.label!),
                onTap: () => Navigator.pop(context, (
                  id: p.savedBranch!.id,
                  name: p.restaurant.name,
                )),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _branchId = picked.id;
      _branchName = picked.name;
    });
  }

  Future<void> _pickTime() async {
    final at = _at ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: at,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(at),
    );
    if (time == null) return;
    setState(
      () =>
          _at = DateTime(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final places = context.read<PlacesController>();
    setState(() => _saving = true);
    try {
      final r = await _repo.confirm(
        widget.id,
        totalSen: senOf(_total.text)!,
        visitedAt: _at!,
        branchId: _branchId,
      );
      unawaited(places.load()); // the place is in the book now
      if (mounted) setState(() => _r = r);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await _repo.remove(widget.id);
      messenger.showSnackBar(SnackBar(content: Text(l.receiptDeleted)));
      router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  /// The place's page in the book (rating, reviews); null when it is not loaded yet.
  String? _placePath(PlacesController places) {
    final id = _r?.place?.restaurantId;
    return places.places.where((p) => p.restaurant.id == id).firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = _r;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.addReceipt),
        actions: [
          if (r != null && !r.saved)
            IconButton(
              tooltip: l.receiptDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: NotebookPage(
        child: switch (r) {
          _ when _error != null => _Message(
            text: errorText(l, _error!),
            action: (l.tryAgain, _load),
          ),
          null => const Center(child: CircularProgressIndicator.adaptive()),
          Receipt(reading: true) => _Message(
            text: l.receiptReading,
            detail: l.receiptReadingHelp,
            busy: true,
          ),
          Receipt(failed: true) => _Message(text: l.receiptFailed),
          Receipt(saved: true) => _saved(context, r),
          _ => _review(context, r),
        },
      ),
    );
  }

  Widget _saved(BuildContext context, Receipt r) {
    final l = AppLocalizations.of(context);
    final path = _placePath(context.watch<PlacesController>());
    final summary = _Message(
      icon: Icons.check_circle_outline,
      text: [
        r.place?.name,
        if (r.totalSen != null) rm(r.totalSen!),
      ].nonNulls.join(' · '),
      detail: l.receiptSaved,
      action: path == null
          ? null
          : (l.receiptRate, () => context.push('/places/$path')),
    );
    if (r.items.isEmpty) return summary;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        summary,
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 0),
          child: _Items(items: r.items),
        ),
      ],
    );
  }

  Widget _review(BuildContext context, Receipt r) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    final sen = senOf(_total.text);
    final placeName = _branchName ?? r.place?.name;
    Widget check(String gap) => r.gaps.contains(gap)
        ? Text(
            l.receiptCheckThis,
            key: ValueKey('check-$gap'),
            style: text.labelMedium?.copyWith(
              color: nb.kunyit,
              fontWeight: FontWeight.w700,
            ),
          )
        : const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 8, 20, 24),
      children: [
        Text(
          l.receiptCheckHelp,
          style: text.bodyMedium?.copyWith(color: nb.inkSoft),
        ),
        const SizedBox(height: 12),
        FutureBuilder(
          future: _photo,
          builder: (context, s) => s.data == null
              ? const SizedBox.shrink()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: InteractiveViewer(
                      child: Image.memory(s.data!, fit: BoxFit.contain),
                    ),
                  ),
                ),
        ),
        if (r.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Items(items: r.items),
        ],
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.receiptPlace),
          subtitle: Text(placeName ?? l.receiptChoosePlace),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [check('shop'), const Icon(Icons.chevron_right)],
          ),
          onTap: _pickPlace,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.receiptDate),
          subtitle: Text(
            _at == null
                ? ''
                : '${loc.formatMediumDate(_at!)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(_at!))}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [check('date'), const Icon(Icons.edit_calendar_outlined)],
          ),
          onTap: _pickTime,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('receipt-total'),
          controller: _total,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l.receiptTotal,
            errorText: _total.text.isNotEmpty && sen == null
                ? l.receiptTotalInvalid
                : null,
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8, top: 14),
              child: check(
                r.gaps.contains('totals_mismatch')
                    ? 'totals_mismatch'
                    : 'total',
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed:
              _saving ||
                  sen == null ||
                  sen <= 0 ||
                  _at == null ||
                  placeName == null
              ? null
              : _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.detail,
    this.busy = false,
    this.icon,
    this.action,
  });

  final String text;
  final String? detail;
  final bool busy;
  final IconData? icon;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final style = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const CircularProgressIndicator.adaptive()
            else if (icon != null)
              Icon(icon, size: 48, color: nb.pandan),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: style.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: style.bodyMedium?.copyWith(color: nb.inkSoft),
              ),
            ],
            if (action case (final label, final onTap)) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onTap, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The printed lines: "2 × Nasi Lemak Ayam ... RM 25.80". As read: the user checks only the total.
class _Items extends StatelessWidget {
  const _Items({required this.items});

  final List<ReceiptItem> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    String qty(double q) =>
        q == q.roundToDouble() ? q.toInt().toString() : q.toString();
    return Column(
      key: const ValueKey('receipt-items'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.receiptItems,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    i.quantity == null ? '' : '${qty(i.quantity!)} ×',
                    style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                  ),
                ),
                Expanded(child: Text(i.name, style: text.bodyMedium)),
                if (i.amountSen != null)
                  Text(
                    rm(i.amountSen!),
                    style: text.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
