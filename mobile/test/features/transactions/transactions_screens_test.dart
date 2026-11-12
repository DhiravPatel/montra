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
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockTransactionsApi api;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;
  late MockPaymentMethodsApi methods;
  final List<TransactionFilter> requested = <TransactionFilter>[];

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    api = MockTransactionsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    methods = MockPaymentMethodsApi();
    requested.clear();
    stubLabels(labels, categories: <CategoryDto>[category()]);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer(
          (_) async => <AccountDto>[
            account(),
            account(
              id: 'usd',
              name: 'USD wallet',
              type: 'cash',
              currency: 'USD',
              balance: '100.00',
            ),
          ],
        );
    when(() => methods.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <PaymentMethodDto>[paymentMethod()]);
  });

  List<Override> overrides() => <Override>[
    transactionsApiProvider.overrideWithValue(api),
    accountsApiProvider.overrideWithValue(accounts),
    labelsApiProvider.overrideWithValue(labels),
    paymentMethodsApiProvider.overrideWithValue(methods),
  ];

  void stubList(
    List<TransactionDto> Function(TransactionFilter f, String? cursor) items, {
    String? Function(String? cursor)? next,
  }) {
    when(
      () => api.list(
        any(),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((Invocation i) async {
      final TransactionFilter f =
          i.positionalArguments.first as TransactionFilter;
      final String? cursor = i.namedArguments[#cursor] as String?;
      requested.add(f);
      return page(items(f, cursor), next: next?.call(cursor));
    });
  }

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  group('list', () {
    testWidgets('the app bar opens recurring payments', (
      WidgetTester tester,
    ) async {
      stubList((TransactionFilter f, String? _) => <TransactionDto>[]);
      final GoRouter router = await pump(tester, '/transactions');
      await tester.tap(find.byTooltip('Recurring payments'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/recurring');
    });

    testWidgets('groups by date, spells out direction and loads more pages', (
      WidgetTester tester,
    ) async {
      stubList(
        (TransactionFilter f, String? cursor) => cursor == null
            ? <TransactionDto>[
                transaction(),
                transaction(
                  id: 'tx-2',
                  type: 'income',
                  direction: 'inflow',
                  amount: '85000.00',
                  merchant: null,
                  categoryId: null,
                  description: 'Salary',
                  localDate: '2026-11-03',
                ),
              ]
            : <TransactionDto>[
                transaction(
                  id: 'tx-3',
                  merchant: 'Metro',
                  localDate: '2026-11-01',
                ),
              ],
        next: (String? cursor) => cursor == null ? 'cursor-2' : null,
      );
      await pump(tester, '/transactions');

      expect(find.text('Wednesday, November 4, 2026'), findsOneWidget);
      expect(find.text('Tuesday, November 3, 2026'), findsOneWidget);
      expect(find.text('Big Bazaar'), findsOneWidget);
      expect(find.text('−₹1,250.75'), findsOneWidget);
      expect(find.text('+₹85,000.00'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('spent 1,250.75 INR')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('received 85,000.00 INR')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(find.text('Load more'), 200);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Metro'), findsOneWidget);
      expect(find.text("That's all 3 transactions."), findsOneWidget);
    });

    testWidgets('a drill-down link applies its filter; clearing it shows all', (
      WidgetTester tester,
    ) async {
      stubList(
        (TransactionFilter f, String? _) =>
            f.categoryIds.isEmpty ? <TransactionDto>[] : <TransactionDto>[],
      );
      final GoRouter router = await pump(
        tester,
        '/transactions?from=2026-11-01&to=2026-11-30&category_id=cat-groceries',
      );

      expect(requested.last.categoryIds, <String>{'cat-groceries'});
      expect(find.text('No transactions match'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      await tester.tap(find.text('Clear filters').first);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/transactions');
      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('shows an error with its reference', (
      WidgetTester tester,
    ) async {
      when(
        () => api.list(
          any(),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(
        serverError(
          ErrorObjectCode.internalError,
          status: 500,
          requestId: 'req-500',
        ),
      );
      await pump(tester, '/transactions');

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Reference: req-500'), findsOneWidget);
    });

    testWidgets('search goes into the route and the request', (
      WidgetTester tester,
    ) async {
      stubList(
        (TransactionFilter f, String? _) => <TransactionDto>[transaction()],
      );
      final GoRouter router = await pump(tester, '/transactions');

      await tester.tap(find.byTooltip('Search transactions'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bazaar');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(locationOf(router), '/transactions?q=bazaar');
      expect(requested.last.query, 'bazaar');
    });

    testWidgets('the filter screen applies a type filter', (
      WidgetTester tester,
    ) async {
      stubList(
        (TransactionFilter f, String? _) => <TransactionDto>[transaction()],
      );
      final GoRouter router = await pump(tester, '/transactions');

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Income'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();

      expect(locationOf(router), '/transactions?type=income');
      expect(requested.last.types, <String>{'income'});
      expect(find.widgetWithText(InputChip, 'Income'), findsOneWidget);
    });

    testWidgets('selected transactions are deleted together after confirming', (
      WidgetTester tester,
    ) async {
      stubList(
        (TransactionFilter f, String? _) => <TransactionDto>[transaction()],
      );
      when(() => api.bulkDelete(<String>['tx-1'])).thenAnswer((_) async => 1);
      await pump(tester, '/transactions');

      await tester.longPress(find.text('Big Bazaar'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 1 transaction?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      verify(() => api.bulkDelete(<String>['tx-1'])).called(1);
      expect(find.text('1 transaction deleted.'), findsOneWidget);
      expect(find.text('1 selected'), findsNothing);
    });
  });

  group('detail', () {
    void stubDetail(TransactionDto tx) {
      stubList((TransactionFilter f, String? _) => <TransactionDto>[]);
      when(() => api.get(tx.id)).thenAnswer((_) async => tx);
      when(() => api.audit(tx.id)).thenAnswer(
        (_) async => <AuditEventDto>[
          AuditEventDto.fromJson(<String, Object?>{
            'id': 1,
            'action': 'created',
            'actor_kind': 'user',
            'version': 1,
            'changes': <String, Object?>{'type': 'expense'},
            'created_at': '2026-11-04T07:00:00Z',
          }),
          AuditEventDto.fromJson(<String, Object?>{
            'id': 2,
            'action': 'updated',
            'actor_kind': 'user',
            'version': 2,
            'changes': <String, Object?>{
              'amount_minor': <String, Object?>{'from': 120000, 'to': 125075},
            },
            'created_at': '2026-11-04T08:00:00Z',
          }),
        ],
      );
      when(() => api.attachments(tx.id)).thenAnswer(
        (_) async => <AttachmentDto>[
          AttachmentDto.fromJson(<String, Object?>{
            'file_id': 'f1',
            'filename': 'receipt.jpg',
            'content_type': 'image/jpeg',
            'size_bytes': 2048,
            'purpose': 'receipt',
            'attached_at': '2026-11-04T08:00:00Z',
          }),
        ],
      );
    }

    testWidgets(
      'shows details, attachments and history; deletes after confirming',
      (WidgetTester tester) async {
        stubDetail(transaction());
        when(() => api.delete('tx-1'))
            .thenAnswer((_) async => transaction(status: 'voided'));
        final GoRouter router = await pump(tester, '/transactions');
        unawaited(router.push<Object?>('/transactions/tx-1'));
        await tester.pumpAndSettle();

        expect(find.text('Big Bazaar'), findsWidgets);
        expect(find.text('−₹1,250.75'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('receipt.jpg'), 300);
        expect(find.textContaining('image/jpeg · 2 KB'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Changed'), 300);
        expect(
          find.textContaining('Amount: ₹1,200.00 → ₹1,250.75'),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Delete this transaction?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        verify(() => api.delete('tx-1')).called(1);
        expect(find.text('Transaction deleted.'), findsOneWidget);
      },
    );

    testWidgets('a deleted transaction can be restored', (
      WidgetTester tester,
    ) async {
      stubDetail(transaction(status: 'voided'));
      when(() => api.restore('tx-1')).thenAnswer((_) async => transaction());
      final GoRouter router = await pump(tester, '/transactions');
      unawaited(router.push<Object?>('/transactions/tx-1'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This transaction is deleted'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
      await tester.pumpAndSettle();

      verify(() => api.restore('tx-1')).called(1);
      expect(find.text('Transaction restored.'), findsOneWidget);
    });

    testWidgets('duplicates with an idempotency key and opens the copy', (
      WidgetTester tester,
    ) async {
      stubDetail(transaction());
      final TransactionDto copy = transaction(id: 'tx-copy');
      when(() => api.get('tx-copy')).thenAnswer((_) async => copy);
      when(() => api.audit('tx-copy'))
          .thenAnswer((_) async => <AuditEventDto>[]);
      when(() => api.attachments('tx-copy'))
          .thenAnswer((_) async => <AttachmentDto>[]);
      String? key;
      when(
        () => api.duplicate(
          'tx-1',
          localDate: any(named: 'localDate'),
          key: any(named: 'key'),
        ),
      ).thenAnswer((Invocation i) async {
        key = i.namedArguments[#key] as String;
        return createResult(copy);
      });
      final GoRouter router = await pump(tester, '/transactions');
      unawaited(router.push<Object?>('/transactions/tx-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create copy'));
      await tester.pumpAndSettle();

      expect(key, isNotEmpty);
      expect(locationOf(router), '/transactions/tx-copy');
      expect(find.text('Copy created.'), findsOneWidget);
    });

    testWidgets('shows not-found for a missing transaction', (
      WidgetTester tester,
    ) async {
      stubList((TransactionFilter f, String? _) => <TransactionDto>[]);
      when(() => api.get('gone'))
          .thenThrow(serverError(ErrorObjectCode.notFound, status: 404));
      final GoRouter router = await pump(tester, '/transactions');
      unawaited(router.push<Object?>('/transactions/gone'));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't find that. It may have been removed."),
        findsOneWidget,
      );
    });
  });

  group('form', () {
    testWidgets('creates an expense and retries with the same key', (
      WidgetTester tester,
    ) async {
      when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
          .thenAnswer((_) async => <AccountDto>[account()]);
      stubList((TransactionFilter f, String? _) => <TransactionDto>[]);
      final List<String> keys = <String>[];
      TransactionInput? sent;
      int calls = 0;
      when(() => api.create(any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            calls++;
            keys.add(i.namedArguments[#key] as String);
            sent = i.positionalArguments.first as TransactionInput;
            if (calls == 1) {
              throw offline;
            }
            return createResult(transaction());
          });
      final GoRouter router = await pump(tester, '/transactions');
      unawaited(router.push<Object?>('/transactions/new?type=expense'));
      await tester.pumpAndSettle();

      expect(find.text('HDFC Savings'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '1250.5',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      expect(sent?.typeValue, TransactionInputType.expense);
      expect(sent?.amount, '1250.50');
      expect(sent?.accountId, 'acc-1');
      expect(sent?.localDate, isNull);
      expect(find.text('Expense saved.'), findsOneWidget);
      expect(locationOf(router), '/transactions');
    });

    testWidgets('edits send only changes with the version; conflicts reload', (
      WidgetTester tester,
    ) async {
      stubList((TransactionFilter f, String? _) => <TransactionDto>[]);
      int gets = 0;
      when(() => api.get('tx-1')).thenAnswer((_) async {
        gets++;
        return transaction(version: gets == 1 ? 3 : 4);
      });
      when(() => api.audit('tx-1')).thenAnswer((_) async => <AuditEventDto>[]);
      when(() => api.attachments('tx-1'))
          .thenAnswer((_) async => <AttachmentDto>[]);
      final List<TransactionPatch> patches = <TransactionPatch>[];
      when(() => api.update('tx-1', any())).thenAnswer((Invocation i) async {
        patches.add(i.positionalArguments[1] as TransactionPatch);
        if (patches.length == 1) {
          throw serverError(ErrorObjectCode.versionConflict, status: 409);
        }
        return transaction(version: 5);
      });
      final GoRouter router = await pump(tester, '/transactions');
      unawaited(router.push<Object?>('/transactions/tx-1/edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        'Monthly groceries',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(patches.first.version, 3);
      expect(patches.first.description, 'Monthly groceries');
      expect(patches.first.amount, isNull);
      expect(patches.first.accountId, isNull);
      expect(patches.first.tagIds, isNull);
      expect(
        find.textContaining('we loaded the latest version'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        'Monthly groceries',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(patches.last.version, 4);
      expect(find.text('Transaction saved.'), findsOneWidget);
    });

    testWidgets('transfer legs only allow descriptive edits', (
      WidgetTester tester,
    ) async {
      stubList((TransactionFilter f, String? _) => <TransactionDto>[]);
      when(() => api.get('leg')).thenAnswer(
        (_) async => transaction(
          id: 'leg',
          type: 'transfer',
          merchant: null,
          categoryId: null,
          transferId: 'tr-1',
        ),
      );
      final GoRouter router = await pump(tester, '/transactions');
      unawaited(router.push<Object?>('/transactions/leg/edit'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Only the description, notes, merchant and tags'),
        findsOneWidget,
      );
      final TextFormField amount = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Amount'),
      );
      expect(amount.enabled, isFalse);
    });
  });

  group('refunds', () {
    testWidgets('shows the server cap message, then records a refund', (
      WidgetTester tester,
    ) async {
      stubList((TransactionFilter f, String? _) => <TransactionDto>[]);
      when(() => api.get('tx-1'))
          .thenAnswer((_) async => transaction(refunded: '250.75'));
      final List<RefundInput> sent = <RefundInput>[];
      when(() => api.refund('tx-1', any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent.add(i.positionalArguments[1] as RefundInput);
            if (sent.length == 1) {
              throw serverError(
                ErrorObjectCode.domainRuleViolation,
                message: 'Refunds and reimbursements cannot exceed the original amount (1000.00 remaining).',
              );
            }
            return createResult(
              transaction(id: 'rf', type: 'refund', direction: 'inflow'),
            );
          });
      final GoRouter router = await pump(tester, '/transactions');
      unawaited(router.push<Object?>('/transactions/tx-1/refund'));
      await tester.pumpAndSettle();

      expect(find.text('₹250.75'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount returned'),
        '5000',
      );
      await tester.ensureVisible(find.text('Save refund'));
      await tester.tap(find.text('Save refund'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1000.00 remaining'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount returned'),
        '100',
      );
      await tester.ensureVisible(find.text('Save refund'));
      await tester.tap(find.text('Save refund'));
      await tester.pumpAndSettle();

      expect(sent.last.amount, '100.00');
      expect(sent.last.typeValue, RefundInputType.refund);
      expect(find.text('Refund saved.'), findsOneWidget);
    });
  });

  group('transfers', () {
    testWidgets('a cross-currency transfer asks for the amount received', (
      WidgetTester tester,
    ) async {
      stubList((TransactionFilter f, String? _) => <TransactionDto>[]);
      TransferInput? sent;
      final TransferDto transfer = TransferDto.fromJson(<String, Object?>{
        'id': 'tr-1',
        'from_account_id': 'acc-1',
        'to_account_id': 'usd',
        'from_transaction_id': 'tx-out',
        'to_transaction_id': 'tx-in',
        'from_amount': moneyJson('8400.00'),
        'to_amount': moneyJson('100.00', currency: 'USD'),
        'fx_rate': '0.011904761905',
        'fx_rate_source': 'manual',
        'status': 'posted',
        'local_date': '2026-11-04',
        'description': 'Holiday money',
        'created_at': '2026-11-04T13:15:57Z',
      });
      when(() => api.transfer(any(), key: any(named: 'key')))
          .thenAnswer((Invocation i) async {
            sent = i.positionalArguments.first as TransferInput;
            return transfer;
          });
      when(() => api.getTransfer('tr-1')).thenAnswer((_) async => transfer);
      when(() => api.deleteTransfer('tr-1')).thenAnswer(
        (_) async => TransferDto.fromJson(<String, Object?>{
          ...transfer.toJson(),
          'status': 'voided',
        }),
      );
      final GoRouter router = await pump(tester, '/transactions');
      unawaited(router.push<Object?>('/transactions/transfer?from=acc-1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose an account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Different currencies'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount sent'),
        '8400',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount received'),
        '100',
      );
      await tester.ensureVisible(find.text('Save transfer'));
      await tester.tap(find.text('Save transfer'));
      await tester.pumpAndSettle();

      expect(sent?.fromAccountId, 'acc-1');
      expect(sent?.toAccountId, 'usd');
      expect(sent?.amount, '8400.00');
      expect(sent?.toAmount, '100.00');
      expect(sent?.fxRate, isNull);
      expect(locationOf(router), '/transactions/transfers/tr-1');
      expect(find.text('HDFC Savings → USD wallet'), findsOneWidget);
      expect(find.text('0.011904761905 (manual)'), findsOneWidget);
      expect(find.text('Holiday money'), findsOneWidget);

      // Let the "Transfer saved." snack bar time out so it doesn't cover the
      // button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Delete transfer'), 200);
      await tester.tap(find.text('Delete transfer'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this transfer?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      verify(() => api.deleteTransfer('tr-1')).called(1);
      verifyNever(() => api.delete(any()));
      expect(find.text('Transfer deleted.'), findsOneWidget);
    });
  });
}
