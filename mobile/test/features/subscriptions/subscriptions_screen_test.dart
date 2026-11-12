import 'package:flutter/material.dart';
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
    stubLabels(labels);
    stubPeople(people);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => api.get(any())).thenAnswer(
      (Invocation i) async => subscriptionDetail(
        json: <String, Object?>{'id': i.positionalArguments.first},
      ),
    );
    when(() => api.detections())
        .thenAnswer((_) async => <DetectionCandidateDto>[]);
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: [
        subscriptionsApiProvider.overrideWithValue(api),
        accountsApiProvider.overrideWithValue(accounts),
        labelsApiProvider.overrideWithValue(labels),
        peopleApiProvider.overrideWithValue(people),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  void stubList(List<SubscriptionDto> Function(String? status) answer) {
    when(() => api.list(status: any(named: 'status'))).thenAnswer(
      (Invocation i) async => answer(i.namedArguments[#status] as String?),
    );
  }

  testWidgets('shows cost per currency, trials, renewals and the list', (
    WidgetTester tester,
  ) async {
    when(() => api.summary()).thenAnswer(
      (_) async => subscriptionSummary(
        totals: <Map<String, Object?>>[
          costTotalJson(),
          costTotalJson(
            currency: 'USD',
            monthly: '12.00',
            annual: '144.00',
            count: 1,
          ),
        ],
        trials: <Map<String, Object?>>[
          subscriptionJson(
            id: 'sub-2',
            name: 'Musicly',
            status: 'trial',
            trialEndsOn: '2026-11-12',
            nextRenewal: '2026-11-12',
          ),
        ],
        renewals: <Map<String, Object?>>[subscriptionJson()],
        pending: 2,
      ),
    );
    stubList(
      (String? status) => status == 'cancelled'
          ? <SubscriptionDto>[
              subscriptionDto(
                id: 'sub-4',
                name: 'Old gym',
                status: 'cancelled',
              ),
            ]
          : <SubscriptionDto>[
              subscriptionDto(),
              subscriptionDto(id: 'sub-3', name: 'Cloudbox', status: 'paused'),
            ],
    );
    final GoRouter router = await pump(tester, '/subscriptions');

    // Totals stay per currency.
    expect(find.text('3 subscriptions in INR'), findsOneWidget);
    expect(find.text('1 subscription in USD'), findsOneWidget);
    expect(find.textContaining('2,215.79'), findsOneWidget);
    expect(find.textContaining('144.00'), findsOneWidget);
    expect(find.text('Free trials ending soon'), findsOneWidget);
    expect(find.text('Trial ends Nov 12, 2026'), findsOneWidget);
    expect(find.text('Renewing in the next 30 days'), findsOneWidget);
    expect(find.text('2 possible subscriptions to review'), findsOneWidget);
    verify(() => api.list()).called(1);

    final Finder list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Cloudbox'),
      300,
      scrollable: list,
    );
    // Status is spelled out, not shown by colour alone.
    expect(find.text('Paused'), findsWidgets);
    expect(find.text('Next charge Nov 10, 2026'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Cancelled'),
      -300,
      scrollable: list,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cancelled'));
    await tester.pumpAndSettle();
    verify(() => api.list(status: 'cancelled')).called(1);
    await tester.scrollUntilVisible(
      find.text('Old gym'),
      300,
      scrollable: list,
    );
    await tester.tap(find.text('Old gym'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/subscriptions/sub-4');
  });

  testWidgets('the review card opens possible subscriptions', (
    WidgetTester tester,
  ) async {
    when(() => api.summary()).thenAnswer((_) async => subscriptionSummary());
    stubList((_) => <SubscriptionDto>[]);
    final GoRouter router = await pump(tester, '/subscriptions');

    // Nothing pending: the card still offers a look.
    expect(find.text('Possible subscriptions'), findsOneWidget);
    await tester.tap(find.text('Possible subscriptions'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/subscriptions/detections');
  });

  testWidgets('empty states invite adding one and explain filters', (
    WidgetTester tester,
  ) async {
    when(() => api.summary()).thenAnswer((_) async => subscriptionSummary());
    stubList((_) => <SubscriptionDto>[]);
    final GoRouter router = await pump(tester, '/subscriptions');

    expect(find.text('No subscriptions yet'), findsOneWidget);
    expect(find.text('What they cost'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Paused'));
    await tester.pumpAndSettle();
    expect(find.text('No subscriptions with this status.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Current'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add subscription'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/subscriptions/new');
  });

  testWidgets('failures can be retried separately', (
    WidgetTester tester,
  ) async {
    int summaries = 0;
    when(() => api.summary()).thenAnswer((_) async {
      summaries++;
      if (summaries == 1) {
        throw serverError(ErrorObjectCode.internalError, status: 500);
      }
      return subscriptionSummary(
        totals: <Map<String, Object?>>[costTotalJson()],
      );
    });
    int lists = 0;
    when(() => api.list(status: any(named: 'status'))).thenAnswer((_) async {
      lists++;
      if (lists == 1) {
        throw offline;
      }
      return <SubscriptionDto>[subscriptionDto()];
    });
    await pump(tester, '/subscriptions');

    expect(find.text("We couldn't load the overview."), findsOneWidget);
    expect(find.text('Try again'), findsNWidgets(2));
    await tester.tap(find.text('Try again').first);
    await tester.pumpAndSettle();
    expect(find.text('3 subscriptions in INR'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Try again'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Streamly'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Streamly'), findsWidgets);
  });
}
