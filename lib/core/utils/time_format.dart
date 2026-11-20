import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

/// A time of day as the phone shows it: "13:47" when it is set to 24-hour, else "1:47 PM". Every time in the app
/// goes through here (not DateFormat.jm: intl's Malay writes "PTG").
String formatTime(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Flutter's Malay text writes AM/PM as "PG" and "P/M". Malaysian apps and receipts write AM/PM in both languages,
/// so Malay keeps every other word of Flutter's and takes these two (the time picker too). Before
/// GlobalMaterialLocalizations.delegate in the app's list.
class MalayTimeDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const MalayTimeDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ms';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // Loads intl's date symbols for the formats below.
    await GlobalMaterialLocalizations.delegate.load(locale);
    const name = 'ms';
    return _MalayMaterial(
      fullYearFormat: intl.DateFormat.y(name),
      compactDateFormat: intl.DateFormat.yMd(name),
      shortDateFormat: intl.DateFormat.yMMMd(name),
      mediumDateFormat: intl.DateFormat.MMMEd(name),
      longDateFormat: intl.DateFormat.yMMMMEEEEd(name),
      yearMonthFormat: intl.DateFormat.yMMMM(name),
      shortMonthDayFormat: intl.DateFormat.MMMd(name),
      decimalFormat: intl.NumberFormat.decimalPattern(name),
      twoDigitZeroPaddedFormat: intl.NumberFormat('00', name),
    );
  }

  @override
  bool shouldReload(MalayTimeDelegate old) => false;
}

class _MalayMaterial extends MaterialLocalizationMs {
  const _MalayMaterial({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  String get anteMeridiemAbbreviation => 'AM';

  @override
  String get postMeridiemAbbreviation => 'PM';
}
