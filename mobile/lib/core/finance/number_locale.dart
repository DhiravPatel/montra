import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';

/// The locale used to format amounts and numbers.
///
/// The app language comes from the device (`en` or `hi`); the region comes
/// from the account's locale (`en-IN` from sign-up), so English users in
/// India get lakh/crore grouping (`12,34,567.00`) while others keep their
/// regional grouping. Hindi always uses Indian grouping.
String numberLocaleOf(BuildContext context, WidgetRef ref) {
  final Locale app = Localizations.localeOf(context);
  final String? account = ref.watch(
    authControllerProvider.select(
      (AuthState state) => state is SignedIn ? state.user.locale : null,
    ),
  );
  return resolveNumberLocale(app, account);
}

/// Pure resolution rule behind [numberLocaleOf] (exposed for tests).
String resolveNumberLocale(Locale app, String? accountLocale) {
  final String? account = accountLocale?.trim();
  if (account != null &&
      account.isNotEmpty &&
      account.toLowerCase().split(RegExp('[-_]')).first == app.languageCode) {
    return account.replaceAll('-', '_');
  }
  return app.toString();
}
