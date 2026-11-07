import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/owner/domain/owner_repository.dart';
import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/places/presentation/pages/places_list_page.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:bukuresipi_flutter/features/shares/presentation/recent_shares.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/recipe_edit_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../places/places_fixtures.dart';
import '../../shares/presentation/share_intake_test.dart' show FakeShares;
import '../recipes_fixtures.dart';
import '../../../fakes.dart';
import '../../owner/owner_fixtures.dart';

Widget app({
  required List<SingleChildWidget> providers,
  required Widget home,
}) => MultiProvider(
  providers: providers,
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ms')],
    home: home,
  ),
);

void main() {
  testWidgets('the book lists places and recipes together, newest first', (
    t,
  ) async {
    // Place from 2026-11-02 (fixture), recipe from the day after: the recipe comes first.
    final places = PlacesController(FakePlaces()..places = [place(id: 'p')]);
    final recipes = RecipesController(
      FakeRecipes()
        ..recipes = [
          recipe(),
          recipe(id: 'r-2', name: 'Ayam Rebus Pedas', stepCount: 0),
        ],
    );
    final recent = RecentShares(FakeShares(), onFinished: () async {});
    await places.load();
    await recipes.load();

    await t.pumpWidget(
      app(
        providers: [
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider.value(value: recipes),
          ChangeNotifierProvider.value(value: recent),
        ],
        home: const PlacesListPage(),
      ),
    );
    await t.pump();

    expect(find.text('Recipes'), findsNothing, reason: 'no separate section');
    expect(find.byIcon(Icons.storefront), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsNWidgets(2));
    expect(find.text('2 ingredients · 2 steps'), findsOneWidget);
    expect(find.text('2 ingredients'), findsOneWidget, reason: 'no "0 steps"');
    double y(String s) => t.getTopLeft(find.text(s)).dy;
    expect(y('Nasi Lemak Ayam'), lessThan(y('Nasi Kandar Pelita')));
  });

  testWidgets('the recipe page shows its ingredients, steps and missing note', (
    t,
  ) async {
    final recipes = RecipesController(
      FakeRecipes()..detailResult = recipeDetail(),
    );
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Nasi Lemak Ayam'), findsOneWidget);
    expect(find.textContaining('Not everything was found'), findsOneWidget);
    expect(find.textContaining('500 g'), findsOneWidget);
    expect(find.textContaining('sedikit bahan rahsia'), findsOneWidget);
    expect(find.text('Goreng ayam hingga masak.'), findsOneWidget);
    expect(find.text('Open video'), findsOneWidget);
  });

  testWidgets(
    'no photo: the owner gets "Add photo", a reader sees just the title',
    (t) async {
      for (final (canEdit, chips) in [(true, 1), (false, 0)]) {
        final recipes = RecipesController(
          FakeRecipes()..detailResult = recipeDetail(canEdit: canEdit),
        );
        await t.pumpWidget(
          app(
            providers: [ChangeNotifierProvider.value(value: recipes)],
            home: RecipeDetailPage(key: ValueKey(canEdit), id: 'r-1'),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('recipe-add-cover')),
          findsNWidgets(chips),
        );
      }
    },
  );

  testWidgets('a recipe with no steps shows no Steps heading', (t) async {
    final recipes = RecipesController(
      FakeRecipes()..detailResult = recipeDetail(steps: const []),
    );
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Steps'), findsNothing);
    expect(
      find.text('Allergens'),
      findsNothing,
    ); // none found: no section, never "safe"
  });

  testWidgets(
    'allergens found are listed with the label warning and the unchecked count',
    (t) async {
      final recipes = RecipesController(
        FakeRecipes()
          ..detailResult = recipeDetail(
            allergens: const [
              RecipeAllergen(name: 'Susu', ingredients: ['Susu segar']),
            ],
          ),
      );
      await t.pumpWidget(
        app(
          providers: [ChangeNotifierProvider.value(value: recipes)],
          home: const RecipeDetailPage(id: 'r-1'),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Allergens'), findsOneWidget);
      expect(find.textContaining('Susu segar'), findsOneWidget);
      expect(
        find.textContaining('Always check product labels.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ingredients not checked: 1.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a recipe is removed only after confirming', (t) async {
    final fake = FakeRecipes()
      ..recipes = [recipe()]
      ..detailResult = recipeDetail();
    final recipes = RecipesController(fake);
    await recipes.load();
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Remove from my book'));
    await t.pumpAndSettle();
    expect(fake.deleted, isEmpty);
    await t.tap(find.widgetWithText(FilledButton, 'Remove'));
    await t.pumpAndSettle();
    expect(fake.deleted, ['r-1']);
    expect(recipes.recipes, isEmpty);
  });

  testWidgets('a recipe load error shows a notice while places still list', (
    t,
  ) async {
    final places = PlacesController(FakePlaces()..places = [place(id: 'p')]);
    final fake = FakeRecipes()..error = const ApiException('network');
    final recipes = RecipesController(fake);
    final recent = RecentShares(FakeShares(), onFinished: () async {});
    await places.load();
    await recipes.load();

    await t.pumpWidget(
      app(
        providers: [
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider.value(value: recipes),
          ChangeNotifierProvider.value(value: recent),
        ],
        home: const PlacesListPage(),
      ),
    );
    await t.pump();

    expect(find.text('Nasi Kandar Pelita'), findsOneWidget);
    expect(find.text('Could not load your recipes.'), findsOneWidget);

    fake
      ..error = null
      ..recipes = [recipe()];
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Could not load your recipes.'), findsNothing);
    expect(find.text('Nasi Lemak Ayam'), findsOneWidget);
  });

  testWidgets('a recipe that is gone says so', (t) async {
    final recipes = RecipesController(
      FakeRecipes()..detailError = const ApiException('not_found', status: 404),
    );
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();

    expect(find.textContaining('no longer in your book'), findsOneWidget);
  });

  testWidgets('tapping an ingredient line links it to a catalogue ingredient', (
    t,
  ) async {
    final repo = FakeRecipes()..detailResult = recipeDetail();
    final recipes = RecipesController(repo);
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: recipes)],
        home: const RecipeDetailPage(id: 'r-1'),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.textContaining('sedikit bahan rahsia'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'susu');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    await t.tap(find.text('Susu segar'));
    await t.pumpAndSettle();
    expect(repo.linked, [('r-1', 1, 'Susu segar')]);
  });

  testWidgets(
    'the editor: one row per line, dragged to reorder, removed, and Enter or a paste splits a row',
    (t) async {
      final fake = FakeRecipes()..detailResult = recipeDetail();
      await t.pumpWidget(
        app(
          providers: [
            ChangeNotifierProvider.value(value: RecipesController(fake)),
          ],
          home: const RecipeDetailPage(id: 'r-1'),
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, '500g ayam'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Name'), '  ');
      await t.tap(find.text('Save'));
      await t.pump();
      expect(find.text('Give the recipe a name.'), findsOneWidget);
      expect(fake.edited, isEmpty);
      await t.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Nasi Lemak Sambal',
      );

      // Drag the first ingredient below the second.
      final drag = await t.startGesture(
        t.getCenter(find.byIcon(Icons.drag_indicator).first),
      );
      await t.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 4; i++) {
        await drag.moveBy(const Offset(0, 30));
        await t.pump(const Duration(milliseconds: 50));
      }
      await drag.up();
      await t.pumpAndSettle();

      // Replace the step with two typed on one row.
      await t.tap(find.byTooltip('Remove').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Add step'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextField).last,
        'Masak nasi.\n  Goreng ayam. ',
      );
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Goreng ayam.'),
        findsOneWidget,
      ); // each pasted line trimmed

      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      final (id, name, ingredients, steps) = fake.edited.single;
      expect([id, name], ['r-1', 'Nasi Lemak Sambal']);
      expect(ingredients, ['sedikit bahan rahsia', '500g ayam']);
      expect(steps, ['Masak nasi.', 'Goreng ayam.']);
      expect(find.text('Save'), findsNothing); // back on the recipe
    },
  );

  testWidgets(
    'someone else\'s public recipe: no edit or remove; copy it or report it',
    (t) async {
      final fake = FakeRecipes()
        ..detailResult = recipeDetail(
          canEdit: false,
          visibility: RecipeVisibility.public,
          owner: const RecipeOwner(name: 'Siti', isMe: false),
        );
      final recipes = RecipesController(fake);
      await t.pumpWidget(
        app(
          providers: [ChangeNotifierProvider.value(value: recipes)],
          home: const RecipeDetailPage(id: 'r-1'),
        ),
      );
      await t.pumpAndSettle();
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.textContaining(l.recipeBy('Siti')), findsOneWidget);
      expect(find.byTooltip('Remove from my book'), findsNothing);
      expect(find.text(l.recipeEdit), findsNothing);
      await t.tap(find.text(l.report));
      await t.pumpAndSettle();
      await t.tap(find.text(l.reasonCopyright));
      await t.pumpAndSettle();
      expect(fake.reports, [('r-1', 'copyright')]);
      expect(
        find.text(l.recipeCopy),
        findsOneWidget,
      ); // opens the copy through the router (not in this harness)
    },
  );

  test('typingWord and completeLine: the word being typed, and the line completed with a catalogue name', () {
    expect(typingWord('2 cawan tep'), 'tep');
    expect(typingWord('2 cawan tepung '), isNull);
    expect(typingWord('2 c'), isNull);
    expect(
      completeLine('2 cawan tepung ga', 'Tepung gandum'),
      '2 cawan tepung gandum',
    );
    expect(completeLine('3 biji tel', 'Telur'), '3 biji telur');
    expect(completeLine('gul', 'Gula'), 'gula');
  });

  testWidgets(
    'the editor suggests catalogue ingredients while typing; a tap completes the line',
    (t) async {
      final fake = FakeRecipes()
        ..detailResult = recipeDetail()
        ..ingredientNames = ['Tepung gandum', 'Tepung beras'];
      await t.pumpWidget(
        app(
          providers: [
            ChangeNotifierProvider.value(value: RecipesController(fake)),
          ],
          home: const RecipeEditPage(),
        ),
      );
      await t.pumpAndSettle();
      final ingredientRow = find.byType(TextField).at(1);
      await t.enterText(ingredientRow, '2 cawan tep');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      expect(find.text('tepung beras'), findsOneWidget);
      await t.tap(find.text('tepung gandum'));
      await t.pump();
      expect(
        find.widgetWithText(TextField, '2 cawan tepung gandum'),
        findsOneWidget,
      );
      expect(find.text('tepung beras'), findsNothing);
    },
  );

  for (final owner in [true, false]) {
    testWidgets(
      'someone else\'s public recipe: ${owner ? 'the owner hides it' : 'a user reports it'}',
      (t) async {
        final auth = AuthController(
          FakeAuthRepository()
            ..session = true
            ..meResult = User(
              id: 'u-1',
              email: 'a@example.com',
              name: 'Ali',
              role: owner ? 'owner' : 'user',
              lang: 'ms',
              emailVerified: true,
            ),
        );
        await auth.restore();
        final ownerRepo = FakeOwner();
        final recipes = RecipesController(
          FakeRecipes()
            ..detailResult = recipeDetail(
              canEdit: false,
              visibility: RecipeVisibility.public,
              owner: const RecipeOwner(name: 'Siti', isMe: false),
            ),
        );
        await t.pumpWidget(
          app(
            providers: [
              ChangeNotifierProvider.value(value: recipes),
              ChangeNotifierProvider.value(value: auth),
              Provider<OwnerRepository>.value(value: ownerRepo),
            ],
            home: const RecipeDetailPage(id: 'r-1'),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Hide'), owner ? findsOneWidget : findsNothing);
        expect(find.text('Report'), owner ? findsNothing : findsOneWidget);
        if (!owner) return;
        await t.tap(find.text('Hide'));
        await t.pumpAndSettle();
        await t.tap(find.text('Hide').last);
        await t.pumpAndSettle();
        expect(ownerRepo.hiddenRecipes, ['r-1']);
      },
    );
  }

  testWidgets(
    'a catalogue dish credits its source and sends the steps to the original recipe',
    (t) async {
      final recipes = RecipesController(
        FakeRecipes()
          ..detailResult = recipeDetail(
            canEdit: false,
            missing: const [],
            steps: const [],
            sourceType: RecipeSourceType.catalogue,
            sourceUrl: 'https://khairulaming.my/rendang-1-ekor-ayam',
          ),
      );
      await t.pumpWidget(
        app(
          providers: [ChangeNotifierProvider.value(value: recipes)],
          home: const RecipeDetailPage(id: 'r-1'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Bukuresipi catalogue · ingredients from khairulaming.my'),
        findsOneWidget,
      );
      await t.scrollUntilVisible(
        find.text('How to cook: see the original recipe'),
        200,
      );
      expect(find.text('How to cook: see the original recipe'), findsOneWidget);
      expect(find.text('Original recipe'), findsOneWidget);
      expect(find.text('Open video'), findsNothing);
    },
  );
}
