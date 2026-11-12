import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
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
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/payment_methods/application/payment_methods_providers.dart';
import 'package:montra_mobile/features/payment_methods/presentation/payment_method_picker.dart';
import 'package:montra_mobile/features/transactions/application/transactions_providers.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';

/// Why a transaction looks like [hint]'s, from its stable reason codes
/// ("same account and amount, 2 days apart").
String duplicateReasons(AppLocalizations l10n, DuplicateHint hint) => <String>[
  for (final String code in hint.reasonCodes)
    ?switch (code) {
      'same_account_amount' => l10n.duplicateSameAccountAmount,
      'same_date' => l10n.duplicateSameDate,
      'within_days' => l10n.duplicateDaysApart(hint.daysApart),
      'same_description' => l10n.duplicateSameDescription,
      _ => null,
    },
].join(', ');

/// Shows the "possible duplicate" notice after a create. Nothing is merged;
/// the user can open the similar transaction.
void showDuplicateNotice(
  BuildContext context,
  GoRouter router,
  CreateResult result,
) {
  final List<DuplicateHint> hints = result.possibleDuplicates;
  if (hints.isEmpty) {
    return;
  }
  final AppLocalizations l10n = context.l10n;
  final String reasons = duplicateReasons(l10n, hints.first);
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(
          reasons.isEmpty
              ? l10n.possibleDuplicateNotice(hints.length)
              : l10n.possibleDuplicateNoticeReasons(hints.length, reasons),
        ),
        action: SnackBarAction(
          label: l10n.possibleDuplicateReview,
          onPressed: () => router.push(
            AppRoutes.transactionDetail(hints.first.transactionId),
          ),
        ),
      ),
    );
}

/// Creates an expense or income, or edits any transaction the user owns.
///
/// Creates send an `Idempotency-Key` (kept across retries of the same
/// input); edits send `version` and, on `VERSION_CONFLICT`, reload the
/// latest version and say so. Transfers, adjustments and opening balances
/// only allow description, notes, merchant and tags to change.
class TransactionFormScreen extends ConsumerWidget {
  /// Creates the form. [transactionId] switches to edit mode; otherwise
  /// [type] (`expense` or `income`) and [accountId] preset a new one.
  const TransactionFormScreen({
    this.transactionId,
    this.type,
    this.accountId,
    super.key,
  });

  /// Transaction to edit.
  final String? transactionId;

  /// Initial type for a new transaction.
  final String? type;

  /// Initial account for a new transaction.
  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = transactionId;
    final AppLocalizations l10n = context.l10n;
    if (id == null) {
      return _TransactionForm(
        initialType: type == 'income'
            ? TransactionInputType.income
            : TransactionInputType.expense,
        initialAccountId: accountId,
      );
    }
    final AsyncValue<TransactionDto> tx = ref.watch(
      transactionDetailProvider(id),
    );
    return tx.when(
      skipLoadingOnReload: true,
      data: (TransactionDto t) => _TransactionForm(original: t),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.transactionEditTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.transactionEditTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(transactionDetailProvider(id)),
        ),
      ),
    );
  }
}

class _TransactionForm extends ConsumerStatefulWidget {
  const _TransactionForm({
    this.original,
    this.initialType = TransactionInputType.expense,
    this.initialAccountId,
  });

  final TransactionDto? original;
  final TransactionInputType initialType;
  final String? initialAccountId;

  @override
  ConsumerState<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends ConsumerState<_TransactionForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _originalAmount = TextEditingController();
  final TextEditingController _fxFee = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();

  late TransactionInputType _type = widget.initialType;
  AccountDto? _account;
  String? _accountId;
  String? _date;
  CategoryDto? _category;
  String? _categoryId;
  String? _categoryLabel;
  String? _categorySystemKey;
  MerchantChoice? _merchant;
  String? _paymentMethodId;
  final List<TagRef> _tags = <TagRef>[];
  final List<String> _newTags = <String>[];
  TransactionInputStatus _status = TransactionInputStatus.posted;
  bool _foreign = false;
  String? _originalCurrency;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'amount': 'amount',
    'currency': 'amount',
    'account_id': 'account',
    'category_id': 'category',
    'merchant_id': 'merchant',
    'merchant_name': 'merchant',
    'payment_method_id': 'payment',
    'tag_ids': 'tags',
    'tag_names': 'tags',
    'description': 'description',
    'notes': 'notes',
    'local_date': 'date',
    'occurred_at': 'date',
    'original_amount': 'original',
    'original_currency': 'original',
    'fx_fee': 'fxFee',
    'status': 'status',
    'type': 'type',
  };

  TransactionDto? get _original => widget.original;
  bool get _editing => _original != null;
  bool get _limited => _original != null && !isFullyEditable(_original!);

  CategoryKindFilter get _kind {
    final TransactionDto? o = _original;
    if (o != null) {
      return o.typeValue == TransactionDtoType.income
          ? CategoryKindFilter.income
          : CategoryKindFilter.spending;
    }
    return _type == TransactionInputType.income
        ? CategoryKindFilter.income
        : CategoryKindFilter.spending;
  }

  @override
  void initState() {
    super.initState();
    _load(_original);
    _accountId ??= widget.initialAccountId;
  }

  @override
  void didUpdateWidget(covariant _TransactionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final TransactionDto? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      setState(() => _load(next));
    }
  }

  void _load(TransactionDto? t) {
    if (t == null) {
      return;
    }
    _amount.text = t.amount.amount;
    _description.text = t.description ?? '';
    _notes.text = t.notes ?? '';
    _accountId = t.accountId;
    _account = null;
    _date = t.localDate;
    _categoryId = t.category?.id;
    _categoryLabel = t.category?.name;
    _categorySystemKey = t.category?.systemKey;
    _category = null;
    _merchant = t.merchant == null
        ? null
        : MerchantChoice(id: t.merchant!.id, name: t.merchant!.name);
    _paymentMethodId = t.paymentMethodId;
    _tags
      ..clear()
      ..addAll(t.tags);
    _newTags.clear();
    _status = TransactionInputStatus.fromJson(t.status.json);
    if (_status == TransactionInputStatus.unrecognized) {
      _status = TransactionInputStatus.posted;
    }
    final Money? original = t.originalAmount;
    _foreign = original != null;
    _originalAmount.text = original?.amount ?? '';
    _originalCurrency = original?.currency;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    _originalAmount.dispose();
    _fxFee.dispose();
    super.dispose();
  }

  String? _currencyOf(Map<String, AccountDto> accounts) =>
      _account?.currency ??
      (_accountId == null ? null : accounts[_accountId]?.currency) ??
      _original?.amount.currency;

  String? _text(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _pickAccount() async {
    final Map<String, AccountDto> accounts = ref.read(accountIndexProvider);
    final AccountDto? a = await showAccountPicker(
      context,
      selectedId: _accountId,
      currency: _editing ? _currencyOf(accounts) : null,
    );
    if (a != null && mounted) {
      setState(() {
        _account = a;
        _accountId = a.id;
      });
    }
  }

  Future<void> _pickCategory() async {
    final Picked<CategoryDto>? picked = await showCategoryPicker(
      context,
      kind: _kind,
      selectedId: _categoryId,
    );
    if (picked != null && mounted) {
      setState(() {
        _category = picked.value;
        _categoryId = picked.value?.id;
        _categoryLabel = picked.value?.name;
        _categorySystemKey = picked.value?.systemKey;
      });
    }
  }

  Future<void> _pickMerchant() async {
    final Picked<MerchantChoice>? picked = await showMerchantPicker(
      context,
      selectedId: _merchant?.id,
    );
    if (picked != null && mounted) {
      setState(() => _merchant = picked.value);
    }
  }

  Future<void> _pickPaymentMethod() async {
    final Picked<PaymentMethodDto>? picked = await showPaymentMethodPicker(
      context,
      selectedId: _paymentMethodId,
    );
    if (picked != null && mounted) {
      setState(() => _paymentMethodId = picked.value?.id);
    }
  }

  Future<void> _addTag() async {
    final TagChoice? choice = await showTagPicker(
      context,
      excludeIds: <String>{for (final TagRef t in _tags) t.id},
    );
    if (choice == null || !mounted) {
      return;
    }
    setState(() {
      final TagDto? tag = choice.tag;
      final String? name = choice.newName;
      if (tag != null) {
        _tags.add(TagRef(id: tag.id, name: tag.name, color: tag.color));
      } else if (name != null && name.isNotEmpty && !_newTags.contains(name)) {
        _newTags.add(name);
      }
    });
  }

  Future<void> _pickOriginalCurrency() async {
    final String? code = await showCurrencyPicker(
      context,
      selected: _originalCurrency,
    );
    if (code != null && mounted) {
      setState(() => _originalCurrency = code);
    }
  }

  Future<void> _submit() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    final Map<String, AccountDto> accounts = ref.read(accountIndexProvider);
    final bool valid = _form.currentState?.validate() ?? false;
    final String? accountId = _accountId;
    if (accountId == null) {
      setState(
        () => _errors = ServerFormErrors(
          fields: <String, String>{'account': l10n.validationAccountRequired},
        ),
      );
      return;
    }
    if (!valid) {
      return;
    }
    final String? currency = _currencyOf(accounts);
    final GoRouter router = GoRouter.of(context);
    final TransactionsApi api = ref.read(transactionsApiProvider);
    try {
      final TransactionDto? original = _original;
      if (original == null) {
        final TransactionInput input = _buildInput(accountId, currency);
        final CreateResult result = await api.create(
          input,
          key: _submission.keyFor(input.toJson()),
        );
        _submission.reset();
        finance.bump();
        if (!mounted) {
          return;
        }
        if (result.possibleDuplicates.isEmpty) {
          showSnack(
            _type == TransactionInputType.income
                ? l10n.incomeSaved
                : l10n.expenseSaved,
          );
        } else {
          showDuplicateNotice(context, router, result);
        }
        context.pop(result.transaction);
      } else {
        final TransactionDto saved = await api.update(
          original.id,
          _buildPatch(original, accountId, currency),
        );
        finance.bump();
        if (!mounted) {
          return;
        }
        showSnack(l10n.transactionSaved);
        context.pop(saved);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      if (error.code == ErrorObjectCode.versionConflict && _editing) {
        ref.invalidate(transactionDetailProvider(_original!.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  void showSnack(String message) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  String? _amountValue(String? currency) =>
      readAmount(context, ref, _amount.text, currency: currency).value;

  String? _originalValue() => !_foreign || _originalCurrency == null
      ? null
      : readAmount(
          context,
          ref,
          _originalAmount.text,
          currency: _originalCurrency,
        ).value;

  TransactionInput _buildInput(String accountId, String? currency) {
    final String? originalAmount = _originalValue();
    final String? fee = _foreign && _fxFee.text.trim().isNotEmpty
        ? readAmount(
            context,
            ref,
            _fxFee.text,
            currency: currency,
            allowZero: true,
          ).value
        : null;
    final MerchantChoice? merchant = _merchant;
    return TransactionInput(
      typeValue: _type,
      accountId: accountId,
      amount: _amountValue(currency) ?? _amount.text.trim(),
      localDate: _date,
      categoryId: _categoryId,
      merchantId: merchant?.id,
      merchantName: merchant != null && merchant.id == null
          ? merchant.name
          : null,
      paymentMethodId: _paymentMethodId,
      tagIds: _tags.isEmpty
          ? null
          : <String>[for (final TagRef t in _tags) t.id],
      tagNames: _newTags.isEmpty ? null : List<String>.of(_newTags),
      description: _text(_description),
      notes: _text(_notes),
      status: _status == TransactionInputStatus.posted ? null : _status,
      originalAmount: originalAmount,
      originalCurrency: originalAmount == null ? null : _originalCurrency,
      fxFee: originalAmount == null ? null : fee,
    );
  }

  TransactionPatch _buildPatch(
    TransactionDto o,
    String accountId,
    String? currency,
  ) {
    final MerchantChoice? merchant = _merchant;
    final bool merchantChanged =
        (merchant?.id ?? merchant?.name) != o.merchant?.id;
    final Set<String> before = <String>{for (final TagRef t in o.tags) t.id};
    final Set<String> now = <String>{for (final TagRef t in _tags) t.id};
    final bool tagsChanged =
        _newTags.isNotEmpty ||
        before.length != now.length ||
        !before.containsAll(now);
    String? changed(String? value, String? previous) =>
        (value ?? '') == (previous ?? '') ? null : (value ?? '');
    if (_limited) {
      return TransactionPatch(
        version: o.version,
        description: changed(_text(_description), o.description),
        notes: changed(_text(_notes), o.notes),
        merchantId: merchantChanged ? merchant?.id : null,
        merchantName: merchantChanged && merchant != null && merchant.id == null
            ? merchant.name
            : null,
        clearMerchant: merchantChanged && merchant == null ? true : null,
        tagIds: tagsChanged ? now.toList() : null,
        tagNames: tagsChanged && _newTags.isNotEmpty
            ? List<String>.of(_newTags)
            : null,
      );
    }
    final String? amount = _amountValue(currency);
    final String? originalAmount = _originalValue();
    final bool originalChanged =
        originalAmount != o.originalAmount?.amount ||
        (originalAmount != null &&
            _originalCurrency != o.originalAmount?.currency);
    final TransactionPatchStatus status = TransactionPatchStatus.fromJson(
      _status.json,
    );
    return TransactionPatch(
      version: o.version,
      amount: amount == null || amount == o.amount.amount ? null : amount,
      accountId: accountId == o.accountId ? null : accountId,
      localDate: _date == null || _date == o.localDate ? null : _date,
      categoryId: _categoryId != null && _categoryId != o.category?.id
          ? _categoryId
          : null,
      clearCategory: _categoryId == null && o.category != null ? true : null,
      merchantId: merchantChanged ? merchant?.id : null,
      merchantName: merchantChanged && merchant != null && merchant.id == null
          ? merchant.name
          : null,
      clearMerchant: merchantChanged && merchant == null ? true : null,
      paymentMethodId:
          _paymentMethodId != null && _paymentMethodId != o.paymentMethodId
          ? _paymentMethodId
          : null,
      clearPaymentMethod: _paymentMethodId == null && o.paymentMethodId != null
          ? true
          : null,
      tagIds: tagsChanged ? now.toList() : null,
      tagNames: tagsChanged && _newTags.isNotEmpty
          ? List<String>.of(_newTags)
          : null,
      description: changed(_text(_description), o.description),
      notes: changed(_text(_notes), o.notes),
      status: status.json == o.status.json ? null : status,
      originalAmount: originalChanged ? originalAmount : null,
      originalCurrency: originalChanged && originalAmount != null
          ? _originalCurrency
          : null,
      clearOriginal: originalAmount == null && o.originalAmount != null
          ? true
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, PaymentMethodDto> methods = ref.watch(
      paymentMethodIndexProvider,
    );
    // Preselect the only usable account for a new transaction.
    if (!_editing && _accountId == null) {
      final List<AccountDto>? usable = ref.watch(usableAccountsProvider).value;
      if (usable != null && usable.length == 1) {
        _accountId = usable.single.id;
      }
    }
    final String? currency = _currencyOf(accounts);
    final TransactionDto? o = _original;
    final String title = o != null
        ? l10n.transactionEditTitle
        : (_type == TransactionInputType.income
              ? l10n.incomeNewTitle
              : l10n.expenseNewTitle);
    final AccountDto? account = _account ?? accounts[_accountId];
    final String? categoryText = _category != null
        ? categoryName(l10n, _category!)
        : (_categoryId == null
              ? null
              : categoryDisplayName(
                  l10n,
                  name: _categoryLabel ?? '',
                  systemKey: _categorySystemKey,
                ));
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
            if (o != null && _limited) ...<Widget>[
              NoticeBanner(
                message: l10n.transactionLimitedEdit(
                  transactionTypeLabel(l10n, o.typeValue),
                ),
              ),
              const SizedBox(height: Insets.md),
            ],
            if (o == null) ...<Widget>[
              SegmentedButton<TransactionInputType>(
                segments: <ButtonSegment<TransactionInputType>>[
                  ButtonSegment<TransactionInputType>(
                    value: TransactionInputType.expense,
                    label: Text(l10n.txTypeExpense),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  ButtonSegment<TransactionInputType>(
                    value: TransactionInputType.income,
                    label: Text(l10n.txTypeIncome),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
                selected: <TransactionInputType>{_type},
                onSelectionChanged: (Set<TransactionInputType> s) =>
                    setState(() {
                      _type = s.first;
                      final CategoryDto? c = _category;
                      if (c != null && !categoryMatches(c, _kind)) {
                        _category = null;
                        _categoryId = null;
                      }
                    }),
              ),
              const SizedBox(height: Insets.md),
            ] else ...<Widget>[
              Text(
                transactionTypeLabel(l10n, o.typeValue),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Insets.md),
            ],
            AmountField(
              controller: _amount,
              label: l10n.amountLabel,
              currency: currency,
              enabled: !_limited,
              autofocus: !_editing,
              errorText: _errors['amount'],
              helperText: currency == null
                  ? l10n.amountChooseAccountFirst
                  : null,
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.accountFieldLabel,
              icon: Icons.account_balance_wallet_outlined,
              value: account?.name ?? o?.accountName,
              placeholder: l10n.accountFieldPlaceholder,
              helperText: _editing && !_limited ? l10n.moveAccountHelp : null,
              errorText: _errors['account'],
              enabled: !_limited,
              onTap: _pickAccount,
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.dateLabel,
              value: _date,
              emptyLabel: l10n.dateToday,
              enabled: !_limited,
              errorText: _errors['date'],
              onChanged: (String? d) => setState(() => _date = d),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.categoryFieldLabel,
              icon: Icons.category_outlined,
              value: categoryText,
              placeholder: l10n.categoryNone,
              errorText: _errors['category'],
              enabled: !_limited,
              onTap: _pickCategory,
              onClear: () => setState(() {
                _category = null;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.merchantFieldLabel,
              icon: Icons.storefront_outlined,
              value: _merchant?.name,
              placeholder: l10n.merchantNone,
              errorText: _errors['merchant'],
              helperText: _merchant != null && _merchant!.id == null
                  ? l10n.merchantNewHelp
                  : null,
              onTap: _pickMerchant,
              onClear: () => setState(() => _merchant = null),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.paymentMethodFieldLabel,
              icon: Icons.credit_card_outlined,
              value: _paymentMethodId == null
                  ? null
                  : (methods[_paymentMethodId]?.label ??
                        l10n.paymentAccountUnknown),
              placeholder: l10n.paymentNone,
              errorText: _errors['payment'],
              enabled: !_limited,
              onTap: _pickPaymentMethod,
              onClear: () => setState(() => _paymentMethodId = null),
            ),
            FormSectionHeader(l10n.tagsLabel),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final TagRef t in _tags)
                  InputChip(
                    label: Text(t.name),
                    onDeleted: () => setState(() => _tags.remove(t)),
                    deleteButtonTooltipMessage: l10n.tagRemove(t.name),
                  ),
                for (final String name in _newTags)
                  InputChip(
                    avatar: const Icon(Icons.fiber_new_outlined, size: 18),
                    label: Text(name),
                    onDeleted: () => setState(() => _newTags.remove(name)),
                    deleteButtonTooltipMessage: l10n.tagRemove(name),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.tagAdd),
                  onPressed: _tags.length + _newTags.length >= 20
                      ? null
                      : _addTag,
                ),
              ],
            ),
            if (_errors['tags'] case final String tagError)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(
                  tagError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _description,
              maxLength: TransactionInput.descriptionMaxLength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.descriptionLabel),
                errorText: _errors['description'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLength: TransactionInput.notesMaxLength,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                helperText: l10n.notesPrivacyHelp,
                errorText: _errors['notes'],
                counterText: '',
              ),
            ),
            if (!_limited)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l10n.moreOptions),
                initiallyExpanded:
                    _foreign || _status != TransactionInputStatus.posted,
                children: <Widget>[
                  DropdownButtonFormField<TransactionInputStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.statusLabel,
                      errorText: _errors['status'],
                    ),
                    items: <DropdownMenuItem<TransactionInputStatus>>[
                      for (final TransactionInputStatus s
                          in TransactionInputStatus.values)
                        if (s != TransactionInputStatus.unrecognized)
                          DropdownMenuItem<TransactionInputStatus>(
                            value: s,
                            child: Text(
                              transactionStatusLabel(
                                l10n,
                                TransactionDtoStatus.fromJson(s.json),
                              ),
                            ),
                          ),
                    ],
                    onChanged: (TransactionInputStatus? s) => setState(
                      () => _status = s ?? TransactionInputStatus.posted,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.foreignCurrencyToggle),
                    subtitle: Text(l10n.foreignCurrencyHelp),
                    value: _foreign,
                    onChanged: (bool v) => setState(() => _foreign = v),
                  ),
                  if (_foreign) ...<Widget>[
                    SelectorField(
                      label: l10n.originalCurrencyLabel,
                      icon: Icons.currency_exchange,
                      value: _originalCurrency,
                      errorText: _errors['original'],
                      onTap: _pickOriginalCurrency,
                    ),
                    const SizedBox(height: Insets.md),
                    AmountField(
                      controller: _originalAmount,
                      label: l10n.originalAmountLabel,
                      currency: _originalCurrency,
                      helperText: l10n.originalAmountHelp,
                    ),
                    if (!_editing) ...<Widget>[
                      const SizedBox(height: Insets.md),
                      AmountField(
                        controller: _fxFee,
                        label: l10n.optionalLabel(l10n.fxFeeLabel),
                        currency: currency,
                        isRequired: false,
                        allowZero: true,
                        helperText: l10n.fxFeeHelp,
                        errorText: _errors['fxFee'],
                      ),
                    ],
                  ],
                  const SizedBox(height: Insets.md),
                ],
              ),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.actionSave, onPressed: _submit),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
