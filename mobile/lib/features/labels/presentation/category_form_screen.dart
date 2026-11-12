import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/application/organize_providers.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/domain/organize_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_style_fields.dart';

/// Creates a category (optionally under [parentId]) or edits [categoryId].
/// Edits send only what changed, with the version.
class CategoryFormScreen extends ConsumerWidget {
  /// Creates the form.
  const CategoryFormScreen({this.categoryId, this.parentId, super.key});

  /// Category to edit; null to create one.
  final String? categoryId;

  /// Parent for a new subcategory.
  final String? parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? id = categoryId;
    if (id == null) {
      return _CategoryForm(parentId: parentId);
    }
    final AsyncValue<CategoryDto> category = ref.watch(
      managedCategoryProvider(id),
    );
    Widget frame(Widget body) => Scaffold(
      appBar: AppBar(title: Text(l10n.categoryEditTitle)),
      body: body,
    );
    return category.when(
      skipLoadingOnReload: true,
      loading: () => frame(const LoadingStateView()),
      error: (Object error, StackTrace _) =>
          error is ApiException && error.code == ErrorObjectCode.notFound
          ? frame(
              MessageStateView(
                icon: Icons.search_off,
                title: l10n.categoryNotFound,
              ),
            )
          : frame(
              ErrorStateView(
                error: error,
                onRetry: () => ref.invalidate(managedCategoryProvider(id)),
              ),
            ),
      data: (CategoryDto c) => _CategoryForm(original: c),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.original, this.parentId});

  final CategoryDto? original;
  final String? parentId;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _sort = TextEditingController();
  CategoryInputKind _kind = CategoryInputKind.expense;
  String? _parentId;
  String? _icon;
  String? _color;
  bool _includeInBudgets = true;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'kind': 'kind',
    'parent_id': 'parent',
    'sort_order': 'sort',
  };

  @override
  void initState() {
    super.initState();
    _parentId = widget.parentId;
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _CategoryForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final CategoryDto? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      _load(next);
    }
  }

  void _load(CategoryDto? c) {
    if (c == null) {
      return;
    }
    _name.text = c.name;
    _sort.text = '${c.sortOrder}';
    _kind = categoryInputKindOf(c.kind);
    _parentId = c.parentId;
    _icon = c.icon;
    _color = c.color;
    _includeInBudgets = c.includeInBudgets;
  }

  @override
  void dispose() {
    _name.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _pickParent() async {
    final AppLocalizations l10n = context.l10n;
    final String? self = widget.original?.id;
    final Picked<CategoryDto>? picked =
        await showSingleSelection<CategoryDto, CategoryDto>(
          context,
          title: l10n.categoryParentLabel,
          source: categoriesProvider,
          onRetry: (WidgetRef ref) => ref.invalidate(categoriesProvider),
          items: (BuildContext context, List<CategoryDto> data) =>
              <SelectionItem<CategoryDto>>[
                for (final CategoryDto c in data)
                  // Only top-level categories can hold subcategories.
                  if (c.parentId == null && c.id != self)
                    SelectionItem<CategoryDto>(
                      id: c.id,
                      value: c,
                      label: categoryName(l10n, c),
                      searchText: c.name,
                      leading: CategoryBadge(
                        icon: c.icon,
                        color: c.color,
                        size: 32,
                      ),
                    ),
              ],
          selectedId: _parentId,
          noneLabel: l10n.categoryParentNone,
          emptyText: l10n.categoryPickerEmpty,
        );
    if (picked != null && mounted) {
      setState(() => _parentId = picked.value?.id);
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final LabelsApi api = ref.read(labelsApiProvider);
    final String name = _name.text.trim();
    final int? sort = int.tryParse(_sort.text.trim());
    final CategoryDto? o = widget.original;
    try {
      if (o == null) {
        await api.createCategory(
          CategoryInput(
            name: name,
            kind: _kind,
            parentId: _parentId,
            icon: _icon,
            color: _color,
            includeInBudgets: _includeInBudgets,
            sortOrder: sort,
          ),
        );
      } else {
        final bool parentChanged = _parentId != o.parentId;
        await api.updateCategory(
          o.id,
          CategoryPatch(
            version: o.version,
            name: name == o.name ? null : name,
            kind: _kind == categoryInputKindOf(o.kind)
                ? null
                : CategoryPatchKind.fromJson(_kind.json),
            parentId: parentChanged ? _parentId : null,
            clearParent: parentChanged && _parentId == null ? true : null,
            icon: _icon == o.icon ? null : _icon,
            color: _color == o.color || _color == null ? null : _color,
            // Removing the color: the API's `clear_color`.
            clearColor: _color == null && o.color != null ? true : null,
            includeInBudgets: _includeInBudgets == o.includeInBudgets
                ? null
                : _includeInBudgets,
            sortOrder: sort == null || sort == o.sortOrder ? null : sort,
          ),
        );
      }
      finance.bump();
      if (mounted) {
        showSnack(
          context,
          o == null ? l10n.categoryCreated(name) : l10n.categorySaved,
        );
        context.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict && o != null) {
        ref
          ..invalidate(managedCategoriesProvider(true))
          ..invalidate(managedCategoryProvider(o.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, CategoryDto> index = ref.watch(categoryIndexProvider);
    final CategoryDto? parent = _parentId == null ? null : index[_parentId];
    final CategoryDto? o = widget.original;
    final String? general = _errors.general;
    final bool hasChildren =
        o != null && index.values.any((CategoryDto c) => c.parentId == o.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(o == null ? l10n.categoryNewTitle : l10n.categoryEditTitle),
      ),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            if (_conflictReloaded) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.warning,
                message: l10n.versionConflictReloaded,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (o?.systemKey != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.info,
                message: l10n.categoryStarterNote,
              ),
              const SizedBox(height: Insets.md),
            ],
            TextFormField(
              controller: _name,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.categoryNameLabel,
                errorText: _errors.fields['name'],
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.categoryNameRequired : null,
            ),
            const SizedBox(height: Insets.md),
            Text(
              l10n.categoryKindLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Insets.xs),
            SegmentedButton<CategoryInputKind>(
              segments: <ButtonSegment<CategoryInputKind>>[
                for (final CategoryInputKind k in <CategoryInputKind>[
                  CategoryInputKind.expense,
                  CategoryInputKind.income,
                  CategoryInputKind.both,
                ])
                  ButtonSegment<CategoryInputKind>(
                    value: k,
                    label: Text(categoryInputKindLabel(l10n, k)),
                  ),
              ],
              selected: <CategoryInputKind>{_kind},
              onSelectionChanged: (Set<CategoryInputKind> v) =>
                  setState(() => _kind = v.first),
            ),
            if (_errors.fields['kind'] case final String kindError)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(
                  kindError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.categoryParentLabel,
              value: parent == null ? null : categoryName(l10n, parent),
              placeholder: l10n.categoryParentNone,
              helperText: hasChildren
                  ? l10n.categoryParentHasChildren
                  : l10n.categoryParentHelp,
              errorText: _errors.fields['parent'],
              enabled: !hasChildren,
              onTap: _pickParent,
              onClear: parent == null || hasChildren
                  ? null
                  : () => setState(() => _parentId = null),
            ),
            const SizedBox(height: Insets.lg),
            CategoryIconField(
              value: _icon,
              onChanged: (String v) => setState(() => _icon = v),
            ),
            const SizedBox(height: Insets.lg),
            LabelColorField(
              value: _color,
              onChanged: (String? v) => setState(() => _color = v),
            ),
            const SizedBox(height: Insets.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.categoryIncludeInBudgets),
              subtitle: Text(l10n.categoryIncludeInBudgetsHelp),
              value: _includeInBudgets,
              onChanged: (bool v) => setState(() => _includeInBudgets = v),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _sort,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: l10n.categorySortLabel,
                helperText: l10n.categorySortHelp,
                errorText: _errors.fields['sort'],
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.actionSave, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
