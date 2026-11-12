import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/challenges/data/challenges_api.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';

/// A counter bumped after every challenge write; lists and pages watch it.
final NotifierProvider<ChallengeRevision, int> challengeRevisionProvider =
    NotifierProvider<ChallengeRevision, int>(ChallengeRevision.new);

/// See [challengeRevisionProvider].
class ChallengeRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentUserIdProvider);
    return 0;
  }

  /// Marks challenge data as changed.
  void bump() => state++;
}

/// Challenges in one list (`mine` or `discover`), page by page.
final AsyncNotifierProviderFamily<
  ChallengesListController,
  PagedList<ChallengeDto>,
  String
>
challengesProvider = AsyncNotifierProvider.autoDispose
    .family<ChallengesListController, PagedList<ChallengeDto>, String>(
      ChallengesListController.new,
    );

/// See [challengesProvider].
class ChallengesListController extends PagedListController<ChallengeDto> {
  /// Creates the controller for the [scope] list.
  ChallengesListController(this.scope);

  /// `mine` or `discover`.
  final String scope;

  @override
  Future<PagedList<ChallengeDto>> build() {
    ref.watch(challengeRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<ChallengeDto>> fetchPage(String? cursor) =>
      ref.read(challengesApiProvider).list(scope: scope, cursor: cursor);

  @override
  String keyOf(ChallengeDto item) => item.id;
}

/// One challenge with the user's participation.
final FutureProviderFamily<ChallengeDto, String> challengeProvider =
    FutureProvider.autoDispose.family<ChallengeDto, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(challengeRevisionProvider);
      return ref.read(challengesApiProvider).get(id);
    });

/// A challenge's leaderboard (only read once the user appears on it).
final FutureProviderFamily<List<ChallengeLeaderboardEntry>, String>
challengeLeaderboardProvider = FutureProvider.autoDispose
    .family<List<ChallengeLeaderboardEntry>, String>((Ref ref, String id) {
      ref.watch(challengeRevisionProvider);
      return ref.read(challengesApiProvider).leaderboard(id);
    });
