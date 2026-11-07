import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notebook.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../places/domain/nearby_branch.dart';
import '../../places/domain/rating.dart';
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

/// The Home tab: one grid of cards, like a marketplace. Recipes (community, then catalogue dishes) load a page at a
/// time as you scroll; every 4th card is a restaurant near the phone (GET /places/nearby, nearest first) with a
/// "Near me" tag and its distance. One search box with suggestions; filters for kind, "says halal" and cuisine.
/// Restaurants are filtered on the phone (the nearby list is at most 100), recipes on the server.
class FeedPage extends StatefulWidget {
  const FeedPage({super.key, this.locate = _phone});

  final Locate locate;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const _nearbyKm = 5.0; // as the map
  static const _every = 4; // a restaurant in every 4th slot

  final _search = SearchController();
  final _scroll = ScrollController();
  String _query = '';
  FeedKind _kind = FeedKind.all;
  bool _halal = false;
  String? _cuisine;

  bool? _located; // null = asking
  List<NearbyBranch> _nearby = const [];

  // Recipes: community pages first, then catalogue pages.
  List<Recipe> _community = const [];
  List<Dish> _dishes = const [];
  String? _cursor;
  bool _inDishes = false;
  bool _done = false;
  bool _busy = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([_loadNearby(), _restart()]);

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

  /// From the first page, for the current query.
  Future<void> _restart() {
    _generation++;
    setState(() {
      _community = const [];
      _dishes = const [];
      _cursor = null;
      _inDishes = false;
      _done = false;
      _busy = false;
      _failed = false;
    });
    return _more();
  }

  /// The next page: community until its last, then the catalogue.
  Future<void> _more() async {
    if (_busy || _done) return;
    final recipes = context.read<RecipesController>();
    final generation = _generation;
    setState(() => _busy = true);
    try {
      final q = _query.isEmpty ? null : _query;
      if (!_inDishes) {
        final page = await recipes.community(query: q, cursor: _cursor);
        if (generation != _generation || !mounted) return;
        setState(() {
          _community = [..._community, ...page.recipes];
          _cursor = page.next;
          _inDishes = page.next == null;
        });
      } else {
        final page = await recipes.dishes(query: q, cursor: _cursor);
        if (generation != _generation || !mounted) return;
        setState(() {
          _dishes = [..._dishes, ...page.dishes];
          _cursor = page.next;
          _done = page.next == null;
        });
      }
    } catch (_) {
      if (generation == _generation && mounted) setState(() => _failed = true);
      return;
    } finally {
      if (generation == _generation && mounted) setState(() => _busy = false);
    }
    // A short page leaves the screen unfilled, so no scroll asks for more: ask now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients && _scroll.position.extentAfter < 800) {
        _more();
      }
    });
  }

  void _submit(String text) {
    if (_search.isOpen) _search.closeView(text);
    if (text.trim() == _query) return;
    setState(() => _query = text.trim());
    _restart();
  }

  bool _matches(NearbyBranch p, String q) =>
      p.name.toLowerCase().contains(q) ||
      (p.label?.toLowerCase().contains(q) ?? false);

  List<NearbyBranch> get _restaurants {
    final q = _query.toLowerCase();
    return [
      for (final p in _nearby)
        if ((q.isEmpty || _matches(p, q)) &&
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

  /// Suggestions as you type: nearby restaurants (on the phone), then recipes and dishes (one small server page
  /// each, after a pause in typing), then "Search 'text'".
  Future<Iterable<Widget>> _suggest(
    BuildContext context,
    SearchController c,
  ) async {
    final l = AppLocalizations.of(context);
    final text = c.text.trim();
    final q = text.toLowerCase();
    final recipes = context.read<RecipesController>();
    final tiles = <Widget>[
      if (q.isNotEmpty)
        for (final p in _nearby.where((p) => _matches(p, q)).take(3))
          ListTile(
            leading: const Icon(Icons.storefront),
            title: Text(p.name),
            subtitle: Text(distanceText(p.distanceM)),
            onTap: () {
              c.closeView(c.text);
              _open(p);
            },
          ),
    ];
    if (text.length >= 2) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (c.text.trim() != text) {
        return tiles; // typed on: the newer call answers
      }
      try {
        final (community, dishes) = await (
          recipes.community(query: text, limit: 5),
          recipes.dishes(query: text, limit: 5),
        ).wait;
        for (final (id, name, icon) in [
          for (final r in community.recipes) (r.id, r.name, Icons.menu_book),
          for (final d in dishes.dishes) (d.id, d.name, Icons.restaurant_menu),
        ]) {
          tiles.add(
            ListTile(
              leading: Icon(icon),
              title: Text(name),
              onTap: () {
                c.closeView(c.text);
                if (mounted) this.context.push('/recipes/$id');
              },
            ),
          );
        }
      } catch (_) {} // suggestions are a help; the search itself still works
    }
    if (text.isNotEmpty) {
      tiles.add(
        ListTile(
          key: const ValueKey('feed-search-for'),
          leading: const Icon(Icons.search),
          title: Text(l.feedSearchFor(text)),
          onTap: () => _submit(text),
        ),
      );
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = _columns(width);
    final cardHeight = FeedCard.heightFor(
      (width - 32 - 12 * (columns - 1)) / columns,
      MediaQuery.textScalerOf(context),
    );
    final cuisines = {
      for (final p in _nearby)
        if (p.cuisine?.trim() case final c? when c.isNotEmpty) c,
    }.toList()..sort();
    final showRestaurants = _kind != FeedKind.recipes;
    final showRecipes = _kind != FeedKind.restaurants;

    Widget place(NearbyBranch p) => FeedCard(
      key: ValueKey('feed-place-${p.branchId}'),
      kind: l.feedKindRestaurant,
      title: p.name,
      subtitle: p.cuisine?.trim() ?? p.label,
      facts: [
        if (p.rating case RatingSummary(:final average?, :final count)
            when count > 0)
          FeedFact(
            Icons.star_rounded,
            '${average.toStringAsFixed(1)} ($count)',
            strong: true,
          ),
        // A quoted claim from the post, never "certified": the words stay "Says halal".
        if (p.halalClaim == 'says_halal')
          FeedFact(Icons.format_quote_rounded, l.feedSaysHalal, strong: true),
      ],
      tag: '${l.feedNearMe} · ${distanceText(p.distanceM)}',
      tagIcon: Icons.near_me,
      icon: Icons.storefront_outlined,
      photo: switch (p.cover) {
        final cover? => (ph) => ShareFill(
          id: cover,
          restaurantId: p.restaurantId,
          fallback: ph,
        ),
        null => null,
      },
      onTap: () => _open(p),
    );
    Widget recipe(Recipe r) => FeedCard(
      key: ValueKey('feed-recipe-${r.id}'),
      kind: l.feedKindRecipe,
      title: r.name,
      subtitle: switch (r.owner) {
        RecipeOwner(:final name?, isMe: false) => l.recipeBy(name),
        _ => null,
      },
      facts: [
        if (r.ingredientCount > 0)
          FeedFact(
            Icons.format_list_bulleted,
            l.recipeIngredientCount(r.ingredientCount),
          ),
      ],
      icon: Icons.menu_book_outlined,
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
    );
    Widget dish(Dish d) => FeedCard(
      key: ValueKey('feed-dish-${d.id}'),
      kind: l.feedKindDish,
      title: d.name,
      subtitle: d.category,
      facts: [
        if (d.ingredientCount > 0)
          FeedFact(
            Icons.format_list_bulleted,
            l.recipeIngredientCount(d.ingredientCount),
          ),
      ],
      icon: Icons.restaurant_menu,
      onTap: () => context.push('/recipes/${d.id}'),
    );

    final restaurants = showRestaurants ? _restaurants : const <NearbyBranch>[];
    final stream = showRecipes
        ? [..._community.map(recipe), ..._dishes.map(dish)]
        : const <Widget>[];
    final cards = <Widget>[];
    var next = 0;
    for (final card in stream) {
      if (cards.length % _every == _every - 1 && next < restaurants.length) {
        cards.add(place(restaurants[next++]));
      }
      cards.add(card);
    }
    // Recipes all shown (or not wanted): the rest of the restaurants follow.
    if (_done || !showRecipes) {
      cards.addAll(restaurants.skip(next).map(place));
    }
    final loading = (_busy && showRecipes) || _located == null;

    Widget note(String label, {VoidCallback? onTap, IconData? icon}) =>
        SliverToBoxAdapter(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: icon == null ? null : Icon(icon, color: nb.margin),
            title: Text(label, style: TextStyle(color: nb.inkSoft)),
            onTap: onTap,
          ),
        );

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
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 800) _more();
            return false;
          },
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SearchAnchor(
                    searchController: _search,
                    viewHintText: l.feedSearchHint,
                    viewOnSubmitted: _submit,
                    suggestionsBuilder: _suggest,
                    builder: (context, c) => SearchBar(
                      key: const ValueKey('feed-search'),
                      controller: c,
                      hintText: l.feedSearchHint,
                      leading: const Icon(Icons.search),
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(nb.paper),
                      side: WidgetStatePropertyAll(BorderSide(color: nb.line)),
                      onTap: c.openView,
                      onChanged: (_) => c.openView(),
                      trailing: [
                        if (_query.isNotEmpty)
                          IconButton(
                            tooltip: MaterialLocalizations.of(context)
                                .deleteButtonTooltip,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              c.clear();
                              _submit('');
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              if (showRestaurants && _located == false)
                note(
                  l.feedLocationOff,
                  onTap: _loadNearby,
                  icon: Icons.location_off_outlined,
                ),
              if (cards.isEmpty && !loading && !_failed) note(l.feedNothing),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // A fixed height for the card's width, so every row lines up whatever the text.
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: cardHeight,
                  ),
                  delegate: SliverChildListDelegate(cards),
                ),
              ),
              SliverToBoxAdapter(
                child: loading
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
      ),
    );
  }
}

/// Columns for a width: 2 on a phone, one more per ~220 dp after that.
int _columns(double width) => math.max(2, (width - 32) ~/ 220);
