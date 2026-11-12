import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/application/organize_providers.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/domain/organize_display.dart';

enum _CategoryAction { edit, addSubcategory, merge, archive, restore, delete }

/// Message for a failed category delete: "in use" is explained with the
/// alternatives (merge or archive).
String categoryDeleteError(AppLocalizations l10n, Object error) =>
    error is ApiException &&
        error.details.any((Detail d) => d.code == 'category_in_use')
    ? l10n.categoryInUse
    : describeError(l10n, error);

/// All categories as a tree, with archived ones on request. Each can be
/// edited, archived or restored, merged into another (after a preview of
/// what moves) and deleted when nothing uses it.
class CategoriesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _showArchived = false;
  String? _busyId;

  Future<void> _run(
    CategoryDto category,
    Future<String?> Function(LabelsApi api) action,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final LabelsApi api = ref.read(labelsApiProvider);
    setState(() => _busyId = category.id);
    try {
      final String? done = await action(api);
      if (done == null) {
        return;
      }
      finance.bump();
      if (mounted) {
        showSnack(context, done);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, categoryDeleteError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _act(CategoryDto category, bool topLevel) async {
    final AppLocalizations l10n = context.l10n;
    final String name = categoryName(l10n, category);
    final bool active = category.status == CategoryDtoStatus.active;
    final _CategoryAction? action = await showOptionSheet<_CategoryAction>(
      context,
      title: name,
      options: <SheetOption<_CategoryAction>>[
        if (active)
          SheetOption<_CategoryAction>(
            value: _CategoryAction.edit,
            label: l10n.categoryEdit,
            icon: Icons.edit_outlined,
          ),
        if (active && topLevel)
          SheetOption<_CategoryAction>(
            value: _CategoryAction.addSubcategory,
            label: l10n.categoryAddSubcategory,
            icon: Icons.subdirectory_arrow_right,
          ),
        if (active)
          SheetOption<_CategoryAction>(
            value: _CategoryAction.merge,
            label: l10n.categoryMergeInto,
            subtitle: l10n.categoryMergeIntoHelp,
            icon: Icons.merge_type,
          ),
        if (active)
          SheetOption<_CategoryAction>(
            value: _CategoryAction.archive,
            label: l10n.categoryArchive,
            subtitle: l10n.categoryArchiveHelp,
            icon: Icons.archive_outlined,
          ),
        if (category.status == CategoryDtoStatus.archived)
          SheetOption<_CategoryAction>(
            value: _CategoryAction.restore,
            label: l10n.categoryRestore,
            icon: Icons.unarchive_outlined,
          ),
        if (category.status != CategoryDtoStatus.merged &&
            category.transactionCount == 0)
          SheetOption<_CategoryAction>(
            value: _CategoryAction.delete,
            label: l10n.categoryDelete,
            icon: Icons.delete_outline,
            destructive: true,
          ),
      ],
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _CategoryAction.edit:
        await context.push<Object?>(AppRoutes.editCategory(category.id));
      case _CategoryAction.addSubcategory:
        await context.push<Object?>(
          Uri(
            path: AppRoutes.newCategory,
            queryParameters: <String, String>{'parent': category.id},
          ).toString(),
        );
      case _CategoryAction.merge:
        await _merge(category);
      case _CategoryAction.archive:
        await _run(category, (LabelsApi api) async {
          await api.archiveCategory(category.id);
          return l10n.categoryArchived(name);
        });
      case _CategoryAction.restore:
        await _run(category, (LabelsApi api) async {
          await api.restoreCategory(category.id);
          return l10n.categoryRestored(name);
        });
      case _CategoryAction.delete:
        final bool confirmed = await showConfirmDialog(
          context,
          title: l10n.categoryDeleteTitle(name),
          body: l10n.categoryDeleteBody,
          confirmLabel: l10n.categoryDelete,
          destructive: true,
        );
        if (confirmed && mounted) {
          await _run(category, (LabelsApi api) async {
            await api.deleteCategory(category.id);
            return l10n.categoryDeleted(name);
          });
        }
    }
  }

  /// Picks the target, previews what moves, then merges after confirming.
  Future<void> _merge(CategoryDto source) async {
    final AppLocalizations l10n = context.l10n;
    final String sourceName = categoryName(l10n, source);
    final Picked<CategoryDto>? picked =
        await showSingleSelection<CategoryDto, CategoryDto>(
          context,
          title: l10n.categoryMergeTargetTitle(sourceName),
          source: categoriesProvider,
          onRetry: (WidgetRef ref) => ref.invalidate(categoriesProvider),
          items: (BuildContext context, List<CategoryDto> data) =>
              <SelectionItem<CategoryDto>>[
                for (final (CategoryDto c, int depth) in categoryTree(data))
                  if (c.id != source.id && c.parentId != source.id)
                    SelectionItem<CategoryDto>(
                      id: c.id,
                      value: c,
                      label: categoryName(l10n, c),
                      indent: depth,
                      searchText: c.name,
                      leading: CategoryBadge(
                        icon: c.icon,
                        color: c.color,
                        size: 32,
                      ),
                    ),
              ],
          emptyText: l10n.categoryPickerEmpty,
        );
    final CategoryDto? target = picked?.value;
    if (target == null || !mounted) {
      return;
    }
    final String targetName = categoryName(l10n, target);
    final LabelsApi api = ref.read(labelsApiProvider);
    setState(() => _busyId = source.id);
    MergeResult preview;
    try {
      preview = await api.mergeCategories(
        targetId: target.id,
        sourceIds: <String>[source.id],
        preview: true,
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _busyId = null);
        showSnack(context, describeError(l10n, error));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _busyId = null);
    final List<String> moves = mergeAffectedLines(l10n, preview.affected);
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.categoryMergeTitle(sourceName, targetName),
      body: moves.isEmpty
          ? l10n.categoryMergeNothing(sourceName)
          : l10n.categoryMergeBody(moves.join('\n'), sourceName),
      confirmLabel: l10n.categoryMerge,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run(source, (LabelsApi api) async {
      await api.mergeCategories(
        targetId: target.id,
        sourceIds: <String>[source.id],
        preview: false,
      );
      return l10n.categoryMerged(sourceName, targetName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<CategoryDto>> categories = ref.watch(
      managedCategoriesProvider(_showArchived),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.categoriesTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.categoryRulesTitle,
            icon: const Icon(Icons.rule),
            onPressed: () => context.push(AppRoutes.categoryRules),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newCategory),
        icon: const Icon(Icons.add),
        label: Text(l10n.categoryNew),
      ),
      body: categories.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingStateView(),
        error: (Object error, StackTrace _) => ErrorStateView(
          error: error,
          onRetry: () =>
              ref.invalidate(managedCategoriesProvider(_showArchived)),
        ),
        data: (List<CategoryDto> list) {
          final Map<String, CategoryDto> byId = <String, CategoryDto>{
            for (final CategoryDto c in list) c.id: c,
          };
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(managedCategoriesProvider(_showArchived));
              await ref.read(managedCategoriesProvider(_showArchived).future);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.md,
                    Insets.md,
                    0,
                  ),
                  child: Text(l10n.categoriesIntro),
                ),
                SwitchListTile(
                  title: Text(l10n.categoriesShowArchived),
                  value: _showArchived,
                  onChanged: (bool v) => setState(() => _showArchived = v),
                ),
                if (list.isEmpty)
                  MessageStateView(
                    icon: Icons.category_outlined,
                    title: l10n.categoriesEmptyTitle,
                    body: l10n.categoriesEmptyBody,
                  )
                else
                  for (final (CategoryDto c, int depth) in categoryTree(list))
                    _CategoryTile(
                      category: c,
                      depth: depth,
                      parent: c.parentId == null ? null : byId[c.parentId],
                      busy: _busyId == c.id,
                      onTap: c.status == CategoryDtoStatus.active
                          ? () => context.push(AppRoutes.editCategory(c.id))
                          : null,
                      onMore: _busyId == null
                          ? () => _act(c, depth == 0)
                          : null,
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.depth,
    required this.parent,
    required this.busy,
    required this.onTap,
    required this.onMore,
  });

  final CategoryDto category;
  final int depth;
  final CategoryDto? parent;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String name = categoryName(l10n, category);
    final CategoryDto? p = parent;
    final String details = <String>[
      categoryKindLabel(l10n, category.kind),
      l10n.categoryTransactionCount(category.transactionCount),
      if (!category.includeInBudgets) l10n.categoryNotInBudgets,
    ].join(' · ');
    return Semantics(
      label: p != null && depth > 0
          ? l10n.subcategoryOf(name, categoryName(l10n, p))
          : null,
      child: ListTile(
        contentPadding: EdgeInsetsDirectional.only(
          start: Insets.md + depth * Insets.lg,
          end: Insets.xs,
        ),
        leading: CategoryBadge(icon: category.icon, color: category.color),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(details),
            if (category.status == CategoryDtoStatus.archived)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: StatusLabel(
                  text: l10n.categoryStatusArchived,
                  icon: Icons.archive_outlined,
                ),
              ),
            if (category.status == CategoryDtoStatus.merged)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: StatusLabel(
                  text: l10n.categoryStatusMerged,
                  icon: Icons.merge_type,
                ),
              ),
          ],
        ),
        onTap: onTap,
        trailing: busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : category.status == CategoryDtoStatus.merged
            ? null
            : IconButton(
                tooltip: l10n.categoryActionsFor(name),
                icon: const Icon(Icons.more_vert),
                onPressed: onMore,
              ),
      ),
    );
  }
}
