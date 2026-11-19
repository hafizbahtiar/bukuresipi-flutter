import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/open_link.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/place.dart';

/// What is known about halal, strongest first. Only [jakim] is a certificate (JAKIM's directory lists the outlet,
/// not expired); [says] and [saysNot] are quotes from a post; [expired] is a certificate past its date.
enum HalalKind {
  jakim,
  says,
  saysNot,
  expired,
  none;

  /// A post's quoted claim ('says_halal' / 'says_not_halal'); null = no claim.
  static HalalKind ofClaim(String? claim) => switch (claim) {
    'says_halal' => says,
    'says_not_halal' => saysNot,
    _ => none,
  };
}

enum HalalBadgeVariant {
  /// Icon and words in the kind's colour, no box: a line inside other text.
  simple,

  /// A pill: under a place's name. JAKIM is filled, a quote is outlined.
  standard,

  /// A card with a round icon, a title, a subtitle and [HalalBadge.children]: a halal tab's item.
  full,
}

/// The one halal badge. Never says "certified" for a quote, and uses no JAKIM logo: the app does not certify, and
/// the logo is JAKIM's mark for certified premises only.
class HalalBadge extends StatelessWidget {
  const HalalBadge(
    this.kind, {
    super.key,
    this.variant = HalalBadgeVariant.standard,
    this.label,
    this.subtitle,
    this.children = const [],
  });

  final HalalKind kind;
  final HalalBadgeVariant variant;

  /// null = the kind's own words ("JAKIM halal", "The post says halal"...).
  final String? label;

  /// [HalalBadgeVariant.full] only: the line under the title, and what sits below it.
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final (icon, color) = switch (kind) {
      HalalKind.jakim => (Icons.verified, nb.pandan),
      HalalKind.says => (Icons.format_quote_rounded, nb.pandanDeep),
      HalalKind.saysNot => (Icons.do_not_disturb_on_outlined, nb.margin),
      HalalKind.expired => (Icons.event_busy_outlined, nb.margin),
      HalalKind.none => (Icons.help_outline, nb.inkSoft),
    };
    final words =
        label ??
        switch (kind) {
          HalalKind.jakim => l.feedJakimHalal,
          HalalKind.says => l.halalSaysHalal,
          HalalKind.saysNot => l.halalSaysNotHalal,
          HalalKind.expired || HalalKind.none => l.halalNoClaim,
        };
    switch (variant) {
      case HalalBadgeVariant.simple:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                words,
                style: text.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      case HalalBadgeVariant.standard:
        final filled = kind == HalalKind.jakim;
        final fg = filled ? Colors.white : color;
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: filled ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: filled ? color : color.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      words,
                      style: TextStyle(
                        color: fg,
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
      case HalalBadgeVariant.full:
        return Container(
          margin: const EdgeInsets.fromLTRB(spaceM, 0, spaceM, spaceS),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kind == HalalKind.none
                ? nb.mist
                : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kind == HalalKind.none
                  ? nb.line
                  : color.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(icon, size: 22, color: color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          words,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle case final s?)
                          Text(
                            s,
                            style: text.bodySmall?.copyWith(color: nb.inkSoft),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (children.isNotEmpty) ...[
                const SizedBox(height: 10),
                // Under the title, past the icon; full width in a narrow card (a 320 dp phone), where it costs lines.
                LayoutBuilder(
                  builder: (context, box) => Padding(
                    padding: EdgeInsets.only(left: box.maxWidth < 300 ? 0 : 52),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// A small link under a card's text ("Check on JAKIM", "Open the post").
class _CardLink extends StatelessWidget {
  const _CardLink({required this.label, required this.url});

  final String label, url;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () =>
        openLink(context, url, failed: AppLocalizations.of(context).openFailed),
    icon: const Icon(Icons.open_in_new, size: 16),
    label: Text(label),
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
  );
}

Widget _note(BuildContext context, String s) => Text(
  s,
  style: Theme.of(context).textTheme.bodySmall
      ?.copyWith(color: Notebook.of(context).inkSoft),
);

/// An outlet's JAKIM directory row: the outlet, until when, when we checked, and JAKIM's own page to check it.
/// Expired stays shown (in red, with its date): never silently dropped, never "not halal".
class HalalCertRow extends StatelessWidget {
  const HalalCertRow({
    super.key,
    required this.title,
    required this.cert,
    this.note = true,
  });

  /// The outlet as we name it (its branch); JAKIM's premise name goes under it.
  final String title;
  final HalalCert cert;

  /// "Listed for this outlet only": once under a list of them, so the last one says it.
  final bool note;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final day = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final expired = cert.expiredAt(DateTime.now());
    final color = expired ? nb.margin : nb.pandanDeep;
    return HalalBadge(
      expired ? HalalKind.expired : HalalKind.jakim,
      variant: HalalBadgeVariant.full,
      label: title,
      subtitle: cert.premise,
      children: [
        Row(
          children: [
            Icon(
              expired ? Icons.event_busy_outlined : Icons.event_available,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                (expired ? l.halalCertExpiredOn : l.halalCertUntil)(
                  day.format(cert.expiresOn),
                ),
                style: text.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          l.halalCertChecked(day.format(cert.checkedAt)),
          style: text.bodySmall?.copyWith(color: nb.inkSoft),
        ),
        _CardLink(label: l.halalCertOpen, url: cert.url),
        if (note) _note(context, l.halalCertNote),
      ],
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
    final text = Theme.of(context).textTheme;
    return HalalBadge(
      HalalKind.none,
      key: const ValueKey('halal-brand'),
      variant: HalalBadgeVariant.full,
      label: l.halalBrandCount(outlets),
      children: [
        for (final b in branches)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l.halalBrandBranch(b.label ?? b.where ?? '-'),
              style: text.bodyMedium,
            ),
          ),
        _CardLink(label: l.halalBrandOpen, url: url),
        _note(context, l.halalBrandNote),
      ],
    );
  }
}

/// What a post says about halal: the quote, its post, and that a quote is not a certificate.
class HalalQuoteRow extends StatelessWidget {
  const HalalQuoteRow({
    super.key,
    required this.claim,
    required this.quote,
    required this.sourceUrl,
  });

  final String? claim;
  final String quote;
  final String? sourceUrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return HalalBadge(
      HalalKind.ofClaim(claim),
      variant: HalalBadgeVariant.full,
      children: [
        Text(
          '“$quote”',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontStyle: FontStyle.italic),
        ),
        if (sourceUrl case final url?)
          _CardLink(label: l.halalSource, url: url),
        _note(context, l.halalNotCert),
      ],
    );
  }
}
