import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';

/// Active categories (for pickers and name lookups). Re-read after finance
/// writes because new merchants/rules can change them.
final FutureProvider<List<CategoryDto>> categoriesProvider =
    FutureProvider.autoDispose<List<CategoryDto>>((Ref ref) async {
      ref.watch(financeRevisionProvider);
      final List<CategoryDto> all = await ref
          .read(labelsApiProvider)
          .listCategories();
      return <CategoryDto>[
        for (final CategoryDto c in all)
          if (c.status == CategoryDtoStatus.active) c,
      ];
    });

/// Categories by ID (empty until loaded).
final Provider<Map<String, CategoryDto>> categoryIndexProvider =
    Provider.autoDispose<Map<String, CategoryDto>>(
      (Ref ref) => <String, CategoryDto>{
        for (final CategoryDto c
            in ref.watch(categoriesProvider).value ?? const <CategoryDto>[])
          c.id: c,
      },
    );

/// Tags that are not archived, most used first.
final FutureProvider<List<TagDto>> tagsProvider =
    FutureProvider.autoDispose<List<TagDto>>((Ref ref) async {
      ref.watch(financeRevisionProvider);
      final List<TagDto> all = await ref.read(labelsApiProvider).listTags();
      final List<TagDto> active = <TagDto>[
        for (final TagDto t in all)
          if (t.archivedAt == null) t,
      ]..sort((TagDto a, TagDto b) => b.usageCount.compareTo(a.usageCount));
      return active;
    });

/// Merchant search results for a query (at least one character).
final FutureProviderFamily<List<MerchantDto>, String> merchantSearchProvider =
    FutureProvider.autoDispose.family<List<MerchantDto>, String>((
      Ref ref,
      String query,
    ) async {
      final List<MerchantDto> found = await ref
          .read(labelsApiProvider)
          .searchMerchants(query);
      return <MerchantDto>[
        for (final MerchantDto m in found)
          if (m.status == MerchantDtoStatus.active) m,
      ];
    });

/// Which categories fit a transaction type (the server enforces the same
/// rule: expense categories for spending, income categories for income).
enum CategoryKindFilter {
  /// Expenses, refunds and reimbursements.
  spending,

  /// Income.
  income,

  /// Everything (filters).
  any,
}

/// Whether [category] can be used under [filter].
bool categoryMatches(CategoryDto category, CategoryKindFilter filter) =>
    switch (filter) {
      CategoryKindFilter.any => true,
      CategoryKindFilter.spending => category.kind != CategoryDtoKind.income,
      CategoryKindFilter.income => category.kind != CategoryDtoKind.expense,
    };

/// [categories] ordered as a tree: each top-level category followed by its
/// subcategories, both by `sort_order` then name. Returns pairs of
/// (category, depth).
List<(CategoryDto, int)> categoryTree(List<CategoryDto> categories) {
  int compare(CategoryDto a, CategoryDto b) {
    final int order = a.sortOrder.compareTo(b.sortOrder);
    return order != 0 ? order : a.name.compareTo(b.name);
  }

  final Set<String> ids = <String>{
    for (final CategoryDto c in categories) c.id,
  };
  final List<CategoryDto> roots = <CategoryDto>[
    for (final CategoryDto c in categories)
      if (c.parentId == null || !ids.contains(c.parentId)) c,
  ]..sort(compare);
  final Map<String, List<CategoryDto>> children = <String, List<CategoryDto>>{};
  for (final CategoryDto c in categories) {
    final String? parent = c.parentId;
    if (parent != null && ids.contains(parent)) {
      (children[parent] ??= <CategoryDto>[]).add(c);
    }
  }
  final List<(CategoryDto, int)> out = <(CategoryDto, int)>[];
  for (final CategoryDto root in roots) {
    out.add((root, 0));
    for (final CategoryDto child
        in (children[root.id] ?? <CategoryDto>[])..sort(compare)) {
      out.add((child, 1));
    }
  }
  return out;
}
