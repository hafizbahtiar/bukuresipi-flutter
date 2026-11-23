import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/open_link.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/ai_button.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/photo_sheet.dart';
import '../../../../core/widgets/pill_switch.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../places/presentation/places_controller.dart';
import '../../domain/einvoice_details.dart';
import '../../domain/einvoice_link.dart';
import '../../domain/receipt.dart';
import '../../domain/receipts_repository.dart';
import '../widgets/split_bill.dart';

/// One receipt: waits while the server reads it, then the user checks the place, time and total and saves.
/// Saved = the place is in their book; "Rate your visit" opens its page (the star rating lives there).
/// A read receipt also has Receipt | Split bill.
class ReceiptPage extends StatefulWidget {
  const ReceiptPage({
    super.key,
    required this.id,
    this.poll = const Duration(seconds: 3),
    this.share,
  });

  final String id;
  final Duration poll;

  /// The platform share sheet for the split bill's text; tests pass a fake.
  final Future<void> Function(String text, Rect? origin)? share;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> with WidgetsBindingObserver {
  late final _repo = context.read<ReceiptsRepository>();
  Receipt? _r;
  Object? _error;
  Timer? _timer;
  int _polls = 0;
  final _total = TextEditingController();
  DateTime? _at;
  String? _branchId; // a place picked by the user, when the read found none
  String? _branchName;
  bool _saving = false;
  bool _split = false;
  // Receipt | Split bill as pages: swiped, or driven by the pill above them.
  final _pages = PageController();
  Future<Uint8List?>? _photo;

  // The user's e-invoice details (this phone only), offered as copy buttons; null = none saved or no account.
  EinvoiceDetails? _details;
  // Back from the shop's e-invoice page: ask once whether it was requested.
  bool _askOnReturn = false;
  bool _scanning = false; // a double tap opens one scanner

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final store = context.read<EinvoiceDetailsStore?>();
    final userId = context.read<AuthController?>()?.user?.id;
    if (store == null || userId == null) return;
    final d = await store.load(userId);
    if (mounted) setState(() => _details = d.isEmpty ? null : d);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_askOnReturn) return;
    _askOnReturn = false;
    if (_r?.einvoice case final e? when !e.done) _askDone();
  }

  Future<void> _askDone() async {
    final l = AppLocalizations.of(context);
    final yes = await showBaseDialog(
      context,
      message: l.einvoiceAskDone,
      confirmLabel: l.einvoiceAskYes,
      cancelLabel: l.einvoiceUndo,
    );
    if (yes && mounted) await _einvoiceDone(true);
  }

  Future<void> _openEinvoice(String url) async {
    final l = AppLocalizations.of(context);
    final host = linkHost(url);
    final risk = switch (linkRisk(url)) {
      LinkRisk.none => null,
      LinkRisk.notSecure => l.einvoiceRiskHttp(host),
      LinkRisk.shortLink => l.einvoiceRiskShort(host),
      LinkRisk.oddName => l.einvoiceRiskName(host),
    };
    if (risk != null) {
      final go = await showBaseDialog(
        context,
        title: l.einvoiceRiskTitle,
        message: risk,
        tone: DialogTone.danger,
        confirmLabel: l.einvoiceRiskOpen,
      );
      if (!go || !mounted) return;
    }
    _askOnReturn = true;
    await openLink(context, url, failed: l.openFailed);
  }

  Future<void> _editDetails() async {
    await context.push('/account/einvoice');
    await _loadDetails();
  }

  /// The photo's QR was not read: Google's live scanner; a phone without it takes a close-up photo of the QR.
  Future<void> _scanEinvoice() async {
    if (_scanning) return;
    _scanning = true;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (await _repo.scanEinvoice(widget.id)) {
        case EinvoiceScan.saved:
          break;
        case EinvoiceScan.closed:
          return;
        case EinvoiceScan.notALink:
          messenger.showSnackBar(SnackBar(content: Text(l.einvoiceNotLink)));
          return;
        case EinvoiceScan.unavailable:
          final picked = await ImagePicker().pickImage(
            source: ImageSource.camera,
          );
          if (picked == null) return;
          if (!await _repo.addEinvoiceFromPhoto(widget.id, picked.path)) {
            messenger.showSnackBar(SnackBar(content: Text(l.einvoiceNoQr)));
            return;
          }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      return;
    } finally {
      _scanning = false;
    }
    _timer?.cancel();
    await _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _total.dispose();
    _pages.dispose();
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
        }
        // Fetched once: the scan while reading, then the preview while checking.
        if (r.hasImage && (r.reading || r.inReview)) {
          _photo ??= _repo.image(r.id).catchError((Object _) => null);
        }
      });
      _timer?.cancel(); // one poll at a time (a segment switch also reloads)
      // [poll] for the first minute (a read takes seconds), then 5x slower: calories can wait on the cron for long.
      if (r.reading || r.caloriesPending) {
        _timer = Timer(_polls++ < 20 ? widget.poll : widget.poll * 5, _load);
      }
    } catch (e) {
      if (!mounted) return;
      // A moment offline while it is being read: what's on screen stays, the next poll tries again.
      final blip =
          e is ApiException &&
          (e.code == ApiException.network || (e.status ?? 0) >= 500);
      if (blip && (_r?.reading == true || _r?.caloriesPending == true)) {
        _timer?.cancel();
        _timer = Timer(_polls++ < 20 ? widget.poll : widget.poll * 5, _load);
        return;
      }
      setState(() => _error = e);
    }
  }

  /// "I've requested it" (or not yet): the server stops (or keeps) the day-before reminder.
  Future<void> _einvoiceDone(bool done) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      await _repo.setEinvoiceDone(widget.id, done);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
    _timer?.cancel();
    await _load();
  }

  /// Ticks line [i] as eaten [n] times: shown at once, then the server's totals.
  Future<void> _eat(int i, double n) async {
    final r = _r!;
    final items = [...r.items];
    final it = items[i];
    items[i] = (
      name: it.name,
      quantity: it.quantity,
      amountSen: it.amountSen,
      kcal: it.kcal,
      kcalSource: it.kcalSource,
      eaten: n,
    );
    setState(
      () => _r = Receipt(
        id: r.id,
        status: r.status,
        shop: r.shop,
        place: r.place,
        visitedAt: r.visitedAt,
        totalSen: r.totalSen,
        gaps: r.gaps,
        items: items,
        charges: r.charges,
        hasImage: r.hasImage,
        reason: r.reason,
        eatenKcal: r.eatenKcal,
        hasEstimate: r.hasEstimate,
        unknownEaten: r.unknownEaten,
        caloriesPending: r.caloriesPending,
        hasSplit: r.hasSplit,
        einvoice: r.einvoice,
        einvoiceBy: r.einvoiceBy,
      ),
    );
    try {
      await _repo.setEaten(r.id, i, n);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText(AppLocalizations.of(context), e))),
        );
      }
    }
    _timer?.cancel();
    await _load();
  }

  Future<void> _pickPlace() async {
    final l = AppLocalizations.of(context);
    final places = context
        .read<PlacesController>()
        .places
        .where((p) => p.mine && p.savedBranch != null)
        .toList();
    final picked = await showBaseSheet<({String id, String name})>(
      context,
      builder: (context) => ListView(
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

  Future<void> _save({bool update = false}) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final places = context.read<PlacesController>();
    // maybeOf: page tests pump it without a router.
    final router = GoRouter.maybeOf(context);
    setState(() => _saving = true);
    try {
      final r = await _repo.confirm(
        widget.id,
        totalSen: senOf(_total.text)!,
        visitedAt: _at!,
        branchId: _branchId,
        update: update,
      );
      unawaited(places.load()); // the place is in the book now
      if (r.id != widget.id) {
        // A rescan: this read went into the receipt saved before, and this one is gone.
        messenger.showSnackBar(SnackBar(content: Text(l.receiptUpdated)));
        router?.pushReplacement('/receipts/${r.id}');
      } else if (mounted) {
        setState(() => _r = r);
      }
    } on ApiException catch (e) {
      // Saved before: offer to update that one with this scan's items and charges.
      if (!update &&
          e.code == 'duplicate_receipt' &&
          e.data['existingId'] != null &&
          mounted) {
        setState(() => _saving = false);
        final yes = await showBaseDialog(
          context,
          title: l.receiptRescanTitle,
          message: l.receiptRescanBody,
          confirmLabel: l.receiptRescanUpdate,
        );
        if (yes && mounted) return _save(update: true);
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
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
    final id = _r?.place?.placeId;
    return places.places.where((p) => p.restaurant.id == id).firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = _r;
    final review = r != null && r.inReview && _error == null;
    final canSplit = r != null && (r.inReview || r.saved) && _error == null;
    final content = switch (r) {
      _ when _error != null => _Message(
        text: errorText(l, _error!),
        action: (l.tryAgain, _load),
      ),
      null => const SingleChildScrollView(child: SkeletonRows(rows: 4)),
      Receipt(reading: true) => FutureBuilder(
        future: _photo,
        builder: (context, s) => s.data == null
            ? _Message(
                text: l.receiptReading,
                detail: l.receiptReadingHelp,
                busy: true,
              )
            : _Scanning(bytes: s.data!),
      ),
      Receipt(failed: true) => _Message(
        icon: Icons.receipt_long_outlined,
        tone: _Tone.problem,
        text: r.notRestaurant ? l.receiptNotRestaurant : l.receiptFailed,
      ),
      Receipt(saved: true) => _saved(context, r),
      _ => _review(context, r),
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(l.addReceipt),
        actions: [
          if (r != null && !r.saved)
            IconButton(
              tooltip: l.receiptDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      // Save stays in reach under a long list of lines (and away while splitting).
      bottomNavigationBar: review && !_split ? _saveBar(context, r) : null,
      body: canSplit
          ? Column(
              children: [
                // The recipe page's tabs: a sliding pill on the page's paper; only what is under it changes.
                Padding(
                  padding: const EdgeInsets.fromLTRB(spaceM, 8, spaceM, 8),
                  child: PillSwitch<bool>(
                    key: const ValueKey('receipt-split-switch'),
                    expand: true,
                    value: _split,
                    onChanged: _setSplit,
                    pages: _pages,
                    options: [
                      (
                        false,
                        PillLabel(
                          Icons.receipt_long_outlined,
                          l.splitTabReceipt,
                        ),
                        null,
                      ),
                      (
                        true,
                        PillLabel(Icons.groups_outlined, l.splitTabBill),
                        null,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => _setSplit(i == 1),
                    children: [
                      content,
                      SplitBill(
                        receipt: r,
                        share: widget.share ?? _shareText,
                        onStop: () => _pages.animateToPage(
                          0,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : content,
    );
  }

  void _setSplit(bool split) {
    if (split == _split) return;
    setState(() => _split = split);
    // Back to Receipt: the split may have changed the ticks.
    if (!split) _load();
  }

  bool _canSave(Receipt r) {
    final sen = senOf(_total.text);
    return !_saving &&
        sen != null &&
        sen > 0 &&
        _at != null &&
        (_branchName ?? r.place?.name) != null;
  }

  Widget _saveBar(BuildContext context, Receipt r) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: nb.paper,
        border: Border(top: BorderSide(color: nb.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _canSave(r) ? _save : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(l.save),
          ),
        ),
      ),
    );
  }

  String _when(BuildContext context, DateTime at) {
    final loc = MaterialLocalizations.of(context);
    return '${loc.formatMediumDate(at)} · ${formatTime(context, at)}';
  }

  Widget _saved(BuildContext context, Receipt r) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final path = _placePath(context.watch<PlacesController>());
    return ListView(
      padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, spaceL),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_outlined, color: nb.pandan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.place?.name ?? r.shop ?? l.addReceipt,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _Chip(
                    icon: Icons.check_circle,
                    label: l.receiptSavedChip,
                    color: nb.pandan,
                  ),
                ],
              ),
              if (r.visitedAt != null)
                Padding(
                  padding: const EdgeInsets.only(left: 34, top: 2),
                  child: Text(
                    _when(context, r.visitedAt!),
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                ),
              if (r.totalSen != null) ...[
                const SizedBox(height: 16),
                Text(
                  l.receiptTotal,
                  style: text.labelMedium?.copyWith(color: nb.inkSoft),
                ),
                Text(
                  rm(r.totalSen!),
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (r.einvoice case final e?)
          _Einvoice(
            einvoice: e,
            details: _details,
            onDone: _einvoiceDone,
            onOpen: () => _openEinvoice(e.url),
            onDetails: _editDetails,
          )
        else
          _ScanEinvoice(by: r.einvoiceBy, onScan: _scanEinvoice),
        if (r.items.isNotEmpty || r.charges.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Items(receipt: r, onEaten: r.hasSplit ? null : _eat),
        ] else ...[
          // Saved before items and charges were read: a new scan of the same receipt fills them in.
          const SizedBox(height: 16),
          Text(
            l.receiptRescanHint,
            key: const ValueKey('receipt-rescan-hint'),
            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: nb.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.receiptSaved,
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ),
          ],
        ),
        if (path != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => context.push('/places/$path'),
            icon: const Icon(Icons.star_outline),
            label: Text(l.receiptRate),
          ),
        ],
      ],
    );
  }

  Widget _review(BuildContext context, Receipt r) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final sen = senOf(_total.text);
    final placeName = _branchName ?? r.place?.name;
    Widget? check(String gap) => r.gaps.contains(gap)
        ? _Chip(
            key: ValueKey('check-$gap'),
            icon: Icons.priority_high,
            label: l.receiptCheckThis,
            color: nb.kunyit,
            onColor: nb.ink,
          )
        : null;
    final totalGap = r.gaps.contains('totals_mismatch')
        ? 'totals_mismatch'
        : 'total';
    return ListView(
      padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, spaceL),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: nb.mist,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.fact_check_outlined, size: 20, color: nb.pandanDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.receiptCheckHelp,
                  style: text.bodyMedium?.copyWith(color: nb.pandanDeep),
                ),
              ),
            ],
          ),
        ),
        FutureBuilder(
          future: _photo,
          builder: (context, s) => switch (s.data) {
            final bytes? => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _Photo(
                bytes: bytes,
                onTap: () => showPhotoDialog(
                  context,
                  bytes,
                  heroTag: _Photo.hero,
                  heroRadius: 14,
                ),
              ),
            ),
            null => const SizedBox.shrink(),
          },
        ),
        const SizedBox(height: 16),
        _Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Field(
                icon: Icons.storefront_outlined,
                label: l.receiptPlace,
                value: placeName ?? l.receiptChoosePlace,
                missing: placeName == null,
                flag: check('shop'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickPlace,
              ),
              Divider(height: 1, color: nb.line),
              _Field(
                icon: Icons.event_outlined,
                label: l.receiptDate,
                value: _at == null ? '' : _when(context, _at!),
                flag: check('date'),
                trailing: const Icon(Icons.edit_calendar_outlined, size: 20),
                onTap: _pickTime,
              ),
              Divider(height: 1, color: nb.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Icon(Icons.payments_outlined, color: nb.pandan),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('receipt-total'),
                        controller: _total,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          labelText: l.receiptTotal,
                          prefixText: 'RM ',
                          errorText: _total.text.isNotEmpty && sen == null
                              ? l.receiptTotalInvalid
                              : null,
                        ),
                      ),
                    ),
                    if (check(totalGap) case final flag?)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 16),
                        child: flag,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (r.einvoice case final e?)
          _Einvoice(
            einvoice: e,
            details: _details,
            onDone: _einvoiceDone,
            onOpen: () => _openEinvoice(e.url),
            onDetails: _editDetails,
          )
        else
          _ScanEinvoice(by: r.einvoiceBy, onScan: _scanEinvoice),
        if (r.items.isNotEmpty || r.charges.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Items(receipt: r, onEaten: r.hasSplit ? null : _eat),
        ],
      ],
    );
  }
}

enum _Tone { normal, problem }

/// No e-invoice link yet: Scan. A receipt that offers one also shows its last day, so a missed QR never hides it.
class _ScanEinvoice extends StatelessWidget {
  const _ScanEinvoice({required this.by, required this.onScan});

  final DateTime? by;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final until = by;
    if (until == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('einvoice-scan'),
          onPressed: onScan,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(l.einvoiceScan),
        ),
      );
    }
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final ended = until.isBefore(DateTime(now.year, now.month, now.day));
    final date = MaterialLocalizations.of(context).formatMediumDate(until);
    return _Card(
      key: const ValueKey('receipt-einvoice-by'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.request_quote_outlined, color: nb.pandan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.einvoiceTitle,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ended ? l.einvoiceEnded(date) : l.einvoiceByScan(date),
                      style: text.bodySmall?.copyWith(
                        color: ended
                            ? Theme.of(context).colorScheme.error
                            : nb.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              key: const ValueKey('einvoice-scan'),
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text(l.einvoiceScan),
            ),
          ),
        ],
      ),
    );
  }
}

/// The receipt's e-invoice request: the shop's page, its last day, then "I've requested it" (no reminder after).
class _Einvoice extends StatelessWidget {
  const _Einvoice({
    required this.einvoice,
    required this.details,
    required this.onDone,
    required this.onOpen,
    required this.onDetails,
  });

  final ReceiptEinvoice einvoice;
  final EinvoiceDetails? details;
  final ValueChanged<bool> onDone;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final until = einvoice.until;
    final now = DateTime.now();
    final ended =
        until != null && until.isBefore(DateTime(now.year, now.month, now.day));
    final date = until == null
        ? null
        : MaterialLocalizations.of(context).formatMediumDate(until);
    final note = einvoice.done
        ? l.einvoiceDoneNote
        : until == null
        ? l.einvoiceNoLimit
        : ended
        ? l.einvoiceEnded(date!)
        : l.einvoiceBy(date!);
    return _Card(
      key: const ValueKey('receipt-einvoice'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.request_quote_outlined, color: nb.pandan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.einvoiceTitle,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: text.bodySmall?.copyWith(
                        color: ended && !einvoice.done
                            ? Theme.of(context).colorScheme.error
                            : nb.inkSoft,
                      ),
                    ),
                    // The real site, before the user pastes an IC into it. Never cut short: the end of a name is
                    // what tells a look-alike apart.
                    if (!einvoice.done) ...[
                      const SizedBox(height: 2),
                      Text(
                        l.einvoiceOpens(linkHost(einvoice.url)),
                        key: const ValueKey('einvoice-host'),
                        style: text.bodySmall?.copyWith(color: nb.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Negative left, positive right; full width so the pair sits at the right.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  key: const ValueKey('einvoice-done'),
                  onPressed: () => onDone(!einvoice.done),
                  child: Text(
                    einvoice.done ? l.einvoiceUndo : l.einvoiceMarkDone,
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('einvoice-open'),
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l.einvoiceRequest),
                ),
              ],
            ),
          ),
          if (!einvoice.done) ...[
            Divider(height: 24, color: nb.line),
            if (details case final d?) ...[
              Text(
                l.einvoiceCopyHint,
                style: text.labelMedium?.copyWith(color: nb.inkSoft),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  for (final (key, label, value) in [
                    ('name', l.einvoiceName, d.name),
                    ('tin', l.einvoiceTin, d.tin),
                    ('id', l.einvoiceIdNumber, d.idNumber),
                    ('email', l.einvoiceEmail, d.email),
                    ('phone', l.einvoicePhone, d.phone),
                    ('address', l.einvoiceAddress, d.address),
                  ])
                    if (value.trim().isNotEmpty)
                      ActionChip(
                        key: ValueKey('einvoice-copy-$key'),
                        avatar: const Icon(Icons.copy, size: 16),
                        visualDensity: VisualDensity.compact,
                        label: Text(label),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(ClipboardData(text: value));
                          messenger
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(content: Text(l.einvoiceCopied(label))),
                            );
                        },
                      ),
                  ActionChip(
                    key: const ValueKey('einvoice-details-edit'),
                    avatar: const Icon(Icons.edit_outlined, size: 16),
                    visualDensity: VisualDensity.compact,
                    label: Text(l.einvoiceDetailsEdit),
                    onPressed: onDetails,
                  ),
                ],
              ),
            ] else
              TextButton.icon(
                key: const ValueKey('einvoice-details-add'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: onDetails,
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: Text(l.einvoiceDetailsAdd),
              ),
          ],
        ],
      ),
    );
  }
}

/// An outlined card, the app's standard surface.
class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: nb.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nb.line),
      ),
      child: child,
    );
  }
}

/// A small rounded label: "Saved", "Check this".
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onColor,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// Text and icon colour on [color]; null = [color] text on a pale [color].
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final fg = onColor ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onColor == null ? color.withValues(alpha: 0.12) : color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One editable line of the details card: icon, label over value, an optional "Check this", then [trailing].
class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailing,
    required this.onTap,
    this.flag,
    this.missing = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget trailing;
  final VoidCallback onTap;
  final Widget? flag;

  /// No value yet: the prompt shows in the accent colour.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Icon(icon, color: nb.pandan),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelMedium?.copyWith(color: nb.inkSoft),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: missing ? nb.pandan : null,
                    ),
                  ),
                ],
              ),
            ),
            if (flag != null) ...[flag!, const SizedBox(width: 4)],
            IconTheme(
              data: IconThemeData(color: nb.inkSoft),
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}

/// While the server reads: the photo with a scan line sweeping over it (still when the phone asks for no motion).
class _Scanning extends StatefulWidget {
  const _Scanning({required this.bytes});

  final Uint8List bytes;

  @override
  State<_Scanning> createState() => _ScanningState();
}

class _ScanningState extends State<_Scanning>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.value = 0.5;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final style = Theme.of(context).textTheme;
    const height = 320.0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(spaceM, 24, spaceM, 24),
      children: [
        ClipRRect(
          key: const ValueKey('receipt-scan'),
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  widget.bytes,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) {
                    final down = _sweep.status != AnimationStatus.reverse;
                    final y = Curves.easeInOut.transform(_sweep.value) * height;
                    return Stack(
                      children: [
                        // A soft trail behind the line, on the side it came from.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: down ? y - 56 : y,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: down
                                    ? Alignment.topCenter
                                    : Alignment.bottomCenter,
                                end: down
                                    ? Alignment.bottomCenter
                                    : Alignment.topCenter,
                                colors: [
                                  nb.pandan.withValues(alpha: 0),
                                  nb.pandan.withValues(alpha: 0.28),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: y - 1.5,
                          height: 3,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: nb.pandan,
                              boxShadow: [
                                BoxShadow(
                                  color: nb.pandan.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l.receiptReading,
          textAlign: TextAlign.center,
          style: style.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          l.receiptReadingHelp,
          textAlign: TextAlign.center,
          style: style.bodyMedium?.copyWith(color: nb.inkSoft),
        ),
      ],
    );
  }
}

/// The receipt photo: a cropped preview; a tap opens it to zoom.
class _Photo extends StatelessWidget {
  const _Photo({required this.bytes, required this.onTap});

  static const hero = 'photo:receipt';

  final Uint8List bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        child: InkWell(
          key: const ValueKey('receipt-photo'),
          onTap: onTap,
          child: Stack(
            children: [
              PhotoHero(
                tag: hero,
                child: Image.memory(
                  bytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        l.receiptPhotoZoom,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.detail,
    this.busy = false,
    this.icon,
    this.tone = _Tone.normal,
    this.action,
  });

  final String text;
  final String? detail;
  final bool busy;
  final IconData? icon;
  final _Tone tone;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final style = Theme.of(context).textTheme;
    final color = tone == _Tone.problem ? nb.margin : nb.pandan;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(spaceM, 24, spaceM, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const CircularProgressIndicator.adaptive()
            else if (icon != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color),
              ),
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

/// The printed lines: "2 × Nasi Lemak Ayam ... RM 25.80", a dashed rule, then the
/// total the user saves (the lines are as read; only the total is checked).
/// The slip: items (each with a tick for what the user ate and its calories), charges, total, then what the ticks add up to.
class _Items extends StatelessWidget {
  const _Items({required this.receipt, required this.onEaten});

  final Receipt receipt;

  /// Line index, how many eaten; null while a split bill sets the ticks.
  final void Function(int, double)? onEaten;

  List<ReceiptItem> get items => receipt.items;
  List<ReceiptCharge> get charges => receipt.charges;
  int? get totalSen => receipt.totalSen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final figures = text.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String qty(double q) =>
        q == q.roundToDouble() ? q.toInt().toString() : q.toString();
    String label(ReceiptCharge c) => switch (c.kind) {
      'subtotal' => l.receiptSubtotal,
      'discount' => l.receiptDiscount,
      'service' => l.receiptService,
      'tax' => l.receiptTax,
      'rounding' => l.receiptRounding,
      _ => c.name ?? '',
    };
    final dashes = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _Dashes(nb.line),
      ),
    );
    // A slip torn off the till: the receipt's own look, kept on purpose in the standard UI.
    return PhysicalShape(
      clipper: const _TornEdge(),
      color: nb.paper,
      elevation: 2,
      shadowColor: nb.ink.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          key: const ValueKey('receipt-items'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 18, color: nb.inkSoft),
                const SizedBox(width: 8),
                Text(
                  l.receiptItems,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (receipt.hasSplit)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.splitCaloriesNote,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
              ),
            const SizedBox(height: 8),
            for (final (n, i) in items.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (onEaten != null)
                          _Tick(
                            key: (i.quantity ?? 1) > 1
                                ? null
                                : ValueKey('eaten-$n'),
                            item: i,
                            onChanged: (v) => onEaten!(n, v),
                          ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            i.quantity == null ? '' : '${qty(i.quantity!)} ×',
                            style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.name, style: text.bodyMedium),
                              if (i.kcal != null)
                                Text(
                                  [
                                    l.caloriesKcal('${i.kcal}'),
                                    if (i.kcalSource == 'ai')
                                      l.caloriesAiEstimate,
                                  ].join(' · '),
                                  style: text.bodySmall?.copyWith(
                                    color: nb.inkSoft,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (i.amountSen != null)
                          Text(
                            rm(i.amountSen!),
                            style: figures?.copyWith(
                              color: i.amountSen! < 0 ? nb.pandan : null,
                            ),
                          ),
                      ],
                    ),
                    // Under the whole line, past the tick: inside the name's column it ran off a 360 px phone.
                    if (onEaten != null && (i.quantity ?? 1) > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 32),
                        child: _Eaten(
                          key: ValueKey('eaten-$n'),
                          item: i,
                          onChanged: (v) => onEaten!(n, v),
                        ),
                      ),
                  ],
                ),
              ),
            if (charges.isNotEmpty) ...[
              dashes,
              for (final c in charges)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          label(c),
                          style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                        ),
                      ),
                      Text(
                        rm(c.amountSen),
                        style: figures?.copyWith(
                          color: c.amountSen < 0 ? nb.pandan : nb.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (totalSen != null) ...[
              dashes,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.receiptTotal,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    rm(totalSen!),
                    style: figures?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
            if (items.isNotEmpty) ...[dashes, _Calories(receipt: receipt)],
          ],
        ),
      ),
    );
  }
}

/// The same-width checkbox in front of every line: all of it eaten, none, or (dash) some of it.
class _Tick extends StatelessWidget {
  const _Tick({super.key, required this.item, required this.onChanged});

  final ReceiptItem item;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cap = item.quantity ?? 1; // the server's cap
    final all = item.eaten >= cap;
    return SizedBox(
      width: 32,
      height: 24,
      child: Checkbox(
        tristate: true,
        value: all ? true : (item.eaten > 0 ? null : false),
        visualDensity: VisualDensity.compact,
        onChanged: (_) => onChanged(all ? 0 : cap),
      ),
    );
  }
}

/// How many of a line of 2 or more were eaten: − n/cap +, under the line's name.
class _Eaten extends StatelessWidget {
  const _Eaten({super.key, required this.item, required this.onChanged});

  final ReceiptItem item;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cap = item.quantity!;
    final n = item.eaten.floor();
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          tooltip: '−',
          onPressed: n > 0 ? () => onChanged((n - 1).toDouble()) : null,
          icon: const Icon(Icons.remove),
        ),
        Text(
          '$n / ${cap.floor()}',
          style: text.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          tooltip: '+',
          onPressed: n + 1 <= cap ? () => onChanged((n + 1).toDouble()) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// What the ticked lines add up to, or why it cannot say yet; always with the disclaimer.
class _Calories extends StatelessWidget {
  const _Calories({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final ticked = receipt.items.any((i) => i.eaten > 0);
    final soft = text.bodySmall?.copyWith(color: nb.inkSoft);
    return Column(
      key: const ValueKey('receipt-calories'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (receipt.caloriesPending)
          Text(l.caloriesCounting, style: soft)
        else if (!ticked)
          Text(l.caloriesTickHint, style: soft)
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  l.caloriesYouAte('${receipt.eatenKcal}'),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (receipt.hasEstimate) AiBadge(label: l.caloriesAiEstimate),
            ],
          ),
          if (receipt.unknownEaten > 0) Text(l.caloriesUnknown, style: soft),
        ],
        const SizedBox(height: 4),
        Text(l.caloriesDisclaimer, style: soft?.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// Round top corners and a zigzag bottom, as a slip torn off the till.
class _TornEdge extends CustomClipper<Path> {
  const _TornEdge();

  @override
  Path getClip(Size size) {
    const tooth = 10.0;
    const r = 14.0;
    final path = Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height - tooth);
    final n = (size.width / (tooth * 2)).ceil();
    final w = size.width / n;
    for (var i = n; i > 0; i--) {
      path
        ..lineTo(w * i - w / 2, size.height)
        ..lineTo(w * (i - 1), size.height - tooth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_TornEdge old) => false;
}

class _Dashes extends CustomPainter {
  const _Dashes(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}

/// The platform share sheet (the split bill's text); [origin] anchors the iPad popover.
Future<void> _shareText(String text, Rect? origin) => SharePlus.instance.share(
  ShareParams(text: text, sharePositionOrigin: origin),
);
