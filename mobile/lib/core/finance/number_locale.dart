import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/settings/app_preferences.dart';

/// The locale used to format amounts and numbers.
///
/// The account's number format preference decides the grouping: `indian`
/// always groups in lakh and crore (`12,34,567.00`), `international` in
/// thousands (`1,234,567.00`). With `locale` (the default) the app language
/// (`en` or `hi`) and the account's locale region (`en-IN` from sign-up)
/// decide, so English users in India get lakh/crore grouping while others
/// keep their regional grouping; Hindi always uses Indian grouping.
String numberLocaleOf(BuildContext context, WidgetRef ref) {
  final Locale app = Localizations.localeOf(context);
  final String? account = ref.watch(
    authControllerProvider.select(
      (AuthState state) => state is SignedIn ? state.user.locale : null,
    ),
  );
  return resolveNumberLocale(
    app,
    account,
    numberFormat: ref.watch(numberFormatPreferenceProvider),
  );
}

/// Pure resolution rule behind [numberLocaleOf] (exposed for tests).
String resolveNumberLocale(
  Locale app,
  String? accountLocale, {
  String? numberFormat,
}) {
  switch (numberFormat) {
    case 'indian':
      return '${app.languageCode}_IN';
    case 'international':
      // Thousands grouping with Latin digits in both app languages.
      return 'en_US';
  }
  final String? account = accountLocale?.trim();
  if (account != null &&
      account.isNotEmpty &&
      account.toLowerCase().split(RegExp('[-_]')).first == app.languageCode) {
    return account.replaceAll('-', '_');
  }
  return app.toString();
}
