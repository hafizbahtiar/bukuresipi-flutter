import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/cover_app_bar.dart';
import '../../../../core/widgets/notebook_dialog.dart' show DialogTone;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../family/presentation/family_controller.dart';
import '../../../shares/presentation/widgets/share_image.dart';
import '../../domain/place.dart';
import '../../domain/report.dart';
import '../places_controller.dart';
import '../widgets/halal_status.dart';
import 'branch_page.dart';
import 'place_edit_page.dart';
import '../widgets/cover_picker_sheet.dart';
import '../widgets/notebook_rating.dart';
import '../widgets/place_category.dart';
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
      final saved = await context.read<PlacesController>().saveBranch(
        branch.id,
      );
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

  Future<void> _report(Place place) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
    final halal = r.halalClaim != null && r.halalQuote != null;

    void pickCover() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CoverPickerSheet(placeId: r.id),
    );
    // Go there first, then keep it (save, note), then the owner's tools, then report; remove last, set apart.
    final more = MoreMenu(
      actions: [
        if (branch?.mapsUrl case final url?)
          MenuAction(
            icon: Icons.directions,
            label: l.directions,
            onTap: () => openLink(context, url, failed: l.openFailed),
          ),
        if (branch case Branch(hasPin: true, :final lat?, :final lng?))
          MenuAction(
            icon: Icons.map_outlined,
            label: l.navMap,
            onTap: () => context.push('/map?lat=$lat&lng=$lng'),
          ),
        if (place.sourceUrl case final url?)
          MenuAction(
            icon: Icons.open_in_new,
            label: l.openYourPost,
            onTap: () => openLink(context, url, failed: l.openFailed),
          ),
        if (!place.mine && place.savedBranch != null)
          MenuAction(
            icon: Icons.bookmark_add_outlined,
            label: l.placeSaveToMine,
            onTap: () => _saveToMine(place),
          ),
        if (owner) ...[
          MenuAction(
            icon: Icons.edit_outlined,
            label: l.placeEdit,
            onTap: () => PlaceEditPage.open(context, r),
          ),
          MenuAction(
            icon: Icons.image_outlined,
            label: l.coverTitle,
            onTap: pickCover,
          ),
          MenuAction(
            icon: Icons.merge_type,
            label: l.checkBranches,
            onTap: _checking ? null : () => _checkBranches(place),
          ),
        ],
        MenuAction(
          icon: Icons.flag_outlined,
          label: l.report,
          onTap: () => _report(place),
        ),
        // Unsave removes only the caller's own save; a family member's stays theirs.
        if (place.mine)
          MenuAction(
            icon: Icons.delete_outline,
            label: l.removePlace,
            danger: true,
            onTap: () => _remove(place),
          ),
      ],
    );

    // The cover the owner picked, else the post's picture, else a short banner (the owner can add a cover there).
    final photoId = r.cover ?? place.shareId;
    final coverBar = CoverAppBar(
      photo: photoId == null
          ? _NoPhoto(onAdd: owner ? pickCover : null)
          : ShareFill(
              key: ValueKey('place-cover-$photoId'),
              id: photoId,
              placeId: r.cover == null ? null : r.id,
              fallback: ColoredBox(color: nb.mist),
            ),
      height: photoId == null ? 140 : null,
      title: r.name,
      actions: [more],
    );
    final header = SliverList.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, spaceM, spaceM, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name, style: nb.hand.copyWith(fontSize: 34, height: 1.05)),
              // "Mamak · Thai": the most specific kind known, then (food) its cuisine.
              Padding(
                padding: const EdgeInsets.only(top: spaceXs),
                child: Row(
                  key: const ValueKey('place-category-line'),
                  children: [
                    Icon(
                      placeCategoryIcon(r.category, r.subcategory),
                      size: 18,
                      color: nb.inkSoft,
                    ),
                    const SizedBox(width: spaceXs + 2),
                    Expanded(
                      child: Text(
                        [
                          if (r.subcategory case final s?)
                            placeSubcategoryLabel(l, s)
                          else
                            placeCategoryLabel(l, r.category),
                          if (r.isFood) ?r.cuisine,
                        ].join(' · '),
                        style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),
              // Halal is a food claim: a shop or a park has none to show.
              if (r.isFood)
                HalalStatus(claim: r.halalQuote == null ? null : r.halalClaim),
            ],
          ),
        ),
        if (savers.length > 1 || !place.mine)
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(l.placeSavedBy(savers.join(', '))),
          ),
        if (place.mine && inFamily)
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: Text(l.placeOnlyMe),
            subtitle: Text(l.placeOnlyMeHint),
            value: place.private,
            onChanged: (v) => _setPrivate(place, v),
          ),
      ],
    );

    return Scaffold(
      body: GestureDetector(
        // A tap off the note closes the keyboard.
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: DetailTabs(
          coverBar: coverBar,
          header: header,
          sections: [
            if (branches.isNotEmpty)
              DetailSection(
                id: 'place-tab-branches',
                label: '${l.branchesTitle} (${branches.length})',
                rows: [
                  for (final b in branches) ...[
                    _BranchRow(
                      place: place,
                      branch: b,
                      fromPost: b == branch && place.branchId != null,
                      owner: owner,
                    ),
                  ],
                ],
              ),
            if (halal)
              DetailSection(
                id: 'place-tab-halal',
                label: l.placeTabHalal,
                rows: [
                  SectionHeader(l.halalTitle),
                  _HalalQuote(restaurant: r),
                ],
              ),
            if (place.mine)
              DetailSection(
                id: 'place-tab-note',
                label: l.noteTitle,
                rows: [
                  SectionHeader(l.noteTitle),
                  _NoteField(
                    controller: _note,
                    saving: _savingNote,
                    onSave: dirty ? () => _saveNote(place) : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The header with no photo: a tinted banner with a shop mark; the owner gets "Add cover photo" on it.
class _NoPhoto extends StatelessWidget {
  const _NoPhoto({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return ColoredBox(
      color: nb.mist,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: onAdd == null
              ? Icon(
                  Icons.storefront_outlined,
                  size: 48,
                  color: nb.pandan.withValues(alpha: 0.5),
                )
              : TextButton.icon(
                  key: const ValueKey('place-add-cover'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(AppLocalizations.of(context).coverTitle),
                ),
        ),
      ),
    );
  }
}

/// Removing or deleting: the red dialog.
Future<bool> _confirm(BuildContext context, String question, String action) =>
    showBaseDialog(
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    return BaseTile(
      key: ValueKey('branch-${branch.id}'),
      title: branch.label ?? branch.where ?? '-',
      subtitle: branch.label == null ? null : branch.where,
      muted: branch.closed,
      leading: BaseTile.icon(
        context,
        branch.hasPin ? Icons.place : Icons.location_off_outlined,
        color: branch.hasPin ? nb.pandanDeep : nb.kunyit,
      ),
      tags: branchTags(l, branch, fromPost: fromPost),
      onTap: () => BranchPage.open(context, place, branch),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RatingLine(
            rating: branch.rating,
            onTap: () => context.push('/branches/${branch.id}/reviews'),
          ),
          if (!branch.hasPin) UnpinnedActions(place: place, branch: branch),
        ],
      ),
      actions: [
        MenuAction(
          icon: Icons.edit_outlined,
          label: l.editBranch,
          onTap: () => editBranch(context, place, branch, owner: owner),
        ),
        MenuAction(
          icon: Icons.reviews_outlined,
          label: l.reviewsTitle,
          onTap: () => context.push('/branches/${branch.id}/reviews'),
        ),
        if (owner)
          MenuAction(
            icon: Icons.delete_outline,
            label: l.deleteBranch,
            danger: true,
            onTap: () => deleteBranch(context, branch),
          ),
      ],
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
      margin: const EdgeInsets.symmetric(horizontal: spaceM),
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

/// The user's own note, with its Save button under it (on when the text changed).
class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            maxLength: 500,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.noteHint),
          ),
          const SizedBox(height: spaceS),
          FilledButton.icon(
            key: const ValueKey('note-save'),
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(l.noteSave),
          ),
        ],
      ),
    );
  }
}
