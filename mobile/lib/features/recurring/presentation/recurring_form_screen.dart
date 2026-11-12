import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
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
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/recurring/application/recurring_providers.dart';
import 'package:montra_mobile/features/recurring/data/recurring_api.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';
import 'package:montra_mobile/features/recurring/presentation/schedule_editor.dart';

/// Creates a recurring expense, income or transfer (with an
/// `Idempotency-Key`, so a retry never adds it twice), or edits one. Edits
/// apply to this and future occurrences and send only the changed fields
/// with the `version` they were loaded at (`RecurringRulePatch`); a
/// concurrent change answers `VERSION_CONFLICT` and the latest version is
/// loaded.
class RecurringFormScreen extends ConsumerWidget {
  /// Creates the form; [ruleId] switches to edit mode.
  const RecurringFormScreen({this.ruleId, super.key});

  /// Rule to edit, or null to create one.
  final String? ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = ruleId;
    final AppLocalizations l10n = context.l10n;
    if (id == null) {
      return const _RuleForm();
    }
    final AsyncValue<RecurringRuleDetail> rule = ref.watch(
      recurringRuleProvider(id),
    );
    return rule.when(
      skipLoadingOnReload: true,
      data: (RecurringRuleDetail r) => _RuleForm(original: r),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.recurringEditTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.recurringEditTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(recurringRuleProvider(id)),
        ),
      ),
    );
  }
}

class _RuleForm extends ConsumerStatefulWidget {
  const _RuleForm({this.original});

  final RecurringRuleDetail? original;

  @override
  ConsumerState<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<_RuleForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  RecurringRuleInputKind _kind = RecurringRuleInputKind.expense;
  bool _variable = false;
  bool _autoPost = false;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _merchantName;
  String? _merchantId;
  List<int> _reminders = const <int>[1];
  late ScheduleValue _schedule;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;
  final IdempotentSubmission _submission = IdempotentSubmission();

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'kind': 'kind',
    'amount': 'amount',
    'currency': 'amount',
    'amount_is_variable': 'amount',
    'account_id': 'account',
    'to_account_id': 'toAccount',
    'category_id': 'category',
    'merchant_name': 'merchant',
    'description': 'description',
    'notes': 'notes',
    'auto_post': 'autoPost',
    'reminder_days_before': 'reminders',
    'frequency': 'frequency',
    'interval_count': 'interval',
    'interval_unit': 'interval',
    'by_month_day': 'anchor',
    'by_weekday': 'anchor',
    'by_week_of_month': 'anchor',
    'start_date': 'start',
    'end_date': 'end',
    'max_occurrences': 'count',
    'local_time': 'time',
    'timezone': 'time',
  };

  bool get _editing => widget.original != null;

  bool get _isTransfer => _kind == RecurringRuleInputKind.transfer;

  @override
  void initState() {
    super.initState();
    _schedule = ScheduleValue.monthly(LocalDates.format(LocalDates.today()));
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _RuleForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final RecurringRuleDetail? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      // A newer version arrived (after a conflict): show what is stored now.
      _load(next);
    }
  }

  void _load(RecurringRuleDetail? r) {
    if (r == null) {
      return;
    }
    _name.text = r.name;
    _amount.text = r.amount?.amount ?? '';
    _description.text = r.description ?? '';
    _notes.text = r.notes ?? '';
    _kind = recurringInputKindOf(r.kind);
    _variable = r.amountIsVariable;
    _autoPost = r.autoPost;
    _accountId = r.accountId;
    _toAccountId = r.toAccountId;
    _categoryId = r.categoryId;
    // Rules carry their merchant by name, so edits keep it as it is.
    _merchantId = r.merchant?.id ?? r.merchantId;
    _merchantName = r.merchant?.name;
    _reminders = List<int>.of(r.reminderDaysBefore);
    _schedule = ScheduleValue.fromDetail(r);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _trimmed(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  /// Currency of the amount: the account's, else the rule's, else the
  /// user's base currency.
  String? _currency(Map<String, AccountDto> accounts) {
    final AccountDto? account = _accountId == null
        ? null
        : accounts[_accountId];
    if (account != null) {
      return account.currency;
    }
    final String? original = widget.original?.currency;
    if (original != null) {
      return original;
    }
    final AuthState auth = ref.read(authControllerProvider);
    return auth is SignedIn ? auth.user.baseCurrency : null;
  }

  bool get _canAutoPost => !_variable && _accountId != null;

  Future<void> _pickAccount({required bool destination}) async {
    final AppLocalizations l10n = context.l10n;
    final AccountDto? picked = await showAccountPicker(
      context,
      selectedId: destination ? _toAccountId : _accountId,
      exclude: <String>{?(destination ? _accountId : _toAccountId)},
      title: destination
          ? l10n.recurringToAccountLabel
          : (_isTransfer
                ? l10n.recurringFromAccountLabel
                : l10n.accountPickerTitle),
    );
    if (picked != null && mounted) {
      setState(() {
        if (destination) {
          _toAccountId = picked.id;
        } else {
          _accountId = picked.id;
        }
      });
    }
  }

  Future<void> _pickCategory() async {
    final Picked<CategoryDto>? picked = await showCategoryPicker(
      context,
      kind: _kind == RecurringRuleInputKind.income
          ? CategoryKindFilter.income
          : CategoryKindFilter.spending,
      selectedId: _categoryId,
    );
    if (picked != null && mounted) {
      setState(() => _categoryId = picked.value?.id);
    }
  }

  Future<void> _pickMerchant() async {
    final Picked<MerchantChoice>? picked = await showMerchantPicker(
      context,
      selectedId: _merchantId,
    );
    if (picked != null && mounted) {
      setState(() {
        _merchantId = picked.value?.id;
        _merchantName = picked.value?.name;
      });
    }
  }

  Future<void> _submit() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    final bool valid = _form.currentState?.validate() ?? false;
    final Map<String, String> missing = <String, String>{
      if (_isTransfer && _accountId == null)
        'account': l10n.recurringAccountRequired,
      if (_isTransfer && _toAccountId == null)
        'toAccount': l10n.recurringAccountRequired,
    };
    if (!valid || missing.isNotEmpty) {
      setState(() => _errors = ServerFormErrors(fields: missing));
      return;
    }
    final Map<String, AccountDto> accounts = ref.read(accountIndexProvider);
    final String? currency = _currency(accounts);
    String? amount;
    if (!_variable && _amount.text.trim().isNotEmpty) {
      amount = readAmount(context, ref, _amount.text, currency: currency).value;
    }
    final ScheduleValue s = _schedule.normalized();
    final RecurringRuleDetail? original = widget.original;
    // An edit keeps the rule's currency unless the account changes.
    final String? ruleCurrency =
        original != null && _accountId == original.accountId
        ? original.currency
        : currency;
    final RecurringRuleInput input = RecurringRuleInput(
      kind: _kind,
      name: _name.text.trim(),
      amount: amount,
      amountIsVariable: _variable,
      currency: ruleCurrency,
      accountId: _accountId,
      toAccountId: _isTransfer ? _toAccountId : null,
      categoryId: _isTransfer ? null : _categoryId,
      merchantName: _isTransfer ? null : _merchantName,
      description: _trimmed(_description),
      notes: _trimmed(_notes),
      autoPost: _canAutoPost && _autoPost,
      frequency: recurringFrequencyOf(s.frequency),
      intervalCount: s.intervalCount,
      intervalUnit: recurringIntervalUnitOf(s.intervalUnit),
      byMonthDay: s.byMonthDay,
      byWeekday: s.byWeekday,
      byWeekOfMonth: s.byWeekOfMonth,
      startDate: s.startDate,
      endDate: s.endDate,
      maxOccurrences: s.maxOccurrences,
      localTime: s.localTime,
      timezone: original?.timezone,
      reminderDaysBefore: _reminders,
    );
    final RecurringApi api = ref.read(recurringApiProvider);
    try {
      if (original == null) {
        await api.create(input, key: _submission.keyFor(input.toJson()));
        _submission.reset();
      } else {
        final RecurringRulePatch patch = recurringPatchFor(original, input);
        if (!patchHasChanges(patch.toJson(), always: <String>{'version'})) {
          if (mounted) {
            showSnack(context, l10n.recurringNoChanges);
            context.pop();
          }
          return;
        }
        await api.update(original.id, patch);
      }
      finance.bump();
      if (!mounted) {
        return;
      }
      showSnack(
        context,
        _editing ? l10n.recurringSaved : l10n.recurringCreated,
      );
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      if (error.code == ErrorObjectCode.versionConflict && original != null) {
        ref.invalidate(recurringRuleProvider(original.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      if (error.details.any(
        (Detail d) => d.code == 'auto_post_needs_amount_and_account',
      )) {
        setState(
          () => _errors = ServerFormErrors(
            fields: <String, String>{
              'autoPost': l10n.recurringAutoPostNeedsAmount,
            },
          ),
        );
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
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final String? general = _errors.general;
    final String? currency = _currency(accounts);
    final CategoryDto? category = _categoryId == null
        ? null
        : categories[_categoryId];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? l10n.recurringEditTitle : l10n.recurringNewTitle,
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
            if (_editing) ...<Widget>[
              NoticeBanner(message: l10n.recurringEditFutureNote),
              const SizedBox(height: Insets.md),
            ],
            Semantics(
              label: l10n.recurringKindLabel,
              child: SegmentedButton<RecurringRuleInputKind>(
                segments: <ButtonSegment<RecurringRuleInputKind>>[
                  for (final RecurringRuleInputKind k in recurringFormKinds)
                    ButtonSegment<RecurringRuleInputKind>(
                      value: k,
                      label: Text(recurringKindLabel(l10n, k.json)),
                    ),
                ],
                selected: <RecurringRuleInputKind>{_kind},
                onSelectionChanged: _editing
                    ? null
                    : (Set<RecurringRuleInputKind> s) => setState(() {
                        _kind = s.first;
                        _categoryId = null;
                      }),
              ),
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(top: Insets.xs),
                child: Text(
                  l10n.recurringKindFixed,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              maxLength: RecurringRuleInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.recurringNameLabel,
                helperText: l10n.recurringNameHelp,
                errorText: _errors['name'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            FormSectionHeader(l10n.recurringAmountSection),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.recurringVariableLabel),
              subtitle: Text(l10n.recurringVariableHelp),
              value: _variable,
              onChanged: (bool v) => setState(() {
                _variable = v;
                if (v) {
                  _autoPost = false;
                }
              }),
            ),
            if (!_variable) ...<Widget>[
              const SizedBox(height: Insets.sm),
              AmountField(
                controller: _amount,
                label: l10n.recurringAmountLabel,
                currency: currency,
                errorText: _errors['amount'],
              ),
            ] else if (_errors['amount'] case final String e)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: _isTransfer
                  ? l10n.recurringFromAccountLabel
                  : l10n.optionalLabel(l10n.accountFieldLabel),
              value: _accountId == null ? null : accounts[_accountId]?.name,
              icon: Icons.account_balance_wallet_outlined,
              errorText: _errors['account'],
              onTap: () => _pickAccount(destination: false),
              onClear: _isTransfer
                  ? null
                  : () => setState(() {
                      _accountId = null;
                      _autoPost = false;
                    }),
            ),
            if (_isTransfer) ...<Widget>[
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.recurringToAccountLabel,
                value: _toAccountId == null
                    ? null
                    : accounts[_toAccountId]?.name,
                icon: Icons.login,
                errorText: _errors['toAccount'],
                onTap: () => _pickAccount(destination: true),
              ),
            ] else ...<Widget>[
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.optionalLabel(l10n.categoryFieldLabel),
                value: category == null ? null : categoryName(l10n, category),
                icon: Icons.category_outlined,
                errorText: _errors['category'],
                onTap: _pickCategory,
                onClear: () => setState(() => _categoryId = null),
              ),
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.optionalLabel(l10n.merchantFieldLabel),
                value: _merchantName,
                icon: Icons.storefront_outlined,
                errorText: _errors['merchant'],
                onTap: _pickMerchant,
                onClear: () => setState(() {
                  _merchantId = null;
                  _merchantName = null;
                }),
              ),
            ],
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.recurringAutoPostLabel),
              subtitle: Text(
                _errors['autoPost'] ??
                    (_canAutoPost
                        ? l10n.recurringAutoPostHelp
                        : l10n.recurringAutoPostNeedsAmount),
              ),
              value: _canAutoPost && _autoPost,
              onChanged: _canAutoPost
                  ? (bool v) => setState(() => _autoPost = v)
                  : null,
            ),
            FormSectionHeader(l10n.scheduleTitle),
            if (_schedule.isKnown)
              ScheduleEditor(
                key: ValueKey<int?>(widget.original?.version),
                value: _schedule,
                errors: _errors.fields,
                onChanged: (ScheduleValue v) => setState(() => _schedule = v),
              )
            else
              NoticeBanner(message: l10n.recurringScheduleUnknown),
            const SizedBox(height: Insets.md),
            ReminderDaysField(
              key: ValueKey<String>('reminders-${widget.original?.version}'),
              value: _reminders,
              onChanged: (List<int> v) => setState(() => _reminders = v),
            ),
            if (_errors['reminders'] case final String e)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FormSectionHeader(l10n.recurringMoreSection),
            TextFormField(
              controller: _description,
              textInputAction: TextInputAction.next,
              maxLength: RecurringRuleInput.descriptionMaxLength,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(
                  RecurringRuleInput.descriptionMaxLength,
                ),
              ],
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.descriptionLabel),
                errorText: _errors['description'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              maxLength: RecurringRuleInput.notesMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _editing ? l10n.actionSave : l10n.recurringCreateButton,
              onPressed: _submit,
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
