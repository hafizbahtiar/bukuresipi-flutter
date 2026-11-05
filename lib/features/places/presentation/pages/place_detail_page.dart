import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../family/presentation/family_controller.dart';
import '../../../shares/presentation/widgets/share_image.dart';
import '../../domain/place.dart';
import '../../domain/report.dart';
import '../places_controller.dart';
import '../widgets/branch_edit_sheet.dart';
import '../widgets/notebook_rating.dart';
import '../widgets/place_report_sheet.dart';
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

  // Called after awaits: the page may be gone by then.
  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

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

  /// A family member's place: the caller's own save of it (then note, Only me, rating are theirs).
  Future<void> _saveToMine(Place place) async {
    final l = AppLocalizations.of(context);
    final branch = place.savedBranch;
    if (branch == null) return;
    final router = GoRouter.of(context);
    try {
      final saved = await context.read<PlacesController>().saveBranch(branch.id);
      _snack(l.placeSavedToMine);
      router.replace('/places/${saved.id}');
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  Future<void> _setPrivate(Place place, bool private) async {
    final l = AppLocalizations.of(context);
    try {
      await context.read<PlacesController>().setPrivate(place.id, private);
    } catch (e) {
      _snack(errorText(l, e));
    }
  }

  Future<void> _report(Place place) => showNotebookSheet<void>(
    context,
    builder: (_) => PlaceReportSheet(
      subject: ReportSubject.fromPlace(place),
      onSubmit: (draft) => context.read<PlacesController>().report(draft),
    ),
  );

  Future<void> _remove(Place place) async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final places = context.read<PlacesController>();
    final hasRating = place.branches.any((b) => b.rating.mine != null);
    final question = hasRating
        ? '${l.removeConfirm}\n\n${l.removePlaceWithRatings}'
        : l.removeConfirm;
    if (!await _confirm(context, question, l.remove)) return;
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
    final inFamily = context.watch<FamilyController?>()?.inFamily ?? false;
    final savers = [
      for (final s in place.savedBy) s.isMe ? l.savedByYou : (s.name ?? '?'),
    ];

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
          if (place.mine)
            DockAction(
              icon: Icons.edit_note,
              label: l.noteSave,
              onPressed: dirty ? () => _saveNote(place) : null,
              busy: _savingNote,
            )
          else if (place.savedBranch != null)
            DockAction(
              icon: Icons.bookmark_add_outlined,
              label: l.placeSaveToMine,
              onPressed: () => _saveToMine(place),
            ),
          if (owner)
            DockAction(
              icon: Icons.merge_type,
              label: l.checkBranches,
              onPressed: () => _checkBranches(place),
              busy: _checking,
            ),
          DockAction(
            icon: Icons.flag_outlined,
            label: l.report,
            onPressed: () => _report(place),
          ),
          // Unsave removes only the caller's own save; a family member's stays theirs.
          if (place.mine)
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
        // Builder: bottomRoom needs the body's context (it holds the keyboard + dock height).
        child: Builder(
          builder: (context) => ListView(
            padding: EdgeInsets.only(bottom: ActionDock.bottomRoom(context)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  notebookGutter + 10,
                  4,
                  20,
                  0,
                ),
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
                    if (place.shareId case final id?) ShareImage(id),
                    if (place.sourceUrl case final url?)
                      TextButton.icon(
                        onPressed: () =>
                            openLink(context, url, failed: l.openFailed),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(l.openYourPost),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
              if (savers.length > 1 || !place.mine)
                NotebookRow(
                  mark: Icon(Icons.people_outline, size: 20, color: nb.inkSoft),
                  child: Text(l.placeSavedBy(savers.join(', '))),
                ),
              if (place.mine && inFamily)
                NotebookRow(
                  mark: Icon(Icons.lock_outline, size: 20, color: nb.inkSoft),
                  onTap: () => _setPrivate(place, !place.private),
                  trailing: Switch(value: place.private, onChanged: (v) => _setPrivate(place, v)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.placeOnlyMe),
                      Text(l.placeOnlyMeHint, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
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
              if (place.mine) ...[
                NotebookHeading(l.noteTitle),
                _NoteField(controller: _note),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Removing or deleting: the red dialog.
Future<bool> _confirm(BuildContext context, String question, String action) =>
    showNotebookDialog(
      context,
      message: question,
      tone: DialogTone.danger,
      confirmLabel: action,
    );

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

  Future<void> _edit(BuildContext context) => showNotebookSheet<void>(
    context,
    builder: (_) => BranchEditSheet(
      placeId: place.id,
      branch: branch,
      canEditShared: owner,
      onSuggest: owner
          ? () => context.read<PlacesController>().suggestBranch(branch.id)
          : null,
      onSave: (edit, scope) => context.read<PlacesController>().updateBranch(
        branch.id,
        label: edit.label,
        address: edit.address,
        city: edit.city,
        state: edit.state,
        lat: edit.lat,
        lng: edit.lng,
        scope: scope,
      ),
    ),
  );

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
      if (branch.pinnedByOwner) l.pinnedByOwner,
      if (fromPost) l.fromYourPost,
    ];
    return NotebookRow(
      mark: PinMark(pinned: branch.hasPin),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.editBranch,
            icon: Icon(Icons.edit_outlined, color: nb.inkSoft),
            onPressed: () => _edit(context),
          ),
          if (owner)
            IconButton(
              tooltip: l.deleteBranch,
              icon: Icon(Icons.delete_outline, color: nb.inkSoft),
              onPressed: () => _delete(context),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.label ?? branch.where ?? '-',
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          for (final n in notes)
            Text(n, style: text.bodySmall?.copyWith(color: nb.inkSoft)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: RatingLine(
              rating: branch.rating,
              onTap: () => context.push('/branches/${branch.id}/reviews'),
            ),
          ),
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
        // Scroll the note above the dock and keyboard, not just into the body (which runs under them). Flutter
        // reveals the caret's line; + 60 keeps the line under it and the 500 counter in sight too.
        scrollPadding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          ActionDock.bottomRoom(context) + 60,
        ),
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
