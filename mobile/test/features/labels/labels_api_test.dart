import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';

import '../../helpers/fakes.dart';
import '../../helpers/organize_fakes.dart';

/// The requests `LabelsApi` sends for the round-3 contract changes.
void main() {
  late FakeHttpAdapter adapter;
  late LabelsApi api;

  Map<String, Object?> page(List<Object?> data, {String? next}) =>
      <String, Object?>{
        'data': data,
        'meta': <String, Object?>{
          'request_id': 'req-ok',
          'timestamp': '2026-11-05T10:00:00Z',
          'next_cursor': ?next,
        },
      };

  setUp(() {
    adapter = FakeHttpAdapter((RequestOptions o) async {
      final String path = o.uri.path;
      if (path.endsWith('/merchants') && o.method == 'GET') {
        return jsonResponse(
          200,
          page(<Object?>[merchantDto().toJson()], next: 'c2'),
        );
      }
      if (path.endsWith('/merge/preview')) {
        return jsonResponse(
          200,
          envelope(merchantMergePreview(transactions: 2).toJson()),
        );
      }
      if (path.contains('/merchants')) {
        return jsonResponse(200, envelope(merchantDetail().toJson()));
      }
      if (path.contains('/tags/')) {
        return jsonResponse(200, envelope(managedTag().toJson()));
      }
      if (path.endsWith('/apply')) {
        return jsonResponse(200, envelope(rulePreview(2).toJson()));
      }
      if (path.contains('/category-rules/')) {
        return jsonResponse(200, envelope(categoryRule().toJson()));
      }
      return jsonResponse(200, envelope(managedCategory().toJson()));
    });
    api = LabelsApi(
      ApiClient(
        createApiDio(testConfig, adapter: adapter, enableLogging: false),
      ),
    );
  });

  test(
    'one tag and one rule are read by ID (reloaded after a conflict)',
    () async {
      final TagDto tag = await api.getTag('tag-trip');
      expect(adapter.requests.last.method, 'GET');
      expect(adapter.requests.last.uri.path, '/api/v1/tags/tag-trip');
      expect(tag.id, 'tag-trip');
      final RuleDto rule = await api.getRule('rule-1');
      expect(adapter.requests.last.method, 'GET');
      expect(adapter.requests.last.uri.path, '/api/v1/category-rules/rule-1');
      expect(rule.id, 'rule-1');
    },
  );

  test(
    'the merchant directory sends the status and pages with a cursor',
    () async {
      final CursorPage<MerchantDto> first = await api.merchantsPage(
        query: ' swig ',
      );
      expect(first.nextCursor, 'c2');
      await api.merchantsPage(status: 'all', cursor: 'c2');
      expect(adapter.requests[0].uri.queryParameters, <String, String>{
        'q': 'swig',
        'status': 'active',
        'limit': '50',
      });
      expect(adapter.requests[1].uri.queryParameters, <String, String>{
        'status': 'all',
        'cursor': 'c2',
        'limit': '50',
      });
    },
  );

  test('alias removal and the merge preview send their bodies', () async {
    await api.removeMerchantAlias('mer-swiggy', 'SWIGGY BLR');
    final MerchantMergeResult preview = await api.previewMerchantMerge(
      targetId: 'mer-swiggy',
      sourceIds: <String>['mer-zomato'],
    );
    expect(preview.affected.transactions, 2);
    expect(adapter.requests[0].uri.path, '/api/v1/merchants/aliases/remove');
    expect(adapter.requests[0].data, <String, Object?>{
      'alias': 'SWIGGY BLR',
      'merchant_id': 'mer-swiggy',
    });
    expect(adapter.requests[1].uri.path, '/api/v1/merchants/merge/preview');
    expect(adapter.requests[1].data, <String, Object?>{
      'source_ids': <String>['mer-zomato'],
      'target_id': 'mer-swiggy',
    });
  });

  test('tags, merchants and rules send their version; colors are cleared '
      'with clear_color', () async {
    await api.updateTag(
      'tag-trip',
      const TagPatch(clearColor: true, version: 3),
    );
    await api.updateMerchant(
      'mer-swiggy',
      const MerchantPatch(archived: true, version: 2),
    );
    await api.updateRule(
      'rule-1',
      const RuleUpdate(
        matchField: RuleUpdateMatchField.merchant,
        matchType: RuleUpdateMatchType.contains,
        name: 'Food',
        pattern: 'swiggy',
        setCategoryId: 'cat-food',
        amountMin: '100.00',
        currency: 'USD',
        version: 4,
      ),
    );
    expect(adapter.requests[0].method, 'PATCH');
    expect(adapter.requests[0].data, <String, Object?>{
      'clear_color': true,
      'version': 3,
    });
    expect(adapter.requests[1].data, <String, Object?>{
      'archived': true,
      'version': 2,
    });
    expect(adapter.requests[2].method, 'PUT');
    expect((adapter.requests[2].data as Map<String, Object?>)['version'], 4);
    expect(
      (adapter.requests[2].data as Map<String, Object?>)['currency'],
      'USD',
    );
  });

  test('a saved rule is applied by ID; a category is read by ID', () async {
    final RulePreview applied = await api.applySavedRule(
      'rule-1',
      onlyUncategorized: true,
    );
    expect(applied.matchCount, 2);
    await api.getCategory('cat-food');
    expect(adapter.requests[0].uri.path, '/api/v1/category-rules/rule-1/apply');
    expect(adapter.requests[0].data, <String, Object?>{
      'only_uncategorized': true,
    });
    expect(adapter.requests[1].method, 'GET');
    expect(adapter.requests[1].uri.path, '/api/v1/categories/cat-food');
  });
}
