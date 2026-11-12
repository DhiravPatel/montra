import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
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
import 'package:montra_mobile/features/transactions/application/transactions_providers.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_form_screen.dart';

/// Records a partial or full refund, or a reimbursement, linked to an
/// expense. The server caps the total at the original amount (its message
/// says how much remains); an explicit correction can go above it.
class RefundScreen extends ConsumerWidget {
  /// Creates the screen for the expense [transactionId].
  const RefundScreen({
    required this.transactionId,
    this.reimbursement = false,
    super.key,
  });

  /// The original expense.
  final String transactionId;

  /// Start with "reimbursement" selected.
  final bool reimbursement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<TransactionDto> original = ref.watch(
      transactionDetailProvider(transactionId),
    );
    return original.when(
      skipLoadingOnReload: true,
      data: (TransactionDto t) => canRefund(t)
          ? _RefundForm(original: t, reimbursement: reimbursement)
          : Scaffold(
              appBar: AppBar(title: Text(l10n.refundTitle)),
              body: MessageStateView(
                icon: Icons.block_outlined,
                title: l10n.refundNotAllowedTitle,
                body: l10n.refundNotAllowedBody,
              ),
            ),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.refundTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.refundTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () =>
              ref.invalidate(transactionDetailProvider(transactionId)),
        ),
      ),
    );
  }
}

class _RefundForm extends ConsumerStatefulWidget {
  const _RefundForm({required this.original, required this.reimbursement});

  final TransactionDto original;
  final bool reimbursement;

  @override
  ConsumerState<_RefundForm> createState() => _RefundFormState();
}

class _RefundFormState extends ConsumerState<_RefundForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();
  late RefundInputType _type = widget.reimbursement
      ? RefundInputType.reimbursement
      : RefundInputType.refund;
  String? _accountId;
  String? _date;
  bool _correction = false;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'amount': 'amount',
    'account_id': 'account',
    'local_date': 'date',
    'description': 'description',
    'notes': 'notes',
    'is_correction': 'amount',
  };

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final TransactionDto o = widget.original;
    final String? amount = readAmount(
      context,
      ref,
      _amount.text,
      currency: o.amount.currency,
    ).value;
    if (amount == null) {
      return;
    }
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final RefundInput input = RefundInput(
      typeValue: _type,
      amount: amount,
      accountId: _accountId,
      localDate: _date,
      description: text(_description),
      notes: text(_notes),
      isCorrection: _correction ? true : null,
    );
    final GoRouter router = GoRouter.of(context);
    try {
      final CreateResult result = await ref
          .read(transactionsApiProvider)
          .refund(o.id, input, key: _submission.keyFor(input.toJson()));
      _submission.reset();
      finance.bump();
      if (!mounted) {
        return;
      }
      if (result.possibleDuplicates.isEmpty) {
        showSnack(
          context,
          _type == RefundInputType.reimbursement
              ? l10n.reimbursementSaved
              : l10n.refundSaved,
        );
      } else {
        showDuplicateNotice(context, router, result);
      }
      context.pop(result.transaction);
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
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
    final TransactionDto o = widget.original;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _type == RefundInputType.reimbursement
              ? l10n.reimbursementTitle
              : l10n.refundTitle,
        ),
      ),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            SectionCard(
              title: l10n.refundOriginalTitle,
              children: <Widget>[
                DetailRow(
                  label: l10n.refundOriginalLabel,
                  value: transactionTitle(l10n, o),
                ),
                DetailRow(
                  label: l10n.amountLabel,
                  semanticsValue: formatMoney(context, ref, o.amount),
                  child: MoneyText(o.amount),
                ),
                DetailRow(
                  label: l10n.refundAlreadyLabel,
                  semanticsValue: formatMoney(context, ref, o.refundedTotal),
                  child: MoneyText(o.refundedTotal),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Text(l10n.refundCapNote),
            const SizedBox(height: Insets.md),
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            SegmentedButton<RefundInputType>(
              segments: <ButtonSegment<RefundInputType>>[
                ButtonSegment<RefundInputType>(
                  value: RefundInputType.refund,
                  label: Text(l10n.txTypeRefund),
                ),
                ButtonSegment<RefundInputType>(
                  value: RefundInputType.reimbursement,
                  label: Text(l10n.txTypeReimbursement),
                ),
              ],
              selected: <RefundInputType>{_type},
              onSelectionChanged: (Set<RefundInputType> s) =>
                  setState(() => _type = s.first),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              _type == RefundInputType.reimbursement
                  ? l10n.reimbursementHelp
                  : l10n.refundHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _amount,
              label: l10n.refundAmountLabel,
              currency: o.amount.currency,
              autofocus: true,
              errorText: _errors['amount'],
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.refundAccountLabel,
              icon: Icons.account_balance_wallet_outlined,
              value: _accountId == null
                  ? o.accountName
                  : (accounts[_accountId]?.name ?? o.accountName),
              helperText: l10n.refundAccountHelp,
              errorText: _errors['account'],
              onTap: () async {
                final AccountDto? a = await showAccountPicker(
                  context,
                  selectedId: _accountId ?? o.accountId,
                  currency: o.amount.currency,
                );
                if (a != null && mounted) {
                  setState(
                    () => _accountId = a.id == o.accountId ? null : a.id,
                  );
                }
              },
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.dateLabel,
              value: _date,
              emptyLabel: l10n.dateToday,
              errorText: _errors['date'],
              onChanged: (String? d) => setState(() => _date = d),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _description,
              maxLength: RefundInput.descriptionMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.descriptionLabel),
                errorText: _errors['description'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLength: RefundInput.notesMaxLength,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
                counterText: '',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _correction,
              title: Text(l10n.refundCorrectionLabel),
              subtitle: Text(l10n.refundCorrectionHelp),
              onChanged: (bool? v) => setState(() => _correction = v ?? false),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _type == RefundInputType.reimbursement
                  ? l10n.reimbursementSave
                  : l10n.refundSave,
              onPressed: _submit,
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
