import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/people/data/people_api.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_picker.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/people_fakes.dart';
import '../../helpers/test_app.dart';

const String me = '7b0b6a52-9d7e-4a4e-9d43-1d3f0c3a9a11';

void main() {
  late MockPeopleApi people;
  late MockTransactionsApi transactions;
  late MockAccountsApi accounts;
  late MockLabelsApi labels;

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    people = MockPeopleApi();
    transactions = MockTransactionsApi();
    accounts = MockAccountsApi();
    labels = MockLabelsApi();
    stubLabels(labels);
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
  });

  /// Opens [open] from a button and records what it returns.
  Future<List<Object?>> host(
    WidgetTester tester,
    Future<Object?> Function(BuildContext context) open,
  ) async {
    final List<Object?> results = <Object?>[];
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => results.add(await open(context)),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        overrides: [
          ...signedInOverrides(),
          peopleApiProvider.overrideWithValue(people),
          transactionsApiProvider.overrideWithValue(transactions),
          accountsApiProvider.overrideWithValue(accounts),
          labelsApiProvider.overrideWithValue(labels),
        ],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return results;
  }

  group('person picker', () {
    testWidgets('offers friends only and leaves out people already added', (
      WidgetTester tester,
    ) async {
      stubPeople(
        people,
        friends: <PublicProfile>[
          friend(),
          friend(id: 'u-ben', name: 'Ben', username: null),
          friend(id: 'u-cy', name: 'Cy Pending', connection: 'request_sent'),
        ],
      );
      final List<Object?> results = await host(
        tester,
        (BuildContext context) =>
            showPersonPicker(context, excludeIds: <String>{'u-ben'}),
      );

      expect(find.text('Choose a person'), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('@asha'), findsOneWidget);
      expect(find.text('Ben'), findsNothing);
      expect(find.text('Cy Pending'), findsNothing);
      await tester.tap(find.text('Asha Rao'));
      await tester.pumpAndSettle();
      expect((results.single! as PersonChoice).userId, 'u-asha');
    });

    testWidgets('lists current group members other than the user', (
      WidgetTester tester,
    ) async {
      when(() => people.group('grp-home')).thenAnswer(
        (_) async => groupDetail(
          members: <Map<String, Object?>>[
            groupMemberJson(id: me, name: 'Me', role: 'owner'),
            groupMemberJson(id: 'u-ravi', name: 'Ravi'),
            groupMemberJson(id: 'u-old', name: 'Left Member', status: 'left'),
          ],
        ),
      );
      final List<Object?> results = await host(
        tester,
        (BuildContext context) =>
            showPersonPicker(context, groupId: 'grp-home'),
      );

      expect(find.text('Choose a group member'), findsOneWidget);
      expect(find.text('Ravi'), findsOneWidget);
      expect(find.text('Me'), findsNothing);
      expect(find.text('Left Member'), findsNothing);
      await tester.tap(find.text('Ravi'));
      await tester.pumpAndSettle();
      expect((results.single! as PersonChoice).displayName, 'Ravi');
    });

    testWidgets('explains when there is no one to pick and retries errors', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => people.friends()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <PublicProfile>[];
      });
      await host(tester, showPersonPicker);

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No connections yet'), findsOneWidget);
    });
  });

  testWidgets('group picker shows member counts and a "No group" choice', (
    WidgetTester tester,
  ) async {
    stubPeople(
      people,
      groups: <GroupDto>[
        groupDto(),
        groupDto(id: 'grp-trip', name: 'Goa trip', members: 1),
      ],
    );
    final List<Object?> results = await host(tester, showGroupPicker);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('3 members'), findsOneWidget);
    expect(find.text('1 member'), findsOneWidget);
    await tester.tap(find.text('No group'));
    await tester.pumpAndSettle();
    final Picked<GroupDto> picked = results.single! as Picked<GroupDto>;
    expect(picked.value, isNull);
  });

  group('transaction picker', () {
    testWidgets('searches as the user types and returns the choice', (
      WidgetTester tester,
    ) async {
      final List<TransactionFilter> asked = <TransactionFilter>[];
      when(
        () => transactions.list(
          any(),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((Invocation i) async {
        final TransactionFilter f =
            i.positionalArguments.first as TransactionFilter;
        asked.add(f);
        return page(<TransactionDto>[
          if (f.query == null) transaction(),
          transaction(
            id: 'tx-2',
            merchant: null,
            description: 'Electricity bill',
          ),
        ]);
      });
      final List<Object?> results = await host(
        tester,
        (BuildContext context) => showTransactionPicker(
          context,
          filter: const TransactionFilter(types: <String>{'expense'}),
        ),
      );

      expect(find.text('Choose a transaction'), findsOneWidget);
      expect(find.text('Big Bazaar'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'electricity');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(asked.last.query, 'electricity');
      expect(asked.last.types, <String>{'expense'});
      expect(find.text('Big Bazaar'), findsNothing);
      await tester.tap(find.text('Electricity bill'));
      await tester.pumpAndSettle();
      expect((results.single! as TransactionDto).id, 'tx-2');
    });

    testWidgets('shows empty and error states', (WidgetTester tester) async {
      when(
        () => transactions.list(
          any(),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenThrow(offline);
      await host(tester, showTransactionPicker);
      expect(find.text('Try again'), findsOneWidget);

      when(
        () => transactions.list(
          any(),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => page(<TransactionDto>[]));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No matching transactions.'), findsOneWidget);
    });
  });
}
