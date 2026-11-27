import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/market.dart';
import '../places_controller.dart';
import 'market_days.dart';
import 'owner_panel.dart';

/// Owner, Edit branch > Days: a market's weekly days. Saved on its own button, replacing the whole list.
class MarketDaysEditor extends StatefulWidget {
  const MarketDaysEditor({
    super.key,
    required this.branchId,
    required this.initial,
    this.market = true,
  });

  final String branchId;
  final List<MarketDay> initial;

  /// false = any other place: its opening hours ("Opening hours", a break = two rows).
  final bool market;

  static const maxRows = 14; // the API's limit

  @override
  State<MarketDaysEditor> createState() => _MarketDaysEditorState();
}

class _MarketDaysEditorState extends State<MarketDaysEditor> {
  late List<MarketDay> _days = [...widget.initial];
  bool _saving = false;
  ({String text, PanelTone tone})? _notice;

  void _edit(void Function() change) => setState(() {
    change();
    _notice = null;
  });

  void _replace(int i, {int? day, String? opens, String? closes}) {
    final d = _days[i];
    _edit(
      () => _days[i] = MarketDay(
        day: day ?? d.day,
        opens: opens ?? d.opens,
        closes: closes ?? d.closes,
      ),
    );
  }

  /// A new row: the day after the last one, at a pasar malam's usual hours.
  void _add() => _edit(
    () => _days.add(
      MarketDay(
        day: _days.isEmpty ? 6 : _days.last.day % 7 + 1,
        opens: '17:00',
        closes: '22:00',
      ),
    ),
  );

  Future<void> _pickDay(int i) async {
    final picked = await showBasePicker<int>(
      context,
      title: AppLocalizations.of(context).marketDayField,
      options: const [1, 2, 3, 4, 5, 6, 7],
      selected: _days[i].day,
      label: (d) => marketDayName(context, d),
      search: false,
    );
    if (picked != null && mounted) _replace(i, day: picked);
  }

  Future<String?> _pickTime(String hhmm) async {
    final [h, m] = hhmm.split(':').map(int.parse).toList();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
    );
    if (t == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  String? _problem(AppLocalizations l) {
    final seen = <String>{};
    for (final d in _days) {
      if (d.opens == d.closes) return l.marketSameTime;
      if (!seen.add('${d.day} ${d.opens}')) return l.marketDayTwice;
    }
    return null;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_problem(l) case final problem?) {
      setState(() => _notice = (text: problem, tone: PanelTone.warning));
      return;
    }
    final places = context.read<PlacesController>();
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      final days = [..._days]
        ..sort((a, b) {
          final byDay = a.day.compareTo(b.day);
          return byDay != 0 ? byDay : a.opensAt.compareTo(b.opensAt);
        });
      await places.setSchedule(widget.branchId, days);
      if (!mounted) return;
      setState(() {
        _days = days;
        _notice = (
          text: widget.market ? l.marketDaysSaved : l.hoursSaved,
          tone: PanelTone.success,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _notice = (text: errorText(l, e), tone: PanelTone.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final field = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: spaceS),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    return OwnerPanel(
      icon: Icons.event_outlined,
      title: widget.market ? l.marketDaysTitle : l.hoursTitle,
      subtitle: widget.market ? l.marketDaysHelp : l.hoursHelp,
      children: [
        if (_days.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: spaceS),
            child: Text(
              widget.market ? l.marketDaysUnknown : l.hoursUnknown,
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
          ),
        for (final (i, d) in _days.indexed)
          Padding(
            key: ValueKey('market-row-$i'),
            padding: const EdgeInsets.only(bottom: spaceS),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spaceXs,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey('market-day-$i'),
                        style: field,
                        onPressed: _saving ? null : () => _pickDay(i),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(marketDayName(context, d.day)),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('market-remove-$i'),
                      tooltip: l.remove,
                      icon: Icon(Icons.close, color: nb.inkSoft),
                      onPressed: _saving
                          ? null
                          : () => _edit(() => _days.removeAt(i)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey('market-opens-$i'),
                        style: field,
                        onPressed: _saving
                            ? null
                            : () async {
                                final t = await _pickTime(d.opens);
                                if (t != null && mounted) {
                                  _replace(i, opens: t);
                                }
                              },
                        child: Text(
                          '${l.marketOpens} ${marketClock(context, d.opens)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: spaceXs),
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey('market-closes-$i'),
                        style: field,
                        onPressed: _saving
                            ? null
                            : () async {
                                final t = await _pickTime(d.closes);
                                if (t != null && mounted) {
                                  _replace(i, closes: t);
                                }
                              },
                        child: Text(
                          '${l.marketCloses} ${marketClock(context, d.closes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (d.closesAt < d.opensAt)
                  Text(
                    l.marketPastMidnight,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
              ],
            ),
          ),
        if (_notice case final n?)
          Padding(
            padding: const EdgeInsets.only(bottom: spaceS),
            child: PanelNotice(text: n.text, tone: n.tone),
          ),
        PanelActions(
          children: [
            BusyButton(
              key: const ValueKey('market-add'),
              icon: Icons.add,
              label: l.marketAddDay,
              busyLabel: l.marketAddDay,
              busy: false,
              kind: BusyButtonKind.outlined,
              onPressed: _saving || _days.length >= MarketDaysEditor.maxRows
                  ? null
                  : _add,
            ),
            BusyButton(
              key: const ValueKey('market-save-days'),
              icon: Icons.check,
              label: l.marketSaveDays,
              busyLabel: l.marketSavingDays,
              busy: _saving,
              kind: BusyButtonKind.filled,
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }
}
