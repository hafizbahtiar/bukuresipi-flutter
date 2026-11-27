import 'package:bukuresipi_flutter/features/owner/domain/owner_repository.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_ingredient_list_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_ingredient_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../owner_fixtures.dart';

// Owner > Ingredients and other names: the list, and one ingredient's page (rename, category, add / remove / split
// another name, look-alikes).
void main() {
  late FakeOwner repo;
  setUp(() {
    repo = FakeOwner()
      ..ingredientRows = const [
        (id: 26, name: 'Limau', category: 'Buah', aliases: 1),
        (id: 1, name: 'Beras putih', category: 'Beras', aliases: 2),
        (id: 7, name: 'Bawang merah', category: 'Bahan asas', aliases: 0),
      ]
      ..details = {
        26: (
          id: 26,
          name: 'Limau',
          category: 'Buah',
          aliases: const ['limau nipis'],
          recipeLines: 12,
          shoppingLines: 3,
          similar: const [
            (id: 55, name: 'Daun limau purut', category: 'Bahan asas'),
          ],
        ),
        55: (
          id: 55,
          name: 'Daun limau purut',
          category: 'Bahan asas',
          aliases: const ['daun limau'],
          recipeLines: 4,
          shoppingLines: 0,
          similar: const [],
        ),
      };
  });

  Future<void> pump(WidgetTester t, String at) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    final router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(
          path: '/all',
          builder: (_, _) => const OwnerIngredientListPage(),
        ),
        GoRoute(
          path: '/owner/ingredient/:id',
          builder: (_, s) =>
              OwnerIngredientPage(id: int.parse(s.pathParameters['id']!)),
        ),
      ],
    );
    await t.pumpWidget(
      Provider<OwnerRepository>.value(
        value: repo,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'the list: every ingredient with its category and other names; search narrows; a tap opens it',
    (t) async {
      await pump(t, '/all');
      expect(find.text('Limau'), findsOneWidget);
      expect(find.text('Buah · 1 other names'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('ingredients-search')),
        'bawang',
      );
      await t.pump();
      expect(find.text('Limau'), findsNothing);
      expect(find.text('Bawang merah'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('ingredients-search')),
        'lim',
      );
      await t.pump();
      await t.tap(find.text('Limau'));
      await t.pumpAndSettle();
      expect(find.text('Other names'), findsOneWidget);
      expect(find.text('limau nipis'), findsOneWidget);
    },
  );

  testWidgets(
    'a name that is another food becomes its own ingredient: asks with the count first',
    (t) async {
      repo.splitAnswer = (
        lines: 2,
        sample: const ['2 biji limau nipis', 'limau nipis'],
      );
      await pump(t, '/owner/ingredient/26');
      await t.longPress(find.byKey(const ValueKey('alias-limau nipis')));
      await t.pumpAndSettle();
      await t.tap(find.text('Make it its own ingredient'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('2 lines that say it move there'),
        findsOneWidget,
      );
      await t.tap(
        find.text('Make it its own ingredient').last,
      ); // the dialog's button
      await t.pumpAndSettle();
      expect(repo.ingredientCalls, ['split 26 limau nipis']);
      expect(find.text('Limau nipis added. 2 lines moved.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('alias-limau nipis')),
        findsNothing,
      ); // read again
    },
  );

  testWidgets(
    'a wrong name is removed: asks with how many lines go back to the gaps',
    (t) async {
      repo.removeAnswer = (lines: 3, sample: const ['2 biji limau nipis']);
      await pump(t, '/owner/ingredient/26');
      await t.longPress(find.byKey(const ValueKey('alias-limau nipis')));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove this name'));
      await t.pumpAndSettle();
      expect(find.textContaining('3 lines'), findsOneWidget);
      await t.tap(find.text('Remove this name').last); // the dialog's button
      await t.pumpAndSettle();
      expect(repo.ingredientCalls, ['remove 26 limau nipis']);
      expect(find.text('Removed. 3 lines unlinked.'), findsOneWidget);
    },
  );

  testWidgets(
    'edit: a new name and category; add another name; a look-alike opens its own page',
    (t) async {
      await pump(t, '/owner/ingredient/26');
      await t.tap(find.byKey(const ValueKey('ingredient-edit')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('ingredient-name')),
        'Limau kasturi',
      );
      await t.tap(find.byKey(const ValueKey('ingredient-save')));
      await t.pumpAndSettle();
      expect(repo.ingredientCalls, ['update 26 Limau kasturi Buah']);

      await t.tap(find.byKey(const ValueKey('alias-add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('alias-new')), 'lime');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('alias-save')));
      await t.pumpAndSettle();
      expect(repo.aliases, [('Limau kasturi', 'lime')]);

      await t.scrollUntilVisible(find.text('Daun limau purut'), 200);
      await t.tap(find.text('Daun limau purut'));
      await t.pumpAndSettle();
      expect(find.text('daun limau'), findsOneWidget);
    },
  );
}
