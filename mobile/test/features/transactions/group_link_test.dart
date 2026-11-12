import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_detail_screen.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/group_money_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/social_fakes.dart';

/// A transaction linked to a group expense or settlement opens that record
/// in its group (`TransactionDTO.group_id`), not the list of groups.
void main() {
  TransactionDto linked({
    String? groupId,
    String? expenseId,
    String? settlementId,
  }) => TransactionDto.fromJson(<String, Object?>{
    ...transactionJson(),
    'group_id': ?groupId,
    'group_expense_id': ?expenseId,
    'settlement_id': ?settlementId,
  });

  group('groupRecordLocation', () {
    test('an expense or settlement opens in its group', () {
      expect(
        groupRecordLocation(linked(groupId: 'g1', expenseId: 'ge-1')),
        '/groups/g1/expenses/ge-1',
      );
      expect(
        groupRecordLocation(linked(groupId: 'g1', settlementId: 'st-1')),
        '/groups/g1/settlements/st-1',
      );
    });

    test('without a visible group the groups list opens', () {
      expect(groupRecordLocation(linked(expenseId: 'ge-1')), '/groups');
      expect(groupRecordLocation(linked(settlementId: 'st-1')), '/groups');
    });

    test('a transaction without a group link has none', () {
      expect(groupRecordLocation(linked(groupId: 'g1')), isNull);
      expect(groupRecordLocation(transaction()), isNull);
    });
  });

  group('transaction detail', () {
    late MockTransactionsApi api;
    late MockGroupMoneyApi groupMoney;
    late MockGroupsApi groups;

    setUpAll(registerFinanceFallbacks);

    setUp(() {
      api = MockTransactionsApi();
      groupMoney = MockGroupMoneyApi();
      groups = MockGroupsApi();
      final MockAccountsApi accounts = MockAccountsApi();
      final MockLabelsApi labels = MockLabelsApi();
      final MockPaymentMethodsApi methods = MockPaymentMethodsApi();
      stubLabels(labels, categories: <CategoryDto>[category()]);
      when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
          .thenAnswer((_) async => <AccountDto>[account()]);
      when(() => methods.list(includeArchived: any(named: 'includeArchived')))
          .thenAnswer((_) async => <PaymentMethodDto>[]);
      when(() => api.audit(any())).thenAnswer((_) async => <AuditEventDto>[]);
      when(() => api.attachments(any()))
          .thenAnswer((_) async => <AttachmentDto>[]);
      overridesFor = <Override>[
        transactionsApiProvider.overrideWithValue(api),
        accountsApiProvider.overrideWithValue(accounts),
        labelsApiProvider.overrideWithValue(labels),
        paymentMethodsApiProvider.overrideWithValue(methods),
        groupMoneyApiProvider.overrideWithValue(groupMoney),
        groupsApiProvider.overrideWithValue(groups),
      ];
    });

    Future<GoRouter> pump(WidgetTester tester, TransactionDto tx) async {
      when(() => api.get(tx.id)).thenAnswer((_) async => tx);
      final ({Widget app, GoRouter router}) r = routedApp(
        '/transactions/${tx.id}',
        overrides: overridesFor,
      );
      await tester.pumpWidget(r.app);
      await tester.pumpAndSettle();
      return r.router;
    }

    Future<void> openGroupRecord(WidgetTester tester) async {
      final Finder tile = find.text('Linked to a group');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('a group expense opens that expense in its group', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(
        tester,
        linked(groupId: 'g1', expenseId: 'ge-1'),
      );
      await openGroupRecord(tester);
      expect(locationOf(router), '/groups/g1/expenses/ge-1');
    });

    testWidgets('without group_id the groups list opens', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester, linked(settlementId: 'st-1'));
      await openGroupRecord(tester);
      expect(locationOf(router), '/groups');
    });
  });
}

/// Overrides for the detail tests (set in `setUp`).
late List<Override> overridesFor;
