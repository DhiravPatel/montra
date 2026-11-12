import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:montra_mobile/core/api/generated/models.dart'
    show CurrencyDto, Money;
import 'package:montra_mobile/core/formatting/currencies.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';

const String nbsp = ' ';

String fmt(
  String amount,
  String currency,
  String locale, {
  CurrencyDisplay display = CurrencyDisplay.symbol,
}) => MoneyFormatter.formatAmount(
  amount,
  currency,
  locale: locale,
  display: display,
);

void main() {
  group('Indian grouping (en_IN)', () {
    test('groups lakhs and crores', () {
      expect(fmt('1234567.89', 'INR', 'en_IN'), '₹12,34,567.89');
      expect(fmt('123456789012.50', 'INR', 'en_IN'), '₹1,23,45,67,89,012.50');
      expect(fmt('100000', 'INR', 'en_IN'), '₹1,00,000.00');
      expect(fmt('999', 'INR', 'en-IN'), '₹999.00');
    });

    test('Hindi uses the same grouping', () {
      expect(fmt('1234567.89', 'INR', 'hi'), '₹12,34,567.89');
    });

    test('reports (3, 2) grouping sizes', () {
      expect(MoneyFormatter.groupingSizes('en_IN'), (3, 2));
      expect(MoneyFormatter.groupingSizes('en_US'), (3, 3));
    });

    test('does not assume INR: other currencies keep Indian grouping', () {
      expect(fmt('1234567.89', 'USD', 'en_IN'), endsWith('12,34,567.89'));
      expect(fmt('1234567.89', 'USD', 'en_IN'), isNot(contains('₹')));
    });
  });

  group('Western grouping', () {
    test('en_US dollars', () {
      expect(fmt('1234567.89', 'USD', 'en_US'), '\$1,234,567.89');
      expect(fmt('0.5', 'USD', 'en_US'), '\$0.50');
    });

    test('de_DE places the symbol after the number with a no-break space', () {
      expect(fmt('1234567.89', 'EUR', 'de_DE'), '1.234.567,89$nbsp€');
    });
  });

  group('minor-unit exponents 0, 2 and 3', () {
    test('0 decimals (JPY) drop zero fractions', () {
      expect(
        fmt('1234567', 'JPY', 'en_US', display: CurrencyDisplay.none),
        '1,234,567',
      );
      expect(
        fmt('1234567.00', 'JPY', 'en_US', display: CurrencyDisplay.none),
        '1,234,567',
      );
    });

    test('3 decimals (KWD) pad the fraction', () {
      expect(
        fmt('1234.5', 'KWD', 'en_US', display: CurrencyDisplay.none),
        '1,234.500',
      );
      expect(
        fmt('1234.5', 'KWD', 'en_US', display: CurrencyDisplay.code),
        'KWD${nbsp}1,234.500',
      );
    });

    test('2 decimals pad and never round', () {
      expect(fmt('12', 'INR', 'en_IN', display: CurrencyDisplay.none), '12.00');
      expect(
        fmt('12.500', 'INR', 'en_IN', display: CurrencyDisplay.none),
        '12.50',
      );
      // Extra significant digits are shown, not rounded away.
      expect(
        fmt('12.345', 'INR', 'en_IN', display: CurrencyDisplay.none),
        '12.345',
      );
    });

    test('exponents match the backend registry', () {
      expect(Currencies.exponentOf('JPY'), 0);
      expect(Currencies.exponentOf('INR'), 2);
      expect(Currencies.exponentOf('KWD'), 3);
      expect(Currencies.exponentOf('XYZ'), isNull);
      final List<String> codes = Currencies.all
          .map((CurrencyDto c) => c.code)
          .toList();
      expect(codes, List<String>.of(codes)..sort(), reason: 'sorted by code');
    });
  });

  group('signs and exactness', () {
    test('negative amounts use the locale minus sign before the symbol', () {
      expect(fmt('-1234.50', 'INR', 'en_IN'), '-₹1,234.50');
      expect(fmt('+5', 'INR', 'en_IN'), '₹5.00');
    });

    test('negative zero is shown as zero', () {
      expect(fmt('-0.00', 'INR', 'en_IN'), '₹0.00');
      expect(fmt('-0', 'JPY', 'en_US', display: CurrencyDisplay.none), '0');
    });

    test('values beyond double precision stay exact', () {
      // 98765432109876543.21 cannot be represented by a double.
      expect(
        fmt('98765432109876543.21', 'USD', 'en_US'),
        '\$98,765,432,109,876,543.21',
      );
      expect(
        fmt(
          '98765432109876543.21',
          'INR',
          'en_IN',
          display: CurrencyDisplay.none,
        ),
        '98,76,54,32,10,98,76,543.21',
      );
    });

    test('leading zeros are removed', () {
      expect(fmt('0001234.5', 'USD', 'en_US'), '\$1,234.50');
    });

    test('rejects anything that is not an exact decimal string', () {
      for (final String bad in <String>[
        '',
        'abc',
        '1e5',
        '12,34',
        '1.2.3',
        '.5',
        'NaN',
        'Infinity',
        '1 000',
      ]) {
        expect(
          () => fmt(bad, 'INR', 'en_IN'),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });

  group('matches intl grouping for integers in the safe range', () {
    const List<String> locales = <String>[
      'en_US',
      'en_IN',
      'de_DE',
      'fr_FR',
      'hi',
      'ja_JP',
      'es_ES',
    ];
    const List<int> values = <int>[
      0,
      7,
      1234,
      12345,
      123456,
      1234567,
      987654321012,
    ];
    for (final String locale in locales) {
      test(locale, () {
        final NumberFormat reference = NumberFormat.decimalPattern(locale);
        for (final int value in values) {
          expect(
            fmt('$value', 'JPY', locale, display: CurrencyDisplay.none),
            reference.format(value),
            reason: '$value in $locale',
          );
        }
      });
    }
  });

  group('API Money object', () {
    test('formats the exact amount string from the contract object', () {
      final Money money = Money.fromJson(const <String, Object?>{
        'amount_minor': 123450,
        'amount': '1234.50',
        'currency': 'INR',
      });
      expect(money.amount, '1234.50');
      expect(money.amountMinor, 123450);
      expect(MoneyFormatter.format(money, locale: 'en_IN'), '₹1,234.50');
    });

    test('derives exact decimal strings from minor units', () {
      expect(MoneyFormatter.decimalFromMinorUnits(123450, 'INR'), '1234.50');
      expect(MoneyFormatter.decimalFromMinorUnits(-5, 'INR'), '-0.05');
      expect(MoneyFormatter.decimalFromMinorUnits(0, 'USD'), '0.00');
      expect(MoneyFormatter.decimalFromMinorUnits(1234, 'JPY'), '1234');
      expect(MoneyFormatter.decimalFromMinorUnits(1234, 'KWD'), '1.234');
      expect(
        MoneyFormatter.decimalFromMinorUnits(-9223372036854775807, 'USD'),
        '-92233720368547758.07',
      );
      expect(
        () => MoneyFormatter.decimalFromMinorUnits(1, 'XYZ'),
        throwsFormatException,
      );
    });

    test('a malformed amount string is rejected, never parsed as a double', () {
      const Money money = Money(
        amount: '1.5e3',
        amountMinor: 150000,
        currency: 'USD',
      );
      expect(
        () => MoneyFormatter.format(money, locale: 'en_US'),
        throwsFormatException,
      );
      expect(
        () => Money.fromJson(const <String, Object?>{
          'amount': 12.5,
          'amount_minor': 1250,
          'currency': 'USD',
        }),
        throwsFormatException,
      );
    });

    test('semantic label uses the ISO code and a localized minus word', () {
      expect(
        MoneyFormatter.semanticLabel(
          const Money(amount: '-1234.5', amountMinor: -123450, currency: 'INR'),
          locale: 'en_IN',
          minusWord: 'minus',
        ),
        'minus 1,234.50 INR',
      );
    });

    test('toString never contains the amount', () {
      expect(
        const Money(
          amount: '1234.50',
          amountMinor: 123450,
          currency: 'INR',
        ).toString(),
        isNot(contains('1234')),
      );
    });
  });
}
