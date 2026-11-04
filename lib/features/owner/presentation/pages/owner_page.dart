import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/load_view.dart';

/// Owner overview: counts, and each outside service's use this month against its cap (tap to change it).
class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  OwnerStats? _stats;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await context.read<OwnerRepository>().getStats();
      if (mounted) {
        setState(() {
          _stats = s;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Meter m) async {
    final l = AppLocalizations.of(context);
    final repo = context.read<OwnerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final change = await showNotebookSheet<(int, String, bool)>(
      context,
      builder: (_) => _MeterSheet(meter: m),
    );
    if (change == null) return;
    try {
      final updated = await repo.updateMeter(
        m.code,
        cap: change.$1,
        period: change.$2,
        active: change.$3,
      );
      if (mounted) setState(() => _stats = _stats?.withMeter(updated));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = _stats;
    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.ownerTitle)),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: s == null
            ? null
            : NotebookPage(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _Ledger(
                      label: l.ownerUsers,
                      value: s.usersTotal,
                      note: l.ownerNewSuffix(s.usersNewThisWeek),
                      onTap: () => context.push('/owner/users'),
                    ),
                    _Ledger(label: l.ownerSharesToday, value: s.sharesToday),
                    _Ledger(
                      label: l.ownerFailedToday,
                      value: s.failedToday,
                      warn: s.failedToday > 0,
                      onTap: () => context.push('/owner/shares'),
                    ),
                    _Ledger(
                      label: l.ownerReports,
                      value: s.reportsOpen,
                      note: l.ownerReportReadyCount(s.reportsReady),
                      onTap: () => context.push('/owner/reports'),
                    ),
                    _Ledger(
                      label: l.ownerReviewReports,
                      value: s.reviewReportsOpen,
                      onTap: () => context.push('/owner/review-reports'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        notebookGutter + 10,
                        28,
                        20,
                        4,
                      ),
                      child: Text(
                        l.ownerMeters,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        notebookGutter + 10,
                        0,
                        20,
                        8,
                      ),
                      child: Text(
                        l.ownerMetersHelp,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Notebook.of(context).inkSoft),
                      ),
                    ),
                    for (final m in s.meters)
                      _MeterTile(meter: m, onTap: () => _edit(m)),
                  ],
                ),
              ),
      ),
    );
  }
}

/// One line of the owner's ledger: what, then the number at the right edge.
class _Ledger extends StatelessWidget {
  const _Ledger({
    required this.label,
    required this.value,
    this.note,
    this.warn = false,
    this.onTap,
  });

  final String label;
  final int value;
  final String? note;
  final bool warn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return NotebookRow(
      onTap: onTap,
      mark: onTap == null
          ? null
          : Icon(Icons.arrow_outward, size: 16, color: nb.inkSoft),
      trailing: Text(
        '$value',
        style: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: warn ? nb.margin : nb.ink,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.titleMedium),
          if (note != null)
            Text(note!, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
        ],
      ),
    );
  }
}

class _MeterTile extends StatelessWidget {
  const _MeterTile({required this.meter, required this.onTap});

  final Meter meter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final high = meter.share >= 0.9;
    return NotebookRow(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meter.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                meter.active
                    ? '${meter.used} / ${meter.cap} ${meter.period == 'day' ? l.ownerPerDay : l.ownerPerMonth}'
                    : l.ownerMeterOff,
                style: TextStyle(
                  color: !meter.active || high ? nb.margin : nb.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: meter.active ? meter.share : 0,
              minHeight: 4,
              color: high ? nb.margin : nb.pandan,
              backgroundColor: nb.mist,
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns (cap, period, on) or null when cancelled.
class _MeterSheet extends StatefulWidget {
  const _MeterSheet({required this.meter});

  final Meter meter;

  @override
  State<_MeterSheet> createState() => _MeterSheetState();
}

class _MeterSheetState extends State<_MeterSheet> {
  late final _cap = TextEditingController(text: '${widget.meter.cap}');
  late bool _active = widget.meter.active;
  late String _period = widget.meter.period == 'day' ? 'day' : 'month';

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final cap = int.tryParse(_cap.text);
    Widget period(String value, String label) => ChoiceChip(
      label: Text(label),
      selected: _period == value,
      onSelected: (_) => setState(() => _period = value),
      selectedColor: nb.mist,
      side: BorderSide(color: nb.line),
      labelStyle: TextStyle(
        color: _period == value ? nb.pandanDeep : nb.inkSoft,
        fontWeight: FontWeight.w600,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 16),
        children: [
          Text(
            widget.meter.name,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cap,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(labelText: l.ownerMeterCap),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text(
            l.ownerMeterPeriod,
            style: text.labelLarge?.copyWith(color: nb.inkSoft),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              period('day', l.ownerPeriodDay),
              period('month', l.ownerPeriodMonth),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.ownerMeterActive),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: cap == null
                      ? null
                      : () => Navigator.pop(context, (cap, _period, _active)),
                  child: Text(l.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
