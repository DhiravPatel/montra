import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';

int _byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// The user's friends (connections whose state is `friend`), by name.
final FutureProvider<List<PublicProfile>> connectionsProvider =
    FutureProvider.autoDispose<List<PublicProfile>>((Ref ref) async {
      ref.watch(currentUserIdProvider);
      final List<PublicProfile> all = await ref
          .read(socialApiProvider)
          .connections();
      return <PublicProfile>[
        for (final PublicProfile p in all)
          if (p.connection == PublicProfileConnection.friend) p,
      ]..sort(
        (PublicProfile a, PublicProfile b) =>
            _byName(a.displayName, b.displayName),
      );
    });

/// Friend requests involving the user, newest first.
final FutureProvider<List<FriendRequestDto>> friendRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequestDto>>((Ref ref) async {
      ref.watch(currentUserIdProvider);
      final List<FriendRequestDto> all = await ref
          .read(socialApiProvider)
          .friendRequests();
      return all.toList()..sort(
        (FriendRequestDto a, FriendRequestDto b) =>
            b.createdAt.compareTo(a.createdAt),
      );
    });

/// Incoming requests still waiting for the user's answer.
List<FriendRequestDto> incomingRequests(
  List<FriendRequestDto> all,
  String? me,
) => <FriendRequestDto>[
  for (final FriendRequestDto r in all)
    if (r.status == FriendRequestDtoStatus.pending && r.to.userId == me) r,
];

/// Requests the user sent that are still waiting.
List<FriendRequestDto> outgoingRequests(
  List<FriendRequestDto> all,
  String? me,
) => <FriendRequestDto>[
  for (final FriendRequestDto r in all)
    if (r.status == FriendRequestDtoStatus.pending && r.from.userId == me) r,
];

/// The user's account, profile and preferences (`GET /me`).
final FutureProvider<MeDto> myProfileProvider =
    FutureProvider.autoDispose<MeDto>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(socialApiProvider).me();
    });

/// People the user blocked, newest first, page by page.
final AsyncNotifierProvider<BlocksController, PagedList<BlockDto>>
blocksProvider =
    AsyncNotifierProvider.autoDispose<BlocksController, PagedList<BlockDto>>(
      BlocksController.new,
    );

/// See [blocksProvider].
class BlocksController extends PagedListController<BlockDto> {
  @override
  Future<PagedList<BlockDto>> build() {
    ref.watch(currentUserIdProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<BlockDto>> fetchPage(String? cursor) =>
      ref.read(socialApiProvider).blocks(cursor: cursor);

  @override
  String keyOf(BlockDto item) => item.userId;
}

/// People the user muted, newest first, page by page.
final AsyncNotifierProvider<MutesController, PagedList<MuteDto>> mutesProvider =
    AsyncNotifierProvider.autoDispose<MutesController, PagedList<MuteDto>>(
      MutesController.new,
    );

/// See [mutesProvider].
class MutesController extends PagedListController<MuteDto> {
  @override
  Future<PagedList<MuteDto>> build() {
    ref.watch(currentUserIdProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<MuteDto>> fetchPage(String? cursor) =>
      ref.read(socialApiProvider).mutes(cursor: cursor);

  @override
  String keyOf(MuteDto item) => item.userId;
}

/// Re-reads everything that shows people after a social write (a request
/// answered, a friend removed, a block or mute changed), including the
/// pickers used when sharing budgets and goals.
void refreshSocial(WidgetRef ref) {
  ref
    ..invalidate(connectionsProvider)
    ..invalidate(friendRequestsProvider)
    ..invalidate(friendsProvider)
    ..invalidate(blocksProvider)
    ..invalidate(mutesProvider);
}
