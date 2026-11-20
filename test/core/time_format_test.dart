import 'package:bukuresipi_flutter/core/time_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The times and a Material word, as the app shows them in [locale].
Future<List<String>> _shown(
  WidgetTester t,
  String locale, {
  bool h24 = false,
}) async {
  late List<String> out;
  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(alwaysUse24HourFormat: h24),
      child: Localizations(
        locale: Locale(locale),
        delegates: const [
          MalayTimeDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        child: Builder(
          builder: (context) {
            final m = MaterialLocalizations.of(context);
            out = [
              formatTime(context, DateTime(2026, 11, 20, 13, 47)),
              formatTime(context, DateTime(2026, 11, 20, 9, 3)),
              m.cancelButtonLabel,
              m.formatMediumDate(DateTime(2026, 11, 20)),
            ];
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  await t.pump(); // the delegates load asynchronously
  return out;
}

void main() {
  testWidgets('Malay: AM/PM (not PG, P/M), the rest of Flutter\'s Malay kept', (
    t,
  ) async {
    expect(await _shown(t, 'ms'), [
      '1:47 PM',
      '9:03 AM',
      'Batal',
      'Jum, 20 Nov',
    ]);
  });

  testWidgets('English as before; a phone set to 24-hour gets 24-hour', (
    t,
  ) async {
    expect((await _shown(t, 'en')).take(2), ['1:47 PM', '9:03 AM']);
    expect((await _shown(t, 'ms', h24: true)).take(2), ['13:47', '09:03']);
  });
}
