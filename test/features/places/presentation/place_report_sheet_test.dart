import 'package:bukuresipi_flutter/features/places/domain/report.dart';
import 'package:bukuresipi_flutter/features/places/presentation/widgets/place_report_sheet.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<ReportDraft>> report(
    WidgetTester t, {
    required bool closed,
  }) async {
    final sent = <ReportDraft>[];
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
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
          body: PlaceReportSheet(
            subject: ReportSubject(
              placeId: 'r-1',
              restaurantName: 'Kedai A',
              branches: [
                ReportBranch(id: 'b-1', label: 'Kedai A KL', closed: closed),
              ],
            ),
            onSubmit: (d) async => sent.add(d),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open or closed'));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Report'));
    await t.pump();
    return sent;
  }

  testWidgets(
    'an open branch is reported permanently closed, no typing needed',
    (t) async {
      final sent = await report(t, closed: false);
      expect(sent.single.field, ReportField.status);
      expect(sent.single.target, ReportTarget.branch);
      expect(sent.single.value, 'closed');
    },
  );

  testWidgets('a closed branch is reported open again', (t) async {
    final sent = await report(t, closed: true);
    expect(sent.single.value, 'open');
  });
}
