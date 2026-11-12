import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/application/organize_providers.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/domain/organize_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/settings/application/preferences_providers.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_tile.dart';

/// Creates a category rule or edits [ruleId] (the whole rule is sent with
/// its `version`; a change made elsewhere reloads the form). Amount limits
/// carry their own currency and match only transactions in it. The form
/// can preview which existing transactions the rule matches and apply it:
/// a saved, unchanged rule is applied as stored
/// (`POST /category-rules/{id}/apply`).
class CategoryRuleFormScreen extends ConsumerWidget {
  /// Creates the form.
  const CategoryRuleFormScreen({this.ruleId, super.key});

  /// Rule to edit; null to create one.
  final String? ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? id = ruleId;
    if (id == null) {
      return const _RuleForm();
    }
    Widget frame(Widget body) => Scaffold(
      appBar: AppBar(title: Text(l10n.ruleEditTitle)),
      body: body,
    );
    return ref
        .watch(categoryRuleProvider(id))
        .when(
          skipLoadingOnReload: true,
          loading: () => frame(const LoadingStateView()),
          error: (Object error, StackTrace _) => frame(
            error is ApiException && error.code == ErrorObjectCode.notFound
                ? MessageStateView(
                    icon: Icons.search_off,
                    title: l10n.ruleNotFound,
                  )
                : ErrorStateView(
                    error: error,
                    onRetry: () => ref.invalidate(categoryRuleProvider(id)),
                  ),
          ),
          data: (RuleDto r) => _RuleForm(original: r),
        );
  }
}

class _RuleForm extends ConsumerStatefulWidget {
  const _RuleForm({this.original});

  final RuleDto? original;

  @override
  ConsumerState<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<_RuleForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _pattern = TextEditingController();
  final TextEditingController _min = TextEditingController();
  final TextEditingController _max = TextEditingController();
  final TextEditingController _priority = TextEditingController(text: '100');
  RuleInputMatchField _field = RuleInputMatchField.any;
  RuleInputMatchType _type = RuleInputMatchType.contains;
  RuleInputApplyTo _applyTo = RuleInputApplyTo.all;
  RuleInputTransactionType? _txType;
  String? _categoryId;
  String? _accountId;
  bool _enabled = true;
  bool _onlyUncategorized = true;
  bool _busy = false;
  RulePreview? _preview;
  String? _previewKey;
  String? _categoryError;
  String? _amountCurrency;
  bool _conflictReloaded = false;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'pattern': 'pattern',
    'match_field': 'pattern',
    'match_type': 'pattern',
    'set_category_id': 'category',
    'account_id': 'account',
    'amount_min': 'min',
    'amount_max': 'max',
    'currency': 'currency',
    'priority': 'priority',
  };

  @override
  void initState() {
    super.initState();
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _RuleForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final RuleDto? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      // A newer version arrived (after a conflict): show what is stored now.
      setState(() => _load(next));
    }
  }

  void _load(RuleDto? r) {
    if (r == null) {
      return;
    }
    final RuleInput input = ruleInputOf(r);
    _name.text = input.name;
    _pattern.text = input.pattern;
    _field = input.matchField;
    _type = input.matchType;
    _applyTo = input.applyTo ?? RuleInputApplyTo.all;
    _txType = input.transactionType;
    _categoryId = input.setCategoryId;
    _accountId = input.accountId;
    _min.text = input.amountMin ?? '';
    _max.text = input.amountMax ?? '';
    _priority.text = '${input.priority ?? ''}';
    _enabled = input.enabled ?? true;
    _amountCurrency = r.currency;
    _preview = null;
    _previewKey = null;
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _pattern,
      _min,
      _max,
      _priority,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The currency of the amount limits: the rule's own, else the base
  /// currency.
  String? get _currency =>
      _amountCurrency ?? ref.read(preferencesProvider).value?.baseCurrency;

  Future<void> _pickCurrency() async {
    final String? code = await showCurrencyPicker(context, selected: _currency);
    if (code != null && mounted) {
      setState(() => _amountCurrency = code);
      _changed();
    }
  }

  /// The rule as currently entered, or null (with errors shown) when the
  /// form is incomplete.
  RuleInput? _input() {
    final AppLocalizations l10n = context.l10n;
    final bool valid = _form.currentState?.validate() ?? false;
    setState(
      () => _categoryError = _categoryId == null
          ? l10n.ruleCategoryRequired
          : null,
    );
    final String? category = _categoryId;
    if (!valid || category == null) {
      return null;
    }
    final String? currency = _currency;
    String? amount(TextEditingController c) => c.text.trim().isEmpty
        ? null
        : readAmount(context, ref, c.text, currency: currency).value;
    final String? min = amount(_min);
    final String? max = amount(_max);
    final String priority = _priority.text.trim();
    return RuleInput(
      name: _name.text.trim(),
      pattern: _pattern.text.trim(),
      matchField: _field,
      matchType: _type,
      setCategoryId: category,
      // Optional: the server uses 100 when it is left empty.
      priority: priority.isEmpty ? null : int.parse(priority),
      enabled: _enabled,
      applyTo: _applyTo,
      transactionType: _txType,
      accountId: _accountId,
      amountMin: min,
      amountMax: max,
      currency: min != null || max != null ? currency : null,
    );
  }

  String _keyOf(RuleInput input, bool onlyUncategorized) =>
      '${jsonEncode(input.toJson())}|$onlyUncategorized';

  void _changed() {
    if (_preview != null) {
      setState(() {
        _preview = null;
        _previewKey = null;
      });
    }
  }

  Future<void> _runPreview() async {
    final AppLocalizations l10n = context.l10n;
    final RuleInput? input = _input();
    if (input == null) {
      return;
    }
    setState(() {
      _busy = true;
      _errors = ServerFormErrors.none;
    });
    try {
      final RulePreview preview = await ref
          .read(labelsApiProvider)
          .previewRule(input, onlyUncategorized: _onlyUncategorized);
      if (mounted) {
        setState(() {
          _preview = preview;
          _previewKey = _keyOf(input, _onlyUncategorized);
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(
            l10n,
            _ruleFieldErrors(error),
            fieldMap: _fields,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Preview and apply report problems as `body.rule.<field>`; the form's
  /// fields are named like the rule's members.
  static ApiException _ruleFieldErrors(ApiException error) => ApiException(
    kind: error.kind,
    code: error.code,
    rawCode: error.rawCode,
    message: error.message,
    statusCode: error.statusCode,
    requestId: error.requestId,
    retryAfter: error.retryAfter,
    details: <Detail>[
      for (final Detail d in error.details)
        Detail(
          code: d.code,
          field: d.field?.replaceFirst('body.rule.', 'body.'),
          message: d.message,
          params: d.params,
        ),
    ],
  );

  /// Whether the form still holds the saved rule (so applying it can use the
  /// stored rule).
  bool _unchanged(RuleInput input) {
    final RuleDto? o = widget.original;
    return o != null &&
        jsonEncode(input.toJson()) == jsonEncode(ruleInputOf(o).toJson());
  }

  Future<void> _apply(String categoryLabel) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final RuleInput? input = _input();
    final RulePreview? preview = _preview;
    if (input == null ||
        preview == null ||
        _previewKey != _keyOf(input, _onlyUncategorized)) {
      return;
    }
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.ruleApplyTitle(preview.matchCount),
      body: l10n.ruleApplyBody(categoryLabel),
      confirmLabel: l10n.ruleApplyConfirm,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    final RuleDto? saved = widget.original;
    try {
      final LabelsApi api = ref.read(labelsApiProvider);
      final RulePreview done = saved != null && _unchanged(input)
          ? await api.applySavedRule(
              saved.id,
              onlyUncategorized: _onlyUncategorized,
            )
          : await api.applyRule(input, onlyUncategorized: _onlyUncategorized);
      finance.bump();
      if (mounted) {
        setState(() {
          _preview = null;
          _previewKey = null;
        });
        showSnack(context, l10n.ruleApplied(done.matchCount));
      }
    } on ApiException catch (error) {
      if (mounted) {
        final ServerFormErrors errors = ServerFormErrors.from(
          l10n,
          _ruleFieldErrors(error),
          fieldMap: _fields,
        );
        if (errors.fields.isEmpty) {
          showSnack(context, describeError(l10n, error));
        } else {
          setState(() => _errors = errors);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final RuleInput? input = _input();
    if (input == null) {
      return;
    }
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    final LabelsApi api = ref.read(labelsApiProvider);
    final RuleDto? o = widget.original;
    try {
      if (o == null) {
        await api.createRule(input);
      } else {
        await api.updateRule(o.id, ruleUpdateOf(input, o.version));
      }
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.ruleSaved);
        context.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict && o != null) {
        ref
          ..invalidate(categoryRuleProvider(o.id))
          ..invalidate(categoryRulesProvider);
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  Future<void> _delete() async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final RuleDto? o = widget.original;
    if (o == null) {
      return;
    }
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.ruleDeleteTitle(o.name),
      body: l10n.ruleDeleteBody,
      confirmLabel: l10n.ruleDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(labelsApiProvider).deleteRule(o.id);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.ruleDeleted);
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _pickCategory() async {
    final Picked<CategoryDto>? picked = await showCategoryPicker(
      context,
      kind: switch (_txType) {
        RuleInputTransactionType.income => CategoryKindFilter.income,
        RuleInputTransactionType.expense => CategoryKindFilter.spending,
        _ => CategoryKindFilter.any,
      },
      selectedId: _categoryId,
      allowNone: false,
    );
    final CategoryDto? c = picked?.value;
    if (c != null && mounted) {
      setState(() {
        _categoryId = c.id;
        _categoryError = null;
      });
      _changed();
    }
  }

  Future<void> _pickAccount() async {
    final AccountDto? account = await showAccountPicker(
      context,
      selectedId: _accountId,
    );
    if (account != null && mounted) {
      setState(() => _accountId = account.id);
      _changed();
    }
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) name,
    required ValueChanged<T> onChanged,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: <DropdownMenuItem<T>>[
      for (final T v in values)
        DropdownMenuItem<T>(value: v, child: Text(name(v))),
    ],
    onChanged: (T? v) {
      if (v != null) {
        onChanged(v);
        _changed();
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final String? currency =
        _amountCurrency ?? ref.watch(preferencesProvider).value?.baseCurrency;
    final CategoryDto? category = _categoryId == null
        ? null
        : categories[_categoryId];
    final String categoryLabel = category == null
        ? l10n.ruleCategoryMissing
        : categoryName(l10n, category);
    final AccountDto? account = _accountId == null
        ? null
        : accounts[_accountId];
    final RulePreview? preview = _preview;
    final String? general = _errors.general;
    final RuleDto? o = widget.original;
    return Scaffold(
      appBar: AppBar(
        title: Text(o == null ? l10n.ruleNewTitle : l10n.ruleEditTitle),
        actions: <Widget>[
          if (o != null)
            IconButton(
              tooltip: l10n.ruleDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
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
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l10n.ruleNameLabel,
                helperText: l10n.ruleNameHelp,
                errorText: _errors.fields['name'],
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.ruleNameRequired : null,
            ),
            const SizedBox(height: Insets.md),
            FormSectionHeader(l10n.ruleWhenSection),
            _dropdown<RuleInputMatchField>(
              label: l10n.ruleFieldLabel,
              value: _field,
              values: const <RuleInputMatchField>[
                RuleInputMatchField.any,
                RuleInputMatchField.merchant,
                RuleInputMatchField.description,
              ],
              name: (RuleInputMatchField f) => ruleFieldLabel(l10n, f),
              onChanged: (RuleInputMatchField f) => setState(() => _field = f),
            ),
            const SizedBox(height: Insets.md),
            _dropdown<RuleInputMatchType>(
              label: l10n.ruleMatchTypeLabel,
              value: _type,
              values: const <RuleInputMatchType>[
                RuleInputMatchType.contains,
                RuleInputMatchType.startsWith,
                RuleInputMatchType.equals,
                RuleInputMatchType.regex,
              ],
              name: (RuleInputMatchType t) => ruleMatchTypeLabel(l10n, t),
              onChanged: (RuleInputMatchType t) => setState(() => _type = t),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _pattern,
              maxLength: 200,
              onChanged: (_) => _changed(),
              decoration: InputDecoration(
                labelText: l10n.rulePatternLabel,
                helperText: _type == RuleInputMatchType.regex
                    ? l10n.rulePatternRegexHelp
                    : l10n.rulePatternHelp,
                errorText: _errors.fields['pattern'],
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.rulePatternRequired : null,
            ),
            const SizedBox(height: Insets.md),
            FormSectionHeader(l10n.ruleThenSection),
            SelectorField(
              label: l10n.ruleCategoryLabel,
              value: category == null ? null : categoryName(l10n, category),
              placeholder: l10n.ruleCategoryPlaceholder,
              errorText: _categoryError ?? _errors.fields['category'],
              onTap: _pickCategory,
            ),
            const SizedBox(height: Insets.md),
            FormSectionHeader(l10n.ruleLimitsSection),
            _dropdown<RuleInputTransactionType?>(
              label: l10n.ruleTypeLabel,
              value: _txType,
              values: const <RuleInputTransactionType?>[
                null,
                RuleInputTransactionType.expense,
                RuleInputTransactionType.income,
              ],
              name: (RuleInputTransactionType? t) => switch (t) {
                RuleInputTransactionType.expense => l10n.ruleTypeExpense,
                RuleInputTransactionType.income => l10n.ruleTypeIncome,
                _ => l10n.ruleTypeAny,
              },
              onChanged: (RuleInputTransactionType? t) =>
                  setState(() => _txType = t),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.ruleAccountLabel,
              value: account?.name,
              placeholder: l10n.ruleAccountAny,
              errorText: _errors.fields['account'],
              onTap: _pickAccount,
              onClear: _accountId == null
                  ? null
                  : () {
                      setState(() => _accountId = null);
                      _changed();
                    },
            ),
            if (currency != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.ruleCurrencyLabel,
                value: currency,
                icon: Icons.currency_exchange,
                helperText: l10n.ruleAmountCurrencyNote(currency),
                errorText: _errors.fields['currency'],
                onTap: _pickCurrency,
              ),
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _min,
                label: l10n.ruleAmountMin,
                currency: currency,
                isRequired: false,
                allowZero: true,
                errorText: _errors.fields['min'],
                onChanged: (_) => _changed(),
              ),
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _max,
                label: l10n.ruleAmountMax,
                currency: currency,
                isRequired: false,
                allowZero: true,
                errorText: _errors.fields['max'],
                helperText: l10n.ruleAmountHelp(currency),
                onChanged: (_) => _changed(),
              ),
            ],
            const SizedBox(height: Insets.md),
            _dropdown<RuleInputApplyTo>(
              label: l10n.ruleApplyToLabel,
              value: _applyTo,
              values: const <RuleInputApplyTo>[
                RuleInputApplyTo.all,
                RuleInputApplyTo.manual,
                RuleInputApplyTo.imports,
              ],
              name: (RuleInputApplyTo a) => ruleApplyToLabel(l10n, a),
              onChanged: (RuleInputApplyTo a) => setState(() => _applyTo = a),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _priority,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.rulePriorityLabel),
                helperText: l10n.rulePriorityOptionalHelp,
                helperMaxLines: 3,
                errorText: _errors.fields['priority'],
              ),
              validator: (String? v) {
                final String text = (v ?? '').trim();
                if (text.isEmpty) {
                  return null;
                }
                final int? p = int.tryParse(text);
                return p == null || p > 10000 ? l10n.rulePriorityInvalid : null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.ruleEnabledLabel),
              subtitle: Text(l10n.ruleEnabledHelp),
              value: _enabled,
              onChanged: (bool v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: Insets.md),
            SectionCard(
              title: l10n.rulePreviewSection,
              children: <Widget>[
                SwitchListTile(
                  title: Text(l10n.ruleOnlyUncategorized),
                  value: _onlyUncategorized,
                  onChanged: (bool v) {
                    setState(() => _onlyUncategorized = v);
                    _changed();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                  child: SubmitButton(
                    label: l10n.rulePreviewAction,
                    kind: SubmitButtonKind.outlined,
                    icon: Icons.visibility_outlined,
                    busy: _busy,
                    onPressed: _busy ? null : _runPreview,
                  ),
                ),
                if (preview != null) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Text(
                      preview.matchCount == 0
                          ? l10n.rulePreviewNone
                          : l10n.rulePreviewCount(
                              preview.matchCount,
                              preview.sample.length,
                            ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final TransactionDto t in preview.sample)
                    TransactionTile(transaction: t),
                  if (preview.matchCount > 0)
                    Padding(
                      padding: const EdgeInsets.all(Insets.md),
                      // A plain button: the confirmation dialog must not
                      // sit behind a spinner.
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _apply(categoryLabel),
                        icon: const Icon(Icons.done_all),
                        label: Text(l10n.ruleApplyAction(preview.matchCount)),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: l10n.actionSave,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
