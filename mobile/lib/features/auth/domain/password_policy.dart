import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Client-side password hints that mirror the server policy
/// (`backend/internal/auth/policy.go`).
///
/// The server is authoritative and rejects weak passwords with a
/// `body.password` field error; these checks only guide the user. Only the
/// length bounds block submission, so a future server-side change cannot be
/// contradicted by a stricter client.
abstract final class PasswordPolicy {
  /// Minimum length from the contract (`RegisterBody.password` and the
  /// `new_password` members all declare 10). A server configured stricter
  /// still answers with a field error, which the forms display.
  static const int minLength = RegisterBody.passwordMinLength;

  /// Maximum length from the contract.
  static const int maxLength = RegisterBody.passwordMaxLength;

  /// Length in Unicode code points, as the server counts.
  static int lengthOf(String password) => password.runes.length;

  /// At least [minLength] characters.
  static bool meetsLength(String password) => lengthOf(password) >= minLength;

  /// Does not contain the email's local part (when it has 4+ characters).
  static bool avoidsEmail(String password, String email) {
    final String local = email.trim().toLowerCase().split('@').first;
    if (local.length < 4 || !email.contains('@')) {
      return true;
    }
    return !password.toLowerCase().contains(local);
  }

  /// At least four distinct characters.
  static bool hasVariety(String password) => password.runes.toSet().length >= 4;

  /// Blocking validation for the new-password field.
  static String? validate(AppLocalizations l10n, String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return l10n.validationPasswordRequired;
    }
    if (!meetsLength(password)) {
      return l10n.validationPasswordTooShort(minLength);
    }
    if (lengthOf(password) > maxLength) {
      return l10n.validationPasswordTooLong(maxLength);
    }
    return null;
  }
}
