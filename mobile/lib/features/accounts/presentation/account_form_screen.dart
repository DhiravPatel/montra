import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/accounts/domain/account_types.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';

/// Preset account colors (`#RRGGBB`) with localized names.
const List<String> accountColors = <String>[
  '#1F6F5C',
  '#3D5A80',
  '#6D597A',
  '#B56576',
  '#E07A5F',
  '#F2CC8F',
  '#81B29A',
  '#8D99AE',
];

String _colorName(AppLocalizations l10n, String hex) => switch (hex) {
  '#1F6F5C' => l10n.colorTeal,
  '#3D5A80' => l10n.colorBlue,
  '#6D597A' => l10n.colorPurple,
  '#B56576' => l10n.colorRose,
  '#E07A5F' => l10n.colorOrange,
  '#F2CC8F' => l10n.colorSand,
  '#81B29A' => l10n.colorGreen,
  _ => l10n.colorGrey,
};

/// Creates an account (opening balance and date are recorded as a ledger
/// event) or edits one (`version` checked; type and opening balance are
/// fixed after creation). Pops with the saved [AccountDto].
class AccountFormScreen extends ConsumerStatefulWidget {
  /// Creates the form; [accountId] switches to edit mode.
  const AccountFormScreen({this.accountId, super.key});

  /// Account to edit, or null to create one.
  final String? accountId;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  @override
  Widget build(BuildContext context) {
    final String? id = widget.accountId;
    if (id == null) {
      return const _AccountForm();
    }
    final AsyncValue<AccountDto> account = ref.watch(accountDetailProvider(id));
    final AppLocalizations l10n = context.l10n;
    return account.when(
      skipLoadingOnReload: true,
      data: (AccountDto a) => _AccountForm(original: a),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.accountEditTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.accountEditTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(accountDetailProvider(id)),
        ),
      ),
    );
  }
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({this.original});

  final AccountDto? original;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _institution = TextEditingController();
  final TextEditingController _masked = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _opening = TextEditingController();
  final TextEditingController _creditLimit = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();

  AccountInputAccountType _type = AccountInputAccountType.bank;
  String? _currency;
  bool _owes = true;
  String? _openingDate;
  int? _statementDay;
  int? _paymentDueDay;
  bool _includeInOverview = true;
  String? _color;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'name': 'name',
    'account_type': 'type',
    'currency': 'currency',
    'opening_balance': 'opening',
    'opening_date': 'openingDate',
    'institution_label': 'institution',
    'masked_number': 'masked',
    'credit_limit': 'creditLimit',
    'statement_day': 'statementDay',
    'payment_due_day': 'paymentDueDay',
    'notes': 'notes',
    'color': 'color',
  };

  bool get _editing => widget.original != null;

  @override
  void initState() {
    super.initState();
    _load(widget.original);
    if (!_editing) {
      final AuthState auth = ref.read(authControllerProvider);
      _currency = auth is SignedIn ? auth.user.baseCurrency : null;
    }
  }

  @override
  void didUpdateWidget(covariant _AccountForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final AccountDto? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      // A newer version arrived (after a conflict): show what is stored now.
      _load(next);
    }
  }

  void _load(AccountDto? a) {
    if (a == null) {
      return;
    }
    _name.text = a.name;
    _institution.text = a.institutionLabel ?? '';
    _masked.text = a.maskedNumber ?? '';
    _notes.text = a.notes ?? '';
    _creditLimit.text = a.creditLimit?.amount ?? '';
    _type = accountTypeOf(a);
    _currency = a.currency;
    _statementDay = a.statementDay;
    _paymentDueDay = a.paymentDueDay;
    _includeInOverview = a.includeInOverview;
    _color = a.color?.toUpperCase();
  }

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _masked.dispose();
    _notes.dispose();
    _opening.dispose();
    _creditLimit.dispose();
    super.dispose();
  }

  String? _trimmed(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _pickCurrency() async {
    final String? code = await showCurrencyPicker(context, selected: _currency);
    if (code != null && mounted) {
      setState(() => _currency = code);
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
    final String? currency = _currency;
    if (currency == null) {
      setState(
        () => _errors = ServerFormErrors(
          fields: <String, String>{'currency': l10n.validationCurrencyRequired},
        ),
      );
      return;
    }
    String? creditLimit;
    if (isLiabilityType(_type) && _creditLimit.text.trim().isNotEmpty) {
      creditLimit = readAmount(
        context,
        ref,
        _creditLimit.text,
        currency: currency,
        allowZero: true,
      ).value;
    }
    final AccountsApi api = ref.read(accountsApiProvider);
    try {
      final AccountDto saved;
      final AccountDto? original = widget.original;
      if (original == null) {
        String? opening;
        if (_opening.text.trim().isNotEmpty) {
          final String? value = readAmount(
            context,
            ref,
            _opening.text,
            currency: currency,
            allowZero: true,
          ).value;
          if (value != null) {
            final bool zero = RegExp(r'^-?0+(\.0+)?$').hasMatch(value);
            opening = isLiabilityType(_type) && _owes && !zero
                ? '-$value'
                : value;
          }
        }
        final AccountInput input = AccountInput(
          accountType: _type,
          name: _name.text.trim(),
          currency: currency,
          openingBalance: opening,
          openingDate: _openingDate,
          institutionLabel: _trimmed(_institution),
          maskedNumber: _trimmed(_masked),
          notes: _trimmed(_notes),
          creditLimit: creditLimit,
          statementDay: isLiabilityType(_type) ? _statementDay : null,
          paymentDueDay: isLiabilityType(_type) ? _paymentDueDay : null,
          includeInOverview: _includeInOverview,
          color: _color,
        );
        saved = await api.create(
          input,
          key: _submission.keyFor(input.toJson()),
        );
        _submission.reset();
      } else {
        saved = await api.update(original.id, _patchFor(original, creditLimit));
      }
      finance.bump();
      if (!mounted) {
        return;
      }
      showSnack(context, _editing ? l10n.accountSaved : l10n.accountCreated);
      context.pop(saved);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      if (error.code == ErrorObjectCode.versionConflict &&
          widget.original != null) {
        ref.invalidate(accountDetailProvider(widget.original!.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  AccountPatch _patchFor(AccountDto o, String? creditLimit) {
    String? changed(String? now, String? before) =>
        (now ?? '') == (before ?? '') ? null : (now ?? '');
    final String? limitText = isLiabilityType(_type)
        ? (creditLimit ?? '')
        : null;
    return AccountPatch(
      version: o.version,
      name: _name.text.trim() == o.name ? null : _name.text.trim(),
      currency: _currency == o.currency ? null : _currency,
      institutionLabel: changed(_trimmed(_institution), o.institutionLabel),
      maskedNumber: changed(_trimmed(_masked), o.maskedNumber),
      notes: changed(_trimmed(_notes), o.notes),
      creditLimit:
          limitText == null || limitText == (o.creditLimit?.amount ?? '')
          ? null
          : limitText,
      // 0 clears a day that was set.
      statementDay: _statementDay != o.statementDay
          ? (_statementDay ?? 0)
          : null,
      paymentDueDay: _paymentDueDay != o.paymentDueDay
          ? (_paymentDueDay ?? 0)
          : null,
      includeInOverview: _includeInOverview != o.includeInOverview
          ? _includeInOverview
          : null,
      color: _color != o.color?.toUpperCase() ? _color : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool liability = isLiabilityType(_type);
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.accountEditTitle : l10n.accountNewTitle),
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
              maxLength: AccountInput.nameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.accountNameLabel,
                helperText: l10n.accountNameHelp,
                errorText: _errors['name'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: Insets.md),
            if (_editing)
              SelectorField(
                label: l10n.accountTypeLabel,
                value: accountTypeLabel(l10n, _type),
                icon: accountTypeIcon(_type),
                helperText: l10n.accountTypeFixed,
                enabled: false,
                onTap: null,
              )
            else
              DropdownButtonFormField<AccountInputAccountType>(
                initialValue: _type,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.accountTypeLabel,
                  errorText: _errors['type'],
                ),
                items: <DropdownMenuItem<AccountInputAccountType>>[
                  for (final AccountInputAccountType t in accountTypeOrder)
                    DropdownMenuItem<AccountInputAccountType>(
                      value: t,
                      child: Row(
                        children: <Widget>[
                          Icon(accountTypeIcon(t), size: 20),
                          const SizedBox(width: Insets.sm),
                          Flexible(child: Text(accountTypeLabel(l10n, t))),
                        ],
                      ),
                    ),
                ],
                onChanged: (AccountInputAccountType? t) {
                  if (t != null) {
                    setState(() => _type = t);
                  }
                },
              ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.currencyFieldLabel,
              value: _currency,
              icon: Icons.currency_exchange,
              errorText: _errors['currency'],
              helperText: _editing ? l10n.accountCurrencyChangeHelp : null,
              onTap: _pickCurrency,
            ),
            if (!_editing) ...<Widget>[
              FormSectionHeader(l10n.openingBalanceSection),
              if (liability) ...<Widget>[
                SegmentedButton<bool>(
                  segments: <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(l10n.openingOwed),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(l10n.openingInCredit),
                    ),
                  ],
                  selected: <bool>{_owes},
                  onSelectionChanged: (Set<bool> s) =>
                      setState(() => _owes = s.first),
                ),
                const SizedBox(height: Insets.sm),
              ],
              AmountField(
                controller: _opening,
                label: liability
                    ? (_owes ? l10n.openingOwedLabel : l10n.openingCreditLabel)
                    : l10n.openingBalanceLabel,
                currency: _currency,
                isRequired: false,
                allowZero: true,
                allowNegative: !liability,
                helperText: liability
                    ? l10n.openingLiabilityHelp
                    : l10n.openingBalanceHelp,
                errorText: _errors['opening'],
              ),
              const SizedBox(height: Insets.md),
              DateSelectorField(
                label: l10n.openingDateLabel,
                value: _openingDate,
                emptyLabel: l10n.dateToday,
                clearable: true,
                lastDate: DateTime.now(),
                errorText: _errors['openingDate'],
                onChanged: (String? d) => setState(() => _openingDate = d),
              ),
            ],
            FormSectionHeader(l10n.accountMoreDetails),
            TextFormField(
              controller: _institution,
              textInputAction: TextInputAction.next,
              maxLength: AccountInput.institutionLabelMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.institutionLabel),
                errorText: _errors['institution'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _masked,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.maskedNumberLabel),
                helperText: l10n.maskedNumberHelp,
                errorText: _errors['masked'],
              ),
              validator: (String? v) {
                final String text = (v ?? '').trim();
                if (text.isEmpty) {
                  return null;
                }
                return RegExp(r'^[0-9]{2,4}$').hasMatch(text)
                    ? null
                    : l10n.maskedNumberInvalid;
              },
            ),
            if (liability) ...<Widget>[
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _creditLimit,
                label: l10n.optionalLabel(l10n.creditLimitLabel),
                currency: _currency,
                isRequired: false,
                allowZero: true,
                errorText: _errors['creditLimit'],
              ),
              const SizedBox(height: Insets.md),
              _DayDropdown(
                key: ValueKey<String>('statement-${widget.original?.version}'),
                label: l10n.statementDayLabel,
                value: _statementDay,
                errorText: _errors['statementDay'],
                onChanged: (int? d) => setState(() => _statementDay = d),
              ),
              const SizedBox(height: Insets.md),
              _DayDropdown(
                key: ValueKey<String>('due-${widget.original?.version}'),
                label: l10n.paymentDueDayLabel,
                value: _paymentDueDay,
                errorText: _errors['paymentDueDay'],
                onChanged: (int? d) => setState(() => _paymentDueDay = d),
              ),
            ],
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              maxLength: AccountInput.notesMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.includeInOverviewLabel),
              subtitle: Text(l10n.includeInOverviewHelp),
              value: _includeInOverview,
              onChanged: (bool v) => setState(() => _includeInOverview = v),
            ),
            FormSectionHeader(l10n.accountColorLabel),
            _ColorChoices(
              selected: _color,
              onChanged: (String? c) => setState(() => _color = c),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _editing ? l10n.actionSave : l10n.accountCreateButton,
              onPressed: _submit,
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}

class _DayDropdown extends StatelessWidget {
  const _DayDropdown({
    required this.label,
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return DropdownButtonFormField<int?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      items: <DropdownMenuItem<int?>>[
        DropdownMenuItem<int?>(child: Text(l10n.notSetLabel)),
        for (int d = 1; d <= 31; d++)
          DropdownMenuItem<int?>(value: d, child: Text(l10n.dayOfMonth(d))),
      ],
      onChanged: onChanged,
    );
  }
}

class _ColorChoices extends StatelessWidget {
  const _ColorChoices({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: <Widget>[
        _ColorButton(
          label: l10n.colorNone,
          selected: selected == null,
          color: null,
          onTap: () => onChanged(null),
        ),
        for (final String hex in accountColors)
          _ColorButton(
            label: _colorName(l10n, hex),
            selected: selected == hex,
            color: Color(0xFF000000 | int.parse(hex.substring(1), radix: 16)),
            onTap: () => onChanged(hex),
          ),
      ],
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color ?? scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.onSurface : scheme.outline,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 20,
                      color: color == null
                          ? scheme.onSurface
                          : (ThemeData.estimateBrightnessForColor(color!) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black),
                    )
                  : (color == null
                        ? Icon(Icons.block, size: 18, color: scheme.outline)
                        : null),
            ),
          ),
        ),
      ),
    );
  }
}
