import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/place.dart';
import '../places_controller.dart';

/// The Book tab: a notebook page, one saved place per line, newest first.
class PlacesListPage extends StatelessWidget {
  const PlacesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final places = context.watch<PlacesController>();
    final list = places.places;

    final List<Widget> lines;
    if (!places.loaded) {
      lines = const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (list.isEmpty && places.error != null) {
      lines = [
        _Note(text: l.placesLoadFailed),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: notebookGutter + 2),
            child: TextButton(onPressed: places.load, child: Text(l.tryAgain)),
          ),
        ),
      ];
    } else if (list.isEmpty) {
      lines = [_Note(text: l.homeEmpty)];
    } else {
      lines = [for (final p in list) PlaceTile(place: p)];
    }

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.homeTitle)),
      body: NotebookPage(
        child: RefreshIndicator(
          onRefresh: places.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: lines,
          ),
        ),
      ),
    );
  }
}

/// One saved place on its line: a mark in the margin (pinned or not), the name, then where it is.
class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final branch = place.savedBranch;
    final pinned = place.pins.isNotEmpty;
    final where = pinned ? (branch?.where ?? branch?.label) : l.noPin;
    return NotebookRow(
      mark: PinMark(pinned: pinned),
      onTap: () => context.push('/places/${place.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.restaurant.name,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (where != null && where.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                where,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: nb.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

/// A line of guidance written on the page.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 24, 24, 8),
    child: Text(
      text,
      style: Notebook.of(context).hand.copyWith(fontSize: 24, height: 1.25),
    ),
  );
}
