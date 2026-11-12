import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/subscriptions_fakes.dart';

void main() {
  late MockSubscriptionsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockPeopleApi people;
  late MockTransactionsApi transactions;

  setUpAll(() {
    registerFinanceFallbacks();
    registerSubscriptionFallbacks();
  });

  setUp(() {
    api = MockSubscriptionsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    people = MockPeopleApi();
    transactions = MockTransactionsApi();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    stubPeople(people);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: [
        subscriptionsApiProvider.overrideWithValue(api),
        accountsApiProvider.overrideWithValue(accounts),
        labelsApiProvider.overrideWithValue(labels),
        peopleApiProvider.overrideWithValue(people),
        transactionsApiProvider.overrideWithValue(transactions),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  void stubDetail(SubscriptionDetail Function() detail) =>
      when(() => api.get('sub-1')).thenAnswer((_) async => detail());

  testWidgets('shows the server cost, look-alikes and price history', (
    WidgetTester tester,
  ) async {
    stubDetail(
      () => subscriptionDetail(
        json: subscriptionJson(
          categoryId: 'cat-groceries',
          accountId: 'acc-1',
          duplicates: <Map<String, Object?>>[
            duplicateWarningJson(
              subscriptionId: 'sub-9',
              name: 'Streamly old',
              reason: 'English text that is not shown',
            ),
          ],
          lastPayment: <String, Object?>{
            'occurred_on': '2026-10-10',
            'amount': moneyJson('499.00'),
            'transaction_id': 'tx-9',
          },
        ),
        events: <Map<String, Object?>>[
          subscriptionEventJson(
            id: 'e3',
            kind: 'payment_recorded',
            occurredOn: '2026-10-10',
            newAmount: '499.00',
            transactionId: 'tx-9',
          ),
          subscriptionEventJson(
            id: 'e2',
            kind: 'price_changed',
            occurredOn: '2026-10-01',
            oldAmount: '449.00',
            newAmount: '499.00',
          ),
          subscriptionEventJson(
            id: 'e1',
            kind: 'created',
            occurredOn: '2026-09-10',
            newAmount: '449.00',
          ),
          subscriptionEventJson(
            id: 'e5',
            kind: 'payment_recorded',
            occurredOn: '2026-11-03',
            newAmount: '499.00',
            transactionId: 'tx-10',
            note: 'Matched when the detection was confirmed',
            noteCode: 'matched_by_detection',
          ),
          subscriptionEventJson(id: 'e0', kind: 'something_new'),
        ],
      ),
    );
    when(() => api.get('sub-9')).thenAnswer(
      (_) async => subscriptionDetail(
        json: <String, Object?>{'id': 'sub-9', 'name': 'Streamly old'},
      ),
    );
    final GoRouter router = await pump(tester, '/subscriptions/sub-1');

    expect(find.text('Streamly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Renews Nov 10, 2026'), findsOneWidget);
    expect(
      find.text('It looks like Streamly old: same merchant.'),
      findsOneWidget,
    );
    expect(find.text('Per month'), findsOneWidget);
    expect(find.text('Per year'), findsOneWidget);
    expect(find.textContaining('5,988.00'), findsOneWidget);

    await reveal(tester, find.text('History'));
    expect(
      find.textContaining('The price went from ₹449.00 on Sep 10, 2026'),
      findsOneWidget,
    );
    await reveal(tester, find.text('Price changed'));
    expect(find.textContaining('₹449.00 to ₹499.00'), findsOneWidget);
    await reveal(tester, find.text('Updated'));
    expect(find.text('Payment recorded'), findsNWidgets(2));
    expect(
      find.textContaining('Linked when you added this subscription'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Open'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/subscriptions/sub-9');
  });

  testWidgets('records a charge as a payment, retrying with the same key', (
    WidgetTester tester,
  ) async {
    stubDetail(subscriptionDetail);
    when(() => api.paymentCandidates('sub-1'))
        .thenAnswer((_) async => <SubscriptionPaymentCandidate>[]);
    when(
      () => transactions.list(
        any(),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => page(<TransactionDto>[
        transaction(
          id: 'tx-new',
          amount: '549.00',
          merchant: 'Streamly charge',
        ),
      ]),
    );
    final List<(SubscriptionPaymentInput, String)> sent =
        <(SubscriptionPaymentInput, String)>[];
    when(() => api.recordPayment('sub-1', any(), key: any(named: 'key')))
        .thenAnswer((Invocation i) async {
          sent.add((
            i.positionalArguments[1] as SubscriptionPaymentInput,
            i.namedArguments[#key] as String,
          ));
          if (sent.length == 1) {
            throw offline;
          }
          return subscriptionDetail();
        });
    await pump(tester, '/subscriptions/sub-1');

    Future<void> recordWithPriceUpdate() async {
      await reveal(tester, find.text('Record a payment'));
      await tester.tap(find.text('Record a payment'));
      await tester.pumpAndSettle();
      expect(find.text('Which charge was this payment?'), findsOneWidget);
      expect(find.textContaining('No matching charges found'), findsOneWidget);
      await tester.tap(find.text('Choose another transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Streamly charge'));
      await tester.pumpAndSettle();
      expect(find.text('Record this payment?'), findsOneWidget);
      expect(
        find.textContaining('different from the current price of ₹499.00'),
        findsOneWidget,
      );
      await tester.tap(find.text('Change the price to ₹549.00'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();
    }

    await recordWithPriceUpdate();
    expect(find.textContaining('internet connection'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await recordWithPriceUpdate();

    expect(sent, hasLength(2));
    expect(sent.first.$1.transactionId, 'tx-new');
    expect(sent.first.$1.updatePrice, isTrue);
    // The retry is the same request, so it reuses the idempotency key.
    expect(sent.last.$2, sent.first.$2);
    expect(find.text('Payment recorded.'), findsOneWidget);
  });

  testWidgets('a suggested charge is linked with its reasons shown; the '
      'price follows when asked (update_price)', (WidgetTester tester) async {
    stubDetail(subscriptionDetail);
    when(() => api.paymentCandidates('sub-1')).thenAnswer(
      (_) async => <SubscriptionPaymentCandidate>[
        subscriptionCandidate(amount: '549.00'),
      ],
    );
    SubscriptionPaymentInput? sent;
    when(() => api.recordPayment('sub-1', any(), key: any(named: 'key')))
        .thenAnswer((Invocation i) async {
          sent = i.positionalArguments[1] as SubscriptionPaymentInput;
          return subscriptionDetail();
        });
    await pump(tester, '/subscriptions/sub-1');
    await reveal(tester, find.text('Record a payment'));
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'HDFC Savings · Same merchant · Same amount · 1 day before the '
        'renewal date',
      ),
      findsOneWidget,
    );
    // The merchant also appears on the detail page behind the sheet.
    await tester.tap(find.text('Streamly Media').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change the price to ₹549.00'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
    await tester.pumpAndSettle();
    expect(sent?.transactionId, 'tx-sub-1');
    expect(sent?.updatePrice, isTrue);
    expect(find.text('Payment recorded.'), findsOneWidget);
  });

  testWidgets('a linked payment is unlinked after confirming', (
    WidgetTester tester,
  ) async {
    stubDetail(
      () => subscriptionDetail(
        events: <Map<String, Object?>>[
          subscriptionEventJson(
            id: 'e2',
            kind: 'payment_recorded',
            occurredOn: '2026-10-10',
            newAmount: '499.00',
            transactionId: 'tx-9',
          ),
        ],
        payments: <Map<String, Object?>>[linkedPaymentJson()],
      ),
    );
    when(() => api.unlinkPayment('sub-1', 'tx-9'))
        .thenAnswer((_) async => subscriptionDetail());
    await pump(tester, '/subscriptions/sub-1');
    await reveal(tester, find.text('Linked payments'));
    expect(find.text('HDFC Savings'), findsWidgets);
    await tester.tap(find.byTooltip('Unlink the payment of Oct 10, 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Unlink this payment?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Unlink'));
    await tester.pumpAndSettle();
    verify(() => api.unlinkPayment('sub-1', 'tx-9')).called(1);
    expect(find.text('Payment unlinked.'), findsOneWidget);
  });

  testWidgets('a charge in another currency is not sent', (
    WidgetTester tester,
  ) async {
    stubDetail(subscriptionDetail);
    when(() => api.paymentCandidates('sub-1'))
        .thenAnswer((_) async => <SubscriptionPaymentCandidate>[]);
    when(
      () => transactions.list(
        any(),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => page(<TransactionDto>[
        transaction(id: 'tx-usd', amount: '9.99', currency: 'USD'),
      ]),
    );
    await pump(tester, '/subscriptions/sub-1');

    await reveal(tester, find.text('Record a payment'));
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose another transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Big Bazaar'));
    await tester.pumpAndSettle();
    expect(
      find.text("Choose a charge in INR, the subscription's currency."),
      findsOneWidget,
    );
    verifyNever(() => api.recordPayment(any(), any(), key: any(named: 'key')));
  });

  testWidgets('cancelling needs the provider confirmation and its date; '
      'the version shown is sent', (WidgetTester tester) async {
    stubDetail(subscriptionDetail);
    SubscriptionActionInput? input;
    int? version;
    when(
      () => api.act(
        'sub-1',
        SubscriptionAction.cancelled,
        input: any(named: 'input'),
        version: any(named: 'version'),
      ),
    ).thenAnswer((Invocation i) async {
      input = i.namedArguments[#input] as SubscriptionActionInput;
      version = i.namedArguments[#version] as int?;
      return subscriptionDetail(json: <String, Object?>{'status': 'cancelled'});
    });
    await pump(tester, '/subscriptions/sub-1');

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as checked'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text("I've started cancelling"), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Reactivate'), findsNothing);
    await tester.tap(find.text('Mark as cancelled'));
    await tester.pumpAndSettle();

    expect(find.text('Has it been cancelled?'), findsOneWidget);
    expect(find.textContaining("Montra doesn't cancel"), findsOneWidget);
    expect(find.text('Cancelled on'), findsOneWidget);
    await tester.tap(find.text("Yes, it's cancelled"));
    await tester.pumpAndSettle();
    expect(input?.confirm, isTrue);
    expect(input?.cancelledOn, LocalDates.format(LocalDates.today()));
    expect(version, 3);
    expect(find.text('Marked as cancelled.'), findsOneWidget);
  });

  testWidgets('an action no longer allowed reloads with a calm message', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    when(() => api.get('sub-1')).thenAnswer((_) async {
      loads++;
      return subscriptionDetail(
        json: <String, Object?>{'status': loads == 1 ? 'active' : 'paused'},
      );
    });
    when(
      () => api.act(
        'sub-1',
        SubscriptionAction.pause,
        input: any(named: 'input'),
        version: any(named: 'version'),
      ),
    ).thenThrow(
      serverError(
        ErrorObjectCode.domainRuleViolation,
        details: const <Detail>[
          Detail(
            code: 'invalid_status_transition',
            message: 'A subscription cannot move from paused to paused.',
            params: <String, String>{'from': 'paused', 'to': 'paused'},
          ),
        ],
      ),
    );
    await pump(tester, '/subscriptions/sub-1');

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("This can't change from paused to paused."),
      findsOneWidget,
    );
    expect(loads, 2);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('ticking a cancellation step changes only that step', (
    WidgetTester tester,
  ) async {
    stubDetail(
      () => subscriptionDetail(
        json: subscriptionJson(
          status: 'cancellation_pending',
          url: 'https://streamly.example/cancel',
          instructions: 'Cancel from the account page.',
          checklist: <Map<String, Object?>>[
            <String, Object?>{'item': 'Download history', 'done': false},
            <String, Object?>{'item': 'Remove card', 'done': true},
          ],
          events: <Map<String, Object?>>[],
        ),
      ),
    );
    (int, ChecklistItemPatch)? sent;
    when(() => api.updateChecklistItem('sub-1', any(), any()))
        .thenAnswer((Invocation i) async {
          sent = (
            i.positionalArguments[1] as int,
            i.positionalArguments[2] as ChecklistItemPatch,
          );
          return subscriptionDetail();
        });
    await pump(tester, '/subscriptions/sub-1');

    expect(find.text('Being cancelled'), findsOneWidget);
    expect(find.textContaining("You've started cancelling"), findsOneWidget);
    expect(find.text('Cancel from the account page.'), findsOneWidget);
    await reveal(tester, find.text('Download history'));
    await tester.tap(find.text('Download history'));
    await tester.pumpAndSettle();

    expect(sent?.$1, 0);
    expect(sent?.$2.toJson(), <String, Object?>{'done': true, 'version': 3});
    verifyNever(() => api.update(any(), any()));

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await reveal(tester, find.text('Copy link'));
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, 'https://streamly.example/cancel');
    expect(find.text('Link copied.'), findsOneWidget);
  });

  testWidgets('a shared subscription is read-only', (
    WidgetTester tester,
  ) async {
    stubDetail(
      () => subscriptionDetail(json: <String, Object?>{'owned': false}),
    );
    await pump(tester, '/subscriptions/sub-1');

    expect(find.text('Shared with you'), findsOneWidget);
    expect(find.textContaining('Only its owner can change it'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('More options'), findsNothing);
    expect(find.text('Record a payment'), findsNothing);
  });

  testWidgets('load failures offer a retry', (WidgetTester tester) async {
    int loads = 0;
    when(() => api.get('sub-1')).thenAnswer((_) async {
      loads++;
      if (loads == 1) {
        throw offline;
      }
      return subscriptionDetail();
    });
    await pump(tester, '/subscriptions/sub-1');

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Streamly'), findsOneWidget);
    expect(find.text('No payments linked yet.'), findsOneWidget);
  });
}
