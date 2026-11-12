import 'package:montra_mobile/app/router/app_routes.dart';

/// Community locations beyond those in [AppRoutes] (owned by the
/// communities feature).
abstract final class CommunityPaths {
  /// Write a post in community [ref].
  static String newPost(String ref) =>
      '${AppRoutes.communityPage(ref)}/posts/new';

  /// Edit post [postId].
  static String editPost(String postId) =>
      '${AppRoutes.postDetail(postId)}/edit';

  /// The communities screen opened on [tab] (`discover`, `yours`,
  /// `invitations`).
  static String communitiesTab(String tab) => Uri(
    path: AppRoutes.communities,
    queryParameters: <String, String>{'tab': tab},
  ).toString();

  /// A new challenge for community [communityId].
  static String newChallengeFor(String communityId) => Uri(
    path: AppRoutes.newChallenge,
    queryParameters: <String, String>{'community_id': communityId},
  ).toString();
}
