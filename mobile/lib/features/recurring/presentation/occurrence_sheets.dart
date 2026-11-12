import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';

/// What the user entered to record (confirm) an occurrence.
@immutable
class ConfirmChoice {
  /// Creates the choice.
  const ConfirmChoice({this.amount, this.date, this.accountId});

  /// Actual amount, when it differs or the rule has none.
  final String? amount;

  /// Transaction date; null for the server default (the due date, or
  /// today when recording early).
  final String? date;

  /// Account, when the rule has none.
  final String? accountId;
}

/// Asks for the details needed to record [occurrence] as a transaction.
/// [needsAmount] when the rule has no fixed amount; [needsAccount] when it
/// has no account. Returns null when dismissed.
Future<ConfirmChoice?> showConfirmOccurrenceSheet(
  BuildContext context, {
  required OccurrenceDto occurrence,
  required bool needsAmount,
  required bool needsAccount,
  String? currency,
}) => showModalBottomSheet<ConfirmChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) => _ConfirmSheet(
    occurrence: occurrence,
    needsAmount: needsAmount,
    needsAccount: needsAccount,
    currency: currency,
  ),
);

class _ConfirmSheet extends ConsumerStatefulWidget {
  const _ConfirmSheet({
    required this.occurrence,
    required this.needsAmount,
    required this.needsAccount,
    this.currency,
  });

  final OccurrenceDto occurrence;
  final bool needsAmount;
  final bool needsAccount;
  final String? currency;

  @override
  ConsumerState<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<_ConfirmSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  String? _date;
  String? _accountId;
  String? _accountError;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.occurrence.amount?.amount ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? get _currency =>
      widget.occurrence.amount?.currency ??
      (_accountId == null
          ? widget.currency
          : ref.read(accountIndexProvider)[_accountId]?.currency) ??
      widget.currency;

  Future<void> _pickAccount() async {
    final AccountDto? picked = await showAccountPicker(
      context,
      selectedId: _accountId,
    );
    if (picked != null && mounted) {
      setState(() {
        _accountId = picked.id;
        _accountError = null;
      });
    }
  }

  void _done() {
    final AppLocalizations l10n = context.l10n;
    final bool valid = _form.currentState?.validate() ?? false;
    if (widget.needsAccount && _accountId == null) {
      setState(() => _accountError = l10n.recurringAccountRequired);
      return;
    }
    if (!valid) {
      return;
    }
    final String text = _amount.text.trim();
    final String? amount = text.isEmpty
        ? null
        : readAmount(context, ref, text, currency: _currency).value;
    // Only send the amount when it was entered or changed.
    final bool changed =
        amount != null && amount != widget.occurrence.amount?.amount;
    Navigator.of(context).pop(
      ConfirmChoice(
        amount: widget.needsAmount || changed ? amount : null,
        date: _date,
        accountId: _accountId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: Insets.md,
        right: Insets.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.md,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.occurrenceConfirmTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                l10n.occurrenceConfirmBody(
                  widget.occurrence.ruleName,
                  LocalDates.display(
                    widget.occurrence.effectiveDate,
                    locale: locale,
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _amount,
                label: l10n.occurrenceAmountLabel,
                currency: _currency,
                isRequired: widget.needsAmount,
                helperText: widget.needsAmount
                    ? null
                    : l10n.occurrenceAmountHelp,
              ),
              const SizedBox(height: Insets.md),
              DateSelectorField(
                label: l10n.dateLabel,
                value: _date,
                emptyLabel: l10n.occurrenceDateDefault,
                clearable: true,
                lastDate: LocalDates.today(),
                onChanged: (String? d) => setState(() => _date = d),
              ),
              if (widget.needsAccount) ...<Widget>[
                const SizedBox(height: Insets.md),
                SelectorField(
                  label: l10n.accountFieldLabel,
                  value: _accountId == null ? null : accounts[_accountId]?.name,
                  icon: Icons.account_balance_wallet_outlined,
                  errorText: _accountError,
                  onTap: _pickAccount,
                ),
              ],
              const SizedBox(height: Insets.lg),
              FilledButton(
                onPressed: _done,
                child: Text(l10n.occurrenceConfirmButton),
              ),
              const SizedBox(height: Insets.sm),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a new expected amount for one occurrence. Returns the decimal
/// string, or null when dismissed.
Future<String?> showOccurrenceAmountSheet(
  BuildContext context, {
  String? initial,
  String? currency,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) =>
      _AmountSheet(initial: initial, currency: currency),
);

class _AmountSheet extends ConsumerStatefulWidget {
  const _AmountSheet({this.initial, this.currency});

  final String? initial;
  final String? currency;

  @override
  ConsumerState<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends ConsumerState<_AmountSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount.text = widget.initial ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _done() {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      readAmount(context, ref, _amount.text, currency: widget.currency).value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: Insets.md,
        right: Insets.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.md,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.occurrenceSetAmountTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Insets.xs),
              Text(l10n.occurrenceSetAmountBody),
              const SizedBox(height: Insets.md),
              AmountField(
                controller: _amount,
                label: l10n.occurrenceAmountLabel,
                currency: widget.currency,
                autofocus: true,
              ),
              const SizedBox(height: Insets.lg),
              FilledButton(onPressed: _done, child: Text(l10n.actionSave)),
              const SizedBox(height: Insets.sm),
            ],
          ),
        ),
      ),
    );
  }
}
