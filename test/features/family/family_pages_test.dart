import 'package:bukuresipi_flutter/features/auth/presentation/auth_controller.dart';
import 'package:bukuresipi_flutter/features/family/presentation/family_controller.dart';
import 'package:bukuresipi_flutter/features/family/presentation/pages/family_join_page.dart';
import 'package:bukuresipi_flutter/features/family/presentation/pages/family_page.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../fakes.dart';
import 'family_fixtures.dart';

void main() {
  late FakeFamily repo;
  late FamilyController family;
  var changed = 0;

  setUp(() {
    repo = FakeFamily();
    changed = 0;
    family = FamilyController(repo, onChanged: () async => changed++);
  });

  Future<void> pump(WidgetTester t, String location) async {
    final auth = AuthController(FakeAuthRepository()..session = true);
    await auth.restore();
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(path: '/family', builder: (_, _) => const FamilyPage()),
        GoRoute(
          path: '/family/join',
          builder: (_, s) => FamilyJoinPage(token: s.uri.queryParameters['t']),
        ),
      ],
    );
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: family),
        ],
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

  testWidgets('a family lists its members by name; the owner can invite', (
    t,
  ) async {
    repo.current = aFamily();
    await pump(t, '/family');
    expect(find.text('Rumah Ali'), findsOneWidget);
    expect(find.text('Siti'), findsOneWidget);
    expect(
      find.textContaining('Created by Hafiz · '),
      findsOneWidget,
    ); // kept after the creator leaves
    await t.tap(
      find.text(lookupAppLocalizations(const Locale('en')).familyInvite),
    );
    await t.pumpAndSettle();
    expect(repo.invites, 1);
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).familyCopyLink),
      findsOneWidget,
    );
  });

  testWidgets(
    'an invite link previews the family, joins it and reloads the book',
    (t) async {
      await pump(t, '/family/join?t=abc');
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l.familyJoinTitle('Rumah Ali')), findsOneWidget);
      await t.tap(find.text(l.familyJoin));
      await t.pumpAndSettle();
      expect(repo.joined, ['abc']);
      expect(family.inFamily, isTrue);
      expect(changed, 1);
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets('a stopped or expired link says so', (t) async {
    await pump(t, '/family/join?t=old');
    expect(
      find.text(lookupAppLocalizations(const Locale('en')).errInviteExpired),
      findsOneWidget,
    );
  });
}
