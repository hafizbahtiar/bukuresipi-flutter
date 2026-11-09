import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/nearby_branch.dart';
import '../../domain/place.dart';

/// Pinned branches of [places] whose restaurant name, branch label or address contains [query] (case-insensitive).
List<(Place, Branch)> searchPins(List<Place> places, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  bool hit(String? s) => s?.toLowerCase().contains(q) ?? false;
  return [
    for (final p in places)
      for (final b in p.pins)
        if (hit(p.restaurant.name) || hit(b.label) || hit(b.where)) (p, b),
  ];
}

/// Server search: (query, submit) -> places near the map's centre.
typedef PlaceSearch = Future<List<PlaceHit>> Function(
  String query, {
  required bool submit,
});

/// The map's search. Your saved places first (on the phone), then other places from the server: while typing, what
/// the app already knows; on Search, also OpenStreetMap when that is little. Picking returns a (Place, Branch) of
/// yours or a [PlaceHit]; the map flies there.
class MapSearch extends SearchDelegate<Object?> {
  MapSearch(this.places, this.search, this.l)
    : super(searchFieldLabel: l.mapSearchHint);

  final List<Place> places;
  final PlaceSearch search;
  final AppLocalizations l;

  // One request per query and kind, kept across rebuilds.
  final _asked = <(String, bool), Future<List<PlaceHit>>>{};

  Future<List<PlaceHit>> _ask(String q, bool submit) => _asked[(q, submit)] ??=
      // Typing: wait for a pause, and drop the request if the query moved on.
      Future<void>.delayed(Duration(milliseconds: submit ? 0 : 300)).then(
        (_) => q != query.trim()
            ? const <PlaceHit>[]
            : search(q, submit: submit).catchError((Object _) {
                _asked.remove((q, submit)); // tried again next time
                return const <PlaceHit>[];
              }),
      );

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => const BackButton();

  @override
  Widget buildResults(BuildContext context) => _list(context, submit: true);

  @override
  Widget buildSuggestions(BuildContext context) =>
      _list(context, submit: false);

  Widget _list(BuildContext context, {required bool submit}) {
    final q = query.trim();
    final mine = searchPins(places, q);
    final myBranches = {for (final (_, b) in mine) b.id};
    final ask = q.length >= 2 ? _ask(q, submit) : null;
    return FutureBuilder<List<PlaceHit>>(
      future: ask,
      builder: (context, s) {
        final others = [
          for (final h in s.data ?? const <PlaceHit>[])
            if (!myBranches.contains(h.branchId)) h,
        ];
        final waiting =
            ask != null && s.connectionState != ConnectionState.done;
        return ListView(
          children: [
            for (final (p, b) in mine)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(p.restaurant.name),
                subtitle: switch (b.label ?? b.where) {
                  final s? => Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  null => null,
                },
                onTap: () => close(context, (p, b)),
              ),
            for (final h in others)
              ListTile(
                key: ValueKey('search-hit-${h.branchId ?? h.poiId}'),
                leading: const Icon(Icons.place_outlined),
                title: Text(h.name),
                subtitle: Text(
                  [distanceText(h.distanceM), ?h.address].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => close(context, h),
              ),
            if (waiting)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (q.isNotEmpty && mine.isEmpty && others.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(submit ? l.mapSearchNone : l.mapSearchPress),
              ),
          ],
        );
      },
    );
  }
}
