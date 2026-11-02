import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/presentation/auth_text.dart';
import '../domain/share.dart';
import '../domain/share_repository.dart';
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
  const SharePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final intake = context.watch<ShareIntake>();
    void close() {
      intake.dismiss();
      context.go('/');
    }

    final body = switch (intake.state) {
      ShareIdle() => _Message(text: l.shareNone),
      ShareWaitingForLogin() => _Message(text: l.shareWaitingLogin),
      ShareSending() => _Message(text: l.shareSending, busy: true),
      ShareAccepted(:final id) => _Progress(key: ValueKey(id), id: id),
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

/// Polls the share now and every 3 s until the API has read it (or 3 minutes pass: it keeps going on the server).
class _Progress extends StatefulWidget {
  const _Progress({super.key, required this.id});

  final String id;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  static const _every = Duration(seconds: 3);
  static const _maxPolls = 60;
  Timer? _timer;
  Share? _share;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    _poll(); // a link shared before comes back done at once
    _timer = Timer.periodic(_every, (_) => _poll());
  }

  Future<void> _poll() async {
    if (++_polls > _maxPolls) return _stop();
    try {
      final s = await context.read<ShareRepository>().get(widget.id);
      if (!mounted) return;
      setState(() => _share = s);
      if (s.isFinished) _stop();
    } catch (_) {
      // Offline for a moment: the next tick tries again.
    }
  }

  void _stop() {
    _timer?.cancel();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = _share;
    if (s == null || !s.isFinished) {
      return _polls > _maxPolls
          ? _Message(text: l.shareStillWorking)
          : _Message(text: l.shareReading, busy: true);
    }
    if (s.status == 'failed' || s.gaps.contains('unreadable')) {
      return _Message(text: l.shareFailed, icon: Icons.error_outline);
    }
    return switch (s.kind) {
      'restaurant' => _Message(
        text: l.shareSavedPlace,
        icon: Icons.check_circle_outline,
      ),
      'recipe' => _Message(
        text: l.shareRecipeSoon,
        icon: Icons.menu_book_outlined,
      ),
      _ => _Message(text: l.shareNothingFound, icon: Icons.search_off),
    };
  }
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
          const CircularProgressIndicator()
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
