import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_theme_constant.dart';

/// The owner's edit pages (Edit place, Edit branch) are built from these, so every tab reads the same way: a panel
/// per job (icon, title, what it does, a status chip), one clear action whose own button shows it is working, and an
/// inline notice for what came back. No loose progress bars.

/// One job on an owner edit tab: icon badge, title, what it does ([subtitle]), an optional [trailing] status chip,
/// then its content.
class OwnerPanel extends StatelessWidget {
  const OwnerPanel({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(spaceM),
      decoration: BoxDecoration(
        color: nb.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: nb.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: nb.mist,
                child: Icon(icon, size: 18, color: nb.pandanDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  // The title's first line centred on the badge.
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle case final s?) ...[
                        const SizedBox(height: 2),
                        Text(
                          s,
                          style: text.bodySmall?.copyWith(color: nb.inkSoft),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing case final t?) ...[
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(top: 3), child: t),
              ],
            ],
          ),
          const SizedBox(height: spaceM),
          ...children,
        ],
      ),
    );
  }
}

enum PanelTone { success, info, warning, error }

/// A small status chip for a panel's header (Valid, Expired, None).
class PanelChip extends StatelessWidget {
  const PanelChip({super.key, required this.label, required this.tone});

  final String label;
  final PanelTone tone;

  @override
  Widget build(BuildContext context) {
    final c = _toneColor(Notebook.of(context), tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: c, fontWeight: FontWeight.w700),
      ),
    );
  }
}

Color _toneColor(Notebook nb, PanelTone tone) => switch (tone) {
  PanelTone.success => nb.pandanDeep,
  PanelTone.info => nb.inkSoft,
  PanelTone.warning => nb.kunyit,
  PanelTone.error => nb.margin,
};

/// What an action came back with, in the panel: tinted by [tone], plain text (never a bold paragraph).
class PanelNotice extends StatelessWidget {
  const PanelNotice({super.key, required this.text, required this.tone});

  final String text;
  final PanelTone tone;

  @override
  Widget build(BuildContext context) {
    final c = _toneColor(Notebook.of(context), tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            switch (tone) {
              PanelTone.success => Icons.check_circle_outline,
              PanelTone.info => Icons.info_outline,
              PanelTone.warning => Icons.help_outline,
              PanelTone.error => Icons.cloud_off_outlined,
            },
            size: 18,
            color: c,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// A first load inside a panel: a small spinner and what it is doing, with room around it.
class PanelLoading extends StatelessWidget {
  const PanelLoading({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: spaceS),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: nb.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// A group of actions, the one rule for every owner panel: negative first (left), positive last (right), in one
/// row at the end when they fit; on a small phone stacked full width, the positive one on top.
class PanelActions extends StatelessWidget {
  const PanelActions({super.key, required this.children});

  /// Negative (Remove, Unpair) first, the positive one last.
  final List<Widget> children;

  /// Narrower than this (a 320 dp phone's panel), a group of two or more is stacked.
  static const _stackBelow = 300.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => children.length > 1 && box.maxWidth < _stackBelow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spaceS,
            children: children.reversed.toList(),
          )
        // Labels too long for one row (a long translation) still stack, at the end.
        : OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: spaceS,
            overflowSpacing: spaceS,
            overflowAlignment: OverflowBarAlignment.end,
            overflowDirection: VerticalDirection.up,
            children: children,
          ),
  );
}

/// [danger] = a negative action (Remove, Unpair): red outline.
enum BusyButtonKind { filled, tonal, outlined, danger }

/// The owner pages' action button: compact (40 px, as wide as its label). Pressed, the pill morphs into a round
/// spinner with [busyLabel] beside it (what it is doing); done, it grows back. Full width only when its parent
/// gives a tight width (a stacked group on a small phone, an Expanded). [onPressed] null = disabled.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.icon,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
    this.kind = BusyButtonKind.tonal,
  });

  final IconData icon;
  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback? onPressed;
  final BusyButtonKind kind;

  static const _h = 40.0;
  static const _pad = 16.0;
  static const _gap = 10.0;
  static const _morph = Duration(milliseconds: 320);
  static const _curve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final enabled = onPressed != null && !busy;
    final (bg, fg) = switch (kind) {
      BusyButtonKind.filled => (cs.primary, cs.onPrimary),
      BusyButtonKind.tonal => (cs.secondaryContainer, cs.onSecondaryContainer),
      BusyButtonKind.outlined => (Colors.transparent, cs.primary),
      BusyButtonKind.danger => (Colors.transparent, nb.margin),
    };
    final edge = switch (kind) {
      BusyButtonKind.outlined => nb.pandan.withValues(alpha: 0.5),
      BusyButtonKind.danger => nb.margin.withValues(alpha: 0.5),
      _ => null,
    };
    final style = text.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: fg,
    );
    final busyStyle = text.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: nb.inkSoft,
    );
    double widthOf(String s, TextStyle? st) => (TextPainter(
      text: TextSpan(text: s, style: st),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout()).width;
    return LayoutBuilder(
      builder: (context, box) {
        final max = box.maxWidth.isFinite ? box.maxWidth : double.infinity;
        final idle = box.hasTightWidth
            ? box.maxWidth
            : (widthOf(label, style) + 18 + 8 + _pad * 2).clamp(_h, max);
        // Busy: the circle and what it is doing; never narrower than the pill was (nothing beside it jumps).
        final working = box.hasTightWidth
            ? box.maxWidth
            : (_h + _gap + widthOf(busyLabel, busyStyle) + 2).clamp(idle, max);
        final width = busy ? working : idle;
        return Semantics(
          button: true,
          enabled: enabled,
          label: busy ? busyLabel : label,
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: _morph,
            curve: _curve,
            width: width,
            height: _h,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                AnimatedContainer(
                  duration: _morph,
                  curve: _curve,
                  width: busy ? _h : idle,
                  height: _h,
                  decoration: BoxDecoration(
                    color: busy && edge != null
                        ? fg.withValues(alpha: 0.08)
                        : bg,
                    borderRadius: BorderRadius.circular(_h / 2),
                    border: edge == null ? null : Border.all(color: edge),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: enabled ? onPressed : null,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.hardEdge,
                          children: [...previous, ?current],
                        ),
                        child: busy
                            ? Center(
                                key: const ValueKey('spin'),
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: fg,
                                  ),
                                ),
                              )
                            : Opacity(
                                key: const ValueKey('label'),
                                opacity: enabled ? 1 : 0.4,
                                // Laid out at the pill's full width while it shrinks: clipped, never squeezed.
                                child: OverflowBox(
                                  minWidth: 0,
                                  maxWidth: idle,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: _pad,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 18, color: fg),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            label,
                                            style: style,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _h + _gap,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: _morph,
                      opacity: busy ? 1 : 0,
                      child: Text(
                        busyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: busyStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Label on the left, value on the right; no value = no row. [onTap] = the value is a link.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
    this.onTap,
  });

  final String label;
  final String? value;
  final bool strong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final style = strong
        ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
        : text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: nb.inkSoft, height: 1.6),
            ),
          ),
          Expanded(
            child: onTap == null
                ? SelectableText(v, style: style)
                : InkWell(
                    onTap: onTap,
                    child: Text(
                      v,
                      style: style?.copyWith(
                        color: nb.pandanDeep,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
