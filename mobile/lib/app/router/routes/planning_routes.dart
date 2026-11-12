import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/bills/presentation/bill_detail_screen.dart';
import 'package:montra_mobile/features/bills/presentation/bill_form_screen.dart';
import 'package:montra_mobile/features/bills/presentation/bill_pay_screen.dart';
import 'package:montra_mobile/features/bills/presentation/bills_screen.dart';
import 'package:montra_mobile/features/calendar/presentation/calendar_screen.dart';
import 'package:montra_mobile/features/recurring/presentation/recurring_detail_screen.dart';
import 'package:montra_mobile/features/recurring/presentation/recurring_form_screen.dart';
import 'package:montra_mobile/features/recurring/presentation/recurring_list_screen.dart';

/// Top-level routes (pushed over the tabs) for: Recurring rules, bills and
/// the planning calendar. Literal segments (`new`) come before `:id`.
List<RouteBase> planningRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.recurring,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const RecurringListScreen()),
  ),
  GoRoute(
    path: AppRoutes.newRecurring,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const RecurringFormScreen()),
  ),
  GoRoute(
    path: '/recurring/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      RecurringDetailScreen(ruleId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/recurring/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      RecurringFormScreen(ruleId: state.pathParameters['id']),
    ),
  ),
  GoRoute(
    path: AppRoutes.bills,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const BillsScreen()),
  ),
  GoRoute(
    path: AppRoutes.newBill,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const BillFormScreen()),
  ),
  GoRoute(
    path: '/bills/:id',
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, BillDetailScreen(billId: state.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/bills/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, BillFormScreen(billId: state.pathParameters['id'])),
  ),
  GoRoute(
    path: '/bills/:id/pay',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      BillPayScreen(
        billId: state.pathParameters['id']!,
        occurrenceId: state.uri.queryParameters['occurrence'],
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.calendar,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CalendarScreen(initialMonth: state.uri.queryParameters['month']),
    ),
  ),
];
