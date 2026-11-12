import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';

/// Email input with autofill and the right keyboard.
class EmailField extends StatelessWidget {
  /// Creates the field.
  const EmailField({
    required this.controller,
    this.errorText,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    super.key,
  });

  /// Text controller.
  final TextEditingController controller;

  /// Server-side error to show.
  final String? errorText;

  /// Client-side validator.
  final FormFieldValidator<String>? validator;

  /// Keyboard action.
  final TextInputAction textInputAction;

  /// Called on the keyboard action.
  final ValueChanged<String>? onFieldSubmitted;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Whether input is allowed.
  final bool enabled;

  /// Focus on first build.
  final bool autofocus;

  /// Maximum length from the contract.
  final int? maxLength;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    autofocus: autofocus,
    keyboardType: TextInputType.emailAddress,
    textInputAction: textInputAction,
    autofillHints: const <String>[AutofillHints.email],
    autocorrect: false,
    enableSuggestions: false,
    maxLength: maxLength,
    maxLengthEnforcement: MaxLengthEnforcement.enforced,
    decoration: InputDecoration(
      labelText: context.l10n.emailLabel,
      errorText: errorText,
      counterText: '',
    ),
    validator: validator ?? (String? v) => validateEmail(context.l10n, v),
    onFieldSubmitted: onFieldSubmitted,
    onChanged: onChanged,
  );
}

/// Basic client-side email check. The server performs the authoritative
/// validation and reports `body.email` errors.
String? validateEmail(AppLocalizations l10n, String? value) {
  final String v = value?.trim() ?? '';
  if (v.isEmpty) {
    return l10n.validationEmailRequired;
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
    return l10n.validationEmailInvalid;
  }
  return null;
}

/// Password input with a show/hide toggle. Suggestions, autocorrect and
/// keyboard learning are disabled.
class PasswordField extends StatefulWidget {
  /// Creates the field.
  const PasswordField({
    required this.controller,
    required this.label,
    this.errorText,
    this.helperText,
    this.validator,
    this.autofillHints = const <String>[AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    super.key,
  });

  /// Text controller.
  final TextEditingController controller;

  /// Field label.
  final String label;

  /// Server-side error to show.
  final String? errorText;

  /// Helper text under the field.
  final String? helperText;

  /// Client-side validator.
  final FormFieldValidator<String>? validator;

  /// Autofill hints (e.g. [AutofillHints.newPassword] on sign-up).
  final List<String> autofillHints;

  /// Keyboard action.
  final TextInputAction textInputAction;

  /// Called on the keyboard action.
  final ValueChanged<String>? onFieldSubmitted;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Whether input is allowed.
  final bool enabled;

  /// Focus on first build.
  final bool autofocus;

  /// Maximum length from the contract.
  final int? maxLength;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      maxLength: widget.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        helperText: widget.helperText,
        counterText: '',
        suffixIcon: IconButton(
          tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
    );
  }
}

/// Six-digit verification code input (TOTP).
class OtpCodeField extends StatelessWidget {
  /// Creates the field.
  const OtpCodeField({
    required this.controller,
    required this.label,
    this.errorText,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
    this.autofocus = false,
    super.key,
  });

  /// Text controller.
  final TextEditingController controller;

  /// Field label.
  final String label;

  /// Server-side error to show.
  final String? errorText;

  /// Client-side validator; defaults to [validateOtpCode].
  final FormFieldValidator<String>? validator;

  /// Called on the keyboard action.
  final ValueChanged<String>? onFieldSubmitted;

  /// Whether input is allowed.
  final bool enabled;

  /// Focus on first build.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    autofillHints: const <String>[AutofillHints.oneTimeCode],
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    decoration: InputDecoration(labelText: label, errorText: errorText),
    validator: validator ?? (String? v) => validateOtpCode(context.l10n, v),
    onFieldSubmitted: onFieldSubmitted,
  );
}

/// Requires exactly six digits.
String? validateOtpCode(AppLocalizations l10n, String? value) {
  final String v = value?.trim() ?? '';
  if (v.isEmpty) {
    return l10n.validationCodeRequired;
  }
  if (!RegExp(r'^\d{6}$').hasMatch(v)) {
    return l10n.validationCodeFormat;
  }
  return null;
}
