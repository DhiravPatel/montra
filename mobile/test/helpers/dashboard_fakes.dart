import 'package:montra_mobile/core/api/generated/models.dart';

import 'budgets_fakes.dart';
import 'finance_fakes.dart';
import 'goals_fakes.dart';
import 'planning_fakes.dart';

/// A `GroupBalance` (positive [net]: the user is owed).
Map<String, Object?> groupBalanceJson({
  String groupId = 'g1',
  String name = 'Flat 4B',
  String type = 'roommates',
  String net = '1000.00',
  String currency = 'INR',
}) => <String, Object?>{
  'group_id': groupId,
  'name': name,
  'group_type': type,
  'my_net': moneyJson(net, currency: currency),
};

/// A `RecurringCommitment` JSON object (monthly amounts per kind and
/// currency, as `GET /analytics/recurring` sends them).
Map<String, Object?> commitmentJson({
  String kind = 'expense',
  String currency = 'INR',
  String monthly = '1499.00',
  String next30 = '1499.00',
  int rules = 1,
  int variable = 0,
}) => <String, Object?>{
  'kind': kind,
  'currency': currency,
  'monthly_equivalent': moneyJson(monthly, currency: currency),
  'next_30_days': moneyJson(next30, currency: currency),
  'rule_count': rules,
  'variable_count': variable,
};

/// A `DashboardPlanning` answer as the live API sends it (fullest budget
/// first, overdue items first, newest alert first, soonest renewal
/// first). [empty] has no items and zero counts.
DashboardPlanning dashboardPlanning({
  bool empty = false,
  List<BudgetDto>? budgets,
  List<CalendarItem>? upcoming,
  List<GoalDto>? goals,
  List<Map<String, Object?>>? groupBalances,
  List<AlertDto>? alerts,
  List<CalendarItem>? renewals,
  List<Map<String, Object?>>? recurring,
  String recurringNoteCode = 'fixed_amounts_expectations',
  int? budgetCount,
  int? overBudgetCount,
  int? upcomingCount,
  int? overdueCount,
  int? goalCount,
  int? groupCount,
  int? alertCount,
  int? renewalCount,
}) {
  final List<BudgetDto> b =
      budgets ??
      (empty
          ? <BudgetDto>[]
          : <BudgetDto>[
              budget(
                name: 'Food budget',
                progress: progressJson(
                  spent: '12500.50',
                  limit: '10000.00',
                  remaining: '0.00',
                  overspent: '2500.50',
                  percentBp: 12500,
                  pace: 'over_budget',
                ),
              ),
              budget(id: 'bud-2', name: 'Monthly spending'),
            ]);
  final List<CalendarItem> u =
      upcoming ??
      (empty
          ? <CalendarItem>[]
          : <CalendarItem>[
              calendarItem(date: '2026-11-08', status: 'overdue'),
              calendarItem(
                date: '2026-11-20',
                title: 'Internet',
                entityId: 'bill-2',
                amount: '799.00',
              ),
            ]);
  final List<GoalDto> g = goals ?? (empty ? <GoalDto>[] : <GoalDto>[goal()]);
  final List<Map<String, Object?>> gb =
      groupBalances ??
      (empty
          ? <Map<String, Object?>>[]
          : <Map<String, Object?>>[
              groupBalanceJson(),
              groupBalanceJson(
                groupId: 'g2',
                name: 'Goa trip',
                type: 'trip',
                net: '-450.25',
              ),
            ]);
  final List<AlertDto> a =
      alerts ??
      (empty
          ? <AlertDto>[]
          : <AlertDto>[
              budgetAlert(budgetName: 'Food budget', threshold: 100),
              budgetAlert(
                id: 'alert-2',
                budgetId: 'bud-2',
                kind: 'forecast_overspend',
              ),
            ]);
  final List<CalendarItem> r =
      renewals ??
      (empty
          ? <CalendarItem>[]
          : <CalendarItem>[
              calendarItem(
                date: '2026-11-12',
                kind: 'subscription_renewal',
                entityType: 'subscription',
                entityId: 'sub-1',
                title: 'Netflix',
                status: 'expected',
                amount: '649.00',
              ),
              calendarItem(
                date: '2026-11-30',
                kind: 'trial_end',
                entityType: 'subscription',
                entityId: 'sub-2',
                title: 'Music Plus',
                status: 'expected',
                amount: '119.00',
              ),
            ]);
  final List<Map<String, Object?>> rc =
      recurring ??
      (empty
          ? <Map<String, Object?>>[]
          : <Map<String, Object?>>[
              commitmentJson(monthly: '12499.50', rules: 2, variable: 1),
              commitmentJson(kind: 'income', monthly: '85000.00'),
              commitmentJson(
                kind: 'subscription',
                currency: 'USD',
                monthly: '19.99',
                next30: '19.99',
              ),
            ]);
  return DashboardPlanning.fromJson(<String, Object?>{
    'today': '2026-11-12',
    'upcoming_through': '2026-11-26',
    'budgets': <Object?>[for (final BudgetDto x in b) x.toJson()],
    'budget_count': budgetCount ?? b.length,
    'over_budget_count': overBudgetCount ?? (empty ? 0 : 1),
    'upcoming': <Object?>[for (final CalendarItem x in u) x.toJson()],
    'upcoming_count': upcomingCount ?? u.length,
    'overdue_count': overdueCount ?? (empty ? 0 : 1),
    'goals': <Object?>[for (final GoalDto x in g) x.toJson()],
    'goal_count': goalCount ?? g.length,
    'group_balances': gb,
    'group_count': groupCount ?? gb.length,
    'alerts': <Object?>[for (final AlertDto x in a) x.toJson()],
    'alert_count': alertCount ?? a.length,
    'renewals_through': '2026-12-12',
    'renewals': <Object?>[for (final CalendarItem x in r) x.toJson()],
    'renewal_count': renewalCount ?? r.length,
    'recurring': rc,
    'recurring_note_code': recurringNoteCode,
  });
}
