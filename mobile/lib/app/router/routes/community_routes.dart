import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/router/route_page.dart';
import 'package:montra_mobile/features/challenges/presentation/challenge_detail_screen.dart';
import 'package:montra_mobile/features/challenges/presentation/challenge_form_screen.dart';
import 'package:montra_mobile/features/challenges/presentation/challenges_screen.dart';
import 'package:montra_mobile/features/communities/domain/invite_links.dart';
import 'package:montra_mobile/features/communities/presentation/communities_screen.dart';
import 'package:montra_mobile/features/communities/presentation/community_form_screen.dart';
import 'package:montra_mobile/features/communities/presentation/community_join_screen.dart';
import 'package:montra_mobile/features/communities/presentation/community_members_screen.dart';
import 'package:montra_mobile/features/communities/presentation/community_moderation_screen.dart';
import 'package:montra_mobile/features/communities/presentation/community_screen.dart';
import 'package:montra_mobile/features/communities/presentation/community_settings_screen.dart';
import 'package:montra_mobile/features/communities/presentation/post_composer_screen.dart';
import 'package:montra_mobile/features/communities/presentation/post_screen.dart';
import 'package:montra_mobile/features/moderation/presentation/my_moderation_screen.dart';

String? _nonEmpty(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();

/// Top-level routes for communities, posts, challenges and the user's own
/// moderation screen (round 5). Literal segments come before parameters.
List<RouteBase> communityRoutes() => <RouteBase>[
  GoRoute(
    path: AppRoutes.communities,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CommunitiesScreen(
        initialTab: _nonEmpty(state.uri.queryParameters['tab']),
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.newCommunity,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const CommunityFormScreen()),
  ),
  GoRoute(
    path: AppRoutes.joinCommunity,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CommunityJoinScreen(initialToken: inviteTokenOfUri(state.uri)),
    ),
  ),
  GoRoute(
    path: '/communities/:ref',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CommunityScreen(communityRef: state.pathParameters['ref']!),
    ),
  ),
  GoRoute(
    path: '/communities/:ref/settings',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CommunitySettingsScreen(communityRef: state.pathParameters['ref']!),
    ),
  ),
  GoRoute(
    path: '/communities/:ref/members',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CommunityMembersScreen(communityRef: state.pathParameters['ref']!),
    ),
  ),
  GoRoute(
    path: '/communities/:ref/moderation',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      CommunityModerationScreen(communityRef: state.pathParameters['ref']!),
    ),
  ),
  GoRoute(
    path: '/communities/:ref/posts/new',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      PostComposerScreen(communityRef: state.pathParameters['ref']),
    ),
  ),
  GoRoute(
    path: '/posts/:id',
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, PostScreen(postId: state.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/posts/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      PostComposerScreen(postId: state.pathParameters['id']),
    ),
  ),
  GoRoute(
    path: AppRoutes.challenges,
    pageBuilder: (BuildContext context, GoRouterState state) =>
        routePage(state, const ChallengesScreen()),
  ),
  GoRoute(
    path: AppRoutes.newChallenge,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ChallengeFormScreen(
        communityId: _nonEmpty(state.uri.queryParameters['community_id']),
        groupId: _nonEmpty(state.uri.queryParameters['group_id']),
      ),
    ),
  ),
  GoRoute(
    path: '/challenges/:id',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ChallengeDetailScreen(challengeId: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/challenges/:id/edit',
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      ChallengeFormScreen(challengeId: state.pathParameters['id']),
    ),
  ),
  GoRoute(
    path: AppRoutes.myModeration,
    pageBuilder: (BuildContext context, GoRouterState state) => routePage(
      state,
      MyModerationScreen(
        initialTab: _nonEmpty(state.uri.queryParameters['tab']),
      ),
    ),
  ),
];
