import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';

/// Text for a subscription status (wire value; the DTO and detail enums
/// share the same values).
String subscriptionStatusText(AppLocalizations l10n, String status) =>
    switch (status) {
      'trial' => l10n.subscriptionStatusTrial,
      'active' => l10n.subscriptionStatusActive,
      'paused' => l10n.subscriptionStatusPaused,
      'cancellation_pending' => l10n.subscriptionStatusCancelling,
      'cancelled' => l10n.subscriptionStatusCancelled,
      _ => l10n.subscriptionStatusUnknown,
    };

/// Icon shown with a status (the text always says it too).
IconData subscriptionStatusIcon(String status) => switch (status) {
  'trial' => Icons.hourglass_top,
  'active' => Icons.autorenew,
  'paused' => Icons.pause_circle_outline,
  'cancellation_pending' => Icons.pending_outlined,
  'cancelled' => Icons.cancel_outlined,
  _ => Icons.help_outline,
};

/// Tone of a status label.
StatusTone subscriptionStatusTone(String status) => switch (status) {
  'active' => StatusTone.positive,
  'cancellation_pending' => StatusTone.caution,
  _ => StatusTone.neutral,
};

/// Label of a list filter (see `subscriptionListFilters`).
String subscriptionFilterLabel(AppLocalizations l10n, String filter) =>
    switch (filter) {
      '' => l10n.subscriptionFilterCurrent,
      'all' => l10n.subscriptionFilterAll,
      _ => subscriptionStatusText(l10n, filter),
    };

/// "Monthly", "Every 10 days": a subscription's billing cycle.
String billingCycleText(
  AppLocalizations l10n,
  String frequency,
  int intervalCount,
  String? intervalUnit,
) => frequencyLabel(
  l10n,
  frequency,
  intervalCount: intervalCount,
  intervalUnit: intervalUnit,
);

/// What a history entry records; unknown kinds read as "Updated".
String subscriptionEventText(
  AppLocalizations l10n,
  SubscriptionEventKind kind,
) => switch (kind) {
  SubscriptionEventKind.created => l10n.subscriptionEventCreated,
  SubscriptionEventKind.edited => l10n.subscriptionEventEdited,
  SubscriptionEventKind.priceChanged => l10n.subscriptionEventPriceChanged,
  SubscriptionEventKind.renewed => l10n.subscriptionEventRenewed,
  SubscriptionEventKind.paymentRecorded => l10n.subscriptionEventPayment,
  SubscriptionEventKind.paymentUnlinked =>
    l10n.subscriptionEventPaymentUnlinked,
  SubscriptionEventKind.trialStarted => l10n.subscriptionEventTrialStarted,
  SubscriptionEventKind.trialEnding => l10n.subscriptionEventTrialEnding,
  SubscriptionEventKind.paused => l10n.subscriptionEventPaused,
  SubscriptionEventKind.resumed => l10n.subscriptionEventResumed,
  SubscriptionEventKind.cancellationStarted =>
    l10n.subscriptionEventCancellationStarted,
  SubscriptionEventKind.cancelled => l10n.subscriptionEventCancelled,
  SubscriptionEventKind.reactivated => l10n.subscriptionEventReactivated,
  SubscriptionEventKind.verified => l10n.subscriptionEventVerified,
  SubscriptionEventKind.unrecognized => l10n.subscriptionEventOther,
};

/// The note of a history entry: Montra's own notes are localized by
/// `note_code`; the user's notes are shown as written.
String? subscriptionEventNote(AppLocalizations l10n, SubscriptionEvent e) =>
    switch (e.noteCode) {
      SubscriptionEventNoteCode.matchedByDetection =>
        l10n.subscriptionNoteMatchedByDetection,
      _ => (e.note?.isEmpty ?? true) ? null : e.note,
    };

/// Why two subscriptions look alike, from the warning's `reason_code`
/// (an unknown code shows the server's English reason).
String duplicateWarningReason(AppLocalizations l10n, DuplicateWarning w) =>
    switch (w.reasonCode) {
      DuplicateWarningReasonCode.sameMerchant =>
        l10n.subscriptionDuplicateSameMerchant,
      DuplicateWarningReasonCode.sameName => l10n.subscriptionDuplicateSameName,
      DuplicateWarningReasonCode.samePriceAndCycle =>
        l10n.subscriptionDuplicateSamePrice,
      DuplicateWarningReasonCode.unrecognized => w.reason,
    };

/// Why a charge was suggested as this subscription's payment, from its
/// stable `reason_codes` (an unknown code shows the English reason at the
/// same position).
List<String> subscriptionCandidateReasons(
  AppLocalizations l10n,
  SubscriptionPaymentCandidate c,
) {
  final List<String> english = c.reasons;
  final int? days = c.daysFromRenewal;
  return <String>[
    for (int i = 0; i < c.reasonCodes.length; i++)
      switch (c.reasonCodes[i]) {
        SubscriptionPaymentCandidateReasonCodesItem.sameMerchant =>
          l10n.subscriptionReasonSameMerchant,
        SubscriptionPaymentCandidateReasonCodesItem.matchesName =>
          l10n.subscriptionReasonMatchesName,
        SubscriptionPaymentCandidateReasonCodesItem.sameAmount =>
          l10n.subscriptionReasonSameAmount,
        SubscriptionPaymentCandidateReasonCodesItem.amountClose =>
          l10n.subscriptionReasonAmountClose,
        SubscriptionPaymentCandidateReasonCodesItem.onRenewalDate =>
          l10n.subscriptionReasonOnRenewalDate,
        SubscriptionPaymentCandidateReasonCodesItem.nearRenewalDate =>
          days == null || days == 0
              ? l10n.subscriptionReasonOnRenewalDate
              : days < 0
              ? l10n.subscriptionReasonDaysBefore(-days)
              : l10n.subscriptionReasonDaysAfter(days),
        SubscriptionPaymentCandidateReasonCodesItem.unrecognized =>
          i < english.length ? english[i] : l10n.subscriptionReasonOther,
      },
  ];
}

const Map<SubscriptionAction, Set<String>>
_actionFrom = <SubscriptionAction, Set<String>>{
  SubscriptionAction.verify: <String>{
    'trial',
    'active',
    'paused',
    'cancellation_pending',
    'cancelled',
  },
  SubscriptionAction.pause: <String>{'trial', 'active'},
  SubscriptionAction.resume: <String>{'paused'},
  SubscriptionAction.cancellationStarted: <String>{'trial', 'active', 'paused'},
  SubscriptionAction.cancelled: <String>{
    'trial',
    'active',
    'paused',
    'cancellation_pending',
  },
  SubscriptionAction.reactivate: <String>{'cancelled', 'cancellation_pending'},
};

/// Lifecycle actions offered in [status] (the server's rules; it still
/// decides and answers CONFLICT otherwise).
List<SubscriptionAction> subscriptionActionsFor(String status) =>
    <SubscriptionAction>[
      for (final SubscriptionAction a in SubscriptionAction.values)
        if (_actionFrom[a]!.contains(status)) a,
    ];

/// Menu text of an action.
String subscriptionActionText(AppLocalizations l10n, SubscriptionAction a) =>
    switch (a) {
      SubscriptionAction.verify => l10n.subscriptionActionVerify,
      SubscriptionAction.pause => l10n.subscriptionActionPause,
      SubscriptionAction.resume => l10n.subscriptionActionResume,
      SubscriptionAction.cancellationStarted =>
        l10n.subscriptionActionCancellationStarted,
      SubscriptionAction.cancelled => l10n.subscriptionActionCancelled,
      SubscriptionAction.reactivate => l10n.subscriptionActionReactivate,
    };

/// Confirmation shown after an action succeeded.
String subscriptionActionDone(AppLocalizations l10n, SubscriptionAction a) =>
    switch (a) {
      SubscriptionAction.verify => l10n.subscriptionVerifiedDone,
      SubscriptionAction.pause => l10n.subscriptionPausedDone,
      SubscriptionAction.resume => l10n.subscriptionResumedDone,
      SubscriptionAction.cancellationStarted =>
        l10n.subscriptionCancellationStartedDone,
      SubscriptionAction.cancelled => l10n.subscriptionCancelledDone,
      SubscriptionAction.reactivate => l10n.subscriptionReactivatedDone,
    };

/// [d] as the edit form sends it (the "before" side of a partial `PATCH`):
/// every editable detail as request JSON, without the version and the
/// invoice file (which the form never changes). `cancelled_on` is included
/// for cancelled subscriptions, whose cancellation date can be corrected.
Map<String, Object?> subscriptionFormJson(SubscriptionDetail d) {
  String? text(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
  final bool custom =
      d.billingFrequency == SubscriptionDetailBillingFrequency.custom;
  return <String, Object?>{
    'name': d.name,
    'plan_name': ?text(d.planName),
    'merchant_name': ?d.merchant?.name,
    'amount': d.amount.amount,
    'currency': d.amount.currency,
    'billing_frequency': d.billingFrequency.json,
    if (custom) 'interval_count': d.intervalCount,
    if (custom) 'interval_unit': ?d.intervalUnit?.json,
    'start_date': d.startDate,
    'next_renewal_date': ?d.nextRenewalDate,
    'trial_ends_on': ?d.trialEndsOn,
    'payment_account_id': ?d.paymentAccountId,
    'category_id': ?d.categoryId,
    'group_id': ?d.groupId,
    'cancellation_url': ?text(d.cancellationUrl),
    'cancellation_instructions': ?text(d.cancellationInstructions),
    'cancellation_checklist': <Map<String, Object?>>[
      for (final CancellationChecklistItem c in d.cancellationChecklist)
        c.toJson(),
    ],
    'notes': ?text(d.notes),
    'reminder_days_before': d.reminderDaysBefore,
    if (d.status == SubscriptionDetailStatus.cancelled)
      'cancelled_on': ?d.cancelledOn,
  };
}

/// Subscription fields cleared with an empty string (`SubscriptionPatch`):
/// an empty `next_renewal_date` asks the server to work it out again.
const Set<String> subscriptionPatchTextFields = <String>{
  'plan_name',
  'merchant_name',
  'cancellation_url',
  'cancellation_instructions',
  'notes',
  'trial_ends_on',
  'next_renewal_date',
};

/// The partial `PATCH /subscriptions/{id}` body turning [original] into
/// [edited] (request JSON as the form sends it): only changed fields,
/// emptied text with `""`, emptied links in `clear`, the billing cycle as
/// a whole, the price with a new currency, and the version shown.
SubscriptionPatch subscriptionPatchFor(
  SubscriptionDetail original,
  Map<String, Object?> edited,
) => SubscriptionPatch.fromJson(
  partialPatch(
    before: subscriptionFormJson(original),
    after: <String, Object?>{...edited, 'version': original.version},
    clearable: <String>{
      for (final SubscriptionPatchClearItem c
          in SubscriptionPatchClearItem.values)
        if (c != SubscriptionPatchClearItem.unrecognized) c.json,
    },
    textFields: subscriptionPatchTextFields,
    together: <Set<String>>[
      <String>{'billing_frequency', 'interval_count', 'interval_unit'},
      <String>{'currency', 'amount'},
    ],
  ),
);

/// How closely a possible subscription matches a regular charge.
enum DetectionStrength {
  /// 85% or more.
  strong,

  /// 70% or more.
  likely,

  /// Below 70% (the server lists matches from 60%).
  possible,
}

/// The server's confidence (`confidence_bp`, 0–10000) as a strength and a
/// whole percentage.
({DetectionStrength strength, int percent}) detectionConfidence(
  int confidenceBp,
) {
  final int bp = confidenceBp.clamp(0, 10000);
  return (
    strength: bp >= 8500
        ? DetectionStrength.strong
        : bp >= 7000
        ? DetectionStrength.likely
        : DetectionStrength.possible,
    percent: (bp / 100).round(),
  );
}

/// The evidence of a possible subscription in plain words, from its stable
/// `reason_codes` (an unknown code shows the English reason at the same
/// position).
List<String> detectionEvidenceLines(
  AppLocalizations l10n,
  DetectionEvidence e,
) {
  final List<String> english = e.reasons;
  final int bp = e.amountToleranceBp;
  final String tolerance = bp % 100 == 0
      ? '${bp ~/ 100}'
      : (bp / 100).toStringAsFixed(1);
  return <String>[
    for (int i = 0; i < e.reasonCodes.length; i++)
      switch (e.reasonCodes[i]) {
        DetectionEvidenceReasonCodesItem.chargeCadence =>
          l10n.detectionEvidenceCharges(e.chargeCount, e.medianIntervalDays),
        DetectionEvidenceReasonCodesItem.intervalsFitCadence =>
          l10n.detectionReasonIntervals(
            e.intervalsInCycle,
            e.intervalsDays.length,
          ),
        DetectionEvidenceReasonCodesItem.amountsWithinTolerance =>
          l10n.detectionReasonAmounts(
            e.amountsWithinTolerance,
            e.chargeCount,
            tolerance,
          ),
        DetectionEvidenceReasonCodesItem.unrecognized =>
          i < english.length ? english[i] : '',
      },
  ].where((String line) => line.isNotEmpty).toList();
}

/// "Strong match (92%)".
String detectionStrengthText(
  AppLocalizations l10n,
  DetectionStrength strength,
  int percent,
) => switch (strength) {
  DetectionStrength.strong => l10n.detectionStrong(percent),
  DetectionStrength.likely => l10n.detectionLikely(percent),
  DetectionStrength.possible => l10n.detectionPossible(percent),
};
