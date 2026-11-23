import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../owner/domain/owner.dart';
import '../../domain/nearby_branch.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import '../pages/branch_edit_page.dart';
import 'map_legend.dart';
import 'map_sheet.dart';
import 'market_days.dart';
import 'notebook_rating.dart';
import '../../../shares/presentation/widgets/share_image.dart';

/// What the map page's sheet shows for one thing: a pin, a search hit, a map label, the owner's place.

/// A place label tapped on the map (OpenStreetMap's): its name and where.
class MapLabel {
  const MapLabel(this.name, this.lat, this.lng);

  final String name;
  final double lat, lng;
}

/// A map label that is not a place in Bukuresipi: its name and directions there.
class MapLabelSheet extends StatelessWidget {
  const MapLabelSheet({super.key, required this.label});

  final MapLabel label;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceM),
      children: [
        Text(
          label.name,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          l.mapLabelNotListed,
          style: text.bodyMedium?.copyWith(color: Notebook.of(context).inkSoft),
        ),
        const SizedBox(height: spaceM),
        OutlinedButton.icon(
          key: const ValueKey('map-label-directions'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 46),
            shape: const StadiumBorder(),
          ),
          onPressed: () => openLink(
            context,
            mapsSearchUrl(label.lat, label.lng),
            failed: l.openFailed,
          ),
          icon: const Icon(Icons.directions),
          label: Text(l.directions),
        ),
      ],
    );
  }
}

/// A slip of paper laid on the map.
class MapSlip extends StatelessWidget {
  const MapSlip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Material(
      color: nb.paper,
      elevation: 2,
      shadowColor: nb.ink.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: nb.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      ),
    );
  }
}

/// A search result not in your book: name, where, and Save (a place new to the app becomes a restaurant). Closes
/// with the saved Place.
class SearchHitSheet extends StatefulWidget {
  const SearchHitSheet({super.key, required this.hit, required this.places});

  final PlaceHit hit;
  final PlacesController places;

  @override
  State<SearchHitSheet> createState() => _SearchHitSheetState();
}

class _SearchHitSheetState extends State<SearchHitSheet> {
  bool _saving = false;

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final close = sheetCloser(context);
    final messenger = ScaffoldMessenger.of(context);
    final h = widget.hit;
    setState(() => _saving = true);
    try {
      final place = await (h.branchId != null
          ? widget.places.saveBranch(h.branchId!)
          : widget.places.savePoi(h.poiId!));
      close(place);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final h = widget.hit;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.name, style: text.titleLarge),
            Text(
              [distanceText(h.distanceM), ?h.address].join(' · '),
              style: text.bodyMedium?.copyWith(color: nb.inkSoft),
            ),
            if (h.poiId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.mapSearchNewPlace,
                  style: text.bodySmall?.copyWith(color: nb.inkSoft),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('search-hit-save'),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined),
              label: Text(l.save),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ],
    );
  }
}

/// A pin tapped on the map: the place on a sheet, then open it or get directions.
class PinSheet extends StatelessWidget {
  const PinSheet({super.key, required this.place, this.branch});

  final Place place;
  final Branch? branch;

  Future<void> _edit(BuildContext context, Branch b) async {
    final owner = context.read<AuthController>().user?.isOwner ?? false;
    final close = sheetCloser(context);
    final saved = await showBranchEdit(
      context,
      builder: (_) => BranchEditPage(
        placeId: place.id,
        branch: b,
        canEditShared: owner,
        onSuggest: owner
            ? () => context.read<PlacesController>().suggestBranch(b.id)
            : null,
        onSave: (edit, scope) => context.read<PlacesController>().updateBranch(
          b.id,
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
    if (saved == true && context.mounted) close(null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final soft = text.bodySmall?.copyWith(color: nb.inkSoft);
    final b = branch;
    // Owner: where the pin came from, and the shared edit under Owner tools (a user's pencil edits their own copy).
    final owner = context.watch<AuthController>().user?.isOwner ?? false;
    return ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceXs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.restaurant.name,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if (place.regular)
                      Padding(
                        padding: const EdgeInsets.only(top: spaceXs),
                        child: TagChip(
                          TileTag(l.placeRegular),
                          key: const ValueKey('pin-sheet-regular'),
                        ),
                      ),
                  ],
                ),
              ),
              ?placePhoto(place, size: 64),
            ],
          ),
        ),
        if (b != null)
          ListTile(
            leading: PinMark(pinned: b.hasPin),
            trailing: owner
                ? null
                : IconButton(
                    tooltip: l.editBranch,
                    icon: Icon(Icons.edit_outlined, color: nb.inkSoft),
                    onPressed: () => _edit(context, b),
                  ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.label ?? b.where ?? '-',
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (b.where != null && b.where != b.label)
                  Text(
                    b.where!,
                    style: text.bodySmall?.copyWith(color: nb.inkSoft),
                  ),
                if (owner)
                  Text(
                    b.pinSource == null
                        ? l.branchPinNone
                        : l.ownerPlacePinSource(sourceName(l, b.pinSource!)),
                    key: const ValueKey('pin-sheet-source'),
                    style: soft,
                  )
                else if (b.pinnedByUser)
                  Text(l.pinnedByUser, style: soft)
                else if (b.pinnedByOwner)
                  Text(l.pinnedByOwner, style: soft),
                Consumer<PlacesController>(
                  builder: (context, places, _) {
                    final live =
                        places
                            .byId(place.id)
                            ?.branches
                            .where((x) => x.id == b.id)
                            .firstOrNull ??
                        b;
                    return RatingLine(
                      rating: live.rating,
                      onTap: () => context.push('/branches/${b.id}/reviews'),
                    );
                  },
                ),
              ],
            ),
          ),
        if (b != null && place.restaurant.isMarket)
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, spaceS),
            child: MarketDaysList(schedule: b.schedule),
          ),
        if (place.note case final note? when note.isNotEmpty)
          ListTile(
            leading: Icon(Icons.sticky_note_2_outlined, color: nb.inkSoft),
            title: Text(note),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () {
                    sheetCloser(context)(null);
                    context.push('/places/${place.id}');
                  },
                  child: Text(l.openPlace),
                ),
              ),
              if (b?.mapsUrl case final url?) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () =>
                        openLink(context, url, failed: l.openFailed),
                    icon: const Icon(Icons.directions),
                    label: Text(l.directions),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (owner && b != null) ...[
          SectionHeader(l.ownerTools),
          ListTile(
            key: const ValueKey('pin-sheet-owner-edit'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.editBranch),
            onTap: () => _edit(context, b),
          ),
        ],
      ],
    );
  }
}

/// The owner's look at any restaurant on the map (one they did not save): where its pin came from, how many saved
/// it, and the shared edits: edit (with the AI draft), check the restaurant's branches, delete the branch.
class OwnerPlaceSheet extends StatefulWidget {
  const OwnerPlaceSheet({
    super.key,
    required this.place,
    required this.onChanged,
  });

  final OwnerPlace place;

  /// The shared data changed: the map reloads the owner's layer.
  final VoidCallback onChanged;

  @override
  State<OwnerPlaceSheet> createState() => _OwnerPlaceSheetState();
}

class _OwnerPlaceSheetState extends State<OwnerPlaceSheet> {
  bool _busy = false;

  OwnerPlace get place => widget.place;

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _edit() async {
    final places = context.read<PlacesController>();
    final close = sheetCloser(context);
    final b = place.branch;
    final saved = await showBranchEdit(
      context,
      builder: (_) => BranchEditPage(
        placeId: '',
        branch: b,
        canEditShared: true,
        onSuggest: () => places.suggestBranch(b.id),
        onSave: (edit, scope) => places.updateBranch(
          b.id,
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
    if (saved == true) {
      widget.onChanged();
      close(null);
    }
  }

  Future<void> _run(Future<String?> Function() action) async {
    final l = AppLocalizations.of(context);
    final close = sheetCloser(context);
    setState(() => _busy = true);
    try {
      final done = await action();
      if (done == null) return;
      widget.onChanged();
      _snack(done);
      close(null);
    } catch (e) {
      _snack(errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _check() async {
    final l = AppLocalizations.of(context);
    final done = await context.read<PlacesController>().tidyBranches(
      place.placeId,
    );
    return l.branchesChecked(done.merged, done.removed);
  }

  Future<String?> _delete() async {
    final l = AppLocalizations.of(context);
    final places = context.read<PlacesController>();
    final sure = await showBaseDialog(
      context,
      message: l.deleteBranchConfirm(
        place.label ?? place.address ?? place.name,
      ),
      tone: DialogTone.danger,
      confirmLabel: l.delete,
      content: DeleteScopeCard(everyone: true, text: l.deleteScopeBranch),
    );
    if (!sure) return null;
    await places.deleteBranch(place.branchId);
    return l.deleteBranch;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final where = [
      for (final line in [place.address, place.city, place.state])
        if (line != null && line.isNotEmpty) line,
    ].join(', ');
    final soft = text.bodySmall?.copyWith(color: nb.inkSoft);
    return ListView(
      shrinkWrap: true,
      children: [
        // As a saved pin's sheet: the place, then its branch and where; then the facts, Directions, the tools.
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceXs),
          child: Text(
            place.name,
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
        ListTile(
          leading: MapMarkDot(MapMark.forSource(place.pinSource)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place.label != null && place.label != place.name)
                Text(
                  place.label!,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              if (where.isNotEmpty)
                Text(
                  where,
                  style: text.bodyMedium?.copyWith(color: nb.inkSoft),
                ),
              Text(
                [
                  l.ownerPlaceSavers(place.savers),
                  place.pinSource == null
                      ? l.branchPinNone
                      : l.ownerPlacePinSource(sourceName(l, place.pinSource!)),
                ].join(' · '),
                key: const ValueKey('owner-sheet-facts'),
                style: soft,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              shape: const StadiumBorder(),
            ),
            onPressed: () => openLink(
              context,
              mapsSearchUrl(place.lat, place.lng),
              failed: l.openFailed,
            ),
            icon: const Icon(Icons.directions),
            label: Text(l.directions),
          ),
        ),
        SectionHeader(l.ownerTools),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          enabled: !_busy,
          onTap: _edit,
          title: Text(l.editBranch),
        ),
        ListTile(
          leading: const Icon(Icons.merge_type),
          enabled: !_busy,
          onTap: () => _run(_check),
          title: Text(l.checkBranches),
        ),
        ListTile(
          leading: Icon(Icons.delete_outline, color: nb.margin),
          enabled: !_busy,
          onTap: () => _run(_delete),
          title: Text(l.deleteBranch, style: TextStyle(color: nb.margin)),
        ),
      ],
    );
  }
}
