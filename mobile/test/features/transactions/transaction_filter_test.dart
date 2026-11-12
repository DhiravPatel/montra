import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

void main() {
  test('reads the dashboard drill-down link the server returns', () {
    final Uri link = Uri.parse(
      '/transactions?from=2026-11-01&to=2026-11-30&category_id=cat-1',
    );
    final TransactionFilter f = TransactionFilter.fromQuery(
      link.queryParameters,
    );
    expect(f.from, '2026-11-01');
    expect(f.to, '2026-11-30');
    expect(f.categoryIds, <String>{'cat-1'});
    expect(f.activeCount, 2);
    expect(f.toQuery()['category_id'], <String>['cat-1']);
  });

  test('ignores malformed values from links', () {
    final TransactionFilter f = TransactionFilter.fromQuery(<String, String>{
      'from': '01-11-2026',
      'range': 'forever',
      'status': 'gone',
      'sort': 'random',
      'direction': 'sideways',
      'type': 'expense, ,income',
    });
    expect(f.from, isNull);
    expect(f.range, isNull);
    expect(f.status, isNull);
    expect(f.sort, 'date_desc');
    expect(f.direction, isNull);
    expect(f.types, <String>{'expense', 'income'});
  });

  test('a named range wins over dates in the query', () {
    const TransactionFilter f = TransactionFilter(
      range: 'last_30_days',
      from: '2026-01-01',
    );
    final Map<String, Object?> q = f.toQuery();
    expect(q['range'], 'last_30_days');
    expect(q.containsKey('from'), isFalse);
  });

  test('amount filters carry their currency; search uses q', () {
    const TransactionFilter f = TransactionFilter(
      minAmount: '100.00',
      currency: 'INR',
      query: ' coffee ',
    );
    final Map<String, Object?> q = f.toQuery();
    expect(q['currency'], 'INR');
    expect(q['min_amount'], '100.00');
    expect(q['q'], 'coffee');
    expect(f.hasQuery, isTrue);
  });

  test('round-trips through the Transactions tab location', () {
    const TransactionFilter f = TransactionFilter(
      range: 'this_month',
      types: <String>{'refund', 'expense'},
      accountIds: <String>{'a2', 'a1'},
      merchantId: 'm1',
      status: 'voided',
      sort: 'amount_desc',
      query: 'rent',
    );
    final String location = f.toLocation();
    expect(location, startsWith('/transactions?'));
    final TransactionFilter back = TransactionFilter.fromQuery(
      Uri.parse(location).queryParameters,
    );
    expect(back, f);
    expect(back.hashCode, f.hashCode);
    expect(const TransactionFilter().toLocation(), '/transactions');
  });

  test('copyWith clears values explicitly and toString hides the search', () {
    const TransactionFilter f = TransactionFilter(
      merchantId: 'm1',
      query: 'private note',
      from: '2026-11-01',
    );
    final TransactionFilter cleared = f.copyWith(
      clearMerchant: true,
      clearDates: true,
      range: 'today',
    );
    expect(cleared.merchantId, isNull);
    expect(cleared.from, isNull);
    expect(cleared.range, 'today');
    expect(cleared.query, 'private note');
    expect(f.cleared().isEmpty, isTrue);
    expect(f.toString(), isNot(contains('private')));
  });

  test('the uncategorized drill-down never sends a category too', () {
    final TransactionFilter f = TransactionFilter.fromQuery(<String, String>{
      'uncategorized': 'true',
      'category_id': 'cat-1',
      'range': 'this_month',
    });
    expect(f.uncategorized, isTrue);
    expect(f.categoryIds, isEmpty);
    expect(f.activeCount, 2);
    final Map<String, Object?> q = f.toQuery();
    expect(q['uncategorized'], isTrue);
    expect(q.containsKey('category_id'), isFalse);
    expect(
      TransactionFilter.fromQuery(Uri.parse(f.toLocation()).queryParameters),
      f,
    );
    // Choosing a category turns the flag off, and the reverse.
    final TransactionFilter picked = f.copyWith(categoryIds: <String>{'cat-2'});
    expect(picked.uncategorized, isFalse);
    expect(picked.copyWith(uncategorized: true).categoryIds, isEmpty);
  });
}
