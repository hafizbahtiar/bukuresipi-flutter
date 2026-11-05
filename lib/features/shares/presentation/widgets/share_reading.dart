import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notebook.dart';
import '../../../../core/widgets/notebook_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/presentation/auth_text.dart';
import '../../domain/share.dart';
import '../recent_shares.dart';

/// The API's platform for a link, read on the phone (the share screen has no server answer yet).
String? platformOfUrl(String url) {
  final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
  bool on(String d) => host == d || host.endsWith('.$d');
  if (on('tiktok.com')) return 'tiktok';
  if (on('instagram.com')) return 'instagram';
  if (on('facebook.com') || on('fb.watch')) return 'facebook';
  if (on('youtube.com') || on('youtu.be')) return 'youtube';
  if (on('maps.app.goo.gl') ||
      on('goo.gl') ||
      host.startsWith('maps.google.')) {
    return 'google_maps';
  }
  return 'web';
}

/// "your TikTok post", "your screenshot" (null platform = an image share), "the web page".
String shareSource(AppLocalizations l, String? platform) => switch (platform) {
  'tiktok' => l.shareSourcePost('TikTok'),
  'instagram' => l.shareSourcePost('Instagram'),
  'facebook' => l.shareSourcePost('Facebook'),
  'youtube' => l.shareSourcePost('YouTube'),
  'google_maps' => l.shareSourceMaps,
  null => l.shareSourceScreenshot,
  _ => l.shareSourceWeb,
};

IconData shareIcon(String? platform) => switch (platform) {
  'google_maps' => Icons.place_outlined,
  'web' => Icons.public,
  null => Icons.image_outlined,
  _ => Icons.play_circle_outline,
};

/// Text lines with a yellow highlighter sweeping across them one by one, like a pen marking what is read. [done]
/// holds every line marked; reduced motion holds them still.
class HighlightSweep extends StatefulWidget {
  const HighlightSweep({
    super.key,
    this.widths = const [0.92, 0.74, 0.58],
    this.lineHeight = 8,
    this.done = false,
  });

  final List<double> widths;
  final double lineHeight;
  final bool done;

  @override
  State<HighlightSweep> createState() => _HighlightSweepState();
}

class _HighlightSweepState extends State<HighlightSweep>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 650 * widget.widths.length + 500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant HighlightSweep old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.done) {
      _c.animateTo(1, duration: const Duration(milliseconds: 300));
    } else if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    final n = widget.widths.length;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Each line gets an equal slice of the loop; the last slice is a pause with everything marked.
        final t = _c.value * (n + 0.8);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : widget.lineHeight),
                child: FractionallySizedBox(
                  widthFactor: widget.widths[i],
                  child: Stack(
                    children: [
                      Container(
                        height: widget.lineHeight,
                        decoration: BoxDecoration(
                          color: nb.ink.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: widget.done
                            ? 1
                            : Curves.easeOutCubic.transform(
                                (t - i).clamp(0.0, 1.0),
                              ),
                        child: Container(
                          height: widget.lineHeight,
                          decoration: BoxDecoration(
                            color: nb.kunyit.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A post pinned into the notebook like a newspaper clipping: tape on top, slightly crooked.
class Clipping extends StatelessWidget {
  const Clipping({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Transform.rotate(
      angle: -1.2 * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            decoration: BoxDecoration(
              color: nb.paper,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: nb.line),
              boxShadow: [
                BoxShadow(
                  color: nb.ink.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: child,
          ),
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.rotate(
                angle: 2 * math.pi / 180,
                child: Container(
                  width: 72,
                  height: 20,
                  color: nb.kunyit.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grows in from nothing and fades in: rows that appear in a list without a jump.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child});

  final Widget child;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();
  late final _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _a,
    alignment: Alignment.topCenter,
    child: FadeTransition(opacity: _a, child: widget.child),
  );
}

/// A share the server is still reading, in the book: which post, what stage, and the highlighter at work.
class ReadingShareRow extends StatelessWidget {
  const ReadingShareRow({super.key, required this.share});

  final Share share;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final stage = share.attempts > 1
        ? l.shareStageRetry(share.attempts, 3)
        : share.status == 'processing'
        ? l.shareStageReading
        : l.shareStageQueued;
    return Appear(
      child: NotebookRow(
        mark: Icon(shareIcon(share.platform), size: 20, color: nb.pandan),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  l.shareReadingTitle(shareSource(l, share.platform)),
                  style: nb.hand.copyWith(fontSize: 22, color: nb.ink),
                ),
              ),
              Text(
                stage,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: nb.inkSoft),
              ),
              const SizedBox(height: 10),
              const SizedBox(width: 220, child: HighlightSweep(lineHeight: 6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A share that ended without a recipe or place: why, in plain words, then retry (when it can help) or remove.
class ShareProblemRow extends StatefulWidget {
  const ShareProblemRow({super.key, required this.share});

  final Share share;

  @override
  State<ShareProblemRow> createState() => _ShareProblemRowState();
}

class _ShareProblemRowState extends State<ShareProblemRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(RecentShares) action) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shared = context.read<RecentShares>();
    setState(() => _busy = true);
    try {
      await action(shared);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    final l = AppLocalizations.of(context);
    final ok = await showNotebookDialog(
      context,
      message: l.shareDismissConfirm,
      tone: DialogTone.danger,
      confirmLabel: l.remove,
    );
    if (ok) await _run((s) => s.dismiss(widget.share.id));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final s = widget.share;
    final why = s.nothingFound
        ? l.shareNothingFound
        : switch (s.reason) {
            final r when r.contains('unreadable') => l.shareWhyUnreadable,
            'quota' => l.shareWhyBusy,
            'ai_failed' || 'timeout' || 'internal' => l.shareWhyError,
            _ => l.shareFailed,
          };
    return Appear(
      child: NotebookRow(
        mark: Icon(
          s.nothingFound ? Icons.search_off : Icons.error_outline,
          size: 20,
          color: s.nothingFound ? nb.inkSoft : nb.margin,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shareSource(l, s.platform),
                style: nb.hand.copyWith(fontSize: 20, color: nb.inkSoft),
              ),
              Text(why),
              // The server's code (unreadable, ai_failed, quota...): what to look up in the logs.
              if (s.reason.isNotEmpty)
                Text(
                  s.reason,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: nb.inkSoft),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  if (!s.nothingFound)
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run((r) => r.retry(s.id)),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(l.tryAgain),
                    ),
                  TextButton.icon(
                    onPressed: _busy ? null : _dismiss,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l.remove),
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

/// A recipe or place that just finished reading: slides into the book under a fading yellow highlight.
class FreshHighlight extends StatefulWidget {
  const FreshHighlight({super.key, required this.fresh, required this.child});

  /// Read once, when the tile first shows.
  final bool fresh;
  final Widget child;

  @override
  State<FreshHighlight> createState() => _FreshHighlightState();
}

class _FreshHighlightState extends State<FreshHighlight>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
    value: widget.fresh ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.fresh) unawaited(_c.forward());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.fresh) return widget.child;
    final nb = Notebook.of(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final grow = Curves.easeOutCubic.transform(
          (_c.value / 0.15).clamp(0, 1),
        );
        final glow = 1 - Curves.easeIn.transform(_c.value);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: grow,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: nb.kunyit.withValues(alpha: 0.45 * glow),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
