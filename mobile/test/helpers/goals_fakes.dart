import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';

import 'finance_fakes.dart';

class MockGoalsApi extends Mock implements GoalsApi {}

/// The signed-in user in widget tests (see `userJson`).
const String goalsTestUserId = '7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11';

/// Registers fallback values for goal `any()` matchers.
void registerGoalFallbacks() {
  registerFallbackValue(
    const GoalInput(
      name: 'x',
      goalType: GoalInputGoalType.custom,
      targetAmount: '1',
    ),
  );
  registerFallbackValue(const GoalPatch());
  registerFallbackValue(const GoalContributionInput(amount: '1'));
  registerFallbackValue(const GoalContributionRecordInput());
  registerFallbackValue(const GoalMemberInput(userId: 'x'));
  registerFallbackValue(const GoalMemberUpdate());
}

/// A `GoalMember` as JSON.
Map<String, Object?> goalMemberJson({
  required String id,
  required String name,
  String role = 'contributor',
  String visibility = 'amounts',
}) => <String, Object?>{
  'user_id': id,
  'display_name': name,
  'role': role,
  'contribution_visibility': visibility,
  'joined_at': '2026-10-01T08:00:00Z',
};

/// A `GoalMilestone` as JSON.
Map<String, Object?> milestoneJson(int percent, {String? label, String? at}) =>
    <String, Object?>{'percent': percent, 'label': ?label, 'reached_at': ?at};

/// A `GoalDTO` (amounts are server values; tests never derive them).
GoalDto goal({
  String id = 'goal-1',
  String name = 'Emergency fund',
  String type = 'emergency_fund',
  String status = 'active',
  String access = 'owner',
  String saved = '25000.00',
  String target = '100000.00',
  String remaining = '75000.00',
  int percentBp = 2500,
  String verified = '0.00',
  String planned = '0.00',
  String starting = '5000.00',
  int contributionCount = 2,
  String? targetDate = '2027-06-30',
  String schedule = 'monthly',
  String? plannedContribution = '8000.00',
  int priority = 2,
  List<Map<String, Object?>> members = const <Map<String, Object?>>[],
  List<Map<String, Object?>>? milestones,
  int version = 1,
  String? ownerId,
  String? ownerName = 'Asha Rao',
  String visibility = 'private',
  String? groupId,
  String? linkedAccountId,
  String? description,
  String? notes,
  String? achievedAt,
  bool reminders = false,
  String currency = 'INR',
}) {
  final String owner =
      ownerId ?? (access == 'owner' ? goalsTestUserId : 'u-asha');
  return GoalDto.fromJson(<String, Object?>{
    'id': id,
    'name': name,
    'owner_user_id': owner,
    'owner': <String, Object?>{'user_id': owner, 'display_name': ?ownerName},
    'goal_type': type,
    'target': moneyJson(target, currency: currency),
    'starting': moneyJson(starting, currency: currency),
    'start_date': '2026-10-01',
    'target_date': ?targetDate,
    'priority': priority,
    'contribution_schedule': schedule,
    if (plannedContribution != null)
      'planned_contribution': moneyJson(
        plannedContribution,
        currency: currency,
      ),
    'visibility': visibility,
    'reminders_enabled': reminders,
    'status': status,
    'access': access,
    'achieved_at': ?achievedAt,
    'group_id': ?groupId,
    'linked_account_id': ?linkedAccountId,
    'description': ?description,
    'notes': ?notes,
    'progress': <String, Object?>{
      'saved': moneyJson(saved, currency: currency),
      'remaining': moneyJson(remaining, currency: currency),
      'percent_bp': percentBp,
      'verified': moneyJson(verified, currency: currency),
      'planned': moneyJson(planned, currency: currency),
      'contribution_count': contributionCount,
    },
    'milestones':
        milestones ??
        <Map<String, Object?>>[
          milestoneJson(25, at: '2026-11-02T10:00:00Z'),
          milestoneJson(50, label: 'Halfway'),
        ],
    // The server lists the owner first (role owner), then the members.
    'members': <Map<String, Object?>>[
      if (!members.any((Map<String, Object?> m) => m['role'] == 'owner'))
        goalMemberJson(id: owner, name: ownerName ?? 'Owner', role: 'owner'),
      ...members,
    ],
    'version': version,
    'created_at': '2026-10-01T08:00:00Z',
  });
}

/// A `GoalContributionDTO`.
GoalContributionDto contribution({
  String id = 'gc-1',
  String? amount = '2500.00',
  String kind = 'contribution',
  String status = 'recorded',
  bool mine = true,
  bool voided = false,
  String? note,
  String? transactionId,
  String date = '2026-11-05',
  String name = 'Asha',
  String userId = goalsTestUserId,
  int? percentBp,
}) => GoalContributionDto.fromJson(<String, Object?>{
  'id': id,
  if (amount != null) 'amount': moneyJson(amount),
  'percent_bp': ?percentBp,
  'kind': kind,
  'status': status,
  'mine': mine,
  'voided': voided,
  'note': ?note,
  'transaction_id': ?transactionId,
  'contributed_on': date,
  'display_name': name,
  'user_id': userId,
  'created_at': '2026-11-05T08:00:00Z',
});

/// A `GoalForecast`.
GoalForecast forecast({
  bool achieved = false,
  bool? onTrack = false,
  String? projected = '2028-03-05',
  String? plannedCompletion = '2027-11-05',
  String? targetDate = '2027-06-30',
  int? daysLeft = 237,
  String? perMonth = '9375.00',
  String? perWeek = '2165.00',
  String pace = '2500.00',
  List<String> assumptions = const <String>[
    'Amounts are exact in INR; no interest, returns or inflation are assumed.',
  ],
  List<String> assumptionCodes = const <String>['exact_amounts_no_growth'],
}) => GoalForecast.fromJson(<String, Object?>{
  'achieved': achieved,
  'on_track': ?onTrack,
  'projected_completion': ?projected,
  'planned_completion': ?plannedCompletion,
  'target_date': ?targetDate,
  'days_left': ?daysLeft,
  if (perMonth != null) 'required_per_month': moneyJson(perMonth),
  if (perWeek != null) 'required_per_week': moneyJson(perWeek),
  'recent_monthly_pace': moneyJson(pace),
  'remaining': moneyJson('75000.00'),
  'saved': moneyJson('25000.00'),
  'target': moneyJson('100000.00'),
  'assumptions': assumptions,
  'assumption_codes': assumptionCodes,
  'assumption_params': <String, String>{
    'currency': 'INR',
    'window_days': '90',
    'months': '3',
  },
});

/// One page of contributions (more after it when [next] is set).
CursorPage<GoalContributionDto> contributionsPage(
  List<GoalContributionDto> items, {
  String? next,
}) => CursorPage<GoalContributionDto>(items, next);

/// Stubs a goal's detail, contributions and forecast.
void stubGoal(
  MockGoalsApi api, {
  GoalDto? detail,
  List<GoalContributionDto>? contributions,
  GoalForecast? outlook,
}) {
  final GoalDto g = detail ?? goal();
  when(() => api.get(g.id)).thenAnswer((_) async => g);
  when(() => api.contributions(g.id, cursor: any(named: 'cursor'))).thenAnswer(
    (_) async => contributionsPage(
      contributions ?? <GoalContributionDto>[contribution()],
    ),
  );
  when(() => api.forecast(g.id)).thenAnswer((_) async => outlook ?? forecast());
}
