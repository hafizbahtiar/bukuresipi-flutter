import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';

import '../../../../core/widgets/wide_page.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/pages/account_page.dart';
import '../../../auth/presentation/widgets/avatar.dart';
import '../../../family/presentation/family_controller.dart';
import '../../../places/presentation/pages/places_list_page.dart';
import '../../../places/presentation/places_controller.dart';
import '../../../recipes/presentation/recipes_controller.dart';
import '../../../shopping/presentation/shopping_controller.dart';
import '../../../shares/presentation/recent_shares.dart';
import '../add_sheet.dart';
import 'feed_page.dart';
import '../receipts_tab.dart';
import '../widgets/floating_nav.dart';

/// Signed-in home: Home (feed, with the map and shopping-list buttons), Book, Receipts and Account tabs, and "+" in
/// the middle (add anything: [showAddSheet]; it is a button, not a tab). Rebuilt after every share (the share page goes
/// back to '/'), so it reloads the places.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.open});

  /// Pass as the route's `extra` to show the Home tab (after a share). A new object each time, so going there twice
  /// still switches (the page keeps its state across navigations).
  static Object get homeTab => HomeOpen(0);

  /// The same for the Book tab (Done after a share: the place or recipe lands there).
  static Object get bookTab => HomeOpen(1);

  /// The Receipts tab on its Calories side, reloaded (a meal saved from "+").
  static Object get caloriesTab => HomeOpen(2, calories: true);

  /// The `extra` of the route; a new one = show Home.
  final Object? open;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _tab = _tabOf(widget.open);

  /// A tab's list is moving: the nav sits smaller ([FloatingNav.compact]); full size again [_rest] after it stops.
  bool _compact = false;

  /// How far the list moved since this scroll began (either way); [_compact] only past [_travel].
  double _run = 0;

  /// Movement that counts as scrolling: a jitter of the finger never shrinks the bar.
  static const _travel = 24.0;

  /// The pause after the list comes to rest before the bar grows back: a quick stop-and-go does not pulse it.
  static const _rest = Duration(milliseconds: 500);
  Timer? _restore;

  void _setCompact(bool compact) {
    if (compact != _compact && mounted) setState(() => _compact = compact);
  }

  void _onScroll(ScrollNotification n) {
    // Vertical only (a card strip scrolled sideways is not the page moving); depth 1 = a NestedScrollView's inner list.
    if (n.metrics.axis != Axis.vertical || n.depth > 1) return;
    switch (n) {
      case ScrollStartNotification():
        _run = 0;
        _restore?.cancel();
      case ScrollUpdateNotification(:final scrollDelta?):
        _restore?.cancel();
        _run += scrollDelta.abs();
        if (_run > _travel) _setCompact(true);
      case ScrollEndNotification():
        _restore?.cancel();
        _restore = Timer(_rest, () => _setCompact(false));
      default:
    }
  }

  /// Bumped when Home's tab is tapped while open: the feed scrolls back to the top.
  final _feedTop = ValueNotifier(0);

  void _select(int tab) {
    if (tab == _tab) {
      if (tab == 0) _feedTop.value++;
      return;
    }
    _restore?.cancel();
    _run = 0;
    setState(() {
      _tab = tab;
      _compact = false; // another tab: show the bar in full
    });
  }

  static int _tabOf(Object? open) => open is HomeOpen ? open.tab : 0;

  @override
  void initState() {
    super.initState();
    // After the first frame: load() notifies at once (spinner), which is not allowed while this page is building.
    final places = context.read<PlacesController>();
    final recipes = context.read<RecipesController>();
    final shared = context.read<RecentShares>();
    final shopping = context.read<ShoppingController>();
    final family = context
        .read<FamilyController?>(); // optional: the app works without a family
    DateTime? loadedAt;
    Future<void> refresh() async {
      // Back from TikTok after sharing: the post may be read by now, so shares always. The rest at most every
      // [_resumeGap] (a share that finishes reloads the book and recipes itself; pull-to-refresh is there too).
      shared.load();
      final now = DateTime.now();
      if (loadedAt != null && now.difference(loadedAt!) < _resumeGap) return;
      loadedAt = now; // no second round while this one runs
      await Future.wait([
        ?family?.load(),
        places.load(),
        recipes.load(),
        shopping.load(),
      ]);
      // Offline: not fresh, so the next return tries again.
      if (places.error != null ||
          recipes.error != null ||
          shopping.error != null) {
        loadedAt = null;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
    _life = AppLifecycleListener(onResume: refresh);
  }

  late final AppLifecycleListener _life;

  /// Switching apps back and forth reloads the heavy lists at most this often.
  static const _resumeGap = Duration(minutes: 2);

  @override
  void didUpdateWidget(covariant HomePage old) {
    super.didUpdateWidget(old);
    if (widget.open != null && !identical(widget.open, old.open)) {
      _tab = _tabOf(widget.open);
    }
  }

  @override
  void dispose() {
    _restore?.cancel();
    _life.dispose();
    _feedTop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final user = context.select<AuthController, User?>((a) => a.user);
    // Material's adaptive layout: a bottom bar on a phone held upright, a rail on the left edge when wide.
    final rail = isWide(context);
    final nav = FloatingNav(
      vertical: rail,
      compact: _compact,
      selected: _tab,
      onSelected: _select,
      addLabel: l.navAdd,
      onAdd: () => showAddSheet(context),
      items: [
        // Outlined when idle, filled and rounded when active: one family, so the switch reads as a fill.
        NavItem(Icons.home_outlined, Icons.home_rounded, l.navHome),
        NavItem(Icons.menu_book_outlined, Icons.menu_book_rounded, l.navBook),
        NavItem(Icons.receipt_long_outlined, Icons.receipt_long, l.navReceipts),
        NavItem(
          Icons.account_circle_outlined,
          Icons.account_circle_rounded,
          l.navAccount,
          // Their photo when they have one; else the icon (a letter would read as a stray button).
          picture: switch (user) {
            final u? when u.avatar != null => Avatar(
              key: const ValueKey('nav-avatar'),
              userId: u.id,
              avatar: u.avatar,
              name: u.name ?? u.email,
              size: 20,
            ),
            _ => null,
          },
        ),
      ],
    );
    final tabs = NotificationListener<ScrollNotification>(
      // While a list scrolls, either way, the nav shrinks out of the way; it grows back once the list is at rest.
      onNotification: (n) {
        _onScroll(n);
        return false;
      },
      child: IndexedStack(
        index: _tab,
        children: [
          // The feed's grid uses the whole screen; the lists are a readable column on a tablet.
          FeedPage(toTop: _feedTop),
          const WidePage(child: PlacesListPage()),
          WidePage(child: ReceiptsTab(open: widget.open)),
          const WidePage(child: AccountPage()),
        ],
      ),
    );
    if (!rail) {
      return Scaffold(
        // The nav floats: the tabs run under it (each pads its list by navRoom).
        extendBody: true,
        body: tabs,
        bottomNavigationBar: nav,
      );
    }
    final media = MediaQuery.of(context);
    return Scaffold(
      body: Row(
        children: [
          // On the desk the readable column (WidePage) sits on: one surface beside a list, a sidebar beside the feed.
          ColoredBox(
            color: Notebook.of(context).mist,
            child: Center(child: nav),
          ),
          Expanded(
            child: LayoutBuilder(
              // The tabs see the screen beside the rail (the feed's columns, WidePage); the notch is the rail's.
              builder: (context, room) => MediaQuery(
                data: media
                    .removePadding(removeLeft: true)
                    .copyWith(size: Size(room.maxWidth, media.size.height)),
                child: tabs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A route `extra` naming the tab to show; compared by identity, so each one switches once.
class HomeOpen {
  HomeOpen(this.tab, {this.calories = false});

  final int tab;

  /// The Receipts tab shows its Calories side, reloaded.
  final bool calories;
}
