import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_theme_constant.dart';
import 'menus.dart';

/// A section's label above its rows, as in Android's settings lists.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(spaceM, spaceL, spaceM, spaceXs),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}

/// How a [BaseTile] sits on the page.
enum TileStyle {
  /// No box: rows of a plain list (the caller adds dividers).
  plain,

  /// A bordered card: items the eye must tell apart (branches, receipts).
  outlined,

  /// A tinted card with no border: a highlighted or summary item.
  filled,
}

/// The colour of a [TileTag].
enum TagTone { neutral, good, warn, danger }

/// A small rounded label under a tile's text: "No pin", "To check", "Closed".
class TileTag {
  const TileTag(this.label, {this.tone = TagTone.neutral, this.key});

  final String label;
  final TagTone tone;
  final Key? key;
}

/// One [TileTag] as a small tinted pill (under a tile's text, or a page's header).
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key});

  final TileTag tag;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final color = switch (tag.tone) {
      TagTone.neutral => nb.inkSoft,
      TagTone.good => nb.pandanDeep,
      TagTone.warn => nb.kunyit,
      TagTone.danger => nb.margin,
    };
    return Container(
      key: tag.key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        tag.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          // Yellow text is unreadable: a warning stays ink on its tint.
          color: tag.tone == TagTone.warn ? nb.ink : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The app's list item. Leading icon or avatar, a bold title, a soft subtitle (2 lines), tags, then any [footer]
/// (a rating line, inline buttons). [trailing] = an amount or a chevron. Its [actions] open on a long press and from
/// a ⋮ button at the end (always shown, so they are found without knowing the long press).
class BaseTile extends StatelessWidget {
  const BaseTile({
    super.key,
    required this.title,
    this.style = TileStyle.outlined,
    this.leading,
    this.subtitle,
    this.tags = const [],
    this.footer,
    this.trailing,
    this.onTap,
    this.actions = const [],
    this.muted = false,
    this.dense = false,
  });

  final String title;
  final TileStyle style;
  final Widget? leading;
  final String? subtitle;
  final List<TileTag> tags;
  final Widget? footer;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<MenuAction> actions;

  /// Greyed and struck through: closed, gone.
  final bool muted;

  /// Tighter padding, for long lists.
  final bool dense;

  /// A round tinted icon for [leading].
  static Widget icon(BuildContext context, IconData icon, {Color? color}) {
    final nb = Notebook.of(context);
    final c = color ?? nb.pandanDeep;
    return CircleAvatar(
      radius: 20,
      backgroundColor: c.withValues(alpha: 0.12),
      child: Icon(icon, size: 22, color: c),
    );
  }

  void _openActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showActionSheet(context, title: title, actions: actions);
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final pad = dense ? spaceS + 2 : spaceM - 4;
    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        spaceM - 4,
        pad,
        actions.isEmpty ? spaceM - 4 : 0,
        pad,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: spaceM - 4)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: muted ? nb.inkSoft : null,
                    decoration: muted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (subtitle case final sub? when sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                    ),
                  ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: spaceS - 2),
                    child: Wrap(
                      spacing: spaceXs + 2,
                      runSpacing: spaceXs,
                      children: [for (final t in tags) TagChip(t)],
                    ),
                  ),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: spaceXs),
                    child: footer!,
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: spaceS),
            Padding(padding: const EdgeInsets.only(top: 2), child: trailing!),
          ],
          if (actions.isNotEmpty)
            IconButton(
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.more_vert, color: nb.inkSoft),
              onPressed: () => _openActions(context),
            ),
        ],
      ),
    );
    final radius = BorderRadius.circular(style == TileStyle.plain ? 0 : 12);
    final tile = Material(
      color: switch (style) {
        TileStyle.filled => nb.mist,
        _ => Colors.transparent,
      },
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: style == TileStyle.outlined
            ? BorderSide(color: nb.line)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: actions.isEmpty ? null : () => _openActions(context),
        child: body,
      ),
    );
    return style == TileStyle.plain
        ? tile
        : Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: spaceM,
              vertical: spaceXs,
            ),
            child: tile,
          );
  }
}

/// A tinted note explaining a section to people who may not know the term (e.g. what allergens are).
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, spaceS),
      elevation: 0,
      color: nb.mist,
      child: Padding(
        padding: const EdgeInsets.all(spaceM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: nb.pandanDeep),
            const SizedBox(width: spaceM),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
