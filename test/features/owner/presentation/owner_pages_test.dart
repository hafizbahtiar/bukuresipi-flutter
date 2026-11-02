import 'package:bukuresipi_flutter/features/owner/domain/owner_repository.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_page.dart';
import 'package:bukuresipi_flutter/features/owner/presentation/pages/owner_users_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../owner_fixtures.dart';

void main() {
  late FakeOwner repo;
  setUp(() => repo = FakeOwner());

  Future<void> pump(WidgetTester t, Widget page) async {
    // A phone-sized screen: the meter list sits below the counts.
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      Provider<OwnerRepository>.value(
        value: repo,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: page,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'the overview shows the counts and each meter\'s use against its cap',
    (t) async {
      await pump(t, const OwnerPage());
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Nominatim'), findsOneWidget);
      expect(find.text('90 / 100 a month'), findsOneWidget);
    },
  );

  testWidgets('a meter\'s cap is changed from its dialog', (t) async {
    await pump(t, const OwnerPage());
    await t.tap(find.text('Nominatim'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '500');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(repo.meterUpdates, [('geo:nominatim', 500, true)]);
    expect(find.text('90 / 500'), findsOneWidget);
  });

  testWidgets('users are searched, and ending a user\'s sessions asks first', (
    t,
  ) async {
    repo.users = [
      ownerUser('siti@b.c', shares: 2),
      ownerUser('ali@b.c', verified: false),
    ];
    await pump(t, const OwnerUsersPage());
    expect(find.text('siti@b.c'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'ali');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(repo.queries.last, 'ali');
    expect(find.text('siti@b.c'), findsNothing);
    await t.tap(find.text('ali@b.c'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sign out everywhere'));
    await t.pumpAndSettle();
    expect(repo.loggedOut, isEmpty);
    await t.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await t.pumpAndSettle();
    expect(repo.loggedOut, ['u-ali@b.c']);
  });
}
