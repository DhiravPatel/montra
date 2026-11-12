import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';

/// Bumped after every budget or alert change so lists, alerts and the
/// Home banner re-read. Reset when the signed-in user changes.
final NotifierProvider<BudgetRevision, int> budgetRevisionProvider =
    NotifierProvider<BudgetRevision, int>(BudgetRevision.new);

/// A counter of budget changes.
class BudgetRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentUserIdProvider);
    return 0;
  }

  /// Marks budget data as changed.
  void bump() => state++;
}

/// Budgets with current progress; archived ones too when the argument is
/// true. Progress depends on transactions, so finance writes refresh it.
final FutureProviderFamily<List<BudgetDto>, bool> budgetsProvider =
    FutureProvider.autoDispose.family<List<BudgetDto>, bool>((
      Ref ref,
      bool includeArchived,
    ) {
      ref
        ..watch(financeRevisionProvider)
        ..watch(budgetRevisionProvider);
      return ref
          .read(budgetsApiProvider)
          .list(includeArchived: includeArchived);
    });

/// One budget with its lifecycle and sharing actions.
final AsyncNotifierProviderFamily<BudgetDetailController, BudgetDto, String>
budgetDetailProvider = AsyncNotifierProvider.autoDispose
    .family<BudgetDetailController, BudgetDto, String>(
      BudgetDetailController.new,
    );

/// Loads a budget; pauses, resumes, archives, restores it and manages its
/// members. Each action sends the displayed `version` (a change made
/// elsewhere answers `VERSION_CONFLICT`), shows the server's answer and
/// refreshes the lists.
class BudgetDetailController extends AsyncNotifier<BudgetDto> {
  /// Creates the controller for [budgetId].
  BudgetDetailController(this.budgetId);

  /// The budget.
  final String budgetId;

  BudgetsApi get _api => ref.read(budgetsApiProvider);

  int? get _version => state.value?.version;

  @override
  Future<BudgetDto> build() {
    ref.watch(financeRevisionProvider);
    return _api.get(budgetId);
  }

  /// Stops tracking until resumed (active budgets only).
  Future<void> pause() => _apply(() => _api.pause(budgetId, version: _version));

  /// Tracks a paused budget again.
  Future<void> resume() =>
      _apply(() => _api.resume(budgetId, version: _version));

  /// Makes an archived budget active again.
  Future<void> restore() =>
      _apply(() => _api.restore(budgetId, version: _version));

  /// Archives the budget; its history is kept.
  Future<void> archive() =>
      _apply(() => _api.archive(budgetId, version: _version));

  /// Shares the budget with someone.
  Future<void> addMember(MemberInput input) =>
      _apply(() => _api.addMember(budgetId, input));

  /// Changes a member's role or allocation.
  Future<void> updateMember(
    String userId,
    BudgetsMembersUpdateRequest change,
  ) => _apply(() => _api.updateMember(budgetId, userId, change));

  /// Removes a member (the owner) or leaves (a member removing
  /// themselves). The budget is re-read afterwards unless [leaving].
  Future<void> removeMember(String userId, {bool leaving = false}) async {
    final BudgetRevision revision = ref.read(budgetRevisionProvider.notifier);
    await _api.removeMember(budgetId, userId);
    revision.bump();
    if (!leaving && ref.mounted) {
      ref.invalidateSelf();
    }
  }

  /// Shows a budget saved elsewhere (the edit form).
  void show(BudgetDto budget) => state = AsyncData<BudgetDto>(budget);

  Future<void> _apply(Future<BudgetDto> Function() action) async {
    final BudgetRevision revision = ref.read(budgetRevisionProvider.notifier);
    final BudgetDto updated = await action();
    if (ref.mounted) {
      state = AsyncData<BudgetDto>(updated);
    }
    revision.bump();
  }
}

/// Which period of a budget to look at: the one containing [date], or the
/// current one when [date] is null.
typedef BudgetPeriodKey = ({String budgetId, String? date});

/// Progress of a period and the period before it (server figures).
final FutureProviderFamily<List<ProgressDto>, BudgetPeriodKey>
budgetHistoryProvider = FutureProvider.autoDispose
    .family<List<ProgressDto>, BudgetPeriodKey>((Ref ref, BudgetPeriodKey key) {
      ref
        ..watch(financeRevisionProvider)
        ..watch(budgetRevisionProvider);
      return ref
          .read(budgetsApiProvider)
          .progress(key.budgetId, date: key.date);
    });

/// The transactions counted in a period, page by page (owner only;
/// exactly the transactions the total counts).
final AsyncNotifierProviderFamily<
  BudgetTransactionsController,
  PagedList<TransactionDto>,
  BudgetPeriodKey
>
budgetTransactionsProvider = AsyncNotifierProvider.autoDispose
    .family<
      BudgetTransactionsController,
      PagedList<TransactionDto>,
      BudgetPeriodKey
    >(BudgetTransactionsController.new);

/// See [budgetTransactionsProvider].
class BudgetTransactionsController extends PagedListController<TransactionDto> {
  /// Creates the controller for [key].
  BudgetTransactionsController(this.key);

  /// The budget and period.
  final BudgetPeriodKey key;

  @override
  Future<PagedList<TransactionDto>> build() {
    ref
      ..watch(financeRevisionProvider)
      ..watch(budgetRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<TransactionDto>> fetchPage(String? cursor) => ref
      .read(budgetsApiProvider)
      .transactions(key.budgetId, date: key.date, cursor: cursor);

  @override
  String keyOf(TransactionDto item) => item.id;
}

/// Budget alerts with [status] (`active`, `snoozed`, `dismissed`), or all
/// alerts when it is null. New alerts follow finance writes.
final FutureProviderFamily<List<AlertDto>, String?> budgetAlertsProvider =
    FutureProvider.autoDispose.family<List<AlertDto>, String?>((
      Ref ref,
      String? status,
    ) {
      ref
        ..watch(financeRevisionProvider)
        ..watch(budgetRevisionProvider);
      return ref.read(budgetsApiProvider).alerts(status: status);
    });

/// The active alerts of one budget (`GET /budget-alerts?budget_id=`), for
/// its detail screen.
final FutureProviderFamily<List<AlertDto>, String> budgetOwnAlertsProvider =
    FutureProvider.autoDispose.family<List<AlertDto>, String>((
      Ref ref,
      String budgetId,
    ) {
      ref
        ..watch(financeRevisionProvider)
        ..watch(budgetRevisionProvider);
      return ref
          .read(budgetsApiProvider)
          .alerts(status: 'active', budgetId: budgetId);
    });

/// Budget alerts with a status (null: all), page by page, for the alerts
/// screen.
final AsyncNotifierProviderFamily<
  BudgetAlertsPageController,
  PagedList<AlertDto>,
  String?
>
budgetAlertsPageProvider = AsyncNotifierProvider.autoDispose
    .family<BudgetAlertsPageController, PagedList<AlertDto>, String?>(
      BudgetAlertsPageController.new,
    );

/// See [budgetAlertsPageProvider].
class BudgetAlertsPageController extends PagedListController<AlertDto> {
  /// Creates the controller for [status].
  BudgetAlertsPageController(this.status);

  /// `active`, `snoozed`, `dismissed`, or null for all.
  final String? status;

  @override
  Future<PagedList<AlertDto>> build() {
    ref
      ..watch(financeRevisionProvider)
      ..watch(budgetRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<AlertDto>> fetchPage(String? cursor) =>
      ref.read(budgetsApiProvider).alertsPage(status: status, cursor: cursor);

  @override
  String keyOf(AlertDto item) => item.id;
}

/// A merchant's details, for the names of merchants a budget counts.
final FutureProviderFamily<MerchantDetail, String> budgetMerchantProvider =
    FutureProvider.autoDispose.family<MerchantDetail, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(currentUserIdProvider);
      return ref.read(budgetsApiProvider).merchant(id);
    });
