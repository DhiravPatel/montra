import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';

/// Kinds a rule can be created with in the recurring form, in order.
const List<RecurringRuleInputKind> recurringFormKinds =
    <RecurringRuleInputKind>[
      RecurringRuleInputKind.expense,
      RecurringRuleInputKind.income,
      RecurringRuleInputKind.transfer,
    ];

/// Localized name of a rule or occurrence kind (wire value); unknown kinds
/// read as "Recurring".
String recurringKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'expense' => l10n.recurringKindExpense,
  'income' => l10n.recurringKindIncome,
  'transfer' => l10n.recurringKindTransfer,
  'bill' => l10n.recurringKindBill,
  'subscription' => l10n.recurringKindSubscription,
  'group_expense' => l10n.recurringKindGroupExpense,
  _ => l10n.recurringKindOther,
};

/// Icon for a rule or occurrence kind.
IconData recurringKindIcon(String kind) => switch (kind) {
  'expense' => Icons.north_east,
  'income' => Icons.south_west,
  'transfer' => Icons.swap_horiz,
  'bill' => Icons.receipt_long_outlined,
  'subscription' => Icons.autorenew,
  'group_expense' => Icons.groups_outlined,
  _ => Icons.repeat,
};

/// Whether rules of [kind] are managed on this screen. Bills are managed
/// from the bill, subscriptions from the subscription and shared expenses
/// from the group, so their schedules are read-only here.
bool isManagedHere(String kind) =>
    kind == 'expense' || kind == 'income' || kind == 'transfer';

/// Text and tone of a rule status.
(String, StatusTone) recurringStatusLabel(
  AppLocalizations l10n,
  String status,
) => switch (status) {
  'active' => (l10n.recurringStatusActive, StatusTone.positive),
  'paused' => (l10n.recurringStatusPaused, StatusTone.caution),
  'ended' => (l10n.recurringStatusEnded, StatusTone.neutral),
  _ => (status, StatusTone.neutral),
};

/// Text, tone and icon of an occurrence status.
(String, StatusTone, IconData) occurrenceStatusLabel(
  AppLocalizations l10n,
  OccurrenceDtoStatus status,
) => switch (status) {
  OccurrenceDtoStatus.scheduled => (
    l10n.occurrenceStatusScheduled,
    StatusTone.neutral,
    Icons.event_outlined,
  ),
  OccurrenceDtoStatus.posted => (
    l10n.occurrenceStatusPosted,
    StatusTone.positive,
    Icons.check_circle_outline,
  ),
  OccurrenceDtoStatus.paid => (
    l10n.occurrenceStatusPaid,
    StatusTone.positive,
    Icons.check_circle_outline,
  ),
  OccurrenceDtoStatus.skipped => (
    l10n.occurrenceStatusSkipped,
    StatusTone.neutral,
    Icons.redo,
  ),
  OccurrenceDtoStatus.overdue => (
    l10n.occurrenceStatusOverdue,
    StatusTone.caution,
    Icons.error_outline,
  ),
  OccurrenceDtoStatus.unrecognized => (
    l10n.occurrenceStatusOther,
    StatusTone.neutral,
    Icons.help_outline,
  ),
};

/// Whether an occurrence still needs something done (not recorded, paid or
/// skipped). A moved occurrence keeps its status (`postponed_to` is set),
/// so it stays open.
bool isOpenOccurrence(OccurrenceDto o) =>
    o.status == OccurrenceDtoStatus.scheduled ||
    o.status == OccurrenceDtoStatus.overdue;

/// Splits [occurrences] (newest first, as the server sends them) into open
/// ones, soonest first, and the rest, newest first.
({List<OccurrenceDto> open, List<OccurrenceDto> done}) splitOccurrences(
  List<OccurrenceDto> occurrences,
) {
  final List<OccurrenceDto> open = occurrences.where(isOpenOccurrence).toList()
    ..sort(
      (OccurrenceDto a, OccurrenceDto b) =>
          a.effectiveDate.compareTo(b.effectiveDate),
    );
  final List<OccurrenceDto> done = occurrences
      .where((OccurrenceDto o) => !isOpenOccurrence(o))
      .toList();
  return (open: open, done: done);
}

/// The date a moved occurrence now falls on (`postponed_to`), or null when
/// it was not moved.
String? movedTo(OccurrenceDto o) {
  final String? to = o.postponedTo;
  return to == null || to.isEmpty || to == o.occurrenceDate ? null : to;
}

/// The form kind of a rule (rules of other kinds are not edited here).
RecurringRuleInputKind recurringInputKindOf(RecurringRuleDetailKind kind) =>
    switch (kind) {
      RecurringRuleDetailKind.income => RecurringRuleInputKind.income,
      RecurringRuleDetailKind.transfer => RecurringRuleInputKind.transfer,
      _ => RecurringRuleInputKind.expense,
    };

/// [rule] as the edit form sends it (`RecurringRuleInput` without the
/// version): the "before" side of a partial `PATCH`.
RecurringRuleInput recurringInputFrom(RecurringRuleDetail rule) {
  final ScheduleValue s = ScheduleValue.fromDetail(rule).normalized();
  final RecurringRuleInputKind kind = recurringInputKindOf(rule.kind);
  final bool transfer = kind == RecurringRuleInputKind.transfer;
  String? text(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
  return RecurringRuleInput(
    kind: kind,
    name: rule.name,
    amount: rule.amountIsVariable ? null : rule.amount?.amount,
    amountIsVariable: rule.amountIsVariable,
    currency: rule.currency,
    accountId: rule.accountId,
    toAccountId: transfer ? rule.toAccountId : null,
    categoryId: transfer ? null : rule.categoryId,
    merchantName: transfer ? null : rule.merchant?.name,
    description: text(rule.description),
    notes: text(rule.notes),
    autoPost: rule.autoPost,
    frequency: recurringFrequencyOf(s.frequency),
    intervalCount: s.intervalCount,
    intervalUnit: recurringIntervalUnitOf(s.intervalUnit),
    byMonthDay: s.byMonthDay,
    byWeekday: s.byWeekday,
    byWeekOfMonth: s.byWeekOfMonth,
    startDate: s.startDate,
    endDate: s.endDate,
    maxOccurrences: s.maxOccurrences,
    localTime: s.localTime,
    timezone: rule.timezone,
    reminderDaysBefore: rule.reminderDaysBefore,
  );
}

/// Rule fields cleared with an empty string (`RecurringRulePatch`).
const Set<String> recurringPatchTextFields = <String>{
  'amount',
  'description',
  'end_date',
  'merchant_name',
  'notes',
};

/// The partial `PATCH /recurring-rules/{id}` body turning [original] into
/// [edited] (as the form sends it): only changed fields, emptied text with
/// `""`, emptied references and anchors in `clear`, the whole schedule
/// group when it changes, and the version shown. The kind never changes.
RecurringRulePatch recurringPatchFor(
  RecurringRuleDetail original,
  RecurringRuleInput edited,
) => RecurringRulePatch.fromJson(
  partialPatch(
    before: recurringInputFrom(original).toJson(),
    after: <String, Object?>{
      ...edited.toJson(),
      'kind': recurringInputFrom(original).kind.json,
      'version': original.version,
    },
    clearable: <String>{
      for (final RecurringRulePatchClearItem c
          in RecurringRulePatchClearItem.values)
        if (c != RecurringRulePatchClearItem.unrecognized) c.json,
    },
    textFields: recurringPatchTextFields,
    together: <Set<String>>[scheduleGroupKeys],
  ),
);
