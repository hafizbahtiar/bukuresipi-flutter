import 'dart:async';
import 'dart:math' as math;

import 'package:bukuresipi_flutter/core/widgets/cover_app_bar.dart';
import 'package:bukuresipi_flutter/features/recipes/domain/recipe.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:bukuresipi_flutter/features/recipes/presentation/recipes_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../recipes_fixtures.dart';
import 'recipe_pages_test.dart' show app;

double titleOpacity(WidgetTester t, String name) => t
    .widget<Opacity>(
      find.ancestor(
        of: find.descendant(
          of: find.byType(CoverAppBar),
          matching: find.text(name),
        ),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets(
    'with a cover: the photo is the top bar; the name joins the bar once it scrolls away; tabs still work',
    (t) async {
      final fake = FakeRecipes()..detailResult = recipeDetail(cover: 'cv-1');
      await t.pumpWidget(
        app(
          providers: [
            ChangeNotifierProvider.value(value: RecipesController(fake)),
          ],
          home: const RecipeDetailPage(id: 'r-1'),
        ),
      );
      await t.pumpAndSettle();
      final name = fake.detailResult!.name;
      expect(find.byType(CoverAppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(titleOpacity(t, name), 0); // open: the name is under the photo
      await t.drag(find.byType(NestedScrollView), const Offset(0, -500));
      await t.pumpAndSettle();
      expect(titleOpacity(t, name), 1); // collapsed: in the bar
      // The pinned pill is below the bar and still switches.
      await t.tap(find.byKey(const ValueKey('recipe-tab-steps')));
      await t.pumpAndSettle();
      expect(find.text('Goreng ayam hingga masak.'), findsOneWidget);
    },
  );

  testWidgets('without a photo: a plain bar, the title starts the page', (
    t,
  ) async {
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
    expect(find.byType(CoverAppBar), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets(
    'opened from a card with a photo: the header (hero target) is there while the recipe loads',
    (t) async {
      final fake = FakeRecipes()
        ..detailResult = recipeDetail(cover: 'cv-1')
        ..detailGate = Completer<void>();
      await t.pumpWidget(
        app(
          providers: [
            ChangeNotifierProvider.value(value: RecipesController(fake)),
          ],
          home: const RecipeDetailPage(
            id: 'r-1',
            preview: RecipePreview(name: 'Kari Ayam', cover: 'cv-1'),
          ),
        ),
      );
      await t.pump();
      expect(find.byType(CoverAppBar), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == recipePhotoTag('r-1'),
        ),
        findsOneWidget,
      );
      fake.detailGate!.complete();
      await t.pumpAndSettle();
      expect(
        find.byType(CoverAppBar),
        findsOneWidget,
      ); // the same header, now with the recipe under it
    },
  );

  testWidgets(
    'with tabs and a long list: the bar stays once collapsed, and the list starts below it and the pill',
    (t) async {
      final fake = FakeRecipes()
        ..detailResult = recipeDetail(
          cover: 'cv-1',
          ingredients: [
            for (var i = 0; i < 40; i++)
              RecipeIngredient(name: 'Bahan $i', rawText: 'bahan $i'),
          ],
        );
      await t.pumpWidget(
        app(
          providers: [
            ChangeNotifierProvider.value(value: RecipesController(fake)),
          ],
          home: const RecipeDetailPage(id: 'r-1'),
        ),
      );
      await t.pumpAndSettle();
      final scroll = find.byType(NestedScrollView);
      double topOfLines() => find
          .textContaining('ahan ')
          .evaluate()
          .map((e) => t.getRect(find.byWidget(e.widget)).top)
          .reduce(math.min);
      final pill = find.byKey(const ValueKey('recipe-tab-ingredients'));
      final openGap = topOfLines() - t.getRect(pill).bottom;

      // Far down: the bar is still there, with the back button.
      await t.drag(scroll, const Offset(0, -1500));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(AppBar)).height, kToolbarHeight);
      expect(t.getTopLeft(find.byType(BackButton)).dy, greaterThanOrEqualTo(0));

      // The list back at its start, the photo still collapsed: its first line is below the pill, not under it.
      final inner = t
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(PageView),
                  matching: find.byType(Scrollable),
                )
                .at(1),
          )
          .position;
      await t.drag(scroll, Offset(0, inner.pixels));
      await t.pumpAndSettle();
      expect(topOfLines(), greaterThanOrEqualTo(t.getRect(pill).bottom));

      // Back at the top: as it opened (no extra gap above the list).
      await t.drag(scroll, const Offset(0, 3000));
      await t.pumpAndSettle();
      expect(topOfLines() - t.getRect(pill).bottom, closeTo(openGap, 0.5));
    },
  );

  for (final tabs in [true, false]) {
    testWidgets(
      'with a cover (tabs: $tabs): a hard pull down closes the page, a small one does not',
      (t) async {
        final fake = FakeRecipes()
          ..detailResult = recipeDetail(
            cover: 'cv-1',
            steps: tabs
                ? const [RecipeStep(stepNo: 1, instruction: 'x')]
                : const [],
          );
        await t.pumpWidget(
          app(
            providers: [
              ChangeNotifierProvider.value(value: RecipesController(fake)),
            ],
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecipeDetailPage(id: 'r-1'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        final page = find.byType(RecipeDetailPage);
        final scroll = find
            .byType(tabs ? NestedScrollView : CustomScrollView)
            .first;

        await t.drag(scroll, const Offset(0, 60));
        await t.pumpAndSettle();
        expect(page, findsOneWidget);

        await t.drag(scroll, const Offset(0, 400));
        await t.pumpAndSettle();
        expect(page, findsNothing);
        expect(find.text('open'), findsOneWidget);
      },
    );
  }
}
