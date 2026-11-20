import 'package:bukuresipi_flutter/core/widgets/base.dart';
import 'package:bukuresipi_flutter/features/auth/domain/user.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/places/domain/place.dart';
import 'package:bukuresipi_flutter/features/places/domain/rating.dart';
import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/map_sheet.dart';
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

/// The map's sheet with [child] in it; [pick] raises it to half, as a tapped pin does.
class _OnMap extends StatefulWidget {
  const _OnMap({required this.child});

  final Widget child;

  @override
  State<_OnMap> createState() => _OnMapState();
}

class _OnMapState extends State<_OnMap> {
  final controller = DraggableScrollableController();
  int shown = 0;

  void pick() => setState(() => shown++);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: MapSheet(
      controller: controller,
      peek: 80,
      top: 60,
      shown: shown,
      showClose: shown > 0,
      onClose: (_) {},
      child: widget.child,
    ),
  );
}

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
                onPressed: () => showBaseSheet<void>(
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
    final save = find.byKey(const ValueKey('branch-save'));
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();

    expect(repo.branchUpdates.single.label, 'My Branch');
    expect(repo.branchUpdates.single.scope, BranchEditScope.personal);
    expect(edited, isTrue);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the sheet shows a one-line rating summary, no star buttons', (
    t,
  ) async {
    final repo = FakePlaces()
      ..ratingResult = const RatingSummary(
        average: 4.3,
        count: 7,
        mine: 4,
        canRate: true,
      );
    final controller = PlacesController(repo);
    await controller.load();
    await t.pumpWidget(
      app(
        providers: [ChangeNotifierProvider.value(value: controller)],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showBaseSheet<void>(
                  context,
                  builder: (_) => NearbySheet(
                    place: nearbyBranch(
                      saved: true,
                      rating: const RatingSummary(
                        average: 4.3,
                        count: 7,
                        canRate: true,
                      ),
                    ),
                    onSave: () async {},
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
    expect(find.byKey(const ValueKey('rating-star-4')), findsNothing);
    expect(find.textContaining('4.3 · 7 ratings'), findsOneWidget);
    expect(t.takeException(), isNull);
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
                  onPressed: () => showBaseSheet<void>(
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
      expect(find.textContaining('No ratings yet.'), findsOneWidget);

      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect(repo.savedBranches, ['b-1']);
      expect(find.text('Saved to your book.'), findsOneWidget);
      expect(find.text('Kedai Sederhana'), findsNothing);
    },
  );

  testWidgets(
    'the owner: Save and Directions, then Owner tools with the shared edit; no Report',
    (t) async {
      final controller = PlacesController(FakePlaces());
      final auth = AuthController(
        FakeAuthRepository()
          ..session = true
          ..meResult = const User(
            id: 'u-1',
            email: 'o@example.com',
            name: null,
            role: 'owner',
            lang: 'en',
            emailVerified: true,
          ),
      );
      await auth.restore();
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
                  onPressed: () => showBaseSheet<void>(
                    context,
                    builder: (_) =>
                        NearbySheet(place: nearbyBranch(), onSave: () async {}),
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
      expect(find.text('Report'), findsNothing);
      expect(find.byKey(const ValueKey('nearby-directions')), findsOneWidget);
      expect(find.text('Owner tools'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('nearby-owner-edit')));
      await t.pumpAndSettle();
      // The owner's edit is the shared one.
      expect(find.text('Only you will see these changes.'), findsNothing);
    },
  );

  testWidgets(
    'on the map at half: Save and Directions stay in the shown part',
    (t) async {
      t.view.physicalSize = const Size(360, 560);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final controller = PlacesController(FakePlaces());
      await t.pumpWidget(
        app(
          providers: [ChangeNotifierProvider.value(value: controller)],
          home: _OnMap(
            child: NearbySheet(
              place: nearbyBranch(),
              onSave: () async {},
              onEdited: () async {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      t.state<_OnMapState>(find.byType(_OnMap)).pick();
      await t.pumpAndSettle();
      final sheet = t.getRect(find.byKey(const ValueKey('map-sheet')));
      final directions = t.getRect(
        find.byKey(const ValueKey('nearby-directions')),
      );
      expect(sheet.height, lessThan(300)); // half: the card is longer than this
      expect(directions.top, greaterThan(sheet.top));
      expect(directions.bottom, lessThanOrEqualTo(sheet.bottom));
      expect(t.takeException(), isNull);
    },
  );
}
