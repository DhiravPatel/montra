import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';

List<SelectionItem<CategoryDto>> _categoryItems(
  BuildContext context,
  List<CategoryDto> data,
  CategoryKindFilter kind,
) {
  final AppLocalizations l10n = context.l10n;
  final Map<String, CategoryDto> byId = <String, CategoryDto>{
    for (final CategoryDto c in data) c.id: c,
  };
  return <SelectionItem<CategoryDto>>[
    for (final (CategoryDto c, int depth) in categoryTree(
      data.where((CategoryDto c) => categoryMatches(c, kind)).toList(),
    ))
      SelectionItem<CategoryDto>(
        id: c.id,
        value: c,
        label: categoryName(l10n, c),
        indent: depth,
        searchText: c.name,
        leading: CategoryBadge(icon: c.icon, color: c.color, size: 32),
        semanticsLabel: depth > 0 && byId[c.parentId] != null
            ? l10n.subcategoryOf(
                categoryName(l10n, c),
                categoryName(l10n, byId[c.parentId]!),
              )
            : null,
      ),
  ];
}

/// Picks one category that fits [kind]. Returns null when dismissed and
/// `Picked(null)` for "No category".
Future<Picked<CategoryDto>?> showCategoryPicker(
  BuildContext context, {
  required CategoryKindFilter kind,
  String? selectedId,
  bool allowNone = true,
}) => showSingleSelection<CategoryDto, CategoryDto>(
  context,
  title: context.l10n.categoryPickerTitle,
  source: categoriesProvider,
  onRetry: (WidgetRef ref) => ref.invalidate(categoriesProvider),
  items: (BuildContext context, List<CategoryDto> data) =>
      _categoryItems(context, data, kind),
  selectedId: selectedId,
  noneLabel: allowNone ? context.l10n.categoryNone : null,
  emptyText: context.l10n.categoryPickerEmpty,
);

/// Picks several categories (filters). Returns null when dismissed.
Future<Set<String>?> showCategoryMultiPicker(
  BuildContext context, {
  Set<String> selectedIds = const <String>{},
}) => showMultiSelection<CategoryDto, CategoryDto>(
  context,
  title: context.l10n.categoryPickerTitle,
  source: categoriesProvider,
  onRetry: (WidgetRef ref) => ref.invalidate(categoriesProvider),
  items: (BuildContext context, List<CategoryDto> data) =>
      _categoryItems(context, data, CategoryKindFilter.any),
  selectedIds: selectedIds,
  emptyText: context.l10n.categoryPickerEmpty,
);

/// A tag choice: an existing tag or a new name the server will create.
@immutable
class TagChoice {
  /// An existing tag.
  const TagChoice.existing(TagDto this.tag) : newName = null;

  /// A new tag name.
  const TagChoice.create(String this.newName) : tag = null;

  /// Existing tag.
  final TagDto? tag;

  /// Name for a new tag.
  final String? newName;
}

List<SelectionItem<TagChoice>> _tagItems(
  BuildContext context,
  List<TagDto> d,
) => <SelectionItem<TagChoice>>[
  for (final TagDto t in d)
    SelectionItem<TagChoice>(
      id: t.id,
      value: TagChoice.existing(t),
      label: t.name,
      leading: const Icon(Icons.sell_outlined),
      subtitle: context.l10n.tagUsage(t.usageCount),
    ),
];

/// Picks one tag, or creates one by name. Returns null when dismissed.
Future<TagChoice?> showTagPicker(
  BuildContext context, {
  Set<String> excludeIds = const <String>{},
}) async {
  final Picked<TagChoice>? picked =
      await showSingleSelection<TagDto, TagChoice>(
        context,
        title: context.l10n.tagPickerTitle,
        source: tagsProvider,
        onRetry: (WidgetRef ref) => ref.invalidate(tagsProvider),
        items: (BuildContext context, List<TagDto> data) => _tagItems(
          context,
          data.where((TagDto t) => !excludeIds.contains(t.id)).toList(),
        ),
        emptyText: context.l10n.tagPickerEmpty,
        create: CreateOption<TagChoice>(
          label: (String q) => context.l10n.tagCreate(q),
          build: (String q) => TagChoice.create(q.trim()),
        ),
      );
  return picked?.value;
}

/// Picks several existing tags (filters, bulk edits).
Future<Set<String>?> showTagMultiPicker(
  BuildContext context, {
  Set<String> selectedIds = const <String>{},
}) => showMultiSelection<TagDto, TagChoice>(
  context,
  title: context.l10n.tagPickerTitle,
  source: tagsProvider,
  onRetry: (WidgetRef ref) => ref.invalidate(tagsProvider),
  items: _tagItems,
  selectedIds: selectedIds,
  emptyText: context.l10n.tagPickerEmpty,
);

/// A merchant choice: an existing merchant or a name the server resolves
/// (matching an existing merchant or alias, or creating one).
@immutable
class MerchantChoice {
  /// Creates the choice.
  const MerchantChoice({required this.name, this.id});

  /// Existing merchant ID.
  final String? id;

  /// Display name.
  final String name;
}

/// Searches merchants as the user types. Returns null when dismissed and
/// `Picked(null)` for "No merchant".
Future<Picked<MerchantChoice>?> showMerchantPicker(
  BuildContext context, {
  String? selectedId,
  bool allowCreate = true,
  bool allowNone = true,
}) => showModalBottomSheet<Picked<MerchantChoice>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) => MerchantPickerSheet(
    selectedId: selectedId,
    allowCreate: allowCreate,
    allowNone: allowNone,
  ),
);

/// The merchant search sheet (public for tests).
class MerchantPickerSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const MerchantPickerSheet({
    this.selectedId,
    this.allowCreate = true,
    this.allowNone = true,
    super.key,
  });

  /// Currently chosen merchant.
  final String? selectedId;

  /// Offer "Use “name”" for new merchants.
  final bool allowCreate;

  /// Offer "No merchant".
  final bool allowNone;

  @override
  ConsumerState<MerchantPickerSheet> createState() =>
      _MerchantPickerSheetState();
}

class _MerchantPickerSheetState extends ConsumerState<MerchantPickerSheet> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  String _search = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _search = value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String typed = _query.text.trim();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              0,
              Insets.md,
              Insets.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    l10n.merchantPickerTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: l10n.merchantSearchLabel,
                    prefixIcon: const Icon(Icons.search),
                    counterText: '',
                  ),
                  onChanged: _onChanged,
                  onSubmitted: (String v) => setState(() => _search = v.trim()),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: <Widget>[
                if (widget.allowCreate && typed.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.add_business_outlined),
                    title: Text(l10n.merchantUseName(typed)),
                    subtitle: Text(l10n.merchantUseNameHelp),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(Picked<MerchantChoice>(MerchantChoice(name: typed))),
                  ),
                if (widget.allowNone && typed.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: Text(l10n.merchantNone),
                    onTap: () =>
                        Navigator.of(context)
                            .pop(const Picked<MerchantChoice>(null)),
                  ),
                if (_search.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Text(
                      l10n.merchantSearchPrompt,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  _results(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<MerchantDto>> found = ref.watch(
      merchantSearchProvider(_search),
    );
    if (found.hasError && !found.isLoading) {
      return SizedBox(
        height: 280,
        child: ErrorStateView(
          error: found.error!,
          onRetry: () => ref.invalidate(merchantSearchProvider(_search)),
        ),
      );
    }
    final List<MerchantDto>? list = found.value;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.all(Insets.lg),
        child: LoadingStateView(),
      );
    }
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Text(
          l10n.merchantNoMatches(_search),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final MerchantDto m in list)
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(m.name),
            subtitle: Text(l10n.merchantTransactionCount(m.transactionCount)),
            selected: m.id == widget.selectedId,
            trailing: m.id == widget.selectedId
                ? Icon(Icons.check, semanticLabel: l10n.selectedLabel)
                : null,
            onTap: () => Navigator.of(context).pop(
              Picked<MerchantChoice>(MerchantChoice(id: m.id, name: m.name)),
            ),
          ),
      ],
    );
  }
}
