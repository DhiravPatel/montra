import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/challenges/data/challenges_api.dart';

class MockChallengesApi extends Mock implements ChallengesApi {}

/// Registers fallback values for the challenge screens' `any()` matchers.
void registerChallengeFallbacks() {
  registerFallbackValue(
    const ChallengeInput(
      challengeType: ChallengeInputChallengeType.noSpend,
      endsOn: '2026-12-01',
      metric: ChallengeInputMetric.days,
      startsOn: '2026-11-01',
      targetValue: 5,
      title: 'x',
    ),
  );
  registerFallbackValue(const ChallengeJoinInput());
  registerFallbackValue(const ChallengeProgressInput());
  registerFallbackValue(<String, Object?>{});
}

/// A `ChallengeParticipationDTO` as JSON.
Map<String, Object?> participationJson({
  bool share = false,
  bool show = false,
  int percent = 40,
  String status = 'active',
}) => <String, Object?>{
  'status': status,
  'share_progress': share,
  'show_on_leaderboard': show,
  'progress_value': 2,
  'percent_complete': percent,
  'current_streak': 2,
  'best_streak': 3,
  'joined_at': '2026-11-02T08:00:00Z',
};

/// A `ChallengeDTO` like the live server's.
ChallengeDto challenge({
  String id = 'ch-1',
  String title = 'No-spend week',
  String visibility = 'community',
  String status = 'active',
  bool leaderboard = true,
  bool mine = false,
  bool ended = false,
  Map<String, Object?>? me,
  int version = 2,
  String startsOn = '2026-11-01',
  String endsOn = '2027-01-31',
}) => ChallengeDto.fromJson(<String, Object?>{
  'id': id,
  'title': title,
  'challenge_type': 'no_spend',
  'description': 'Skip extras for a week.',
  'rules': 'Check in daily.',
  'metric': 'days',
  'target_value': 5,
  'starts_on': startsOn,
  'ends_on': endsOn,
  'visibility': visibility,
  if (visibility == 'community') 'community_id': 'com-1',
  if (visibility == 'community')
    'community': <String, Object?>{'id': 'com-1', 'name': 'Savers Circle'},
  'leaderboard_enabled': leaderboard,
  'status': status,
  'ended': ended,
  'participant_count': 3,
  'mine': mine,
  'me': ?me,
  'version': version,
  'created_at': '2026-11-01T08:00:00Z',
});

/// One page of challenges.
CursorPage<ChallengeDto> challengesPage(
  List<ChallengeDto> items, {
  String? next,
}) => CursorPage<ChallengeDto>(items, next);

/// A leaderboard entry.
ChallengeLeaderboardEntry leaderEntry({
  int rank = 1,
  String name = 'Ravi Kumar',
  bool me = false,
}) => ChallengeLeaderboardEntry.fromJson(<String, Object?>{
  'rank': rank,
  'display_name': name,
  'percent_complete': 80,
  'current_streak': 4,
  'completed': false,
  'is_me': me,
});
