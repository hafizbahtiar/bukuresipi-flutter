import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_constant.dart';
import 'notebook_dialog.dart' show DialogTone;
import 'pill_switch.dart';

// Standard app UI (Material 3, styled by app_theme.dart), replacing the notebook look page by page. Auth pages
// keep the notebook cover. Moving a page over:
//   NotebookPage            -> nothing (the Scaffold body as is)
//   NotebookTitle(t)        -> kept: page titles stay handwritten (the app's title font)
//   NotebookRow             -> ListTile in a plain list, or BaseTile for items that need telling apart
//   NotebookHeading(t)      -> SectionHeader(t)
//   NotebookSegmented       -> SegmentedButton
//   NotebookPinnedBar       -> PinnedBar
//   showNotebookSheet       -> showModalBottomSheet(isScrollControlled: true, showDragHandle: true)
//   showNotebookPicker      -> showBasePicker
//   showNotebookDialog      -> showBaseDialog (same arguments)
//   notebookGutter + 10     -> spaceM (app_theme_constant.dart)

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

/// A standard dialog with showNotebookDialog's arguments, so a call moves over by its name alone.
/// true = the positive button; false = Cancel, back or a tap outside.
Future<bool> showBaseDialog(
  BuildContext context, {
  String? title,
  required String message,
  DialogTone tone = DialogTone.confirm,
  String? confirmLabel,
  String? cancelLabel,
  Widget? content,
}) async {
  final l = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  final nb = Notebook.of(context);
  final danger = tone == DialogTone.danger;
  final accent = danger ? scheme.error : nb.pandan;
  // The theme's FilledButton is a full-width bar (forms): in a dialog it is a normal-size button, so the answer
  // and Cancel read as a pair, the answer on the right.
  const size = Size(64, 40);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(switch (tone) {
            DialogTone.info => Icons.info_outline,
            DialogTone.confirm => Icons.help_outline,
            DialogTone.danger => Icons.warning_amber_rounded,
          }, color: accent),
          title: title == null ? null : Text(title, style: text.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                message,
                textAlign: title == null ? TextAlign.center : TextAlign.start,
                style: (title == null ? text.bodyLarge : text.bodyMedium)
                    ?.copyWith(color: title == null ? nb.ink : nb.inkSoft),
              ),
              ?content,
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            spaceL,
            0,
            spaceL,
            spaceL - spaceXs,
          ),
          actions: [
            if (tone != DialogTone.info)
              TextButton(
                key: const ValueKey('dialog-cancel'),
                style: TextButton.styleFrom(
                  minimumSize: size,
                  foregroundColor: nb.inkSoft,
                ),
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelLabel ?? l.cancel),
              ),
            FilledButton(
              key: const ValueKey('dialog-confirm'),
              style: FilledButton.styleFrom(
                minimumSize: size,
                padding: const EdgeInsets.symmetric(horizontal: spaceL),
                textStyle: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: accent,
                foregroundColor: danger ? scheme.onError : Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel ?? l.ok),
            ),
          ],
        ),
      ) ??
      false;
}

/// Picks one of [options] in a bottom sheet, the current one ticked. null = dismissed without choosing.
/// [search] (on by default) adds a box that filters the list as you type; turn it off for a few fixed choices.
/// [custom] lets the typed text itself be the answer when it matches no option ("Use “Taman Melati”").
Future<T?> showBasePicker<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? selected,
  required String Function(T) label,
  bool search = true,
  T Function(String typed)? custom,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => Padding(
      // The keyboard (search box) pushes the sheet up instead of covering the list.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.8,
          ),
          child: _PickerSheet<T>(
            title: title,
            options: options,
            selected: selected,
            label: label,
            search: search,
            custom: custom,
          ),
        ),
      ),
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.label,
    required this.search,
    required this.custom,
  });

  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final bool search;
  final T Function(String typed)? custom;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (q.isEmpty || widget.label(o).toLowerCase().contains(q)) o,
    ];
    final exact = widget.options.any((o) => widget.label(o).toLowerCase() == q);
    final typed = _query.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (widget.search)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
            child: TextField(
              key: const ValueKey('picker-search'),
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.pickerSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: spaceS),
            children: [
              if (widget.custom case final custom?
                  when typed.isNotEmpty && !exact)
                ListTile(
                  key: const ValueKey('picker-custom'),
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l.pickerUseTyped(typed)),
                  onTap: () => Navigator.pop(context, custom(typed)),
                ),
              for (final option in shown)
                ListTile(
                  title: Text(widget.label(option)),
                  selected: option == widget.selected,
                  trailing: option == widget.selected
                      ? Icon(Icons.check, color: nb.pandanDeep)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
              if (shown.isEmpty && widget.custom == null)
                ListTile(
                  title: Text(
                    l.pickerNone,
                    style: TextStyle(color: nb.inkSoft),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A form field whose value is picked from a list in a [showBasePicker] sheet: looks like a text field, opens the
/// sheet on tap. No [options] (e.g. offline) = a plain text field, so the value can still be typed.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.controller,
    required this.label,
    this.badge,
    required this.options,
    this.search = true,
    this.allowTyped = false,
    this.onPicked,
  });

  final TextEditingController controller;

  final String label;

  /// Beside the label, e.g. an AiBadge when AI filled the field.
  final Widget? badge;
  final List<String> options;
  final bool search;

  /// The typed text may be kept when it matches no option.
  final bool allowTyped;
  final ValueChanged<String>? onPicked;

  Future<void> _open(BuildContext context) async {
    final picked = await showBasePicker<String>(
      context,
      title: label,
      options: options,
      selected: controller.text.isEmpty ? null : controller.text,
      label: (o) => o,
      search: search,
      custom: allowTyped ? (typed) => typed : null,
    );
    if (picked == null) return;
    controller.text = picked;
    onPicked?.call(picked);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    readOnly: options.isNotEmpty,
    onTap: options.isEmpty ? null : () => _open(context),
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(
      label: badge == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                badge!,
              ],
            ),
      suffixIcon: options.isEmpty ? null : const Icon(Icons.arrow_drop_down),
    ),
  );
}

/// A bar pinned at the top of a scroll view (a page's tabs), opaque so rows scroll under it.
/// Used with `SliverPersistentHeader(pinned: true)`.
class PinnedBar extends SliverPersistentHeaderDelegate {
  PinnedBar({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: spaceM, vertical: spaceS),
      child: Center(child: child),
    ),
  );

  @override
  bool shouldRebuild(PinnedBar old) => true;
}

/// One item of a [MoreMenu]. No [onTap] = shown, but off. [danger] = red (remove, hide).
class MenuAction {
  const MenuAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
}

/// The app bar's ⋮ button: a page's actions in a popup menu, in the order given; a line sets the danger items
/// (remove, hide) apart at the end. Nothing to show = no button.
class MoreMenu extends StatelessWidget {
  const MoreMenu({super.key, required this.actions});

  final List<MenuAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final nb = Notebook.of(context);
    return PopupMenuButton<int>(
      key: const ValueKey('more-menu'),
      icon: const Icon(Icons.more_vert),
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      color: nb.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: nb.line),
      ),
      position: PopupMenuPosition.under,
      onSelected: (i) => actions[i].onTap?.call(),
      itemBuilder: (context) => [
        for (final (i, a) in actions.indexed) ...[
          if (a.danger && i > 0 && !actions[i - 1].danger)
            const PopupMenuDivider(),
          PopupMenuItem(
            value: i,
            enabled: a.onTap != null,
            child: Row(
              children: [
                Icon(
                  a.icon,
                  size: 20,
                  color: a.danger ? scheme.error : nb.inkSoft,
                ),
                const SizedBox(width: spaceM),
                Flexible(
                  child: Text(
                    a.label,
                    style: a.danger ? TextStyle(color: scheme.error) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// [actions] as a bottom sheet, [title] on top: a tile's long-press menu and its ⋮ button. A danger action is
/// red and comes last, after a divider.
Future<void> showActionSheet(
  BuildContext context, {
  String? title,
  required List<MenuAction> actions,
}) {
  final nb = Notebook.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
          for (final (i, a) in actions.indexed) ...[
            if (a.danger && i > 0 && !actions[i - 1].danger)
              const Divider(height: spaceS),
            ListTile(
              leading: Icon(a.icon, color: a.danger ? nb.margin : null),
              title: Text(
                a.label,
                style: a.danger ? TextStyle(color: nb.margin) : null,
              ),
              enabled: a.onTap != null,
              onTap: () {
                Navigator.pop(sheet);
                a.onTap?.call();
              },
            ),
          ],
          const SizedBox(height: spaceS),
        ],
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

/// One section of a [DetailTabs]: its tab label and its rows. [id] keys the tab's label and its scroll position.
class DetailSection {
  const DetailSection({
    required this.id,
    required this.label,
    required this.rows,
  });

  final String id;
  final String label;
  final List<Widget> rows;
}

/// A detail page's body (recipe, place): an optional photo bar ([coverBar], a pinned sliver such as CoverAppBar),
/// a [header] sliver, then the [sections]: tabs under a pinned pill when there are two or more (swiped, or picked
/// on the pill), else one list. Pass only sections with something in them.
class DetailTabs extends StatefulWidget {
  const DetailTabs({
    super.key,
    this.coverBar,
    required this.header,
    required this.sections,
  });

  final Widget? coverBar;
  final Widget header;
  final List<DetailSection> sections;

  @override
  State<DetailTabs> createState() => _DetailTabsState();
}

class _DetailTabsState extends State<DetailTabs> {
  final _pages = PageController();

  /// For its outer scroll: how far the photo bar has collapsed.
  final _nested = GlobalKey<NestedScrollViewState>();
  String? _selected;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final coverBar = widget.coverBar;
    Widget list(List<Widget> rows) => SliverPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + spaceL,
      ),
      sliver: SliverList.list(children: rows),
    );
    if (sections.length < 2) {
      return CustomScrollView(
        slivers: [
          ?coverBar,
          widget.header,
          list([for (final s in sections) ...s.rows]),
        ],
      );
    }
    // Keyboard open = typing in a tab (the header has no fields): fold the header away, or on a short phone it
    // takes all the room left above the keyboard and the field is pushed off screen.
    // The Scaffold takes the keyboard out of its body's MediaQuery (it shrinks the body instead): ask the window,
    // and depend on the body's size so this runs again when the keyboard opens.
    MediaQuery.sizeOf(context);
    if (View.of(context).viewInsets.bottom > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final outer = _nested.currentState?.outerController;
        if (outer == null || !outer.hasClients) return;
        final end = outer.position.maxScrollExtent;
        if (outer.offset < end) outer.jumpTo(end);
      });
    }
    final selected = sections.any((s) => s.id == _selected)
        ? _selected!
        : sections.first.id;
    final pill = SliverPersistentHeader(
      pinned: true,
      delegate: PinnedBar(
        height: MediaQuery.textScalerOf(context).scale(40) + 16,
        child: PillSwitch<String>(
          expand: true,
          value: selected,
          onChanged: (v) => setState(() => _selected = v),
          pages: _pages,
          options: [
            for (final s in sections)
              (
                s.id,
                Text(
                  s.label,
                  key: ValueKey(s.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                null,
              ),
          ],
        ),
      ),
    );
    return NestedScrollView(
      key: _nested,
      headerSliverBuilder: (context, _) => [
        // Pinned on its own: it stays as a bar (back button) once the photo has scrolled away.
        ?coverBar,
        widget.header,
        // The pinned pill (and the photo bar, pinned too): absorbed so each tab's list starts below them.
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: pill,
        ),
      ],
      // One page per tab: swiped, or driven by the pill (it follows the swipe).
      body: PageView(
        controller: _pages,
        onPageChanged: (i) => setState(() => _selected = sections[i].id),
        children: [
          for (final s in sections)
            Builder(
              builder: (context) => CustomScrollView(
                key: PageStorageKey(s.id),
                slivers: [
                  if (coverBar != null)
                    SliverToBoxAdapter(
                      child: _UnderBar(
                        nested: _nested,
                        bar: kToolbarHeight + MediaQuery.paddingOf(context).top,
                      ),
                    ),
                  SliverOverlapInjector(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                  ),
                  list(s.rows),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Room at the top of a tab's list for the pinned photo bar, which covers the list's start only as it finishes
/// collapsing: 0 while the photo is open, growing to the bar's height ([bar]) over the outer scroll's last [bar]
/// pixels. (The pill has NestedScrollView's absorber; a second fixed one would leave a gap while the photo is open.)
class _UnderBar extends StatelessWidget {
  const _UnderBar({required this.nested, required this.bar});

  final GlobalKey<NestedScrollViewState> nested;
  final double bar;

  @override
  Widget build(BuildContext context) {
    final outer = nested.currentState?.outerController;
    if (outer == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: outer,
      builder: (context, _) {
        // Before the first layout the outer scroll has no size yet.
        if (!outer.hasClients || !outer.position.hasContentDimensions) {
          return const SizedBox.shrink();
        }
        final p = outer.position;
        return SizedBox(
          height: (p.pixels - (p.maxScrollExtent - bar)).clamp(0.0, bar),
        );
      },
    );
  }
}
