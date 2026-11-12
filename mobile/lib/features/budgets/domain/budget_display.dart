import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';

/// Budget types in the order the form offers them.
const List<BudgetInputBudgetType> budgetTypeOrder = <BudgetInputBudgetType>[
  BudgetInputBudgetType.total,
  BudgetInputBudgetType.category,
  BudgetInputBudgetType.merchant,
  BudgetInputBudgetType.account,
  BudgetInputBudgetType.envelope,
  BudgetInputBudgetType.zeroBased,
];

/// Budget periods in the order the form offers them.
const List<BudgetInputPeriod> budgetPeriodOrder = <BudgetInputPeriod>[
  BudgetInputPeriod.weekly,
  BudgetInputPeriod.monthly,
  BudgetInputPeriod.annual,
  BudgetInputPeriod.custom,
];

/// Rollover policies in the order the form offers them.
const List<BudgetInputRolloverPolicy> rolloverOrder =
    <BudgetInputRolloverPolicy>[
      BudgetInputRolloverPolicy.none,
      BudgetInputRolloverPolicy.carryUnused,
      BudgetInputRolloverPolicy.carryOverspend,
      BudgetInputRolloverPolicy.carryBoth,
    ];

/// Alert levels (percent of the limit) the server accepts
/// (`alert_thresholds` enum); the form offers all of them.
const List<int> budgetThresholdOptions = <int>[
  1,
  5,
  10,
  20,
  25,
  30,
  40,
  50,
  60,
  70,
  75,
  80,
  90,
  95,
  100,
  110,
  125,
  150,
];

/// Most alert levels a budget can have (`alert_thresholds` maxItems).
const int budgetMaxThresholds = 10;

/// Levels the server uses when none are sent on create. An empty list
/// turns threshold alerts off.
const List<int> budgetDefaultThresholds = <int>[50, 75, 90, 100];

/// Types a group budget can have: group budgets track all of the group's
/// expenses, split between members at most.
const List<BudgetInputBudgetType> groupBudgetTypes = <BudgetInputBudgetType>[
  BudgetInputBudgetType.total,
  BudgetInputBudgetType.envelope,
  BudgetInputBudgetType.zeroBased,
];

/// The form's type for a budget's (response) type.
BudgetInputBudgetType budgetInputType(BudgetDtoBudgetType type) =>
    BudgetInputBudgetType.fromJson(type.json);

/// The form's period for a budget's (response) period.
BudgetInputPeriod budgetInputPeriod(BudgetDtoPeriod period) =>
    BudgetInputPeriod.fromJson(period.json);

/// The form's rollover policy for a budget's (response) policy.
BudgetInputRolloverPolicy budgetInputRollover(BudgetDtoRolloverPolicy policy) =>
    BudgetInputRolloverPolicy.fromJson(policy.json);

/// Whether a budget of [type] needs at least one allocation (the server
/// rejects category, envelope and zero-based budgets without one).
bool budgetNeedsAllocations(BudgetInputBudgetType type) =>
    type == BudgetInputBudgetType.category ||
    type == BudgetInputBudgetType.envelope ||
    type == BudgetInputBudgetType.zeroBased;

/// Whether the allocations of [type] are per category (category budgets
/// count only the categories they list; envelopes are filled by category).
bool budgetCategoryAllocations(BudgetInputBudgetType type) =>
    type == BudgetInputBudgetType.category ||
    type == BudgetInputBudgetType.envelope ||
    type == BudgetInputBudgetType.zeroBased;

/// Name of a budget type.
String budgetTypeLabel(AppLocalizations l10n, BudgetInputBudgetType type) =>
    switch (type) {
      BudgetInputBudgetType.total => l10n.budgetTypeTotal,
      BudgetInputBudgetType.category => l10n.budgetTypeCategory,
      BudgetInputBudgetType.merchant => l10n.budgetTypeMerchant,
      BudgetInputBudgetType.account => l10n.budgetTypeAccount,
      BudgetInputBudgetType.envelope => l10n.budgetTypeEnvelope,
      BudgetInputBudgetType.zeroBased => l10n.budgetTypeZeroBased,
      BudgetInputBudgetType.unrecognized => l10n.budgetTypeUnknown,
    };

/// One-line explanation of a budget type.
String budgetTypeHelp(AppLocalizations l10n, BudgetInputBudgetType type) =>
    switch (type) {
      BudgetInputBudgetType.total => l10n.budgetTypeTotalHelp,
      BudgetInputBudgetType.category => l10n.budgetTypeCategoryHelp,
      BudgetInputBudgetType.merchant => l10n.budgetTypeMerchantHelp,
      BudgetInputBudgetType.account => l10n.budgetTypeAccountHelp,
      BudgetInputBudgetType.envelope => l10n.budgetTypeEnvelopeHelp,
      BudgetInputBudgetType.zeroBased => l10n.budgetTypeZeroBasedHelp,
      BudgetInputBudgetType.unrecognized => l10n.budgetTypeUnknown,
    };

/// Icon for a budget type.
IconData budgetTypeIcon(BudgetInputBudgetType type) => switch (type) {
  BudgetInputBudgetType.total => Icons.savings_outlined,
  BudgetInputBudgetType.category => Icons.category_outlined,
  BudgetInputBudgetType.merchant => Icons.storefront_outlined,
  BudgetInputBudgetType.account => Icons.account_balance_outlined,
  BudgetInputBudgetType.envelope => Icons.mail_outline,
  BudgetInputBudgetType.zeroBased => Icons.pie_chart_outline,
  BudgetInputBudgetType.unrecognized => Icons.savings_outlined,
};

/// Name of a budget period.
String budgetPeriodLabel(AppLocalizations l10n, BudgetInputPeriod period) =>
    switch (period) {
      BudgetInputPeriod.weekly => l10n.budgetPeriodWeekly,
      BudgetInputPeriod.monthly => l10n.budgetPeriodMonthly,
      BudgetInputPeriod.annual => l10n.budgetPeriodAnnual,
      BudgetInputPeriod.custom => l10n.budgetPeriodCustom,
      BudgetInputPeriod.unrecognized => l10n.budgetPeriodUnknown,
    };

/// What happens at the end of a period.
String budgetRolloverLabel(
  AppLocalizations l10n,
  BudgetInputRolloverPolicy policy,
) => switch (policy) {
  BudgetInputRolloverPolicy.none => l10n.budgetRolloverNone,
  BudgetInputRolloverPolicy.carryUnused => l10n.budgetRolloverUnused,
  BudgetInputRolloverPolicy.carryOverspend => l10n.budgetRolloverOverspend,
  BudgetInputRolloverPolicy.carryBoth => l10n.budgetRolloverBoth,
  BudgetInputRolloverPolicy.unrecognized => l10n.budgetRolloverUnknown,
};

/// Name of a budget status.
String budgetStatusLabel(AppLocalizations l10n, BudgetDtoStatus status) =>
    switch (status) {
      BudgetDtoStatus.active => l10n.budgetStatusActive,
      BudgetDtoStatus.paused => l10n.budgetStatusPaused,
      BudgetDtoStatus.archived => l10n.budgetStatusArchived,
      BudgetDtoStatus.unrecognized => l10n.budgetStatusUnknown,
    };

/// The pace in words. Calm wording: being over is a fact, not a failure.
String budgetPaceLabel(AppLocalizations l10n, ProgressDtoPace pace) =>
    switch (pace) {
      ProgressDtoPace.underPace => l10n.budgetPaceUnder,
      ProgressDtoPace.onTrack => l10n.budgetPaceOnTrack,
      ProgressDtoPace.aheadOfPace => l10n.budgetPaceAhead,
      ProgressDtoPace.overBudget => l10n.budgetPaceOver,
      ProgressDtoPace.unrecognized => l10n.budgetPaceUnknown,
    };

/// Tone of the pace label (always shown with its words and an icon).
StatusTone budgetPaceTone(ProgressDtoPace pace) => switch (pace) {
  ProgressDtoPace.underPace || ProgressDtoPace.onTrack => StatusTone.positive,
  ProgressDtoPace.aheadOfPace ||
  ProgressDtoPace.overBudget => StatusTone.caution,
  ProgressDtoPace.unrecognized => StatusTone.neutral,
};

/// Icon of the pace label (distinct per pace, so meaning never depends on
/// color).
IconData budgetPaceIcon(ProgressDtoPace pace) => switch (pace) {
  ProgressDtoPace.underPace => Icons.trending_down,
  ProgressDtoPace.onTrack => Icons.check_circle_outline,
  ProgressDtoPace.aheadOfPace => Icons.trending_up,
  ProgressDtoPace.overBudget => Icons.error_outline,
  ProgressDtoPace.unrecognized => Icons.help_outline,
};

/// Who shared [budget] and what the user may do with it ("Shared by Asha
/// · can edit"), for collaborators; null for the owner.
String? budgetSharedByLabel(AppLocalizations l10n, BudgetDto budget) {
  final String owner = budget.ownerDisplayName.trim();
  return switch (budget.access) {
    BudgetDtoAccess.owner || BudgetDtoAccess.unrecognized => null,
    BudgetDtoAccess.editor =>
      owner.isEmpty
          ? l10n.budgetAccessEditor
          : l10n.budgetSharedByEditor(owner),
    BudgetDtoAccess.viewer =>
      owner.isEmpty
          ? l10n.budgetAccessViewer
          : l10n.budgetSharedByViewer(owner),
  };
}

/// What a member may do.
String budgetRoleLabel(AppLocalizations l10n, MemberDtoRole role) =>
    switch (role) {
      MemberDtoRole.editor => l10n.budgetRoleEditor,
      MemberDtoRole.viewer ||
      MemberDtoRole.unrecognized => l10n.budgetRoleViewer,
    };

/// The headline of a budget alert.
String budgetAlertTitle(AppLocalizations l10n, AlertDto alert) =>
    switch (alert.kind) {
      AlertDtoKind.threshold when alert.threshold == 100 =>
        l10n.budgetAlertFullyUsed(alert.budgetName),
      AlertDtoKind.threshold => l10n.budgetAlertThreshold(
        alert.budgetName,
        alert.threshold,
      ),
      AlertDtoKind.forecastOverspend => l10n.budgetAlertForecast(
        alert.budgetName,
      ),
      AlertDtoKind.unusualSpend => l10n.budgetAlertUnusual(alert.budgetName),
      AlertDtoKind.unrecognized => l10n.budgetAlertOther(alert.budgetName),
    };

/// Plain-language notes on how [progress] of [budget] was calculated, in
/// the user's language: the server's `explanation_items` (codes with
/// values), plus what the budget counts (pending or posted transactions,
/// or the group's expenses). An unknown code falls back to the server's
/// English line at the same position. [money] formats an exact amount
/// string in a currency and [date] a calendar date.
List<String> budgetExplanation(
  AppLocalizations l10n, {
  required BudgetDto budget,
  required ProgressDto progress,
  required String Function(String amount, String currency) money,
  required String Function(String date) date,
}) {
  final List<ExplainItem> items = progress.explanationItems;
  if (items.isEmpty) {
    return progress.explanation;
  }
  final String counts = budget.groupId != null
      ? l10n.budgetExplainGroup
      : (budget.includePending
            ? l10n.budgetExplainPending
            : l10n.budgetExplainPostedOnly);
  final List<String> out = <String>[];
  bool countsShown = false;
  for (int i = 0; i < items.length; i++) {
    final ExplainItem item = items[i];
    final String? text =
        budgetExplainItemText(l10n, item, money: money, date: date) ??
        (i < progress.explanation.length ? progress.explanation[i] : null);
    if (text != null) {
      out.add(text);
    }
    if (!countsShown &&
        (item.code == 'refunds_restore' ||
            item.code == 'refunds_do_not_restore')) {
      out.add(counts);
      countsShown = true;
    }
  }
  if (!countsShown) {
    out.insert(out.isEmpty ? 0 : 1, counts);
  }
  return out;
}

/// One explanation item in the user's language, or null for a code this
/// app does not know.
String? budgetExplainItemText(
  AppLocalizations l10n,
  ExplainItem item, {
  required String Function(String amount, String currency) money,
  required String Function(String date) date,
}) {
  final Map<String, String> p = item.params ?? const <String, String>{};
  final String currency = p['currency'] ?? '';
  return switch (item.code) {
    'spent_of_limit'
        when p['spent'] != null &&
            p['limit'] != null &&
            p['from'] != null &&
            p['to'] != null =>
      l10n.budgetExplainSpent(
        money(p['spent']!, currency),
        money(p['limit']!, currency),
        date(p['from']!),
        date(p['to']!),
      ),
    'refunds_restore' => l10n.budgetExplainRefundsRestore,
    'refunds_do_not_restore' => l10n.budgetExplainRefundsIgnored,
    'rollover_included' when p['amount'] != null => l10n.budgetExplainCarry(
      money(p['amount']!, currency),
    ),
    'projection_estimate' when p['projected'] != null =>
      l10n.budgetExplainProjected(money(p['projected']!, currency)),
    'other_currencies_excluded' when int.tryParse(p['count'] ?? '') != null =>
      l10n.budgetExplainOtherCurrency(int.parse(p['count']!)),
    'owner_totals_only' => l10n.budgetExplainCollaborator,
    _ => null,
  };
}

/// The stored [budget] as the form would send it, so an edit can send only
/// what the user changed (see `partialPatch`). Mirrors the form's choices:
/// group budgets carry no filters, custom periods no rollover, and only
/// merchant budgets list merchants.
BudgetInput budgetInputOf(BudgetDto budget) {
  final bool group = budget.groupId != null;
  final BudgetInputBudgetType type = budgetInputType(budget.budgetType);
  final BudgetInputPeriod period = budgetInputPeriod(budget.period);
  final bool custom = period == BudgetInputPeriod.custom;
  final BudgetInputRolloverPolicy rollover = custom
      ? BudgetInputRolloverPolicy.none
      : budgetInputRollover(budget.rolloverPolicy);
  final String? notes = budget.notes?.trim();
  return BudgetInput(
    name: budget.name.trim(),
    budgetType: type,
    period: period,
    currency: budget.currency,
    limit: budget.limit.amount,
    startsOn: budget.startsOn,
    endsOn: custom ? budget.endsOn : null,
    timezone: budget.timezone,
    rolloverPolicy: rollover,
    rolloverCap: rollover == BudgetInputRolloverPolicy.none
        ? null
        : budget.rolloverCap?.amount,
    includePending: !group && budget.includePending,
    refundsRestore: budget.refundsRestore,
    countGroupShares: budget.countGroupShares,
    includedAccountIds: group ? <String>[] : budget.includedAccountIds,
    excludedCategoryIds: group ? <String>[] : budget.excludedCategoryIds,
    merchantIds: !group && type == BudgetInputBudgetType.merchant
        ? budget.merchantIds
        : <String>[],
    alertThresholds: List<int>.of(budget.alertThresholds)..sort(),
    alertForecast: budget.alertForecast,
    visibility: group && budget.visibility == BudgetDtoVisibility.members
        ? BudgetInputVisibility.members
        : BudgetInputVisibility.private,
    notes: notes == null || notes.isEmpty ? null : notes,
    groupId: budget.groupId,
    allocations: <AllocInput>[
      for (final AllocationDto a in budget.allocations) allocInputOf(a),
    ],
    version: budget.version,
  );
}

/// A stored allocation as a request item.
AllocInput allocInputOf(AllocationDto a) {
  final String? label = a.label?.trim();
  return AllocInput(
    limit: a.limit.amount,
    label: label == null || label.isEmpty ? null : label,
    categoryId: a.categoryId,
    merchantId: a.categoryId == null ? a.merchantId : null,
    accountId: a.categoryId == null && a.merchantId == null
        ? a.accountId
        : null,
    memberUserId:
        a.categoryId == null && a.merchantId == null && a.accountId == null
        ? a.memberUserId
        : null,
  );
}

/// Basis points (10000 = 100 %) as a percentage in [locale], e.g. `40.5%`.
String budgetPercent(int basisPoints, String locale) {
  try {
    return NumberFormat.decimalPercentPattern(
      locale: locale.replaceAll('-', '_'),
      decimalDigits: 1,
    ).format(basisPoints / 10000);
  } on Object {
    return '${(basisPoints / 100).toStringAsFixed(1)}%';
  }
}

/// Bar length for [basisPoints] of a limit, for drawing only.
double budgetBarFraction(int basisPoints) =>
    (basisPoints / 10000).clamp(0, 1).toDouble();
