import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';

/// Goal types in the order forms offer them.
const List<GoalInputGoalType> goalTypeOrder = <GoalInputGoalType>[
  GoalInputGoalType.emergencyFund,
  GoalInputGoalType.travel,
  GoalInputGoalType.education,
  GoalInputGoalType.device,
  GoalInputGoalType.vehicle,
  GoalInputGoalType.home,
  GoalInputGoalType.event,
  GoalInputGoalType.debtPayoff,
  GoalInputGoalType.largePurchase,
  GoalInputGoalType.custom,
];

/// Contribution schedules in the order forms offer them.
const List<GoalInputContributionSchedule> goalScheduleOrder =
    <GoalInputContributionSchedule>[
      GoalInputContributionSchedule.none,
      GoalInputContributionSchedule.weekly,
      GoalInputContributionSchedule.biweekly,
      GoalInputContributionSchedule.monthly,
    ];

/// Status filters of the goals list: null is every goal except archived
/// ones (the server default) and `all` includes archived goals.
const List<String?> goalStatusFilters = <String?>[
  null,
  'active',
  'paused',
  'achieved',
  'cancelled',
  'archived',
  'all',
];

/// The goal's type as a form value, or null when this app version doesn't
/// know it.
GoalInputGoalType? goalTypeOf(GoalDto goal) => switch (goal.goalType) {
  GoalDtoGoalType.emergencyFund => GoalInputGoalType.emergencyFund,
  GoalDtoGoalType.travel => GoalInputGoalType.travel,
  GoalDtoGoalType.education => GoalInputGoalType.education,
  GoalDtoGoalType.device => GoalInputGoalType.device,
  GoalDtoGoalType.vehicle => GoalInputGoalType.vehicle,
  GoalDtoGoalType.home => GoalInputGoalType.home,
  GoalDtoGoalType.event => GoalInputGoalType.event,
  GoalDtoGoalType.debtPayoff => GoalInputGoalType.debtPayoff,
  GoalDtoGoalType.largePurchase => GoalInputGoalType.largePurchase,
  GoalDtoGoalType.custom => GoalInputGoalType.custom,
  GoalDtoGoalType.unrecognized => null,
};

/// The goal's schedule as a form value.
GoalInputContributionSchedule goalScheduleOf(GoalDto goal) {
  final GoalInputContributionSchedule schedule =
      GoalInputContributionSchedule.fromJson(goal.contributionSchedule.json);
  return schedule == GoalInputContributionSchedule.unrecognized
      ? GoalInputContributionSchedule.none
      : schedule;
}

/// Name of a goal type.
String goalTypeLabel(AppLocalizations l10n, GoalInputGoalType? type) =>
    switch (type) {
      GoalInputGoalType.emergencyFund => l10n.goalTypeEmergencyFund,
      GoalInputGoalType.travel => l10n.goalTypeTravel,
      GoalInputGoalType.education => l10n.goalTypeEducation,
      GoalInputGoalType.device => l10n.goalTypeDevice,
      GoalInputGoalType.vehicle => l10n.goalTypeVehicle,
      GoalInputGoalType.home => l10n.goalTypeHome,
      GoalInputGoalType.event => l10n.goalTypeEvent,
      GoalInputGoalType.debtPayoff => l10n.goalTypeDebtPayoff,
      GoalInputGoalType.largePurchase => l10n.goalTypeLargePurchase,
      GoalInputGoalType.custom ||
      GoalInputGoalType.unrecognized ||
      null => l10n.goalTypeCustom,
    };

/// Icon of a goal type (decorative; the name is always shown).
IconData goalTypeIcon(GoalInputGoalType? type) => switch (type) {
  GoalInputGoalType.emergencyFund => Icons.health_and_safety_outlined,
  GoalInputGoalType.travel => Icons.flight_takeoff,
  GoalInputGoalType.education => Icons.school_outlined,
  GoalInputGoalType.device => Icons.smartphone,
  GoalInputGoalType.vehicle => Icons.directions_car_outlined,
  GoalInputGoalType.home => Icons.home_outlined,
  GoalInputGoalType.event => Icons.celebration_outlined,
  GoalInputGoalType.debtPayoff => Icons.request_quote_outlined,
  GoalInputGoalType.largePurchase => Icons.shopping_bag_outlined,
  GoalInputGoalType.custom ||
  GoalInputGoalType.unrecognized ||
  null => Icons.flag_outlined,
};

/// Name of a goal status.
String goalStatusLabel(AppLocalizations l10n, GoalDtoStatus status) =>
    switch (status) {
      GoalDtoStatus.active => l10n.goalStatusActive,
      GoalDtoStatus.paused => l10n.goalStatusPaused,
      GoalDtoStatus.achieved => l10n.goalStatusAchieved,
      GoalDtoStatus.cancelled => l10n.goalStatusCancelled,
      GoalDtoStatus.archived => l10n.goalStatusArchived,
      GoalDtoStatus.unrecognized => l10n.goalStatusUnknown,
    };

/// A status chip for goals that are not simply active (icon + text).
StatusLabel? goalStatusChip(AppLocalizations l10n, GoalDtoStatus status) =>
    switch (status) {
      GoalDtoStatus.active => null,
      GoalDtoStatus.paused => StatusLabel(
        text: l10n.goalStatusPaused,
        icon: Icons.pause_circle_outline,
      ),
      GoalDtoStatus.achieved => StatusLabel(
        text: l10n.goalStatusAchieved,
        tone: StatusTone.positive,
      ),
      GoalDtoStatus.cancelled => StatusLabel(
        text: l10n.goalStatusCancelled,
        icon: Icons.do_not_disturb_on_outlined,
      ),
      GoalDtoStatus.archived => StatusLabel(
        text: l10n.goalStatusArchived,
        icon: Icons.inventory_2_outlined,
      ),
      GoalDtoStatus.unrecognized => StatusLabel(text: l10n.goalStatusUnknown),
    };

/// Label of a status filter chip (see [goalStatusFilters]).
String goalFilterLabel(AppLocalizations l10n, String? status) =>
    switch (status) {
      null => l10n.goalFilterCurrent,
      'all' => l10n.goalFilterAll,
      _ => goalStatusLabel(l10n, GoalDtoStatus.fromJson(status)),
    };

/// Name of a contribution schedule.
String goalScheduleLabel(
  AppLocalizations l10n,
  GoalInputContributionSchedule schedule,
) => switch (schedule) {
  GoalInputContributionSchedule.weekly => l10n.frequencyWeekly,
  GoalInputContributionSchedule.biweekly => l10n.frequencyBiweekly,
  GoalInputContributionSchedule.monthly => l10n.frequencyMonthly,
  GoalInputContributionSchedule.none ||
  GoalInputContributionSchedule.unrecognized => l10n.goalScheduleNone,
};

/// "1 · Highest" … "5 · Lowest" (1 is the highest priority).
String goalPriorityLabel(AppLocalizations l10n, int priority) {
  final String word = switch (priority) {
    1 => l10n.goalPriorityHighest,
    2 => l10n.goalPriorityHigh,
    3 => l10n.goalPriorityMedium,
    4 => l10n.goalPriorityLow,
    _ => l10n.goalPriorityLowest,
  };
  return '$priority · $word';
}

/// Name of a contribution status.
String contributionStatusLabel(
  AppLocalizations l10n,
  GoalContributionDtoStatus status,
) => switch (status) {
  GoalContributionDtoStatus.planned => l10n.contributionStatusPlanned,
  GoalContributionDtoStatus.recorded => l10n.contributionStatusRecorded,
  GoalContributionDtoStatus.verified => l10n.contributionStatusVerified,
  GoalContributionDtoStatus.unrecognized => l10n.contributionStatusUnknown,
};

/// Icon of a contribution status (each status has its own shape).
IconData contributionStatusIcon(GoalContributionDtoStatus status) =>
    switch (status) {
      GoalContributionDtoStatus.planned => Icons.schedule,
      GoalContributionDtoStatus.recorded => Icons.edit_note,
      GoalContributionDtoStatus.verified => Icons.verified_outlined,
      GoalContributionDtoStatus.unrecognized => Icons.help_outline,
    };

/// What a member may do (the owner is listed first with its own role).
String goalRoleLabel(AppLocalizations l10n, GoalMemberRole role) =>
    switch (role) {
      GoalMemberRole.owner => l10n.goalMemberRoleOwner,
      GoalMemberRole.contributor => l10n.goalMemberRoleContributor,
      GoalMemberRole.viewer ||
      GoalMemberRole.unrecognized => l10n.goalMemberRoleViewer,
    };

/// The people a goal is shared with, without its owner (the server lists
/// the owner first in `members`).
List<GoalMember> goalSharedMembers(GoalDto goal) => <GoalMember>[
  for (final GoalMember m in goal.members)
    if (m.role != GoalMemberRole.owner && m.userId != goal.ownerUserId) m,
];

/// One forecast assumption in the user's language, from its code and the
/// forecast's `assumption_params`; null for a code this app doesn't know.
String? goalAssumptionText(
  AppLocalizations l10n,
  GoalForecastAssumptionCodesItem code,
  Map<String, String> params,
) => switch (code) {
  GoalForecastAssumptionCodesItem.exactAmountsNoGrowth =>
    l10n.goalAssumptionExact(params['currency'] ?? ''),
  GoalForecastAssumptionCodesItem.recentPaceWindow => l10n.goalAssumptionPace(
    params['window_days'] ?? '90',
    params['months'] ?? '3',
  ),
  GoalForecastAssumptionCodesItem.plannedNotCounted =>
    l10n.goalAssumptionPlanned,
  GoalForecastAssumptionCodesItem.unrecognized => null,
};

/// The forecast's assumptions in the user's language: each code is
/// localized; an unknown code falls back to the server's English line at
/// the same position.
List<String> goalAssumptions(AppLocalizations l10n, GoalForecast forecast) {
  final List<GoalForecastAssumptionCodesItem> codes = forecast.assumptionCodes;
  final List<String> english = forecast.assumptions;
  final int count = codes.length > english.length
      ? codes.length
      : english.length;
  return <String>[
    for (int i = 0; i < count; i++)
      if ((i < codes.length
                  ? goalAssumptionText(
                      l10n,
                      codes[i],
                      forecast.assumptionParams,
                    )
                  : null) ??
              (i < english.length ? english[i] : null)
          case final String text)
        text,
  ];
}

/// The stored [goal] as the form would send it, so an edit can send only
/// what the user changed (see `partialPatch`).
GoalInput goalInputOf(GoalDto goal) {
  final GoalInputContributionSchedule schedule = goalScheduleOf(goal);
  String? trimmed(String? v) {
    final String? t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  return GoalInput(
    name: goal.name.trim(),
    goalType: goalTypeOf(goal) ?? GoalInputGoalType.unrecognized,
    targetAmount: goal.target.amount,
    currency: goal.target.currency,
    startingAmount: goal.starting.amountMinor == 0
        ? null
        : goal.starting.amount,
    startDate: goal.startDate,
    targetDate: goal.targetDate,
    contributionSchedule: schedule,
    plannedContribution: schedule == GoalInputContributionSchedule.none
        ? null
        : goal.plannedContribution?.amount,
    priority: goal.priority.clamp(1, 5),
    linkedAccountId: goal.linkedAccountId,
    milestones:
        <GoalMilestoneInput>[
          for (final GoalMilestone m in goal.milestones)
            GoalMilestoneInput(percent: m.percent, label: trimmed(m.label)),
        ]..sort(
          (GoalMilestoneInput a, GoalMilestoneInput b) =>
              a.percent.compareTo(b.percent),
        ),
    remindersEnabled: goal.remindersEnabled,
    visibility: goal.visibility == GoalDtoVisibility.members
        ? GoalInputVisibility.members
        : GoalInputVisibility.private,
    groupId: goal.groupId,
    description: trimmed(goal.description),
    notes: trimmed(goal.notes),
    version: goal.version,
  );
}

/// How a member's contributions appear to others.
String goalContributionVisibilityLabel(
  AppLocalizations l10n,
  GoalMemberContributionVisibility visibility,
) => switch (visibility) {
  GoalMemberContributionVisibility.amounts => l10n.goalMemberVisibilityAmounts,
  GoalMemberContributionVisibility.percentOnly =>
    l10n.goalMemberVisibilityPercent,
  GoalMemberContributionVisibility.hidden ||
  GoalMemberContributionVisibility.unrecognized =>
    l10n.goalMemberVisibilityHidden,
};

/// The server's progress (basis points of the target) as a 0–1 fraction,
/// for drawing a bar only; the text always shows the server's numbers.
double goalProgressFraction(int percentBp) =>
    (percentBp / 10000).clamp(0.0, 1.0);

/// "45%" or "45.5%" for [bp] basis points in [locale].
String formatGoalPercent(int bp, String locale) {
  final int digits = bp % 100 == 0 ? 0 : 1;
  try {
    return NumberFormat.decimalPercentPattern(
      locale: locale.replaceAll('-', '_'),
      decimalDigits: digits,
    ).format(bp / 10000);
  } on Object {
    return '${(bp / 100).toStringAsFixed(digits)}%';
  }
}

/// Whether the user may change the goal itself (edit, pause, members…).
bool canManageGoal(GoalDto goal) => goal.access == GoalDtoAccess.owner;

/// Whether the user may add contributions now (contributions are accepted
/// for active goals only).
bool canContribute(GoalDto goal) =>
    goal.status == GoalDtoStatus.active &&
    (goal.access == GoalDtoAccess.owner ||
        goal.access == GoalDtoAccess.contributor);

/// A goal member's name; `display_name` is optional in the contract (a
/// person who left Montra), so an empty name is shown as nothing.
String memberName(GoalMember member) => member.displayName?.trim() ?? '';
