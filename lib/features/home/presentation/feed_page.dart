import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notebook.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../places/domain/nearby_branch.dart';
import '../../places/presentation/location.dart';
import '../../places/presentation/places_controller.dart';
import '../../places/presentation/widgets/nearby_carousel.dart';
import '../../places/presentation/widgets/nearby_sheet.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipes_controller.dart';
import '../../recipes/presentation/widgets/recipe_rows.dart';

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
  static const _preview = 3; // rows per section on "All"

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
    final restaurants = _restaurants;
    final cuisines = {
      for (final p in _nearby)
        if (p.cuisine?.trim() case final c? when c.isNotEmpty) c,
    }.toList()..sort();
    final showRestaurants = _kind != FeedKind.recipes;
    final showRecipes = _kind != FeedKind.restaurants;
    final all = _kind == FeedKind.all;
    List<T> cut<T>(List<T> list) => all ? list.take(_preview).toList() : list;

    Widget note(String text, {VoidCallback? onTap}) => NotebookRow(
      onTap: onTap,
      child: Text(text, style: TextStyle(color: nb.inkSoft)),
    );
    Widget seeAll(FeedKind kind) => Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => setState(() => _kind = kind),
        child: Text(l.feedSeeAll),
      ),
    );

    final restaurantRows = <Widget>[
      NotebookHeading(l.feedNearYou),
      if (_located == false)
        NotebookRow(
          mark: Icon(Icons.location_off_outlined, size: 20, color: nb.margin),
          onTap: _loadNearby,
          child: Text(l.feedLocationOff),
        )
      else if (_located == true && restaurants.isEmpty)
        note(l.feedNoneNear)
      else
        for (final p in cut(restaurants))
          Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 4, 4, 12, 4),
            child: NearbyCard(place: p, onTap: () => _open(p)),
          ),
      if (all && restaurants.length > _preview) seeAll(FeedKind.restaurants),
    ];

    final recipeRows = <Widget>[
      NotebookHeading(l.recipesCommunity),
      if (_community.isEmpty && !_loading) note(l.recipesEmptyCommunity),
      for (final r in cut(_community)) RecipeRow(recipe: r),
      if (!all && _next != null && !_loading)
        note(l.recipesLoadMore, onTap: () => _loadRecipes(more: true)),
      if (all && (_community.length > _preview || _next != null))
        seeAll(FeedKind.recipes),
      NotebookHeading(l.recipesCatalogue),
      if (_dishes.isEmpty && !_loading) note(l.recipesEmptyCatalogue),
      for (final d in cut(_dishes)) DishRow(dish: d),
      if (all && _dishes.length > _preview) seeAll(FeedKind.recipes),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
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
      body: NotebookPage(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              NotebookRow(
                mark: Icon(Icons.search, size: 20, color: nb.inkSoft),
                trailing: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .deleteButtonTooltip,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          _typed('');
                        },
                      ),
                child: TextField(
                  controller: _search,
                  onChanged: _typed,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.feedSearchHint,
                    border: InputBorder.none,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  notebookGutter + 4,
                  4,
                  12,
                  4,
                ),
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
              if (_failed)
                NotebookRow(
                  mark: Icon(Icons.cloud_off, size: 20, color: nb.margin),
                  onTap: _refresh,
                  child: Text(l.recipesLoadFailed2),
                ),
              if (showRestaurants) ...restaurantRows,
              if (showRecipes) ...recipeRows,
              if (_loading || _located == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
