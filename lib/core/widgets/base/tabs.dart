import 'package:flutter/material.dart';

import '../../theme/app_theme_constant.dart';
import '../pill_switch.dart';
import 'tiles.dart';

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

/// An edit page's body in its detail page's segments (the same pill, the same [DetailSection]s): one page per section,
/// swiped or picked on the pill, each a plain scroll view kept alive once shown, so fields keep what was typed and a
/// field scrolled into view (Scrollable.ensureVisible) lands right, which DetailTabs' nested scroll does not do. A
/// section is built the first time it comes into view (its work, e.g. a search, waits until then). One section = no
/// pill.
class EditTabs extends StatefulWidget {
  const EditTabs({super.key, required this.sections});

  final List<DetailSection> sections;

  @override
  State<EditTabs> createState() => _EditTabsState();
}

class _EditTabsState extends State<EditTabs> {
  final _pages = PageController();
  String? _selected;

  @override
  void didUpdateWidget(EditTabs old) {
    super.didUpdateWidget(old);
    if (widget.sections.length <= old.sections.length) return;
    // A page added after the built ones does not lay the PageView out again: a tap on it would stop at the old end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      final p = _pages.position;
      p.applyContentDimensions(
        0,
        p.viewportDimension * (widget.sections.length - 1),
      );
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    Widget body(DetailSection s) => SingleChildScrollView(
      padding: EdgeInsets.only(
        // Under the pill: with the pill's own fixed gap, 16 before a tab's first row (rows bring no top padding).
        top: sections.length > 1 ? spaceS : 0,
        bottom: MediaQuery.paddingOf(context).bottom + spaceL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: s.rows,
      ),
    );
    if (sections.length < 2) return body(sections.first);
    final selected = sections.any((s) => s.id == _selected)
        ? _selected!
        : sections.first.id;
    return Column(
      children: [
        Padding(
          // A fixed gap under the pill: scrolled content never runs up against it.
          padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, spaceS),
          child: PillSwitch<String>(
            expand: true,
            value: selected,
            onChanged: (v) => setState(() => _selected = v),
            pages: _pages,
            options: [
              for (final s in sections)
                (
                  s.id,
                  // A small phone with four tabs: the label shrinks a little rather than losing its end.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(s.label, key: ValueKey(s.id), maxLines: 1),
                  ),
                  null,
                ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (i) => setState(() => _selected = sections[i].id),
            children: [for (final s in sections) _KeepAlive(child: body(s))],
          ),
        ),
      ],
    );
  }
}

/// Keeps a swiped-away page (its fields, its scroll) instead of building it again.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
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
    Widget list(List<Widget> rows, {bool tab = false}) => SliverPadding(
      padding: EdgeInsets.only(
        // Under the pill: a clear gap before the tab's content (a section title brings its own).
        top: tab && rows.firstOrNull is! SectionHeader ? spaceS : 0,
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
                // A small phone with four tabs: the label shrinks a little rather than losing its end ("Comp…").
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(s.label, key: ValueKey(s.id), maxLines: 1),
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
                  list(s.rows, tab: true),
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
