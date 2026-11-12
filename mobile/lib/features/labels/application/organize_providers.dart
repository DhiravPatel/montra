import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';

/// Categories for the management screen: active ones, plus archived and
/// merged ones when [includeArchived]. Re-read after any finance write.
final FutureProviderFamily<List<CategoryDto>, bool> managedCategoriesProvider =
    FutureProvider.autoDispose.family<List<CategoryDto>, bool>((
      Ref ref,
      bool includeArchived,
    ) async {
      ref.watch(financeRevisionProvider);
      return ref
          .read(labelsApiProvider)
          .listCategories(includeArchived: includeArchived);
    });

/// One category by ID in any status (`GET /categories/{id}`).
final FutureProviderFamily<CategoryDto, String> managedCategoryProvider =
    FutureProvider.autoDispose.family<CategoryDto, String>((
      Ref ref,
      String id,
    ) {
      ref.watch(financeRevisionProvider);
      return ref.read(labelsApiProvider).getCategory(id);
    });

/// Category rules in the order they run: lower priority first, then name.
final FutureProvider<List<RuleDto>> categoryRulesProvider =
    FutureProvider.autoDispose<List<RuleDto>>((Ref ref) async {
      ref.watch(financeRevisionProvider);
      final List<RuleDto> rules = await ref.read(labelsApiProvider).listRules();
      return rules..sort(compareRules);
    });

/// One category rule (`GET /category-rules/{id}`), for its edit form;
/// re-read after a change made elsewhere.
final FutureProviderFamily<RuleDto, String> categoryRuleProvider =
    FutureProvider.autoDispose.family<RuleDto, String>((Ref ref, String id) {
      ref.watch(financeRevisionProvider);
      return ref.read(labelsApiProvider).getRule(id);
    });

/// Running order of category rules (the first match wins).
int compareRules(RuleDto a, RuleDto b) {
  final int byPriority = a.priority.compareTo(b.priority);
  return byPriority != 0
      ? byPriority
      : a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Every tag, archived ones included, by name.
final FutureProvider<List<TagDto>> allTagsProvider =
    FutureProvider.autoDispose<List<TagDto>>((Ref ref) async {
      ref.watch(financeRevisionProvider);
      final List<TagDto> all = await ref.read(labelsApiProvider).listTags();
      return all..sort(
        (TagDto a, TagDto b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    });

/// What the merchant directory lists: a search text ('' for all) and a
/// status (`active`, `archived`, `merged` or `all`).
typedef MerchantDirectoryKey = ({String query, String status});

/// Merchants for the directory, page by page ("Load more").
final AsyncNotifierProviderFamily<
  MerchantDirectoryController,
  PagedList<MerchantDto>,
  MerchantDirectoryKey
>
merchantDirectoryProvider = AsyncNotifierProvider.autoDispose
    .family<
      MerchantDirectoryController,
      PagedList<MerchantDto>,
      MerchantDirectoryKey
    >(MerchantDirectoryController.new);

/// See [merchantDirectoryProvider].
class MerchantDirectoryController extends PagedListController<MerchantDto> {
  /// Creates the controller for [key].
  MerchantDirectoryController(this.key);

  /// The search and status.
  final MerchantDirectoryKey key;

  @override
  Future<PagedList<MerchantDto>> build() {
    ref.watch(financeRevisionProvider);
    return firstPage();
  }

  @override
  Future<CursorPage<MerchantDto>> fetchPage(String? cursor) => ref
      .read(labelsApiProvider)
      .merchantsPage(query: key.query, status: key.status, cursor: cursor);

  @override
  String keyOf(MerchantDto item) => item.id;
}

/// One merchant with 12 months of spending.
final FutureProviderFamily<MerchantDetail, String> merchantDetailProvider =
    FutureProvider.autoDispose.family<MerchantDetail, String>((
      Ref ref,
      String id,
    ) async {
      ref.watch(financeRevisionProvider);
      return ref.read(labelsApiProvider).getMerchant(id);
    });
