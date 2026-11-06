import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../router/book_page_transitions.dart';

/// Brand from the website (bukuresipi-astro global.css): a notebook page. Paper, ink, pale-blue rules, a red margin
/// line, pandan green, kunyit yellow. Familjen Grotesk for text; Caveat (handwriting) only for what a person would
/// write by hand: page titles, section headings, step numbers and the user's own notes.
abstract final class AppTheme {
  static const pandan = Color(0xFF2F6B3B);

  static ThemeData light() => _build(Notebook.light, Brightness.light);
  static ThemeData dark() => _build(Notebook.dark, Brightness.dark);

  static ThemeData _build(Notebook nb, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: pandan,
          brightness: brightness,
        ).copyWith(
          primary: nb.pandan,
          onPrimary: nb.paper,
          secondary: nb.kunyit,
          onSecondary: const Color(0xFF17231B),
          surface: nb.paper,
          onSurface: nb.ink,
          onSurfaceVariant: nb.inkSoft,
          outline: nb.rule,
          outlineVariant: nb.line,
          error: nb.margin,
          surfaceContainerLowest: nb.paper,
          surfaceContainerLow: nb.mist,
          surfaceContainer: nb.mist,
        );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: nb.paper,
    );
    final text = GoogleFonts.familjenGroteskTextTheme(base.textTheme)
        .apply(bodyColor: nb.ink, displayColor: nb.ink);
    return base.copyWith(
      textTheme: text,
      extensions: [
        nb.copyWith(
          hand: GoogleFonts.caveat(
            color: nb.pandanDeep,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: nb.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: nb.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: nb.paper,
        surfaceTintColor: Colors.transparent,
        indicatorColor: nb.mist,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? nb.pandanDeep
                : nb.inkSoft,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? nb.pandanDeep
                : nb.inkSoft,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: nb.rule, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: nb.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: nb.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: nb.pandan, width: 2),
        ),
        filled: true,
        fillColor: nb.paper,
        errorMaxLines: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      // Pandan, pill-shaped like the filled buttons: the book's one "new" action (Recipes > New recipe).
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: nb.pandan,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        // Compact: a 44 px pill, not Material's 56 px slab.
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 44),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
        extendedIconLabelSpacing: 8,
        iconSize: 20,
        extendedTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: nb.paper,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: nb.paper,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: nb.ink,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: BookPageTransitionsBuilder(),
          TargetPlatform.iOS: BookPageTransitionsBuilder(),
          TargetPlatform.macOS: BookPageTransitionsBuilder(),
          TargetPlatform.windows: BookPageTransitionsBuilder(),
          TargetPlatform.linux: BookPageTransitionsBuilder(),
          TargetPlatform.fuchsia: BookPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// The notebook's colours and handwriting. Read with `Notebook.of(context)`.
class Notebook extends ThemeExtension<Notebook> {
  const Notebook({
    required this.paper,
    required this.ink,
    required this.inkSoft,
    required this.rule,
    required this.margin,
    required this.pandan,
    required this.pandanDeep,
    required this.mist,
    required this.kunyit,
    required this.line,
    this.hand = const TextStyle(fontStyle: FontStyle.italic),
  });

  final Color paper,
      ink,
      inkSoft,
      rule,
      margin,
      pandan,
      pandanDeep,
      mist,
      kunyit,
      line;

  /// Handwriting (Caveat); plain italic until the theme sets it (tests).
  final TextStyle hand;

  static const light = Notebook(
    paper: Color(0xFFFFFFFF),
    ink: Color(0xFF17231B),
    inkSoft: Color(0xFF4A5A4F),
    rule: Color(0xFFCFE0F1),
    margin: Color(0xFFD23C35),
    pandan: Color(0xFF2F6B3B),
    pandanDeep: Color(0xFF1F4A29),
    mist: Color(0xFFEDF4EC),
    kunyit: Color(0xFFF6C945),
    line: Color(0xFFDFE7DD),
  );

  static const dark = Notebook(
    paper: Color(0xFF131A15),
    ink: Color(0xFFE6EDE7),
    inkSoft: Color(0xFFA3B2A7),
    rule: Color(0xFF26364A),
    margin: Color(0xFFB4504A),
    pandan: Color(0xFF7FBF8A),
    pandanDeep: Color(0xFFA6D7AE),
    mist: Color(0xFF1C2820),
    kunyit: Color(0xFFF6C945),
    line: Color(0xFF2A362D),
  );

  static Notebook of(BuildContext context) {
    final t = Theme.of(context);
    return t.extension<Notebook>() ??
        (t.brightness == Brightness.dark ? dark : light);
  }

  @override
  Notebook copyWith({TextStyle? hand}) => Notebook(
    paper: paper,
    ink: ink,
    inkSoft: inkSoft,
    rule: rule,
    margin: margin,
    pandan: pandan,
    pandanDeep: pandanDeep,
    mist: mist,
    kunyit: kunyit,
    line: line,
    hand: hand ?? this.hand,
  );

  @override
  Notebook lerp(Notebook? other, double t) =>
      t < 0.5 || other == null ? this : other;
}
