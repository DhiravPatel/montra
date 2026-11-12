import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/goals/application/goals_providers.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_picker.dart';

/// Records the user's own planned [contribution] to [goal]
/// (`POST /goals/{id}/contributions/{contributionId}/record`, with an
/// `Idempotency-Key`). The planned row itself becomes recorded, or
/// verified when a transaction is linked, so it is counted once. Returns
/// true when it was recorded.
Future<bool> showRecordContributionSheet(
  BuildContext context, {
  required GoalDto goal,
  required GoalContributionDto contribution,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          RecordContributionSheet(goal: goal, contribution: contribution),
    ) ??
    false;

/// The sheet behind [showRecordContributionSheet].
class RecordContributionSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const RecordContributionSheet({
    required this.goal,
    required this.contribution,
    super.key,
  });

  /// The goal.
  final GoalDto goal;

  /// The planned contribution to record.
  final GoalContributionDto contribution;

  @override
  ConsumerState<RecordContributionSheet> createState() =>
      _RecordContributionSheetState();
}

class _RecordContributionSheetState
    extends ConsumerState<RecordContributionSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.contribution.amount?.amount ?? '',
  );
  final IdempotentSubmission _submission = IdempotentSubmission();
  String? _date;
  TransactionDto? _transaction;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _busy = false;

  static const Map<String, String> _fields = <String, String>{
    'amount': 'amount',
    'contributed_on': 'date',
    'transaction_id': 'transaction',
  };

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickTransaction() async {
    final TransactionDto? picked = await showTransactionPicker(
      context,
      title: context.l10n.contributionTransactionPickerTitle,
    );
    if (picked != null && mounted) {
      setState(() => _transaction = picked);
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String? amount = readAmount(
      context,
      ref,
      _amount.text,
      currency: widget.goal.target.currency,
    ).value;
    if (amount == null) {
      return;
    }
    final String? planned = widget.contribution.amount?.amount;
    final GoalContributionRecordInput input = GoalContributionRecordInput(
      // Omitted when unchanged: the server records the planned amount.
      amount: amount == planned ? null : amount,
      contributedOn: _date,
      transactionId: _transaction?.id,
    );
    final GoalsApi api = ref.read(goalsApiProvider);
    final GoalsRevision revision = ref.read(goalsRevisionProvider.notifier);
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await api.recordContribution(
        widget.goal.id,
        widget.contribution.id,
        input,
        key: _submission.keyFor(input.toJson()),
      );
      _submission.reset();
      revision.bump();
      if (_transaction != null) {
        finance.bump();
      }
      navigator.pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      setState(() {
        _busy = false;
        _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields);
      });
    }
  }

  String _transactionText(AppLocalizations l10n, TransactionDto t) => <String>[
    transactionTitle(l10n, t),
    formatMoneyText(t.amount, numberLocaleOf(context, ref)),
    LocalDates.display(
      t.localDate,
      locale: Localizations.localeOf(context).toString(),
    ),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String? general = _errors.general;
    final TransactionDto? linked = _transaction;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.lg),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.contributionRecordTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(l10n.contributionRecordIntro),
              const SizedBox(height: Insets.md),
              if (general != null) ...<Widget>[
                NoticeBanner(
                  tone: NoticeTone.error,
                  message: general,
                  requestId: _errors.requestId,
                ),
                const SizedBox(height: Insets.md),
              ],
              AmountField(
                controller: _amount,
                label:
                    widget.contribution.kind ==
                        GoalContributionDtoKind.withdrawal
                    ? l10n.contributionWithdrawalAmountLabel
                    : l10n.contributionAmountLabel,
                currency: widget.goal.target.currency,
                helperText: l10n.contributionRecordAmountHelp,
                errorText: _errors['amount'],
              ),
              const SizedBox(height: Insets.md),
              DateSelectorField(
                label: l10n.dateLabel,
                value: _date,
                emptyLabel: l10n.dateToday,
                clearable: true,
                errorText: _errors['date'],
                onChanged: (String? d) => setState(() => _date = d),
              ),
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.optionalLabel(l10n.contributionTransactionLabel),
                value: linked == null ? null : _transactionText(l10n, linked),
                placeholder: l10n.contributionTransactionPlaceholder,
                icon: Icons.receipt_long_outlined,
                helperText: l10n.contributionTransactionHelp,
                errorText: _errors['transaction'],
                onTap: _pickTransaction,
                onClear: linked == null
                    ? null
                    : () => setState(() => _transaction = null),
              ),
              const SizedBox(height: Insets.lg),
              SubmitButton(
                label: l10n.contributionRecordSave,
                busy: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
