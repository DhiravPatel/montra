import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_export.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';

import 'finance_fakes.dart';
import 'people_fakes.dart';

// Fixtures in the shapes the live API returned (Goa trip, three members).

class MockGroupMoneyApi extends Mock implements GroupMoneyApi {}

/// The signed-in user (`userJson()`).
const String me = '7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11';

/// Other members.
const String ravi = 'u-ravi';
const String meera = 'u-meera';
const String former = 'u-old';

/// The group.
const String gid = 'grp-goa';

/// Registers fallback values for `any()`.
void registerGroupMoneyFallbacks() {
  registerFinanceFallbacks();
  registerFallbackValue(
    const GroupExpenseInput(
      description: 'x',
      participants: <ExpenseParticipantInput>[],
    ),
  );
  registerFallbackValue(
    const SettlementInput(payerUserId: 'a', payeeUserId: 'b', amount: '1'),
  );
  registerFallbackValue(
    const GroupRecurringInput(
      name: 'x',
      amount: '1',
      frequency: GroupRecurringInputFrequency.monthly,
      startDate: '2026-11-01',
      participants: <ExpenseParticipantInput>[],
    ),
  );
  registerFallbackValue(
    const GroupRecurringUpdate(
      name: 'x',
      amount: '1',
      version: 1,
      participants: <ExpenseParticipantInput>[],
    ),
  );
  registerFallbackValue(const GroupExpenseFilter());
  registerFallbackValue(SettlementAction.confirm);
  registerFallbackValue(GroupRecurringAction.pause);
}

Map<String, Object?> _member(
  String id,
  String name, {
  String role = 'member',
  String status = 'active',
}) => groupMemberJson(id: id, name: name, role: role, status: status);

/// A `GroupDetail` with Asha (the user), Ravi, Meera and a removed member.
GroupDetail goaGroup({
  String myRole = 'owner',
  String status = 'active',
  String split = 'equal',
  bool withFormer = true,
}) => GroupDetail.fromJson(<String, Object?>{
  'id': gid,
  'name': 'Goa trip',
  'group_type': 'trip',
  'base_currency': 'INR',
  'default_split_method': split,
  'allow_member_invites': true,
  'require_join_approval': false,
  'simplify_debts': true,
  'member_count': 3,
  'my_net': moneyJson('7754.43'),
  'my_role': myRole,
  'status': status,
  'timezone': 'Asia/Kolkata',
  'created_at': '2026-11-01T08:00:00Z',
  'version': 1,
  'members': <Object?>[
    _member(me, 'Asha Rao', role: myRole == 'none' ? 'member' : myRole),
    _member(ravi, 'Ravi Kumar'),
    _member(meera, 'Meera Iyer'),
    if (withFormer) _member(former, 'Old Friend', status: 'removed'),
  ],
});

/// An expense (`GroupExpenseDetail` JSON; also decodes as `GroupExpenseDTO`).
Map<String, Object?> expenseJson({
  String id = 'exp-1',
  String description = 'Dinner at the beach shack',
  String amount = '3300.00',
  String split = 'equal',
  String status = 'active',
  String date = '2026-11-02',
  String? category = 'food_dining',
  List<Map<String, Object?>>? shares,
  List<Map<String, Object?>>? payers,
  List<Map<String, Object?>> items = const <Map<String, Object?>>[],
  List<Map<String, Object?>> comments = const <Map<String, Object?>>[],
  List<Map<String, Object?>> disputes = const <Map<String, Object?>>[],
  String? original,
  String? originalCurrency,
  String? fxRate,
  String? fxSource,
  String createdBy = me,
  String? myTransactionId,
  String? receiptFileId,
  int version = 1,
  int revisions = 1,
  String myShare = '1100.00',
  String myPaid = '3300.00',
}) => <String, Object?>{
  'id': id,
  'group_id': gid,
  'description': description,
  'amount': moneyJson(amount),
  'original_amount': ?(original == null
      ? null
      : moneyJson(original, currency: originalCurrency ?? 'USD')),
  'fx_rate': ?fxRate,
  'fx_rate_source': ?fxSource,
  if (fxSource != null) 'fx_rate_at': '2026-11-01T18:30:00Z',
  'category_key': ?category,
  'expense_date': date,
  'split_method': split,
  'payers':
      payers ??
      <Object?>[
        <String, Object?>{'user_id': me, 'paid': moneyJson(amount)},
      ],
  'shares':
      shares ??
      <Object?>[
        <String, Object?>{'user_id': me, 'share': moneyJson('1100.00')},
        <String, Object?>{'user_id': ravi, 'share': moneyJson('1100.00')},
        <String, Object?>{'user_id': meera, 'share': moneyJson('1100.00')},
      ],
  'my_share': moneyJson(myShare),
  'my_paid': moneyJson(myPaid),
  'my_transaction_id': ?myTransactionId,
  'receipt_file_id': ?receiptFileId,
  'status': status,
  'created_by': createdBy,
  'version': version,
  'created_at': '2026-11-12T06:01:35Z',
  'items': items,
  'comments': comments,
  'disputes': disputes,
  'revisions': revisions,
};

/// A `GroupExpenseDetail`.
GroupExpenseDetail expenseDetail({
  String id = 'exp-1',
  String split = 'equal',
  String status = 'active',
  List<Map<String, Object?>>? shares,
  List<Map<String, Object?>>? payers,
  List<Map<String, Object?>> items = const <Map<String, Object?>>[],
  List<Map<String, Object?>> comments = const <Map<String, Object?>>[],
  List<Map<String, Object?>> disputes = const <Map<String, Object?>>[],
  String? original,
  String? originalCurrency,
  String? fxRate,
  String? fxSource,
  String amount = '3300.00',
  String createdBy = me,
  String? myTransactionId,
  String? receiptFileId,
  int version = 1,
  int revisions = 1,
}) => GroupExpenseDetail.fromJson(
  expenseJson(
    id: id,
    split: split,
    status: status,
    shares: shares,
    payers: payers,
    items: items,
    comments: comments,
    disputes: disputes,
    original: original,
    originalCurrency: originalCurrency,
    fxRate: fxRate,
    fxSource: fxSource,
    amount: amount,
    createdBy: createdBy,
    myTransactionId: myTransactionId,
    receiptFileId: receiptFileId,
    version: version,
    revisions: revisions,
  ),
);

/// A list item (`GroupExpenseDTO`).
GroupExpenseDto expenseDto({
  String id = 'exp-1',
  String description = 'Dinner at the beach shack',
  String amount = '3300.00',
  String status = 'active',
  String? original,
}) => GroupExpenseDto.fromJson(
  expenseJson(
    id: id,
    description: description,
    amount: amount,
    status: status,
    original: original,
    fxRate: original == null ? null : '83.5',
    fxSource: original == null ? null : 'manual',
  ),
);

/// One page of expenses.
CursorPage<GroupExpenseDto> expensePage(
  List<GroupExpenseDto> items, {
  String? next,
}) => CursorPage<GroupExpenseDto>(items, next);

Map<String, Object?> _transfer(
  String from,
  String fromName,
  String to,
  String toName,
  String amount,
) => <String, Object?>{
  'from_user_id': from,
  'from_name': fromName,
  'to_user_id': to,
  'to_name': toName,
  'amount': moneyJson(amount),
  'involves_me': from == me || to == me,
};

Map<String, Object?> _balance(
  String id,
  String name,
  String net, {
  String status = 'active',
}) => <String, Object?>{
  'user_id': id,
  'display_name': name,
  'member_status': status,
  'paid': moneyJson('6500.00'),
  'share': moneyJson('7789.60'),
  'settlements_sent': moneyJson('500.00'),
  'settlements_received': moneyJson('0.00'),
  'net': moneyJson(net),
  'pending_out': moneyJson('0.00'),
  'pending_in': moneyJson('200.00'),
};

/// `GET /groups/{id}/balances` (live shape).
GroupBalancesDto balances({bool settled = false, int disputed = 0}) =>
    GroupBalancesDto.fromJson(<String, Object?>{
      'group_id': gid,
      'currency': 'INR',
      'balances': <Object?>[
        _balance(meera, 'Meera Iyer', settled ? '0.00' : '-6964.83'),
        _balance(ravi, 'Ravi Kumar', settled ? '0.00' : '-789.60'),
        _balance(me, 'Asha Rao', settled ? '0.00' : '7754.43'),
        _balance(former, 'Old Friend', '0.00', status: 'removed'),
      ],
      'my_net': moneyJson(settled ? '0.00' : '7754.43'),
      'original_debts': settled
          ? <Object?>[]
          : <Object?>[
              _transfer(meera, 'Meera Iyer', ravi, 'Ravi Kumar', '1867.00'),
              _transfer(meera, 'Meera Iyer', me, 'Asha Rao', '5097.83'),
              _transfer(ravi, 'Ravi Kumar', me, 'Asha Rao', '2656.60'),
            ],
      'simplified': settled
          ? <Object?>[]
          : <Object?>[
              _transfer(meera, 'Meera Iyer', me, 'Asha Rao', '6964.83'),
              _transfer(ravi, 'Ravi Kumar', me, 'Asha Rao', '789.60'),
            ],
      'simplify_enabled': true,
      'disputed_expenses': disputed,
      'computed_at': '2026-11-12T06:01:40Z',
    });

/// `GET /groups/{id}/settlement-suggestions`.
GroupSuggestionsDto suggestions({bool empty = false}) =>
    GroupSuggestionsDto.fromJson(<String, Object?>{
      'mode': 'simplified',
      'currency': 'INR',
      'note':
          'Suggestions only. Montra does not move money; record a settlement '
          'after you pay off-app.',
      'suggestions': empty
          ? <Object?>[]
          : <Object?>[
              _transfer(meera, 'Meera Iyer', me, 'Asha Rao', '6964.83'),
              _transfer(ravi, 'Ravi Kumar', me, 'Asha Rao', '789.60'),
            ],
    });

/// A `SettlementDTO` (live shape).
SettlementDto settlement({
  String id = 'st-1',
  String payer = ravi,
  String payee = me,
  String amount = '500.00',
  String status = 'user_reported_paid',
  String method = 'upi',
  String? myTransactionId,
  String? correctsId,
  String? correctedById,
  String? proposedBy,
  int version = 1,
}) => SettlementDto.fromJson(<String, Object?>{
  'id': id,
  'group_id': gid,
  'payer_user_id': payer,
  'payer_name': payer == me ? 'Asha Rao' : 'Ravi Kumar',
  'payee_user_id': payee,
  'payee_name': payee == me ? 'Asha Rao' : 'Someone',
  'amount': moneyJson(amount),
  'method': method,
  'status': status,
  'verification': 'user_reported',
  'proposed_by': proposedBy ?? payer,
  if (status == 'confirmed') 'confirmed_by': payee,
  if (status == 'confirmed') 'confirmed_at': '2026-11-12T06:01:36Z',
  if (status == 'voided') 'void_reason': 'Recorded twice',
  if (status == 'voided') 'voided_by': payee,
  if (status == 'voided') 'voided_at': '2026-11-12T06:01:36Z',
  if (status == 'disputed') 'dispute_reason': 'I never received it',
  'note': 'Part of the dinner',
  'settled_on': '2026-11-05',
  'my_transaction_id': ?myTransactionId,
  'corrects_settlement_id': ?correctsId,
  'corrected_by_settlement_id': ?correctedById,
  'counted': status == 'confirmed',
  'version': version,
  'created_at': '2026-11-12T06:01:36Z',
});

/// A recurring shared expense with open and handled occurrences.
GroupRecurringDto recurring({
  String id = 'rule-1',
  String status = 'active',
  bool autoAdd = false,
  String createdBy = me,
  int version = 1,
  String split = 'equal',
  List<Map<String, Object?>>? participants,
}) => GroupRecurringDto.fromJson(<String, Object?>{
  'rule': <String, Object?>{
    'id': id,
    'kind': 'group_expense',
    'name': 'Villa cleaning',
    'frequency': 'daily',
    'interval_count': 1,
    'start_date': '2026-11-01',
    'end_date': '2026-11-20',
    'timezone': 'Asia/Kolkata',
    'local_time': '09:00',
    'amount': moneyJson('600.00'),
    'currency': 'INR',
    'amount_is_variable': false,
    'auto_post': autoAdd,
    'reminder_days_before': <int>[0],
    'status': status,
    'completed_count': 1,
    'owned': createdBy == me,
    'group_id': gid,
    'next_occurrence': '2026-11-13',
    'version': version,
    'created_at': '2026-11-12T06:01:36Z',
  },
  'created_by': createdBy,
  'auto_add': autoAdd,
  'template': <String, Object?>{
    'category_key': 'housing_rent',
    'split_method': split,
    'participants':
        participants ??
        <Object?>[
          <String, Object?>{'user_id': me},
          <String, Object?>{'user_id': ravi},
          <String, Object?>{'user_id': meera},
        ],
  },
  'occurrences': <Object?>[
    _occurrence('occ-3', '2026-11-13', 'scheduled'),
    _occurrence('occ-2', '2026-11-02', 'skipped'),
    _occurrence('occ-1', '2026-11-01', 'posted', expenseId: 'exp-9'),
  ],
});

Map<String, Object?> _occurrence(
  String id,
  String date,
  String status, {
  String? expenseId,
}) => <String, Object?>{
  'id': id,
  'rule_id': 'rule-1',
  'rule_name': 'Villa cleaning',
  'kind': 'group_expense',
  'occurrence_date': date,
  'effective_date': date,
  'due_at': '${date}T03:30:00Z',
  'status': status,
  'amount': moneyJson('600.00'),
  'group_id': gid,
  'group_expense_id': ?expenseId,
};

/// `GET /groups/{id}/reports` (live shape).
GroupReportDto groupReport({bool empty = false}) =>
    GroupReportDto.fromJson(<String, Object?>{
      'group_id': gid,
      'group_type': 'trip',
      'currency': 'INR',
      'total_spent': moneyJson(empty ? '0.00' : '23541.38'),
      'expense_count': empty ? 0 : 7,
      'disputed_count': empty ? 0 : 1,
      'participant_count': empty ? 0 : 3,
      'per_person_average': moneyJson(empty ? '0.00' : '7847.13'),
      'my_paid': moneyJson('17041.38'),
      'my_share': moneyJson('8786.95'),
      'by_category': empty
          ? <Object?>[]
          : <Object?>[
              <String, Object?>{
                'category_key': 'housing_rent',
                'total': moneyJson('12600.00'),
                'count': 2,
              },
              <String, Object?>{
                'category_key': 'uncategorized',
                'total': moneyJson('5641.38'),
                'count': 2,
              },
            ],
      'by_member': empty
          ? <Object?>[]
          : <Object?>[
              <String, Object?>{
                'user_id': me,
                'display_name': 'Asha Rao',
                'paid': moneyJson('17041.38'),
                'share': moneyJson('8786.95'),
              },
            ],
      'by_month': empty
          ? <Object?>[]
          : <Object?>[
              <String, Object?>{
                'month': '2026-11',
                'total': moneyJson('23541.38'),
                'count': 7,
              },
            ],
      'original_currencies': empty
          ? <Object?>[]
          : <Object?>[
              <String, Object?>{
                'currency': 'USD',
                'original': moneyJson('40.00', currency: 'USD'),
                'converted': moneyJson('3340.00'),
                'count': 1,
              },
            ],
      'settlements': <String, Object?>{
        'confirmed': moneyJson('500.00'),
        'pending': moneyJson('0.00'),
        'disputed': 0,
        'count': 1,
      },
      'balances': balances().toJson(),
      'trip': <String, Object?>{
        'start_date': '2026-11-01',
        'end_date': '2026-11-05',
        'destination': 'Goa',
        'days': 5,
        'daily_average': moneyJson('4708.28'),
      },
    });

/// The CSV export (with the server's byte order mark).
const GroupExport groupExport = GroupExport(
  csv:
      '\ufeffrecord,date,description,category,amount,currency\n'
      'expense,2026-11-02,Dinner,food_dining,3300.00,INR\n'
      'settlement,2026-11-05,,,500.00,INR\n',
  fileName: 'goa-trip-expenses-2026-11-12.csv',
);

/// Stubs reads used by most screens.
void stubGroupMoney(
  MockGroupMoneyApi api,
  MockPeopleApi people,
  MockAccountsApi accounts, {
  GroupDetail? group,
}) {
  when(() => people.group(any())).thenAnswer((_) async => group ?? goaGroup());
  stubPeople(people);
  when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
      .thenAnswer((_) async => <AccountDto>[account()]);
  when(
    () => api.expenses(
      any(),
      filter: any(named: 'filter'),
      cursor: any(named: 'cursor'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => expensePage(<GroupExpenseDto>[expenseDto()]));
  when(() => api.expense(any(), any()))
      .thenAnswer((_) async => expenseDetail());
  when(() => api.balances(any())).thenAnswer((_) async => balances());
  when(() => api.suggestions(any(), mine: any(named: 'mine')))
      .thenAnswer((_) async => suggestions());
  when(() => api.settlements(any(), includeVoided: any(named: 'includeVoided')))
      .thenAnswer((_) async => <SettlementDto>[settlement()]);
  when(() => api.settlement(any(), any()))
      .thenAnswer((_) async => settlement());
  when(() => api.recurring(any()))
      .thenAnswer((_) async => <GroupRecurringDto>[recurring()]);
  when(() => api.recurringRule(any(), any()))
      .thenAnswer((_) async => recurring());
  when(
    () => api.report(
      any(),
      from: any(named: 'from'),
      to: any(named: 'to'),
    ),
  ).thenAnswer((_) async => groupReport());
  when(() => api.export(any())).thenAnswer((_) async => groupExport);
}

/// Provider overrides for the group money screens.
List<Override> groupMoneyOverrides(
  MockGroupMoneyApi api,
  MockPeopleApi people,
  MockAccountsApi accounts,
) => <Override>[
  groupMoneyApiProvider.overrideWithValue(api),
  peopleApiProvider.overrideWithValue(people),
  accountsApiProvider.overrideWithValue(accounts),
];

/// Drags the page's main scroll view until [finder] is on screen (every
/// child of these pages is built, so it can be measured anywhere).
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  final double height =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (int i = 0; i < 40; i++) {
    final Rect r = tester.getRect(finder.first);
    if (r.top >= 80 && r.bottom <= height - 24) {
      return;
    }
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, r.top < 80 ? 250 : -250),
    );
    await tester.pumpAndSettle();
  }
}
