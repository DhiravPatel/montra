import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Categories, category rules, tags and merchants: the reads behind the
/// pickers and the management calls behind the organize screens.
class LabelsApi {
  /// Creates the API over [client].
  LabelsApi(this._client);

  final ApiClient _client;

  /// `GET /categories` (active ones unless [includeArchived]).
  Future<List<CategoryDto>> listCategories({bool includeArchived = false}) =>
      _client.send(
        ApiEndpoints.listCategories,
        query: <String, Object?>{if (includeArchived) 'include_archived': true},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListCategoryDto(json).data,
      );

  /// `GET /tags`.
  Future<List<TagDto>> listTags() => _client.send(
    ApiEndpoints.listTags,
    decode: (Map<String, Object?> json) => decodeEnvelopeListTagDto(json).data,
  );

  // Categories.

  /// `GET /categories/{id}`: one category in any status (active, archived
  /// or merged).
  Future<CategoryDto> getCategory(String id) => _client.send(
    ApiEndpoints.getCategory,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeCategoryDto(json).data,
  );

  /// `POST /categories`.
  Future<CategoryDto> createCategory(CategoryInput input) => _client.send(
    ApiEndpoints.createCategory,
    body: input.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeCategoryDto(json).data,
  );

  /// `PATCH /categories/{id}` (only the fields set in [patch]; the color is
  /// removed with `clear_color`).
  Future<CategoryDto> updateCategory(String id, CategoryPatch patch) =>
      _client.send(
        ApiEndpoints.updateCategory,
        pathParameters: <String, String>{'id': id},
        body: patch.toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeCategoryDto(json).data,
      );

  /// `POST /categories/{id}/archive`.
  Future<CategoryDto> archiveCategory(String id) => _client.send(
    ApiEndpoints.archiveCategory,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeCategoryDto(json).data,
  );

  /// `POST /categories/{id}/restore`.
  Future<CategoryDto> restoreCategory(String id) => _client.send(
    ApiEndpoints.restoreCategory,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeCategoryDto(json).data,
  );

  /// `DELETE /categories/{id}`; only unused categories can be deleted
  /// (409 `category_in_use` otherwise).
  Future<void> deleteCategory(String id) => _client.send(
    ApiEndpoints.deleteCategory,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /categories/merge`: moves everything that uses [sourceIds] to
  /// [targetId] (transactions, rules, budget limits and filters, recurring
  /// rules, bills, subscriptions). With [preview] nothing changes and the
  /// affected counts are returned ([MergeAffected]).
  Future<MergeResult> mergeCategories({
    required String targetId,
    required List<String> sourceIds,
    required bool preview,
  }) => _client.send(
    ApiEndpoints.mergeCategories,
    body: MergeInput(
      targetId: targetId,
      sourceIds: sourceIds,
      preview: preview,
    ).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeMergeResult(json).data,
  );

  // Category rules.

  /// `GET /category-rules/{id}`: one rule (reloaded after a change made
  /// elsewhere).
  Future<RuleDto> getRule(String id) => _client.send(
    ApiEndpoints.getCategoryRule,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeRuleDto(json).data,
  );

  /// `GET /category-rules`.
  Future<List<RuleDto>> listRules() => _client.send(
    ApiEndpoints.listCategoryRules,
    decode: (Map<String, Object?> json) => decodeEnvelopeListRuleDto(json).data,
  );

  /// `POST /category-rules`.
  Future<RuleDto> createRule(RuleInput rule) => _client.send(
    ApiEndpoints.createCategoryRule,
    body: rule.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeRuleDto(json).data,
  );

  /// `PUT /category-rules/{id}`: the whole rule with the `version` that was
  /// loaded (a change made elsewhere answers `VERSION_CONFLICT`).
  Future<RuleDto> updateRule(String id, RuleUpdate rule) => _client.send(
    ApiEndpoints.updateCategoryRule,
    pathParameters: <String, String>{'id': id},
    body: rule.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeRuleDto(json).data,
  );

  /// `POST /category-rules/{id}/apply`: applies the saved rule to matching
  /// existing transactions (only those without a category when
  /// [onlyUncategorized]).
  Future<RulePreview> applySavedRule(
    String id, {
    required bool onlyUncategorized,
  }) => _client.send(
    ApiEndpoints.applySavedCategoryRule,
    pathParameters: <String, String>{'id': id},
    body: RuleApplyInput(onlyUncategorized: onlyUncategorized).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeRulePreview(json).data,
  );

  /// `DELETE /category-rules/{id}`.
  Future<void> deleteRule(String id) => _client.send(
    ApiEndpoints.deleteCategoryRule,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /category-rules/preview`: how many existing transactions [rule]
  /// matches, with a sample. Nothing changes.
  Future<RulePreview> previewRule(
    RuleInput rule, {
    required bool onlyUncategorized,
  }) => _client.send(
    ApiEndpoints.previewCategoryRule,
    body: CategoryRulesPreviewRequest(
      rule: rule,
      onlyUncategorized: onlyUncategorized,
    ).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeRulePreview(json).data,
  );

  /// `POST /category-rules/apply`: sets the rule's category on matching
  /// existing transactions.
  Future<RulePreview> applyRule(
    RuleInput rule, {
    required bool onlyUncategorized,
  }) => _client.send(
    ApiEndpoints.applyCategoryRules,
    body: CategoryRulesApplyRequest(
      rule: rule,
      onlyUncategorized: onlyUncategorized,
    ).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeRulePreview(json).data,
  );

  // Tags.

  /// `POST /tags`.
  /// `GET /tags/{id}`: one tag (reloaded after a change made elsewhere).
  Future<TagDto> getTag(String id) => _client.send(
    ApiEndpoints.getTag,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeTagDto(json).data,
  );

  Future<TagDto> createTag(TagBody body) => _client.send(
    ApiEndpoints.createTag,
    body: body.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeTagDto(json).data,
  );

  /// `PATCH /tags/{id}`: rename, recolor (or remove the color with
  /// `clear_color`), archive or unarchive, with the tag's `version`.
  Future<TagDto> updateTag(String id, TagPatch patch) => _client.send(
    ApiEndpoints.updateTag,
    pathParameters: <String, String>{'id': id},
    body: patch.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeTagDto(json).data,
  );

  /// `DELETE /tags/{id}` (transactions keep everything but the tag).
  Future<void> deleteTag(String id) => _client.send(
    ApiEndpoints.deleteTag,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  // Merchants.

  /// Merchants per page of the directory.
  static const int merchantPageSize = 50;

  /// One page of `GET /merchants` with [status] (`active` — the server
  /// default —, `archived`, `merged` or `all`), matching [query] (name or
  /// alias) when given.
  Future<CursorPage<MerchantDto>> merchantsPage({
    String? query,
    String status = 'active',
    String? cursor,
    int limit = merchantPageSize,
  }) => _client.send(
    ApiEndpoints.listMerchants,
    query: <String, Object?>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      'status': status,
      'cursor': cursor,
      'limit': limit,
    },
    decode: (Map<String, Object?> json) {
      final EnvelopeListMerchantDto envelope = decodeEnvelopeListMerchantDto(
        json,
      );
      return CursorPage<MerchantDto>(envelope.data, envelope.meta.nextCursor);
    },
  );

  /// `GET /merchants/{id}` with 12 months of spending.
  Future<MerchantDetail> getMerchant(String id) => _client.send(
    ApiEndpoints.getMerchant,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeMerchantDetail(json).data,
  );

  /// `PATCH /merchants/{id}` (only the fields set in [patch], with the
  /// merchant's `version`).
  Future<MerchantDetail> updateMerchant(String id, MerchantPatch patch) =>
      _client.send(
        ApiEndpoints.updateMerchant,
        pathParameters: <String, String>{'id': id},
        body: patch.toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeMerchantDetail(json).data,
      );

  /// `POST /merchants/aliases`: another name the merchant appears under.
  Future<MerchantDetail> addMerchantAlias(String merchantId, String alias) =>
      _client.send(
        ApiEndpoints.addMerchantAlias,
        body: MerchantsAliasesRequest(
          merchantId: merchantId,
          alias: alias,
        ).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeMerchantDetail(json).data,
      );

  /// `POST /merchants/aliases/remove`: the merchant stops matching
  /// [alias].
  Future<MerchantDetail> removeMerchantAlias(String merchantId, String alias) =>
      _client.send(
        ApiEndpoints.removeMerchantAlias,
        body: MerchantsAliasesRemoveRequest(
          merchantId: merchantId,
          alias: alias,
        ).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeMerchantDetail(json).data,
      );

  /// `POST /merchants/merge/preview`: what merging [sourceIds] into
  /// [targetId] would move. Nothing changes.
  Future<MerchantMergeResult> previewMerchantMerge({
    required String targetId,
    required List<String> sourceIds,
  }) => _client.send(
    ApiEndpoints.previewMerchantMerge,
    body: MerchantsMergePreviewRequest(
      targetId: targetId,
      sourceIds: sourceIds,
    ).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeMerchantMergeResult(json).data,
  );

  /// `POST /merchants/merge`: moves [sourceIds] (transactions, aliases,
  /// rules, budget limits and filters, recurring rules, subscriptions) into
  /// [targetId].
  Future<MerchantDetail> mergeMerchants({
    required String targetId,
    required List<String> sourceIds,
  }) => _client.send(
    ApiEndpoints.mergeMerchants,
    body: MerchantsMergeRequest(
      targetId: targetId,
      sourceIds: sourceIds,
    ).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeMerchantDetail(json).data,
  );

  /// `GET /merchants?q=` — active merchants whose name or alias matches
  /// [query] (the first page; for pickers).
  Future<List<MerchantDto>> searchMerchants(String query, {int limit = 20}) =>
      _client.send(
        ApiEndpoints.listMerchants,
        query: <String, Object?>{'q': query.trim(), 'limit': limit},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListMerchantDto(json).data,
      );
}

/// Labels endpoints. Overridden in tests.
final Provider<LabelsApi> labelsApiProvider = Provider<LabelsApi>(
  (Ref ref) => LabelsApi(ref.watch(apiClientProvider)),
);
