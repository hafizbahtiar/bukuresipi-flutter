import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/passkey_auth.dart';
import '../auth_controller.dart';
import '../auth_text.dart';

/// "Sign in with a passkey" on the login cover: the phone's fingerprint / screen-lock sheet, no email typed.
/// Hidden when the app has no PasskeyAuth (not Android 9+).
class PasskeyButton extends StatefulWidget {
  const PasskeyButton({super.key, required this.onError});

  /// The error text to show on the cover (null clears it).
  final ValueChanged<String?> onError;

  @override
  State<PasskeyButton> createState() => _PasskeyButtonState();
}

class _PasskeyButtonState extends State<PasskeyButton> {
  bool _busy = false;

  Future<void> _go(PasskeyAuth passkeys) async {
    final l = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    setState(() => _busy = true);
    widget.onError(null);
    try {
      await auth.loginWithPasskey(passkeys); // signed in: the router moves on
    } catch (e) {
      widget.onError(errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passkeys = context.watch<PasskeyAuth?>();
    if (passkeys == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final nb = Notebook.light; // the cover is always light
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(
        key: const ValueKey('passkey-sign-in'),
        onPressed: _busy ? null : () => _go(passkeys),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: nb.pandanDeep,
          side: BorderSide(color: nb.pandan),
          textStyle: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: _busy
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: nb.pandan,
                ),
              )
            : const Icon(Icons.fingerprint, size: 20),
        label: Text(l.passkeySignIn, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
