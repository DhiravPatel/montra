import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/groups/presentation/group_activity_screen.dart';
import 'package:montra_mobile/features/groups/presentation/group_detail_screen.dart';
import 'package:montra_mobile/features/groups/presentation/group_form_screen.dart';
import 'package:montra_mobile/features/groups/presentation/group_join_screen.dart';
import 'package:montra_mobile/features/groups/presentation/group_settings_screen.dart';
import 'package:montra_mobile/features/groups/presentation/groups_screen.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';
import 'package:montra_mobile/features/social/presentation/blocked_muted_screen.dart';
import 'package:montra_mobile/features/social/presentation/friends_screen.dart';
import 'package:montra_mobile/features/social/presentation/social_settings_screen.dart';

/// Top-level routes for friends and groups (round 4; owned by the social
/// feature). Literal segments come before parameters, so `/groups/new`
/// and `/groups/join` are never read as group IDs. Group money screens
/// (`/groups/:id/expenses`, …) are in `group_money_routes.dart`.
List<RouteBase> socialRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.friends,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      FriendsScreen(
        initialTab: FriendsTab.parse(state.uri.queryParameters['tab']),
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.blockedAndMuted,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const BlockedMutedScreen()),
  ),
  GoRoute(
    path: AppRoutes.socialSettings,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const SocialSettingsScreen()),
  ),
  GoRoute(
    path: AppRoutes.groups,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const GroupsScreen()),
  ),
  GoRoute(
    path: AppRoutes.newGroup,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const GroupFormScreen()),
  ),
  GoRoute(
    path: AppRoutes.joinGroup,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupJoinScreen(initialToken: InviteLinks.tokenFromUri(state.uri)),
    ),
  ),
  GoRoute(
    path: '/groups/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupDetailScreen(groupId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/groups/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, GroupFormScreen(groupId: state.pathParameters['id'])),
  ),
  GoRoute(
    path: '/groups/:id/settings',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupSettingsScreen(groupId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/groups/:id/activity',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      GroupActivityScreen(groupId: state.pathParameters['id']!),
    ),
  ),
];
