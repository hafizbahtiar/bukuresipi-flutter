import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notebook.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../places/domain/nearby_branch.dart';
import '../../shares/presentation/widgets/share_image.dart';
import 'widgets/feed_card.dart';
import '../../places/presentation/location.dart';
import '../../places/presentation/places_controller.dart';
import '../../places/presentation/widgets/nearby_sheet.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipes_controller.dart';

enum FeedKind { all, recipes, restaurants }

/// Where the phone is; null = location refused or unavailable.
typedef Locate = Future<({double lat, double lng})?> Function();

Future<({double lat, double lng})?> _phone() async {
  final p = await currentPosition(timeLimit: const Duration(seconds: 10));
  return p == null ? null : (lat: p.latitude, lng: p.longitude);
}

/// The Home tab: restaurants near the phone (GET /places/nearby), community recipes and catalogue dishes in one
/// page, with one search box and filters (kind, "says halal", cuisine). Built only from existing endpoints:
/// recipes are searched on the server, restaurants filtered on the phone (the nearby list is small).
/// shortcut: one mixed list from separate endpoints; a ranked GET /feed when the sections are not enough.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key, this.locate = _phone});

  final Locate locate;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const _nearbyKm = 5.0; // as the map

  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  FeedKind _kind = FeedKind.all;
  bool _halal = false;
  String? _cuisine;

  bool? _located; // null = asking
  List<NearbyBranch> _nearby = const [];
  List<Recipe> _community = const [];
  String? _next;
  List<Dish> _dishes = const [];
  bool _loading = true;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([_loadNearby(), _loadRecipes()]);

  Future<void> _loadNearby() async {
    final here = await widget.locate();
    if (!mounted) return;
    setState(() => _located = here != null);
    if (here == null) return;
    try {
      final rows = await context.read<PlacesController>().nearby(
        here.lat,
        here.lng,
        _nearbyKm,
      );
      if (mounted) {
        setState(
          () =>
              _nearby = [...rows]
                ..sort((a, b) => a.distanceM.compareTo(b.distanceM)),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Community + catalogue for the current query; [more] = the next community page.
  Future<void> _loadRecipes({bool more = false}) async {
    final recipes = context.read<RecipesController>();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final (page, dishes) = await (
        recipes.community(query: _query, cursor: more ? _next : null),
        more ? Future.value(_dishes) : recipes.dishes(query: _query),
      ).wait;
      if (generation != _generation || !mounted) return;
      setState(() {
        _community = more ? [..._community, ...page.recipes] : page.recipes;
        _next = page.next;
        _dishes = dishes;
      });
    } catch (_) {
      if (generation == _generation && mounted) setState(() => _failed = true);
    } finally {
      if (generation == _generation && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _typed(String text) {
    setState(() {}); // the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = text.trim());
      _loadRecipes();
    });
  }

  List<NearbyBranch> get _restaurants {
    final q = _query.toLowerCase();
    return [
      for (final p in _nearby)
        if ((q.isEmpty ||
                p.name.toLowerCase().contains(q) ||
                (p.label?.toLowerCase().contains(q) ?? false)) &&
            (!_halal || p.halalClaim == 'says_halal') &&
            (_cuisine == null || p.cuisine?.trim() == _cuisine))
          p,
    ];
  }

  void _open(NearbyBranch place) {
    if (place.saved && place.placeId != null) {
      context.push('/places/${place.placeId}');
      return;
    }
    final places = context.read<PlacesController>();
    showNotebookSheet<void>(
      context,
      builder: (_) => NearbySheet(
        place: place,
        onEdited: _loadNearby,
        onSave: () async {
          await places.saveBranch(place.branchId);
          await _loadNearby();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    // Two rows of cards per section on "All", whatever the column count.
    final columns = _columns(MediaQuery.sizeOf(context).width);
    final preview = columns * 2;
    final restaurants = _restaurants;
    final cuisines = {
      for (final p in _nearby)
        if (p.cuisine?.trim() case final c? when c.isNotEmpty) c,
    }.toList()..sort();
    final showRestaurants = _kind != FeedKind.recipes;
    final showRecipes = _kind != FeedKind.restaurants;
    final all = _kind == FeedKind.all;
    List<T> cut<T>(List<T> list) => all ? list.take(preview).toList() : list;

    // Sections: a title (handwritten, like the book's) with "See all", then a grid of cards.
    Widget title(String label, {FeedKind? seeAll}) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: nb.hand.copyWith(fontSize: 26, height: 1, color: nb.ink),
              ),
            ),
            if (seeAll != null)
              TextButton(
                onPressed: () => setState(() => _kind = seeAll),
                child: Text(l.feedSeeAll),
              ),
          ],
        ),
      ),
    );
    Widget note(String label, {VoidCallback? onTap, IconData? icon}) =>
        SliverToBoxAdapter(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: icon == null ? null : Icon(icon, color: nb.margin),
            title: Text(label, style: TextStyle(color: nb.inkSoft)),
            onTap: onTap,
          ),
        );
    // 2 columns on a phone, more as the screen widens.
    Widget grid(List<Widget> cards) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid.count(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.74,
        children: cards,
      ),
    );

    final restaurantSlivers = [
      title(
        l.feedNearYou,
        seeAll: all && restaurants.length > preview
            ? FeedKind.restaurants
            : null,
      ),
      if (_located == false)
        note(
          l.feedLocationOff,
          onTap: _loadNearby,
          icon: Icons.location_off_outlined,
        )
      else if (_located == true && restaurants.isEmpty)
        note(l.feedNoneNear)
      else
        grid([
          for (final p in cut(restaurants))
            FeedCard(
              key: ValueKey('feed-place-${p.branchId}'),
              title: p.name,
              meta: [distanceText(p.distanceM), ?p.cuisine?.trim()].join(' · '),
              badge: p.halalClaim == 'says_halal' ? l.feedSaysHalal : null,
              icon: Icons.storefront,
              tint: nb.pandan,
              onTap: () => _open(p),
            ),
        ]),
    ];

    String byLine(Recipe r) => [
      if (r.owner?.name case final n? when !(r.owner?.isMe ?? false))
        l.recipeBy(n),
      if (r.ingredientCount > 0) l.recipeIngredientCount(r.ingredientCount),
    ].join(' · ');

    final recipeSlivers = [
      title(
        l.recipesCommunity,
        seeAll: all && (_community.length > preview || _next != null)
            ? FeedKind.recipes
            : null,
      ),
      if (_community.isEmpty && !_loading) note(l.recipesEmptyCommunity),
      grid([
        for (final r in cut(_community))
          FeedCard(
            key: ValueKey('feed-recipe-${r.id}'),
            title: r.name,
            meta: byLine(r),
            icon: Icons.menu_book,
            tint: nb.margin,
            photo: switch ((r.cover, r.shareId)) {
              (final cover?, _) => (ph) => ShareFill(
                id: cover,
                recipeId: r.id,
                fallback: ph,
              ),
              (null, final id?) => (ph) => ShareFill(id: id, fallback: ph),
              _ => null,
            },
            onTap: () => context.push('/recipes/${r.id}'),
          ),
      ]),
      if (!all && _next != null && !_loading)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton(
              onPressed: () => _loadRecipes(more: true),
              child: Text(l.recipesLoadMore),
            ),
          ),
        ),
      title(
        l.recipesCatalogue,
        seeAll: all && _dishes.length > preview ? FeedKind.recipes : null,
      ),
      if (_dishes.isEmpty && !_loading) note(l.recipesEmptyCatalogue),
      grid([
        for (final d in cut(_dishes))
          FeedCard(
            key: ValueKey('feed-dish-${d.id}'),
            title: d.name,
            meta: [
              ?d.category,
              if (d.ingredientCount > 0)
                l.recipeIngredientCount(d.ingredientCount),
            ].join(' · '),
            icon: Icons.restaurant_menu,
            tint: nb.kunyit,
            onTap: () => context.push('/recipes/${d.id}'),
          ),
      ]),
    ];

    return Scaffold(
      backgroundColor:
          nb.mist, // cards on a soft page; the ruled lines stay in the Book
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: nb.mist,
        title: NotebookTitle(l.navHome),
        actions: [
          IconButton(
            key: const ValueKey('feed-map'),
            tooltip: l.navMap,
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push('/map'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SearchBar(
                  controller: _search,
                  hintText: l.feedSearchHint,
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(nb.paper),
                  side: WidgetStatePropertyAll(BorderSide(color: nb.line)),
                  onChanged: _typed,
                  trailing: [
                    if (_search.text.isNotEmpty)
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _typed('');
                        },
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final (kind, label) in [
                      (FeedKind.all, l.feedAll),
                      (FeedKind.recipes, l.navRecipes),
                      (FeedKind.restaurants, l.feedRestaurants),
                    ])
                      ChoiceChip(
                        key: ValueKey('feed-kind-${kind.name}'),
                        label: Text(label),
                        selected: _kind == kind,
                        onSelected: (_) => setState(() => _kind = kind),
                      ),
                    if (showRestaurants) ...[
                      FilterChip(
                        key: const ValueKey('feed-halal'),
                        label: Text(l.feedSaysHalal),
                        selected: _halal,
                        onSelected: (on) => setState(() => _halal = on),
                      ),
                      if (cuisines.isNotEmpty)
                        PopupMenuButton<String?>(
                          tooltip: l.feedCuisine,
                          initialValue: _cuisine,
                          onSelected: (c) => setState(() => _cuisine = c),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: null,
                              child: Text(l.feedAnyCuisine),
                            ),
                            for (final c in cuisines)
                              PopupMenuItem(value: c, child: Text(c)),
                          ],
                          child: Chip(
                            label: Text(_cuisine ?? l.feedCuisine),
                            avatar: const Icon(Icons.arrow_drop_down),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (_failed)
              note(
                l.recipesLoadFailed2,
                onTap: _refresh,
                icon: Icons.cloud_off,
              ),
            if (showRestaurants) ...restaurantSlivers,
            if (showRecipes) ...recipeSlivers,
            SliverToBoxAdapter(
              child: _loading || _located == null
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  : const SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }
}

/// Columns for a width: 2 on a phone, one more per ~220 dp after that.
int _columns(double width) => math.max(2, (width - 32) ~/ 220);
