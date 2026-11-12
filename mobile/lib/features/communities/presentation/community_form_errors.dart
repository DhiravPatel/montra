import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';

/// Form errors for community and challenge forms. A daily cap (429
/// `daily_cap`) is shown with the wait from `Retry-After` (through
/// [describeError]); everything else maps onto the form's fields.
ServerFormErrors formErrorsOf(
  AppLocalizations l10n,
  ApiException error,
  Map<String, String> fields,
) => error.code == ErrorObjectCode.rateLimited
    ? ServerFormErrors(general: describeError(l10n, error))
    : ServerFormErrors.from(l10n, error, fieldMap: fields);
