import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/frequency.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/reminder_days_field.dart';
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
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';
import 'package:montra_mobile/features/subscriptions/application/subscriptions_providers.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';
import 'package:montra_mobile/features/subscriptions/domain/subscription_display.dart';

/// Most cancellation checklist steps the server accepts.
const int subscriptionChecklistMax = 20;

/// Longest checklist step the server accepts.
const int subscriptionChecklistItemMax = 200;

/// Adds a subscription by hand (with an `Idempotency-Key`, so a retry never
/// adds it twice) or edits one. Edits send only the changed details with
/// the `version` they were loaded at (`SubscriptionPatch`): emptied text is
/// cleared, removed links go in `clear`, and a newer version reloads the
/// form. A cancelled subscription's cancellation date can be corrected.
class SubscriptionFormScreen extends ConsumerWidget {
  /// Creates the form; [subscriptionId] switches to edit mode.
  const SubscriptionFormScreen({this.subscriptionId, super.key});

  /// Subscription to edit, or null to add one.
  final String? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = subscriptionId;
    if (id == null) {
      return const _SubscriptionForm();
    }
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<SubscriptionDetail> detail = ref.watch(
      subscriptionDetailProvider(id),
    );
    return detail.when(
      skipLoadingOnReload: true,
      data: (SubscriptionDetail d) => _SubscriptionForm(original: d),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.subscriptionEditTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.subscriptionEditTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(subscriptionDetailProvider(id)),
        ),
      ),
    );
  }
}

class _SubscriptionForm extends ConsumerStatefulWidget {
  const _SubscriptionForm({this.original});

  final SubscriptionDetail? original;

  @override
  ConsumerState<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends ConsumerState<_SubscriptionForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _plan = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _interval = TextEditingController(text: '1');
  final TextEditingController _url = TextEditingController();
  final TextEditingController _instructions = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _newStep = TextEditingController();

  MerchantChoice? _merchant;
  String? _currency;
  bool _currencyChosen = false;
  SubscriptionInputBillingFrequency? _frequency =
      SubscriptionInputBillingFrequency.monthly;
  SubscriptionInputIntervalUnit? _unit = SubscriptionInputIntervalUnit.month;
  String? _startDate;
  String? _trialEndsOn;
  String? _nextRenewal;
  String? _cancelledOn;
  String? _accountId;
  String? _categoryId;
  String? _groupId;
  List<int> _reminders = const <int>[3];
  List<CancellationChecklistItem> _checklist =
      const <CancellationChecklistItem>[];
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;
  final IdempotentSubmission _submission = IdempotentSubmission();

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'plan_name': 'plan',
    'merchant_name': 'merchant',
    'amount': 'amount',
    'currency': 'currency',
    'billing_frequency': 'frequency',
    'interval_count': 'interval',
    'interval_unit': 'unit',
    'start_date': 'start',
    'trial_ends_on': 'trial',
    'next_renewal_date': 'next',
    'payment_account_id': 'account',
    'category_id': 'category',
    'group_id': 'group',
    'reminder_days_before': 'reminders',
    'cancellation_url': 'url',
    'cancellation_instructions': 'instructions',
    'cancellation_checklist': 'checklist',
    'notes': 'notes',
    'cancelled_on': 'cancelledOn',
  };

  /// Billing cycles offered, in order.
  static const List<SubscriptionInputBillingFrequency> _frequencies =
      <SubscriptionInputBillingFrequency>[
        SubscriptionInputBillingFrequency.weekly,
        SubscriptionInputBillingFrequency.monthly,
        SubscriptionInputBillingFrequency.quarterly,
        SubscriptionInputBillingFrequency.semiannual,
        SubscriptionInputBillingFrequency.yearly,
        SubscriptionInputBillingFrequency.custom,
      ];

  static const List<SubscriptionInputIntervalUnit> _units =
      <SubscriptionInputIntervalUnit>[
        SubscriptionInputIntervalUnit.day,
        SubscriptionInputIntervalUnit.week,
        SubscriptionInputIntervalUnit.month,
        SubscriptionInputIntervalUnit.year,
      ];

  bool get _editing => widget.original != null;

  bool get _custom => _frequency == SubscriptionInputBillingFrequency.custom;

  @override
  void initState() {
    super.initState();
    final SubscriptionDetail? original = widget.original;
    if (original == null) {
      final AuthState auth = ref.read(authControllerProvider);
      _currency = auth is SignedIn ? auth.user.baseCurrency : null;
      _startDate = LocalDates.format(LocalDates.today());
    } else {
      _load(original);
    }
  }

  @override
  void didUpdateWidget(covariant _SubscriptionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final SubscriptionDetail? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      // A newer version arrived (after a conflict): show what is stored now.
      _load(next);
    }
  }

  void _load(SubscriptionDetail d) {
    _name.text = d.name;
    _plan.text = d.planName ?? '';
    _amount.text = d.amount.amount;
    _currency = d.amount.currency;
    _currencyChosen = true;
    final SubscriptionInputBillingFrequency frequency =
        SubscriptionInputBillingFrequency.fromJson(d.billingFrequency.json);
    _frequency = frequency == SubscriptionInputBillingFrequency.unrecognized
        ? null
        : frequency;
    final String? unit = d.intervalUnit?.json;
    final SubscriptionInputIntervalUnit parsedUnit = unit == null
        ? SubscriptionInputIntervalUnit.month
        : SubscriptionInputIntervalUnit.fromJson(unit);
    _unit = parsedUnit == SubscriptionInputIntervalUnit.unrecognized
        ? null
        : parsedUnit;
    _interval.text = '${d.intervalCount}';
    _merchant = switch (d.merchant) {
      final MerchantRef m => MerchantChoice(id: m.id, name: m.name),
      null => null,
    };
    _startDate = d.startDate;
    _trialEndsOn = d.trialEndsOn;
    _nextRenewal = d.nextRenewalDate;
    _cancelledOn = d.cancelledOn;
    _accountId = d.paymentAccountId;
    _categoryId = d.categoryId;
    _groupId = d.groupId;
    _reminders = List<int>.of(d.reminderDaysBefore);
    _checklist = List<CancellationChecklistItem>.of(d.cancellationChecklist);
    _url.text = d.cancellationUrl ?? '';
    _instructions.text = d.cancellationInstructions ?? '';
    _notes.text = d.notes ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _plan.dispose();
    _amount.dispose();
    _interval.dispose();
    _url.dispose();
    _instructions.dispose();
    _notes.dispose();
    _newStep.dispose();
    super.dispose();
  }

  String? _trimmed(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
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

  Future<void> _pickCurrency() async {
    final String? code = await showCurrencyPicker(context, selected: _currency);
    if (code != null && mounted) {
      setState(() {
        _currency = code;
        _currencyChosen = true;
      });
    }
  }

  Future<void> _pickAccount() async {
    final AccountDto? account = await showAccountPicker(
      context,
      selectedId: _accountId,
      title: context.l10n.subscriptionPaymentAccountLabel,
    );
    if (account != null && mounted) {
      setState(() {
        _accountId = account.id;
        // The subscription follows the account's currency unless the user
        // chose one.
        if (!_currencyChosen) {
          _currency = account.currency;
        }
      });
    }
  }

  Future<void> _pickCategory() async {
    final Picked<CategoryDto>? picked = await showCategoryPicker(
      context,
      kind: CategoryKindFilter.spending,
      selectedId: _categoryId,
    );
    if (picked != null && mounted) {
      setState(() => _categoryId = picked.value?.id);
    }
  }

  Future<void> _pickGroup() async {
    final Picked<GroupDto>? picked = await showGroupPicker(
      context,
      selectedId: _groupId,
    );
    if (picked != null && mounted) {
      setState(() => _groupId = picked.value?.id);
    }
  }

  void _addStep() {
    final String text = _newStep.text.trim();
    if (text.isEmpty || _checklist.length >= subscriptionChecklistMax) {
      return;
    }
    setState(() {
      _checklist = <CancellationChecklistItem>[
        ..._checklist,
        CancellationChecklistItem(item: text, done: false),
      ];
      _newStep.clear();
    });
  }

  void _setStepDone(int index, bool done) {
    setState(() {
      _checklist = <CancellationChecklistItem>[
        for (int i = 0; i < _checklist.length; i++)
          i == index
              ? CancellationChecklistItem(item: _checklist[i].item, done: done)
              : _checklist[i],
      ];
    });
  }

  void _removeStep(int index) {
    setState(() {
      _checklist = <CancellationChecklistItem>[
        for (int i = 0; i < _checklist.length; i++)
          if (i != index) _checklist[i],
      ];
    });
  }

  SubscriptionInput _input(String amount) {
    final SubscriptionDetail? original = widget.original;
    return SubscriptionInput(
      name: _name.text.trim(),
      planName: _trimmed(_plan),
      merchantName: _merchant?.name,
      amount: amount,
      currency: _currency,
      billingFrequency: _frequency!,
      intervalCount: _custom ? int.tryParse(_interval.text.trim()) : null,
      intervalUnit: _custom ? _unit : null,
      startDate: _startDate ?? LocalDates.format(LocalDates.today()),
      nextRenewalDate: _nextRenewal,
      trialEndsOn: _trialEndsOn,
      paymentAccountId: _accountId,
      categoryId: _categoryId,
      groupId: _groupId,
      // Files are managed elsewhere; keep the one already linked.
      invoiceFileId: original?.invoiceFileId,
      cancellationUrl: _trimmed(_url),
      cancellationInstructions: _trimmed(_instructions),
      cancellationChecklist: _checklist,
      notes: _trimmed(_notes),
      reminderDaysBefore: _reminders,
      version: original?.version,
    );
  }

  /// Whether the cancellation date can be corrected (cancelled ones only).
  bool get _cancelled =>
      widget.original?.status == SubscriptionDetailStatus.cancelled;

  /// The form as `PATCH` JSON: what [_input] sends, without the version and
  /// the invoice file (never changed here), plus the cancellation date of
  /// a cancelled subscription.
  Map<String, Object?> _editJson(String amount) => <String, Object?>{
    ..._input(amount).toJson()
      ..remove('version')
      ..remove('invoice_file_id'),
    if (_cancelled) 'cancelled_on': ?_cancelledOn,
  };

  Future<void> _submit() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String? amount = readAmount(
      context,
      ref,
      _amount.text,
      currency: _currency,
    ).value;
    if (amount == null) {
      return;
    }
    final SubscriptionsApi api = ref.read(subscriptionsApiProvider);
    final SubscriptionDetail? original = widget.original;
    try {
      final SubscriptionDetail saved;
      if (original == null) {
        final SubscriptionInput input = _input(amount);
        saved = await api.create(
          input,
          key: _submission.keyFor(input.toJson()),
        );
        _submission.reset();
      } else {
        final SubscriptionPatch patch = subscriptionPatchFor(
          original,
          _editJson(amount),
        );
        if (!patchHasChanges(patch.toJson())) {
          if (mounted) {
            showSnack(context, l10n.subscriptionNoChanges);
            context.pop();
          }
          return;
        }
        saved = await api.update(original.id, patch);
      }
      finance.bump();
      if (!mounted) {
        return;
      }
      if (original == null) {
        showSnack(context, l10n.subscriptionCreated);
        // The detail shows the normalized cost and any look-alikes.
        context.pushReplacement(AppRoutes.subscriptionDetail(saved.id));
      } else {
        showSnack(context, l10n.subscriptionSaved);
        context.pop(saved);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      if (error.code == ErrorObjectCode.versionConflict && original != null) {
        ref.invalidate(subscriptionDetailProvider(original.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  String? _validateUrl(AppLocalizations l10n, String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) {
      return null;
    }
    if (!v.toLowerCase().startsWith('https://') ||
        RegExp(r'[\s<>"]').hasMatch(v)) {
      return l10n.subscriptionCancellationUrlInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final Map<String, GroupDto> groups = ref.watch(groupIndexProvider);
    final String version = '${widget.original?.version}';
    final String? accountId = _accountId;
    final String? categoryId = _categoryId;
    final String? groupId = _groupId;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? l10n.subscriptionEditTitle : l10n.subscriptionNewTitle,
        ),
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
              textInputAction: TextInputAction.next,
              maxLength: SubscriptionInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.subscriptionNameLabel,
                helperText: l10n.subscriptionNameHelp,
                errorText: _errors['name'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _plan,
              textInputAction: TextInputAction.next,
              maxLength: SubscriptionInput.planNameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.subscriptionPlanLabel),
                errorText: _errors['plan'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.merchantFieldLabel,
              icon: Icons.storefront_outlined,
              value: _merchant?.name,
              placeholder: l10n.merchantNone,
              errorText: _errors['merchant'],
              onTap: _pickMerchant,
              onClear: () => setState(() => _merchant = null),
            ),
            FormSectionHeader(l10n.subscriptionPriceSection),
            AmountField(
              controller: _amount,
              label: l10n.subscriptionAmountLabel,
              currency: _currency,
              errorText: _errors['amount'],
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.currencyFieldLabel,
              value: _currency,
              icon: Icons.currency_exchange,
              errorText: _errors['currency'],
              onTap: _pickCurrency,
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<SubscriptionInputBillingFrequency>(
              key: ValueKey<String>('frequency-$version'),
              initialValue: _frequency,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.subscriptionFrequencyLabel,
                errorText: _errors['frequency'],
              ),
              items: <DropdownMenuItem<SubscriptionInputBillingFrequency>>[
                for (final SubscriptionInputBillingFrequency f in _frequencies)
                  DropdownMenuItem<SubscriptionInputBillingFrequency>(
                    value: f,
                    child: Text(frequencyLabel(l10n, f.json)),
                  ),
              ],
              validator: (SubscriptionInputBillingFrequency? f) =>
                  f == null ? l10n.subscriptionFrequencyRequired : null,
              onChanged: (SubscriptionInputBillingFrequency? f) =>
                  setState(() => _frequency = f),
            ),
            if (_custom) ...<Widget>[
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _interval,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: l10n.subscriptionIntervalCountLabel,
                  errorText: _errors['interval'],
                ),
                validator: (String? v) {
                  final int? n = int.tryParse((v ?? '').trim());
                  return n == null || n < 1 || n > 366
                      ? l10n.subscriptionIntervalInvalid
                      : null;
                },
              ),
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<SubscriptionInputIntervalUnit>(
                key: ValueKey<String>('unit-$version'),
                initialValue: _unit,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionIntervalUnitLabel,
                  errorText: _errors['unit'],
                ),
                items: <DropdownMenuItem<SubscriptionInputIntervalUnit>>[
                  for (final SubscriptionInputIntervalUnit u in _units)
                    DropdownMenuItem<SubscriptionInputIntervalUnit>(
                      value: u,
                      child: Text(intervalUnitLabel(l10n, u.json)),
                    ),
                ],
                validator: (SubscriptionInputIntervalUnit? u) =>
                    u == null ? l10n.validationRequired : null,
                onChanged: (SubscriptionInputIntervalUnit? u) =>
                    setState(() => _unit = u),
              ),
            ],
            FormSectionHeader(l10n.subscriptionDatesSection),
            DateSelectorField(
              label: l10n.subscriptionStartLabel,
              value: _startDate,
              errorText: _errors['start'],
              onChanged: (String? d) => setState(() => _startDate = d),
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.optionalLabel(l10n.subscriptionTrialLabel),
              value: _trialEndsOn,
              emptyLabel: l10n.subscriptionNoTrial,
              clearable: true,
              errorText: _errors['trial'],
              onChanged: (String? d) => setState(() => _trialEndsOn = d),
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.subscriptionNextRenewalLabel,
              value: _nextRenewal,
              emptyLabel: l10n.subscriptionNextRenewalAuto,
              helperText: l10n.subscriptionNextRenewalHelp,
              clearable: true,
              errorText: _errors['next'],
              onChanged: (String? d) => setState(() => _nextRenewal = d),
            ),
            if (_cancelled) ...<Widget>[
              const SizedBox(height: Insets.md),
              DateSelectorField(
                label: l10n.subscriptionCancelledOn,
                value: _cancelledOn,
                helperText: l10n.subscriptionCancelledOnHelp,
                lastDate: LocalDates.today(),
                errorText: _errors['cancelledOn'],
                onChanged: (String? d) => setState(() => _cancelledOn = d),
              ),
            ],
            FormSectionHeader(l10n.subscriptionPaymentSection),
            SelectorField(
              label: l10n.subscriptionPaymentAccountLabel,
              icon: Icons.account_balance_wallet_outlined,
              value: accountId == null
                  ? null
                  : (accounts[accountId]?.name ?? l10n.paymentAccountUnknown),
              placeholder: l10n.subscriptionPaymentAccountNone,
              errorText: _errors['account'],
              onTap: _pickAccount,
              onClear: () => setState(() => _accountId = null),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.categoryFieldLabel,
              icon: Icons.category_outlined,
              value: categoryId == null
                  ? null
                  : switch (categories[categoryId]) {
                      final CategoryDto c => categoryName(l10n, c),
                      null => l10n.subscriptionCategoryUnavailable,
                    },
              placeholder: l10n.categoryNone,
              errorText: _errors['category'],
              onTap: _pickCategory,
              onClear: () => setState(() => _categoryId = null),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.subscriptionGroupLabel,
              icon: Icons.groups_outlined,
              value: groupId == null
                  ? null
                  : (groups[groupId]?.name ??
                        l10n.subscriptionGroupUnavailable),
              placeholder: l10n.groupNone,
              helperText: l10n.subscriptionGroupHelp,
              errorText: _errors['group'],
              onTap: _pickGroup,
              onClear: () => setState(() => _groupId = null),
            ),
            FormSectionHeader(l10n.subscriptionRemindersSection),
            ReminderDaysField(
              value: _reminders,
              label: l10n.subscriptionRemindersLabel,
              onChanged: (List<int> v) => setState(() => _reminders = v),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              l10n.subscriptionRemindersHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_errors['reminders'] case final String message)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FormSectionHeader(l10n.subscriptionCancellationSection),
            TextFormField(
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              maxLength: SubscriptionInput.cancellationUrlMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(
                  l10n.subscriptionCancellationUrlLabel,
                ),
                helperText: l10n.subscriptionCancellationUrlHelp,
                errorText: _errors['url'],
                counterText: '',
              ),
              validator: (String? v) => _validateUrl(l10n, v),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _instructions,
              minLines: 2,
              maxLines: 6,
              maxLength: SubscriptionInput.cancellationInstructionsMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(
                  l10n.subscriptionCancellationHowLabel,
                ),
                errorText: _errors['instructions'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            _ChecklistEditor(
              steps: _checklist,
              controller: _newStep,
              errorText: _errors['checklist'],
              onAdd: _addStep,
              onDone: _setStepDone,
              onRemove: _removeStep,
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 6,
              maxLength: SubscriptionInput.notesMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
                counterText: '',
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

class _ChecklistEditor extends StatelessWidget {
  const _ChecklistEditor({
    required this.steps,
    required this.controller,
    required this.onAdd,
    required this.onDone,
    required this.onRemove,
    this.errorText,
  });

  final List<CancellationChecklistItem> steps;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final void Function(int index, bool done) onDone;
  final void Function(int index) onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final bool full = steps.length >= subscriptionChecklistMax;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(l10n.subscriptionChecklistTitle, style: text.titleSmall),
        ),
        Text(l10n.subscriptionChecklistHelp, style: text.bodySmall),
        for (int i = 0; i < steps.length; i++)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: steps[i].done,
            onChanged: (bool? v) => onDone(i, v ?? false),
            title: Text(steps[i].item),
            secondary: IconButton(
              tooltip: l10n.subscriptionChecklistRemove(steps[i].item),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onRemove(i),
            ),
          ),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              l10n.subscriptionChecklistFull(subscriptionChecklistMax),
              style: text.bodySmall,
            ),
          )
        else
          TextField(
            controller: controller,
            maxLength: subscriptionChecklistItemMax,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              labelText: l10n.subscriptionChecklistAdd,
              counterText: '',
              errorText: errorText,
              suffixIcon: IconButton(
                tooltip: l10n.subscriptionChecklistAddButton,
                icon: const Icon(Icons.add),
                onPressed: onAdd,
              ),
            ),
          ),
      ],
    );
  }
}
