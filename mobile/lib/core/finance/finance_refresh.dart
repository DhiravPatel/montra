import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';

/// The signed-in user's ID, or null. Finance providers depend on it so
/// cached data never outlives the account it belongs to.
final Provider<String?> currentUserIdProvider = Provider<String?>(
  (Ref ref) => ref.watch(
    authControllerProvider.select(
      (AuthState state) => state is SignedIn ? state.user.id : null,
    ),
  ),
);

/// A counter bumped after every successful finance write (transaction,
/// transfer, account, payment method, dashboard layout).
///
/// Finance providers watch it, so lists, balances and dashboard figures are
/// re-read from the server after a change instead of being patched on the
/// client (the server owns every total). It resets when the signed-in user
/// changes.
final NotifierProvider<FinanceRevision, int> financeRevisionProvider =
    NotifierProvider<FinanceRevision, int>(FinanceRevision.new);

/// See [financeRevisionProvider].
class FinanceRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentUserIdProvider);
    return 0;
  }

  /// Marks finance data as changed.
  void bump() => state++;
}

/// Convenience for controllers and screens.
extension FinanceRefreshRef on Ref {
  /// Call after a successful write.
  void financeChanged() => read(financeRevisionProvider.notifier).bump();
}

/// Convenience for widgets.
extension FinanceRefreshWidgetRef on WidgetRef {
  /// Call after a successful write.
  void financeChanged() => read(financeRevisionProvider.notifier).bump();
}
