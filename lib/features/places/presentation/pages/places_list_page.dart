import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../domain/place.dart';
import '../places_controller.dart';

/// The Book tab: everything the user saved, newest first.
class PlacesListPage extends StatelessWidget {
  const PlacesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final places = context.watch<PlacesController>();
    final list = places.places;

    final Widget body;
    if (!places.loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (list.isEmpty && places.error != null) {
      body = _Centered(
        text: l.placesLoadFailed,
        action: TextButton(onPressed: places.load, child: Text(l.tryAgain)),
      );
    } else if (list.isEmpty) {
      body = _Centered(text: l.homeEmpty, icon: Icons.ios_share);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) => PlaceTile(place: list[i]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: const [AccountButton()],
      ),
      body: RefreshIndicator(
        onRefresh: places.load,
        // A scrollable child even when empty, so pull-to-refresh works there too.
        child: body is ListView
            ? body
            : LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(height: box.maxHeight, child: body),
                ),
              ),
      ),
    );
  }
}

class PlaceTile extends StatelessWidget {
  const PlaceTile({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final branch = place.savedBranch;
    final pinned = place.pins.isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: pinned
            ? c.primaryContainer
            : c.surfaceContainerHighest,
        child: Icon(
          pinned ? Icons.restaurant : Icons.location_off_outlined,
          color: pinned ? c.onPrimaryContainer : c.onSurfaceVariant,
        ),
      ),
      title: Text(
        place.restaurant.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        pinned ? (branch?.where ?? branch?.label ?? '') : l.noPin,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/places/${place.id}'),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, this.icon, this.action});

  final String text;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    ),
  );
}
