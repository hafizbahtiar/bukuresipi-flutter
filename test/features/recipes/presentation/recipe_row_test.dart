import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/widgets/recipe_rows.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recipes_fixtures.dart';

void main() {
  testWidgets('a recipe with no photo shows the cooking drawing', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ms')],
        home: Scaffold(body: RecipeRow(recipe: recipe())),
      ),
    );
    await t.pump();
    expect(find.byKey(const ValueKey('recipe-placeholder')), findsOneWidget);
  });
}
