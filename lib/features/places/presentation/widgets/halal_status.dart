import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/place.dart';

/// The halal status as a pill under the restaurant's name: what the post claims ('says_halal' / 'says_not_halal'),
/// or that it claims nothing. Always a quote's summary, never "certified" (the quote and JAKIM note sit below).
class HalalStatus extends StatelessWidget {
  const HalalStatus({super.key, required this.claim}) : jakim = null;

  /// JAKIM's directory lists the place's outlet(s): [jakim] is the pill's text ("JAKIM halal · 2 outlets").
  const HalalStatus.jakim(String this.jakim, {super.key}) : claim = null;

  /// null = no claim (no quote, or no source to quote).
  final String? claim;
  final String? jakim;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final (icon, label, color) = switch (claim) {
      _ when jakim != null => (Icons.verified, jakim!, nb.pandanDeep),
      'says_halal' => (
        Icons.verified_outlined,
        l.halalSaysHalal,
        nb.pandanDeep,
      ),
      'says_not_halal' => (
        Icons.do_not_disturb_on_outlined,
        l.halalSaysNotHalal,
        nb.margin,
      ),
      _ => (Icons.help_outline, l.halalNoClaim, nb.inkSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A branch's JAKIM directory row: the outlet, until when, when we checked, and JAKIM's own page to check it.
/// Expired stays shown (in red, with its date): never silently dropped, never "not halal".
class HalalCertRow extends StatelessWidget {
  const HalalCertRow({super.key, required this.branch});

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
class HalalBrandRow extends StatelessWidget {
  const HalalBrandRow({
    super.key,
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
