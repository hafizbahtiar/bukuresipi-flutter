import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/settings/locale_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/google_auth.dart';
import '../auth_controller.dart';
import '../auth_text.dart';

/// "Continue with Google" for the login and register covers: one button signs in or up (the API decides).
/// Hidden when the app has no GoogleAuth (not Android, or no client id in .env).
class GoogleButton extends StatefulWidget {
  const GoogleButton({super.key, required this.onError});

  /// The error text to show on the cover (null clears it).
  final ValueChanged<String?> onError;

  @override
  State<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<GoogleButton> {
  bool _busy = false;

  Future<void> _go(GoogleAuth google) async {
    final l = AppLocalizations.of(context);
    final auth = context.read<AuthController>();
    final lang = context.read<LocaleController>().lang;
    setState(() => _busy = true);
    widget.onError(null);
    try {
      final token = await google.idToken();
      if (token == null) return; // closed the sheet
      await auth.loginWithGoogle(token, lang); // the router moves on
    } catch (e) {
      widget.onError(errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final google = context.watch<GoogleAuth?>();
    if (google == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final family = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    final rule = Expanded(child: Divider(color: Notebook.light.rule));
    final button = OutlinedButton(
      onPressed: _busy ? null : () => _go(google),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F), // Google's button text colour
        side: const BorderSide(color: Color(0xFF747775)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: TextStyle(
          fontFamily: family,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: _busy
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Notebook.light.pandan,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Google's own "G" (the 2025 gradient), cut from its sign-in asset pack
                // (developers.google.com/identity/branding-guidelines); 20 dp, as the guidelines say.
                Image.asset('assets/brand/google_g.png', width: 20, height: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l.googleContinue,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              rule,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  l.orDivider,
                  style: TextStyle(
                    fontFamily: family,
                    fontSize: 12,
                    color: Notebook.light.inkSoft,
                  ),
                ),
              ),
              rule,
            ],
          ),
        ),
        button,
      ],
    );
  }
}
