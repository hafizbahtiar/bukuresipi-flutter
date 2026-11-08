import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../places_controller.dart';

/// For a branch without a pin: "Find location" (the server looks again, free sources) or "Set on map" (by hand).
class UnpinnedActions extends StatefulWidget {
  const UnpinnedActions({super.key, required this.place, required this.branch});

  final Place place;
  final Branch branch;

  @override
  State<UnpinnedActions> createState() => _UnpinnedActionsState();
}

class _UnpinnedActionsState extends State<UnpinnedActions> {
  bool _finding = false;

  Future<void> _find() async {
    final l = AppLocalizations.of(context);
    // A dialog, not a snackbar: on the map this sits in a sheet that covers the snackbar, and a found branch leaves
    // the sheet's list (this widget is gone), so the answer goes on the navigator.
    final nav = Navigator.of(context);
    final pinPath = '/places/${widget.place.id}/pin/${widget.branch.id}';
    setState(() => _finding = true);
    String message;
    var offerPin = true;
    try {
      final result = await context.read<PlacesController>().locate(
        widget.branch.id,
      );
      offerPin = result != LocateResult.found;
      message = switch (result) {
        LocateResult.found => l.locationFound,
        LocateResult.triedToday => l.locationTriedToday,
        LocateResult.notFound => l.locationNotFound,
      };
    } catch (e) {
      message = errorText(l, e);
    } finally {
      if (mounted) setState(() => _finding = false);
    }
    if (!nav.mounted) return;
    final setPin = await showDialog<bool>(
      context: nav.context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          if (offerPin)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.setOnMap),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.ok),
          ),
        ],
      ),
    );
    if (setPin == true && nav.mounted) nav.context.push(pinPath);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const dense = VisualDensity(horizontal: -2, vertical: -2);
    return Wrap(
      spacing: 4,
      children: [
        TextButton.icon(
          onPressed: _finding ? null : _find,
          style: TextButton.styleFrom(
            visualDensity: dense,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: _finding
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : const Icon(Icons.travel_explore, size: 18),
          label: Text(_finding ? l.findingLocation : l.findLocation),
        ),
        TextButton.icon(
          onPressed: _finding
              ? null
              : () => context.push(
                  '/places/${widget.place.id}/pin/${widget.branch.id}',
                ),
          style: TextButton.styleFrom(
            visualDensity: dense,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
          label: Text(l.setOnMap),
        ),
      ],
    );
  }
}
