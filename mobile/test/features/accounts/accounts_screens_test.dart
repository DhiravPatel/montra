import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

BalanceTotals totals() => BalanceTotals.fromJson(<String, Object?>{
  'currency': 'INR',
  'assets': moneyJson('25000.50'),
  'liabilities': moneyJson('3200.00'),
  'net_worth': moneyJson('21800.50'),
  'account_count': 2,
});

BalanceReport history(String id) => BalanceReport.fromJson(<String, Object?>{
  'account_id': id,
  'as_of': '2026-11-04',
  'balance': moneyJson('-3200.00'),
  'balance_source': 'calculated',
  'verified': false,
  'history': <Object?>[
    <String, Object?>{'date': '2026-11-03', 'balance': moneyJson('0.00')},
    <String, Object?>{'date': '2026-11-04', 'balance': moneyJson('-3200.00')},
  ],
});

void main() {
  late MockAccountsApi api;
  late MockLabelsApi labels;

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    api = MockAccountsApi();
    labels = MockLabelsApi();
    stubLabels(labels);
    when(() => api.totals()).thenAnswer((_) async => <BalanceTotals>[totals()]);
  });

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: [
        accountsApiProvider.overrideWithValue(api),
        labelsApiProvider.overrideWithValue(labels),
      ],
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  group('accounts list', () {
    testWidgets('groups accounts by type and shows liabilities as owed', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer(
        (_) async => <AccountDto>[
          account(),
          account(
            id: 'card',
            name: 'Visa card',
            type: 'credit_card',
            balance: '-3200.00',
          ),
        ],
      );
      await pump(tester, '/accounts');

      expect(find.text('Savings account (1)'), findsOneWidget);
      expect(find.text('Credit card (1)'), findsOneWidget);
      expect(find.text('HDFC Savings'), findsOneWidget);
      expect(find.text('₹25,000.50'), findsWidgets);
      // The card reads "Owed ₹3,200.00", not a bare negative number.
      expect(find.text('₹3,200.00'), findsWidgets);
      expect(find.text('Owed'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Owed, 3,200\.00 INR')),
        findsOneWidget,
      );
      // Server totals, never added up on the device.
      expect(find.text('Totals (tracked)'), findsOneWidget);
      expect(find.text('₹21,800.50'), findsOneWidget);
    });

    testWidgets('shows an empty state and can include archived accounts', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer((_) async => <AccountDto>[]);
      when(() => api.list(includeArchived: true))
          .thenAnswer((_) async => <AccountDto>[account(status: 'archived')]);
      await pump(tester, '/accounts');

      expect(find.text('No accounts yet'), findsOneWidget);
      await tester.tap(find.text('Show archived and closed accounts'));
      await tester.pumpAndSettle();

      verify(() => api.list(includeArchived: true)).called(1);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('shows an offline state with a retry', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => api.list()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <AccountDto>[account()];
      });
      await pump(tester, '/accounts');

      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('HDFC Savings'), findsOneWidget);
    });
  });

  group('account form', () {
    testWidgets('creates a credit card with the amount owed as negative', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer((_) async => <AccountDto>[]);
      AccountInput? sent;
      String? key;
      when(() => api.create(any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments.first as AccountInput;
            key = i.namedArguments[#key] as String;
            return account(type: 'credit_card', balance: '-2500.00');
          });
      final GoRouter router = await pump(tester, '/accounts');
      unawaited(router.push<Object?>('/accounts/new'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account name'),
        'Visa card',
      );
      await tester.tap(find.text('Bank account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Credit card').last);
      await tester.pumpAndSettle();
      expect(find.text('I owe this'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount owed now'),
        '2500',
      );
      await tester.ensureVisible(find.text('Add account').last);
      await tester.tap(find.text('Add account').last);
      await tester.pumpAndSettle();

      expect(sent?.name, 'Visa card');
      expect(sent?.accountType, AccountInputAccountType.creditCard);
      expect(sent?.currency, 'INR');
      expect(sent?.openingBalance, '-2500.00');
      expect(key, isNotEmpty);
      expect(find.text('Account added.'), findsOneWidget);
      expect(locationOf(router), '/accounts');
    });

    testWidgets('shows server field errors next to the field', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer((_) async => <AccountDto>[]);
      when(() => api.create(any(), key: any(named: 'key'))).thenThrow(
        serverError(
          ErrorObjectCode.validationError,
          details: const <Detail>[
            Detail(field: 'body.name', message: 'Name is required.'),
          ],
        ),
      );
      final GoRouter router = await pump(tester, '/accounts');
      unawaited(router.push<Object?>('/accounts/new'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account name'),
        ' x ',
      );
      await tester.ensureVisible(find.text('Add account').last);
      await tester.tap(find.text('Add account').last);
      await tester.pumpAndSettle();

      expect(find.text('Name is required.'), findsOneWidget);
    });

    testWidgets('a stale edit reloads the account and says so', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer((_) async => <AccountDto>[account()]);
      int gets = 0;
      when(() => api.get('acc-1')).thenAnswer((_) async {
        gets++;
        return account(
          version: gets,
          name: gets == 1 ? 'HDFC Savings' : 'HDFC Main',
        );
      });
      AccountPatch? patch;
      when(() => api.update('acc-1', any())).thenAnswer((Invocation i) async {
        patch = i.positionalArguments[1] as AccountPatch;
        throw serverError(ErrorObjectCode.versionConflict, status: 409);
      });
      final GoRouter router = await pump(tester, '/accounts');
      unawaited(router.push<Object?>('/accounts/acc-1/edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account name'),
        'Salary account',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(patch?.version, 1);
      expect(patch?.name, 'Salary account');
      expect(patch?.currency, isNull);
      expect(
        find.textContaining('we loaded the latest version'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'HDFC Main'), findsOneWidget);
    });
  });

  group('account detail', () {
    testWidgets('shows the card liability, history and recent transactions', (
      WidgetTester tester,
    ) async {
      final AccountDto card = account(
        id: 'card',
        name: 'Visa card',
        type: 'credit_card',
        balance: '-3200.00',
        creditLimit: '50000.00',
        availableCredit: '46800.00',
      );
      when(() => api.list()).thenAnswer((_) async => <AccountDto>[card]);
      when(() => api.get('card')).thenAnswer((_) async => card);
      when(() => api.balance('card', from: any(named: 'from')))
          .thenAnswer((_) async => history('card'));
      when(() => api.transactions('card', limit: 10)).thenAnswer(
        (_) async => CursorPage<TransactionDto>(<TransactionDto>[
          transaction(accountId: 'card', accountName: 'Visa card'),
        ], null),
      );
      when(() => api.archive('card', version: any(named: 'version')))
          .thenAnswer(
            (_) async => account(
              id: 'card',
              name: 'Visa card',
              type: 'credit_card',
              status: 'archived',
            ),
          );
      final GoRouter router = await pump(tester, '/accounts');
      unawaited(router.push<Object?>('/accounts/card'));
      await tester.pumpAndSettle();

      expect(find.text('Credit limit'), findsOneWidget);
      expect(find.text('₹46,800.00'), findsOneWidget);
      expect(find.text('Owed'), findsOneWidget);
      const String summary =
          'The balance went from ₹0.00 on Nov 3, 2026 to -₹3,200.00 on '
          'Nov 4, 2026. Lowest -₹3,200.00, highest ₹0.00.';
      await tester.scrollUntilVisible(find.text(summary), 200);
      expect(find.text(summary), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Big Bazaar'), 200);
      expect(find.text('Big Bazaar'), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive this account?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      verify(() => api.archive('card', version: 1)).called(1);
      expect(find.text('Account archived.'), findsOneWidget);
    });

    testWidgets('shows when it was last reconciled and imported, with the '
        'reconciled balance', (WidgetTester tester) async {
      final AccountDto acc = AccountDto.fromJson(<String, Object?>{
        ...account().toJson(),
        'last_reconciled_at': '2026-11-12T06:04:12Z',
        'last_reconciled_balance': moneyJson('106209.50'),
        'last_import_at': '2026-11-12T06:03:03Z',
      });
      when(() => api.list()).thenAnswer((_) async => <AccountDto>[acc]);
      when(() => api.get('acc-1')).thenAnswer((_) async => acc);
      when(() => api.balance('acc-1', from: any(named: 'from')))
          .thenAnswer((_) async => history('acc-1'));
      when(() => api.transactions('acc-1', limit: 10)).thenAnswer(
        (_) async => const CursorPage<TransactionDto>(<TransactionDto>[], null),
      );
      final GoRouter router = await pump(tester, '/accounts');
      unawaited(router.push<Object?>('/accounts/acc-1'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Balance when last reconciled'),
        200,
      );
      expect(find.text('₹1,06,209.50'), findsOneWidget);
      expect(find.text('Last reconciled'), findsOneWidget);
    });

    testWidgets('shows a not-found error for a missing account', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer((_) async => <AccountDto>[]);
      when(() => api.get('gone')).thenThrow(
        serverError(
          ErrorObjectCode.notFound,
          status: 404,
          requestId: 'req-404',
        ),
      );
      final GoRouter router = await pump(tester, '/accounts');
      unawaited(router.push<Object?>('/accounts/gone'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Reference: req-404'), findsOneWidget);
    });
  });

  group('balance adjustment', () {
    testWidgets('sets a corrected balance with a reason and a key', (
      WidgetTester tester,
    ) async {
      when(() => api.list()).thenAnswer((_) async => <AccountDto>[account()]);
      when(() => api.get('acc-1')).thenAnswer((_) async => account());
      AdjustmentInput? sent;
      when(() => api.adjust('acc-1', any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments[1] as AdjustmentInput;
            return account(balance: '24000.00');
          });
      final GoRouter router = await pump(tester, '/accounts');
      unawaited(router.push<Object?>('/accounts/acc-1/adjust'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correct balance'),
        '24000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason'),
        'ok',
      );
      await tester.ensureVisible(find.text('Save adjustment'));
      await tester.tap(find.text('Save adjustment'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a reason of at least 3 characters.'),
        findsOneWidget,
      );
      verifyNever(() => api.adjust(any(), any(), key: any(named: 'key')));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason'),
        'Matched bank app',
      );
      await tester.tap(find.text('Save adjustment'));
      await tester.pumpAndSettle();

      expect(sent?.targetBalance, '24000.00');
      expect(sent?.delta, isNull);
      expect(sent?.reason, 'Matched bank app');
      expect(find.text('Balance adjusted.'), findsOneWidget);
    });
  });
}
