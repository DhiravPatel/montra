import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/saved_filters/saved_filters.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/search/data/search_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/saved_filters_fakes.dart';
import '../../helpers/search_fakes.dart';

const String acc = 'a0000000-0000-4000-8000-000000000001';

void main() {
  late MockTransactionsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockPaymentMethodsApi methods;
  late MockSavedFiltersApi saved;
  late MockSearchApi search;

  setUpAll(() {
    registerFinanceFallbacks();
    registerFallbackValue(SavedFilterScope.transactions);
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    api = MockTransactionsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    methods = MockPaymentMethodsApi();
    saved = MockSavedFiltersApi();
    search = MockSearchApi();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => methods.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <PaymentMethodDto>[]);
    when(
      () => api.list(
        any(),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => page(<TransactionDto>[transaction()]));
    when(() => search.recent()).thenAnswer((_) async => <RecentDto>[]);
  });

  List<Override> overrides() => <Override>[
    transactionsApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    labelsApiProvider.overrideWithValue(labels),
    paymentMethodsApiProvider.overrideWithValue(methods),
    savedFiltersApiProvider.overrideWithValue(saved),
    searchApiProvider.overrideWithValue(search),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  testWidgets('saves the current filters under a name; a taken name is '
      'shown on the field', (WidgetTester tester) async {
    when(() => saved.list(SavedFilterScope.transactions))
        .thenAnswer((_) async => <SavedFilterDto>[]);
    int attempts = 0;
    when(() => saved.create(any(), any(), any())).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        throw const ApiException(
          kind: ApiErrorKind.server,
          code: ErrorObjectCode.conflict,
          statusCode: 409,
        );
      }
      return savedFilter('Groceries', <String, Object?>{});
    });
    await pump(tester, '/transactions?type=expense&account_id=$acc');

    await tester.tap(find.byTooltip('Saved filters'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
    await tester.tap(find.text('Save current filters'));
    await tester.pumpAndSettle();

    // Blank names never reach the server.
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);
    verifyNever(() => saved.create(any(), any(), any()));

    await tester.enterText(find.byType(TextFormField), ' Groceries ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('You already saved one with this name. Choose another name.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved “Groceries”.'), findsOneWidget);
    verify(
      () => saved.create(
        SavedFilterScope.transactions,
        ' Groceries ',
        <String, Object?>{
          'type': <String>['expense'],
          'account_id': <String>[acc],
        },
      ),
    ).called(2);
  });

  testWidgets('applies a saved filter (also one saved on the web) and '
      'marks unreadable ones', (WidgetTester tester) async {
    when(() => saved.list(SavedFilterScope.transactions)).thenAnswer(
      (_) async => <SavedFilterDto>[
        savedFilter('Broken', <Object?>[1, 2], id: 's0'),
        savedFilter('Big spends', <String, Object?>{
          'sort': 'amount_desc',
          'type': <String>['expense'],
          'q': 'rent',
        }),
      ],
    );
    final GoRouter router = await pump(tester, '/transactions');
    await tester.tap(find.byTooltip('Saved filters'));
    await tester.pumpAndSettle();
    expect(
      find.text('Can’t be used in this version of the app.'),
      findsOneWidget,
    );
    expect(find.text('Search: “rent” · 1 filter'), findsOneWidget);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
    await tester.tap(find.text('Big spends'));
    await tester.pumpAndSettle();
    final Uri location = Uri.parse(locationOf(router));
    expect(location.queryParameters, <String, String>{
      'type': 'expense',
      'q': 'rent',
      'sort': 'amount_desc',
    });
    expect(find.text('Showing “Big spends”.'), findsOneWidget);
  });

  testWidgets('deletes after confirming; one already deleted elsewhere is '
      'treated as gone', (WidgetTester tester) async {
    final List<SavedFilterDto> items = <SavedFilterDto>[
      savedFilter('Old', <String, Object?>{
        'type': <String>['income'],
      }),
    ];
    when(() => saved.list(SavedFilterScope.transactions))
        .thenAnswer((_) async => List<SavedFilterDto>.of(items));
    when(() => saved.delete('s1')).thenAnswer((_) async {
      items.clear();
      throw const ApiException(
        kind: ApiErrorKind.server,
        code: ErrorObjectCode.notFound,
        statusCode: 404,
      );
    });
    await pump(tester, '/transactions');
    await tester.tap(find.byTooltip('Saved filters'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete “Old”'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Old”?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => saved.delete(any()));

    await tester.tap(find.byTooltip('Delete “Old”'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('“Old” was already deleted.'), findsOneWidget);
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('a drill-down to spending without a payment method shows and '
      'sends payment_method_id=none', (WidgetTester tester) async {
    await pump(tester, '/transactions?payment_method_id=none');
    expect(find.text('No payment method'), findsOneWidget);
    final TransactionFilter sent =
        verify(
              () => api.list(
                captureAny(),
                cursor: any(named: 'cursor'),
                limit: any(named: 'limit'),
              ),
            ).captured.last
            as TransactionFilter;
    expect(sent.toQuery()['payment_method_id'], 'none');
  });

  testWidgets('search runs a saved search with its section and order', (
    WidgetTester tester,
  ) async {
    when(() => saved.list(SavedFilterScope.search)).thenAnswer(
      (_) async => <SavedFilterDto>[
        savedFilter('Rent bills', <String, Object?>{
          'q': 'rent',
          'scope': 'bills',
          'sort': 'recent',
        }, scope: 'search'),
      ],
    );
    when(
      () => search.search(
        any(),
        scope: any(named: 'scope'),
        sort: any(named: 'sort'),
        limit: any(named: 'limit'),
        save: any(named: 'save'),
      ),
    ).thenAnswer((_) async => searchResults(query: 'rent'));
    await pump(tester, '/search');
    await tester.tap(find.byTooltip('Saved searches'));
    await tester.pumpAndSettle();
    expect(find.text('Save this search'), findsOneWidget);
    expect(
      find.text('Type at least 2 characters to save a search.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Rent bills'));
    await tester.pumpAndSettle();
    verify(
      () => search.search('rent', scope: 'bills', sort: 'recent', save: true),
    ).called(1);
  });
}
