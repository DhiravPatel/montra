import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/amount_input.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('AmountInput.parse', () {
    String? value(
      String raw, {
      int exponent = 2,
      bool negative = false,
      bool zero = false,
    }) => AmountInput.parse(
      raw,
      exponent: exponent,
      allowNegative: negative,
      allowZero: zero,
    ).value;

    AmountInputError? error(
      String raw, {
      int exponent = 2,
      bool negative = false,
      bool zero = false,
    }) => AmountInput.parse(
      raw,
      exponent: exponent,
      allowNegative: negative,
      allowZero: zero,
    ).error;

    test('normalizes to the currency precision without rounding', () {
      expect(value('1250.5'), '1250.50');
      expect(value('1,23,456.75'), '123456.75');
      expect(value(' 12 '), '12.00');
      expect(value('.5'), '0.50');
      expect(value('007.10'), '7.10');
      expect(value('12.500'), '12.50');
      expect(value('1500', exponent: 0), '1500');
      expect(value('1.234', exponent: 3), '1.234');
    });

    test('rejects what the server would reject', () {
      expect(error(''), AmountInputError.required);
      expect(error('12a'), AmountInputError.invalid);
      expect(error('1.2.3'), AmountInputError.invalid);
      expect(error('1.255'), AmountInputError.tooPrecise);
      expect(error('1.5', exponent: 0), AmountInputError.tooPrecise);
      expect(error('0'), AmountInputError.notPositive);
      expect(error('-5'), AmountInputError.negative);
      expect(error('12345678901234'), AmountInputError.tooLarge);
    });

    test('signed and zero amounts when allowed', () {
      expect(value('-2500', negative: true), '-2500.00');
      expect(value('−2500', negative: true), '-2500.00');
      expect(value('0', zero: true), '0.00');
      expect(value('-0', negative: true, zero: true), '0.00');
    });

    test('uses the locale separators', () {
      expect(
        AmountInput.parseForLocale('1,234.50', exponent: 2, locale: 'hi').value,
        '1234.50',
      );
      expect(
        AmountInput.parse(
          '1.234,50',
          exponent: 2,
          symbols: MoneyFormatter.symbolsFor('de'),
        ).value,
        '1234.50',
      );
    });
  });

  group('RateInput.parse', () {
    test('accepts positive exact rates only', () {
      expect(RateInput.parse('83.1234'), '83.1234');
      expect(RateInput.parse('0.011904761905'), '0.011904761905');
      expect(RateInput.parse('083,5'), '83.5');
      expect(RateInput.parse('0'), isNull);
      expect(RateInput.parse('-1'), isNull);
      expect(RateInput.parse('abc'), isNull);
    });
  });

  group('LocalDates', () {
    test('round-trips calendar days without time-zone shifts', () {
      expect(LocalDates.format(DateTime(2026, 3, 9)), '2026-03-09');
      expect(LocalDates.parse('2026-11-04'), DateTime(2026, 11, 4));
      expect(LocalDates.parse('2026-02-31'), isNull);
      expect(LocalDates.parse('04/11/2026'), isNull);
      expect(LocalDates.display('2026-11-04', locale: 'en'), 'Nov 4, 2026');
      expect(LocalDates.display('bad', locale: 'en'), 'bad');
      expect(
        LocalDates.displayRange('2026-11-01', '2026-11-30', locale: 'en'),
        'Nov 1, 2026 – Nov 30, 2026',
      );
    });
  });

  group('resolveNumberLocale', () {
    test('keeps the account region when the language matches', () {
      expect(resolveNumberLocale(const Locale('en'), 'en-IN'), 'en_IN');
      expect(resolveNumberLocale(const Locale('hi'), 'en-IN'), 'hi');
      expect(resolveNumberLocale(const Locale('en'), null), 'en');
      expect(
        MoneyFormatter.formatAmount('1234567.5', 'INR', locale: 'en_IN'),
        '₹12,34,567.50',
      );
    });
  });
}
