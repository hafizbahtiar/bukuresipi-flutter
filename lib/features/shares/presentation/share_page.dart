import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notebook.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/auth_text.dart';
import 'recent_shares.dart';
import 'share_intake.dart';
import 'widgets/share_reading.dart';

String shareErrorText(AppLocalizations l, String code) => switch (code) {
  'no_link' => l.errNoLink,
  'invalid_url' => l.errInvalidUrl,
  'story_link' => l.errStoryLink,
  'daily_limit' => l.errDailyLimit,
  'invalid_image' => l.errInvalidImage,
  'unsupported' => l.errUnsupportedShare,
  _ => errorText(l, code),
};

/// What happened to the post the user just shared into the app: the post as a clipping with the highlighter at
/// work while it is sent, a tick when the server has it, then back to the app it came from.
class SharePage extends StatelessWidget {
  const SharePage({super.key, this.leave});

  /// After a share is accepted. Default: close the app, back to TikTok or wherever the share came from.
  final VoidCallback? leave;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final intake = context.watch<ShareIntake>();
    void close() {
      intake.dismiss();
      context.go('/');
    }

    void leaveApp() {
      close();
      context.read<RecentShares>().load();
      SystemNavigator.pop(); // Android: back to the source app; iOS ignores it and the book is shown
    }

    final item = intake.current;
    final platform = item?.kind == IncomingKind.image
        ? null
        : platformOfUrl(item?.value ?? '');
    final state = intake.state;
    final Widget body = switch (state) {
      ShareIdle() => _Note(text: l.shareNone, icon: Icons.ios_share),
      ShareWaitingForLogin() => _Note(
        text: l.shareWaitingLogin,
        icon: Icons.lock_outline,
      ),
      // One widget for sending and accepted: the clipping stays put, the tick lands on it.
      ShareSending() || ShareAccepted() => _Sent(
        key: const ValueKey('sent'),
        platform: platform,
        acceptedId: state is ShareAccepted ? state.id : null,
        leave: leave ?? leaveApp,
      ),
      final ShareFailed f => _Note(
        text: shareErrorText(l, f.code),
        icon: Icons.error_outline,
        error: true,
        action: f.canRetry
            ? TextButton.icon(
                onPressed: intake.retry,
                icon: const Icon(Icons.refresh),
                label: Text(l.tryAgain),
              )
            : null,
      ),
    };

    return Scaffold(
      appBar: AppBar(toolbarHeight: 76, title: NotebookTitle(l.shareTitle)),
      body: NotebookPage(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(notebookGutter + 16, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(a),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: body.key ?? ValueKey(state.runtimeType),
                          child: body,
                        ),
                      ),
                    ),
                  ),
                ),
                FilledButton(onPressed: close, child: Text(l.doneButton)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The shared post as a clipping. Sending: the highlighter sweeps it. Accepted ([acceptedId] set): every line marked,
/// a tick pops onto it, and a thin bar fills while we wait to [leave] (about two seconds).
class _Sent extends StatefulWidget {
  const _Sent({
    super.key,
    required this.platform,
    required this.acceptedId,
    required this.leave,
  });

  final String? platform;
  final String? acceptedId;
  final VoidCallback leave;

  @override
  State<_Sent> createState() => _SentState();
}

class _SentState extends State<_Sent> with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.leave();
      });

  @override
  void initState() {
    super.initState();
    if (widget.acceptedId != null) _c.forward();
  }

  @override
  void didUpdateWidget(covariant _Sent old) {
    super.didUpdateWidget(old);
    if (widget.acceptedId == old.acceptedId) return;
    widget.acceptedId == null ? _c.reset() : _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final nb = Notebook.of(context);
    final text = Theme.of(context).textTheme;
    final accepted = widget.acceptedId != null;
    final source = shareSource(l, widget.platform);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Clipping(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(shareIcon(widget.platform), color: nb.pandan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source[0].toUpperCase() + source.substring(1),
                          style: nb.hand.copyWith(fontSize: 24, color: nb.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  HighlightSweep(done: accepted),
                ],
              ),
            ),
            Positioned(
              right: -10,
              top: -14,
              child: AnimatedScale(
                scale: accepted ? 1 : 0,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: nb.pandan,
                  child: const Icon(Icons.check, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Semantics(
          liveRegion: true,
          child: Text(
            accepted ? l.shareSavedLeaving : l.shareSending,
            textAlign: TextAlign.center,
            style: text.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: accepted ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _c.value,
                    minHeight: 3,
                    color: nb.kunyit,
                    backgroundColor: nb.line,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.shareBackSoon,
                style: text.bodySmall?.copyWith(color: nb.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.text,
    required this.icon,
    this.error = false,
    this.action,
  });

  final String text;
  final IconData icon;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final nb = Notebook.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: error ? nb.margin : nb.pandan),
        const SizedBox(height: 20),
        Semantics(
          liveRegion: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    );
  }
}
