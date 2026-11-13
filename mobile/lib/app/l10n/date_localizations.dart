import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/formatting/dates.dart';

/// The app's localization delegates with the account's date [settings]
/// applied: date pickers start their weeks on the chosen day and read and
/// show typed dates in the chosen order.
///
/// When [settings] change, the Material localizations reload, which makes
/// every widget that reads the locale (all of the app's text) rebuild, so
/// dates written through [LocalDates] follow the new settings at once.
List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates(
  DateSettings settings,
) => <LocalizationsDelegate<dynamic>>[
  DateSettingsMaterialLocalizations(settings),
  ...AppLocalizations.localizationsDelegates,
];

/// Material localizations for the app's languages (English and Hindi) with
/// the account's first day of the week and date order. Comes before
/// [GlobalMaterialLocalizations.delegate], which serves everything else.
class DateSettingsMaterialLocalizations
    extends LocalizationsDelegate<MaterialLocalizations> {
  /// Creates the delegate for [settings].
  const DateSettingsMaterialLocalizations(this.settings);

  /// The account's date settings.
  final DateSettings settings;

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'hi';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    // Loads the date symbols for the locale, as the stock delegate does.
    GlobalMaterialLocalizations.delegate.load(locale);
    final String canonical = intl.Intl.canonicalizedLocale(locale.toString());
    final String name = intl.DateFormat.localeExists(canonical)
        ? canonical
        : locale.languageCode;
    final String? pattern = settings.order.datePattern;
    final intl.DateFormat compact = pattern == null
        ? intl.DateFormat.yMd(name)
        : intl.DateFormat(pattern, name);
    final String numbers = intl.NumberFormat.localeExists(canonical)
        ? canonical
        : locale.languageCode;
    final _Formats f = (
      fullYear: intl.DateFormat.y(name),
      compact: compact,
      short: intl.DateFormat.yMMMd(name),
      medium: intl.DateFormat.MMMEd(name),
      long: intl.DateFormat.yMMMMEEEEd(name),
      yearMonth: intl.DateFormat.yMMMM(name),
      shortMonthDay: intl.DateFormat.MMMd(name),
      decimal: intl.NumberFormat.decimalPattern(numbers),
      twoDigits: intl.NumberFormat('00', numbers),
    );
    return SynchronousFuture<MaterialLocalizations>(
      locale.languageCode == 'hi'
          ? _HindiWithDates(settings, f)
          : _EnglishWithDates(settings, f),
    );
  }

  @override
  bool shouldReload(DateSettingsMaterialLocalizations old) =>
      old.settings != settings;
}

typedef _Formats = ({
  intl.DateFormat fullYear,
  intl.DateFormat compact,
  intl.DateFormat short,
  intl.DateFormat medium,
  intl.DateFormat long,
  intl.DateFormat yearMonth,
  intl.DateFormat shortMonthDay,
  intl.NumberFormat decimal,
  intl.NumberFormat twoDigits,
});

class _EnglishWithDates extends MaterialLocalizationEn {
  _EnglishWithDates(this._settings, _Formats f)
    : super(
        fullYearFormat: f.fullYear,
        compactDateFormat: f.compact,
        shortDateFormat: f.short,
        mediumDateFormat: f.medium,
        longDateFormat: f.long,
        yearMonthFormat: f.yearMonth,
        shortMonthDayFormat: f.shortMonthDay,
        decimalFormat: f.decimal,
        twoDigitZeroPaddedFormat: f.twoDigits,
      );

  final DateSettings _settings;

  @override
  int get firstDayOfWeekIndex =>
      _settings.weekStart ?? super.firstDayOfWeekIndex;

  @override
  String get dateHelpText => _settings.order.inputHint ?? super.dateHelpText;
}

class _HindiWithDates extends MaterialLocalizationHi {
  _HindiWithDates(this._settings, _Formats f)
    : super(
        fullYearFormat: f.fullYear,
        compactDateFormat: f.compact,
        shortDateFormat: f.short,
        mediumDateFormat: f.medium,
        longDateFormat: f.long,
        yearMonthFormat: f.yearMonth,
        shortMonthDayFormat: f.shortMonthDay,
        decimalFormat: f.decimal,
        twoDigitZeroPaddedFormat: f.twoDigits,
      );

  final DateSettings _settings;

  @override
  int get firstDayOfWeekIndex =>
      _settings.weekStart ?? super.firstDayOfWeekIndex;

  @override
  String get dateHelpText => _settings.order.inputHint ?? super.dateHelpText;
}
