import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_alerts_screen.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_detail_screen.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_form_screen.dart';
import 'package:montra_mobile/features/budgets/presentation/budgets_screen.dart';

/// Top-level routes (pushed over the tabs) for: Budgets and budget alerts.
List<RouteBase> budgetRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.budgets,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const BudgetsScreen()),
  ),
  // Literal paths before `/budgets/:id`.
  GoRoute(
    path: AppRoutes.newBudget,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const BudgetFormScreen()),
  ),
  GoRoute(
    path: AppRoutes.budgetAlerts,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const BudgetAlertsScreen()),
  ),
  GoRoute(
    path: '/budgets/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      BudgetDetailScreen(budgetId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/budgets/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      BudgetFormScreen(budgetId: state.pathParameters['id']),
    ),
  ),
];
