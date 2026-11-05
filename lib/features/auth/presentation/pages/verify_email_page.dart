import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_text.dart';
import '../widgets/auth_cover.dart';
import '../widgets/auth_widgets.dart';

/// Opened from the confirmation email (App Link https://bukuresipi.com/auth/verify?token=...). Confirms at once:
/// only the user's own tap opens the app (mail scanners open the website, which waits for a button).
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.token});

  final String? token;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    final l = AppLocalizations.of(context);
    if ((widget.token ?? '').isEmpty) {
      return setState(() => _error = l.errInvalidToken);
    }
    try {
      await context.read<AuthController>().verifyEmail(widget.token!);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final signedIn =
        context.watch<AuthController>().status == AuthStatus.signedIn;
    return AuthCover(
      kicker: l.verifyTitle,
      children: [
        if (!_done && _error == null) ...[
          const Center(child: CircularProgressIndicator.adaptive()),
          const SizedBox(height: 16),
          Text(l.verifyWorking, textAlign: TextAlign.center),
        ],
        if (_done) FormMessage(l.verifyDone, success: true),
        if (_error != null) FormMessage(_error),
        if (_done || _error != null) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(signedIn ? '/account' : '/login'),
            child: Text(signedIn ? l.continueButton : l.toLoginButton),
          ),
        ],
      ],
    );
  }
}
