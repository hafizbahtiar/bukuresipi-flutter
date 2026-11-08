import 'package:bukuresipi_flutter/core/network/api_exception.dart';
import 'package:bukuresipi_flutter/features/auth/presentation/auth_text.dart';
import 'package:bukuresipi_flutter/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // The app gets these from flutter_localizations at start-up; a plain test loads them itself.
  setUpAll(initializeDateFormatting);

  test('a banned sign-in says until when and why, or that it is for good', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      errorText(
        en,
        const ApiException(
          'banned',
          status: 403,
          data: {'until': '2026-12-01T00:00:00.000Z', 'reason': 'Spam reviews'},
        ),
      ),
      'This account is suspended until Dec 1, 2026.\nReason: Spam reviews',
    );
    expect(
      errorText(
        en,
        const ApiException('banned', data: {'until': null, 'reason': null}),
      ),
      'This account has been suspended.',
    );
    final ms = lookupAppLocalizations(const Locale('ms'));
    expect(
      errorText(
        ms,
        const ApiException('banned', data: {'reason': 'Akaun palsu'}),
      ),
      'Akaun ini telah digantung.\nSebab: Akaun palsu',
    );
  });
}
