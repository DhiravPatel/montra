import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/saved_filters/saved_filters.dart';
import 'package:montra_mobile/features/search/presentation/search_screen.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';

import '../../helpers/fakes.dart';

const String acc = 'a0000000-0000-4000-8000-000000000001';
const String cat = 'c0000000-0000-4000-8000-000000000001';

SavedFilterDto saved(
  String name,
  Object? filter, {
  String id = 's1',
  String scope = 'transactions',
}) => SavedFilterDto.fromJson(<String, Object?>{
  'id': id,
  'scope': scope,
  'name': name,
  'filter': filter,
  'created_at': '2026-11-13T07:00:00Z',
});

void main() {
  group('TransactionFilter saved JSON', () {
    test('saves the GET /transactions query without empty values', () {
      const TransactionFilter filter = TransactionFilter(
        range: 'this_month',
        types: <String>{'expense'},
        accountIds: <String>{acc},
        query: ' rent ',
        minAmount: '10.00',
        currency: 'INR',
        sort: 'amount_desc',
      );
      expect(filter.toSavedJson(), <String, Object?>{
        'range': 'this_month',
        'type': <String>['expense'],
        'account_id': <String>[acc],
        'currency': 'INR',
        'min_amount': '10.00',
        'q': 'rent',
        'sort': 'amount_desc',
      });
      expect(
        TransactionFilter.fromSavedJson(filter.toSavedJson()),
        filter.copyWith(query: 'rent'),
      );
    });

    test('applies what the web saves (lists, booleans, default sort)', () {
      final TransactionFilter? filter = TransactionFilter.fromSavedJson(
        <String, Object?>{
          'sort': 'date_desc',
          'type': <Object?>['expense', 'income'],
          'uncategorized': true,
          'category_id': <Object?>[cat],
          'from': '2026-11-01',
          'to': '2026-11-30',
          'include_shared': true,
        },
      );
      expect(filter, isNotNull);
      expect(filter!.types, <String>{'expense', 'income'});
      expect(filter.uncategorized, isTrue);
      expect(filter.categoryIds, isEmpty);
      expect(filter.from, '2026-11-01');
      expect(filter.to, '2026-11-30');
    });

    test('ignores invalid values and refuses filters it cannot read', () {
      final TransactionFilter filter = TransactionFilter.fromSavedJson(
        <String, Object?>{
          'account_id': <Object?>['not-a-uuid', acc, 3],
          'status': 'nonsense',
          'min_amount': '1e9',
          'direction': 'outflow',
        },
      )!;
      expect(filter.accountIds, <String>{acc});
      expect(filter.status, isNull);
      expect(filter.minAmount, isNull);
      expect(filter.direction, 'outflow');
      expect(
        TransactionFilter.fromSavedJson(<String, Object?>{'colour': 'red'}),
        isNull,
      );
      expect(
        TransactionFilter.fromSavedJson(const <String, Object?>{}),
        const TransactionFilter(),
      );
    });

    test('a saved filter that is not a JSON object is unusable', () {
      expect(savedFilterObject(saved('x', <Object?>[1, 2])), isNull);
      expect(savedFilterObject(saved('x', 'text')), isNull);
      expect(
        savedFilterObject(saved('x', <String, Object?>{'q': 'a'})),
        <String, Object?>{'q': 'a'},
      );
    });
  });

  group('SavedSearch', () {
    test('reads q, scope and sort with safe defaults', () {
      final SavedSearch s = SavedSearch.fromJson(<String, Object?>{
        'q': '  rent   flat ',
        'scope': 'bills',
        'sort': 'recent',
      })!;
      expect((s.query, s.scope, s.sort), ('rent flat', 'bills', 'recent'));
      final SavedSearch d = SavedSearch.fromJson(<String, Object?>{
        'q': 'rent',
        'scope': 'planets',
      })!;
      expect((d.scope, d.sort), ('all', 'relevance'));
      expect(SavedSearch.fromJson(<String, Object?>{'q': 'r'}), isNull);
      expect(SavedSearch.fromJson(<String, Object?>{'q': 3}), isNull);
    });
  });

  test('names are trimmed, required and at most 80 characters', () async {
    final AppLocalizations l10n = await AppLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(SavedFilterName.validate(l10n, '   '), 'Enter a name.');
    expect(SavedFilterName.validate(l10n, 'x' * 81), isNotNull);
    expect(SavedFilterName.validate(l10n, ' ${'x' * 80} '), isNull);
    expect(SavedFilterName.normalize('  Food  '), 'Food');
  });

  test('SavedFiltersApi calls the contract endpoints', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter((RequestOptions o) async {
      if (o.method == 'GET') {
        return jsonResponse(200, envelope(<Object?>[]));
      }
      if (o.method == 'DELETE') {
        return jsonResponse(200, envelope(<String, Object?>{'ok': true}));
      }
      return jsonResponse(
        201,
        envelope(saved('Food', <String, Object?>{'q': 'x'}).toJson()),
      );
    });
    final SavedFiltersApi api = SavedFiltersApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
    await api.list(SavedFilterScope.search);
    await api.create(
      SavedFilterScope.transactions,
      '  Food ',
      <String, Object?>{
        'type': <String>['expense'],
      },
    );
    await api.delete('s1');
    expect(adapter.requests[0].uri.path, '/api/v1/saved-filters');
    expect(adapter.requests[0].uri.queryParameters['scope'], 'search');
    expect(adapter.requests[1].data, <String, Object?>{
      'filter': <String, Object?>{
        'type': <String>['expense'],
      },
      'name': 'Food',
      'scope': 'transactions',
    });
    expect(adapter.requests[1].headers.containsKey('Idempotency-Key'), isFalse);
    expect(adapter.requests[2].method, 'DELETE');
    expect(adapter.requests[2].uri.path, '/api/v1/saved-filters/s1');
  });
}
