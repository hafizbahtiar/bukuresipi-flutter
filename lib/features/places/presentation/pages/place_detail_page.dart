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

/// One saved place as a notebook page; its actions (directions, save note, check branches, remove) float in a dock.
class PlaceDetailPage extends StatefulWidget {
  const PlaceDetailPage({super.key, required this.id});

  final String id;

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  final _note = TextEditingController();
  String? _savedNote; // what the server has; null until the place is shown
  bool _savingNote = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _note.addListener(
      () => setState(() {}),
    ); // Save note turns on once the text differs
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveNote(Place place) async {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _savingNote = true);
    try {
      await context.read<PlacesController>().updateNote(place.id, _note.text);
      _savedNote = _note.text;
      _snack(l.noteSaved);
    } catch (e) {
      _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _checkBranches(Place place) async {
    final l = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      final done = await context.read<PlacesController>().tidyBranches(
        place.restaurant.id,
      );
      _snack(l.branchesChecked(done.merged, done.removed));
    } catch (e) {
      _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _remove(Place place) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final places = context.read<PlacesController>();
    if (!await _confirm(context, l.removeConfirm, l.remove)) return;
    try {
      await places.remove(place.id);
      await navigator.maybePop();
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final place = context.watch<PlacesController>().byId(widget.id);
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
    if (_savedNote == null) {
      _savedNote = place.note ?? '';
      _note.text = _savedNote!;
    }
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final r = place.restaurant;
    final branch = place.savedBranch;
    // The post's branch first, then the others.
    final branches = [?branch, ...place.branches.where((b) => b != branch)];
    final dirty = _note.text.trim() != _savedNote!.trim();

    return Scaffold(
      appBar: AppBar(),
      extendBody: true,
      bottomNavigationBar: ActionDock(
        actions: [
          if (branch?.mapsUrl case final url?)
            DockAction(
              icon: Icons.directions,
              label: l.directions,
              onPressed: () => openLink(context, url, failed: l.openFailed),
            ),
          DockAction(
            icon: Icons.edit_note,
            label: l.noteSave,
            onPressed: dirty ? () => _saveNote(place) : null,
            busy: _savingNote,
          ),
          if (owner)
            DockAction(
              icon: Icons.merge_type,
              label: l.checkBranches,
              onPressed: () => _checkBranches(place),
              busy: _checking,
            ),
          DockAction(
            icon: Icons.delete_outline,
            label: l.remove,
            tooltip: l.removePlace,
            danger: true,
            onPressed: () => _remove(place),
          ),
        ],
      ),
      body: NotebookPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: ActionDock.clearance),
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
                ],
              ),
            ),
            NotebookHeading(l.branchesTitle),
            for (final b in branches)
              _BranchRow(
                place: place,
                branch: b,
                fromPost: b == branch && place.branchId != null,
                owner: owner,
              ),
            if (r.halalClaim != null && r.halalQuote != null) ...[
              NotebookHeading(l.halalTitle),
              _HalalQuote(restaurant: r),
            ],
            NotebookHeading(l.noteTitle),
            _NoteField(controller: _note),
          ],
        ),
      ),
    );
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

/// The user's own note, in handwriting on the page's lines (saved from the dock).
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: nb.rule),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(notebookGutter + 10, 0, 20, 0),
      child: TextField(
        controller: controller,
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
    );
  }
}
