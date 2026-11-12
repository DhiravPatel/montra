import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/accounts/domain/account_types.dart';

/// The user's accounts; archived and closed ones too when the argument is
/// true. Re-read after every finance write.
final FutureProviderFamily<List<AccountDto>, bool> accountsProvider =
    FutureProvider.autoDispose.family<List<AccountDto>, bool>((
      Ref ref,
      bool includeArchived,
    ) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(accountsApiProvider)
          .list(includeArchived: includeArchived);
    });

/// Active accounts the user owns: the ones that can take new transactions.
final FutureProvider<List<AccountDto>> usableAccountsProvider =
    FutureProvider.autoDispose<List<AccountDto>>((Ref ref) async {
      final List<AccountDto> all = await ref.watch(
        accountsProvider(false).future,
      );
      return <AccountDto>[
        for (final AccountDto a in all)
          if (isUsableAccount(a)) a,
      ];
    });

/// Accounts by ID, including archived ones (for names in lists).
final Provider<Map<String, AccountDto>> accountIndexProvider =
    Provider.autoDispose<Map<String, AccountDto>>(
      (Ref ref) => <String, AccountDto>{
        for (final AccountDto a
            in ref.watch(accountsProvider(true)).value ?? const <AccountDto>[])
          a.id: a,
      },
    );

/// Server totals per currency (assets, liabilities, net worth).
final FutureProvider<List<BalanceTotals>> accountTotalsProvider =
    FutureProvider.autoDispose<List<BalanceTotals>>((Ref ref) {
      ref.watch(financeRevisionProvider);
      return ref.read(accountsApiProvider).totals();
    });

/// One account, with its lifecycle actions.
final AsyncNotifierProviderFamily<AccountDetailController, AccountDto, String>
accountDetailProvider = AsyncNotifierProvider.autoDispose
    .family<AccountDetailController, AccountDto, String>(
      AccountDetailController.new,
    );

/// Loads an account and archives, restores or closes it.
class AccountDetailController extends AsyncNotifier<AccountDto> {
  /// Creates the controller for [accountId].
  AccountDetailController(this.accountId);

  /// The account.
  final String accountId;

  AccountsApi get _api => ref.read(accountsApiProvider);

  @override
  Future<AccountDto> build() {
    ref.watch(financeRevisionProvider);
    return _api.get(accountId);
  }

  /// Archives the account (history is kept; no new transactions).
  Future<void> archive() => _apply(_api.archive);

  /// Makes an archived or closed account active again.
  Future<void> restore() => _apply(_api.restore);

  /// Closes the account (the server requires a zero balance).
  Future<void> close() => _apply(_api.close);

  /// Applies a lifecycle change with the version shown, so a concurrent
  /// edit answers `VERSION_CONFLICT` instead of being overwritten.
  Future<void> _apply(
    Future<AccountDto> Function(String id, {int? version}) action,
  ) async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AccountDto updated = await action(
      accountId,
      version: state.value?.version,
    );
    if (ref.mounted) {
      state = AsyncData<AccountDto>(updated);
    }
    finance.bump();
  }
}

/// Daily balance history for the last 30 days (server-calculated).
final FutureProviderFamily<BalanceReport, String> accountHistoryProvider =
    FutureProvider.autoDispose.family<BalanceReport, String>((
      Ref ref,
      String accountId,
    ) {
      ref.watch(financeRevisionProvider);
      final DateTime from = LocalDates.today().subtract(
        const Duration(days: 29),
      );
      return ref
          .read(accountsApiProvider)
          .balance(accountId, from: LocalDates.format(from));
    });

/// The most recent transactions of an account.
final FutureProviderFamily<CursorPage<TransactionDto>, String>
accountRecentTransactionsProvider = FutureProvider.autoDispose
    .family<CursorPage<TransactionDto>, String>((Ref ref, String accountId) {
      ref.watch(financeRevisionProvider);
      return ref.read(accountsApiProvider).transactions(accountId, limit: 10);
    });
