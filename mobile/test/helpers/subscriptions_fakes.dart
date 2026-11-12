import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';

import 'finance_fakes.dart';

class MockSubscriptionsApi extends Mock implements SubscriptionsApi {}

/// Registers fallback values for subscription `any()` matchers.
void registerSubscriptionFallbacks() {
  registerFallbackValue(
    const SubscriptionInput(
      amount: '1',
      billingFrequency: SubscriptionInputBillingFrequency.monthly,
      name: 'x',
      startDate: '2026-01-01',
    ),
  );
  registerFallbackValue(const SubscriptionPaymentInput(transactionId: 'x'));
  registerFallbackValue(const SubscriptionPatch());
  registerFallbackValue(const ChecklistItemPatch());
  registerFallbackValue(const SubscriptionActionInput());
  registerFallbackValue(const DetectionConfirmInput());
  registerFallbackValue(SubscriptionAction.verify);
}

/// A `SubscriptionDTO` (or, with [events], `SubscriptionDetail`) as JSON.
Map<String, Object?> subscriptionJson({
  String id = 'sub-1',
  String name = 'Streamly',
  String? plan = 'Premium',
  String amount = '499.00',
  String currency = 'INR',
  String frequency = 'monthly',
  int intervalCount = 1,
  String? intervalUnit,
  String status = 'active',
  String source = 'manual',
  String startDate = '2026-09-10',
  String? nextRenewal = '2026-11-10',
  String? trialEndsOn,
  String monthly = '499.00',
  String annual = '5988.00',
  bool owned = true,
  int version = 3,
  String? merchant = 'Streamly Media',
  String? categoryId,
  String? accountId,
  String? groupId,
  String? invoiceFileId,
  String? url,
  String? instructions,
  List<Map<String, Object?>> checklist = const <Map<String, Object?>>[],
  List<int> reminders = const <int>[1, 3],
  List<Map<String, Object?>> duplicates = const <Map<String, Object?>>[],
  Map<String, Object?>? lastPayment,
  String? notes,
  DateTime? lastVerifiedAt,
  String? cancelledOn,
  List<Map<String, Object?>>? events,
  List<Map<String, Object?>>? payments,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'plan_name': ?plan,
  if (merchant != null)
    'merchant': <String, Object?>{'id': 'mer-$id', 'name': merchant},
  'amount': moneyJson(amount, currency: currency),
  'billing_frequency': frequency,
  'interval_count': intervalCount,
  'interval_unit': ?intervalUnit,
  'start_date': startDate,
  'next_renewal_date': ?nextRenewal,
  'trial_ends_on': ?trialEndsOn,
  'status': status,
  'source': source,
  'category_id': ?categoryId,
  'payment_account_id': ?accountId,
  'group_id': ?groupId,
  'invoice_file_id': ?invoiceFileId,
  'cancellation_url': ?url,
  'cancellation_instructions': ?instructions,
  'cancellation_checklist': checklist,
  'reminder_days_before': reminders,
  'monthly_cost': moneyJson(monthly, currency: currency),
  'annual_cost': moneyJson(annual, currency: currency),
  'duplicate_warnings': duplicates,
  'last_payment': ?lastPayment,
  'last_verified_at': ?lastVerifiedAt?.toIso8601String(),
  'cancelled_on': ?cancelledOn,
  'notes': ?notes,
  'owned': owned,
  'version': version,
  'created_at': '2026-09-10T08:00:00Z',
  'events': ?events,
  if (events != null) 'payments': payments ?? <Map<String, Object?>>[],
};

/// A `SubscriptionDTO`.
SubscriptionDto subscriptionDto({
  String id = 'sub-1',
  String name = 'Streamly',
  String status = 'active',
  String amount = '499.00',
  String currency = 'INR',
  String? nextRenewal = '2026-11-10',
  String? trialEndsOn,
  bool owned = true,
}) => SubscriptionDto.fromJson(
  subscriptionJson(
    id: id,
    name: name,
    status: status,
    amount: amount,
    currency: currency,
    nextRenewal: nextRenewal,
    trialEndsOn: trialEndsOn,
    owned: owned,
  ),
);

/// A subscription history entry as JSON.
Map<String, Object?> subscriptionEventJson({
  required String id,
  required String kind,
  String occurredOn = '2026-11-01',
  String? oldAmount,
  String? newAmount,
  String? transactionId,
  String? note,
  String? noteCode,
}) => <String, Object?>{
  'id': id,
  'kind': kind,
  'occurred_on': occurredOn,
  'created_at': '${occurredOn}T08:00:00Z',
  if (oldAmount != null) 'old_amount': moneyJson(oldAmount),
  if (newAmount != null) 'new_amount': moneyJson(newAmount),
  'transaction_id': ?transactionId,
  'note': ?note,
  'note_code': ?noteCode,
};

/// A `DuplicateWarning` as JSON.
Map<String, Object?> duplicateWarningJson({
  String subscriptionId = 'sub-2',
  String name = 'Streamly Family',
  String reasonCode = 'same_merchant',
  String reason = 'Same merchant',
}) => <String, Object?>{
  'subscription_id': subscriptionId,
  'name': name,
  'reason': reason,
  'reason_code': reasonCode,
  'reason_params': <String, String>{'name': name},
};

/// A `SubscriptionPaymentCandidate`.
SubscriptionPaymentCandidate subscriptionCandidate({
  String transactionId = 'tx-sub-1',
  String? merchant = 'Streamly Media',
  String amount = '499.00',
  String date = '2026-11-09',
  List<String> reasonCodes = const <String>[
    'same_merchant',
    'same_amount',
    'near_renewal_date',
  ],
  int? daysFromRenewal = -1,
  String? expectedDate = '2026-11-10',
}) => SubscriptionPaymentCandidate.fromJson(<String, Object?>{
  'transaction_id': transactionId,
  'merchant': ?merchant,
  'description': 'STREAMLY*PREMIUM',
  'account_name': 'HDFC Savings',
  'local_date': date,
  'amount': moneyJson(amount),
  'reason_codes': reasonCodes,
  'reasons': <String>[for (final String c in reasonCodes) 'English $c'],
  'days_from_renewal': ?daysFromRenewal,
  'expected_date': ?expectedDate,
});

/// A `SubscriptionDetail`; [json] overrides fields of [subscriptionJson].
SubscriptionDetail subscriptionDetail({
  Map<String, Object?> json = const <String, Object?>{},
  List<Map<String, Object?>> events = const <Map<String, Object?>>[],
  List<Map<String, Object?>> payments = const <Map<String, Object?>>[],
}) => SubscriptionDetail.fromJson(<String, Object?>{
  ...subscriptionJson(events: events, payments: payments),
  ...json,
});

/// A `LinkedPayment` as JSON.
Map<String, Object?> linkedPaymentJson({
  String transactionId = 'tx-9',
  String amount = '499.00',
  String date = '2026-10-10',
  String? accountName = 'HDFC Savings',
}) => <String, Object?>{
  'transaction_id': transactionId,
  'amount': moneyJson(amount),
  'local_date': date,
  'account_name': ?accountName,
  'linked_at': '${date}T10:00:00Z',
};

/// A `SubscriptionSummary`.
SubscriptionSummary subscriptionSummary({
  List<Map<String, Object?>> totals = const <Map<String, Object?>>[],
  List<Map<String, Object?>> renewals = const <Map<String, Object?>>[],
  List<Map<String, Object?>> trials = const <Map<String, Object?>>[],
  int pending = 0,
}) => SubscriptionSummary.fromJson(<String, Object?>{
  'totals': totals,
  'upcoming_renewals': renewals,
  'trials_ending_soon': trials,
  'pending_detections': pending,
});

/// A per-currency total as JSON.
Map<String, Object?> costTotalJson({
  String currency = 'INR',
  String monthly = '2215.79',
  String annual = '26589.50',
  int count = 3,
}) => <String, Object?>{
  'currency': currency,
  'monthly': moneyJson(monthly, currency: currency),
  'annual': moneyJson(annual, currency: currency),
  'count': count,
};

/// A `DetectionCandidateDTO`.
DetectionCandidateDto detectionCandidate({
  String id = 'det-1',
  String label = 'Cloudbox Storage',
  String amount = '129.00',
  String tolerance = '6.45',
  String cadence = 'monthly',
  int confidenceBp = 9200,
  String? merchantId = 'mer-cloud',
  String? next = '2026-12-04',
  int charges = 6,
  int median = 30,
  List<String> reasonCodes = const <String>[
    'charge_cadence',
    'intervals_fit_cadence',
    'amounts_within_tolerance',
  ],
}) => DetectionCandidateDto.fromJson(<String, Object?>{
  'id': id,
  'merchant_label': label,
  'merchant_id': ?merchantId,
  'amount': moneyJson(amount),
  'amount_tolerance': moneyJson(tolerance),
  'cadence': cadence,
  'confidence': (confidenceBp / 10000).toStringAsFixed(3),
  'confidence_bp': confidenceBp,
  'status': 'pending',
  'next_expected_date': ?next,
  'evidence_transaction_ids': <String>['tx-a', 'tx-b'],
  'evidence': <String, Object?>{
    'amounts_minor': <int>[12900, 12900],
    'charge_count': charges,
    'intervals_days': <int>[30, 31, 30, 30, 31],
    'intervals_in_cycle': 5,
    'amounts_within_tolerance': charges,
    'amount_tolerance_bp': 500,
    'last_charge_date': '2026-11-04',
    'median_interval_days': median,
    'reason_codes': reasonCodes,
    'reasons': <String>[
      for (final String c in reasonCodes) 'English evidence $c',
    ],
  },
  'created_at': '2026-11-05T06:00:00Z',
});
