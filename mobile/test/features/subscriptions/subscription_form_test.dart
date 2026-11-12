import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
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
    when(() => api.summary()).thenAnswer((_) async => subscriptionSummary());
    when(() => api.list(status: any(named: 'status')))
        .thenAnswer((_) async => <SubscriptionDto>[]);
  });

  Future<GoRouter> pump(WidgetTester tester, String push) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      '/subscriptions',
      overrides: [
        subscriptionsApiProvider.overrideWithValue(api),
        accountsApiProvider.overrideWithValue(accounts),
        labelsApiProvider.overrideWithValue(labels),
        peopleApiProvider.overrideWithValue(people),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    unawaited(r.router.push<Object?>(push));
    await tester.pumpAndSettle();
    return r.router;
  }

  /// Brings [finder] into view with no text field focused (a focused field
  /// would scroll itself back on screen).
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await reveal(tester, find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds a custom-cycle subscription and opens it', (
    WidgetTester tester,
  ) async {
    SubscriptionInput? sent;
    String? key;
    when(() => api.create(any(), key: any(named: 'key')))
        .thenAnswer((Invocation i) async {
          sent = i.positionalArguments.first as SubscriptionInput;
          key = i.namedArguments[#key] as String?;
          return subscriptionDetail(
            json: <String, Object?>{'id': 'sub-new', 'name': 'Musicly'},
          );
        });
    when(() => api.get('sub-new')).thenAnswer(
      (_) async => subscriptionDetail(
        json: <String, Object?>{'id': 'sub-new', 'name': 'Musicly'},
      ),
    );
    final GoRouter router = await pump(tester, '/subscriptions/new');

    expect(find.text('Add subscription'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Musicly',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price per billing cycle'),
      '199',
    );
    final Finder cycle = find.byType(
      DropdownButtonFormField<SubscriptionInputBillingFrequency>,
    );
    await reveal(tester, cycle);
    await tester.tap(cycle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repeats every'),
      '10',
    );
    final Finder unit = find.byType(
      DropdownButtonFormField<SubscriptionInputIntervalUnit>,
    );
    await reveal(tester, unit);
    await tester.tap(unit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Days').last);
    await tester.pumpAndSettle();

    final Finder step = find.widgetWithText(TextField, 'Add a step');
    await reveal(tester, step);
    await tester.enterText(step, 'Download playlists');
    await tester.tap(find.byTooltip('Add this step'));
    await tester.pumpAndSettle();
    expect(find.text('Download playlists'), findsOneWidget);
    await save(tester);

    final SubscriptionInput input = sent!;
    expect(input.name, 'Musicly');
    expect(input.amount, '199.00');
    expect(input.currency, 'INR');
    expect(input.billingFrequency, SubscriptionInputBillingFrequency.custom);
    expect(input.intervalCount, 10);
    expect(input.intervalUnit, SubscriptionInputIntervalUnit.day);
    expect(input.startDate, LocalDates.format(LocalDates.today()));
    expect(input.reminderDaysBefore, <int>[3]);
    expect(input.cancellationChecklist?.single.item, 'Download playlists');
    expect(input.version, isNull);
    expect(key, hasLength(greaterThanOrEqualTo(8)));
    // The new subscription opens so its cost and look-alikes are visible.
    expect(locationOf(router), '/subscriptions/sub-new');
    expect(find.text('Subscription added.'), findsOneWidget);
  });

  testWidgets('checks required fields and the cancellation page first', (
    WidgetTester tester,
  ) async {
    await pump(tester, '/subscriptions/new');

    final Finder url = find.widgetWithText(
      TextFormField,
      'Cancellation page (optional)',
    );
    await reveal(tester, url);
    await tester.enterText(url, 'http://example.com/cancel');
    await save(tester);

    expect(
      find.text("Use the provider's official https:// page."),
      findsOneWidget,
    );
    expect(find.text('This field is required.'), findsOneWidget);
    verifyNever(() => api.create(any(), key: any(named: 'key')));
  });

  testWidgets('editing sends only the changes with the version; removed '
      'links are cleared', (WidgetTester tester) async {
    when(() => api.get('sub-1')).thenAnswer(
      (_) async => subscriptionDetail(
        json: subscriptionJson(
          invoiceFileId: 'file-1',
          categoryId: 'cat-groceries',
          accountId: 'acc-1',
          url: 'https://streamly.example/cancel',
          checklist: <Map<String, Object?>>[
            <String, Object?>{'item': 'Download history', 'done': true},
          ],
          events: <Map<String, Object?>>[],
        ),
      ),
    );
    SubscriptionPatch? sent;
    when(() => api.update('sub-1', any())).thenAnswer((Invocation i) async {
      sent = i.positionalArguments[1] as SubscriptionPatch;
      return subscriptionDetail();
    });
    final GoRouter router = await pump(tester, '/subscriptions/sub-1/edit');

    expect(find.text('Edit subscription'), findsOneWidget);
    expect(find.text('Streamly Media'), findsOneWidget);
    expect(find.text('HDFC Savings'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Streamly Family',
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.byTooltip('Clear Paid from'));
    await tester.tap(find.byTooltip('Clear Paid from'));
    await tester.pumpAndSettle();
    await save(tester);

    // The invoice and everything unchanged stay out of the request.
    expect(sent?.toJson(), <String, Object?>{
      'name': 'Streamly Family',
      'clear': <String>['payment_account_id'],
      'version': 3,
    });
    expect(locationOf(router), '/subscriptions');
    expect(find.text('Subscription saved.'), findsOneWidget);
  });

  testWidgets('a cancelled subscription can correct its cancellation date', (
    WidgetTester tester,
  ) async {
    when(() => api.get('sub-1')).thenAnswer(
      (_) async => subscriptionDetail(
        json: subscriptionJson(
          status: 'cancelled',
          nextRenewal: null,
          cancelledOn: '2026-11-01',
          events: <Map<String, Object?>>[],
        ),
      ),
    );
    await pump(tester, '/subscriptions/sub-1/edit');
    await reveal(tester, find.text('Cancelled on'));
    expect(find.text('Nov 1, 2026'), findsOneWidget);
    expect(find.textContaining('Correct the date'), findsOneWidget);
    // Saving without changes sends nothing.
    await save(tester);
    expect(find.text('Nothing changed.'), findsOneWidget);
    verifyNever(() => api.update(any(), any()));
  });

  testWidgets('a newer version is loaded before saving again', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    when(() => api.get('sub-1')).thenAnswer((_) async {
      loads++;
      return subscriptionDetail(
        json: loads == 1
            ? const <String, Object?>{}
            : <String, Object?>{'name': 'Streamly Duo', 'version': 4},
      );
    });
    final List<SubscriptionPatch> sent = <SubscriptionPatch>[];
    when(() => api.update('sub-1', any())).thenAnswer((Invocation i) async {
      sent.add(i.positionalArguments[1] as SubscriptionPatch);
      if (sent.length == 1) {
        throw serverError(ErrorObjectCode.versionConflict, status: 409);
      }
      return subscriptionDetail();
    });
    await pump(tester, '/subscriptions/sub-1/edit');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Streamly Plus',
    );
    await save(tester);
    expect(sent.single.toJson(), <String, Object?>{
      'name': 'Streamly Plus',
      'version': 3,
    });
    expect(find.textContaining('changed somewhere else'), findsOneWidget);
    expect(find.text('Streamly Duo'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Streamly Plus',
    );
    await tester.pumpAndSettle();
    await save(tester);
    expect(sent.last.toJson(), <String, Object?>{
      'name': 'Streamly Plus',
      'version': 4,
    });
  });

  testWidgets('server field errors appear next to the field', (
    WidgetTester tester,
  ) async {
    when(() => api.create(any(), key: any(named: 'key'))).thenThrow(
      serverError(
        ErrorObjectCode.validationError,
        details: const <Detail>[
          Detail(
            field: 'body.trial_ends_on',
            message: 'The trial cannot end before the start date.',
          ),
        ],
      ),
    );
    await pump(tester, '/subscriptions/new');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Musicly',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price per billing cycle'),
      '199',
    );
    await save(tester);

    expect(
      find.text('The trial cannot end before the start date.'),
      findsOneWidget,
    );
  });

  testWidgets('shows load errors with a retry', (WidgetTester tester) async {
    int loads = 0;
    when(() => api.get('sub-1')).thenAnswer((_) async {
      loads++;
      if (loads == 1) {
        throw offline;
      }
      return subscriptionDetail();
    });
    await pump(tester, '/subscriptions/sub-1/edit');

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Name'), findsOneWidget);
  });
}
