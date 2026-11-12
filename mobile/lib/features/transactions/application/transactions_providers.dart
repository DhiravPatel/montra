import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

/// Loaded pages of a transaction list.
@immutable
class TransactionListState {
  /// Creates the state.
  const TransactionListState({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Transactions loaded so far, in server order.
  final List<TransactionDto> items;

  /// Cursor of the next page; null after the last page.
  final String? nextCursor;

  /// Whether the next page is being fetched.
  final bool loadingMore;

  /// Why the last "load more" failed (the loaded items stay visible).
  final Object? loadMoreError;

  /// Whether more pages exist.
  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

/// A paginated, filtered transaction list (infinite scroll). Keyed by the
/// filter; re-read from the first page after any finance write.
final AsyncNotifierProviderFamily<
  TransactionsListController,
  TransactionListState,
  TransactionFilter
>
transactionsListProvider = AsyncNotifierProvider.autoDispose
    .family<
      TransactionsListController,
      TransactionListState,
      TransactionFilter
    >(TransactionsListController.new);

/// See [transactionsListProvider].
class TransactionsListController extends AsyncNotifier<TransactionListState> {
  /// Creates the controller for [filter].
  TransactionsListController(this.filter);

  /// Page size.
  static const int pageSize = 50;

  /// The filter.
  final TransactionFilter filter;

  TransactionsApi get _api => ref.read(transactionsApiProvider);

  @override
  Future<TransactionListState> build() async {
    ref.watch(financeRevisionProvider);
    final CursorPage<TransactionDto> page = await _api.list(
      filter,
      limit: pageSize,
    );
    return TransactionListState(items: page.items, nextCursor: page.nextCursor);
  }

  /// Loads the next page, if any. Failures keep the loaded items and are
  /// reported in [TransactionListState.loadMoreError].
  Future<void> loadMore() async {
    final TransactionListState? current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        state.isLoading) {
      return;
    }
    state = AsyncData<TransactionListState>(
      TransactionListState(
        items: current.items,
        nextCursor: current.nextCursor,
        loadingMore: true,
      ),
    );
    try {
      final CursorPage<TransactionDto> page = await _api.list(
        filter,
        cursor: current.nextCursor,
        limit: pageSize,
      );
      if (!ref.mounted) {
        return;
      }
      final Set<String> seen = <String>{
        for (final TransactionDto t in current.items) t.id,
      };
      state = AsyncData<TransactionListState>(
        TransactionListState(
          items: <TransactionDto>[
            ...current.items,
            for (final TransactionDto t in page.items)
              if (!seen.contains(t.id)) t,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<TransactionListState>(
        TransactionListState(
          items: current.items,
          nextCursor: current.nextCursor,
          loadMoreError: error,
        ),
      );
    }
  }

  /// Reloads from the first page.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // Exposed through `state`.
    }
  }
}

/// One transaction with its actions (void, restore, duplicate).
final AsyncNotifierProviderFamily<
  TransactionDetailController,
  TransactionDto,
  String
>
transactionDetailProvider = AsyncNotifierProvider.autoDispose
    .family<TransactionDetailController, TransactionDto, String>(
      TransactionDetailController.new,
    );

/// See [transactionDetailProvider].
class TransactionDetailController extends AsyncNotifier<TransactionDto> {
  /// Creates the controller for [transactionId].
  TransactionDetailController(this.transactionId);

  /// The transaction.
  final String transactionId;

  TransactionsApi get _api => ref.read(transactionsApiProvider);

  @override
  Future<TransactionDto> build() {
    ref.watch(financeRevisionProvider);
    return _api.get(transactionId);
  }

  /// Voids the transaction (a transfer leg voids the whole transfer).
  Future<void> delete() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final TransactionDto voided = await _api.delete(transactionId);
    if (ref.mounted) {
      state = AsyncData<TransactionDto>(voided);
    }
    finance.bump();
  }

  /// Restores a voided transaction.
  Future<void> restore() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final TransactionDto restored = await _api.restore(transactionId);
    if (ref.mounted) {
      state = AsyncData<TransactionDto>(restored);
    }
    finance.bump();
  }

  /// Duplicates the transaction with an idempotency [key].
  Future<CreateResult> duplicate({
    String? localDate,
    required String key,
  }) async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final CreateResult result = await _api.duplicate(
      transactionId,
      localDate: localDate,
      key: key,
    );
    finance.bump();
    return result;
  }
}

/// Audit history of a transaction.
final FutureProviderFamily<List<AuditEventDto>, String>
transactionAuditProvider = FutureProvider.autoDispose
    .family<List<AuditEventDto>, String>((Ref ref, String id) {
      ref.watch(financeRevisionProvider);
      return ref.read(transactionsApiProvider).audit(id);
    });

/// Files attached to a transaction.
final FutureProviderFamily<List<AttachmentDto>, String>
transactionAttachmentsProvider = FutureProvider.autoDispose
    .family<List<AttachmentDto>, String>((Ref ref, String id) {
      ref.watch(financeRevisionProvider);
      return ref.read(transactionsApiProvider).attachments(id);
    });

/// A transfer by ID (both sides, fee, rate, date, description, notes).
final FutureProviderFamily<TransferDto, String> transferDetailProvider =
    FutureProvider.autoDispose.family<TransferDto, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(financeRevisionProvider);
      return ref.read(transactionsApiProvider).getTransfer(id);
    });
