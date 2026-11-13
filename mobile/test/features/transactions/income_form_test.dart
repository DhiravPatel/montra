import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

/// Adding income (TXN-006): `POST /transactions` with `type: income`, an
/// income category and an `Idempotency-Key`.
void main() {
  late MockTransactionsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockPaymentMethodsApi methods;
  late List<(TransactionInput, String)> sent;

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    api = MockTransactionsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    methods = MockPaymentMethodsApi();
    sent = <(TransactionInput, String)>[];
    stubLabels(
      labels,
      categories: <CategoryDto>[
        category(),
        category(
          id: 'cat-salary',
          name: 'Salary',
          systemKey: 'salary',
          kind: 'income',
        ),
      ],
    );
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
    ).thenAnswer((_) async => page(<TransactionDto>[]));
    when(() => api.create(any(), key: any(named: 'key')))
        .thenAnswer((Invocation i) async {
          final TransactionInput input =
              i.positionalArguments.first as TransactionInput;
          sent.add((input, i.namedArguments[#key] as String));
          return createResult(
            transaction(
              id: 'tx-income',
              type: 'income',
              direction: 'inflow',
              amount: input.amount,
              categoryId: input.categoryId,
              categoryName: 'Salary',
              merchant: null,
              description: input.description,
            ),
          );
        });
  });

  List<Override> overrides() => <Override>[
    transactionsApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    labelsApiProvider.overrideWithValue(labels),
    paymentMethodsApiProvider.overrideWithValue(methods),
  ];

  Future<GoRouter> open(
    WidgetTester tester, {
    String type = 'income',
    Locale locale = const Locale('en'),
  }) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      '/transactions',
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    unawaited(r.router.push<Object?>('/transactions/new?type=$type'));
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('records income in an income category with an idempotency '
      'key and says so', (WidgetTester tester) async {
    final GoRouter router = await open(tester);

    expect(find.text('New income'), findsOneWidget);
    expect(find.text('HDFC Savings'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '85000',
    );
    await tapVisible(tester, find.text('Category'));
    // Only income categories are offered for income.
    expect(find.text('Groceries'), findsNothing);
    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description (optional)'),
      'November salary',
    );
    await tapVisible(tester, find.text('Save'));

    final (TransactionInput input, String key) = sent.single;
    expect(input.typeValue, TransactionInputType.income);
    expect(input.amount, '85000.00');
    expect(input.accountId, 'acc-1');
    expect(input.categoryId, 'cat-salary');
    expect(input.description, 'November salary');
    expect(key.length, greaterThanOrEqualTo(8));
    expect(find.text('Income saved.'), findsOneWidget);
    expect(locationOf(router), '/transactions');
  });

  testWidgets('switching an expense to income keeps the amount and drops an '
      'expense category', (WidgetTester tester) async {
    await open(tester, type: 'expense');
    expect(find.text('New expense'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '1200.5',
    );
    await tapVisible(tester, find.text('Category'));
    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    await tapVisible(tester, find.text('Income'));
    expect(find.text('New income'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    await tapVisible(tester, find.text('Save'));

    expect(sent.single.$1.typeValue, TransactionInputType.income);
    expect(sent.single.$1.amount, '1200.50');
    expect(sent.single.$1.categoryId, isNull);
  });

  testWidgets('a failed save keeps the form; trying again reuses the key', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    when(() => api.create(any(), key: any(named: 'key')))
        .thenAnswer((Invocation i) async {
          sent.add((
            i.positionalArguments.first as TransactionInput,
            i.namedArguments[#key] as String,
          ));
          if (++calls == 1) {
            throw offline;
          }
          return createResult(transaction(type: 'income', direction: 'inflow'));
        });
    final GoRouter router = await open(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '500');
    await tapVisible(tester, find.text('Save'));

    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('New income'), findsOneWidget);

    await tapVisible(tester, find.text('Save'));
    expect(sent, hasLength(2));
    expect(sent[1].$2, sent[0].$2);
    expect(find.text('Income saved.'), findsOneWidget);
    expect(locationOf(router), '/transactions');
  });

  testWidgets('a refused amount is shown on its field', (
    WidgetTester tester,
  ) async {
    when(() => api.create(any(), key: any(named: 'key'))).thenThrow(
      serverError(
        ErrorObjectCode.validationError,
        details: const <Detail>[
          Detail(field: 'body.amount', message: 'The amount is too large.'),
        ],
      ),
    );
    await open(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '1');
    await tapVisible(tester, find.text('Save'));
    expect(find.text('The amount is too large.'), findsOneWidget);
    expect(find.text('Income saved.'), findsNothing);
  });

  testWidgets('an empty amount is not sent', (WidgetTester tester) async {
    await open(tester);
    await tapVisible(tester, find.text('Save'));
    verifyNever(() => api.create(any(), key: any(named: 'key')));
    expect(find.text('New income'), findsOneWidget);
  });

  testWidgets('with no account yet, income cannot be saved and the form '
      'says to choose one', (WidgetTester tester) async {
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[]);
    await open(tester);
    expect(
      find.text('Choose the account first to set the currency.'),
      findsOneWidget,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '500');
    await tapVisible(tester, find.text('Save'));
    verifyNever(() => api.create(any(), key: any(named: 'key')));
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('the income form fits at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, locale: locale);
      final Finder list = find.byType(Scrollable).last;
      for (int i = 0; i < 8; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
