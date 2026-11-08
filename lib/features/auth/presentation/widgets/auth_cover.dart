import 'dart:math';

import '../../../../core/constants/image_constant.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// The outside of the book, shared by every signed-out screen. The current action is the small sticker;
/// the page's form is written on the paper label.
class AuthCover extends StatelessWidget {
  const AuthCover({
    super.key,
    required this.kicker,
    required this.children,
    this.subtitle,
    this.footer,
    this.top,
    this.showBack = false,
    this.bottomAligned = false,
    this.onBack,
  });

  /// The action, printed on the small sticker ("LOG MASUK", "DAFTAR AKAUN"...).
  final String kicker;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  /// Printed above the sticker: the cover's brand mark on pages with room at the top.
  final Widget? top;
  final bool showBack;

  /// Puts the label at the bottom of the cover (thumb reach) when the page is shorter than the screen.
  final bool bottomAligned;

  /// Overrides what the back arrow does (a deep-linked page has nothing to pop).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hand = Notebook.of(context).hand
        .copyWith(fontSize: 46, height: 0.95, color: Notebook.light.pandanDeep);
    final base = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.light()
        : Theme.of(context);
    final family = base.textTheme.bodyMedium?.fontFamily;
    final labelTheme = base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        errorMaxLines: 2,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Notebook.light.rule, width: 1.2),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Notebook.light.rule, width: 1.2),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Notebook.light.pandan, width: 2),
        ),
        errorStyle: TextStyle(
          fontFamily: family,
          fontSize: 11,
          height: 1.2,
          color: Notebook.light.margin,
        ),
        labelStyle: TextStyle(
          fontFamily: family,
          color: Notebook.light.inkSoft,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: family,
          color: Notebook.light.pandanDeep,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: TextStyle(
          fontFamily: family,
          fontSize: 11,
          color: Notebook.light.inkSoft,
        ),
        counterStyle: TextStyle(
          fontFamily: family,
          fontSize: 11,
          color: Notebook.light.inkSoft,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: Notebook.light.pandan,
          foregroundColor: Notebook.light.paper,
          disabledBackgroundColor: Notebook.light.pandan.withValues(
            alpha: 0.55,
          ),
          disabledForegroundColor: Notebook.light.paper,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: ColoredBox(color: AppTheme.pandan)),
            const Positioned.fill(child: CustomPaint(painter: _CoverTexture())),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 30,
              child: _Spine(),
            ),
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 9,
              child: _PageEdge(),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(48, 26, 28, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 430,
                        minHeight: bottomAligned
                            ? max(0.0, constraints.maxHeight - 50)
                            : 0.0,
                      ),
                      child: Column(
                        mainAxisAlignment: bottomAligned
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (top != null) ...[
                            top!,
                            const SizedBox(height: 28),
                          ],
                          SizedBox(
                            height: 40,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                if (showBack)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      tooltip: MaterialLocalizations.of(context)
                                          .backButtonTooltip,
                                      onPressed:
                                          onBack ??
                                          () => Navigator.maybePop(context),
                                      icon: const Icon(Icons.arrow_back),
                                      color: Notebook.light.paper,
                                      iconSize: 20,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 40,
                                            height: 40,
                                          ),
                                    ),
                                  ),
                                _KickerLabel(text: kicker.toUpperCase()),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _NameLabel(
                            child: Theme(
                              data: labelTheme,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l.appName,
                                    textAlign: TextAlign.center,
                                    style: hand,
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.35,
                                        color: Notebook.light.inkSoft,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 1,
                                    color: Notebook.light.rule,
                                  ),
                                  const SizedBox(height: 14),
                                  ...children,
                                ],
                              ),
                            ),
                          ),
                          if (footer != null) ...[
                            const SizedBox(height: 18),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The brand mark printed on the cover: the book-and-pin seal, the wordmark, and a kunyit rule.
class CoverBrand extends StatelessWidget {
  const CoverBrand({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 96,
        height: 96,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Notebook.light.paper,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            ImageConstant.appIcon,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        AppLocalizations.of(context).appName.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 6.5,
          fontWeight: FontWeight.w800,
          color: Notebook.light.paper.withValues(alpha: 0.88),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: 34,
        height: 2,
        color: Notebook.light.kunyit.withValues(alpha: 0.85),
      ),
    ],
  );
}

/// A line printed on the cover, below the label. Plain text, not a button: the whole line is the tap target.
class CoverLink extends StatefulWidget {
  const CoverLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
    this.iconBefore = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  /// A back link ("Sign in") puts its arrow before the words, pointing the way back.
  final bool iconBefore;

  @override
  State<CoverLink> createState() => _CoverLinkState();
}

class _CoverLinkState extends State<CoverLink> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    onTap: widget.onPressed,
    child: ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedOpacity(
          opacity: _down ? 0.55 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.iconBefore) ...[
                  Icon(widget.icon, size: 16, color: Notebook.light.kunyit),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Notebook.light.paper,
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (!widget.iconBefore) ...[
                  const SizedBox(width: 6),
                  Icon(widget.icon, size: 16, color: Notebook.light.kunyit),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The cover is a physical object: it keeps the light paper palette even in dark mode, like the splash.
class _CoverTexture extends CustomPainter {
  const _CoverTexture();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(19);
    final bigLight = Paint()
      ..color = const Color(0xFF8CC196).withValues(alpha: 0.05);
    final bigDark = Paint()
      ..color = const Color(0xFF142E1B).withValues(alpha: 0.08);
    for (var i = 0; i < 80; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final w = 12 + rnd.nextDouble() * 46;
      final h = 5 + rnd.nextDouble() * 14;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(rnd.nextDouble() * pi);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        i.isEven ? bigLight : bigDark,
      );
      canvas.restore();
    }
    final light = Paint()
      ..color = const Color(0xFF6FA57B).withValues(alpha: 0.12);
    final dark = Paint()
      ..color = const Color(0xFF1B3D24).withValues(alpha: 0.18);
    for (var i = 0; i < 1200; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final w = 1.2 + rnd.nextDouble() * 4.5;
      final h = 0.8 + rnd.nextDouble() * 2.2;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(rnd.nextDouble() * pi);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        i.isEven ? light : dark,
      );
      canvas.restore();
    }
    final vignette = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.45, -0.6),
        radius: 1.15,
        colors: [Color(0x14FFFFFF), Color(0x00000000), Color(0x33000000)],
        stops: [0, 0.6, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The dark tape down the left edge, as on an exercise book.
class _Spine extends StatelessWidget {
  const _Spine();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0C160F), Color(0xFF18291C), Color(0xFF0C160F)],
        stops: [0, 0.75, 1],
      ),
      border: Border(
        right: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(5, 0),
        ),
      ],
    ),
  );
}

/// The closed page block on the right, so the cover reads as a book, not a card.
class _PageEdge extends StatelessWidget {
  const _PageEdge();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _PageEdgePainter());
}

class _PageEdgePainter extends CustomPainter {
  const _PageEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF3EEDF));
    final line = Paint()
      ..color = const Color(0xFF17231B).withValues(alpha: 0.10)
      ..strokeWidth = 0.6;
    for (var x = 0.5; x < size.width; x += 1.6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    final shade = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x33000000), Color(0x00000000)],
      ).createShader(rect);
    canvas.drawRect(rect, shade);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The small printed label ("LOG MASUK"), like the "college ruled" label on a composition book.
class _KickerLabel extends StatelessWidget {
  const _KickerLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.012,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Notebook.light.paper,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Notebook.light.ink.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 2.6,
          fontWeight: FontWeight.w800,
          color: Notebook.light.ink,
        ),
      ),
    ),
  );
}

/// The pasted paper label: double rule, ruled fields, a strip of tape at the top.
class _NameLabel extends StatelessWidget {
  const _NameLabel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Notebook.light.paper,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Notebook.light.ink.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Notebook.light.ink.withValues(alpha: 0.14),
            ),
          ),
          child: child,
        ),
      ),
      Positioned(
        top: -10,
        left: 26,
        child: Transform.rotate(
          angle: -0.06,
          child: Container(
            width: 62,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.40),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
