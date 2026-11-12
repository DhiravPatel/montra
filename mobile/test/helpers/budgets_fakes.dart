import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/budgets/data/budgets_api.dart';

import 'finance_fakes.dart';

class MockBudgetsApi extends Mock implements BudgetsApi {}

/// The signed-in test user's ID (see `fakes.dart`).
const String testUserId = '7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11';

/// Registers fallback values for budget `any()` matchers.
void registerBudgetFallbacks() {
  registerFinanceFallbacks();
  registerFallbackValue(
    const BudgetInput(
      budgetType: BudgetInputBudgetType.total,
      currency: 'INR',
      limit: '1',
      name: 'x',
      period: BudgetInputPeriod.monthly,
    ),
  );
  registerFallbackValue(const BudgetPatch(version: 1));
  registerFallbackValue(
    const MemberInput(role: MemberInputRole.viewer, userId: 'u'),
  );
  registerFallbackValue(
    const BudgetsMembersUpdateRequest(
      role: BudgetsMembersUpdateRequestRole.viewer,
    ),
  );
  registerFallbackValue(
    const BudgetAlertsUpdateRequest(
      status: BudgetAlertsUpdateRequestStatus.active,
    ),
  );
}

/// A `ProgressDTO` as JSON (server figures; nothing is derived here).
Map<String, Object?> progressJson({
  String spent = '4000.00',
  String limit = '10000.00',
  String baseLimit = '10000.00',
  String remaining = '6000.00',
  String overspent = '0.00',
  int percentBp = 4000,
  String pace = 'on_track',
  int elapsedDays = 12,
  int totalDays = 30,
  String periodStart = '2026-11-01',
  String periodEnd = '2026-11-30',
  String expectedByNow = '4000.00',
  String projected = '10000.00',
  String projectedOver = '0.00',
  String dailyAllowance = '333.33',
  String rolloverIn = '0.00',
  int transactionCount = 3,
  int otherCurrencyCount = 0,
  String? asOf,
  String currency = 'INR',
  bool refundsRestore = true,
  bool collaborator = false,
  List<Map<String, Object?>>? explanationItems,
}) => <String, Object?>{
  'period_start': periodStart,
  'period_end': periodEnd,
  'base_limit': moneyJson(baseLimit, currency: currency),
  'rollover_in': moneyJson(rolloverIn, currency: currency),
  'limit': moneyJson(limit, currency: currency),
  'spent': moneyJson(spent, currency: currency),
  'remaining': moneyJson(remaining, currency: currency),
  'overspent': moneyJson(overspent, currency: currency),
  'percent_bp': percentBp,
  'elapsed_days': elapsedDays,
  'total_days': totalDays,
  'expected_by_now': moneyJson(expectedByNow, currency: currency),
  'projected': moneyJson(projected, currency: currency),
  'projected_over': moneyJson(projectedOver, currency: currency),
  'daily_allowance': moneyJson(dailyAllowance, currency: currency),
  'pace': pace,
  'transaction_count': transactionCount,
  'other_currency_count': otherCurrencyCount,
  'explanation': <String>['Spent $spent of $limit.'],
  'explanation_items':
      explanationItems ??
      <Map<String, Object?>>[
        <String, Object?>{
          'code': 'spent_of_limit',
          'params': <String, String>{
            'spent': spent,
            'limit': limit,
            'currency': currency,
            'from': periodStart,
            'to': periodEnd,
          },
        },
        <String, Object?>{
          'code': refundsRestore ? 'refunds_restore' : 'refunds_do_not_restore',
        },
        if (rolloverIn != '0.00')
          <String, Object?>{
            'code': 'rollover_included',
            'params': <String, String>{
              'amount': rolloverIn,
              'currency': currency,
            },
          },
        if (elapsedDays > 0 && elapsedDays < totalDays)
          <String, Object?>{
            'code': 'projection_estimate',
            'params': <String, String>{
              'projected': projected,
              'currency': currency,
            },
          },
        if (otherCurrencyCount > 0)
          <String, Object?>{
            'code': 'other_currencies_excluded',
            'params': <String, String>{'count': '$otherCurrencyCount'},
          },
        if (collaborator) <String, Object?>{'code': 'owner_totals_only'},
      ],
  'as_of': ?asOf,
};

/// A `ProgressDTO`.
ProgressDto progress({
  String spent = '4000.00',
  String limit = '10000.00',
  int percentBp = 4000,
  String pace = 'on_track',
  String periodStart = '2026-11-01',
  String periodEnd = '2026-11-30',
}) => ProgressDto.fromJson(
  progressJson(
    spent: spent,
    limit: limit,
    percentBp: percentBp,
    pace: pace,
    periodStart: periodStart,
    periodEnd: periodEnd,
  ),
);

/// An `AllocationDTO` as JSON.
Map<String, Object?> allocationJson({
  String id = 'alloc-1',
  String? categoryId,
  String? merchantId,
  String? accountId,
  String? memberUserId,
  String? label,
  String limit = '6000.00',
  String spent = '1500.00',
  String remaining = '4500.00',
  String overspent = '0.00',
  int percentBp = 2500,
}) => <String, Object?>{
  'id': id,
  'category_id': ?categoryId,
  'merchant_id': ?merchantId,
  'account_id': ?accountId,
  'member_user_id': ?memberUserId,
  'label': ?label,
  'limit': moneyJson(limit),
  'spent': moneyJson(spent),
  'remaining': moneyJson(remaining),
  'overspent': moneyJson(overspent),
  'percent_bp': percentBp,
};

/// A `MemberDTO` as JSON.
Map<String, Object?> budgetMemberJson({
  String id = 'u-asha',
  String name = 'Asha Rao',
  String role = 'viewer',
  String? allocation,
}) => <String, Object?>{
  'user_id': id,
  'display_name': name,
  'role': role,
  if (allocation != null) 'allocation': moneyJson(allocation),
};

/// A `BudgetDTO` as JSON.
Map<String, Object?> budgetJson({
  String id = 'bud-1',
  String name = 'Monthly spending',
  String type = 'total',
  String period = 'monthly',
  String status = 'active',
  String access = 'owner',
  String owner = testUserId,
  String ownerName = 'Asha Rao',
  String limit = '10000.00',
  String currency = 'INR',
  Map<String, Object?>? progress,
  bool withProgress = true,
  List<Map<String, Object?>> allocations = const <Map<String, Object?>>[],
  List<Map<String, Object?>> members = const <Map<String, Object?>>[],
  String? groupId,
  List<String> merchantIds = const <String>[],
  List<String> accountIds = const <String>[],
  List<String> excludedIds = const <String>[],
  String rollover = 'none',
  String? rolloverCap,
  String visibility = 'private',
  String? notes,
  String startsOn = '2026-11-01',
  String? endsOn,
  bool includePending = false,
  bool refundsRestore = true,
  bool countGroupShares = true,
  bool alertForecast = true,
  List<int> thresholds = const <int>[50, 75, 90, 100],
  int version = 3,
}) => <String, Object?>{
  'id': id,
  'owner_user_id': owner,
  'owner_display_name': ownerName,
  'name': name,
  'budget_type': type,
  'period': period,
  'status': status,
  'access': access,
  'currency': currency,
  'limit': moneyJson(limit, currency: currency),
  if (withProgress && status == 'active')
    'progress':
        progress ??
        progressJson(
          currency: currency,
          refundsRestore: refundsRestore,
          collaborator: access != 'owner',
        ),
  'allocations': allocations,
  'members': members,
  'group_id': ?groupId,
  'merchant_ids': merchantIds,
  'included_account_ids': accountIds,
  'excluded_category_ids': excludedIds,
  'rollover_policy': rollover,
  if (rolloverCap != null) 'rollover_cap': moneyJson(rolloverCap),
  'visibility': visibility,
  'notes': ?notes,
  'starts_on': startsOn,
  'ends_on': ?endsOn,
  'include_pending': includePending,
  'refunds_restore': refundsRestore,
  'count_group_shares': countGroupShares,
  'alert_forecast': alertForecast,
  'alert_thresholds': thresholds,
  'timezone': 'Asia/Kolkata',
  'created_at': '2026-11-01T08:00:00Z',
  'updated_at': '2026-11-04T08:00:00Z',
  'version': version,
};

/// A `BudgetDTO`.
BudgetDto budget({
  String id = 'bud-1',
  String name = 'Monthly spending',
  String type = 'total',
  String period = 'monthly',
  String status = 'active',
  String access = 'owner',
  String owner = testUserId,
  String ownerName = 'Asha Rao',
  Map<String, Object?>? progress,
  List<Map<String, Object?>> allocations = const <Map<String, Object?>>[],
  List<Map<String, Object?>> members = const <Map<String, Object?>>[],
  String? groupId,
  List<String> merchantIds = const <String>[],
  String visibility = 'private',
  String? notes,
  List<int> thresholds = const <int>[50, 75, 90, 100],
  int version = 3,
}) => BudgetDto.fromJson(
  budgetJson(
    id: id,
    name: name,
    type: type,
    period: period,
    status: status,
    access: access,
    owner: owner,
    ownerName: ownerName,
    thresholds: thresholds,
    progress: progress,
    allocations: allocations,
    members: members,
    groupId: groupId,
    merchantIds: merchantIds,
    visibility: visibility,
    notes: notes,
    version: version,
  ),
);

/// An `AlertDTO`.
AlertDto budgetAlert({
  String id = 'alert-1',
  String budgetId = 'bud-1',
  String budgetName = 'Monthly spending',
  String kind = 'threshold',
  int threshold = 90,
  String status = 'active',
  String? snoozedUntil,
}) => AlertDto.fromJson(<String, Object?>{
  'id': id,
  'budget_id': budgetId,
  'budget_name': budgetName,
  'kind': kind,
  'threshold': threshold,
  'status': status,
  'period_start': '2026-11-01',
  'triggered_at': '2026-11-04T09:30:00Z',
  'snoozed_until': ?snoozedUntil,
});

/// One page of [items] (more after it when [next] is set).
CursorPage<T> budgetPage<T>(List<T> items, {String? next}) =>
    CursorPage<T>(items, next);

/// Stubs reads every budget screen makes, with no alerts by default.
void stubBudgetBasics(
  MockBudgetsApi api, {
  List<AlertDto> activeAlerts = const <AlertDto>[],
}) {
  // Active alerts (all budgets, or one with `?budget_id=`).
  when(
    () => api.alerts(
      status: any(named: 'status'),
      budgetId: any(named: 'budgetId'),
    ),
  ).thenAnswer((Invocation i) async {
    if (i.namedArguments[#status] != 'active') {
      return <AlertDto>[];
    }
    final Object? budgetId = i.namedArguments[#budgetId];
    return <AlertDto>[
      for (final AlertDto a in activeAlerts)
        if (budgetId == null || a.budgetId == budgetId) a,
    ];
  });
  when(
    () => api.alertsPage(
      status: any(named: 'status'),
      cursor: any(named: 'cursor'),
    ),
  ).thenAnswer((_) async => budgetPage(<AlertDto>[]));
  when(
    () => api.alertsPage(
      status: 'active',
      cursor: any(named: 'cursor'),
    ),
  ).thenAnswer((_) async => budgetPage(activeAlerts));
}

/// Stubs the counted transactions of [budgetId] with one page of [items].
void stubBudgetTransactions(
  MockBudgetsApi api,
  String budgetId,
  List<TransactionDto> items, {
  String? next,
}) {
  when(
    () => api.transactions(
      budgetId,
      date: any(named: 'date'),
      cursor: any(named: 'cursor'),
    ),
  ).thenAnswer((_) async => budgetPage(items, next: next));
}
