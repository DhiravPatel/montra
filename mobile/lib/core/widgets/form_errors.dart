import 'package:flutter/foundation.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';

/// Server errors split into per-field messages and a form-level message.
///
/// `details[].field` values such as `body.password` are mapped to form
/// fields through [ServerFormErrors.from]'s `fieldMap` (JSON member name ->
/// form field id). Details that match no field are kept in [general] so no
/// message is ever silently dropped.
@immutable
class ServerFormErrors {
  /// Creates the errors.
  const ServerFormErrors({
    this.fields = const <String, String>{},
    this.general,
    this.requestId,
  });

  /// No errors.
  static const ServerFormErrors none = ServerFormErrors();

  /// Maps [error] onto a form.
  ///
  /// [generalMessage] customizes the form-level text for errors without
  /// mappable details; it defaults to [describeError].
  factory ServerFormErrors.from(
    AppLocalizations l10n,
    Object error, {
    required Map<String, String> fieldMap,
    String Function(ApiException error)? generalMessage,
  }) {
    if (error is! ApiException) {
      return ServerFormErrors(general: describeError(l10n, error));
    }
    // Throttling (including daily caps) is about the whole form and says
    // when to try again (Retry-After), which only describeError knows.
    if (error.isThrottled) {
      return ServerFormErrors(general: describeError(l10n, error));
    }
    final Map<String, String> fields = <String, String>{};
    final List<String> unmapped = <String>[];
    for (final Detail detail in error.details) {
      final String? member = ApiException.bodyFieldOf(detail.field);
      final String? field = member == null ? null : fieldMap[member];
      final String message = detailMessage(l10n, detail);
      if (field != null) {
        fields.putIfAbsent(field, () => message);
      } else if (message.isNotEmpty) {
        unmapped.add(message);
      }
    }
    String? general;
    if (unmapped.isNotEmpty) {
      general = unmapped.join('\n');
    } else if (fields.isEmpty) {
      general = generalMessage?.call(error) ?? describeError(l10n, error);
    } else if (error.code != ErrorObjectCode.validationError) {
      general = generalMessage?.call(error);
    }
    return ServerFormErrors(
      fields: Map<String, String>.unmodifiable(fields),
      general: general,
      requestId: _shouldShowReference(error) ? error.requestId : null,
    );
  }

  /// Field id -> message.
  final Map<String, String> fields;

  /// Form-level message, if any.
  final String? general;

  /// Request reference to show with [general].
  final String? requestId;

  /// Whether there is anything to show.
  bool get isEmpty => fields.isEmpty && general == null;

  /// Message for [field], if any.
  String? operator [](String field) => fields[field];

  /// Codes that are ordinary user feedback; a support reference would only
  /// add noise to them.
  static const Set<ErrorObjectCode> _expectedCodes = <ErrorObjectCode>{
    ErrorObjectCode.validationError,
    ErrorObjectCode.unauthenticated,
    ErrorObjectCode.reauthRequired,
    ErrorObjectCode.mfaRequired,
    ErrorObjectCode.mfaCodeInvalid,
    ErrorObjectCode.mfaChallengeExpired,
    ErrorObjectCode.emailNotVerified,
    ErrorObjectCode.rateLimited,
    ErrorObjectCode.loginThrottled,
    ErrorObjectCode.gone,
  };

  /// References help support investigate unexpected server failures.
  static bool _shouldShowReference(ApiException error) =>
      error.kind == ApiErrorKind.server && !_expectedCodes.contains(error.code);
}
