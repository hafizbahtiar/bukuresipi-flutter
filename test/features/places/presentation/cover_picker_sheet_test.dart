import 'package:bukuresipi_flutter/features/places/presentation/places_controller.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/cover_picker_sheet.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../places_fixtures.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  Future<FakePlaces> pump(
    WidgetTester t,
    List<String> covers,
    String? current,
  ) async {
    final places = FakePlaces()
      ..coverIds = covers
      ..currentCover = current;
    await t.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PlacesController(places),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const CoverPickerSheet(restaurantId: 'r-1'),
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
    return places;
  }

  testWidgets('the owner taps a post photo and it becomes the cover', (
    t,
  ) async {
    final places = await pump(t, ['aa', 'bb'], 'aa');
    await t.tap(find.byKey(const ValueKey('cover-bb')));
    await t.pumpAndSettle();
    expect(places.coverPicks, ['bb']);
    expect(find.text(l.coverSaved), findsOneWidget);
  });

  testWidgets('the cover can be cleared', (t) async {
    final places = await pump(t, ['aa'], 'aa');
    await t.tap(find.text(l.coverNone));
    await t.pumpAndSettle();
    expect(places.coverPicks, [null]);
  });

  testWidgets('no post photos yet: says how to get one, nothing to clear', (
    t,
  ) async {
    await pump(t, [], null);
    expect(find.text(l.coverEmpty), findsOneWidget);
    expect(find.text(l.coverNone), findsNothing);
    // A photo of the owner's own is always offered: camera or gallery.
    expect(find.byKey(const ValueKey('cover-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-gallery')), findsOneWidget);
  });
}
