import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import '../widgets/unpinned_actions.dart';

class PlaceDetailPage extends StatelessWidget {
  const PlaceDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final place = context.watch<PlacesController>().byId(id);
    final owner = context.select<AuthController, bool>(
      (a) => a.user?.isOwner ?? false,
    );
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
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final r = place.restaurant;
    final branch = place.savedBranch;
    // The post's branch first, then the others.
    final branches = [?branch, ...place.branches.where((b) => b != branch)];

    return Scaffold(
      appBar: AppBar(),
      body: NotebookPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (r.cuisine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        r.cuisine!,
                        style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                      ),
                    ),
                  if (branch?.hasPin ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: FilledButton.tonalIcon(
                        onPressed: () => openLink(
                          context,
                          _mapsUrl(branch!),
                          failed: l.openFailed,
                        ),
                        icon: const Icon(Icons.directions),
                        label: Text(l.directions),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _Heading(l.branchesTitle),
            for (final b in branches)
              _BranchRow(
                place: place,
                branch: b,
                fromPost: b == branch && place.branchId != null,
                owner: owner,
              ),
            if (r.halalClaim != null && r.halalQuote != null) ...[
              _Heading(l.halalTitle),
              _HalalQuote(restaurant: r),
            ],
            _Heading(l.noteTitle),
            _NoteEditor(place: place),
            Padding(
              padding: const EdgeInsets.fromLTRB(notebookGutter + 2, 28, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _remove(context, place),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.removePlace),
                  style: TextButton.styleFrom(foregroundColor: nb.margin),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Google Maps search by coordinates (opens the Maps app when installed).
  static String _mapsUrl(Branch b) => Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': '${b.lat},${b.lng}'},
  ).toString();

  Future<void> _remove(BuildContext context, Place place) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final places = context.read<PlacesController>();
    final yes = await _confirm(context, l.removeConfirm, l.remove);
    if (!yes) return;
    try {
      await places.remove(place.id);
      await navigator.maybePop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }
}

Future<bool> _confirm(
  BuildContext context,
  String question,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 28, 20, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.place,
    required this.branch,
    required this.fromPost,
    required this.owner,
  });

  final Place place;
  final Branch branch;
  final bool fromPost;
  final bool owner;

  Future<void> _delete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final places = context.read<PlacesController>();
    if (!await _confirm(
      context,
      l.deleteBranchConfirm(branch.label ?? branch.where ?? ''),
      l.delete,
    )) {
      return;
    }
    try {
      await places.deleteBranch(branch.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final notes = [
      ?branch.where,
      if (!branch.hasPin) l.noPin,
      if (branch.pinnedByUser) l.pinnedByUser,
      if (fromPost) l.fromYourPost,
    ];
    return NotebookRow(
      mark: PinMark(pinned: branch.hasPin),
      trailing: owner
          ? IconButton(
              tooltip: l.deleteBranch,
              icon: Icon(Icons.delete_outline, color: nb.inkSoft),
              onPressed: () => _delete(context),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.label ?? branch.where ?? '-',
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          for (final n in notes)
            Text(n, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
          if (!branch.hasPin)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: UnpinnedActions(place: place, branch: branch),
            ),
        ],
      ),
    );
  }
}

/// What a post said, quoted like a clipping, with its link. Never a badge: it is a claim, not a certification.
class _HalalQuote extends StatelessWidget {
  const _HalalQuote({required this.restaurant});

  final PlaceRestaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(notebookGutter + 10, 2, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: nb.kunyit, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(l.halalSource),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          Text(
            l.halalNotCert,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// The user's own note, in handwriting on the page's lines.
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
    final nb = Notebook.of(context);
    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: nb.rule),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _note,
            maxLength: 500,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: nb.hand.copyWith(fontSize: 24, height: 1.3, color: nb.ink),
            decoration: InputDecoration(
              hintText: l.noteHint,
              hintStyle: nb.hand.copyWith(
                fontSize: 22,
                color: nb.inkSoft.withValues(alpha: 0.6),
              ),
              filled: false,
              border: underline,
              enabledBorder: underline,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: nb.pandan, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text(l.noteSave),
            ),
          ),
        ],
      ),
    );
  }
}
