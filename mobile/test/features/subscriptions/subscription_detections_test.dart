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
    stubLabels(labels, categories: <CategoryDto>[category()]);
    stubPeople(people);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  Future<GoRouter> pump(WidgetTester tester) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      '/subscriptions/detections',
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

  testWidgets('explains each match and confirms it with changes', (
    WidgetTester tester,
  ) async {
    bool confirmed = false;
    when(() => api.detections()).thenAnswer(
      (_) async => confirmed
          ? <DetectionCandidateDto>[]
          : <DetectionCandidateDto>[detectionCandidate()],
    );
    DetectionConfirmInput? sent;
    when(() => api.confirmDetection('det-1', any()))
        .thenAnswer((Invocation i) async {
          sent = i.positionalArguments[1] as DetectionConfirmInput;
          confirmed = true;
          return subscriptionDetail(
            json: <String, Object?>{'id': 'sub-new', 'source': 'detected'},
          );
        });
    when(() => api.get('sub-new')).thenAnswer(
      (_) async => subscriptionDetail(
        json: <String, Object?>{
          'id': 'sub-new',
          'name': 'Cloudbox 200 GB',
          'source': 'detected',
        },
      ),
    );
    final GoRouter router = await pump(tester);

    expect(
      find.textContaining('Nothing is added until you confirm'),
      findsOneWidget,
    );
    expect(find.text('Cloudbox Storage'), findsOneWidget);
    expect(find.text('Strong match (92%)'), findsOneWidget);
    // Evidence in words from its stable reason codes.
    expect(find.text('6 charges, usually 30 days apart'), findsOneWidget);
    expect(
      find.text('5 of 5 gaps between charges fit this pattern'),
      findsOneWidget,
    );
    expect(
      find.text('6 of 6 amounts are within 5% of the usual amount'),
      findsOneWidget,
    );
    expect(find.text('Last charge on Nov 4, 2026'), findsOneWidget);
    expect(
      find.text('Next charge expected around Dec 4, 2026'),
      findsOneWidget,
    );
    expect(find.text('Amounts vary by up to ₹6.45.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add as subscription'));
    await tester.pumpAndSettle();
    expect(find.text('Add as a subscription'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Cloudbox 200 GB',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Add as subscription').last,
    );
    await tester.pumpAndSettle();

    // Only what changed is sent; the rest uses what was detected.
    expect(sent?.name, 'Cloudbox 200 GB');
    expect(sent?.amount, isNull);
    expect(sent?.nextRenewalDate, isNull);
    expect(sent?.paymentAccountId, isNull);
    expect(locationOf(router), '/subscriptions/sub-new');
    expect(find.text('Found in your transactions'), findsWidgets);
  });

  testWidgets('dismissing asks first and removes the match', (
    WidgetTester tester,
  ) async {
    bool dismissed = false;
    when(() => api.detections()).thenAnswer(
      (_) async => dismissed
          ? <DetectionCandidateDto>[]
          : <DetectionCandidateDto>[detectionCandidate()],
    );
    when(() => api.dismissDetection('det-1')).thenAnswer((_) async {
      dismissed = true;
    });
    await pump(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Not a subscription'));
    await tester.pumpAndSettle();
    expect(find.text('Not a subscription?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Not a subscription'));
    await tester.pumpAndSettle();

    verify(() => api.dismissDetection('det-1')).called(1);
    expect(find.text('Removed from the list.'), findsOneWidget);
    expect(find.text('Nothing to review'), findsOneWidget);
  });

  testWidgets('looking again runs in the background', (
    WidgetTester tester,
  ) async {
    when(() => api.detections())
        .thenAnswer((_) async => <DetectionCandidateDto>[]);
    when(() => api.refreshDetections()).thenAnswer((_) async {});
    await pump(tester);

    expect(find.text('Nothing to review'), findsOneWidget);
    await tester.tap(find.byTooltip('Look again'));
    await tester.pumpAndSettle();
    verify(() => api.refreshDetections()).called(1);
    expect(find.textContaining('runs in the background'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (WidgetTester tester) async {
    int loads = 0;
    when(() => api.detections()).thenAnswer((_) async {
      loads++;
      if (loads == 1) {
        throw offline;
      }
      return <DetectionCandidateDto>[
        detectionCandidate(confidenceBp: 6400, merchantId: null, next: null),
      ];
    });
    await pump(tester);

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Possible match (64%)'), findsOneWidget);
    expect(find.text('See charges'), findsNothing);
    expect(find.textContaining('Next charge expected'), findsNothing);
  });
}
