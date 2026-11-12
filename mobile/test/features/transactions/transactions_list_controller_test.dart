import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/transactions/application/transactions_providers.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import '../../helpers/finance_fakes.dart';

void main() {
  late MockTransactionsApi api;
  late ProviderContainer container;
  const TransactionFilter filter = TransactionFilter(range: 'this_month');

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    api = MockTransactionsApi();
    container = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        transactionsApiProvider.overrideWithValue(api),
        ...signedInOverrides(),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<TransactionListState> load() async {
    final ProviderSubscription<AsyncValue<TransactionListState>> sub = container
        .listen(transactionsListProvider(filter), (_, _) {});
    addTearDown(sub.close);
    return container.read(transactionsListProvider(filter).future);
  }

  test('loads the next page with the cursor and skips duplicates', () async {
    when(() => api.list(filter, limit: 50)).thenAnswer(
      (_) async => page(<TransactionDto>[
        transaction(id: 't1'),
        transaction(id: 't2'),
      ], next: 'cursor-1'),
    );
    when(() => api.list(filter, cursor: 'cursor-1', limit: 50)).thenAnswer(
      (_) async =>
          page(<TransactionDto>[transaction(id: 't2'), transaction(id: 't3')]),
    );

    final TransactionListState first = await load();
    expect(first.items.map((TransactionDto t) => t.id), <String>['t1', 't2']);
    expect(first.hasMore, isTrue);

    await container.read(transactionsListProvider(filter).notifier).loadMore();
    final TransactionListState next = container
        .read(transactionsListProvider(filter))
        .requireValue;
    expect(next.items.map((TransactionDto t) => t.id), <String>[
      't1',
      't2',
      't3',
    ]);
    expect(next.hasMore, isFalse);

    // The last page is final: no more requests.
    await container.read(transactionsListProvider(filter).notifier).loadMore();
    verify(() => api.list(filter, cursor: 'cursor-1', limit: 50)).called(1);
  });

  test('a failed page keeps what was loaded and can be retried', () async {
    when(() => api.list(filter, limit: 50)).thenAnswer(
      (_) async => page(<TransactionDto>[transaction(id: 't1')], next: 'c1'),
    );
    int calls = 0;
    when(() => api.list(filter, cursor: 'c1', limit: 50)).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw offline;
      }
      return page(<TransactionDto>[transaction(id: 't2')]);
    });

    await load();
    final TransactionsListController controller = container.read(
      transactionsListProvider(filter).notifier,
    );
    await controller.loadMore();
    TransactionListState state = container
        .read(transactionsListProvider(filter))
        .requireValue;
    expect(state.items, hasLength(1));
    expect(state.loadMoreError, offline);

    await controller.loadMore();
    state = container.read(transactionsListProvider(filter)).requireValue;
    expect(state.items.map((TransactionDto t) => t.id), <String>['t1', 't2']);
    expect(state.loadMoreError, isNull);
  });

  test('a finance write reloads the list from the first page', () async {
    when(() => api.list(filter, limit: 50))
        .thenAnswer((_) async => page(<TransactionDto>[transaction(id: 't1')]));
    await load();
    container.read(financeRevisionProvider.notifier).bump();
    await container.read(transactionsListProvider(filter).future);
    verify(() => api.list(filter, limit: 50)).called(2);
  });
}
