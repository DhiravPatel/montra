import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/amount_input.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

enum _FxMode { received, rate }

/// Moves money between two of the user's accounts. The server writes both
/// legs (and an optional fee expense) atomically; transfers never count as
/// income or spending. Cross-currency transfers need the amount received
/// or an exact exchange rate.
class TransferFormScreen extends ConsumerStatefulWidget {
  /// Creates the form; [fromAccountId] presets the source.
  const TransferFormScreen({this.fromAccountId, super.key});

  /// Source account.
  final String? fromAccountId;

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _toAmount = TextEditingController();
  final TextEditingController _rate = TextEditingController();
  final TextEditingController _fee = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();
  late String? _fromId = widget.fromAccountId;
  String? _toId;
  String? _date;
  _FxMode _fxMode = _FxMode.received;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'from_account_id': 'from',
    'to_account_id': 'to',
    'amount': 'amount',
    'to_amount': 'toAmount',
    'fx_rate': 'rate',
    'fee': 'fee',
    'local_date': 'date',
    'description': 'description',
    'notes': 'notes',
  };

  @override
  void dispose() {
    _amount.dispose();
    _toAmount.dispose();
    _rate.dispose();
    _fee.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    final Map<String, AccountDto> accounts = ref.read(accountIndexProvider);
    final AccountDto? from = _fromId == null ? null : accounts[_fromId];
    final AccountDto? to = _toId == null ? null : accounts[_toId];
    final Map<String, String> missing = <String, String>{
      if (from == null) 'from': l10n.validationAccountRequired,
      if (to == null) 'to': l10n.validationAccountRequired,
    };
    final bool valid = _form.currentState?.validate() ?? false;
    if (missing.isNotEmpty) {
      setState(() => _errors = ServerFormErrors(fields: missing));
      return;
    }
    if (!valid || from == null || to == null) {
      return;
    }
    final bool crossCurrency = from.currency != to.currency;
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final TransferInput input = TransferInput(
      fromAccountId: from.id,
      toAccountId: to.id,
      amount:
          readAmount(
            context,
            ref,
            _amount.text,
            currency: from.currency,
          ).value ??
          _amount.text.trim(),
      toAmount: crossCurrency && _fxMode == _FxMode.received
          ? readAmount(
              context,
              ref,
              _toAmount.text,
              currency: to.currency,
            ).value
          : null,
      fxRate: crossCurrency && _fxMode == _FxMode.rate
          ? RateInput.parse(_rate.text)
          : null,
      fee: _fee.text.trim().isEmpty
          ? null
          : readAmount(
              context,
              ref,
              _fee.text,
              currency: from.currency,
              allowZero: true,
            ).value,
      localDate: _date,
      description: text(_description),
      notes: text(_notes),
    );
    try {
      final TransferDto transfer = await ref
          .read(transactionsApiProvider)
          .transfer(input, key: _submission.keyFor(input.toJson()));
      _submission.reset();
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.transferSaved);
        context.pushReplacement(AppRoutes.transferDetail(transfer.id));
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
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final AccountDto? from = _fromId == null ? null : accounts[_fromId];
    final AccountDto? to = _toId == null ? null : accounts[_toId];
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferNewTitle)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            Text(l10n.transferIntro),
            const SizedBox(height: Insets.md),
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            SelectorField(
              label: l10n.transferFromLabel,
              icon: Icons.north_east,
              value: from == null ? null : '${from.name} · ${from.currency}',
              placeholder: l10n.accountFieldPlaceholder,
              errorText: _errors['from'],
              onTap: () async {
                final AccountDto? a = await showAccountPicker(
                  context,
                  selectedId: _fromId,
                  exclude: <String>{?_toId},
                  title: l10n.transferFromLabel,
                );
                if (a != null && mounted) {
                  setState(() => _fromId = a.id);
                }
              },
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.transferToLabel,
              icon: Icons.south_west,
              value: to == null ? null : '${to.name} · ${to.currency}',
              placeholder: l10n.accountFieldPlaceholder,
              errorText: _errors['to'],
              onTap: () async {
                final AccountDto? a = await showAccountPicker(
                  context,
                  selectedId: _toId,
                  exclude: <String>{?_fromId},
                  title: l10n.transferToLabel,
                );
                if (a != null && mounted) {
                  setState(() => _toId = a.id);
                }
              },
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _amount,
              label: l10n.transferAmountLabel,
              helperText: l10n.transferAmountHelp,
              currency: from?.currency,
              errorText: _errors['amount'],
            ),
            if (from != null &&
                to != null &&
                from.currency != to.currency) ...<Widget>[
              FormSectionHeader(l10n.transferFxSection),
              Text(l10n.transferFxHelp(from.currency, to.currency)),
              const SizedBox(height: Insets.sm),
              SegmentedButton<_FxMode>(
                segments: <ButtonSegment<_FxMode>>[
                  ButtonSegment<_FxMode>(
                    value: _FxMode.received,
                    label: Text(l10n.transferFxReceived),
                  ),
                  ButtonSegment<_FxMode>(
                    value: _FxMode.rate,
                    label: Text(l10n.transferFxRate),
                  ),
                ],
                selected: <_FxMode>{_fxMode},
                onSelectionChanged: (Set<_FxMode> s) =>
                    setState(() => _fxMode = s.first),
              ),
              const SizedBox(height: Insets.md),
              if (_fxMode == _FxMode.received)
                AmountField(
                  controller: _toAmount,
                  label: l10n.transferToAmountLabel,
                  currency: to.currency,
                  errorText: _errors['toAmount'],
                )
              else
                TextFormField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.transferRateLabel(
                      from.currency,
                      to.currency,
                    ),
                    helperText: l10n.transferRateHelp,
                    errorText: _errors['rate'],
                  ),
                  validator: (String? v) => RateInput.parse(v ?? '') == null
                      ? l10n.transferRateInvalid
                      : null,
                ),
            ],
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _fee,
              label: l10n.optionalLabel(l10n.transferFeeLabel),
              helperText: l10n.transferFeeHelp,
              currency: from?.currency,
              isRequired: false,
              allowZero: true,
              errorText: _errors['fee'],
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
              maxLength: TransferInput.descriptionMaxLength,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.descriptionLabel),
                errorText: _errors['description'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _notes,
              maxLength: TransferInput.notesMaxLength,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['notes'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.transferSave, onPressed: _submit),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
