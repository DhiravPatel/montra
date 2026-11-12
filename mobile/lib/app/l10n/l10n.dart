import 'package:flutter/widgets.dart';
import 'package:montra_mobile/app/l10n/generated/app_localizations.dart';

export 'package:montra_mobile/app/l10n/generated/app_localizations.dart';

/// Shorthand for the generated [AppLocalizations].
extension AppLocalizationsContext on BuildContext {
  /// Localized strings for the current locale.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
