import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/recurring/data/recurring_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/planning_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockRecurringApi api;
  late MockBillsApi bills;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockTransactionsApi transactions;

  setUpAll(registerPlanningFallbacks);

  setUp(() {
    api = MockRecurringApi();
    bills = MockBillsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    transactions = MockTransactionsApi();
    stubLabels(labels);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(
      () => api.list(
        kind: any(named: 'kind'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => <RecurringRuleDto>[rule()]);
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: [
        recurringApiProvider.overrideWithValue(api),
        billsApiProvider.overrideWithValue(bills),
        accountsApiProvider.overrideWithValue(accounts),
        labelsApiProvider.overrideWithValue(labels),
        transactionsApiProvider.overrideWithValue(transactions),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> open(WidgetTester tester, GoRouter router, String to) async {
    unawaited(router.push<Object?>(to));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  group('list', () {
    testWidgets('shows active rules first with schedule, next date and '
        'amount, and filters by type', (WidgetTester tester) async {
      when(
        () => api.list(
          kind: any(named: 'kind'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((Invocation i) async {
        final String? kind = i.namedArguments[#kind] as String?;
        return <RecurringRuleDto>[
          if (kind == null)
            rule(
              id: 'rule-3',
              name: 'Gym',
              status: 'paused',
              frequency: 'weekly',
              byMonthDay: null,
              amount: '1200.00',
            ),
          if (kind == null || kind == 'expense') rule(),
          if (kind == null || kind == 'income')
            rule(
              id: 'rule-2',
              name: 'Salary',
              kind: 'income',
              variable: true,
              amount: null,
              byMonthDay: -1,
              nextOccurrence: '2026-11-30',
            ),
        ];
      });
      await pump(tester, '/recurring');

      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Monthly · on day 5'), findsOneWidget);
      expect(find.text('Next: Dec 5, 2026'), findsOneWidget);
      expect(find.text('₹15,000.00'), findsOneWidget);
      expect(find.text('Monthly · on the last day'), findsOneWidget);
      expect(find.text('Varies'), findsOneWidget);
      // Paused rules are labelled and listed after active ones.
      final double gym = tester.getTopLeft(find.text('Gym')).dy;
      expect(gym, greaterThan(tester.getTopLeft(find.text('Rent')).dy));
      expect(gym, greaterThan(tester.getTopLeft(find.text('Salary')).dy));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
      await tester.pumpAndSettle();
      verify(() => api.list(kind: 'income')).called(1);
      expect(find.text('Rent'), findsNothing);
      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('recovers from an error and explains an empty list', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(
        () => api.list(
          kind: any(named: 'kind'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <RecurringRuleDto>[];
      });
      await pump(tester, '/recurring');

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No recurring items yet'), findsOneWidget);
      expect(find.text('Add your first recurring item'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ended'));
      await tester.pumpAndSettle();
      verify(() => api.list(status: 'ended')).called(1);
      expect(find.text('Nothing matches these filters'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('creates a weekly expense that is recorded automatically', (
      WidgetTester tester,
    ) async {
      RecurringRuleInput? sent;
      String? key;
      when(() => api.create(any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments.first as RecurringRuleInput;
            key = i.namedArguments[#key] as String?;
            return rule();
          });
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/new');

      // Auto-posting needs a fixed amount and an account.
      expect(find.text('Needs a fixed amount and an account.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Gym');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expected amount'),
        '500',
      );
      await tester.tap(find.text('Account (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HDFC Savings'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Record automatically'));
      await tester.tap(find.text('Record automatically'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Monthly'));
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Same day as the start date'));
      await tester.tap(find.text('Same day as the start date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monday').last);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Add recurring item'));
      await tester.tap(find.text('Add recurring item'));
      await tester.pumpAndSettle();

      final RecurringRuleInput input = sent!;
      expect(input.kind, RecurringRuleInputKind.expense);
      expect(input.name, 'Gym');
      expect(input.amount, '500.00');
      expect(input.amountIsVariable, isFalse);
      expect(input.currency, 'INR');
      expect(input.accountId, 'acc-1');
      expect(input.autoPost, isTrue);
      expect(input.frequency, RecurringRuleInputFrequency.weekly);
      expect(input.byWeekday, 1);
      expect(input.byMonthDay, isNull);
      expect(input.startDate, LocalDates.format(LocalDates.today()));
      expect(input.reminderDaysBefore, <int>[1]);
      expect(input.version, isNull);
      expect(key, hasLength(greaterThanOrEqualTo(8)));
      expect(find.text('Recurring item added.'), findsOneWidget);
      expect(locationOf(router), '/recurring');
    });

    testWidgets('edits this and future occurrences with only the changes; '
        'a stale version is reloaded first', (WidgetTester tester) async {
      int loads = 0;
      when(() => api.get('rule-1')).thenAnswer((_) async {
        loads++;
        return ruleDetail(
          merchantId: 'm-1',
          merchantName: 'Landlord',
          description: 'Flat 4B',
          name: loads == 1 ? 'Rent' : 'Rent flat',
          version: loads == 1 ? 1 : 2,
        );
      });
      final List<RecurringRulePatch> sent = <RecurringRulePatch>[];
      when(() => api.update('rule-1', any())).thenAnswer((Invocation i) async {
        sent.add(i.positionalArguments[1] as RecurringRulePatch);
        if (sent.length == 1) {
          throw serverError(ErrorObjectCode.versionConflict, status: 409);
        }
        return rule();
      });
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1/edit');

      expect(
        find.textContaining('this and future occurrences'),
        findsOneWidget,
      );
      // The merchant comes with the rule (no extra lookup).
      expect(find.text('Landlord'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Home',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(sent.first.toJson(), <String, Object?>{
        'name': 'Home',
        'version': 1,
      });
      expect(find.textContaining('changed somewhere else'), findsOneWidget);
      expect(find.text('Rent flat'), findsOneWidget);

      // Emptied text is cleared with "" and a removed merchant goes too.
      await scrollTo(tester, find.byTooltip('Clear Merchant (optional)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear Merchant (optional)'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.widgetWithText(TextFormField, 'Flat 4B'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Flat 4B'), '');
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent.last.toJson(), <String, Object?>{
        'description': '',
        'merchant_name': '',
        'version': 2,
      });
      expect(
        find.text('Saved for this and future occurrences.'),
        findsOneWidget,
      );
    });

    testWidgets('a new frequency sends the whole schedule and clears the old '
        'day', (WidgetTester tester) async {
      when(() => api.get('rule-1'))
          .thenAnswer((_) async => ruleDetail(version: 3));
      RecurringRulePatch? sent;
      when(() => api.update('rule-1', any())).thenAnswer((Invocation i) async {
        sent = i.positionalArguments[1] as RecurringRulePatch;
        return rule();
      });
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1/edit');
      await scrollTo(tester, find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final Map<String, Object?> body = sent!.toJson();
      expect(body['frequency'], 'weekly');
      expect(body['clear'], <String>['by_month_day']);
      expect(body['version'], 3);
      expect(body.containsKey('start_date'), isFalse);
      expect(body.containsKey('name'), isFalse);
    });

    testWidgets('a transfer needs both accounts', (WidgetTester tester) async {
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/new');
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Savings',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expected amount'),
        '2000',
      );
      await scrollTo(tester, find.text('Add recurring item'));
      await tester.tap(find.text('Add recurring item'));
      await tester.pumpAndSettle();
      expect(find.text('Choose an account.'), findsNWidgets(2));
      verifyNever(() => api.create(any(), key: any(named: 'key')));
    });
  });

  group('detail', () {
    final List<Map<String, Object?>> occurrences = <Map<String, Object?>>[
      occurrenceJson(id: 'occ-2'),
      occurrenceJson(
        id: 'occ-1',
        date: '2026-11-05',
        status: 'posted',
        transactionId: 'tx-1',
      ),
      occurrenceJson(id: 'occ-0', date: '2026-10-05', status: 'skipped'),
    ];

    testWidgets('lists coming-up and past occurrences and records one with '
        'an idempotency key', (WidgetTester tester) async {
      when(() => api.get('rule-1')).thenAnswer(
        (_) async => ruleDetail(completed: 1, occurrences: occurrences),
      );
      OccurrenceAction? acted;
      String? key;
      when(() => api.act('occ-2', any(), key: any(named: 'key'))).thenAnswer((
        Invocation i,
      ) async {
        acted = i.positionalArguments[1] as OccurrenceAction;
        key = i.namedArguments[#key] as String?;
        return occurrence(id: 'occ-2', status: 'posted', transactionId: 'tx');
      });
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1');

      expect(find.text('Monthly · on day 5'), findsOneWidget);
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.text('Dec 5, 2026'), findsOneWidget);
      expect(find.text('Recorded'), findsOneWidget);
      expect(find.text('Linked to a transaction'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);

      await tester.tap(find.text('Dec 5, 2026'));
      await tester.pumpAndSettle();
      expect(find.text('Due Dec 5, 2026'), findsOneWidget);
      await tester.tap(find.text('Record it now'));
      await tester.pumpAndSettle();
      expect(find.text('Rent, due Dec 5, 2026.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Record'));
      await tester.pumpAndSettle();

      expect(acted?.action, OccurrenceActionAction.confirm);
      expect(acted?.amount, isNull, reason: 'the amount was not changed');
      expect(acted?.accountId, isNull, reason: 'the rule has an account');
      expect(key, hasLength(greaterThanOrEqualTo(8)));
      expect(find.text('Recorded.'), findsOneWidget);
    });

    testWidgets('skips, changes the amount, links, postpones and reopens '
        'occurrences', (WidgetTester tester) async {
      when(() => api.get('rule-1'))
          .thenAnswer((_) async => ruleDetail(occurrences: occurrences));
      final List<(String, OccurrenceAction, String)> acted =
          <(String, OccurrenceAction, String)>[];
      when(() => api.act(any(), any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            acted.add((
              i.positionalArguments[0] as String,
              i.positionalArguments[1] as OccurrenceAction,
              i.namedArguments[#key] as String,
            ));
            return occurrence(id: i.positionalArguments[0] as String);
          });
      TransactionFilter? asked;
      when(
        () => transactions.list(
          any(),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((Invocation i) async {
        asked = i.positionalArguments.first as TransactionFilter;
        return page(<TransactionDto>[transaction(id: 'tx-5')]);
      });
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1');

      Future<void> choose(String occurrenceDate, String option) async {
        await tester.ensureVisible(find.text(occurrenceDate));
        await tester.pumpAndSettle();
        await tester.tap(find.text(occurrenceDate));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option));
        await tester.pumpAndSettle();
      }

      await choose('Dec 5, 2026', 'Skip this one');
      expect(find.text('Skip this one?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Skip this one'));
      await tester.pumpAndSettle();
      expect(acted.last.$2.action, OccurrenceActionAction.skip);
      expect(find.text('Skipped.'), findsOneWidget);

      await choose('Dec 5, 2026', 'Change the amount');
      await tester.enterText(find.byType(TextFormField), '15500');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(acted.last.$2.action, OccurrenceActionAction.setAmount);
      expect(acted.last.$2.amount, '15500.00');

      await choose('Dec 5, 2026', 'Link a transaction I already added');
      expect(find.text('Choose the transaction'), findsOneWidget);
      await tester.tap(find.text('Big Bazaar'));
      await tester.pumpAndSettle();
      expect(asked?.types, <String>{'expense'});
      expect(acted.last.$2.action, OccurrenceActionAction.linkTransaction);
      expect(acted.last.$2.transactionId, 'tx-5');

      await choose('Dec 5, 2026', 'Move to another date');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final DateTime today = LocalDates.today();
      final DateTime due = DateTime(2026, 12, 5);
      final DateTime expected = due.isBefore(today)
          ? today
          : due.add(const Duration(days: 1));
      expect(acted.last.$2.action, OccurrenceActionAction.postpone);
      expect(acted.last.$2.postponeTo, LocalDates.format(expected));

      await choose('Oct 5, 2026', 'Undo skip');
      expect(acted.last.$1, 'occ-0');
      expect(acted.last.$2.action, OccurrenceActionAction.reopen);

      // A new key for every action that went through.
      expect(acted.map((e) => e.$3).toSet(), hasLength(acted.length));
    });

    testWidgets('pauses, skips the next one, stops and deletes with the '
        'version shown and the outcome explained', (WidgetTester tester) async {
      when(() => api.get('rule-1'))
          .thenAnswer((_) async => ruleDetail(version: 7));
      when(() => api.pause('rule-1', version: any(named: 'version')))
          .thenAnswer((_) async => rule());
      when(() => api.skipNext('rule-1', version: any(named: 'version')))
          .thenAnswer((_) async => rule());
      when(() => api.stop('rule-1', version: any(named: 'version')))
          .thenAnswer((_) async => rule());
      when(() => api.delete('rule-1')).thenAnswer(
        (_) async => const RecurringDeleteResult(
          outcome: RecurringDeleteResultOutcome.ended,
        ),
      );
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1');

      Future<void> menu(String item, {String? confirm}) async {
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(item).last);
        await tester.pumpAndSettle();
        if (confirm != null) {
          await tester.tap(find.widgetWithText(FilledButton, confirm));
          await tester.pumpAndSettle();
        }
      }

      await menu('Pause');
      verify(() => api.pause('rule-1', version: 7)).called(1);
      expect(find.text('Paused.'), findsOneWidget);

      await menu('Skip the next one', confirm: 'Skip the next one');
      verify(() => api.skipNext('rule-1', version: 7)).called(1);

      await menu('Stop', confirm: 'Stop');
      verify(() => api.stop('rule-1', version: 7)).called(1);

      await menu('Delete', confirm: 'Delete');
      verify(() => api.delete('rule-1')).called(1);
      expect(find.textContaining('it was ended instead'), findsOneWidget);
      expect(locationOf(router), '/recurring/rule-1');
    });

    testWidgets('an unused rule is deleted and the list is shown again', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rule-1')).thenAnswer((_) async => ruleDetail());
      when(() => api.delete('rule-1')).thenAnswer(
        (_) async => const RecurringDeleteResult(
          outcome: RecurringDeleteResultOutcome.deleted,
        ),
      );
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this recurring item?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Recurring item deleted.'), findsOneWidget);
      expect(locationOf(router), '/recurring');
    });

    testWidgets('a refused move is explained and the rule reloaded', (
      WidgetTester tester,
    ) async {
      int loads = 0;
      when(() => api.get('rule-1')).thenAnswer((_) async {
        loads++;
        return ruleDetail(status: 'paused');
      });
      when(() => api.resume('rule-1', version: any(named: 'version')))
          .thenThrow(
            serverError(
              ErrorObjectCode.domainRuleViolation,
              details: const <Detail>[
                Detail(
                  code: 'invalid_status_transition',
                  message: 'A rule cannot move from ended to active.',
                  params: <String, String>{'from': 'ended', 'to': 'active'},
                ),
              ],
            ),
          );
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          "This can't change from ended to active. Reload to see where it "
          'stands now.',
        ),
        findsOneWidget,
      );
      expect(loads, 2);
    });

    testWidgets('shows the merchant and where a moved occurrence went', (
      WidgetTester tester,
    ) async {
      when(() => api.get('rule-1')).thenAnswer(
        (_) async => ruleDetail(
          merchantId: 'm-1',
          merchantName: 'Landlord',
          occurrences: <Map<String, Object?>>[
            occurrenceJson(
              id: 'occ-9',
              date: '2026-12-05',
              effectiveDate: '2026-12-12',
            ),
          ],
        ),
      );
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1');
      expect(find.text('Dec 5, 2026'), findsOneWidget);
      expect(find.text('Moved to Dec 12, 2026'), findsOneWidget);
      // Still open: it keeps its status.
      expect(find.text('Scheduled'), findsOneWidget);
      await scrollTo(tester, find.text('Landlord'));
      expect(find.text('Landlord'), findsOneWidget);
    });

    testWidgets('a bill schedule is read-only here and opens its bill', (
      WidgetTester tester,
    ) async {
      when(() => api.get('sched-1')).thenAnswer(
        (_) async => ruleDetail(
          id: 'sched-1',
          kind: 'bill',
          name: 'Electricity',
          billId: 'bill-1',
        ),
      );
      when(() => bills.get('bill-1')).thenAnswer((_) async => billDetail());
      when(
        () => bills.paymentCandidates(
          any(),
          occurrenceId: any(named: 'occurrenceId'),
        ),
      ).thenAnswer((_) async => <BillPaymentCandidate>[]);
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/sched-1');

      expect(
        find.textContaining('This schedule belongs to a bill'),
        findsOneWidget,
      );
      expect(find.byTooltip('More options'), findsNothing);
      await tester.tap(find.text('Open bill'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/bills/bill-1');
    });

    testWidgets('shows an error state with retry', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.get('rule-1')).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return ruleDetail();
      });
      final GoRouter router = await pump(tester, '/recurring');
      await open(tester, router, '/recurring/rule-1');
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing coming up.'), findsOneWidget);
      expect(find.text('Nothing recorded yet.'), findsOneWidget);
    });
  });
}
