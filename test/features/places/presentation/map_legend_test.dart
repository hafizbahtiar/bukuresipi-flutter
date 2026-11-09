import 'package:bukuresipi_flutter/features/places/presentation/widgets/map_legend.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the legend lists every dot and switches other users\' restaurants off',
    (t) async {
      final changes = <bool>[];
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ms')],
          home: Scaffold(
            body: MapLegend(
              owner: true,
              showCommunity: true,
              onShowCommunity: changes.add,
            ),
          ),
        ),
      );
      expect(find.byType(MapMarkDot), findsWidgets);
      await t.scrollUntilVisible(find.byType(Switch), 200);
      await t.tap(find.byType(Switch));
      await t.pump();
      expect(changes, [false]);
      expect(t.widget<Switch>(find.byType(Switch)).value, isFalse);
    },
  );

  testWidgets('a user\'s legend has no other-users row and no switch', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ms')],
        home: Scaffold(
          body: MapLegend(showCommunity: false, onShowCommunity: (_) {}),
        ),
      ),
    );
    expect(
      find.byType(MapMarkDot),
      findsNWidgets(MapMark.values.where((m) => !m.ownerOnly).length),
    );
    expect(find.byType(Switch), findsNothing);
  });
}
