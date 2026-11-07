import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/place.dart';

/// Pinned branches of [places] whose restaurant name, branch label or address contains [query] (case-insensitive).
/// shortcut: the user's own book only, filtered on the phone; other restaurants need GET /places/search (IDEA.md).
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

/// The map's search: the user's saved places that have a pin. Picking one returns it (the map flies there).
class MapSearch extends SearchDelegate<(Place, Branch)?> {
  MapSearch(this.places, AppLocalizations l)
    : _none = l.mapSearchNone,
      super(searchFieldLabel: l.mapSearchHint);

  final List<Place> places;
  final String _none;

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
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final hits = searchPins(places, query);
    if (query.trim().isNotEmpty && hits.isEmpty) {
      return Padding(padding: const EdgeInsets.all(24), child: Text(_none));
    }
    return ListView(
      children: [
        for (final (p, b) in hits)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(p.restaurant.name),
            subtitle: switch (b.label ?? b.where) {
              final s? => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis),
              null => null,
            },
            onTap: () => close(context, (p, b)),
          ),
      ],
    );
  }
}
