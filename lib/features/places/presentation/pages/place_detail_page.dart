import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../places_controller.dart';

class PlaceDetailPage extends StatelessWidget {
  const PlaceDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final place = context.watch<PlacesController>().byId(id);
    if (place == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(l.placeGone),
          ),
        ),
      );
    }
    final text = Theme.of(context).textTheme;
    final r = place.restaurant;
    final branch = place.savedBranch;
    // The post's branch first, then the others.
    final branches = [?branch, ...place.branches.where((b) => b != branch)];

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            r.name,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (r.cuisine != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(r.cuisine!, style: text.bodyMedium),
            ),
          const SizedBox(height: 16),
          if (branch?.hasPin ?? false)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => openLink(
                  context,
                  _mapsUrl(r.name, branch!),
                  failed: l.openFailed,
                ),
                icon: const Icon(Icons.directions),
                label: Text(l.directions),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ),
          const SizedBox(height: 24),
          Text(l.branchesTitle, style: text.titleMedium),
          for (final b in branches)
            _BranchTile(
              branch: b,
              fromPost: b == branch && place.branchId != null,
            ),
          if (r.halalClaim != null && r.halalQuote != null) ...[
            const SizedBox(height: 24),
            _HalalQuote(restaurant: r),
          ],
          const SizedBox(height: 24),
          _NoteEditor(place: place),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _remove(context, place),
              icon: const Icon(Icons.delete_outline),
              label: Text(l.removePlace),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Google Maps search by coordinates (opens the Maps app when installed).
  static String _mapsUrl(String name, Branch b) => Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': '${b.lat},${b.lng}'},
  ).toString();

  Future<void> _remove(BuildContext context, Place place) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final places = context.read<PlacesController>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.removeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await places.remove(place.id);
      await navigator.maybePop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({required this.branch, required this.fromPost});

  final Branch branch;
  final bool fromPost;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final lines = [
      if (branch.where != null) branch.where!,
      if (!branch.hasPin) l.noPin,
      if (fromPost) l.fromYourPost,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        branch.hasPin ? Icons.place_outlined : Icons.location_off_outlined,
        color: branch.hasPin ? c.primary : c.outline,
      ),
      title: Text(branch.label ?? branch.where ?? '-'),
      subtitle: lines.isEmpty ? null : Text(lines.join('\n')),
    );
  }
}

/// What a post said, quoted, with the link. Never a badge: it is a claim, not a certification.
class _HalalQuote extends StatelessWidget {
  const _HalalQuote({required this.restaurant});

  final PlaceRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.halalTitle, style: text.titleSmall),
          const SizedBox(height: 8),
          Text(
            '“${restaurant.halalQuote}”',
            style: text.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
          ),
          if (restaurant.halalSourceUrl != null)
            TextButton.icon(
              onPressed: () => openLink(
                context,
                restaurant.halalSourceUrl!,
                failed: l.openFailed,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l.halalSource),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          Text(
            l.halalNotCert,
            style: text.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({required this.place});

  final Place place;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _note = TextEditingController(text: widget.place.note ?? '');
  bool _saving = false;

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await context.read<PlacesController>().updateNote(
        widget.place.id,
        _note.text,
      );
      messenger.showSnackBar(SnackBar(content: Text(l.noteSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.noteTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l.noteHint),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l.noteSave),
          ),
        ),
      ],
    );
  }
}
