import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/search/data/search_api.dart';

import '../../helpers/router_app.dart';
import '../../helpers/search_fakes.dart';

void main() {
  late MockSearchApi api;

  setUp(() {
    api = MockSearchApi();
    when(() => api.recent()).thenAnswer((_) async => <RecentDto>[]);
  });

  void stubSearch(Results results) {
    when(
      () => api.search(
        any(),
        scope: any(named: 'scope'),
        sort: any(named: 'sort'),
        limit: any(named: 'limit'),
        save: any(named: 'save'),
      ),
    ).thenAnswer((_) async => results);
  }

  List<Override> overrides() => <Override>[
    searchApiProvider.overrideWithValue(api),
  ];

  Future<GoRouter> pump(WidgetTester tester) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      '/search',
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('typing searches without saving; submitting saves', (
    WidgetTester tester,
  ) async {
    stubSearch(
      searchResults(
        transactions: <Map<String, Object?>>[transactionHitJson()],
        accounts: <Map<String, Object?>>[
          <String, Object?>{
            'id': 'acc-1',
            'name': 'Engage Savings',
            'kind': 'savings',
          },
        ],
        users: <Map<String, Object?>>[
          <String, Object?>{
            'user_id': 'u-1',
            'display_name': 'Asha',
            'username': 'asha',
          },
        ],
      ),
    );
    final GoRouter router = await pump(tester);
    expect(find.text('Search Montra'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'e');
    await tester.pump(const Duration(seconds: 1));
    verifyNever(
      () => api.search(
        any(),
        scope: any(named: 'scope'),
        sort: any(named: 'sort'),
        limit: any(named: 'limit'),
        save: any(named: 'save'),
      ),
    );

    await tester.enterText(find.byType(TextField), 'engage');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    verify(
      () => api.search('engage', scope: 'all', sort: 'relevance', save: false),
    ).called(1);
    expect(find.text('Engage test 100% juice_bar'), findsOneWidget);
    expect(find.text('Engage Savings'), findsOneWidget);
    expect(find.text('Savings account'), findsOneWidget);
    expect(find.text('@asha'), findsOneWidget);
    expect(
      find.text(
        'People are found only by their exact username, and only if they '
        'allow it.',
      ),
      findsOneWidget,
    );

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    verify(
      () => api.search('engage', scope: 'all', sort: 'relevance', save: true),
    ).called(1);

    await tester.tap(find.text('Engage Savings'));
    await tester.pumpAndSettle();
    expect(locationOf(router), '/accounts/acc-1');
  });

  testWidgets('a section and a sort ask again without saving', (
    WidgetTester tester,
  ) async {
    stubSearch(searchResults(sort: 'name'));
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'rent');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Nothing found'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Bills'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bills'));
    await tester.pumpAndSettle();
    verify(
      () => api.search('rent', scope: 'bills', sort: 'relevance', save: false),
    ).called(1);
    await tester.ensureVisible(find.text('Best match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Best match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name').last);
    await tester.pumpAndSettle();
    verify(() => api.search('rent', scope: 'bills', sort: 'name', save: false))
        .called(1);
  });

  testWidgets('recent searches re-run and can be cleared', (
    WidgetTester tester,
  ) async {
    when(() => api.recent())
        .thenAnswer((_) async => <RecentDto>[recentSearch(query: 'groceries')]);
    when(() => api.clearRecent()).thenAnswer((_) async => 1);
    stubSearch(searchResults(query: 'groceries'));
    await pump(tester);
    expect(find.text('Recent searches'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear recent searches?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    verify(() => api.clearRecent()).called(1);
    expect(find.text('Recent searches cleared.'), findsOneWidget);

    await tester.tap(find.text('groceries'));
    await tester.pumpAndSettle();
    verify(
      () =>
          api.search('groceries', scope: 'all', sort: 'relevance', save: true),
    ).called(1);
  });

  testWidgets('a failed search offers a retry', (WidgetTester tester) async {
    when(
      () => api.search(
        any(),
        scope: any(named: 'scope'),
        sort: any(named: 'sort'),
        limit: any(named: 'limit'),
        save: any(named: 'save'),
      ),
    ).thenThrow(const ApiException(kind: ApiErrorKind.network));
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'rent');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
