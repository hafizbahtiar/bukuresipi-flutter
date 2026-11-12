import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../core/widgets/notebook.dart' show NotebookTitle;
import '../../../../core/widgets/notebook_dialog.dart' show DialogTone;
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/place.dart';
import '../places_controller.dart';
import '../widgets/notebook_rating.dart';
import '../widgets/unpinned_actions.dart';
import 'branch_edit_page.dart';

/// What to know about a branch at a glance, as tags (its tile and its page).
List<TileTag> branchTags(
  AppLocalizations l,
  Branch b, {
  bool fromPost = false,
}) => [
  if (b.closed)
    TileTag(
      l.branchClosed,
      tone: TagTone.danger,
      key: ValueKey('branch-closed-${b.id}'),
    ),
  if (!b.hasPin) TileTag(l.noPin, tone: TagTone.warn),
  if (b.pinnedByUser) TileTag(l.pinnedByUser, tone: TagTone.good),
  if (b.pinnedByOwner) TileTag(l.pinnedByOwner, tone: TagTone.good),
  if (fromPost) TileTag(l.fromYourPost),
];

/// Edit mode: the branch form, full page.
Future<void> editBranch(
  BuildContext context,
  Place place,
  Branch branch, {
  required bool owner,
}) {
  final places = context.read<PlacesController>();
  return showBranchEdit(
    context,
    builder: (_) => BranchEditPage(
      placeId: place.id,
      branch: branch,
      canEditShared: owner,
      onSuggest: owner ? () => places.suggestBranch(branch.id) : null,
      onSave: (edit, scope) => places.updateBranch(
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
}

/// Owner: deletes the branch after asking. true = deleted.
Future<bool> deleteBranch(BuildContext context, Branch branch) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final places = context.read<PlacesController>();
  final yes = await showBaseDialog(
    context,
    message: l.deleteBranchConfirm(branch.label ?? branch.where ?? ''),
    tone: DialogTone.danger,
    confirmLabel: l.delete,
  );
  if (!yes) return false;
  try {
    await places.deleteBranch(branch.id);
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    return false;
  }
}

/// View mode of one branch: what is known (name, address, town, state, pin), how to get there, its rating.
/// The pencil opens edit mode; it follows the controller, so a saved edit shows here at once.
class BranchPage extends StatelessWidget {
  const BranchPage({super.key, required this.placeId, required this.branchId});

  final String placeId;
  final String branchId;

  static Future<void> open(BuildContext context, Place place, Branch b) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BranchPage(placeId: place.id, branchId: b.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final place = context.watch<PlacesController>().byId(placeId);
    final branch = place == null
        ? null
        : [
            ?place.savedBranch,
            ...place.branches,
          ].where((b) => b.id == branchId).firstOrNull;
    if (place == null || branch == null) {
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
    final owner = context.select<AuthController, bool>(
      (a) => a.user?.isOwner ?? false,
    );
    final fromPost =
        branch.id == place.savedBranch?.id && place.branchId != null;
    final tags = branchTags(l, branch, fromPost: fromPost);
    final pinned = branch.hasPin;
    String shown(String? v) => v == null || v.trim().isEmpty ? '—' : v;

    Widget fact(IconData icon, String label, String value, {Key? key}) =>
        ListTile(
          key: key,
          leading: Icon(icon, color: nb.inkSoft),
          title: Text(
            label,
            style: text.labelMedium?.copyWith(color: nb.inkSoft),
          ),
          subtitle: Text(
            value,
            style: text.bodyLarge?.copyWith(
              color: value == '—' ? nb.inkSoft : nb.ink,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: NotebookTitle(branch.label ?? place.restaurant.name),
        actions: [
          IconButton(
            key: const ValueKey('branch-edit'),
            tooltip: l.editBranch,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => editBranch(context, place, branch, owner: owner),
          ),
          MoreMenu(
            actions: [
              if (branch.mapsUrl case final url?)
                MenuAction(
                  icon: Icons.directions,
                  label: l.directions,
                  onTap: () => openLink(context, url, failed: l.openFailed),
                ),
              if (pinned)
                MenuAction(
                  icon: Icons.map_outlined,
                  label: l.navMap,
                  onTap: () =>
                      context.push('/map?lat=${branch.lat}&lng=${branch.lng}'),
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
                  onTap: () async {
                    final nav = Navigator.of(context);
                    if (await deleteBranch(context, branch)) nav.pop();
                  },
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: spaceL),
        children: [
          // Header: whose branch, its status, then the two ways to go.
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, 0),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 18, color: nb.inkSoft),
                const SizedBox(width: spaceS),
                Expanded(
                  child: Text(
                    place.restaurant.name,
                    style: text.titleSmall?.copyWith(color: nb.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(spaceM, spaceS, spaceM, 0),
              child: Wrap(
                spacing: spaceXs + 2,
                runSpacing: spaceXs,
                children: [for (final t in tags) TagChip(t)],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(spaceM, spaceM, spaceM, 0),
            child: pinned
                ? Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('branch-directions'),
                          onPressed: () => openLink(
                            context,
                            branch.mapsUrl!,
                            failed: l.openFailed,
                          ),
                          icon: const Icon(Icons.directions),
                          label: Text(l.directions),
                        ),
                      ),
                      const SizedBox(width: spaceS),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: () => context.push(
                            '/map?lat=${branch.lat}&lng=${branch.lng}',
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: Text(l.navMap),
                        ),
                      ),
                    ],
                  )
                // No pin yet: the ways to give it one.
                : UnpinnedActions(place: place, branch: branch),
          ),
          SectionHeader(l.branchDetails),
          fact(
            Icons.label_outline,
            l.branchLabel,
            shown(branch.label),
            key: const ValueKey('branch-view-label'),
          ),
          fact(
            Icons.place_outlined,
            l.branchAddress,
            shown(branch.address),
            key: const ValueKey('branch-view-address'),
          ),
          fact(Icons.location_city_outlined, l.branchCity, shown(branch.city)),
          fact(Icons.map_outlined, l.branchState, shown(branch.state)),
          SectionHeader(l.branchLocation),
          fact(
            pinned ? Icons.my_location : Icons.location_off_outlined,
            '${l.branchLatitude}, ${l.branchLongitude}',
            pinned
                ? '${branch.lat!.toStringAsFixed(6)}, ${branch.lng!.toStringAsFixed(6)}'
                : l.noPin,
          ),
          SectionHeader(l.reviewsTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: spaceM),
            child: RatingLine(
              rating: branch.rating,
              onTap: () => context.push('/branches/${branch.id}/reviews'),
            ),
          ),
        ],
      ),
    );
  }
}
