import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/calendar/data/calendar_api.dart';
import 'package:montra_mobile/features/recurring/data/recurring_api.dart';

import 'finance_fakes.dart';

class MockRecurringApi extends Mock implements RecurringApi {}

class MockBillsApi extends Mock implements BillsApi {}

class MockCalendarApi extends Mock implements CalendarApi {}

/// Registers fallback values for `any()` matchers (finance ones included).
void registerPlanningFallbacks() {
  registerFinanceFallbacks();
  registerFallbackValue(
    const RecurringRuleInput(
      frequency: RecurringRuleInputFrequency.monthly,
      kind: RecurringRuleInputKind.expense,
      name: 'x',
      startDate: '2026-11-05',
    ),
  );
  registerFallbackValue(
    const OccurrenceAction(action: OccurrenceActionAction.skip),
  );
  registerFallbackValue(
    const BillInput(
      frequency: BillInputFrequency.monthly,
      name: 'x',
      startDate: '2026-11-05',
    ),
  );
  registerFallbackValue(const BillPatch(version: 1));
  registerFallbackValue(const RecurringRulePatch(version: 1));
  registerFallbackValue(const MarkPaidInput());
  registerFallbackValue(BillAction.pause);
}

/// An `OccurrenceDTO` JSON object.
Map<String, Object?> occurrenceJson({
  String id = 'occ-1',
  String ruleId = 'rule-1',
  String ruleName = 'Rent',
  String kind = 'expense',
  String date = '2026-12-05',
  String? effectiveDate,
  String status = 'scheduled',
  String? amount = '15000.00',
  String currency = 'INR',
  String? transactionId,
  String? billId,
}) => <String, Object?>{
  'id': id,
  'rule_id': ruleId,
  'rule_name': ruleName,
  'kind': kind,
  'occurrence_date': date,
  'effective_date': effectiveDate ?? date,
  if (effectiveDate != null && effectiveDate != date)
    'postponed_to': effectiveDate,
  'due_at': '${effectiveDate ?? date}T03:30:00Z',
  'status': status,
  if (amount != null) 'amount': moneyJson(amount, currency: currency),
  'transaction_id': ?transactionId,
  'bill_id': ?billId,
};

/// An `OccurrenceDTO`.
OccurrenceDto occurrence({
  String id = 'occ-1',
  String date = '2026-12-05',
  String status = 'scheduled',
  String? amount = '15000.00',
  String? transactionId,
}) => OccurrenceDto.fromJson(
  occurrenceJson(
    id: id,
    date: date,
    status: status,
    amount: amount,
    transactionId: transactionId,
  ),
);

/// A `RecurringRuleDTO` JSON object.
Map<String, Object?> ruleJson({
  String id = 'rule-1',
  String name = 'Rent',
  String kind = 'expense',
  String status = 'active',
  String frequency = 'monthly',
  int intervalCount = 1,
  String? intervalUnit,
  int? byMonthDay = 5,
  int? byWeekday,
  int? byWeekOfMonth,
  String? amount = '15000.00',
  String currency = 'INR',
  bool variable = false,
  String? accountId = 'acc-1',
  String? toAccountId,
  String? categoryId,
  String? merchantId,
  String? merchantName,
  String? billId,
  bool autoPost = false,
  String startDate = '2026-11-05',
  String? endDate,
  int? maxOccurrences,
  String? nextOccurrence = '2026-12-05',
  int version = 1,
  bool owned = true,
  List<int> reminders = const <int>[1],
  int completed = 0,
  String? description,
  String? notes,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'kind': kind,
  'status': status,
  'frequency': frequency,
  'interval_count': intervalCount,
  'interval_unit': ?intervalUnit,
  'by_month_day': ?byMonthDay,
  'by_weekday': ?byWeekday,
  'by_week_of_month': ?byWeekOfMonth,
  if (amount != null) 'amount': moneyJson(amount, currency: currency),
  'currency': currency,
  'amount_is_variable': variable,
  'account_id': ?accountId,
  'to_account_id': ?toAccountId,
  'category_id': ?categoryId,
  'merchant_id': ?merchantId,
  if (merchantId != null && merchantName != null)
    'merchant': <String, Object?>{'id': merchantId, 'name': merchantName},
  'bill_id': ?billId,
  'auto_post': autoPost,
  'start_date': startDate,
  'end_date': ?endDate,
  'max_occurrences': ?maxOccurrences,
  'next_occurrence': ?nextOccurrence,
  'local_time': '09:00',
  'timezone': 'Asia/Kolkata',
  'reminder_days_before': reminders,
  'completed_count': completed,
  'owned': owned,
  'version': version,
  'description': ?description,
  'notes': ?notes,
  'created_at': '2026-11-01T08:00:00Z',
};

/// A `RecurringRuleDTO`.
RecurringRuleDto rule({
  String id = 'rule-1',
  String name = 'Rent',
  String kind = 'expense',
  String status = 'active',
  String frequency = 'monthly',
  int? byMonthDay = 5,
  String? amount = '15000.00',
  bool variable = false,
  String? nextOccurrence = '2026-12-05',
}) => RecurringRuleDto.fromJson(
  ruleJson(
    id: id,
    name: name,
    kind: kind,
    status: status,
    frequency: frequency,
    byMonthDay: byMonthDay,
    amount: amount,
    variable: variable,
    nextOccurrence: nextOccurrence,
  ),
);

/// A `RecurringRuleDetail` with [occurrences] (JSON from [occurrenceJson]).
RecurringRuleDetail ruleDetail({
  String id = 'rule-1',
  String name = 'Rent',
  String kind = 'expense',
  String status = 'active',
  String? amount = '15000.00',
  bool variable = false,
  String? accountId = 'acc-1',
  String? merchantId,
  String? merchantName,
  String? billId,
  String frequency = 'monthly',
  String? intervalUnit,
  String? description,
  bool autoPost = false,
  bool owned = true,
  int version = 1,
  int completed = 0,
  List<Map<String, Object?>> occurrences = const <Map<String, Object?>>[],
}) => RecurringRuleDetail.fromJson(<String, Object?>{
  ...ruleJson(
    id: id,
    name: name,
    kind: kind,
    status: status,
    frequency: frequency,
    intervalUnit: intervalUnit,
    amount: amount,
    variable: variable,
    accountId: accountId,
    merchantId: merchantId,
    merchantName: merchantName,
    billId: billId,
    description: description,
    autoPost: autoPost,
    owned: owned,
    version: version,
    completed: completed,
  ),
  'occurrences': occurrences,
});

/// A `BillDTO` JSON object (with its schedule).
Map<String, Object?> billJson({
  String id = 'bill-1',
  String name = 'Electricity',
  String? provider = 'BESCOM',
  String state = 'upcoming',
  String status = 'active',
  String? expected = '1800.00',
  bool variable = false,
  String? paymentAccountId = 'acc-1',
  String? categoryId,
  Map<String, Object?>? nextDue,
  Map<String, Object?>? lastPaid,
  int version = 1,
  bool owned = true,
  List<int> reminders = const <int>[3],
  String? notes,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'provider_name': ?provider,
  'state': state,
  'status': status,
  'currency': 'INR',
  if (expected != null) 'expected_amount': moneyJson(expected),
  'amount_is_variable': variable,
  'payment_account_id': ?paymentAccountId,
  'category_id': ?categoryId,
  'next_due': ?nextDue,
  'last_paid': ?lastPaid,
  'owned': owned,
  'version': version,
  'notes': ?notes,
  'created_at': '2026-11-01T08:00:00Z',
  'schedule': ruleJson(
    id: 'sched-$id',
    name: name,
    kind: 'bill',
    billId: id,
    byMonthDay: 10,
    amount: expected,
    variable: variable,
    accountId: paymentAccountId,
    startDate: '2026-10-10',
    nextOccurrence: '2026-11-10',
    reminders: reminders,
  ),
};

/// A bill occurrence JSON object.
Map<String, Object?> billOccurrenceJson({
  String id = 'bocc-1',
  String date = '2026-11-10',
  String status = 'scheduled',
  String? amount = '1800.00',
  String? transactionId,
}) => occurrenceJson(
  id: id,
  ruleId: 'sched-bill-1',
  ruleName: 'Electricity',
  kind: 'bill',
  date: date,
  status: status,
  amount: amount,
  transactionId: transactionId,
  billId: 'bill-1',
);

/// A `BillDTO`.
BillDto bill({
  String id = 'bill-1',
  String name = 'Electricity',
  String state = 'upcoming',
  String status = 'active',
  String? expected = '1800.00',
  bool variable = false,
  Map<String, Object?>? nextDue,
  Map<String, Object?>? lastPaid,
}) => BillDto.fromJson(
  billJson(
    id: id,
    name: name,
    state: state,
    status: status,
    expected: expected,
    variable: variable,
    nextDue: nextDue,
    lastPaid: lastPaid,
  ),
);

/// A `BillDetail` with [occurrences].
BillDetail billDetail({
  String state = 'upcoming',
  String status = 'active',
  String? expected = '1800.00',
  bool variable = false,
  String? paymentAccountId = 'acc-1',
  Map<String, Object?>? nextDue,
  Map<String, Object?>? lastPaid,
  int version = 1,
  bool owned = true,
  String? notes,
  List<Map<String, Object?>> occurrences = const <Map<String, Object?>>[],
}) => BillDetail.fromJson(<String, Object?>{
  ...billJson(
    state: state,
    status: status,
    expected: expected,
    variable: variable,
    paymentAccountId: paymentAccountId,
    nextDue: nextDue,
    lastPaid: lastPaid,
    version: version,
    owned: owned,
    notes: notes,
  ),
  'occurrences': occurrences,
});

/// A `BillPaymentCandidate`.
BillPaymentCandidate candidate({
  String transactionId = 'tx-9',
  String? merchant = 'BESCOM',
  String amount = '1800.00',
  String date = '2026-11-08',
  List<String> reasonCodes = const <String>['same_provider', 'near_due_date'],
  List<String> reasons = const <String>['Same provider', 'Near the due date'],
  int daysFromDue = -2,
}) => BillPaymentCandidate.fromJson(<String, Object?>{
  'transaction_id': transactionId,
  'merchant': ?merchant,
  'description': 'Electricity',
  'account_name': 'HDFC Savings',
  'local_date': date,
  'amount': moneyJson(amount),
  'reason_codes': reasonCodes,
  'reasons': reasons,
  'days_from_due': daysFromDue,
});

/// A `CalendarItem`.
CalendarItem calendarItem({
  String date = '2026-11-10',
  String kind = 'bill',
  String entityType = 'bill',
  String entityId = 'bill-1',
  String title = 'Electricity',
  String status = 'scheduled',
  String? amount = '1800.00',
  String? scheduledOn,
}) => CalendarItem.fromJson(<String, Object?>{
  'date': date,
  'scheduled_on': ?scheduledOn,
  if (scheduledOn != null) 'postponed_to': date,
  'kind': kind,
  'entity_type': entityType,
  'entity_id': entityId,
  'title': title,
  'status': status,
  if (amount != null) 'amount': moneyJson(amount),
});
