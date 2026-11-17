import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
/// The route `extra` from a card whose photo flies into the page's header: the page fades in instead of flipping.
class PlacePhotoFlight {
  const PlacePhotoFlight();
}

/// The hero tag shared by a place card's photo and its page header ([id] = the saved place's id).
Object placePhotoTag(String id) => 'place-photo-$id';

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

  /// Owner's "Check JAKIM" running (a place or a branch): its buttons wait.
  bool _checkingHalal = false;

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

  /// Owner: the brand's JAKIM count and every branch, now.
  Future<void> _checkJakimPlace(Place place) async {
    final l = AppLocalizations.of(context);
    setState(() => _checkingHalal = true);
    try {
      final r = await context.read<PlacesController>().checkHalalPlace(
        place.restaurant.id,
      );
      if (r.outlets == null &&
          r.branches.values.every((s) => s == 'unavailable')) {
        _snack(l.jakimCheckDown);
      } else {
        _snack(
          l.jakimCheckPlace(
            r.outlets ?? 0,
            r.branches.values.where((s) => s == 'found').length,
            r.branches.length,
          ),
        );
      }
    } catch (e) {
      _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _checkingHalal = false);
    }
  }

  /// Owner: one branch now; no automatic match = JAKIM's rows to choose from.
  Future<void> _checkJakimBranch(Branch branch) async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    final name = branch.label ?? branch.where ?? '-';
    setState(() => _checkingHalal = true);
    try {
      final r = await places.checkHalalBranch(branch.id);
      switch (r.status) {
        case 'found':
          _snack(l.jakimCheckFound(name));
        case 'unavailable':
          _snack(l.jakimCheckDown);
        default:
          final url = r.url;
          if (r.rows.isEmpty || url == null || !mounted) {
            _snack(l.jakimCheckNone(name));
            break;
          }
          setState(
            () => _checkingHalal = false,
          ); // the check is done: no progress bar behind the sheet
          final row = await showBaseSheet<JakimRow>(
            context,
            floating: false,
            builder: (sheet) => _JakimChooser(branch: name, rows: r.rows),
          );
          if (row == null) {
            _snack(l.jakimCheckNone(name));
            break;
          }
          await places.setHalalCert(branch.id, row, url);
          _snack(l.jakimCertSaved);
      }
    } catch (e) {
      _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _checkingHalal = false);
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
    final certified = [
      for (final b in branches)
        if (b.halalCert != null) b,
    ];
    // The brand is on JAKIM but these outlets are not confirmed: said as such, never as halal.
    final brandOnly = r.halalBrand == null
        ? const <Branch>[]
        : [
            for (final b in branches)
              if (b.halalCert == null && !b.closed) b,
          ];

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
    // A screen wide, so decoded larger than a card's (as a recipe's header).
    final cacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(600, 1600);
    final photo = photoId == null
        ? null
        : ShareFill(
            key: ValueKey('place-cover-$photoId'),
            id: photoId,
            placeId: r.cover == null ? null : r.id,
            fallbackShareId: r.cover == null ? null : place.shareId,
            fallback: ColoredBox(color: nb.mist),
            cacheWidth: cacheWidth,
          );
    ShareFill.warm(
      context,
      photo,
    ); // decoded during a card's flight, not on landing
    final coverBar = CoverAppBar(
      photo: photo ?? _NoPhoto(onAdd: owner ? pickCover : null),
      height: photo == null ? 140 : null,
      title: r.name,
      heroTag: photo == null ? null : placePhotoTag(widget.id),
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
            if (halal ||
                certified.isNotEmpty ||
                brandOnly.isNotEmpty ||
                (owner && r.isFood))
              DetailSection(
                id: 'place-tab-halal',
                label: l.placeTabHalal,
                rows: [
                  if (certified.isNotEmpty) ...[
                    SectionHeader(l.halalCertTitle),
                    for (final b in certified) _HalalCertRow(branch: b),
                  ],
                  if (r.halalBrand case final brand?
                      when brandOnly.isNotEmpty) ...[
                    SectionHeader(l.halalBrandTitle),
                    _HalalBrandRow(
                      outlets: brand.outlets,
                      url: brand.url,
                      branches: brandOnly,
                    ),
                  ],
                  if (owner && r.isFood)
                    _OwnerJakim(
                      branches: branches,
                      busy: _checkingHalal,
                      onPlace: () => _checkJakimPlace(place),
                      onBranch: _checkJakimBranch,
                    ),
                  if (halal) ...[
                    SectionHeader(l.halalTitle),
                    _HalalQuote(restaurant: r),
                  ],
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

/// A branch's JAKIM directory row: the outlet, until when, when we checked, and JAKIM's own page to check it.
/// Expired stays shown (in red, with its date): never silently dropped, never "not halal".
class _HalalCertRow extends StatelessWidget {
  const _HalalCertRow({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final cert = branch.halalCert!;
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final expired = cert.expiredAt(DateTime.now());
    final dates = (expired ? l.halalCertExpired : l.halalCertValid)(
      day.format(cert.expiresOn),
      day.format(cert.checkedAt),
    );
    return Container(
      key: ValueKey('halal-cert-${branch.id}'),
      margin: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: expired ? nb.margin : nb.pandan, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.label ?? branch.where ?? cert.premise,
            style: text.titleSmall,
          ),
          Text(
            cert.premise,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
          Text(
            dates,
            style: text.bodyMedium?.copyWith(color: expired ? nb.margin : null),
          ),
          TextButton.icon(
            onPressed: () => openLink(context, cert.url, failed: l.openFailed),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l.halalCertOpen),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          Text(
            l.halalCertNote,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// The brand has JAKIM-certified premises, but these outlets are not matched: each premises is certified on its own,
/// so the words say "not confirmed", never "halal", and send the user to the certificate at the premises.
class _HalalBrandRow extends StatelessWidget {
  const _HalalBrandRow({
    required this.outlets,
    required this.url,
    required this.branches,
  });

  final int outlets;
  final String url;
  final List<Branch> branches;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('halal-brand'),
      margin: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: nb.line, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.halalBrandCount(outlets), style: text.bodyMedium),
          for (final b in branches)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.halalBrandBranch(b.label ?? b.where ?? '-'),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          TextButton.icon(
            onPressed: () => openLink(context, url, failed: l.openFailed),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l.halalBrandOpen),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          Text(
            l.halalBrandNote,
            style: text.bodySmall?.copyWith(color: nb.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Owner only: "Check JAKIM" for the whole place (the brand + every branch) or one branch.
class _OwnerJakim extends StatelessWidget {
  const _OwnerJakim({
    required this.branches,
    required this.busy,
    required this.onPlace,
    required this.onBranch,
  });

  final List<Branch> branches;
  final bool busy;
  final VoidCallback onPlace;
  final ValueChanged<Branch> onBranch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy) const LinearProgressIndicator(),
          TextButton.icon(
            key: const ValueKey('jakim-check-place'),
            onPressed: busy ? null : onPlace,
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: Text(l.jakimCheckAll),
          ),
          for (final b in branches.where((b) => !b.closed))
            TextButton(
              key: ValueKey('jakim-check-${b.id}'),
              onPressed: busy ? null : () => onBranch(b),
              child: Text(l.jakimCheckBranch(b.label ?? b.where ?? '-')),
            ),
        ],
      ),
    );
  }
}

/// JAKIM's rows for a branch the check did not match: the owner picks the one that is it, or none.
class _JakimChooser extends StatelessWidget {
  const _JakimChooser({required this.branch, required this.rows});

  final String branch;
  final List<JakimRow> rows;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, spaceM, spaceM, spaceS),
            child: Text(l.jakimChooseTitle(branch), style: text.titleMedium),
          ),
          for (final (i, r) in rows.indexed)
            ListTile(
              key: ValueKey('jakim-choose-$i'),
              title: Text(r.premise),
              subtitle: Text(
                l.jakimDraftRow(r.address, day.format(r.expiresOn)),
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
              onTap: () => Navigator.of(context).pop(r),
            ),
          TextButton(
            key: const ValueKey('jakim-choose-none'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.jakimChooseNone),
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
