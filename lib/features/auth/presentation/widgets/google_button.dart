import 'dart:math' as math;

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
                const SizedBox.square(
                  dimension: 18,
                  child: CustomPaint(painter: _GoogleG()),
                ),
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

/// The four-colour Google "G" (drawn, so no image asset or SVG package): blue, green, yellow, red arcs and the bar.
class _GoogleG extends CustomPainter {
  const _GoogleG();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (s - stroke) / 2,
    );
    Paint p(int c) => Paint()
      ..color = Color(c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    double deg(double d) => d * math.pi / 180;
    canvas
      ..drawArc(rect, deg(-40), deg(85), false, p(0xFF4285F4)) // blue, right
      ..drawArc(rect, deg(45), deg(90), false, p(0xFF34A853)) // green, bottom
      ..drawArc(rect, deg(135), deg(90), false, p(0xFFFBBC05)) // yellow, left
      ..drawArc(rect, deg(225), deg(95), false, p(0xFFEA4335)) // red, top
      ..drawRect(
        Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2 - stroke / 4, stroke),
        Paint()..color = const Color(0xFF4285F4),
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
