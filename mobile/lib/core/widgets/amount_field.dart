import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/amount_input.dart';
import 'package:montra_mobile/core/formatting/currencies.dart';

/// Minor-unit digits of [currency]; 2 when unknown (the server validates).
int exponentFor(String? currency) =>
    currency == null ? 2 : Currencies.exponentOf(currency) ?? 2;

/// Localized message for an [AmountInputError].
String amountErrorText(
  AppLocalizations l10n,
  AmountInputError error, {
  required int exponent,
}) => switch (error) {
  AmountInputError.required => l10n.amountRequired,
  AmountInputError.invalid => l10n.amountInvalid,
  AmountInputError.tooPrecise =>
    exponent == 0 ? l10n.amountNoDecimals : l10n.amountTooPrecise(exponent),
  AmountInputError.notPositive => l10n.amountNotPositive,
  AmountInputError.negative => l10n.amountNegative,
  AmountInputError.tooLarge => l10n.amountTooLarge,
};

/// Reads [text] as an amount in [currency] using the user's notation.
AmountParseResult readAmount(
  BuildContext context,
  WidgetRef ref,
  String text, {
  required String? currency,
  bool allowNegative = false,
  bool allowZero = false,
}) => AmountInput.parseForLocale(
  text,
  exponent: exponentFor(currency),
  locale: numberLocaleOf(context, ref),
  allowNegative: allowNegative,
  allowZero: allowZero,
);

/// A text field for an exact money amount in [currency].
///
/// The value is validated with [AmountInput] (string arithmetic only, the
/// currency's minor-unit precision) and the currency code is shown next to
/// it. Optional fields ([isRequired] false) accept an empty value.
class AmountField extends ConsumerWidget {
  /// Creates the field.
  const AmountField({
    required this.controller,
    required this.label,
    required this.currency,
    this.isRequired = true,
    this.allowNegative = false,
    this.allowZero = false,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  /// Text controller.
  final TextEditingController controller;

  /// Field label.
  final String label;

  /// ISO code of the amount (null until an account is chosen).
  final String? currency;

  /// Whether a value is required.
  final bool isRequired;

  /// Whether negative amounts are accepted.
  final bool allowNegative;

  /// Whether zero is accepted.
  final bool allowZero;

  /// Server-side error.
  final String? errorText;

  /// Helper text.
  final String? helperText;

  /// Change callback.
  final ValueChanged<String>? onChanged;

  /// Whether input is allowed.
  final bool enabled;

  /// Focus on first build.
  final bool autofocus;

  /// Keyboard action.
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? code = currency;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      keyboardType: TextInputType.numberWithOptions(
        decimal: exponentFor(code) > 0,
        signed: allowNegative,
      ),
      inputFormatters: <TextInputFormatter>[
        AmountInput.formatter(allowNegative: allowNegative),
      ],
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        suffixText: code,
      ),
      onChanged: onChanged,
      validator: (String? value) {
        final String text = value ?? '';
        if (!isRequired && text.trim().isEmpty) {
          return null;
        }
        final int exponent = exponentFor(code);
        final AmountParseResult result = readAmount(
          context,
          ref,
          text,
          currency: code,
          allowNegative: allowNegative,
          allowZero: allowZero,
        );
        final AmountInputError? error = result.error;
        return error == null
            ? null
            : amountErrorText(l10n, error, exponent: exponent);
      },
    );
  }
}
