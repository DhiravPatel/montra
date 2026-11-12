import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/subscriptions_fakes.dart';

/// Subscription screens at 200 % text in English and Hindi must lay out
/// without overflow (overflow is reported as a test failure).
void main() {
  late MockSubscriptionsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockPeopleApi people;

  setUpAll(() {
    registerFinanceFallbacks();
    registerSubscriptionFallbacks();
  });

  setUp(() {
    api = MockSubscriptionsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    people = MockPeopleApi();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    stubPeople(people);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    final Map<String, Object?> long = subscriptionJson(
      name: 'A subscription with a rather long name for its service',
      amount: '123456.78',
      monthly: '123456.78',
      annual: '1481481.36',
      status: 'cancellation_pending',
      trialEndsOn: '2026-11-12',
      url: 'https://very-long-provider-domain.example/account/cancel',
      instructions: 'Open the account page, choose Plans and then Cancel.',
      checklist: <Map<String, Object?>>[
        <String, Object?>{'item': 'Download everything first', 'done': false},
      ],
      duplicates: <Map<String, Object?>>[
        duplicateWarningJson(
          subscriptionId: 'sub-9',
          name: 'Another long subscription name',
          reasonCode: 'same_price_and_cycle',
        ),
      ],
      lastPayment: <String, Object?>{
        'occurred_on': '2026-10-10',
        'amount': moneyJson('123456.78'),
        'transaction_id': 'tx-9',
      },
      payments: <Map<String, Object?>>[
        linkedPaymentJson(
          amount: '123456.78',
          accountName: 'A savings account with a very long name indeed',
        ),
      ],
      events: <Map<String, Object?>>[
        subscriptionEventJson(
          id: 'e3',
          kind: 'payment_recorded',
          occurredOn: '2026-10-10',
          newAmount: '123456.78',
          transactionId: 'tx-9',
          noteCode: 'matched_by_detection',
          note: 'Matched by detection',
        ),
        subscriptionEventJson(
          id: 'e2',
          kind: 'price_changed',
          oldAmount: '99999.00',
          newAmount: '123456.78',
        ),
        subscriptionEventJson(
          id: 'e1',
          kind: 'created',
          occurredOn: '2026-09-10',
          newAmount: '99999.00',
        ),
      ],
    );
    when(() => api.summary()).thenAnswer(
      (_) async => subscriptionSummary(
        totals: <Map<String, Object?>>[
          costTotalJson(monthly: '123456.78', annual: '1481481.36'),
        ],
        trials: <Map<String, Object?>>[long],
        renewals: <Map<String, Object?>>[long],
        pending: 3,
      ),
    );
    when(() => api.list(status: any(named: 'status'))).thenAnswer(
      (_) async => <SubscriptionDto>[SubscriptionDto.fromJson(long)],
    );
    when(() => api.get(any()))
        .thenAnswer((_) async => SubscriptionDetail.fromJson(long));
    when(() => api.paymentCandidates(any())).thenAnswer(
      (_) async => <SubscriptionPaymentCandidate>[
        subscriptionCandidate(
          merchant: 'A merchant with a remarkably long trading name',
          amount: '123456.78',
          daysFromRenewal: 4,
        ),
      ],
    );
    when(() => api.detections()).thenAnswer(
      (_) async => <DetectionCandidateDto>[
        detectionCandidate(label: 'A merchant with a very long label indeed'),
      ],
    );
  });

  List<Override> overrides() => <Override>[
    subscriptionsApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    labelsApiProvider.overrideWithValue(labels),
    peopleApiProvider.overrideWithValue(people),
  ];

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('subscription screens fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final ({Widget app, GoRouter router}) r = routedApp(
        '/home',
        overrides: overrides(),
        locale: locale,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      for (final String location in <String>[
        '/subscriptions',
        '/subscriptions/sub-1',
        '/subscriptions/new',
        '/subscriptions/sub-1/edit',
        '/subscriptions/detections',
      ]) {
        unawaited(r.router.push<Object?>(location));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
        for (int i = 0; i < 10; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: location);
        r.router.pop();
        await tester.pumpAndSettle();
      }

      // The payment suggestions sheet.
      unawaited(r.router.push<Object?>('/subscriptions/sub-1'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(Icons.link),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.link));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'payment sheet');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'payment sheet');
    });
  }
}
