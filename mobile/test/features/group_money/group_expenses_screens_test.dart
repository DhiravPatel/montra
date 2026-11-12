import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/currency_catalog.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/group_money_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';

const String requiredText = 'This field is required.';

const List<CurrencyDto> _currencies = <CurrencyDto>[
  CurrencyDto(code: 'INR', name: 'Indian Rupee', exponent: 2, selectable: true),
  CurrencyDto(code: 'USD', name: 'US Dollar', exponent: 2, selectable: true),
];

void main() {
  late MockGroupMoneyApi api;
  late MockPeopleApi people;
  late MockAccountsApi accounts;

  setUpAll(registerGroupMoneyFallbacks);

  setUp(() {
    api = MockGroupMoneyApi();
    people = MockPeopleApi();
    accounts = MockAccountsApi();
    stubGroupMoney(api, people, accounts);
  });

  List<Override> overrides() => <Override>[
    ...groupMoneyOverrides(api, people, accounts),
    currencyCatalogProvider.overrideWith(
      (_) async => CurrencyCatalog(_currencies),
    ),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  group('expense list', () {
    testWidgets('shows expenses with what you paid and your share, filters '
        'by status and loads more', (WidgetTester tester) async {
      when(
        () => api.expenses(
          any(),
          filter: any(named: 'filter'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((Invocation i) async {
        final GroupExpenseFilter f =
            i.namedArguments[#filter]! as GroupExpenseFilter;
        if (f.status == 'disputed') {
          return expensePage(<GroupExpenseDto>[
            expenseDto(
              id: 'exp-d',
              description: 'Villa rent',
              status: 'disputed',
            ),
          ]);
        }
        if (i.namedArguments[#cursor] == 'c2') {
          return expensePage(<GroupExpenseDto>[
            expenseDto(
              id: 'exp-2',
              description: 'Boat tour',
              original: '40.00',
            ),
          ]);
        }
        return expensePage(<GroupExpenseDto>[expenseDto()], next: 'c2');
      });
      await pump(tester, '/groups/$gid/expenses');

      expect(find.text('Expenses · Goa trip'), findsOneWidget);
      expect(find.text('Dinner at the beach shack'), findsOneWidget);
      expect(find.text('₹3,300.00'), findsOneWidget);
      expect(
        find.textContaining('You paid ₹3,300.00 · your share ₹1,100.00'),
        findsOneWidget,
      );
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Boat tour'), findsOneWidget);
      expect(find.textContaining(r'Paid in $40.00'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Disputed'));
      await tester.pumpAndSettle();
      expect(find.text('Villa rent'), findsOneWidget);
      expect(find.text('Dinner at the beach shack'), findsNothing);
      expect(find.text('Add expense'), findsOneWidget);
    });

    testWidgets('empty and error states', (WidgetTester tester) async {
      int calls = 0;
      when(
        () => api.expenses(
          any(),
          filter: any(named: 'filter'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return expensePage(<GroupExpenseDto>[]);
      });
      await pump(tester, '/groups/$gid/expenses');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No shared expenses yet'), findsOneWidget);
    });

    testWidgets('an archived group is read-only', (WidgetTester tester) async {
      when(() => people.group(any()))
          .thenAnswer((_) async => goaGroup(status: 'archived'));
      await pump(tester, '/groups/$gid/expenses');
      expect(
        find.text(
          'This group is archived, so nothing can be added or changed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add expense'), findsNothing);
    });

    testWidgets('a group that cannot be loaded shows an error', (
      WidgetTester tester,
    ) async {
      when(() => people.group(any()))
          .thenThrow(serverError(ErrorObjectCode.notFound, status: 404));
      await pump(tester, '/groups/$gid/expenses');
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('expense form', () {
    Future<GroupExpenseInput> submitCreate(WidgetTester tester) async {
      GroupExpenseInput? sent;
      when(() => api.createExpense(any(), any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[1] as GroupExpenseInput;
            return expenseDetail();
          });
      final Finder save = find.widgetWithText(FilledButton, 'Add expense');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
      return sent!;
    }

    testWidgets('adds an equal split between current members (former ones '
        'are not offered) with an idempotency key kept for a retry', (
      WidgetTester tester,
    ) async {
      final List<String> keys = <String>[];
      int calls = 0;
      when(() => api.createExpense(any(), any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            keys.add(i.namedArguments[#key]! as String);
            calls++;
            if (calls == 1) {
              throw offline;
            }
            return expenseDetail();
          });
      final GoRouter router = await pump(tester, '/groups/$gid/expenses/new');
      expect(find.text('Old Friend'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Dinner',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '3000',
      );
      final Finder save = find.widgetWithText(FilledButton, 'Add expense');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Check your internet connection'),
        findsOneWidget,
      );
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(1), reason: 'a retry reuses the key');
      final GroupExpenseInput sent =
          verify(
                () => api.createExpense(
                  gid,
                  captureAny(),
                  key: any(named: 'key'),
                ),
              ).captured.last
              as GroupExpenseInput;
      expect(sent.amount, '3000.00');
      expect(sent.splitMethod, GroupExpenseInputSplitMethod.equal);
      expect(
        sent.participants.map((ExpenseParticipantInput p) => p.userId),
        <String>[me, meera, ravi],
      );
      expect(sent.payers, isNull, reason: 'the caller paid everything');
      expect(locationOf(router), '/groups/$gid/expenses/exp-1');
    });

    testWidgets('exact amounts show a preview of what is left and send each '
        'amount', (WidgetTester tester) async {
      await pump(tester, '/groups/$gid/expenses/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Taxi',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '1200',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Exact amounts'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount for You'),
        '500',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount for Ravi Kumar'),
        '600',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('₹1,100.00 so far, ₹100.00 still to assign.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount for Meera Iyer'),
        '100',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('the amounts add up to the total.'),
        findsOneWidget,
      );
      final GroupExpenseInput sent = await submitCreate(tester);
      expect(sent.splitMethod, GroupExpenseInputSplitMethod.exact);
      expect(
        sent.participants.map((ExpenseParticipantInput p) => p.value),
        <String>['500.00', '100.00', '600.00'],
      );
    });

    testWidgets('percentages and shares send their values', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/groups/$gid/expenses/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Villa',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '12000',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Percentages'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Percentage for You'),
        '33.33',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Percentage for Ravi Kumar'),
        '33.33',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Percentage for Meera Iyer'),
        '33,34',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('the percentages add up to 100%.'),
        findsOneWidget,
      );
      final GroupExpenseInput sent = await submitCreate(tester);
      expect(
        sent.participants.map((ExpenseParticipantInput p) => p.value),
        <String>['33.33', '33.34', '33.33'],
      );
    });

    testWidgets('shares leave out unticked members', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/groups/$gid/expenses/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Scooter',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '900',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Shares'));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.widgetWithText(CheckboxListTile, 'Meera Iyer'),
      );
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Meera Iyer'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Shares for You'),
        '1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Shares for Ravi Kumar'),
        '2',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('3 shares in total.'), findsOneWidget);
      final GroupExpenseInput sent = await submitCreate(tester);
      expect(sent.splitMethod, GroupExpenseInputSplitMethod.shares);
      expect(sent.participants, hasLength(2));
    });

    testWidgets('by item: items with who shared them', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/groups/$gid/expenses/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Supermarket',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '1100',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'By item'));
      await tester.pumpAndSettle();
      final Finder addItem = find.text('Add item');
      await scrollTo(tester, addItem);
      await tester.tap(addItem);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item 1'),
        'Water',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item amount'),
        '600',
      );
      await scrollTo(tester, find.widgetWithText(FilterChip, 'Meera Iyer'));
      await tester.tap(find.widgetWithText(FilterChip, 'Meera Iyer'));
      await tester.pumpAndSettle();
      final GroupExpenseInput sent = await submitCreate(tester);
      expect(sent.splitMethod, GroupExpenseInputSplitMethod.itemized);
      final ExpenseItemInput item = sent.items!.single;
      expect(item.description, 'Water');
      expect(item.amount, '600.00');
      expect(item.sharedBy.map((ExpenseItemShareInput s) => s.userId), <String>[
        me,
        ravi,
      ]);
    });

    testWidgets('several payers with a preview of what is left', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/groups/$gid/expenses/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Villa',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '12000',
      );
      final Finder several = find.widgetWithText(
        ChoiceChip,
        'Several people paid',
      );
      await scrollTo(tester, several);
      await tester.tap(several);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Paid by You (optional)'),
        '7000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Paid by Ravi Kumar (optional)'),
        '5000',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('the payments add up to the total.'),
        findsOneWidget,
      );
      final GroupExpenseInput sent = await submitCreate(tester);
      expect(
        sent.payers!.map((ExpensePayerInput p) => '${p.userId}:${p.amount}'),
        <String>['$me:7000.00', '$ravi:5000.00'],
      );
    });

    testWidgets("another currency with Montra's rate leaves the amount to "
        'the server', (WidgetTester tester) async {
      await pump(tester, '/groups/$gid/expenses/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Boat tour',
      );
      await tester.tap(find.text('Paid in another currency'));
      await tester.pumpAndSettle();
      final Finder save = find.widgetWithText(FilledButton, 'Add expense');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Choose the currency you paid in.'), findsOneWidget);
      await scrollTo(tester, find.text('Currency paid in'));
      await tester.tap(find.text('Currency paid in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD · US Dollar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount paid'),
        '40',
      );
      final GroupExpenseInput sent = await submitCreate(tester);
      expect(sent.amount, isNull);
      expect(sent.originalAmount, '40.00');
      expect(sent.originalCurrency, 'USD');
      expect(sent.fxRateSource, GroupExpenseInputFxRateSource.lookup);
      expect(sent.fxRate, isNull);
    });

    testWidgets('editing an expense in another currency with my own rate '
        'keeps the payers and sends the version', (WidgetTester tester) async {
      when(() => api.expense(any(), any())).thenAnswer(
        (_) async => expenseDetail(
          original: '40.00',
          originalCurrency: 'USD',
          fxRate: '83.5',
          fxSource: 'ecb',
          amount: '3340.00',
          version: 3,
          payers: <Map<String, Object?>>[
            <String, Object?>{'user_id': ravi, 'paid': moneyJson('3340.00')},
          ],
        ),
      );
      GroupExpenseInput? sent;
      when(() => api.updateExpense(any(), any(), any()))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[2] as GroupExpenseInput;
            return expenseDetail();
          });
      await pump(tester, '/groups/$gid/expenses/exp-1/edit');
      expect(find.text('Edit expense'), findsOneWidget);
      await scrollTo(tester, find.text('Enter the rate I used'));
      await tester.tap(find.text('Enter the rate I used'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'USD 1 = ? INR'),
        '84,10',
      );
      final Finder save = find.widgetWithText(FilledButton, 'Save');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(sent!.version, 3);
      expect(sent!.fxRateSource, GroupExpenseInputFxRateSource.manual);
      expect(sent!.fxRate, '84.10');
      expect(sent!.amount, isNull);
      expect(sent!.payers!.single.userId, ravi);
      expect(
        sent!.payers!.single.amount,
        isNull,
        reason: 'the server derives the amount of a foreign-currency expense',
      );
    });

    testWidgets('a change made elsewhere reloads the expense', (
      WidgetTester tester,
    ) async {
      int reads = 0;
      when(() => api.expense(any(), any())).thenAnswer((_) async {
        reads++;
        return expenseDetail(version: reads);
      });
      when(() => api.updateExpense(any(), any(), any()))
          .thenThrow(serverError(ErrorObjectCode.versionConflict, status: 409));
      await pump(tester, '/groups/$gid/expenses/exp-1/edit');
      final Finder save = find.widgetWithText(FilledButton, 'Save');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.textContaining('changed somewhere else'), findsOneWidget);
    });

    testWidgets('coded split errors are explained', (
      WidgetTester tester,
    ) async {
      when(() => api.createExpense(any(), any(), key: any(named: 'key')))
          .thenThrow(
            serverError(
              ErrorObjectCode.domainRuleViolation,
              details: const <Detail>[
                Detail(
                  code: 'split_mismatch',
                  message: 'The split does not add up',
                ),
              ],
            ),
          );
      await pump(tester, '/groups/$gid/expenses/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Dinner',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '100',
      );
      final Finder save = find.widgetWithText(FilledButton, 'Add expense');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.textContaining("The split doesn't add up"));
      expect(find.textContaining("The split doesn't add up"), findsOneWidget);
    });
  });

  group('expense detail', () {
    testWidgets('shows the server split, payers, the rate used and history', (
      WidgetTester tester,
    ) async {
      when(() => api.expense(any(), any())).thenAnswer(
        (_) async => expenseDetail(
          split: 'percentage',
          original: '40.00',
          originalCurrency: 'USD',
          fxRate: '83.5',
          fxSource: 'ecb',
          amount: '3340.00',
          revisions: 2,
          shares: <Map<String, Object?>>[
            <String, Object?>{
              'user_id': me,
              'share': moneyJson('1670.00'),
              'input_value': '50',
            },
            <String, Object?>{
              'user_id': former,
              'share': moneyJson('1670.00'),
              'input_value': '50',
            },
          ],
        ),
      );
      await pump(tester, '/groups/$gid/expenses/exp-1');
      expect(find.text('₹3,340.00'), findsWidgets);
      expect(find.text(r'$40.00'), findsOneWidget);
      expect(find.text('1 USD = 83.5 INR'), findsOneWidget);
      expect(find.text('European Central Bank'), findsOneWidget);
      expect(find.text('Edited once'), findsOneWidget);
      await scrollTo(tester, find.text('Old Friend · 50 %'));
      expect(find.text('You · 50 %'), findsOneWidget);
    });

    testWidgets('comments, disputes and withdrawing my dispute', (
      WidgetTester tester,
    ) async {
      when(() => api.expense(any(), any())).thenAnswer(
        (_) async => expenseDetail(
          status: 'disputed',
          comments: <Map<String, Object?>>[
            <String, Object?>{
              'id': 'c-1',
              'author_id': ravi,
              'body': 'Was this with the tip?',
              'created_at': '2026-11-12T06:01:35Z',
            },
          ],
          disputes: <Map<String, Object?>>[
            <String, Object?>{
              'id': 'd-1',
              'raised_by': me,
              'reason': 'Amount was 3000',
              'status': 'open',
              'created_at': '2026-11-12T06:01:35Z',
            },
          ],
        ),
      );
      when(() => api.comment(any(), any(), any())).thenAnswer(
        (_) async => GroupCommentDto(
          id: 'c-2',
          body: 'Yes',
          createdAt: DateTime.utc(2026, 11, 12),
        ),
      );
      when(
        () => api.resolveDispute(
          any(),
          any(),
          resolution: any(named: 'resolution'),
          withdraw: any(named: 'withdraw'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester, '/groups/$gid/expenses/exp-1');
      expect(
        find.textContaining('Someone disputed this expense'),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('Was this with the tip?'));
      expect(find.text('Amount was 3000'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a comment'),
        'Yes',
      );
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Send'));
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();
      verify(() => api.comment(gid, 'exp-1', 'Yes')).called(1);
      await scrollTo(tester, find.text('Withdraw'));
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Withdraw'));
      await tester.pumpAndSettle();
      verify(() => api.resolveDispute(gid, 'd-1', withdraw: true)).called(1);
      expect(find.text('Dispute withdrawn.'), findsOneWidget);
    });

    testWidgets('raising a dispute needs a reason', (
      WidgetTester tester,
    ) async {
      when(() => api.dispute(any(), any(), any())).thenAnswer(
        (_) async => GroupDisputeDto(
          id: 'd-2',
          reason: 'Wrong',
          status: GroupDisputeDtoStatus.open,
          createdAt: DateTime.utc(2026, 11, 12),
        ),
      );
      await pump(tester, '/groups/$gid/expenses/exp-1');
      await scrollTo(tester, find.text('Something is wrong'));
      await tester.tap(find.text('Something is wrong'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(requiredText), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Wrong amount');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => api.dispute(gid, 'exp-1', 'Wrong amount')).called(1);
    });

    testWidgets('records my payment in an account; an existing record can '
        'be removed', (WidgetTester tester) async {
      when(() => api.myRecord(any(), any(), accountId: any(named: 'accountId')))
          .thenAnswer((_) async => expenseDetail(myTransactionId: 'tx-9'));
      await pump(tester, '/groups/$gid/expenses/exp-1');
      final Finder link = find.text('Record my payment in an account');
      await scrollTo(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      await tester.tap(find.text('HDFC Savings'));
      await tester.pumpAndSettle();
      verify(() => api.myRecord(gid, 'exp-1', accountId: 'acc-1')).called(1);
      expect(find.text('Recorded in your account.'), findsOneWidget);
    });

    testWidgets('already recorded is explained', (WidgetTester tester) async {
      when(() => api.myRecord(any(), any(), accountId: any(named: 'accountId')))
          .thenThrow(
            serverError(
              ErrorObjectCode.conflict,
              status: 409,
              details: const <Detail>[
                Detail(code: 'expense_already_recorded', message: 'x'),
              ],
            ),
          );
      await pump(tester, '/groups/$gid/expenses/exp-1');
      final Finder link = find.text('Record my payment in an account');
      await scrollTo(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      await tester.tap(find.text('HDFC Savings'));
      await tester.pumpAndSettle();
      expect(
        find.text('This expense is already recorded in your account.'),
        findsOneWidget,
      );
    });

    testWidgets('the creator deletes after confirming; members only edit', (
      WidgetTester tester,
    ) async {
      when(() => api.deleteExpense(any(), any())).thenAnswer((_) async {});
      final GoRouter router = await pump(tester, '/groups/$gid/expenses');
      unawaited(router.push<Object?>('/groups/$gid/expenses/exp-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this expense?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      verify(() => api.deleteExpense(gid, 'exp-1')).called(1);
      expect(locationOf(router), '/groups/$gid/expenses');
    });

    testWidgets('members who did not create it can edit but not delete', (
      WidgetTester tester,
    ) async {
      when(() => people.group(any()))
          .thenAnswer((_) async => goaGroup(myRole: 'member'));
      when(() => api.expense(any(), any()))
          .thenAnswer((_) async => expenseDetail(createdBy: ravi));
      await pump(tester, '/groups/$gid/expenses/exp-1');
      expect(find.byTooltip('Delete'), findsNothing);
      expect(find.byTooltip('Edit'), findsOneWidget);
    });

    testWidgets('a deleted expense is explained and cannot be edited', (
      WidgetTester tester,
    ) async {
      when(() => api.expense(any(), any()))
          .thenAnswer((_) async => expenseDetail(status: 'deleted'));
      await pump(tester, '/groups/$gid/expenses/exp-1');
      expect(find.textContaining('This expense was deleted.'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNothing);
    });

    testWidgets('errors offer a retry', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.expense(any(), any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return expenseDetail();
      });
      await pump(tester, '/groups/$gid/expenses/exp-1');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Dinner at the beach shack'), findsWidgets);
    });
  });

  test('ApiException kind for offline is network', () {
    expect(offline.kind, ApiErrorKind.network);
  });
}
