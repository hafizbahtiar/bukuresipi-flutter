import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_theme_constant.dart';

// The app's AI actions look the same everywhere: the sparkle, the pandan tint on mist, and a spinner in place of
// the sparkle while it works. Three forms:
//   AiButton(label:)        a labelled pill in a page (Suggest with AI, Find variants)
//   AiButton.icon(tooltip:) an app bar action (the recipe editor's AI draft)
//   AiBadge()               a small "AI" mark beside what AI filled or estimated (a field label, a total)

const _sparkle = Icons.auto_awesome;

/// An AI action. [busy] = working: the spinner shows and it does not take another tap.
class AiButton extends StatelessWidget {
  const AiButton({
    super.key,
    required String this.label,
    required this.onPressed,
    this.busy = false,
  }) : tooltip = null;

  const AiButton.icon({
    super.key,
    required String this.tooltip,
    required this.onPressed,
    this.busy = false,
  }) : label = null;

  final String? label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final icon = busy
        ? SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: nb.pandan),
          )
        : const Icon(_sparkle, size: 18);
    final tap = busy ? null : onPressed;
    if (label == null) {
      return IconButton(
        tooltip: tooltip,
        color: nb.pandanDeep,
        onPressed: tap,
        icon: busy ? icon : const Icon(_sparkle),
      );
    }
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        // The theme's FilledButton is a full-width bar (forms): this one is as wide as its label.
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: spaceM),
        backgroundColor: nb.mist,
        foregroundColor: nb.pandanDeep,
        disabledBackgroundColor: nb.mist,
        shape: StadiumBorder(
          side: BorderSide(color: nb.pandan.withValues(alpha: 0.35)),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      onPressed: tap,
      icon: icon,
      label: Text(label!),
    );
  }
}

/// "AI" (or [label], e.g. "AI estimate") in a small tinted chip: this value came from AI, check it.
class AiBadge extends StatelessWidget {
  const AiBadge({super.key, this.label = 'AI'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: nb.mist,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: nb.pandan.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_sparkle, size: 12, color: nb.pandanDeep),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              height: 1,
              fontWeight: FontWeight.w800,
              color: nb.pandanDeep,
            ),
          ),
        ],
      ),
    );
  }
}
