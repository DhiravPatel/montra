import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';
import 'package:montra_mobile/features/goals/domain/goal_export.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';

/// Bumped after every goal write so lists, details, contributions and
/// forecasts are read again. Starts over for each signed-in user.
final NotifierProvider<GoalsRevision, int> goalsRevisionProvider =
    NotifierProvider<GoalsRevision, int>(GoalsRevision.new);

/// See [goalsRevisionProvider].
class GoalsRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(currentUserIdProvider);
    return 0;
  }

  /// Marks goal data as stale.
  void bump() => state++;
}

void _watchGoalData(Ref ref) {
  // Finance writes matter too: a linked transaction verifies a
  // contribution.
  ref
    ..watch(financeRevisionProvider)
    ..watch(goalsRevisionProvider);
}

/// Goals for a status filter (see `goalStatusFilters`): null lists every
/// goal except archived ones.
final FutureProviderFamily<List<GoalDto>, String?> goalsProvider =
    FutureProvider.autoDispose.family<List<GoalDto>, String?>((
      Ref ref,
      String? status,
    ) {
      _watchGoalData(ref);
      return ref.read(goalsApiProvider).list(status: status);
    });

/// One goal, with its lifecycle and sharing actions.
final AsyncNotifierProviderFamily<GoalDetailController, GoalDto, String>
goalDetailProvider = AsyncNotifierProvider.autoDispose
    .family<GoalDetailController, GoalDto, String>(GoalDetailController.new);

/// Loads a goal and pauses, resumes, achieves, ends or archives it, and
/// manages its members and the user's own contributions. Lifecycle and
/// member changes send the displayed `version`, so a change made
/// elsewhere answers `VERSION_CONFLICT` instead of being overwritten.
class GoalDetailController extends AsyncNotifier<GoalDto> {
  /// Creates the controller for [goalId].
  GoalDetailController(this.goalId);

  /// The goal.
  final String goalId;

  GoalsApi get _api => ref.read(goalsApiProvider);

  int? get _version => state.value?.version;

  @override
  Future<GoalDto> build() {
    _watchGoalData(ref);
    return _api.get(goalId);
  }

  /// Pauses an active goal.
  Future<void> pause() => _apply(() => _api.pause(goalId, version: _version));

  /// Resumes a paused (or archived) goal.
  Future<void> resume() => _apply(() => _api.resume(goalId, version: _version));

  /// Marks the goal as achieved.
  Future<void> achieve() =>
      _apply(() => _api.achieve(goalId, version: _version));

  /// Ends the goal without reaching it (history is kept).
  Future<void> cancel() => _apply(() => _api.cancel(goalId, version: _version));

  /// Archives the goal (history is kept).
  Future<void> archive() =>
      _apply(() => _api.archive(goalId, version: _version));

  /// Shares the goal with [userId].
  Future<void> addMember(String userId, GoalMemberInputRole role) => _apply(
    () => _api.addMember(
      goalId,
      GoalMemberInput(userId: userId, role: role),
      version: _version,
    ),
  );

  /// Changes a member's role (owner) or the user's own contribution
  /// visibility (the owner's too).
  Future<void> updateMember(String userId, GoalMemberUpdate update) => _apply(
    () => _api.updateMember(goalId, userId, update, version: _version),
  );

  /// Removes a member; the goal is then read again.
  Future<void> removeMember(String userId) => _apply(() async {
    await _api.removeMember(goalId, userId, version: _version);
    return _api.get(goalId);
  });

  /// Leaves a shared goal. The goal can't be read afterwards, so the state
  /// is left as it was; the caller closes the screen.
  Future<void> leave(String userId) async {
    final GoalsRevision revision = ref.read(goalsRevisionProvider.notifier);
    await _api.removeMember(goalId, userId, version: _version);
    revision.bump();
  }

  /// Voids one of the user's own contributions.
  Future<void> voidContribution(String contributionId) =>
      _apply(() => _api.voidContribution(goalId, contributionId));

  Future<void> _apply(Future<GoalDto> Function() request) async {
    final GoalsRevision revision = ref.read(goalsRevisionProvider.notifier);
    final GoalDto updated = await request();
    if (ref.mounted) {
      state = AsyncData<GoalDto>(updated);
    }
    revision.bump();
  }
}

/// A goal's contribution history, newest first as the server sends it,
/// page by page ("Load more").
final AsyncNotifierProviderFamily<
  GoalContributionsController,
  PagedList<GoalContributionDto>,
  String
>
goalContributionsProvider = AsyncNotifierProvider.autoDispose
    .family<
      GoalContributionsController,
      PagedList<GoalContributionDto>,
      String
    >(GoalContributionsController.new);

/// See [goalContributionsProvider].
class GoalContributionsController
    extends PagedListController<GoalContributionDto> {
  /// Creates the controller for [goalId].
  GoalContributionsController(this.goalId);

  /// The goal.
  final String goalId;

  @override
  Future<PagedList<GoalContributionDto>> build() {
    _watchGoalData(ref);
    return firstPage();
  }

  @override
  Future<CursorPage<GoalContributionDto>> fetchPage(String? cursor) =>
      ref.read(goalsApiProvider).contributions(goalId, cursor: cursor);

  @override
  String keyOf(GoalContributionDto item) => item.id;
}

/// The server's forecast for a goal.
final FutureProviderFamily<GoalForecast, String> goalForecastProvider =
    FutureProvider.autoDispose.family<GoalForecast, String>((
      Ref ref,
      String goalId,
    ) {
      _watchGoalData(ref);
      return ref.read(goalsApiProvider).forecast(goalId);
    });

/// A goal's contribution history as CSV.
final FutureProviderFamily<GoalExport, String> goalExportProvider =
    FutureProvider.autoDispose.family<GoalExport, String>((
      Ref ref,
      String goalId,
    ) {
      _watchGoalData(ref);
      return ref.read(goalsApiProvider).export(goalId);
    });
