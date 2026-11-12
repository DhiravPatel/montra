import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Money;
import 'package:montra_mobile/core/formatting/currencies.dart';

/// How the currency is shown next to the amount.
enum CurrencyDisplay {
  /// Locale symbol, e.g. `₹1,23,456.50`, `$1,234.50`.
  symbol,

  /// ISO code, e.g. `INR 1,23,456.50` (unambiguous across currencies).
  code,

  /// Number only, e.g. `1,23,456.50`.
  none,
}

/// Formats exact decimal money strings for display without ever converting
/// the value to a floating-point number (ADR-006, spec §0.5).
///
/// Works on the contract's `Money` object
/// (`{amount_minor, amount, currency}`): the exact `amount` string is what
/// gets displayed; `amount_minor` is only a fallback source of the digits.
///
/// The decimal string is split into its integer and fraction digits. The
/// integer digits are grouped with the locale's grouping sizes taken from
/// `intl` (so `en_IN` gets lakh/crore grouping: `12,34,56,789`), and the
/// locale's separators, digits, minus sign and currency pattern come from
/// `intl`'s CLDR data. The fraction is padded to the currency's minor-unit
/// exponent (0, 2 or 3) and never rounded.
abstract final class MoneyFormatter {
  /// Formats an API [money] value for [locale] (e.g. `en_IN`, `en-US`,
  /// `hi`).
  static String format(
    Money money, {
    required String locale,
    CurrencyDisplay display = CurrencyDisplay.symbol,
  }) => formatAmount(
    money.amount,
    money.currency,
    locale: locale,
    display: display,
  );

  /// Formats a decimal [amount] string in [currencyCode] for [locale].
  ///
  /// Throws [FormatException] when [amount] is not an exact decimal string.
  static String formatAmount(
    String amount,
    String currencyCode, {
    required String locale,
    CurrencyDisplay display = CurrencyDisplay.symbol,
  }) {
    final _Decimal value = _Decimal.parse(
      amount,
      Currencies.exponentOf(currencyCode),
    );
    final String intlLocale = _intlLocale(locale);
    final NumberSymbols symbols = NumberFormat.decimalPattern(intlLocale)
        .symbols;
    final String number = _formatNumber(value, symbols);

    final String withCurrency = switch (display) {
      CurrencyDisplay.none => number,
      CurrencyDisplay.code => _applyCurrencyPattern(
        number,
        currencyCode,
        symbols.CURRENCY_PATTERN,
      ),
      CurrencyDisplay.symbol => _applyCurrencyPattern(
        number,
        NumberFormat.simpleCurrency(
          locale: intlLocale,
          name: currencyCode,
        ).currencySymbol,
        symbols.CURRENCY_PATTERN,
      ),
    };
    return value.negative ? '${symbols.MINUS_SIGN}$withCurrency' : withCurrency;
  }

  /// A screen-reader friendly label such as `minus 1,234.50 INR`: the ISO
  /// code is read reliably, unlike many currency symbols. [minusWord] lets
  /// callers pass a localized word for the sign.
  static String semanticLabel(
    Money money, {
    required String locale,
    required String minusWord,
  }) {
    final _Decimal value = _Decimal.parse(
      money.amount,
      Currencies.exponentOf(money.currency),
    );
    final NumberSymbols symbols = NumberFormat.decimalPattern(
      _intlLocale(locale),
    ).symbols;
    final String number = _formatNumber(value, symbols);
    return value.negative
        ? '$minusWord $number ${money.currency}'
        : '$number ${money.currency}';
  }

  /// The exact decimal string for [minorUnits] of [currencyCode], using
  /// integer/string arithmetic only (e.g. `-5` INR -> `-0.05`, `1234` JPY ->
  /// `1234`, `1234` KWD -> `1.234`).
  ///
  /// Throws [FormatException] for a currency whose exponent is unknown.
  static String decimalFromMinorUnits(int minorUnits, String currencyCode) {
    final int? exponent = Currencies.exponentOf(currencyCode);
    if (exponent == null) {
      throw FormatException('Unknown currency exponent for $currencyCode');
    }
    final bool negative = minorUnits < 0;
    // Work on the digit string so even the most negative int stays exact.
    String digits = minorUnits.toString();
    if (negative) {
      digits = digits.substring(1);
    }
    String amount = digits;
    if (exponent > 0) {
      final String padded = digits.padLeft(exponent + 1, '0');
      final int split = padded.length - exponent;
      amount = '${padded.substring(0, split)}.${padded.substring(split)}';
    }
    return negative ? '-$amount' : amount;
  }

  /// Decimal and grouping symbols of [locale] (CLDR data from `intl`), used
  /// to read amounts typed in the user's notation.
  static NumberSymbols symbolsFor(String locale) =>
      NumberFormat.decimalPattern(_intlLocale(locale)).symbols;

  /// Integer grouping sizes `(primary, secondary)` of [locale]'s decimal
  /// pattern, e.g. `(3, 2)` for `en_IN`, `(3, 3)` for `en_US`, null when the
  /// locale does not group digits.
  static (int, int)? groupingSizes(String locale) => _groupingOf(
    NumberFormat.decimalPattern(_intlLocale(locale)).symbols.DECIMAL_PATTERN,
  );

  static String _intlLocale(String locale) {
    final String canonical = Intl.canonicalizedLocale(
      locale.replaceAll('-', '_'),
    );
    return Intl.verifiedLocale(
          canonical,
          NumberFormat.localeExists,
          onFailure: (String _) => 'en',
        ) ??
        'en';
  }

  static String _formatNumber(_Decimal value, NumberSymbols symbols) {
    final (int, int)? grouping = _groupingOf(symbols.DECIMAL_PATTERN);
    final String grouped = grouping == null
        ? value.integerDigits
        : _group(
            value.integerDigits,
            grouping.$1,
            grouping.$2,
            symbols.GROUP_SEP,
          );
    final String text = value.fractionDigits.isEmpty
        ? grouped
        : '$grouped${symbols.DECIMAL_SEP}${value.fractionDigits}';
    return _localizeDigits(text, symbols.ZERO_DIGIT);
  }

  static (int, int)? _groupingOf(String pattern) {
    final String positive = pattern.split(';').first;
    final String integerPart = positive
        .split('.')
        .first
        .replaceAll(RegExp(r'[^#0,]'), '');
    final List<String> groups = integerPart.split(',');
    if (groups.length < 2) {
      return null;
    }
    final int primary = groups.last.length;
    final int secondary = groups.length > 2
        ? groups[groups.length - 2].length
        : primary;
    if (primary <= 0 || secondary <= 0) {
      return null;
    }
    return (primary, secondary);
  }

  static String _group(
    String digits,
    int primary,
    int secondary,
    String separator,
  ) {
    if (digits.length <= primary) {
      return digits;
    }
    final List<String> parts = <String>[
      digits.substring(digits.length - primary),
    ];
    int end = digits.length - primary;
    while (end > 0) {
      final int start = end - secondary < 0 ? 0 : end - secondary;
      parts.insert(0, digits.substring(start, end));
      end = start;
    }
    return parts.join(separator);
  }

  static String _localizeDigits(String text, String zeroDigit) {
    if (zeroDigit == '0' || zeroDigit.isEmpty) {
      return text;
    }
    final int zero = zeroDigit.codeUnitAt(0);
    final StringBuffer out = StringBuffer();
    for (final int unit in text.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        out.writeCharCode(zero + unit - 0x30);
      } else {
        out.writeCharCode(unit);
      }
    }
    return out.toString();
  }

  /// Places [currency] according to the positive part of a CLDR currency
  /// pattern such as `¤#,##0.00`, `#,##0.00 ¤` or `¤ #,##0.00`.
  static String _applyCurrencyPattern(
    String number,
    String currency,
    String pattern,
  ) {
    const String placeholder = '¤';
    const String nbsp = ' ';
    final String positive = pattern.split(';').first.replaceAll("'", '');
    final int numberStart = positive.indexOf(RegExp('[#0]'));
    final int numberEnd = positive.lastIndexOf(RegExp('[#0]')) + 1;
    if (numberStart < 0) {
      return '$currency$nbsp$number';
    }
    String prefix = positive
        .substring(0, numberStart)
        .replaceAll(placeholder, currency);
    String suffix = positive
        .substring(numberEnd)
        .replaceAll(placeholder, currency);
    final bool letterSymbol = RegExp(
      r'\p{L}',
      unicode: true,
    ).hasMatch(currency.isEmpty ? '' : currency[currency.length - 1]);
    // CLDR currency spacing: keep a word-like symbol (e.g. "KWD") from
    // touching the digits.
    if (prefix.isNotEmpty && prefix.trim() == prefix && letterSymbol) {
      prefix = '$prefix$nbsp';
    }
    final bool letterStart = RegExp(
      r'\p{L}',
      unicode: true,
    ).hasMatch(currency.isEmpty ? '' : currency[0]);
    if (suffix.isNotEmpty && suffix.trim() == suffix && letterStart) {
      suffix = '$nbsp$suffix';
    }
    return '$prefix$number$suffix';
  }
}

/// A validated decimal split into digits (no numeric conversion).
class _Decimal {
  const _Decimal(this.negative, this.integerDigits, this.fractionDigits);

  factory _Decimal.parse(String amount, int? exponent) {
    final Match? match = RegExp(r'^([+-])?(\d+)(?:\.(\d+))?$')
        .firstMatch(amount.trim());
    if (match == null) {
      throw const FormatException('Amount is not an exact decimal string');
    }
    String integer = match.group(2)!.replaceFirst(RegExp('^0+(?=.)'), '');
    String fraction = match.group(3) ?? '';
    if (exponent != null) {
      if (fraction.length < exponent) {
        fraction = fraction.padRight(exponent, '0');
      } else if (fraction.length > exponent) {
        // Trailing zeros beyond the exponent carry no value; other extra
        // digits are kept rather than rounded away.
        final String significant = fraction.replaceFirst(RegExp(r'0+$'), '');
        fraction = significant.length > exponent
            ? significant
            : significant.padRight(exponent, '0');
      }
    }
    if (integer.isEmpty) {
      integer = '0';
    }
    final bool isZero =
        RegExp(r'^0+$').hasMatch(integer) &&
        (fraction.isEmpty || RegExp(r'^0+$').hasMatch(fraction));
    return _Decimal(match.group(1) == '-' && !isZero, integer, fraction);
  }

  final bool negative;
  final String integerDigits;
  final String fractionDigits;
}
