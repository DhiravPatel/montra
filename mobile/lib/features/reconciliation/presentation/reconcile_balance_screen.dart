import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/amount_input.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';
import 'package:montra_mobile/features/reconciliation/presentation/reconciliation_screen.dart';

/// Checks a statement balance (`POST /accounts/{id}/reconciliations`): the
/// statement date and closing balance, typed exactly in the account's
/// currency. The server compares it with Montra's balance on that date and
/// reports the difference; when they match, posted transactions up to the
/// date are marked reconciled. For cards and loans the amount owed can be
/// typed as a positive number.
class ReconcileBalanceScreen extends ConsumerWidget {
  /// Creates the screen for [accountId], optionally for the statement of
  /// import [importBatchId].
  const ReconcileBalanceScreen({
    required this.accountId,
    this.importBatchId,
    super.key,
  });

  /// The account.
  final String accountId;

  /// The statement import this balance comes from, if any.
  final String? importBatchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AccountDto> account = ref.watch(
      accountDetailProvider(accountId),
    );
    return Scaffold(
      appBar: AppBar(
        actions: const <Widget>[HelpGuideButton(HelpGuide.reconciliation)],
        title: Text(l10n.reconCheckBalance),
      ),
      body: AsyncValueView<AccountDto>(
        value: account,
        onRetry: () => ref.invalidate(accountDetailProvider(accountId)),
        data: (AccountDto a) => _Form(account: a, importBatchId: importBatchId),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.account, required this.importBatchId});

  final AccountDto account;
  final String? importBatchId;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _balance = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  late bool _owed = widget.account.isLiability;
  String? _date;
  String? _dateError;
  ServerFormErrors _errors = ServerFormErrors.none;
  ReconBalanceDto? _result;

  static const Map<String, String> _fields = <String, String>{
    'statement_date': 'date',
    'statement_balance': 'balance',
    'balance_kind': 'balance',
    'notes': 'notes',
    'import_batch_id': 'general',
  };

  @override
  void dispose() {
    _balance.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() {
      _errors = ServerFormErrors.none;
      _dateError = null;
    });
    final bool ok = _form.currentState?.validate() ?? false;
    final String? date = _date;
    if (date == null) {
      setState(() => _dateError = l10n.reconDateRequired);
      return;
    }
    if (!ok) {
      return;
    }
    final AmountParseResult amount = readAmount(
      context,
      ref,
      _balance.text,
      currency: widget.account.currency,
      allowNegative: !_owed,
      allowZero: true,
    );
    final String? value = amount.value;
    if (value == null) {
      return;
    }
    final String notes = _notes.text.trim();
    try {
      final ReconBalanceDto result = await ref
          .read(reconciliationApiProvider)
          .reconcile(
            widget.account.id,
            ReconBalanceInput(
              statementDate: date,
              statementBalance: value,
              balanceKind: widget.account.isLiability
                  ? (_owed
                        ? ReconBalanceInputBalanceKind.amountOwed
                        : ReconBalanceInputBalanceKind.balance)
                  : null,
              importBatchId: widget.importBatchId,
              notes: notes.isEmpty ? null : notes,
            ),
          );
      finance.bump();
      if (mounted) {
        setState(() => _result = result);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AccountDto a = widget.account;
    final ReconBalanceDto? result = _result;
    if (result != null) {
      return ScrollableContent(
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              result.status == ReconBalanceDtoStatus.balanced
                  ? l10n.reconResultBalanced
                  : l10n.reconResultOff,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: Insets.md),
          ReconBalanceCard(balance: result),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            icon: Icons.check,
            label: l10n.actionDone,
            onPressed: () async => context.pop(),
          ),
          const SizedBox(height: Insets.sm),
          SubmitButton(
            kind: SubmitButtonKind.outlined,
            icon: Icons.refresh,
            label: l10n.reconCheckAgain,
            onPressed: () async => setState(() => _result = null),
          ),
        ],
      );
    }
    final String? general = _errors.general ?? _errors['general'];
    return Form(
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
          Text(l10n.reconFormIntro(a.name)),
          if (widget.importBatchId != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            NoticeBanner(message: l10n.reconFromImport),
          ],
          const SizedBox(height: Insets.md),
          DateSelectorField(
            label: l10n.reconStatementDate,
            value: _date,
            emptyLabel: l10n.reconChooseDate,
            errorText: _dateError ?? _errors['date'],
            lastDate: LocalDates.today(),
            onChanged: (String? d) => setState(() => _date = d),
          ),
          const SizedBox(height: Insets.md),
          if (a.isLiability) ...<Widget>[
            FormSectionHeader(l10n.reconBalanceKindLabel),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                ChoiceChip(
                  label: Text(l10n.reconKindOwed),
                  selected: _owed,
                  onSelected: (_) => setState(() => _owed = true),
                ),
                ChoiceChip(
                  label: Text(l10n.reconKindBalance),
                  selected: !_owed,
                  onSelected: (_) => setState(() => _owed = false),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
          ],
          AmountField(
            controller: _balance,
            label: _owed
                ? l10n.reconAmountOwedLabel
                : l10n.reconStatementBalance,
            currency: a.currency,
            allowNegative: !_owed,
            allowZero: true,
            errorText: _errors['balance'],
            helperText: _owed
                ? l10n.reconAmountOwedHelp
                : l10n.reconStatementBalanceHelp,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _notes,
            maxLength: ReconBalanceInput.notesMaxLength,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              labelText: l10n.notesLabel,
              errorText: _errors['notes'],
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            l10n.reconWhatHappens,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            icon: Icons.fact_check_outlined,
            label: l10n.reconCompare,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
