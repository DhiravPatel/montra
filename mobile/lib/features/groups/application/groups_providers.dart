import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';

int _byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// Every group the user belongs to, active ones first and then by name
/// (archived groups included; screens filter them).
final FutureProvider<List<GroupDto>> allGroupsProvider =
    FutureProvider.autoDispose<List<GroupDto>>((Ref ref) async {
      ref.watch(currentUserIdProvider);
      ref.watch(financeRevisionProvider);
      final List<GroupDto> all = await ref
          .read(groupsApiProvider)
          .list(includeArchived: true);
      return all.toList()..sort((GroupDto a, GroupDto b) {
        final bool aActive = a.status == GroupDtoStatus.active;
        final bool bActive = b.status == GroupDtoStatus.active;
        if (aActive != bActive) {
          return aActive ? -1 : 1;
        }
        return _byName(a.name, b.name);
      });
    });

/// Username invitations addressed to the user that are still open,
/// newest first.
final FutureProvider<List<GroupInvitationDto>> myGroupInvitationsProvider =
    FutureProvider.autoDispose<List<GroupInvitationDto>>((Ref ref) async {
      ref.watch(currentUserIdProvider);
      final List<GroupInvitationDto> all = await ref
          .read(groupsApiProvider)
          .myInvitations();
      return <GroupInvitationDto>[
        for (final GroupInvitationDto i in all)
          if (i.status == GroupInvitationDtoStatus.active) i,
      ]..sort(
        (GroupInvitationDto a, GroupInvitationDto b) =>
            b.createdAt.compareTo(a.createdAt),
      );
    });

/// A group's balances (`GET /groups/{id}/balances`).
final FutureProviderFamily<GroupBalancesDto, String> groupBalancesProvider =
    FutureProvider.autoDispose.family<GroupBalancesDto, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(currentUserIdProvider);
      ref.watch(financeRevisionProvider);
      return ref.read(groupsApiProvider).balances(id);
    });

/// A group's invitations, every status (active ones first, then newest).
final FutureProviderFamily<List<GroupInvitationDto>, String>
groupInvitationsProvider = FutureProvider.autoDispose
    .family<List<GroupInvitationDto>, String>((Ref ref, String id) async {
      ref.watch(currentUserIdProvider);
      final List<GroupInvitationDto> all = await ref
          .read(groupsApiProvider)
          .invitations(id, includeInactive: true);
      return all.toList()..sort((GroupInvitationDto a, GroupInvitationDto b) {
        final bool aActive = a.status == GroupInvitationDtoStatus.active;
        final bool bActive = b.status == GroupInvitationDtoStatus.active;
        if (aActive != bActive) {
          return aActive ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    });

/// A group's join requests (admins), pending ones first.
final FutureProviderFamily<List<GroupJoinRequestDto>, String>
groupJoinRequestsProvider = FutureProvider.autoDispose
    .family<List<GroupJoinRequestDto>, String>((Ref ref, String id) async {
      ref.watch(currentUserIdProvider);
      final List<GroupJoinRequestDto> all = await ref
          .read(groupsApiProvider)
          .joinRequests(id);
      return all.toList()..sort((GroupJoinRequestDto a, GroupJoinRequestDto b) {
        final bool aPending = a.status == GroupJoinRequestDtoStatus.pending;
        final bool bPending = b.status == GroupJoinRequestDtoStatus.pending;
        if (aPending != bPending) {
          return aPending ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    });

/// The pages of a group's activity loaded so far (`before` paging).
@immutable
class ActivityFeed {
  /// Creates the feed.
  const ActivityFeed({
    required this.events,
    this.nextBefore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Events loaded so far, newest first.
  final List<GroupActivityDto> events;

  /// `before` for the next page; null after the last one.
  final int? nextBefore;

  /// Whether the next page is being fetched.
  final bool loadingMore;

  /// Why the last "load more" failed (the loaded events stay visible).
  final Object? loadMoreError;

  /// Whether more pages exist.
  bool get hasMore => nextBefore != null;

  /// A copy with other paging fields.
  ActivityFeed copyWith({bool loadingMore = false, Object? loadMoreError}) =>
      ActivityFeed(
        events: events,
        nextBefore: nextBefore,
        loadingMore: loadingMore,
        loadMoreError: loadMoreError,
      );
}

/// A group's activity feed, page by page.
final AsyncNotifierProviderFamily<GroupActivityController, ActivityFeed, String>
groupActivityProvider = AsyncNotifierProvider.autoDispose
    .family<GroupActivityController, ActivityFeed, String>(
      GroupActivityController.new,
    );

/// See [groupActivityProvider].
class GroupActivityController extends AsyncNotifier<ActivityFeed> {
  /// Creates the controller for group [groupId].
  GroupActivityController(this.groupId);

  /// The group.
  final String groupId;

  @override
  Future<ActivityFeed> build() async {
    ref.watch(currentUserIdProvider);
    final GroupActivityPage page = await ref
        .read(groupsApiProvider)
        .activity(groupId);
    return ActivityFeed(events: page.events, nextBefore: page.nextBefore);
  }

  /// Loads the next page, if any. Failures keep the loaded events.
  Future<void> loadMore() async {
    final ActivityFeed? current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        state.isLoading) {
      return;
    }
    state = AsyncData<ActivityFeed>(current.copyWith(loadingMore: true));
    try {
      final GroupActivityPage page = await ref
          .read(groupsApiProvider)
          .activity(groupId, before: current.nextBefore);
      if (!ref.mounted) {
        return;
      }
      final Set<int> seen = <int>{
        for (final GroupActivityDto e in current.events) e.id,
      };
      state = AsyncData<ActivityFeed>(
        ActivityFeed(
          events: <GroupActivityDto>[
            ...current.events,
            for (final GroupActivityDto e in page.events)
              if (!seen.contains(e.id)) e,
          ],
          nextBefore: page.nextBefore,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<ActivityFeed>(current.copyWith(loadMoreError: error));
    }
  }
}

/// Re-reads everything about group [id] (and the group lists, including
/// the pickers used when sharing budgets and goals) after a write.
void refreshGroup(WidgetRef ref, String id) {
  ref
    ..invalidate(groupDetailProvider(id))
    ..invalidate(groupInvitationsProvider(id))
    ..invalidate(groupJoinRequestsProvider(id))
    ..invalidate(groupActivityProvider(id))
    ..invalidate(groupBalancesProvider(id));
  refreshGroupLists(ref);
}

/// Re-reads the group lists after a group was created, joined, archived,
/// restored, left or deleted.
void refreshGroupLists(WidgetRef ref) {
  ref
    ..invalidate(allGroupsProvider)
    ..invalidate(groupsProvider)
    ..invalidate(myGroupInvitationsProvider);
}
