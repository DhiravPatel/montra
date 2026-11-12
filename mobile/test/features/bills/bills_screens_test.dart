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
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/planning_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockBillsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockTransactionsApi transactions;

  setUpAll(registerPlanningFallbacks);

  setUp(() {
    api = MockBillsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    transactions = MockTransactionsApi();
    stubLabels(labels);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => api.list(status: any(named: 'status')))
        .thenAnswer((_) async => <BillDto>[bill()]);
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: [
        billsApiProvider.overrideWithValue(api),
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

  final Map<String, Object?> due = billOccurrenceJson();

  group('list', () {
    testWidgets('shows each bill with its payment state, due date and '
        'amount, and filters by status', (WidgetTester tester) async {
      when(() => api.list(status: any(named: 'status')))
          .thenAnswer((Invocation i) async {
            if (i.namedArguments[#status] == 'paused') {
              return <BillDto>[bill(id: 'b-3', name: 'Gym', status: 'paused')];
            }
            return <BillDto>[
              bill(state: 'overdue', nextDue: due),
              bill(
                id: 'b-2',
                name: 'Phone',
                state: 'paid',
                variable: true,
                expected: null,
                lastPaid: billOccurrenceJson(
                  id: 'p',
                  date: '2026-11-01',
                  status: 'paid',
                ),
              ),
            ];
          });
      await pump(tester, '/bills');

      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('BESCOM'), findsNWidgets(2));
      expect(find.text('Due Nov 10, 2026'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('₹1,800.00'), findsOneWidget);
      expect(find.text('Paid Nov 1, 2026'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Varies'), findsOneWidget);
      verify(() => api.list(status: 'active')).called(1);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Paused'));
      await tester.pumpAndSettle();
      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('Electricity'), findsNothing);
    });

    testWidgets('explains empty lists and recovers from errors', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.list(status: any(named: 'status'))).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <BillDto>[];
      });
      await pump(tester, '/bills');
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No bills yet'), findsOneWidget);
      expect(find.text('Add your first bill'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await tester.pumpAndSettle();
      expect(find.text('No bills here'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('adds a monthly bill with reminders; a retry after a lost '
        'connection reuses the idempotency key', (WidgetTester tester) async {
      BillInput? sent;
      final List<String> keys = <String>[];
      when(() => api.create(any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments.first as BillInput;
            keys.add(i.namedArguments[#key]! as String);
            if (keys.length == 1) {
              throw offline;
            }
            return billDetail();
          });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/new');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bill name'),
        'Water',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Provider (optional)'),
        'BWSSB',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expected amount'),
        '650',
      );
      await scrollTo(tester, find.text('3 days before'));
      await tester.tap(find.text('3 days before'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Add bill').last);
      await tester.tap(find.text('Add bill').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Check your internet connection'),
        findsWidgets,
      );
      await scrollTo(tester, find.text('Add bill').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add bill').last);
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys.first, hasLength(greaterThanOrEqualTo(8)));
      expect(keys.last, keys.first, reason: 'same request, same key');

      final BillInput input = sent!;
      expect(input.name, 'Water');
      expect(input.providerName, 'BWSSB');
      expect(input.expectedAmount, '650.00');
      expect(input.amountIsVariable, isFalse);
      expect(input.currency, 'INR');
      expect(input.frequency, BillInputFrequency.monthly);
      expect(input.startDate, LocalDates.format(LocalDates.today()));
      expect(input.reminderDaysBefore, <int>[1, 3]);
      expect(input.status, isNull);
      expect(input.version, isNull);
      expect(find.text('Bill added.'), findsOneWidget);
    });

    testWidgets('edits send only the changes with the version; a stale '
        'version is reloaded', (WidgetTester tester) async {
      int loads = 0;
      when(() => api.get('bill-1')).thenAnswer((_) async {
        loads++;
        return billDetail(
          status: 'paused',
          version: loads == 1 ? 1 : 2,
          notes: 'Meter 42',
        );
      });
      final List<BillPatch> sent = <BillPatch>[];
      when(() => api.update('bill-1', any())).thenAnswer((Invocation i) async {
        sent.add(i.positionalArguments[1] as BillPatch);
        if (sent.length == 1) {
          throw serverError(ErrorObjectCode.versionConflict, status: 409);
        }
        return billDetail();
      });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1/edit');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expected amount'),
        '1900',
      );
      await scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Only the change is sent (the status is never part of an edit).
      expect(sent.first.toJson(), <String, Object?>{
        'expected_amount': '1900.00',
        'version': 1,
      });
      expect(find.textContaining('changed somewhere else'), findsOneWidget);

      // The newer version was loaded; the change is made again on it.
      await scrollTo(
        tester,
        find.widgetWithText(TextFormField, 'Expected amount'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Expected amount'),
        '1900',
      );
      await scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent.last.toJson(), <String, Object?>{
        'expected_amount': '1900.00',
        'version': 2,
      });
      expect(find.text('Bill saved.'), findsOneWidget);
    });

    testWidgets('emptied fields are cleared: text with "" and links with '
        'clear; nothing changed sends nothing', (WidgetTester tester) async {
      when(() => api.get('bill-1'))
          .thenAnswer((_) async => billDetail(notes: 'Meter 42', version: 4));
      BillPatch? sent;
      when(() => api.update('bill-1', any())).thenAnswer((Invocation i) async {
        sent = i.positionalArguments[1] as BillPatch;
        return billDetail();
      });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1/edit');

      // Saving without changes sends nothing.
      await scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing changed.'), findsOneWidget);
      verifyNever(() => api.update(any(), any()));

      await open(tester, router, '/bills/bill-1/edit');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Provider (optional)'),
        '',
      );
      await tester.tap(find.byTooltip('Clear Paid from (optional)'));
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.widgetWithText(TextFormField, 'Notes (optional)'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'),
        '',
      );
      await scrollTo(tester, find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent?.toJson(), <String, Object?>{
        'provider_name': '',
        'notes': '',
        'clear': <String>['payment_account_id'],
        'version': 4,
      });
      expect(find.text('Bill saved.'), findsOneWidget);
    });

    testWidgets('a schedule this version does not know is not edited', (
      WidgetTester tester,
    ) async {
      final Map<String, Object?> json = <String, Object?>{
        ...billJson(),
        'occurrences': <Object?>[],
      };
      (json['schedule']! as Map<String, Object?>)['frequency'] = 'lunar';
      when(() => api.get('bill-1'))
          .thenAnswer((_) async => BillDetail.fromJson(json));
      BillPatch? sent;
      when(() => api.update('bill-1', any())).thenAnswer((Invocation i) async {
        sent = i.positionalArguments[1] as BillPatch;
        return billDetail();
      });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1/edit');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bill name'),
        'Power',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.textContaining("can't show"));
      expect(find.textContaining("can't show"), findsOneWidget);
      await scrollTo(tester, find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent?.toJson(), <String, Object?>{'name': 'Power', 'version': 1});
    });
  });

  group('detail', () {
    testWidgets('shows the state and history; skips with confirmation, and '
        'pauses or archives through the lifecycle actions with the version '
        'shown', (WidgetTester tester) async {
      when(() => api.get('bill-1')).thenAnswer(
        (_) async => billDetail(
          state: 'due_soon',
          nextDue: due,
          lastPaid: billOccurrenceJson(
            id: 'p',
            date: '2026-10-10',
            status: 'paid',
            transactionId: 'tx-1',
          ),
          occurrences: <Map<String, Object?>>[
            due,
            billOccurrenceJson(
              id: 'p',
              date: '2026-10-10',
              status: 'paid',
              transactionId: 'tx-1',
            ),
          ],
        ),
      );
      when(() => api.skip('bill-1', occurrenceId: any(named: 'occurrenceId')))
          .thenAnswer((_) async => billDetail());
      final List<(BillAction, int?)> actions = <(BillAction, int?)>[];
      when(() => api.act('bill-1', any(), version: any(named: 'version')))
          .thenAnswer((Invocation i) async {
            actions.add((
              i.positionalArguments[1] as BillAction,
              i.namedArguments[#version] as int?,
            ));
            return billDetail();
          });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');

      expect(find.text('Due soon'), findsOneWidget);
      expect(find.text('Last paid Oct 10, 2026'), findsOneWidget);
      expect(find.text('Monthly · on day 10'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);

      await tester.tap(find.text('Skip this payment'));
      await tester.pumpAndSettle();
      expect(find.text('Skip this payment?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Skip this one'));
      await tester.pumpAndSettle();
      verify(() => api.skip('bill-1', occurrenceId: 'bocc-1')).called(1);
      expect(find.text('Skipped.'), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause').last);
      await tester.pumpAndSettle();
      expect(actions.last, (BillAction.pause, 1));
      expect(find.text('Bill paused.'), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await tester.pumpAndSettle();
      expect(find.text('Archive this bill?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(actions.last, (BillAction.archive, 1));
      verifyNever(() => api.update(any(), any()));

      await tester.tap(find.text('Mark as paid'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/bills/bill-1/pay?occurrence=bocc-1');
    });

    testWidgets('shows an error state with retry', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.get('bill-1')).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return billDetail(status: 'archived', state: 'archived');
      });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Archived. Its payment history'),
        findsOneWidget,
      );
      expect(find.text('No payments yet.'), findsOneWidget);
      expect(find.text('Mark as paid'), findsNothing);
    });

    testWidgets('an archived bill is restored; a move that no longer fits is '
        'explained and the bill reloaded', (WidgetTester tester) async {
      int loads = 0;
      when(() => api.get('bill-1')).thenAnswer((_) async {
        loads++;
        return billDetail(status: 'archived', state: 'archived', version: 3);
      });
      int calls = 0;
      when(() => api.act('bill-1', any(), version: any(named: 'version')))
          .thenAnswer((Invocation i) async {
            calls++;
            if (calls == 1) {
              throw serverError(
                ErrorObjectCode.domainRuleViolation,
                details: const <Detail>[
                  Detail(
                    code: 'invalid_status_transition',
                    message: 'A bill cannot move from active to active.',
                    params: <String, String>{'from': 'active', 'to': 'active'},
                  ),
                ],
              );
            }
            return billDetail();
          });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');
      // Archived bills offer restore only (no edit, pause or archive).
      expect(find.byTooltip('Edit'), findsNothing);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsNothing);
      await tester.tap(find.text('Restore').last);
      await tester.pumpAndSettle();
      verify(() => api.act('bill-1', BillAction.restore, version: 3)).called(1);
      expect(
        find.text(
          "This can't change from active to active. Reload to see where it "
          'stands now.',
        ),
        findsOneWidget,
      );
      expect(loads, 2, reason: 'reloaded after the refusal');

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore').last);
      await tester.pumpAndSettle();
      expect(find.text('Bill restored.'), findsOneWidget);
    });

    testWidgets('a moved payment says where it moved', (
      WidgetTester tester,
    ) async {
      final Map<String, Object?> moved =
          billOccurrenceJson(id: 'bocc-2', date: '2026-12-10')
            ..addAll(<String, Object?>{
              'effective_date': '2026-12-20',
              'postponed_to': '2026-12-20',
            });
      when(() => api.get('bill-1')).thenAnswer(
        (_) async => billDetail(
          nextDue: due,
          occurrences: <Map<String, Object?>>[moved, due],
        ),
      );
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');
      await scrollTo(tester, find.text('Moved to Dec 20, 2026'));
      expect(find.text('Moved to Dec 20, 2026'), findsOneWidget);
      expect(find.text('Dec 10, 2026'), findsOneWidget);
    });
  });

  group('mark as paid', () {
    setUp(() {
      when(
        () => api.get('bill-1'),
      ).thenAnswer((_) async => billDetail(nextDue: due, occurrences: [due]));
    });

    testWidgets('links a suggested payment with an idempotency key', (
      WidgetTester tester,
    ) async {
      when(
        () => api.paymentCandidates(
          'bill-1',
          occurrenceId: any(named: 'occurrenceId'),
        ),
      ).thenAnswer(
        (_) async => <BillPaymentCandidate>[
          candidate(
            reasonCodes: <String>[
              'same_provider',
              'same_amount',
              'near_due_date',
            ],
            reasons: <String>['English 1', 'English 2', 'English 3'],
            daysFromDue: -2,
          ),
        ],
      );
      MarkPaidInput? sent;
      String? key;
      when(() => api.markPaid('bill-1', any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[1] as MarkPaidInput;
            key = i.namedArguments[#key] as String?;
            return billDetail(state: 'paid');
          });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');
      await open(tester, router, '/bills/bill-1/pay?occurrence=bocc-1');

      expect(find.text('Electricity, due Nov 10, 2026'), findsOneWidget);
      // Reasons come from the stable codes, in the user's language.
      expect(
        find.textContaining(
          'HDFC Savings · Same provider · Same amount · 2 days before the '
          'due date',
        ),
        findsOneWidget,
      );
      // Nothing is linked until the user chooses.
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the payment to link.'), findsOneWidget);
      verifyNever(() => api.markPaid(any(), any(), key: any(named: 'key')));

      await tester.tap(find.text('BESCOM'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.pumpAndSettle();
      expect(sent?.transactionId, 'tx-9');
      expect(sent?.occurrenceId, 'bocc-1');
      expect(sent?.createTransaction, isNull);
      expect(key, hasLength(greaterThanOrEqualTo(8)));
      expect(find.text('Marked as paid.'), findsOneWidget);
      expect(locationOf(router), '/bills/bill-1');
    });

    testWidgets('records a new payment from the bill account', (
      WidgetTester tester,
    ) async {
      when(
        () => api.paymentCandidates(
          'bill-1',
          occurrenceId: any(named: 'occurrenceId'),
        ),
      ).thenAnswer((_) async => <BillPaymentCandidate>[]);
      MarkPaidInput? sent;
      when(() => api.markPaid('bill-1', any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[1] as MarkPaidInput;
            return billDetail(state: 'paid');
          });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');
      await open(tester, router, '/bills/bill-1/pay');

      expect(find.textContaining('No matching payments found'), findsOneWidget);
      await tester.tap(find.text('Record new'));
      await tester.pumpAndSettle();
      expect(find.text('1800.00'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount paid'),
        '1925.50',
      );
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.pumpAndSettle();
      expect(sent?.createTransaction, isTrue);
      expect(sent?.amount, '1925.50');
      expect(sent?.accountId, 'acc-1');
      expect(sent?.paidOn, isNull, reason: 'today, the server default');
      expect(sent?.occurrenceId, 'bocc-1');
      expect(find.text('Marked as paid.'), findsOneWidget);
    });

    testWidgets('can link any expense, and retries suggestions that failed', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(
        () => api.paymentCandidates(
          'bill-1',
          occurrenceId: any(named: 'occurrenceId'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <BillPaymentCandidate>[];
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
        return page(<TransactionDto>[transaction(id: 'tx-7')]);
      });
      MarkPaidInput? sent;
      when(() => api.markPaid('bill-1', any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[1] as MarkPaidInput;
            return billDetail(state: 'paid');
          });
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');
      await open(tester, router, '/bills/bill-1/pay');

      expect(find.text("We couldn't load suggested payments."), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No matching payments found'), findsOneWidget);

      await tester.tap(find.text('Choose another transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Big Bazaar'));
      await tester.pumpAndSettle();
      expect(asked?.types, <String>{'expense'});
      expect(find.text('Chosen payment'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.pumpAndSettle();
      expect(sent?.transactionId, 'tx-7');
    });

    testWidgets('a bill without a payment account asks for one', (
      WidgetTester tester,
    ) async {
      when(() => api.get('bill-1')).thenAnswer(
        (_) async => billDetail(
          paymentAccountId: null,
          nextDue: due,
          occurrences: <Map<String, Object?>>[due],
        ),
      );
      when(
        () => api.paymentCandidates(
          'bill-1',
          occurrenceId: any(named: 'occurrenceId'),
        ),
      ).thenAnswer((_) async => <BillPaymentCandidate>[]);
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');
      await open(tester, router, '/bills/bill-1/pay');
      await tester.tap(find.text('Record new'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.tap(find.widgetWithText(FilledButton, 'Mark as paid'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the account you paid from.'), findsOneWidget);
      verifyNever(() => api.markPaid(any(), any(), key: any(named: 'key')));
    });

    testWidgets('a payment already handled elsewhere is explained', (
      WidgetTester tester,
    ) async {
      when(
        () => api.paymentCandidates(
          'bill-1',
          occurrenceId: any(named: 'occurrenceId'),
        ),
      ).thenThrow(
        serverError(
          ErrorObjectCode.conflict,
          status: 409,
          details: const <Detail>[
            Detail(
              code: 'occurrence_not_open',
              message: 'That occurrence is already paid.',
            ),
          ],
        ),
      );
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1');
      await open(tester, router, '/bills/bill-1/pay?occurrence=bocc-1');
      expect(
        find.text(
          'That payment is already paid, skipped or no longer part of this '
          'bill.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says when nothing is due', (WidgetTester tester) async {
      when(() => api.get('bill-1'))
          .thenAnswer((_) async => billDetail(state: 'paid'));
      final GoRouter router = await pump(tester, '/bills');
      await open(tester, router, '/bills/bill-1/pay');
      expect(
        find.text('Nothing is due on this bill right now.'),
        findsOneWidget,
      );
    });
  });
}
