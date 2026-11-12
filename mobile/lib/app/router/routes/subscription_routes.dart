import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscription_detail_screen.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscription_detections_screen.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscription_form_screen.dart';
import 'package:montra_mobile/features/subscriptions/presentation/subscriptions_screen.dart';

/// Top-level routes (pushed over the tabs) for: Subscriptions and
/// subscription detections. Fixed paths come before `/subscriptions/:id`.
List<RouteBase> subscriptionRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.subscriptions,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const SubscriptionsScreen()),
  ),
  GoRoute(
    path: AppRoutes.newSubscription,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const SubscriptionFormScreen()),
  ),
  GoRoute(
    path: AppRoutes.subscriptionDetections,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const SubscriptionDetectionsScreen()),
  ),
  GoRoute(
    path: '/subscriptions/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      SubscriptionDetailScreen(subscriptionId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/subscriptions/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      SubscriptionFormScreen(subscriptionId: state.pathParameters['id']),
    ),
  ),
];
