import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/owner.dart';
import '../../domain/owner_repository.dart';
import '../load_view.dart';

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
    final change = await showDialog<(int, bool)>(
      context: context,
      builder: (_) => _MeterDialog(meter: m),
    );
    if (change == null) return;
    try {
      final updated = await repo.updateMeter(
        m.code,
        monthlyCap: change.$1,
        active: change.$2,
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
      appBar: AppBar(title: Text(l.ownerTitle)),
      body: LoadView(
        loading: _loading,
        error: _error,
        onReload: _load,
        child: s == null
            ? null
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.9,
                    children: [
                      _Count(label: l.ownerUsers, value: s.usersTotal),
                      _Count(
                        label: l.ownerNewThisWeek,
                        value: s.usersNewThisWeek,
                      ),
                      _Count(label: l.ownerSharesToday, value: s.sharesToday),
                      _Count(
                        label: l.ownerFailedToday,
                        value: s.failedToday,
                        warn: s.failedToday > 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.people_outline),
                    title: Text(l.ownerUsers),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/owner/users'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.report_outlined),
                    title: Text(l.ownerFailedShares),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/owner/shares'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.ownerMeters,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      l.ownerMetersHelp,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  for (final m in s.meters)
                    _MeterTile(meter: m, onTap: () => _edit(m)),
                ],
              ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, this.warn = false});

  final String label;
  final int value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn ? c.errorContainer : c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: text.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$value',
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: warn ? c.onErrorContainer : null,
            ),
          ),
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
    final c = Theme.of(context).colorScheme;
    final high = meter.share >= 0.9;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                Text(
                  meter.active
                      ? '${meter.used} / ${meter.monthlyCap}'
                      : l.ownerMeterOff,
                  style: TextStyle(
                    color: !meter.active || high ? c.error : c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: meter.active ? meter.share : 0,
                minHeight: 6,
                color: high ? c.error : c.primary,
                backgroundColor: c.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns (cap, on) or null when cancelled.
class _MeterDialog extends StatefulWidget {
  const _MeterDialog({required this.meter});

  final Meter meter;

  @override
  State<_MeterDialog> createState() => _MeterDialogState();
}

class _MeterDialogState extends State<_MeterDialog> {
  late final _cap = TextEditingController(text: '${widget.meter.monthlyCap}');
  late bool _active = widget.meter.active;

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cap = int.tryParse(_cap.text);
    return AlertDialog(
      title: Text(widget.meter.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.ownerMeterActive),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: cap == null
              ? null
              : () => Navigator.pop(context, (
                  int.tryParse(_cap.text) ?? widget.meter.monthlyCap,
                  _active,
                )),
          child: Text(l.save),
        ),
      ],
    );
  }
}
