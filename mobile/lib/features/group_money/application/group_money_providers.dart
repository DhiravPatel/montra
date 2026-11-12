import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_export.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';

// Every group money provider watches the finance revision: an expense or a
// settlement can create or change the caller's own linked transactions, so
// writes bump it (see [groupMoneyChanged]) and everything is re-read from
// the server, which owns every total.

/// The people of group [groupId] as the signed-in user sees them.
final FutureProviderFamily<GroupPeople, String> groupPeopleProvider =
    FutureProvider.autoDispose.family<GroupPeople, String>((
      Ref ref,
      String groupId,
    ) async {
      final String? me = ref.watch(currentUserIdProvider);
      final GroupDetail group = await ref.watch(
        groupDetailProvider(groupId).future,
      );
      return GroupPeople(group, me);
    });

/// Which page of expenses: a group and its filter.
typedef GroupExpensesQuery = ({String groupId, GroupExpenseFilter filter});

/// A group's expenses for a filter, page by page.
final AsyncNotifierProviderFamily<
  GroupExpensesController,
  PagedList<GroupExpenseDto>,
  GroupExpensesQuery
>
groupExpensesProvider = AsyncNotifierProvider.autoDispose
    .family<
      GroupExpensesController,
      PagedList<GroupExpenseDto>,
      GroupExpensesQuery
    >(GroupExpensesController.new);

/// See [groupExpensesProvider].
class GroupExpensesController extends PagedListController<GroupExpenseDto> {
  /// Creates the controller for [query].
  GroupExpensesController(this.query);

  /// The group and filter.
  final GroupExpensesQuery query;

  @override
  Future<PagedList<GroupExpenseDto>> build() {
    ref.watch(financeRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<GroupExpenseDto>> fetchPage(String? cursor) => ref
      .read(groupMoneyApiProvider)
      .expenses(query.groupId, filter: query.filter, cursor: cursor);

  @override
  String keyOf(GroupExpenseDto item) => item.id;
}

/// A group and one of its records.
typedef GroupRecord = ({String groupId, String id});

/// One expense with its items, comments, disputes and history count.
final FutureProviderFamily<GroupExpenseDetail, GroupRecord>
groupExpenseProvider = FutureProvider.autoDispose
    .family<GroupExpenseDetail, GroupRecord>((Ref ref, GroupRecord r) {
      ref.watch(financeRevisionProvider);
      return ref.read(groupMoneyApiProvider).expense(r.groupId, r.id);
    });

/// The balances of group [groupId].
final FutureProviderFamily<GroupBalancesDto, String> groupBalancesProvider =
    FutureProvider.autoDispose.family<GroupBalancesDto, String>((
      Ref ref,
      String groupId,
    ) {
      ref.watch(financeRevisionProvider);
      return ref.read(groupMoneyApiProvider).balances(groupId);
    });

/// Settlement suggestions: everyone's or only the caller's.
typedef SuggestionsQuery = ({String groupId, bool mine});

/// Suggested payments that would settle the group.
final FutureProviderFamily<GroupSuggestionsDto, SuggestionsQuery>
groupSuggestionsProvider = FutureProvider.autoDispose
    .family<GroupSuggestionsDto, SuggestionsQuery>((
      Ref ref,
      SuggestionsQuery q,
    ) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(groupMoneyApiProvider)
          .suggestions(q.groupId, mine: q.mine);
    });

/// Settlements of a group, voided ones included on request.
typedef SettlementsQuery = ({String groupId, bool includeVoided});

/// A group's settlements, newest first.
final FutureProviderFamily<List<SettlementDto>, SettlementsQuery>
groupSettlementsProvider = FutureProvider.autoDispose
    .family<List<SettlementDto>, SettlementsQuery>((
      Ref ref,
      SettlementsQuery q,
    ) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(groupMoneyApiProvider)
          .settlements(q.groupId, includeVoided: q.includeVoided);
    });

/// One settlement.
final FutureProviderFamily<SettlementDto, GroupRecord> groupSettlementProvider =
    FutureProvider.autoDispose.family<SettlementDto, GroupRecord>((
      Ref ref,
      GroupRecord r,
    ) {
      ref.watch(financeRevisionProvider);
      return ref.read(groupMoneyApiProvider).settlement(r.groupId, r.id);
    });

/// A group's recurring shared expenses.
final FutureProviderFamily<List<GroupRecurringDto>, String>
groupRecurringListProvider = FutureProvider.autoDispose
    .family<List<GroupRecurringDto>, String>((Ref ref, String groupId) {
      ref.watch(financeRevisionProvider);
      return ref.read(groupMoneyApiProvider).recurring(groupId);
    });

/// One recurring shared expense with its occurrences.
final FutureProviderFamily<GroupRecurringDto, GroupRecord>
groupRecurringProvider = FutureProvider.autoDispose
    .family<GroupRecurringDto, GroupRecord>((Ref ref, GroupRecord r) {
      ref.watch(financeRevisionProvider);
      return ref.read(groupMoneyApiProvider).recurringRule(r.groupId, r.id);
    });

/// A group report period (`from`/`to` null for all time).
typedef GroupReportQuery = ({String groupId, String? from, String? to});

/// The group report for a period.
final FutureProviderFamily<GroupReportDto, GroupReportQuery>
groupReportProvider = FutureProvider.autoDispose
    .family<GroupReportDto, GroupReportQuery>((Ref ref, GroupReportQuery q) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(groupMoneyApiProvider)
          .report(q.groupId, from: q.from, to: q.to);
    });

/// The CSV export of a group (read when asked for; kept while shown).
final FutureProviderFamily<GroupExport, String> groupExportProvider =
    FutureProvider.autoDispose.family<GroupExport, String>(
      (Ref ref, String groupId) =>
          ref.read(groupMoneyApiProvider).export(groupId),
    );

/// Marks group money (and the caller's linked records) as changed after a
/// successful write: lists, balances, the group's `my_net` and the
/// caller's own transactions are re-read from the server.
void groupMoneyChanged(WidgetRef ref, String groupId) {
  ref.read(financeRevisionProvider.notifier).bump();
  ref
    ..invalidate(groupDetailProvider(groupId))
    ..invalidate(groupsProvider);
}
