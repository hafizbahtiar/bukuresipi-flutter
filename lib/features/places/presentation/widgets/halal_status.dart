import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// The halal status as a pill under the restaurant's name: what the post claims ('says_halal' / 'says_not_halal'),
/// or that it claims nothing. Always a quote's summary, never "certified" (the quote and JAKIM note sit below).
class HalalStatus extends StatelessWidget {
  const HalalStatus({super.key, required this.claim});

  /// null = no claim (no quote, or no source to quote).
  final String? claim;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final (icon, label, color) = switch (claim) {
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
