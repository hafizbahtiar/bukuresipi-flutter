import 'package:bukuresipi_flutter/core/theme/app_theme.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner_repository.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipe_variant.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/widgets/recipe_variants.dart';
import 'package:bukuresipi_flutter/features/shares/domain/share_repository.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../owner/owner_fixtures.dart';
import '../../shares/presentation/share_intake_test.dart' show FakeShares;
import '../recipes_fixtures.dart';

const kampung = RecipeVariant(
  id: 'v1',
  url: 'https://masak.example.my/kari-ayam',
  title: 'Kari Ayam Kampung',
  site: 'masak.example.my',
  lang: 'ms',
  match: 0.9,
  stepCount: 7,
  ingredients: [
    VariantIngredient(text: '1 ekor ayam', name: 'Ayam', confidence: 1),
    VariantIngredient(
      text: '400 ml coconut milk',
      name: 'Santan',
      confidence: 0.82,
    ),
    VariantIngredient(text: 'For the paste:'),
  ],
  adds: ['Kunyit'],
  lacks: ['Serai'],
);

Future<({FakeOwner owner, FakeShares shares})> pump(
  WidgetTester t, {
  required bool owner,
  List<RecipeVariant> stored = const [],
}) async {
  final ownerRepo = FakeOwner()..foundVariants = const [kampung];
  final shares = FakeShares();
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: RecipesController(FakeRecipes()..variantList = stored),
        ),
        Provider<OwnerRepository>.value(value: ownerRepo),
        Provider<ShareRepository>.value(value: shares),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ms')],
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeVariants(recipeId: 'd-1', owner: owner),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (owner: ownerRepo, shares: shares);
}

void main() {
  testWidgets('a user sees nothing until variants exist', (t) async {
    await pump(t, owner: false);
    expect(find.text('Recipe variants'), findsNothing);
  });

  testWidgets(
    'a variant shows its match, site, language, steps and ingredient difference',
    (t) async {
      await pump(t, owner: false, stored: const [kampung]);
      expect(find.text('Recipe variants'), findsOneWidget);
      expect(find.text('Find variants'), findsNothing);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('masak.example.my · MS · 7 steps'), findsOneWidget);
      expect(find.textContaining('+ kunyit'), findsOneWidget);
      expect(find.textContaining('− serai'), findsOneWidget);
    },
  );

  testWidgets(
    'the sheet lists each line with its link and certainty; Save sends the link to the book',
    (t) async {
      final fakes = await pump(t, owner: false, stored: const [kampung]);
      await t.tap(find.text('Kari Ayam Kampung'));
      await t.pumpAndSettle();
      expect(find.text('ayam'), findsOneWidget); // certain: no %
      expect(find.text('santan · 82% sure'), findsOneWidget);
      expect(find.text('not in the catalogue'), findsOneWidget);
      expect(find.text('7 steps, on the recipe\'s page'), findsOneWidget);
      await t.tap(find.text('Save to my book'));
      await t.pumpAndSettle();
      expect(fakes.shares.sent, ['link:https://masak.example.my/kari-ayam']);
    },
  );

  testWidgets('the owner finds variants', (t) async {
    final fakes = await pump(t, owner: true);
    expect(find.textContaining('No variants yet'), findsOneWidget);
    await t.tap(find.text('Find variants'));
    await t.pumpAndSettle();
    expect(fakes.owner.variantSearches, ['d-1']);
    expect(find.text('Kari Ayam Kampung'), findsOneWidget);
    expect(find.text('1 variant found'), findsOneWidget);
  });
}
