import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/goals/application/goals_providers.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_picker.dart';

/// Adds a contribution or withdrawal to a goal. Sent with an
/// `Idempotency-Key`, so a retry after a lost connection never adds it
/// twice. Linking the transaction that moved the money verifies it.
class ContributionFormScreen extends ConsumerWidget {
  /// Creates the form for [goalId].
  const ContributionFormScreen({required this.goalId, super.key});

  /// The goal.
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return ref
        .watch(goalDetailProvider(goalId))
        .when(
          skipLoadingOnReload: true,
          data: (GoalDto goal) => _ContributionForm(goal: goal),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(l10n.goalAddContribution)),
            body: const LoadingStateView(),
          ),
          error: (Object error, StackTrace _) => Scaffold(
            appBar: AppBar(title: Text(l10n.goalAddContribution)),
            body: ErrorStateView(
              error: error,
              onRetry: () => ref.invalidate(goalDetailProvider(goalId)),
            ),
          ),
        );
  }
}

class _ContributionForm extends ConsumerStatefulWidget {
  const _ContributionForm({required this.goal});

  final GoalDto goal;

  @override
  ConsumerState<_ContributionForm> createState() => _ContributionFormState();
}

class _ContributionFormState extends ConsumerState<_ContributionForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();

  GoalContributionInputKind _kind = GoalContributionInputKind.contribution;
  GoalContributionInputStatus _status = GoalContributionInputStatus.recorded;
  String? _date;
  TransactionDto? _transaction;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'amount': 'amount',
    'kind': 'kind',
    'status': 'status',
    'contributed_on': 'date',
    'note': 'note',
    'transaction_id': 'transaction',
  };

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTransaction() async {
    final TransactionDto? picked = await showTransactionPicker(
      context,
      title: context.l10n.contributionTransactionPickerTitle,
    );
    if (picked != null && mounted) {
      setState(() {
        _transaction = picked;
        // A linked transaction means the money has moved.
        _status = GoalContributionInputStatus.recorded;
      });
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final GoalDto goal = widget.goal;
    final String? amount = readAmount(
      context,
      ref,
      _amount.text,
      currency: goal.target.currency,
    ).value;
    if (amount == null) {
      return;
    }
    final String? note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final GoalContributionInput input = GoalContributionInput(
      amount: amount,
      kind: _kind,
      status: _transaction == null
          ? _status
          : GoalContributionInputStatus.recorded,
      contributedOn: _date,
      note: note,
      transactionId: _transaction?.id,
    );
    final GoalsApi api = ref.read(goalsApiProvider);
    final GoalsRevision revision = ref.read(goalsRevisionProvider.notifier);
    try {
      await api.addContribution(
        goal.id,
        input,
        key: _submission.keyFor(input.toJson()),
      );
      _submission.reset();
      revision.bump();
      if (!mounted) {
        return;
      }
      showSnack(
        context,
        _kind == GoalContributionInputKind.withdrawal
            ? l10n.contributionWithdrawalSavedDone
            : l10n.contributionSavedDone,
      );
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      final bool inactive = error.details.any(
        (Detail d) => d.code == 'goal_inactive',
      );
      setState(
        () => _errors = inactive
            ? ServerFormErrors(general: l10n.contributionGoalInactive)
            : ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  String _transactionText(AppLocalizations l10n, TransactionDto t) {
    final String locale = numberLocaleOf(context, ref);
    final String dateLocale = Localizations.localeOf(context).toString();
    return <String>[
      transactionTitle(l10n, t),
      formatMoneyText(t.amount, locale),
      LocalDates.display(t.localDate, locale: dateLocale),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final GoalDto goal = widget.goal;
    final String? general = _errors.general;
    final TransactionDto? linked = _transaction;
    final bool withdrawal = _kind == GoalContributionInputKind.withdrawal;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contributionNewTitle(goal.name))),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (!canContribute(goal)) ...<Widget>[
              NoticeBanner(message: l10n.contributionGoalInactive),
              const SizedBox(height: Insets.md),
            ],
            SegmentedButton<GoalContributionInputKind>(
              segments: <ButtonSegment<GoalContributionInputKind>>[
                ButtonSegment<GoalContributionInputKind>(
                  value: GoalContributionInputKind.contribution,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(l10n.contributionKindContribution),
                ),
                ButtonSegment<GoalContributionInputKind>(
                  value: GoalContributionInputKind.withdrawal,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: Text(l10n.contributionKindWithdrawal),
                ),
              ],
              selected: <GoalContributionInputKind>{_kind},
              onSelectionChanged: (Set<GoalContributionInputKind> s) =>
                  setState(() => _kind = s.first),
            ),
            if (_errors['kind'] case final String e)
              Text(
                e,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _amount,
              label: withdrawal
                  ? l10n.contributionWithdrawalAmountLabel
                  : l10n.contributionAmountLabel,
              currency: goal.target.currency,
              errorText: _errors['amount'],
            ),
            FormSectionHeader(l10n.statusLabel),
            SegmentedButton<GoalContributionInputStatus>(
              segments: <ButtonSegment<GoalContributionInputStatus>>[
                ButtonSegment<GoalContributionInputStatus>(
                  value: GoalContributionInputStatus.recorded,
                  icon: const Icon(Icons.edit_note),
                  label: Text(l10n.contributionStatusRecorded),
                ),
                ButtonSegment<GoalContributionInputStatus>(
                  value: GoalContributionInputStatus.planned,
                  icon: const Icon(Icons.schedule),
                  label: Text(l10n.contributionStatusPlanned),
                  enabled: linked == null,
                ),
              ],
              selected: <GoalContributionInputStatus>{_status},
              onSelectionChanged: (Set<GoalContributionInputStatus> s) =>
                  setState(() => _status = s.first),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              _status == GoalContributionInputStatus.planned
                  ? l10n.contributionPlannedHelp
                  : l10n.contributionRecordedHelp,
              style: theme.textTheme.bodySmall,
            ),
            if (_errors['status'] case final String e)
              Text(
                e,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
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
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.contributionNoteLabel),
                errorText: _errors['note'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: withdrawal
                  ? l10n.contributionWithdrawalSave
                  : l10n.contributionSave,
              onPressed: canContribute(goal) ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
