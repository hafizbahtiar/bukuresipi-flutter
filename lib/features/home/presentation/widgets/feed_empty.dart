import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A button of [FeedEmpty]: icon, label, what it does.
typedef FeedEmptyAction = (IconData, String, VoidCallback);

/// Home with nothing to show, as a page of the notebook: a drawing (or an icon on a soft circle), a handwritten
/// title, one line of why, and what to do next ([primary], filled; [secondary], outlined).
class FeedEmpty extends StatelessWidget {
  const FeedEmpty({
    super.key,
    required this.title,
    required this.body,
    required this.primary,
    this.secondary,
    this.icon,
    this.drawing,
  });

  final String title;
  final String body;
  final FeedEmptyAction primary;
  final FeedEmptyAction? secondary;

  /// Shown on a soft circle when there is no [drawing].
  final IconData? icon;

  /// An asset illustration (the cooking drawing).
  final String? drawing;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final (pIcon, pLabel, pTap) = primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: nb.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: nb.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              if (drawing case final d?)
                Image.asset(
                  d,
                  key: const ValueKey('feed-empty-drawing'),
                  height: 132,
                  fit: BoxFit.contain,
                  cacheHeight: 400,
                  excludeFromSemantics: true,
                )
              else if (icon case final i?)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: nb.mist,
                    shape: BoxShape.circle,
                    border: Border.all(color: nb.line),
                  ),
                  child: Icon(i, size: 32, color: nb.pandan),
                ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: nb.hand.copyWith(
                  fontSize: 30,
                  height: 1.1,
                  color: nb.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: nb.inkSoft,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              // Side by side when they fit, else stacked: a long Malay label never squeezes.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('feed-empty-primary'),
                    onPressed: pTap,
                    icon: Icon(pIcon, size: 18),
                    label: Text(pLabel),
                  ),
                  if (secondary case (final sIcon, final sLabel, final sTap))
                    OutlinedButton.icon(
                      key: const ValueKey('feed-empty-secondary'),
                      onPressed: sTap,
                      icon: Icon(sIcon, size: 18),
                      label: Text(sLabel),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
