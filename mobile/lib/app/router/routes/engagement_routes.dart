import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/insights/presentation/insight_detail_screen.dart';
import 'package:montra_mobile/features/insights/presentation/insight_mutes_screen.dart';
import 'package:montra_mobile/features/integrations/presentation/connection_screen.dart';
import 'package:montra_mobile/features/integrations/presentation/integrations_screen.dart';
import 'package:montra_mobile/features/notifications/presentation/notification_settings_screen.dart';
import 'package:montra_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:montra_mobile/features/search/presentation/search_screen.dart';

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Top-level routes for notifications, search, insight details and
/// integrations (round 5). Literal segments come before parameters. The
/// Insights list itself is a tab of the app shell (`/insights`).
List<RouteBase> engagementRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.notifications,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const NotificationsScreen()),
  ),
  GoRoute(
    path: AppRoutes.notificationSettings,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const NotificationSettingsScreen()),
  ),
  GoRoute(
    path: AppRoutes.search,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const SearchScreen()),
  ),
  GoRoute(
    path: AppRoutes.insightMutes,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const InsightMutesScreen()),
  ),
  GoRoute(
    path: '/insights/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      InsightDetailScreen(insightId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: AppRoutes.integrations,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      IntegrationsScreen(
        accountId: _nonEmpty(state.uri.queryParameters['account_id']),
      ),
    ),
  ),
  GoRoute(
    path: '/integrations/connections/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ConnectionScreen(connectionId: state.pathParameters['id']!),
    ),
  ),
];
