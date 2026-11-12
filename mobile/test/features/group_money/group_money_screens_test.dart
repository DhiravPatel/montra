import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';

import '../../helpers/files_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/group_money_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';

/// Balances, settlements, recurring shared expenses and group reports.
void main() {
  late MockGroupMoneyApi api;
  late MockPeopleApi people;
  late MockAccountsApi accounts;
  late FakeFileExporter exporter;

  setUpAll(registerGroupMoneyFallbacks);

  setUp(() {
    api = MockGroupMoneyApi();
    people = MockPeopleApi();
    accounts = MockAccountsApi();
    exporter = FakeFileExporter();
    stubGroupMoney(api, people, accounts);
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: <Override>[
        ...groupMoneyOverrides(api, people, accounts),
        fileExporterProvider.overrideWithValue(exporter),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Finder dialogButton() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(FilledButton),
  );

  group('balances', () {
    testWidgets('shows my balance, suggestions, debts both ways and former '
        'members', (WidgetTester tester) async {
      await pump(tester, '/groups/$gid/balances');
      expect(find.text('You are owed ₹7,754.43'), findsWidgets);
      expect(find.text('Meera Iyer pays You'), findsWidgets);
      await tester.tap(find.widgetWithText(ChoiceChip, 'As recorded'));
      await tester.pumpAndSettle();
      expect(find.text('Meera Iyer pays Ravi Kumar'), findsOneWidget);
      await scrollTo(tester, find.text('Old Friend'));
      expect(find.text('Removed'), findsOneWidget);
      expect(find.text('Meera Iyer owes ₹6,964.83'), findsOneWidget);
    });

    testWidgets('a suggestion opens the payment form prefilled', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester, '/groups/$gid/balances');
      await tester.tap(
        find.byTooltip('Record a payment from Meera Iyer to You of ₹6,964.83'),
      );
      await tester.pumpAndSettle();
      expect(
        locationOf(router),
        '/groups/$gid/settlements/new?payer=$meera&payee=$me&amount=6964.83',
      );
      expect(find.text('Meera Iyer'), findsOneWidget);
      expect(find.text('6964.83'), findsOneWidget);
    });

    testWidgets('only mine, settled groups and disputed expenses', (
      WidgetTester tester,
    ) async {
      when(() => api.balances(any()))
          .thenAnswer((_) async => balances(settled: true, disputed: 2));
      when(() => api.suggestions(any(), mine: any(named: 'mine')))
          .thenAnswer((_) async => suggestions(empty: true));
      await pump(tester, '/groups/$gid/balances');
      expect(find.text('You are all settled'), findsWidgets);
      expect(
        find.textContaining('2 disputed expenses still count'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Only mine'));
      await tester.pumpAndSettle();
      verify(() => api.suggestions(gid, mine: true)).called(1);
      expect(find.text('You have nothing to pay or receive.'), findsOneWidget);
    });

    testWidgets('errors offer a retry', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.balances(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return balances();
      });
      await pump(tester, '/groups/$gid/balances');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('You are owed ₹7,754.43'), findsWidgets);
    });
  });

  group('settlements', () {
    testWidgets('lists payments with their state; voided ones on request', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/groups/$gid/settlements');
      expect(find.text('Ravi Kumar paid You'), findsOneWidget);
      expect(find.text('Waiting for confirmation'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Show voided'));
      await tester.pumpAndSettle();
      verify(() => api.settlements(gid, includeVoided: true)).called(1);
    });

    testWidgets('empty list', (WidgetTester tester) async {
      when(
        () =>
            api.settlements(any(), includeVoided: any(named: 'includeVoided')),
      ).thenAnswer((_) async => <SettlementDto>[]);
      await pump(tester, '/groups/$gid/settlements');
      expect(find.text('No payments yet'), findsOneWidget);
    });

    testWidgets('records a planned payment with an idempotency key', (
      WidgetTester tester,
    ) async {
      SettlementInput? sent;
      String? key;
      when(() => api.createSettlement(any(), any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[1] as SettlementInput;
            key = i.namedArguments[#key] as String?;
            return settlement(status: 'proposed', payer: me, payee: ravi);
          });
      final GoRouter router = await pump(
        tester,
        '/groups/$gid/settlements/new?payee=$ravi&amount=789.60',
      );
      expect(find.textContaining('Montra never moves money'), findsWidgets);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
      await tester.tap(find.text('Not paid yet'));
      await tester.pumpAndSettle();
      final Finder save = find.widgetWithText(FilledButton, 'Record a payment');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(sent!.payerUserId, me);
      expect(sent!.payeeUserId, ravi);
      expect(sent!.amount, '789.60');
      expect(sent!.method, SettlementInputMethod.cash);
      expect(sent!.state, SettlementInputState.proposed);
      expect(key, isNotNull);
      expect(locationOf(router), '/groups/$gid/settlements/st-1');
    });

    testWidgets('who received it is required', (WidgetTester tester) async {
      await pump(tester, '/groups/$gid/settlements/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '10',
      );
      final Finder save = find.widgetWithText(FilledButton, 'Record a payment');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Who received it'));
      expect(find.text('This field is required.'), findsOneWidget);
      verifyNever(
        () => api.createSettlement(any(), any(), key: any(named: 'key')),
      );
    });

    testWidgets('the payee confirms a reported payment with its version', (
      WidgetTester tester,
    ) async {
      when(() => api.settlement(any(), any()))
          .thenAnswer((_) async => settlement(version: 2));
      when(
        () => api.settlementAction(
          any(),
          any(),
          any(),
          version: any(named: 'version'),
          accountId: any(named: 'accountId'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => settlement(status: 'confirmed', version: 3));
      await pump(tester, '/groups/$gid/settlements/st-1');
      expect(find.text('Ravi Kumar paid You'), findsOneWidget);
      expect(find.text('Mark as paid'), findsNothing);
      expect(find.text('Dispute'), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget);
      await tester.tap(find.text('Confirm I received it'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton());
      await tester.pumpAndSettle();
      verify(
        () => api.settlementAction(
          gid,
          'st-1',
          SettlementAction.confirm,
          version: 2,
        ),
      ).called(1);
      expect(find.text('Payment confirmed.'), findsOneWidget);
    });

    testWidgets('the payer marks a planned payment paid; voiding needs a '
        'reason', (WidgetTester tester) async {
      when(() => api.settlement(any(), any())).thenAnswer(
        (_) async => settlement(status: 'proposed', payer: me, payee: ravi),
      );
      when(
        () => api.settlementAction(
          any(),
          any(),
          any(),
          version: any(named: 'version'),
          accountId: any(named: 'accountId'),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => settlement());
      await pump(tester, '/groups/$gid/settlements/st-1');
      expect(find.text('Confirm I received it'), findsNothing);
      await tester.tap(find.text('Mark as paid'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton());
      await tester.pumpAndSettle();
      verify(
        () => api.settlementAction(
          gid,
          'st-1',
          SettlementAction.markPaid,
          version: 1,
        ),
      ).called(1);

      await scrollTo(tester, find.text('Void'));
      await tester.tap(find.text('Void'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton());
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Recorded twice',
      );
      await tester.tap(dialogButton());
      await tester.pumpAndSettle();
      verify(
        () => api.settlementAction(
          gid,
          'st-1',
          SettlementAction.voidIt,
          version: 1,
          reason: 'Recorded twice',
        ),
      ).called(1);
    });

    testWidgets('a coded conflict is explained and reloads the payment', (
      WidgetTester tester,
    ) async {
      int reads = 0;
      when(() => api.settlement(any(), any())).thenAnswer((_) async {
        reads++;
        return settlement();
      });
      when(
        () => api.settlementAction(
          any(),
          any(),
          any(),
          version: any(named: 'version'),
          accountId: any(named: 'accountId'),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(
        serverError(
          ErrorObjectCode.conflict,
          status: 409,
          details: const <Detail>[
            Detail(
              code: 'settlement_not_confirmable',
              message: 'x',
              params: <String, String>{'status': 'confirmed'},
            ),
          ],
        ),
      );
      await pump(tester, '/groups/$gid/settlements/st-1');
      await tester.tap(find.text('Confirm I received it'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton());
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This payment can no longer be confirmed. It is now: Confirmed.',
        ),
        findsOneWidget,
      );
      expect(reads, 2);
    });

    testWidgets('an admin confirms for a former member; a correction links '
        'both records', (WidgetTester tester) async {
      when(() => api.settlement(any(), any())).thenAnswer(
        (_) async => settlement(
          payer: ravi,
          payee: former,
          correctsId: 'st-0',
          myTransactionId: 'tx-5',
        ),
      );
      await pump(tester, '/groups/$gid/settlements/st-1');
      expect(find.text('Confirm I received it'), findsOneWidget);
      expect(find.text('This corrects an earlier payment'), findsOneWidget);
      await scrollTo(tester, find.text('Recorded in your account'));
      expect(find.text('Remove from my account'), findsOneWidget);
    });

    testWidgets('correcting a payment sends a new key to the correct '
        'endpoint', (WidgetTester tester) async {
      when(
        () =>
            api.correctSettlement(any(), any(), any(), key: any(named: 'key')),
      ).thenAnswer((_) async => settlement(id: 'st-2', correctsId: 'st-1'));
      final GoRouter router = await pump(
        tester,
        '/groups/$gid/settlements/st-1',
      );
      await scrollTo(tester, find.text('Correct'));
      await tester.tap(find.text('Correct'));
      await tester.pumpAndSettle();
      expect(find.text('Correct this payment'), findsWidgets);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '450',
      );
      final Finder save = find.widgetWithText(
        FilledButton,
        'Save the correction',
      );
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final SettlementInput sent =
          verify(
                () => api.correctSettlement(
                  gid,
                  'st-1',
                  captureAny(),
                  key: any(named: 'key'),
                ),
              ).captured.single
              as SettlementInput;
      expect(sent.amount, '450.00');
      expect(sent.payerUserId, ravi);
      expect(locationOf(router), '/groups/$gid/settlements/st-2');
    });
  });

  group('recurring shared expenses', () {
    testWidgets('list, then a member adds a due occurrence', (
      WidgetTester tester,
    ) async {
      when(() => people.group(any()))
          .thenAnswer((_) async => goaGroup(myRole: 'member'));
      when(() => api.recurringRule(any(), any()))
          .thenAnswer((_) async => recurring(createdBy: ravi));
      when(() => api.addOccurrence(any(), any(), any(), key: any(named: 'key')))
          .thenAnswer((_) async => expenseDetail(id: 'exp-7'));
      final GoRouter router = await pump(tester, '/groups/$gid/recurring');
      expect(find.text('Villa cleaning'), findsOneWidget);
      expect(find.text('A member adds it when due'), findsOneWidget);
      await tester.tap(find.text('Villa cleaning'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit'), findsNothing, reason: 'not the creator');
      await scrollTo(tester, find.text('Add the expense now'));
      expect(find.text('Skip this one'), findsNothing);
      await tester.tap(find.text('Add the expense now'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton());
      await tester.pumpAndSettle();
      verify(
        () => api.addOccurrence(gid, 'rule-1', 'occ-3', key: any(named: 'key')),
      ).called(1);
      expect(locationOf(router), '/groups/$gid/expenses/exp-7');
    });

    testWidgets('the creator skips an occurrence and pauses the rule', (
      WidgetTester tester,
    ) async {
      when(() => api.skipOccurrence(any(), any(), any()))
          .thenAnswer((_) async => recurring());
      when(() => api.recurringAction(any(), any(), any()))
          .thenAnswer((_) async => recurring(status: 'paused'));
      await pump(tester, '/groups/$gid/recurring/rule-1');
      await scrollTo(tester, find.text('Skip this one'));
      await tester.tap(find.text('Skip this one'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton());
      await tester.pumpAndSettle();
      verify(() => api.skipOccurrence(gid, 'rule-1', 'occ-3')).called(1);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause').last);
      await tester.pumpAndSettle();
      verify(
        () => api.recurringAction(gid, 'rule-1', GroupRecurringAction.pause),
      ).called(1);
    });

    testWidgets('a former participant is named when adding fails', (
      WidgetTester tester,
    ) async {
      when(() => api.addOccurrence(any(), any(), any(), key: any(named: 'key')))
          .thenThrow(
            serverError(
              ErrorObjectCode.domainRuleViolation,
              details: const <Detail>[
                Detail(
                  code: 'recurring_member_inactive',
                  message: 'x',
                  params: <String, String>{'user_id': former},
                ),
              ],
            ),
          );
      await pump(tester, '/groups/$gid/recurring/rule-1');
      await scrollTo(tester, find.text('Add the expense now'));
      await tester.tap(find.text('Add the expense now'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Old Friend is no longer a member.'),
        findsOneWidget,
      );
    });

    testWidgets('creates one with a schedule, a split and a key', (
      WidgetTester tester,
    ) async {
      GroupRecurringInput? sent;
      when(() => api.createRecurring(any(), any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[1] as GroupRecurringInput;
            return recurring(id: 'rule-2');
          });
      final GoRouter router = await pump(tester, '/groups/$gid/recurring/new');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Rent',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount each time'),
        '30000',
      );
      final Finder auto = find.text('Add automatically when due');
      await scrollTo(tester, auto);
      await tester.tap(auto);
      await tester.pumpAndSettle();
      final Finder save = find.widgetWithText(
        FilledButton,
        'Add recurring expense',
      );
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(sent!.name, 'Rent');
      expect(sent!.amount, '30000.00');
      expect(sent!.frequency, GroupRecurringInputFrequency.monthly);
      expect(sent!.autoAdd, isTrue);
      expect(sent!.timezone, 'Asia/Kolkata');
      expect(sent!.participants, hasLength(3));
      expect(sent!.payers, isNull);
      expect(locationOf(router), '/groups/$gid/recurring/rule-2');
    });

    testWidgets('edits the amount with the version', (
      WidgetTester tester,
    ) async {
      when(() => api.recurringRule(any(), any()))
          .thenAnswer((_) async => recurring(version: 4));
      GroupRecurringUpdate? sent;
      when(() => api.updateRecurring(any(), any(), any()))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[2] as GroupRecurringUpdate;
            return recurring(version: 5);
          });
      await pump(tester, '/groups/$gid/recurring/rule-1/edit');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount each time'),
        '650',
      );
      expect(find.textContaining('The schedule cannot change'), findsOneWidget);
      final Finder save = find.widgetWithText(FilledButton, 'Save');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(sent!.version, 4);
      expect(sent!.amount, '650.00');
      expect(sent!.participants, hasLength(3));
    });

    testWidgets('empty list and errors', (WidgetTester tester) async {
      int calls = 0;
      when(() => api.recurring(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <GroupRecurringDto>[];
      });
      await pump(tester, '/groups/$gid/recurring');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No recurring expenses'), findsOneWidget);
    });
  });

  group('reports', () {
    testWidgets('summary, categories, members, currencies and the CSV '
        'export to share or save', (WidgetTester tester) async {
      await pump(tester, '/groups/$gid/reports');
      expect(find.text('₹23,541.38'), findsWidgets);
      expect(find.text('7 expenses'), findsWidgets);
      expect(find.text('Goa'), findsOneWidget);
      await scrollTo(tester, find.text('Largest: Housing & rent, ₹12,600.00.'));
      await scrollTo(tester, find.text(r'$40.00 → ₹3,340.00'));
      await tester.tap(find.byTooltip('Export as CSV'));
      await tester.pumpAndSettle();
      expect(find.text('goa-trip-expenses-2026-11-12.csv'), findsOneWidget);
      expect(find.text('2 rows'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(exporter.shared.single.name, 'goa-trip-expenses-2026-11-12.csv');
      expect(exporter.shared.single.mimeType, 'text/csv');
    });

    testWidgets('an empty period and a failed export', (
      WidgetTester tester,
    ) async {
      when(
        () => api.report(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => groupReport(empty: true));
      when(() => api.export(any())).thenThrow(offline);
      await pump(tester, '/groups/$gid/reports');
      expect(find.text('Nothing to report yet'), findsOneWidget);
      await tester.tap(find.byTooltip('Export as CSV'));
      await tester.pumpAndSettle();
      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );
    });
  });

  test('the export file keeps the server name', () {
    final DownloadedFile file = groupExport.toFile();
    expect(file.name, 'goa-trip-expenses-2026-11-12.csv');
    unawaited(Future<void>.value());
  });
}
