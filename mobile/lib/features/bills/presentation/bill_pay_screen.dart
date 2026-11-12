import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/bills/application/bills_providers.dart';
import 'package:montra_mobile/features/bills/data/bills_api.dart';
import 'package:montra_mobile/features/bills/domain/bill_display.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_picker.dart';

/// Marks a bill occurrence as paid: either by linking a payment the user
/// already recorded (suggested candidates, or any expense) or by recording
/// a new payment. Nothing is matched automatically.
class BillPayScreen extends ConsumerWidget {
  /// Creates the screen for [billId] and, optionally, one [occurrenceId]
  /// (default: the oldest unpaid occurrence).
  const BillPayScreen({required this.billId, this.occurrenceId, super.key});

  /// The bill.
  final String billId;

  /// The occurrence to pay, if not the oldest unpaid one.
  final String? occurrenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<BillDetail> bill = ref.watch(billProvider(billId));
    return bill.when(
      skipLoadingOnReload: true,
      data: (BillDetail b) {
        final OccurrenceDto? target =
            b.occurrences
                .where((OccurrenceDto o) => o.id == occurrenceId)
                .firstOrNull ??
            b.nextDue;
        if (target == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.billPayTitle)),
            body: MessageStateView(
              icon: Icons.check_circle_outline,
              title: l10n.billNothingToPay,
            ),
          );
        }
        return _PayForm(bill: b, occurrence: target);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.billPayTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.billPayTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(billProvider(billId)),
        ),
      ),
    );
  }
}

enum _PayMode { link, record }

/// A payment chosen to link: a suggestion or any picked transaction.
@immutable
class _Linked {
  const _Linked({required this.id, required this.title, required this.amount});

  final String id;
  final String title;
  final Money amount;
}

class _PayForm extends ConsumerStatefulWidget {
  const _PayForm({required this.bill, required this.occurrence});

  final BillDetail bill;
  final OccurrenceDto occurrence;

  @override
  ConsumerState<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends ConsumerState<_PayForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();
  _PayMode _mode = _PayMode.link;
  _Linked? _linked;
  String? _accountId;
  String? _paidOn;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'amount': 'amount',
    'account_id': 'account',
    'paid_on': 'paidOn',
    'transaction_id': 'transaction',
  };

  @override
  void initState() {
    super.initState();
    _amount.text =
        widget.occurrence.amount?.amount ??
        widget.bill.expectedAmount?.amount ??
        '';
    _accountId = widget.bill.paymentAccountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? _currency(Map<String, AccountDto> accounts) =>
      (_accountId == null ? null : accounts[_accountId]?.currency) ??
      widget.bill.currency;

  BillCandidatesQuery get _query =>
      (billId: widget.bill.id, occurrenceId: widget.occurrence.id);

  Future<void> _pickTransaction() async {
    final TransactionDto? t = await showTransactionPicker(
      context,
      filter: const TransactionFilter(types: <String>{'expense'}),
    );
    if (t != null && mounted) {
      setState(() {
        _linked = _Linked(
          id: t.id,
          title: t.merchant?.name ?? t.description ?? t.localDate,
          amount: t.amount,
        );
        _errors = ServerFormErrors.none;
      });
    }
  }

  Future<void> _pickAccount() async {
    final AccountDto? picked = await showAccountPicker(
      context,
      selectedId: _accountId,
    );
    if (picked != null && mounted) {
      setState(() => _accountId = picked.id);
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() => _errors = ServerFormErrors.none);
    final MarkPaidInput input;
    if (_mode == _PayMode.link) {
      final _Linked? linked = _linked;
      if (linked == null) {
        setState(
          () => _errors = ServerFormErrors(
            fields: <String, String>{'transaction': l10n.billChoosePayment},
          ),
        );
        return;
      }
      input = MarkPaidInput(
        occurrenceId: widget.occurrence.id,
        transactionId: linked.id,
      );
    } else {
      if (!(_form.currentState?.validate() ?? false)) {
        return;
      }
      if (_accountId == null) {
        setState(
          () => _errors = ServerFormErrors(
            fields: <String, String>{'account': l10n.billAccountRequired},
          ),
        );
        return;
      }
      final String text = _amount.text.trim();
      input = MarkPaidInput(
        occurrenceId: widget.occurrence.id,
        createTransaction: true,
        amount: text.isEmpty
            ? null
            : readAmount(
                context,
                ref,
                text,
                currency: _currency(ref.read(accountIndexProvider)),
              ).value,
        accountId: _accountId,
        paidOn: _paidOn,
      );
    }
    final BillsApi api = ref.read(billsApiProvider);
    try {
      await api.markPaid(
        widget.bill.id,
        input,
        key: _submission.keyFor(<String, Object?>{
          'bill': widget.bill.id,
          ...input.toJson(),
        }),
      );
      _submission.reset();
      finance.bump();
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.billMarkedPaid);
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.billPayTitle)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            Text(
              l10n.billPayIntro(
                widget.bill.name,
                LocalDates.display(
                  widget.occurrence.effectiveDate,
                  locale: locale,
                ),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Insets.md),
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            SegmentedButton<_PayMode>(
              segments: <ButtonSegment<_PayMode>>[
                ButtonSegment<_PayMode>(
                  value: _PayMode.link,
                  label: Text(l10n.billPayLinkMode),
                  icon: const Icon(Icons.link),
                ),
                ButtonSegment<_PayMode>(
                  value: _PayMode.record,
                  label: Text(l10n.billPayRecordMode),
                  icon: const Icon(Icons.add),
                ),
              ],
              selected: <_PayMode>{_mode},
              onSelectionChanged: (Set<_PayMode> s) => setState(() {
                _mode = s.first;
                _errors = ServerFormErrors.none;
              }),
            ),
            const SizedBox(height: Insets.md),
            if (_mode == _PayMode.link)
              ..._linkSection(context, l10n, locale)
            else
              ..._recordSection(context, l10n, accounts),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.billMarkPaid, onPressed: _submit),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }

  List<Widget> _linkSection(
    BuildContext context,
    AppLocalizations l10n,
    String locale,
  ) {
    final AsyncValue<List<BillPaymentCandidate>> candidates = ref.watch(
      billCandidatesProvider(_query),
    );
    final _Linked? linked = _linked;
    final String? error = _errors['transaction'];
    return <Widget>[
      Text(l10n.billPayLinkHelp),
      const SizedBox(height: Insets.sm),
      candidates.when(
        skipLoadingOnReload: true,
        loading: () => const Padding(
          padding: EdgeInsets.all(Insets.md),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object e, StackTrace _) => NoticeBanner(
          tone: NoticeTone.error,
          // A coded refusal (for example `occurrence_not_open` when this
          // payment was already handled) explains itself.
          message:
              e is ApiException &&
                  e.details.any((Detail d) => (d.code ?? '').isNotEmpty)
              ? describeError(l10n, e)
              : l10n.billCandidatesError,
          action: TextButton(
            onPressed: () => ref.invalidate(billCandidatesProvider(_query)),
            child: Text(l10n.actionRetry),
          ),
        ),
        data: (List<BillPaymentCandidate> list) => list.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                child: Text(l10n.billNoCandidates),
              )
            : RadioGroup<String>(
                groupValue: linked?.id,
                onChanged: (String? id) {
                  final BillPaymentCandidate? c = list
                      .where((BillPaymentCandidate c) => c.transactionId == id)
                      .firstOrNull;
                  if (c != null) {
                    setState(() {
                      _linked = _Linked(
                        id: c.transactionId,
                        title: c.merchant ?? c.description ?? c.accountName,
                        amount: c.amount,
                      );
                      _errors = ServerFormErrors.none;
                    });
                  }
                },
                child: Column(
                  children: <Widget>[
                    for (final BillPaymentCandidate c in list)
                      _CandidateTile(candidate: c, locale: locale),
                  ],
                ),
              ),
      ),
      if (linked != null &&
          !(candidates.value ?? const <BillPaymentCandidate>[]).any(
            (BillPaymentCandidate c) => c.transactionId == linked.id,
          )) ...<Widget>[
        const SizedBox(height: Insets.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle),
            title: Text(linked.title),
            subtitle: Text(l10n.billChosenPayment),
            trailing: MoneyText(linked.amount),
          ),
        ),
      ],
      const SizedBox(height: Insets.sm),
      OutlinedButton.icon(
        onPressed: _pickTransaction,
        icon: const Icon(Icons.search),
        label: Text(l10n.billChooseOtherPayment),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: Insets.sm),
          child: Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ];
  }

  List<Widget> _recordSection(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, AccountDto> accounts,
  ) => <Widget>[
    Text(l10n.billPayRecordHelp),
    const SizedBox(height: Insets.md),
    AmountField(
      controller: _amount,
      label: l10n.billPaidAmountLabel,
      currency: _currency(accounts),
      isRequired: widget.bill.amountIsVariable,
      helperText: widget.bill.amountIsVariable ? null : l10n.billPaidAmountHelp,
      errorText: _errors['amount'],
    ),
    const SizedBox(height: Insets.md),
    SelectorField(
      label: l10n.billPaidFromLabel,
      value: _accountId == null ? null : accounts[_accountId]?.name,
      icon: Icons.account_balance_wallet_outlined,
      errorText: _errors['account'],
      onTap: _pickAccount,
    ),
    const SizedBox(height: Insets.md),
    DateSelectorField(
      label: l10n.billPaidOnLabel,
      value: _paidOn,
      emptyLabel: l10n.dateToday,
      clearable: true,
      lastDate: LocalDates.today(),
      errorText: _errors['paidOn'],
      onChanged: (String? d) => setState(() => _paidOn = d),
    ),
  ];
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate, required this.locale});

  final BillPaymentCandidate candidate;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final BillPaymentCandidate c = candidate;
    final List<String> reasons = billCandidateReasons(context.l10n, c);
    return RadioListTile<String>(
      value: c.transactionId,
      contentPadding: EdgeInsets.zero,
      title: Text(
        <String>[
              ?c.merchant,
              if (c.merchant == null) ?c.description,
            ].firstOrNull ??
            c.accountName,
      ),
      subtitle: Text(
        <String>[
          LocalDates.display(c.localDate, locale: locale),
          c.accountName,
          ...reasons,
        ].join(' · '),
      ),
      secondary: MoneyText(c.amount),
    );
  }
}
