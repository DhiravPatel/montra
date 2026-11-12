import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

/// Adds a shared expense (with an `Idempotency-Key`, so a retry never adds
/// it twice) or edits one (the whole expense with its `version`; the
/// server keeps the history). Splits: equally, exact amounts, percentages,
/// shares or by item; one or several payers; an amount paid in another
/// currency with Montra's rate or the user's own, in which case the server
/// works out the amount in the group currency. The split preview is a
/// guide only: the server computes every share and the expense screen
/// shows its result.
class GroupExpenseFormScreen extends ConsumerWidget {
  /// Creates the form; [expenseId] switches to edit mode.
  const GroupExpenseFormScreen({
    required this.groupId,
    this.expenseId,
    super.key,
  });

  /// The group.
  final String groupId;

  /// The expense to edit, or null to add one.
  final String? expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String title = expenseId == null
        ? l10n.gxAddExpense
        : l10n.gxEditExpense;
    return GroupPeopleScope(
      groupId: groupId,
      title: title,
      builder: (BuildContext context, GroupPeople people) {
        final String? id = expenseId;
        if (id == null) {
          return _ExpenseForm(people: people);
        }
        final GroupRecord record = (groupId: groupId, id: id);
        final AsyncValue<GroupExpenseDetail> expense = ref.watch(
          groupExpenseProvider(record),
        );
        final GroupExpenseDetail? loaded = expense.value;
        if (loaded != null) {
          return _ExpenseForm(people: people, original: loaded);
        }
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: expense.hasError && !expense.isLoading
              ? ErrorStateView(
                  error: expense.error!,
                  onRetry: () => ref.invalidate(groupExpenseProvider(record)),
                )
              : const LoadingStateView(),
        );
      },
    );
  }
}

enum _PayerMode { you, one, several }

class _ItemDraft {
  _ItemDraft({String description = '', String amount = '', Set<String>? by})
    : description = TextEditingController(text: description),
      amount = TextEditingController(text: amount),
      sharedBy = by ?? <String>{};

  final TextEditingController description;
  final TextEditingController amount;
  final Set<String> sharedBy;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({required this.people, this.original});

  final GroupPeople people;
  final GroupExpenseDetail? original;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _originalAmount = TextEditingController();
  final TextEditingController _rate = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();

  String? _date;
  String? _category;
  String _method = 'equal';
  bool _foreign = false;
  String? _originalCurrency;
  bool _lookup = true;
  List<SplitRowState> _rows = <SplitRowState>[];
  _PayerMode _payerMode = _PayerMode.you;
  String? _payerId;
  final Map<String, TextEditingController> _payerAmounts =
      <String, TextEditingController>{};
  final List<_ItemDraft> _items = <_ItemDraft>[];
  String? _accountId;
  String? _receiptFileId;
  String? _receiptName;
  List<String> _formerParticipants = <String>[];
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'description': 'description',
    'amount': 'amount',
    'original_amount': 'original',
    'original_currency': 'currency',
    'fx_rate': 'rate',
    'fx_rate_source': 'rate',
    'expense_date': 'date',
    'category_key': 'category',
    'split_method': 'split',
    'participants': 'split',
    'payers': 'payers',
    'items': 'items',
    'payer_account_id': 'account',
    'receipt_file_id': 'receipt',
    'notes': 'notes',
  };

  GroupPeople get _people => widget.people;
  bool get _editing => widget.original != null;
  String get _currency => _people.currency;
  String get _groupId => _people.group.id;

  @override
  void initState() {
    super.initState();
    _method = _people.group.defaultSplitMethod.json;
    if (!expenseSplitMethods.contains(_method)) {
      _method = 'equal';
    }
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _ExpenseForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final GroupExpenseDetail? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      setState(() => _load(next));
    }
  }

  void _load(GroupExpenseDetail? e) {
    for (final SplitRowState r in _rows) {
      r.dispose();
    }
    for (final TextEditingController c in _payerAmounts.values) {
      c.dispose();
    }
    _payerAmounts.clear();
    for (final _ItemDraft i in _items) {
      i.dispose();
    }
    _items.clear();
    final Map<String, ExpenseShareDto> shares = <String, ExpenseShareDto>{
      for (final ExpenseShareDto s in e?.shares ?? const <ExpenseShareDto>[])
        s.userId: s,
    };
    _rows = <SplitRowState>[
      for (final GroupMemberDto m in _people.activeMembers)
        SplitRowState(
          m.userId,
          included: e == null || shares.containsKey(m.userId),
          value: _shareValue(e, shares[m.userId]),
        ),
    ];
    for (final GroupMemberDto m in _people.activeMembers) {
      _payerAmounts[m.userId] = TextEditingController();
    }
    if (e == null) {
      return;
    }
    _formerParticipants = <String>[
      for (final String id in shares.keys)
        if (!_people.isActiveMember(id)) id,
    ];
    _description.text = e.description;
    _notes.text = e.notes ?? '';
    _date = e.expenseDate;
    _category = e.categoryKey;
    _method = expenseSplitMethods.contains(e.splitMethod)
        ? e.splitMethod
        : 'equal';
    final Money? original = e.originalAmount;
    _foreign = original != null;
    if (original != null) {
      _originalCurrency = original.currency;
      _originalAmount.text = original.amount;
      _rate.text = e.fxRate ?? '';
      final String? source = e.fxRateSource?.json;
      _lookup = source == 'ecb' || source == 'provider';
    } else {
      _amount.text = e.amount.amount;
    }
    final List<ExpensePayerDto> payers = e.payers;
    if (payers.length == 1 && _people.isMe(payers.single.userId)) {
      _payerMode = _PayerMode.you;
    } else if (payers.length == 1) {
      _payerMode = _PayerMode.one;
      _payerId = payers.single.userId;
    } else {
      _payerMode = _PayerMode.several;
      for (final ExpensePayerDto p in payers) {
        _payerAmounts[p.userId]?.text = p.paid.amount;
      }
    }
    for (final ExpenseItemDto item in e.items) {
      _items.add(
        _ItemDraft(
          description: item.description,
          amount: item.amount.amount,
          by: <String>{for (final ExpenseShareDto s in item.shares) s.userId},
        ),
      );
    }
    _receiptFileId = e.receiptFileId;
  }

  String _shareValue(GroupExpenseDetail? e, ExpenseShareDto? s) {
    if (e == null || s == null) {
      return '';
    }
    return switch (e.splitMethod) {
      'exact' => s.inputValue ?? s.share.amount,
      'percentage' || 'shares' => s.inputValue ?? '',
      _ => '',
    };
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    _originalAmount.dispose();
    _rate.dispose();
    for (final SplitRowState r in _rows) {
      r.dispose();
    }
    for (final TextEditingController c in _payerAmounts.values) {
      c.dispose();
    }
    for (final _ItemDraft i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  String? _trimmed(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  String? _amountOf(String text, {String? currency}) =>
      readAmount(context, ref, text, currency: currency ?? _currency).value;

  bool get _iPay => switch (_payerMode) {
    _PayerMode.you => true,
    _PayerMode.one => _people.isMe(_payerId),
    _PayerMode.several =>
      (_payerAmounts[_people.me]?.text.trim().isNotEmpty ?? false),
  };

  Future<void> _pickCurrency() async {
    final String? code = await showCurrencyPicker(
      context,
      selected: _originalCurrency,
    );
    if (code != null && mounted) {
      setState(() => _originalCurrency = code);
    }
  }

  Future<void> _pickCategory() async {
    final AppLocalizations l10n = context.l10n;
    final String? picked = await showOptionSheet<String>(
      context,
      title: l10n.categoryFieldLabel,
      selected: _category,
      options: <SheetOption<String>>[
        for (final String key in groupCategoryKeys)
          SheetOption<String>(value: key, label: groupCategoryLabel(l10n, key)),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
    }
  }

  Future<void> _pickPayer() async {
    final String? picked = await showMemberPicker(
      context,
      people: _people,
      title: context.l10n.gxWhoPaid,
    );
    if (picked != null && mounted) {
      setState(() => _payerId = picked);
    }
  }

  Future<void> _pickAccount() async {
    final AccountDto? picked = await showAccountPicker(
      context,
      selectedId: _accountId,
      currency: _currency,
      title: context.l10n.gxRecordInAccount,
    );
    if (picked != null && mounted) {
      setState(() => _accountId = picked.id);
    }
  }

  Future<void> _attachReceipt() async {
    final PickedFile? picked = await pickFileFor(
      context,
      ref,
      purpose: UploadPurpose.groupAttachment,
    );
    if (picked == null || !mounted) {
      return;
    }
    final FileDto? file = await uploadWithProgress(
      context,
      file: picked,
      purpose: UploadPurpose.groupAttachment,
      groupId: _groupId,
    );
    if (file != null && mounted) {
      setState(() {
        _receiptFileId = file.id;
        _receiptName = file.originalFilename ?? picked.name;
      });
    }
  }

  GroupExpenseInput? _build(AppLocalizations l10n) {
    final List<SplitRowState> included = _rows
        .where((SplitRowState r) => r.included)
        .toList();
    if (included.isEmpty) {
      setState(
        () => _errors = ServerFormErrors(
          fields: <String, String>{'split': l10n.gxSplitNeedsPeople},
        ),
      );
      return null;
    }
    final List<ExpenseParticipantInput> participants =
        <ExpenseParticipantInput>[
          for (final SplitRowState r in included)
            ExpenseParticipantInput(
              userId: r.userId,
              value: switch (_method) {
                'exact' => _amountOf(r.value.text),
                'percentage' => percentWire(r.value.text),
                'shares' => r.value.text.trim(),
                _ => null,
              },
            ),
        ];
    final String? amount = _foreign ? null : _amountOf(_amount.text);
    final List<ExpenseItemInput>? items = _method == 'itemized'
        ? <ExpenseItemInput>[
            for (final _ItemDraft i in _items)
              ExpenseItemInput(
                description: i.description.text.trim(),
                amount: _amountOf(i.amount.text) ?? '',
                sharedBy: <ExpenseItemShareInput>[
                  for (final SplitRowState r in included)
                    if (i.sharedBy.contains(r.userId))
                      ExpenseItemShareInput(userId: r.userId),
                ],
              ),
          ]
        : null;
    if (items != null &&
        items.any((ExpenseItemInput i) => i.sharedBy.isEmpty)) {
      setState(
        () => _errors = ServerFormErrors(
          fields: <String, String>{'items': l10n.gxItemNeedsPeople},
        ),
      );
      return null;
    }
    List<ExpensePayerInput>? payers;
    final GroupExpenseDetail? original = widget.original;
    switch (_payerMode) {
      // Without payers the caller paid everything (create and edit). A
      // single other payer is sent without an amount: the server makes them
      // the whole amount (also the derived total of another currency), so
      // the app never computes it.
      case _PayerMode.you:
        payers = null;
      case _PayerMode.one:
        payers = <ExpensePayerInput>[ExpensePayerInput(userId: _payerId ?? '')];
      case _PayerMode.several:
        payers = <ExpensePayerInput>[
          for (final MapEntry<String, TextEditingController> p
              in _payerAmounts.entries)
            if (p.value.text.trim().isNotEmpty)
              ExpensePayerInput(
                userId: p.key,
                amount: _amountOf(p.value.text) ?? '',
              ),
        ];
    }
    return GroupExpenseInput(
      description: _description.text.trim(),
      amount: amount,
      expenseDate: _date,
      categoryKey: _category,
      notes: _editing ? _notes.text.trim() : _trimmed(_notes),
      splitMethod: GroupExpenseInputSplitMethod.fromJson(_method),
      participants: participants,
      items: items,
      payers: payers,
      originalAmount: _foreign
          ? _amountOf(_originalAmount.text, currency: _originalCurrency)
          : null,
      originalCurrency: _foreign ? _originalCurrency : null,
      fxRateSource: _foreign
          ? (_lookup
                ? GroupExpenseInputFxRateSource.lookup
                : GroupExpenseInputFxRateSource.manual)
          : null,
      fxRate: _foreign && !_lookup ? percentWire(_rate.text) : null,
      payerAccountId: !_editing && _iPay ? _accountId : null,
      receiptFileId: _receiptFileId,
      version: original?.version,
    );
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    final bool valid = _form.currentState?.validate() ?? false;
    final Map<String, String> missing = <String, String>{
      if (_foreign && _originalCurrency == null)
        'currency': l10n.gxChooseCurrency,
      if (_payerMode == _PayerMode.one && _payerId == null)
        'payers': l10n.gxChoosePayer,
    };
    if (missing.isNotEmpty) {
      setState(() => _errors = ServerFormErrors(fields: missing));
    }
    if (!valid || missing.isNotEmpty) {
      return;
    }
    final GroupExpenseInput? input = _build(l10n);
    if (input == null) {
      return;
    }
    final GroupMoneyApi api = ref.read(groupMoneyApiProvider);
    final GroupExpenseDetail? original = widget.original;
    final GoRouter router = GoRouter.of(context);
    try {
      final GroupExpenseDetail saved;
      if (original == null) {
        saved = await api.createExpense(
          _groupId,
          input,
          key: _submission.keyFor(input.toJson()),
        );
        _submission.reset();
      } else {
        saved = await api.updateExpense(_groupId, original.id, input);
      }
      if (!mounted) {
        return;
      }
      groupMoneyChanged(ref, _groupId);
      showSnack(context, _editing ? l10n.gxExpenseSaved : l10n.gxExpenseAdded);
      if (original == null) {
        unawaited(
          router.pushReplacement(
            AppRoutes.groupExpenseDetail(_groupId, saved.id),
          ),
        );
      } else {
        leaveTo(router, AppRoutes.groupExpenseDetail(_groupId, saved.id));
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      if (error.code == ErrorObjectCode.versionConflict && original != null) {
        ref.invalidate(
          groupExpenseProvider((groupId: _groupId, id: original.id)),
        );
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
    final ThemeData theme = Theme.of(context);
    final String? general = _errors.general;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.gxEditExpense : l10n.gxAddExpense),
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
            if (_formerParticipants.isNotEmpty) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.warning,
                message: l10n.gxFormerParticipants(
                  _formerParticipants
                      .map((String id) => _people.name(l10n, id))
                      .join(', '),
                ),
              ),
              const SizedBox(height: Insets.md),
            ],
            TextFormField(
              controller: _description,
              textInputAction: TextInputAction.next,
              maxLength: GroupExpenseInput.descriptionMaxLength,
              decoration: InputDecoration(
                labelText: l10n.descriptionLabel,
                helperText: l10n.gxDescriptionHelp,
                errorText: _errors['description'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            FormSectionHeader(l10n.gxAmountSection),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.gxForeignLabel),
              subtitle: Text(l10n.gxForeignHelp(_currency)),
              value: _foreign,
              onChanged: (bool v) => setState(() {
                _foreign = v;
                if (v && _payerMode == _PayerMode.several) {
                  _payerMode = _PayerMode.you;
                }
              }),
            ),
            if (!_foreign)
              AmountField(
                controller: _amount,
                label: l10n.amountLabel,
                currency: _currency,
                errorText: _errors['amount'],
                onChanged: (_) => setState(() {}),
              )
            else ...<Widget>[
              SelectorField(
                label: l10n.gxOriginalCurrency,
                value: _originalCurrency,
                icon: Icons.currency_exchange,
                errorText: _errors['currency'],
                onTap: _pickCurrency,
              ),
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _originalAmount,
                label: l10n.gxOriginalAmount,
                currency: _originalCurrency,
                errorText: _errors['original'],
              ),
              const SizedBox(height: Insets.sm),
              RadioGroup<bool>(
                groupValue: _lookup,
                onChanged: (bool? v) => setState(() => _lookup = v ?? true),
                child: Column(
                  children: <Widget>[
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      title: Text(l10n.gxRateLookup),
                      subtitle: Text(l10n.gxRateLookupHelp),
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      title: Text(l10n.gxRateManual),
                      subtitle: Text(l10n.gxRateManualHelp(_currency)),
                    ),
                  ],
                ),
              ),
              if (!_lookup)
                TextFormField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.gxRateLabel(
                      _originalCurrency ?? '…',
                      _currency,
                    ),
                    errorText: _errors['rate'],
                  ),
                  validator: (String? v) =>
                      isValidRate(v ?? '') ? null : l10n.gxRateInvalid,
                ),
              if (_errors['rate'] case final String e when _lookup)
                Text(
                  e,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              const SizedBox(height: Insets.xs),
              Text(
                l10n.gxForeignServerAmount(_currency),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.dateLabel,
              value: _date,
              emptyLabel: l10n.gxDateToday,
              errorText: _errors['date'],
              clearable: true,
              onChanged: (String? v) => setState(() => _date = v),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.optionalLabel(l10n.categoryFieldLabel),
              value: _category == null
                  ? null
                  : groupCategoryLabel(l10n, _category),
              icon: Icons.category_outlined,
              errorText: _errors['category'],
              onTap: _pickCategory,
              onClear: () => setState(() => _category = null),
            ),
            FormSectionHeader(l10n.gxSplitSection),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String m in expenseSplitMethods)
                  ChoiceChip(
                    label: Text(splitMethodLabel(l10n, m)),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              splitMethodHelp(l10n, _method),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.sm),
            SplitEditor(
              people: _people,
              method: _method,
              rows: _rows,
              currency: _currency,
              amountText: _foreign ? null : _amount.text,
              errorText: _errors['split'],
              onChanged: () => setState(() {}),
            ),
            if (_method == 'itemized') ..._itemEditor(l10n, theme),
            FormSectionHeader(l10n.gxWhoPaid),
            ..._payerEditor(l10n, theme, accounts),
            FormSectionHeader(l10n.gxMoreSection),
            _receiptTile(l10n),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              maxLength: GroupExpenseInput.notesMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _editing ? l10n.actionSave : l10n.gxAddExpense,
              onPressed: _submit,
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }

  List<Widget> _itemEditor(AppLocalizations l10n, ThemeData theme) {
    final List<SplitRowState> included = _rows
        .where((SplitRowState r) => r.included)
        .toList();
    return <Widget>[
      FormSectionHeader(l10n.gxItemsSection),
      Text(l10n.gxItemsHelp, style: theme.textTheme.bodySmall),
      for (int i = 0; i < _items.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Insets.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _items[i].description,
                  maxLength: ExpenseItemInput.descriptionMaxLength,
                  decoration: InputDecoration(
                    labelText: l10n.gxItemName(i + 1),
                    counterText: '',
                  ),
                  validator: (String? v) =>
                      (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
                ),
                AmountField(
                  controller: _items[i].amount,
                  label: l10n.gxItemAmount,
                  currency: _currency,
                ),
                const SizedBox(height: Insets.xs),
                Text(l10n.gxItemSharedBy, style: theme.textTheme.bodySmall),
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    for (final SplitRowState r in included)
                      FilterChip(
                        label: Text(_people.name(l10n, r.userId)),
                        selected: _items[i].sharedBy.contains(r.userId),
                        onSelected: (bool on) => setState(() {
                          if (on) {
                            _items[i].sharedBy.add(r.userId);
                          } else {
                            _items[i].sharedBy.remove(r.userId);
                          }
                        }),
                      ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _items.removeAt(i).dispose()),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.gxItemRemove),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (_errors['items'] case final String e)
        Text(
          e,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => setState(
            () => _items.add(
              _ItemDraft(
                by: <String>{for (final SplitRowState r in included) r.userId},
              ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: Text(l10n.gxItemAdd),
        ),
      ),
    ];
  }

  List<Widget> _payerEditor(
    AppLocalizations l10n,
    ThemeData theme,
    Map<String, AccountDto> accounts,
  ) {
    final List<Widget> out = <Widget>[
      Wrap(
        spacing: Insets.xs,
        runSpacing: Insets.xs,
        children: <Widget>[
          for (final (_PayerMode mode, String label) in <(_PayerMode, String)>[
            (_PayerMode.you, l10n.gxPayerYou),
            (_PayerMode.one, l10n.gxPayerOne),
            if (!_foreign) (_PayerMode.several, l10n.gxPayerSeveral),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _payerMode == mode,
              onSelected: (_) => setState(() => _payerMode = mode),
            ),
        ],
      ),
      if (_foreign) ...<Widget>[
        const SizedBox(height: Insets.xs),
        Text(
          l10n.gxForeignPayerNote(_currency),
          style: theme.textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: Insets.sm),
    ];
    if (_payerMode == _PayerMode.one) {
      out.add(
        SelectorField(
          label: l10n.gxWhoPaid,
          value: _payerId == null ? null : _people.name(l10n, _payerId),
          icon: Icons.person_outline,
          errorText: _errors['payers'],
          onTap: _pickPayer,
        ),
      );
    } else if (_payerMode == _PayerMode.several) {
      for (final GroupMemberDto m in _people.activeMembers) {
        out
          ..add(
            AmountField(
              controller: _payerAmounts[m.userId]!,
              label: l10n.optionalLabel(
                l10n.gxPaidBy(_people.name(l10n, m.userId)),
              ),
              currency: _currency,
              isRequired: false,
              onChanged: (_) => setState(() {}),
            ),
          )
          ..add(const SizedBox(height: Insets.sm));
      }
      final String? preview = _payersPreview(l10n);
      if (preview != null) {
        out.add(
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.gxPreview(preview),
              style: theme.textTheme.bodySmall,
            ),
          ),
        );
      }
      if (_errors['payers'] case final String e) {
        out.add(
          Text(
            e,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        );
      }
    } else if (_errors['payers'] case final String e) {
      out.add(
        Text(
          e,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }
    if (!_editing && _iPay) {
      out
        ..add(const SizedBox(height: Insets.md))
        ..add(
          SelectorField(
            label: l10n.optionalLabel(l10n.gxRecordInAccount),
            value: _accountId == null ? null : accounts[_accountId]?.name,
            icon: Icons.account_balance_wallet_outlined,
            helperText: l10n.gxRecordInAccountHelp,
            errorText: _errors['account'],
            onTap: _pickAccount,
            onClear: () => setState(() => _accountId = null),
          ),
        );
    }
    return out;
  }

  String? _payersPreview(AppLocalizations l10n) {
    final int exponent = exponentFor(_currency);
    int paid = 0;
    for (final TextEditingController c in _payerAmounts.values) {
      final String? v = c.text.trim().isEmpty ? null : _amountOf(c.text);
      paid += v == null ? 0 : (minorOf(v, exponent) ?? 0);
    }
    final String? total = _amountOf(_amount.text);
    final int? totalMinor = total == null ? null : minorOf(total, exponent);
    if (totalMinor == null) {
      return null;
    }
    final String locale = Localizations.localeOf(context).toString();
    final int left = totalMinor - paid;
    final String paidText = formatMoneyLocale(paid, locale);
    if (left == 0) {
      return l10n.gxPreviewPayersOk;
    }
    final String diff = formatMoneyLocale(left.abs(), locale);
    return left > 0
        ? l10n.gxPreviewLeft(paidText, diff)
        : l10n.gxPreviewTooMuch(paidText, diff);
  }

  String formatMoneyLocale(int minor, String locale) =>
      formatMoneyText(moneyOfMinor(minor, _currency), locale);

  Widget _receiptTile(AppLocalizations l10n) {
    final String? id = _receiptFileId;
    if (id == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _attachReceipt,
              icon: const Icon(Icons.attach_file),
              label: Text(l10n.gxAttachReceipt),
            ),
            if (_errors['receipt'] case final String e)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.attach_file),
      title: Text(_receiptName ?? l10n.gxReceiptAttached),
      subtitle: Text(l10n.gxReceiptHelp),
      trailing: IconButton(
        tooltip: l10n.gxReceiptRemove,
        icon: const Icon(Icons.close),
        onPressed: () => setState(() {
          _receiptFileId = null;
          _receiptName = null;
        }),
      ),
    );
  }
}
