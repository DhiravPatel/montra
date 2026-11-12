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
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/accounts/presentation/account_widgets.dart';

/// Corrects an account balance with an auditable adjustment (reason
/// required). The user either states the balance it should have or the
/// change; the server records the difference as an `adjustment`
/// transaction and never overwrites the ledger.
class AdjustBalanceScreen extends ConsumerWidget {
  /// Creates the screen for [accountId].
  const AdjustBalanceScreen({required this.accountId, super.key});

  /// The account.
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<AccountDto> account = ref.watch(
      accountDetailProvider(accountId),
    );
    return account.when(
      skipLoadingOnReload: true,
      data: (AccountDto a) => _AdjustForm(account: a),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.adjustTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.adjustTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(accountDetailProvider(accountId)),
        ),
      ),
    );
  }
}

enum _Mode { target, delta }

class _AdjustForm extends ConsumerStatefulWidget {
  const _AdjustForm({required this.account});

  final AccountDto account;

  @override
  ConsumerState<_AdjustForm> createState() => _AdjustFormState();
}

class _AdjustFormState extends ConsumerState<_AdjustForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();
  _Mode _mode = _Mode.target;
  String? _date;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'target_balance': 'amount',
    'delta': 'amount',
    'reason': 'reason',
    'effective_date': 'date',
  };

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String? value = readAmount(
      context,
      ref,
      _amount.text,
      currency: widget.account.currency,
      allowNegative: true,
      allowZero: _mode == _Mode.target,
    ).value;
    if (value == null) {
      return;
    }
    final AdjustmentInput input = AdjustmentInput(
      reason: _reason.text.trim(),
      targetBalance: _mode == _Mode.target ? value : null,
      delta: _mode == _Mode.delta ? value : null,
      effectiveDate: _date,
    );
    try {
      await ref
          .read(accountsApiProvider)
          .adjust(
            widget.account.id,
            input,
            key: _submission.keyFor(input.toJson()),
          );
      _submission.reset();
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.adjustDone);
        context.pop();
      }
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
    final AccountDto a = widget.account;
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adjustTitle)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            Text(l10n.adjustIntro(a.name)),
            const SizedBox(height: Insets.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(l10n.adjustCurrentBalance)),
                    AccountBalanceText(a),
                  ],
                ),
              ),
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
            SegmentedButton<_Mode>(
              segments: <ButtonSegment<_Mode>>[
                ButtonSegment<_Mode>(
                  value: _Mode.target,
                  label: Text(l10n.adjustModeTarget),
                ),
                ButtonSegment<_Mode>(
                  value: _Mode.delta,
                  label: Text(l10n.adjustModeDelta),
                ),
              ],
              selected: <_Mode>{_mode},
              onSelectionChanged: (Set<_Mode> s) =>
                  setState(() => _mode = s.first),
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _amount,
              label: _mode == _Mode.target
                  ? l10n.adjustTargetLabel
                  : l10n.adjustDeltaLabel,
              helperText: _mode == _Mode.target
                  ? (a.isLiability
                        ? l10n.adjustTargetLiabilityHelp
                        : l10n.adjustTargetHelp)
                  : l10n.adjustDeltaHelp,
              currency: a.currency,
              allowNegative: true,
              allowZero: _mode == _Mode.target,
              errorText: _errors['amount'],
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _reason,
              maxLength: AdjustmentInput.reasonMaxLength,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.adjustReasonLabel,
                helperText: l10n.adjustReasonHelp,
                errorText: _errors['reason'],
              ),
              validator: (String? v) =>
                  (v ?? '').trim().length < AdjustmentInput.reasonMinLength
                  ? l10n.adjustReasonTooShort
                  : null,
            ),
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.adjustDateLabel,
              value: _date,
              emptyLabel: l10n.dateToday,
              clearable: true,
              lastDate: DateTime.now(),
              errorText: _errors['date'],
              onChanged: (String? d) => setState(() => _date = d),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.adjustButton, onPressed: _submit),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
