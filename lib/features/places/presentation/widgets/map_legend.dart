import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// The circles on the map. The map page draws them from these values and the legend paints the same ones, so the two
/// never disagree. Other users stay anonymous: their restaurants are "other Bukuresipi users", never a name.
enum MapMark {
  mine(radius: 8, strokeWidth: 3),
  mineHandPin(radius: 8, strokeWidth: 3),
  family(radius: 8, strokeWidth: 3),
  community(radius: 5, strokeWidth: 1),
  here(radius: 6.5, strokeWidth: 2.5);

  const MapMark({required this.radius, required this.strokeWidth});

  final double radius;
  final double strokeWidth;

  Color fill(Notebook nb) => switch (this) {
    mine || mineHandPin => nb.pandan,
    family => Colors.white,
    community => nb.inkSoft.withValues(alpha: 0.7),
    here => hereBlue,
  };

  Color stroke(Notebook nb) => switch (this) {
    mineHandPin => nb.kunyit,
    family => nb.pandan,
    mine || community || here => Colors.white,
  };

  static const hereBlue = Color(0xFF1E88E5);
}

/// The paper-circle map button that opens the legend.
class MapLegendButton extends StatelessWidget {
  const MapLegendButton({
    super.key,
    required this.owner,
    required this.showCommunity,
    required this.onShowCommunity,
  });

  final bool owner;
  final bool showCommunity;
  final ValueChanged<bool> onShowCommunity;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return Tooltip(
      message: l.mapLegend,
      child: Material(
        color: nb.paper,
        elevation: 2,
        shadowColor: nb.ink.withValues(alpha: 0.3),
        shape: CircleBorder(side: BorderSide(color: nb.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showNotebookSheet<void>(
            context,
            builder: (_) => MapLegend(
              owner: owner,
              showCommunity: showCommunity,
              onShowCommunity: onShowCommunity,
            ),
          ),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(Icons.legend_toggle, size: 20, color: nb.pandanDeep),
          ),
        ),
      ),
    );
  }
}

/// What each circle on the map means.
class MapLegend extends StatefulWidget {
  const MapLegend({
    super.key,
    this.owner = false,
    required this.showCommunity,
    required this.onShowCommunity,
  });

  /// Only the owner sees other users' restaurants, so only the owner gets that row and its switch.
  final bool owner;
  final bool showCommunity;
  final ValueChanged<bool> onShowCommunity;

  @override
  State<MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<MapLegend> {
  late bool _community = widget.showCommunity;

  void _set(bool on) {
    setState(() => _community = on);
    widget.onShowCommunity(on);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final rows = [
      (MapMark.mine, l.legendMine, l.legendMineHint),
      (MapMark.mineHandPin, l.legendHandPin, l.legendHandPinHint),
      (MapMark.family, l.legendFamily, l.legendFamilyHint),
      if (widget.owner)
        (MapMark.community, l.legendCommunity, l.legendCommunityOwnerHint),
      (MapMark.here, l.legendHere, l.legendHereHint),
    ];
    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 8),
          child: Text(
            l.mapLegend,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final (mark, title, hint) in rows)
          NotebookRow(
            mark: MapMarkDot(mark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(hint, style: text.bodyMedium?.copyWith(color: nb.inkSoft)),
              ],
            ),
          ),
        if (widget.owner)
          NotebookRow(
            mark: Icon(Icons.layers_outlined, size: 20, color: nb.inkSoft),
            onTap: () => _set(!_community),
            trailing: Switch(value: _community, onChanged: _set),
            child: Text(
              l.mapShowCommunity,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

/// One map circle, painted as the map draws it.
class MapMarkDot extends StatelessWidget {
  const MapMarkDot(this.mark, {super.key});

  final MapMark mark;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final d = (mark.radius + mark.strokeWidth) * 2;
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: mark.fill(nb),
        shape: BoxShape.circle,
        border: Border.all(color: mark.stroke(nb), width: mark.strokeWidth),
        boxShadow: [
          BoxShadow(color: nb.ink.withValues(alpha: 0.25), blurRadius: 2),
        ],
      ),
    );
  }
}
