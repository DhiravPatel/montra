import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/number_symbols.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';

/// Why a typed amount was rejected.
enum AmountInputError {
  /// Nothing was entered.
  required,

  /// Not a number.
  invalid,

  /// More decimal places than the currency allows.
  tooPrecise,

  /// Zero or negative where a positive amount is needed.
  notPositive,

  /// Negative where only zero or more is allowed.
  negative,

  /// Too many digits to be a realistic amount.
  tooLarge,
}

/// Result of [AmountInput.parse]: exactly one of [value] and [error] is set.
@immutable
class AmountParseResult {
  const AmountParseResult._(this.value, this.error);

  /// The normalized decimal string for the API, e.g. `1234.50`.
  final String? value;

  /// Why the input was rejected.
  final AmountInputError? error;

  /// Whether the input was accepted.
  bool get isValid => value != null;
}

/// Reads amounts typed by the user into the API's exact decimal strings
/// (docs/API.md: "Amounts in requests are exact decimal strings in the
/// currency's minor-unit precision").
///
/// Only string operations are used; the value is never converted to a
/// floating-point number. The server re-validates every amount.
abstract final class AmountInput {
  /// Integer digits accepted (keeps minor units far inside int64 for
  /// every exponent up to 4).
  static const int maxIntegerDigits = 13;

  /// Parses [raw] for a currency with [exponent] minor-unit digits.
  ///
  /// Group separators (`,`, spaces and the locale's own) are ignored; the
  /// locale's decimal separator and `.` are both accepted. With
  /// [allowNegative] a leading minus is allowed; [allowZero] accepts zero.
  /// The result is padded to [exponent] decimals (`12.5` -> `12.50`).
  static AmountParseResult parse(
    String raw, {
    required int exponent,
    bool allowNegative = false,
    bool allowZero = false,
    NumberSymbols? symbols,
  }) {
    String text = raw.trim();
    if (text.isEmpty) {
      return const AmountParseResult._(null, AmountInputError.required);
    }
    bool negative = false;
    if (text.startsWith('-') || text.startsWith('−')) {
      negative = true;
      text = text.substring(1).trim();
    } else if (text.startsWith('+')) {
      text = text.substring(1).trim();
    }
    final String decimalSeparator = symbols?.DECIMAL_SEP ?? '.';
    final String groupSeparator = symbols?.GROUP_SEP ?? ',';
    // Remove grouping first (unless the locale groups with its decimal
    // separator, which CLDR never does), then unify the decimal separator.
    final StringBuffer cleaned = StringBuffer();
    for (final String char in text.split('')) {
      if (char == ' ' || char == ' ' || char == ' ') {
        continue;
      }
      if (char == groupSeparator && char != decimalSeparator) {
        continue;
      }
      if (char == ',' && decimalSeparator != ',') {
        continue;
      }
      cleaned.write(char == decimalSeparator ? '.' : char);
    }
    final String normalized = cleaned.toString();
    final Match? match =
        RegExp(r'^(\d+)(?:\.(\d*))?$').firstMatch(normalized) ??
        RegExp(r'^()\.(\d+)$').firstMatch(normalized);
    if (match == null) {
      return const AmountParseResult._(null, AmountInputError.invalid);
    }
    String integer = match.group(1) ?? '';
    String fraction = match.group(2) ?? '';
    // Trailing zeros beyond the exponent carry no value.
    if (fraction.length > exponent) {
      final String trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
      if (trimmed.length > exponent) {
        return const AmountParseResult._(null, AmountInputError.tooPrecise);
      }
      fraction = trimmed;
    }
    integer = integer.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (integer.isEmpty) {
      integer = '0';
    }
    if (integer.length > maxIntegerDigits) {
      return const AmountParseResult._(null, AmountInputError.tooLarge);
    }
    fraction = fraction.padRight(exponent, '0');
    final bool isZero =
        RegExp(r'^0+$').hasMatch(integer) &&
        (fraction.isEmpty || RegExp(r'^0+$').hasMatch(fraction));
    if (negative && !isZero && !allowNegative) {
      return const AmountParseResult._(null, AmountInputError.negative);
    }
    if (isZero && !allowZero) {
      return const AmountParseResult._(null, AmountInputError.notPositive);
    }
    final String body = exponent == 0 ? integer : '$integer.$fraction';
    return AmountParseResult._(negative && !isZero ? '-$body' : body, null);
  }

  /// [parse] with [locale]'s separators.
  static AmountParseResult parseForLocale(
    String raw, {
    required int exponent,
    required String locale,
    bool allowNegative = false,
    bool allowZero = false,
  }) => parse(
    raw,
    exponent: exponent,
    allowNegative: allowNegative,
    allowZero: allowZero,
    symbols: MoneyFormatter.symbolsFor(locale),
  );

  /// Characters an amount field accepts while typing.
  static TextInputFormatter formatter({bool allowNegative = false}) =>
      FilteringTextInputFormatter.allow(
        allowNegative ? RegExp(r'[0-9.,\-− ]') : RegExp(r'[0-9., ]'),
      );
}

/// Exact decimal strings for exchange rates (`83.1234`): positive, up to 12
/// decimals, no grouping.
abstract final class RateInput {
  /// Returns the normalized rate or null when [raw] is not a positive
  /// decimal.
  static String? parse(String raw) {
    final String text = raw.trim().replaceAll(',', '.');
    final Match? match = RegExp(r'^(\d{1,9})(?:\.(\d{1,12}))?$')
        .firstMatch(text);
    if (match == null) {
      return null;
    }
    final String integer = match
        .group(1)!
        .replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final String fraction = match.group(2) ?? '';
    final bool zero =
        RegExp(r'^0+$').hasMatch(integer) &&
        (fraction.isEmpty || RegExp(r'^0+$').hasMatch(fraction));
    if (zero) {
      return null;
    }
    return fraction.isEmpty ? integer : '$integer.$fraction';
  }
}
