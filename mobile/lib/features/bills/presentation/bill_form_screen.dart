import 'package:flutter/material.dart';
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
import 'package:montra_mobile/features/bills/application/bills_providers.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/bills/domain/bill_display.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';
import 'package:montra_mobile/features/recurring/presentation/schedule_editor.dart';

/// Creates a bill (with an `Idempotency-Key`, so a retry never adds it
/// twice) or edits one and its future schedule. Edits send only the
/// changed fields with the `version` they were loaded at (`BillPatch`):
/// emptied optional fields are cleared, and a concurrent change loads the
/// latest version.
class BillFormScreen extends ConsumerWidget {
  /// Creates the form; [billId] switches to edit mode.
  const BillFormScreen({this.billId, super.key});

  /// Bill to edit, or null to create one.
  final String? billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = billId;
    final AppLocalizations l10n = context.l10n;
    if (id == null) {
      return const _BillForm();
    }
    final AsyncValue<BillDetail> bill = ref.watch(billProvider(id));
    return bill.when(
      skipLoadingOnReload: true,
      data: (BillDetail b) => _BillForm(original: b),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.billEditTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.billEditTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(billProvider(id)),
        ),
      ),
    );
  }
}

class _BillForm extends ConsumerStatefulWidget {
  const _BillForm({this.original});

  final BillDetail? original;

  @override
  ConsumerState<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends ConsumerState<_BillForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _provider = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  bool _variable = false;
  String? _accountId;
  String? _categoryId;
  List<int> _reminders = const <int>[1];
  late ScheduleValue _schedule;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;
  final IdempotentSubmission _submission = IdempotentSubmission();

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'provider_name': 'provider',
    'expected_amount': 'amount',
    'amount_is_variable': 'amount',
    'currency': 'amount',
    'payment_account_id': 'account',
    'category_id': 'category',
    'notes': 'notes',
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

  @override
  void initState() {
    super.initState();
    _schedule = ScheduleValue.monthly(LocalDates.format(LocalDates.today()));
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _BillForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final BillDetail? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      _load(next);
    }
  }

  void _load(BillDetail? b) {
    if (b == null) {
      return;
    }
    _name.text = b.name;
    _provider.text = b.providerName ?? '';
    _amount.text = b.expectedAmount?.amount ?? '';
    _notes.text = b.notes ?? '';
    _variable = b.amountIsVariable;
    _accountId = b.paymentAccountId;
    _categoryId = b.categoryId;
    _reminders = List<int>.of(b.schedule.reminderDaysBefore);
    _schedule = ScheduleValue.fromRule(b.schedule);
  }

  @override
  void dispose() {
    _name.dispose();
    _provider.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _trimmed(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

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

  Future<void> _pickAccount() async {
    final AccountDto? picked = await showAccountPicker(
      context,
      selectedId: _accountId,
      title: context.l10n.billPaymentAccountLabel,
    );
    if (picked != null && mounted) {
      setState(() => _accountId = picked.id);
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
    final String? currency = _currency(ref.read(accountIndexProvider));
    final String? amount = _variable
        ? null
        : readAmount(context, ref, _amount.text, currency: currency).value;
    final ScheduleValue s = _schedule.normalized();
    final BillDetail? original = widget.original;
    // The currency follows the payment account; an edit keeps the bill's
    // own currency unless the account changes.
    final String? billCurrency =
        original != null && _accountId == original.paymentAccountId
        ? original.currency
        : currency;
    final BillInput input = BillInput(
      name: _name.text.trim(),
      providerName: _trimmed(_provider),
      amountIsVariable: _variable,
      expectedAmount: amount,
      currency: billCurrency,
      paymentAccountId: _accountId,
      categoryId: _categoryId,
      notes: _trimmed(_notes),
      frequency: billFrequencyOf(s.frequency),
      intervalCount: s.intervalCount,
      intervalUnit: billIntervalUnitOf(s.intervalUnit),
      byMonthDay: s.byMonthDay,
      byWeekday: s.byWeekday,
      byWeekOfMonth: s.byWeekOfMonth,
      startDate: s.startDate,
      endDate: s.endDate,
      maxOccurrences: s.maxOccurrences,
      localTime: s.localTime,
      timezone: original?.schedule.timezone,
      reminderDaysBefore: _reminders,
    );
    final BillsApi api = ref.read(billsApiProvider);
    try {
      if (original == null) {
        await api.create(input, key: _submission.keyFor(input.toJson()));
        _submission.reset();
      } else {
        final BillPatch patch = billPatchFor(original, input);
        if (!patchHasChanges(patch.toJson())) {
          if (mounted) {
            showSnack(context, l10n.billNoChanges);
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
      showSnack(context, _editing ? l10n.billSaved : l10n.billCreated);
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      if (error.code == ErrorObjectCode.versionConflict && original != null) {
        ref.invalidate(billProvider(original.id));
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
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final String? general = _errors.general;
    final CategoryDto? category = _categoryId == null
        ? null
        : categories[_categoryId];
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.billEditTitle : l10n.billNewTitle),
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
              maxLength: BillInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.billNameLabel,
                helperText: l10n.billNameHelp,
                errorText: _errors['name'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _provider,
              textInputAction: TextInputAction.next,
              maxLength: BillInput.providerNameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.billProviderLabel),
                helperText: l10n.billProviderHelp,
                errorText: _errors['provider'],
                counterText: '',
              ),
            ),
            FormSectionHeader(l10n.billAmountSection),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.billVariableLabel),
              subtitle: Text(l10n.billVariableHelp),
              value: _variable,
              onChanged: (bool v) => setState(() => _variable = v),
            ),
            if (!_variable) ...<Widget>[
              const SizedBox(height: Insets.sm),
              AmountField(
                controller: _amount,
                label: l10n.billExpectedAmountLabel,
                currency: _currency(accounts),
                errorText: _errors['amount'],
              ),
            ] else if (_errors['amount'] case final String e)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.optionalLabel(l10n.billPaymentAccountLabel),
              value: _accountId == null ? null : accounts[_accountId]?.name,
              icon: Icons.account_balance_wallet_outlined,
              helperText: l10n.billPaymentAccountHelp,
              errorText: _errors['account'],
              onTap: _pickAccount,
              onClear: () => setState(() => _accountId = null),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.optionalLabel(l10n.categoryFieldLabel),
              value: category == null ? null : categoryName(l10n, category),
              icon: Icons.category_outlined,
              errorText: _errors['category'],
              onTap: _pickCategory,
              onClear: () => setState(() => _categoryId = null),
            ),
            FormSectionHeader(l10n.billScheduleSection),
            if (_schedule.isKnown)
              ScheduleEditor(
                key: ValueKey<int?>(widget.original?.version),
                value: _schedule,
                errors: _errors.fields,
                onChanged: (ScheduleValue v) => setState(() => _schedule = v),
              )
            else
              NoticeBanner(message: l10n.billScheduleUnknown),
            const SizedBox(height: Insets.md),
            ReminderDaysField(
              value: _reminders,
              onChanged: (List<int> v) => setState(() => _reminders = v),
            ),
            if (_errors['reminders'] case final String e)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              maxLength: BillInput.notesMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _editing ? l10n.actionSave : l10n.billCreateButton,
              onPressed: _submit,
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
