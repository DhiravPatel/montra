import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Challenge types offered when creating one, in order.
const List<ChallengeInputChallengeType> challengeTypes =
    <ChallengeInputChallengeType>[
      ChallengeInputChallengeType.noSpend,
      ChallengeInputChallengeType.savingsStreak,
      ChallengeInputChallengeType.groceryBudget,
      ChallengeInputChallengeType.mealPlanning,
      ChallengeInputChallengeType.travelSavings,
      ChallengeInputChallengeType.custom,
    ];

/// Name of a challenge type (wire value; `ChallengeDTO.challenge_type` is a
/// plain string).
String challengeTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'no_spend' => l10n.challengeTypeNoSpend,
  'savings_streak' => l10n.challengeTypeSavingsStreak,
  'grocery_budget' => l10n.challengeTypeGroceryBudget,
  'meal_planning' => l10n.challengeTypeMealPlanning,
  'travel_savings' => l10n.challengeTypeTravelSavings,
  _ => l10n.challengeTypeCustom,
};

/// Measures offered, in order.
const List<ChallengeInputMetric> challengeMetrics = <ChallengeInputMetric>[
  ChallengeInputMetric.days,
  ChallengeInputMetric.streak,
  ChallengeInputMetric.milestones,
  ChallengeInputMetric.percent,
];

/// Name of a measure (wire value).
String challengeMetricLabel(AppLocalizations l10n, String metric) =>
    switch (metric) {
      'days' => l10n.challengeMetricDays,
      'streak' => l10n.challengeMetricStreak,
      'milestones' => l10n.challengeMetricMilestones,
      'percent' => l10n.challengeMetricPercent,
      _ => l10n.statusWordUnknown,
    };

/// How progress counts for a measure (wire value).
String challengeMetricHelp(AppLocalizations l10n, String metric) =>
    switch (metric) {
      'days' => l10n.challengeMetricDaysHelp,
      'streak' => l10n.challengeMetricStreakHelp,
      'milestones' => l10n.challengeMetricMilestonesHelp,
      'percent' => l10n.challengeMetricPercentHelp,
      _ => '',
    };

/// The target in words, e.g. "5 days" (wire value of the measure).
String challengeTargetText(AppLocalizations l10n, String metric, int target) =>
    switch (metric) {
      'days' => l10n.challengeTargetDays(target),
      'streak' => l10n.challengeTargetStreak(target),
      'milestones' => l10n.challengeTargetCheckIns(target),
      'percent' => l10n.challengeTargetPercent(target),
      _ => '$target',
    };

/// Name of a challenge status (wire value).
String challengeStatusLabel(AppLocalizations l10n, ChallengeDto challenge) {
  if (challenge.status == ChallengeDtoStatus.active && challenge.ended) {
    return l10n.challengeStatusEnded;
  }
  return switch (challenge.status) {
    ChallengeDtoStatus.draft => l10n.challengeStatusDraft,
    ChallengeDtoStatus.active => l10n.challengeStatusActive,
    ChallengeDtoStatus.completed => l10n.challengeStatusCompleted,
    ChallengeDtoStatus.cancelled => l10n.challengeStatusCancelled,
    ChallengeDtoStatus.unrecognized => l10n.statusWordUnknown,
  };
}

/// Who can see a challenge (wire value).
String challengeVisibilityLabel(AppLocalizations l10n, String visibility) =>
    switch (visibility) {
      'private' => l10n.challengeScopePrivate,
      'group' => l10n.challengeScopeGroup,
      'community' => l10n.challengeScopeCommunity,
      'public' => l10n.challengeScopePublic,
      _ => l10n.statusWordUnknown,
    };

/// Whether [challenge] still takes check-ins and new participants.
bool challengeIsOpen(ChallengeDto challenge) =>
    challenge.status == ChallengeDtoStatus.active && !challenge.ended;

/// Milestones shown on a challenge (share of the target, in percent).
const List<int> challengeMilestones = <int>[25, 50, 75, 100];

/// Name of a milestone (25, 50 = halfway, 75, 100 = target reached).
String challengeMilestoneLabel(AppLocalizations l10n, int percent) =>
    switch (percent) {
      50 => l10n.challengeMilestoneHalfway,
      100 => l10n.challengeMilestoneDone,
      _ => l10n.challengeMilestonePercent(percent),
    };
