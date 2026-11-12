import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/goals/presentation/contribution_form_screen.dart';
import 'package:montra_mobile/features/goals/presentation/goal_detail_screen.dart';
import 'package:montra_mobile/features/goals/presentation/goal_export_screen.dart';
import 'package:montra_mobile/features/goals/presentation/goal_form_screen.dart';
import 'package:montra_mobile/features/goals/presentation/goals_screen.dart';

/// Top-level routes (pushed over the tabs) for: Goals.
///
/// `/goals/new` is declared before `/goals/:id` so it is never read as an
/// ID. Extra paths are built with `GoalPaths`.
List<RouteBase> goalRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.goals,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const GoalsScreen()),
  ),
  GoRoute(
    path: AppRoutes.newGoal,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const GoalFormScreen()),
  ),
  GoRoute(
    path: '/goals/:id',
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, GoalDetailScreen(goalId: state.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/goals/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, GoalFormScreen(goalId: state.pathParameters['id'])),
  ),
  GoRoute(
    path: '/goals/:id/contribute',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ContributionFormScreen(goalId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/goals/:id/export',
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, GoalExportScreen(goalId: state.pathParameters['id']!)),
  ),
];
