import 'package:bukuresipi_flutter/core/widgets/notebook.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/nearby_sheet.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../fakes.dart';
import '../places_fixtures.dart';

Widget app({
  required Widget home,
  required List<SingleChildWidget> providers,
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
  testWidgets('edit from the nearby sheet is personal to this user', (t) async {
    final repo = FakePlaces()..places = [place(id: 'p')];
    final controller = PlacesController(repo);
    await controller.load();
    final auth = AuthController(FakeAuthRepository()..session = true);
    await auth.restore();
    var edited = false;

    await t.pumpWidget(
      app(
        providers: [
          ChangeNotifierProvider.value(value: controller),
          ChangeNotifierProvider.value(value: auth),
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showNotebookSheet<void>(
                  context,
                  builder: (_) => NearbySheet(
                    place: nearbyBranch(),
                    onSave: () async {},
                    onEdited: () async => edited = true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Edit branch'));
    await t.pumpAndSettle();

    expect(find.text('Only you will see these changes.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('branch-label')), 'My Branch');
    // The nearby sheet's Save is still in the tree underneath the edit sheet.
    final save = find.widgetWithText(FilledButton, 'Save').last;
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.label, 'My Branch');
    expect(repo.branchUpdates.single.scope, BranchEditScope.personal);
    expect(edited, isTrue);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'the nearby sheet shows the branch, distance and halal, then saves',
    (t) async {
      final repo = FakePlaces()
        ..places = [place(id: 'p')]
        ..saveBranchResult = place(id: 'p');
      final controller = PlacesController(repo);
      await controller.load();

      await t.pumpWidget(
        app(
          providers: [ChangeNotifierProvider.value(value: controller)],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showNotebookSheet<void>(
                    context,
                    builder: (_) => NearbySheet(
                      place: nearbyBranch(),
                      onSave: () => controller.saveBranch('b-1'),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      expect(find.text('Kedai Sederhana'), findsOneWidget);
      expect(find.text('Kedai Sederhana Bangsar'), findsOneWidget);
      expect(find.text('Jalan Telawi'), findsOneWidget);
      expect(find.text('2.4 km'), findsOneWidget);
      expect(find.textContaining('Halal ya'), findsOneWidget);

      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect(repo.savedBranches, ['b-1']);
      expect(find.text('Saved to your book.'), findsOneWidget);
      expect(find.text('Kedai Sederhana'), findsNothing);
    },
  );
}
