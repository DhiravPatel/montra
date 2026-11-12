import 'package:montra_mobile/app/router/app_routes.dart';

/// Reconciliation locations beyond those in [AppRoutes] (owned by the
/// reconciliation feature).
abstract final class ReconciliationPaths {
  /// Statement lines of account [accountId] to match by hand; [matched]
  /// opens the lines already matched by hand.
  static String lines(String accountId, {bool matched = false}) => Uri(
    path: '${AppRoutes.reconcileAccount(accountId)}/lines',
    queryParameters: matched ? <String, String>{'status': 'matched'} : null,
  ).toString();
}
