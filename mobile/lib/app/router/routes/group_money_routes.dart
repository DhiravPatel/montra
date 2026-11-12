import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/group_money/presentation/group_balances_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_expense_detail_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_expense_form_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_expenses_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_recurring_detail_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_recurring_form_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_recurring_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_reports_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/group_settlements_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/settlement_detail_screen.dart';
import 'package:montra_mobile/features/group_money/presentation/settlement_form_screen.dart';

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Top-level routes for group expenses, balances, settlements, recurring
/// shared expenses and group reports (round 4; owned by the group money
/// feature). Literal segments come before parameters.
List<RouteBase> groupMoneyRoutes() => <RouteBase>[
  GoRoute(
    path: '/groups/:groupId/expenses',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupExpensesScreen(groupId: state.pathParameters['groupId']!),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/expenses/new',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupExpenseFormScreen(groupId: state.pathParameters['groupId']!),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/expenses/:expenseId',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupExpenseDetailScreen(
        groupId: state.pathParameters['groupId']!,
        expenseId: state.pathParameters['expenseId']!,
      ),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/expenses/:expenseId/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupExpenseFormScreen(
        groupId: state.pathParameters['groupId']!,
        expenseId: state.pathParameters['expenseId'],
      ),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/balances',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupBalancesScreen(groupId: state.pathParameters['groupId']!),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/settlements',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupSettlementsScreen(groupId: state.pathParameters['groupId']!),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/settlements/new',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      SettlementFormScreen(
        groupId: state.pathParameters['groupId']!,
        payerId: _nonEmpty(state.uri.queryParameters['payer']),
        payeeId: _nonEmpty(state.uri.queryParameters['payee']),
        amount: _nonEmpty(state.uri.queryParameters['amount']),
      ),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/settlements/:settlementId',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      SettlementDetailScreen(
        groupId: state.pathParameters['groupId']!,
        settlementId: state.pathParameters['settlementId']!,
      ),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/settlements/:settlementId/correct',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      SettlementFormScreen(
        groupId: state.pathParameters['groupId']!,
        correctsId: state.pathParameters['settlementId'],
      ),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/recurring',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupRecurringScreen(groupId: state.pathParameters['groupId']!),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/recurring/new',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupRecurringFormScreen(groupId: state.pathParameters['groupId']!),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/recurring/:ruleId',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupRecurringDetailScreen(
        groupId: state.pathParameters['groupId']!,
        ruleId: state.pathParameters['ruleId']!,
      ),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/recurring/:ruleId/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupRecurringFormScreen(
        groupId: state.pathParameters['groupId']!,
        ruleId: state.pathParameters['ruleId'],
      ),
    ),
  ),
  GoRoute(
    path: '/groups/:groupId/reports',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupReportsScreen(groupId: state.pathParameters['groupId']!),
    ),
  ),
];
