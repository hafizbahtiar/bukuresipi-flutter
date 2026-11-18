import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/open_link.dart';
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
    final navigator = Navigator.of(context);
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
    if (mounted) navigator.pop();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.nearbySaved)));
      navigator.pop();
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
    final where = [
      p.label,
      p.address,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return Column(
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
                    HalalStatus(
                      claim: p.halalQuote == null ? null : p.halalClaim,
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
                ListTile(
                  key: const ValueKey('nearby-jakim'),
                  leading: Icon(
                    Icons.verified_outlined,
                    color: cert.expiredAt(DateTime.now())
                        ? nb.margin
                        : nb.pandanDeep,
                  ),
                  title: Text(cert.premise),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (cert.expiredAt(DateTime.now())
                            ? l.halalCertExpired
                            : l.halalCertValid)(
                          _day(context, cert.expiresOn),
                          _day(context, cert.checkedAt),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            openLink(context, cert.url, failed: l.openFailed),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(l.halalCertOpen),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (p.halalClaim != null && p.halalQuote != null) ...[
                SectionHeader(l.halalTitle),
                ListTile(
                  leading: Icon(Icons.info_outline, color: nb.kunyit),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '“${p.halalQuote}”',
                        style: text.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (p.halalSourceUrl case final url?)
                        TextButton.icon(
                          onPressed: () =>
                              openLink(context, url, failed: l.openFailed),
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
                ),
              ],
            ],
          ),
        ),
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
          padding: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, 0),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : Text(l.save),
          ),
        ),
      ],
    );
  }
}

String _day(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);
