import 'package:flutter/material.dart';
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
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';

/// Edits a merchant's name, default category, website and notes. Only
/// what changed is sent, with the merchant's `version`; a change made
/// elsewhere reloads the form and says so.
class MerchantFormScreen extends ConsumerWidget {
  /// Creates the form for [merchantId].
  const MerchantFormScreen({required this.merchantId, super.key});

  /// Merchant to edit.
  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<MerchantDetail> merchant = ref.watch(
      merchantDetailProvider(merchantId),
    );
    return merchant.when(
      skipLoadingOnReload: true,
      data: (MerchantDetail m) => _MerchantForm(original: m),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.merchantEdit)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.merchantEdit)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(merchantDetailProvider(merchantId)),
        ),
      ),
    );
  }
}

class _MerchantForm extends ConsumerStatefulWidget {
  const _MerchantForm({required this.original});

  final MerchantDetail original;

  @override
  ConsumerState<_MerchantForm> createState() => _MerchantFormState();
}

class _MerchantFormState extends ConsumerState<_MerchantForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.original.name,
  );
  late final TextEditingController _website = TextEditingController(
    text: widget.original.website ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.original.notes ?? '',
  );
  late String? _categoryId = widget.original.defaultCategoryId;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'website': 'website',
    'notes': 'notes',
    'default_category_id': 'category',
  };

  @override
  void didUpdateWidget(covariant _MerchantForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final MerchantDetail next = widget.original;
    if (next.version != oldWidget.original.version) {
      // A newer version arrived (after a conflict): show what is stored now.
      _name.text = next.name;
      _website.text = next.website ?? '';
      _notes.text = next.notes ?? '';
      _categoryId = next.defaultCategoryId;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _website.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final Picked<CategoryDto>? picked = await showCategoryPicker(
      context,
      kind: CategoryKindFilter.any,
      selectedId: _categoryId,
    );
    if (picked != null && mounted) {
      setState(() => _categoryId = picked.value?.id);
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
    final MerchantDetail o = widget.original;
    final String name = _name.text.trim();
    final String website = _website.text.trim();
    final String notes = _notes.text.trim();
    final bool categoryChanged = _categoryId != o.defaultCategoryId;
    final MerchantPatch patch = MerchantPatch(
      name: name == o.name ? null : name,
      website: website == (o.website ?? '') ? null : website,
      notes: notes == (o.notes ?? '') ? null : notes,
      defaultCategoryId: categoryChanged ? _categoryId : null,
      clearDefaultCategory: categoryChanged && _categoryId == null
          ? true
          : null,
      version: o.version,
    );
    final LabelsApi api = ref.read(labelsApiProvider);
    try {
      await api.updateMerchant(o.id, patch);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.merchantSaved);
        context.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(merchantDetailProvider(o.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(
        () => _errors = error.code == ErrorObjectCode.conflict
            ? ServerFormErrors(
                fields: <String, String>{'name': l10n.merchantNameTaken},
              )
            : ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CategoryDto? category = _categoryId == null
        ? null
        : ref.watch(categoryIndexProvider)[_categoryId];
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.merchantEdit)),
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
            TextFormField(
              controller: _name,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l10n.merchantNameLabel,
                errorText: _errors.fields['name'],
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.merchantNameRequired : null,
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.merchantDefaultCategory,
              value: category == null ? null : categoryName(l10n, category),
              placeholder: l10n.merchantNoDefaultCategory,
              helperText: l10n.merchantDefaultCategoryHelp,
              errorText: _errors.fields['category'],
              onTap: _pickCategory,
              onClear: _categoryId == null
                  ? null
                  : () => setState(() => _categoryId = null),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _website,
              maxLength: 200,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.merchantWebsiteLabel,
                errorText: _errors.fields['website'],
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLength: 1000,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.merchantNotesLabel,
                errorText: _errors.fields['notes'],
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
