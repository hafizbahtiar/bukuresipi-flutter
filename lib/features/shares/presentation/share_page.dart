import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/auth_text.dart';
import 'recent_shares.dart';
import 'share_intake.dart';

String shareErrorText(AppLocalizations l, String code) => switch (code) {
  'no_link' => l.errNoLink,
  'invalid_url' => l.errInvalidUrl,
  'story_link' => l.errStoryLink,
  'daily_limit' => l.errDailyLimit,
  'invalid_image' => l.errInvalidImage,
  'unsupported' => l.errUnsupportedShare,
  _ => errorText(l, code),
};

/// What happened to the post the user just shared into the app.
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

    final body = switch (intake.state) {
      ShareIdle() => _Message(text: l.shareNone),
      ShareWaitingForLogin() => _Message(text: l.shareWaitingLogin),
      ShareSending() => _Message(text: l.shareSending, busy: true),
      ShareAccepted(:final id) => _Saved(
        key: ValueKey(id),
        leave: leave ?? leaveApp,
      ),
      final ShareFailed f => _Message(
        text: shareErrorText(l, f.code),
        icon: Icons.error_outline,
        action: f.canRetry
            ? TextButton(onPressed: intake.retry, child: Text(l.tryAgain))
            : null,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.shareTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Center(child: body)),
              FilledButton(onPressed: close, child: Text(l.doneButton)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The server has the post and reads it on its own: say so, then go back to the app the post came from. The book
/// shows it as "reading" until it is done.
class _Saved extends StatefulWidget {
  const _Saved({super.key, required this.leave});

  final VoidCallback leave;

  @override
  State<_Saved> createState() => _SavedState();
}

class _SavedState extends State<_Saved> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1500), widget.leave);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Message(
    text: AppLocalizations.of(context).shareSavedLeaving,
    icon: Icons.check_circle_outline,
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.busy = false,
    this.icon,
    this.action,
  });

  final String text;
  final bool busy;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const CircularProgressIndicator.adaptive()
        else if (icon != null)
          Icon(icon, size: 48, color: c.primary),
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
