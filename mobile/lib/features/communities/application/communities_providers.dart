import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';

/// A counter bumped after every community write (join, leave, post,
/// comment, settings, moderation); community lists and pages watch it and
/// read again from the server. Resets when the signed-in user changes.
final NotifierProvider<CommunityRevision, int> communityRevisionProvider =
    NotifierProvider<CommunityRevision, int>(CommunityRevision.new);

/// See [communityRevisionProvider].
class CommunityRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentUserIdProvider);
    return 0;
  }

  /// Marks community data as changed.
  void bump() => state++;
}

/// Communities matching a search ([q] empty = the directory).
final FutureProviderFamily<List<CommunityDto>, String>
discoverCommunitiesProvider = FutureProvider.autoDispose
    .family<List<CommunityDto>, String>((Ref ref, String q) {
      ref.watch(communityRevisionProvider);
      return ref
          .read(communitiesApiProvider)
          .list(q: q.trim().isEmpty ? null : q.trim());
    });

/// The communities the user belongs to (or asked to join).
final FutureProvider<List<CommunityDto>> myCommunitiesProvider =
    FutureProvider.autoDispose<List<CommunityDto>>((Ref ref) {
      ref.watch(communityRevisionProvider);
      return ref.read(communitiesApiProvider).list(mine: true);
    });

/// Community invitations addressed to the user.
final FutureProvider<List<CommunityInvitationDto>>
myCommunityInvitationsProvider =
    FutureProvider.autoDispose<List<CommunityInvitationDto>>((Ref ref) {
      ref.watch(communityRevisionProvider);
      return ref.read(communitiesApiProvider).myInvitations();
    });

/// One community by ID or URL name.
final FutureProviderFamily<CommunityDto, String> communityProvider =
    FutureProvider.autoDispose.family<CommunityDto, String>((
      Ref ref,
      String ref0,
    ) {
      ref.watch(communityRevisionProvider);
      return ref.read(communitiesApiProvider).get(ref0);
    });

/// What a feed shows: a community's posts in one order, optionally
/// searched.
typedef FeedQuery = ({String communityId, String sort, String q});

/// A community's feed, page by page (cursor; "Load more").
final AsyncNotifierProviderFamily<
  CommunityFeedController,
  PagedList<CommunityPostDto>,
  FeedQuery
>
communityFeedProvider = AsyncNotifierProvider.autoDispose
    .family<CommunityFeedController, PagedList<CommunityPostDto>, FeedQuery>(
      CommunityFeedController.new,
    );

/// See [communityFeedProvider].
class CommunityFeedController extends PagedListController<CommunityPostDto> {
  /// Creates the controller for [query].
  CommunityFeedController(this.query);

  /// The feed shown.
  final FeedQuery query;

  @override
  Future<PagedList<CommunityPostDto>> build() {
    ref.watch(communityRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<CommunityPostDto>> fetchPage(String? cursor) => ref
      .read(communitiesApiProvider)
      .posts(
        query.communityId,
        sort: query.sort,
        q: query.q.trim().isEmpty ? null : query.q.trim(),
        cursor: cursor,
      );

  @override
  String keyOf(CommunityPostDto item) => item.id;
}

/// One post with its comments.
final FutureProviderFamily<CommunityPostDetail, String> postDetailProvider =
    FutureProvider.autoDispose.family<CommunityPostDetail, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(communityRevisionProvider);
      return ref.read(communitiesApiProvider).post(id);
    });

/// Members of a community with one status (`''` = every member the caller
/// may see).
typedef MembersQuery = ({String communityId, String status});

/// See [MembersQuery].
final FutureProviderFamily<List<CommunityMemberDto>, MembersQuery>
communityMembersProvider = FutureProvider.autoDispose
    .family<List<CommunityMemberDto>, MembersQuery>((Ref ref, MembersQuery q) {
      ref.watch(communityRevisionProvider);
      return ref
          .read(communitiesApiProvider)
          .members(q.communityId, status: q.status.isEmpty ? null : q.status);
    });

/// A community's invitations (moderators).
typedef InvitationsQuery = ({String communityId, bool includeInactive});

/// See [InvitationsQuery].
final FutureProviderFamily<List<CommunityInvitationDto>, InvitationsQuery>
communityInvitationsProvider = FutureProvider.autoDispose
    .family<List<CommunityInvitationDto>, InvitationsQuery>((
      Ref ref,
      InvitationsQuery q,
    ) {
      ref.watch(communityRevisionProvider);
      return ref
          .read(communitiesApiProvider)
          .invitations(q.communityId, includeInactive: q.includeInactive);
    });

/// The moderators' report queue with one status (`''` = all).
typedef ReportsQuery = ({String communityId, String status});

/// See [ReportsQuery].
final FutureProviderFamily<List<ModerationReportDto>, ReportsQuery>
moderationReportsProvider = FutureProvider.autoDispose
    .family<List<ModerationReportDto>, ReportsQuery>((Ref ref, ReportsQuery q) {
      ref.watch(communityRevisionProvider);
      return ref
          .read(communitiesApiProvider)
          .moderationReports(
            q.communityId,
            status: q.status.isEmpty ? null : q.status,
          );
    });

/// Open appeals against a community's moderation.
final FutureProviderFamily<List<ModerationAppealDto>, String>
moderationAppealsProvider = FutureProvider.autoDispose
    .family<List<ModerationAppealDto>, String>((Ref ref, String id) {
      ref.watch(communityRevisionProvider);
      return ref.read(communitiesApiProvider).moderationAppeals(id);
    });

/// A community's moderation log.
final FutureProviderFamily<List<ModerationActionDto>, String>
moderationLogProvider = FutureProvider.autoDispose
    .family<List<ModerationActionDto>, String>((Ref ref, String id) {
      ref.watch(communityRevisionProvider);
      return ref.read(communitiesApiProvider).moderationLog(id);
    });
