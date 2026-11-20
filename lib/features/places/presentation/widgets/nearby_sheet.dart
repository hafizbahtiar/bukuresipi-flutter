import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../core/widgets/base.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/nearby_branch.dart';
import '../../domain/place.dart';
import '../../domain/report.dart';
import '../places_controller.dart';
import '../pages/branch_edit_page.dart';
import 'halal_status.dart';
import 'map_sheet.dart';
import 'notebook_rating.dart';
import 'place_report_sheet.dart';

/// A nearby branch on a sheet: where it is, how far, the post's halal claim, and Save.
class NearbySheet extends StatefulWidget {
  const NearbySheet({
    super.key,
    required this.place,
    required this.onSave,
    this.onEdited,
  });

  final NearbyBranch place;
  final Future<void> Function() onSave;

  /// Called after a branch edit so the map can reload its nearby list.
  final Future<void> Function()? onEdited;

  @override
  State<NearbySheet> createState() => _NearbySheetState();
}

class _NearbySheetState extends State<NearbySheet> {
  bool _saving = false;

  Future<void> _report() => showBaseSheet<void>(
    context,
    builder: (_) => PlaceReportSheet(
      subject: ReportSubject.fromNearby(widget.place),
      onSubmit: (draft) => context.read<PlacesController>().report(draft),
    ),
  );

  Future<void> _edit() async {
    final owner = context.read<AuthController>().user?.isOwner ?? false;
    final places = context.read<PlacesController>();
    final close = sheetCloser(context);
    final p = widget.place;
    final saved = await showBranchEdit(
      context,
      builder: (_) => BranchEditPage(
        placeId: p.savedPlaceId ?? '',
        branch: Branch(
          id: p.branchId,
          label: p.label,
          address: p.address,
          lat: p.lat,
          lng: p.lng,
        ),
        canEditShared: owner,
        onSuggest: owner ? () => places.suggestBranch(p.branchId) : null,
        onSave: (edit, scope) => places.updateBranch(
          p.branchId,
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
    if (saved != true || !mounted) return;
    await widget.onEdited?.call();
    if (mounted) close(null);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final close = sheetCloser(context);
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.nearbySaved)));
      close(null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final p = widget.place;
    // Owner: a shared edit (an owner tool, at the bottom), and no Report (it would only reach them).
    final owner = context.watch<AuthController?>()?.user?.isOwner ?? false;
    final where = [
      p.label,
      p.address,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    // In the map's sheet: as tall as its shown part, so Save / Directions stay at its edge while the rest scrolls
    // (a floor keeps them laid out when lowered: clipped, never squeezed).
    final visible = sheetVisibleHeight(context);
    final card = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceXs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    HalalBadge(
                      HalalKind.ofClaim(
                        p.halalQuote == null ? null : p.halalClaim,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.place_outlined, color: nb.pandanDeep),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in where)
                      Text(
                        line,
                        style: text.bodyLarge?.copyWith(
                          fontWeight: line == p.label
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: line == p.label ? null : nb.inkSoft,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        distanceText(p.distanceM),
                        style: text.bodyMedium?.copyWith(
                          color: nb.pandanDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.star_outline_rounded, color: nb.kunyit),
                title: RatingLine(
                  rating: p.rating,
                  onTap: () => context.push('/branches/${p.branchId}/reviews'),
                ),
              ),
              // JAKIM's directory lists this outlet: its own block, apart from what posts say.
              if (p.halalCert case final cert?) ...[
                SectionHeader(l.halalCertTitle),
                HalalCertRow(
                  key: const ValueKey('nearby-jakim'),
                  title: p.label ?? p.name,
                  cert: cert,
                ),
              ],
              if (p.halalClaim != null && p.halalQuote != null) ...[
                SectionHeader(l.halalTitle),
                HalalQuoteRow(
                  claim: p.halalClaim,
                  quote: p.halalQuote!,
                  sourceUrl: p.halalSourceUrl,
                ),
              ],
            ],
          ),
        ),
        if (!owner)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: spaceS),
              // Wraps on a narrow phone or with large text instead of running off the edge.
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(l.editBranch),
                  ),
                  TextButton.icon(
                    onPressed: _report,
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: Text(l.report),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(spaceM, owner ? spaceS : 0, spaceM, 0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(l.save),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('nearby-directions'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => openLink(
                    context,
                    mapsSearchUrl(p.lat, p.lng),
                    failed: l.openFailed,
                  ),
                  icon: const Icon(Icons.directions),
                  label: Text(l.directions),
                ),
              ),
            ],
          ),
        ),
        if (owner) ...[
          SectionHeader(l.ownerTools),
          ListTile(
            key: const ValueKey('nearby-owner-edit'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.editBranch),
            onTap: _edit,
          ),
        ],
      ],
    );
    return visible == null
        ? card
        : SizedBox(height: math.max(visible, 220), child: card);
  }
}
