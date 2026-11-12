import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';

/// Status filters of the bills list (wire values), in order.
const List<String> billStatusFilters = <String>[
  'active',
  'paused',
  'archived',
  'all',
];

/// Text, tone and icon of a bill's payment state (`state` wire value).
/// A bill is never shown as paid just because its date passed.
(String, StatusTone, IconData) billStateLabel(
  AppLocalizations l10n,
  String state,
) => switch (state) {
  'overdue' => (l10n.billStateOverdue, StatusTone.caution, Icons.error_outline),
  'due_today' => (l10n.billStateDueToday, StatusTone.caution, Icons.today),
  'due_soon' => (l10n.billStateDueSoon, StatusTone.caution, Icons.schedule),
  'paid' => (
    l10n.billStatePaid,
    StatusTone.positive,
    Icons.check_circle_outline,
  ),
  'upcoming' => (l10n.billStateUpcoming, StatusTone.neutral, Icons.event),
  'paused' => (
    l10n.billStatePaused,
    StatusTone.neutral,
    Icons.pause_circle_outline,
  ),
  'archived' => (
    l10n.billStateArchived,
    StatusTone.neutral,
    Icons.inventory_2_outlined,
  ),
  'ended' => (
    l10n.billStateEnded,
    StatusTone.neutral,
    Icons.stop_circle_outlined,
  ),
  _ => (l10n.billStateOther, StatusTone.neutral, Icons.help_outline),
};

/// [bill] as the edit form sends it (`BillInput` without status, version or
/// document): the "before" side of a partial `PATCH`.
BillInput billInputFrom(BillDetail bill) {
  final ScheduleValue s = ScheduleValue.fromRule(bill.schedule).normalized();
  String? text(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
  return BillInput(
    name: bill.name,
    providerName: text(bill.providerName),
    amountIsVariable: bill.amountIsVariable,
    expectedAmount: bill.amountIsVariable ? null : bill.expectedAmount?.amount,
    currency: bill.currency,
    paymentAccountId: bill.paymentAccountId,
    categoryId: bill.categoryId,
    notes: text(bill.notes),
    frequency: billFrequencyOf(s.frequency),
    intervalCount: s.intervalCount,
    intervalUnit: billIntervalUnitOf(s.intervalUnit),
    byMonthDay: s.byMonthDay,
    byWeekday: s.byWeekday,
    byWeekOfMonth: s.byWeekOfMonth,
    startDate: s.startDate,
    endDate: s.endDate,
    maxOccurrences: s.maxOccurrences,
    localTime: s.localTime,
    timezone: bill.schedule.timezone,
    reminderDaysBefore: bill.schedule.reminderDaysBefore,
  );
}

/// The partial `PATCH /bills/{id}` body turning [original] into [edited]
/// (both as the form sends them): only changed fields, emptied text with
/// `""`, emptied references and schedule anchors in `clear`, the whole
/// schedule group when the frequency or an anchor changes, and the
/// version shown.
BillPatch billPatchFor(BillDetail original, BillInput edited) =>
    BillPatch.fromJson(
      partialPatch(
        before: billInputFrom(original).toJson(),
        after: <String, Object?>{
          ...edited.toJson(),
          'version': original.version,
        }..remove('status'),
        clearable: <String>{
          for (final BillPatchClearItem c in BillPatchClearItem.values)
            if (c != BillPatchClearItem.unrecognized) c.json,
        },
        textFields: billPatchTextFields,
        together: <Set<String>>[scheduleGroupKeys],
      ),
    );

/// Bill fields cleared with an empty string (`BillPatch`): `""` for
/// `expected_amount` makes the bill variable.
const Set<String> billPatchTextFields = <String>{
  'provider_name',
  'notes',
  'end_date',
  'expected_amount',
};

/// Lifecycle actions offered for a bill in [status] (the server's rules:
/// pause from active, resume from paused, archive from active or paused,
/// restore from archived).
List<BillAction> billActionsFor(BillDetailStatus status) => switch (status) {
  BillDetailStatus.active => const <BillAction>[
    BillAction.pause,
    BillAction.archive,
  ],
  BillDetailStatus.paused => const <BillAction>[
    BillAction.resume,
    BillAction.archive,
  ],
  BillDetailStatus.archived => const <BillAction>[BillAction.restore],
  BillDetailStatus.unrecognized => const <BillAction>[],
};

/// Why a recorded payment was suggested for a bill, in the user's
/// language, from its stable `reason_codes` (an unknown code falls back to
/// the server's English reason at the same position).
List<String> billCandidateReasons(
  AppLocalizations l10n,
  BillPaymentCandidate candidate,
) {
  final List<BillPaymentCandidateReasonCodesItem> codes = candidate.reasonCodes;
  final List<String> english = candidate.reasons;
  final int days = candidate.daysFromDue;
  return <String>[
    for (int i = 0; i < codes.length; i++)
      switch (codes[i]) {
        BillPaymentCandidateReasonCodesItem.sameProvider =>
          l10n.billReasonSameProvider,
        BillPaymentCandidateReasonCodesItem.sameAmount =>
          l10n.billReasonSameAmount,
        BillPaymentCandidateReasonCodesItem.amountClose =>
          l10n.billReasonAmountClose,
        BillPaymentCandidateReasonCodesItem.onDueDate =>
          l10n.billReasonOnDueDate,
        BillPaymentCandidateReasonCodesItem.nearDueDate =>
          days < 0
              ? l10n.billReasonDaysBefore(-days)
              : days > 0
              ? l10n.billReasonDaysAfter(days)
              : l10n.billReasonOnDueDate,
        BillPaymentCandidateReasonCodesItem.unrecognized =>
          i < english.length ? english[i] : l10n.billReasonOther,
      },
  ];
}

/// Location of the mark-paid screen for [billId], for one occurrence when
/// [occurrenceId] is given (default: the oldest unpaid one).
String billPayLocation(String billId, {String? occurrenceId}) =>
    occurrenceId == null
    ? AppRoutes.payBill(billId)
    : '${AppRoutes.payBill(billId)}?occurrence='
          '${Uri.encodeQueryComponent(occurrenceId)}';
