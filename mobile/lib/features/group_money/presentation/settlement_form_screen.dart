import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

/// Records a payment between two members (a settlement), or corrects one
/// (records the right one and voids the original). Montra never moves
/// money: this notes a payment made in cash, by bank transfer or UPI, and
/// the other side confirms it. Saved with an `Idempotency-Key`.
class SettlementFormScreen extends ConsumerWidget {
  /// Creates the form; [correctsId] corrects that settlement.
  const SettlementFormScreen({
    required this.groupId,
    this.correctsId,
    this.payerId,
    this.payeeId,
    this.amount,
    super.key,
  });

  /// The group.
  final String groupId;

  /// The settlement to correct, if any.
  final String? correctsId;

  /// Prefilled payer (from a suggestion).
  final String? payerId;

  /// Prefilled payee.
  final String? payeeId;

  /// Prefilled amount (decimal string).
  final String? amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String title = correctsId == null
        ? l10n.gxRecordPayment
        : l10n.gxCorrectTitle;
    return GroupPeopleScope(
      groupId: groupId,
      title: title,
      builder: (BuildContext context, GroupPeople people) {
        final String? id = correctsId;
        if (id == null) {
          return _SettlementForm(
            people: people,
            payerId: payerId,
            payeeId: payeeId,
            amount: amount,
          );
        }
        final GroupRecord record = (groupId: groupId, id: id);
        final AsyncValue<SettlementDto> s = ref.watch(
          groupSettlementProvider(record),
        );
        final SettlementDto? loaded = s.value;
        if (loaded != null) {
          return _SettlementForm(people: people, original: loaded);
        }
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: s.hasError && !s.isLoading
              ? ErrorStateView(
                  error: s.error!,
                  onRetry: () =>
                      ref.invalidate(groupSettlementProvider(record)),
                )
              : const LoadingStateView(),
        );
      },
    );
  }
}

class _SettlementForm extends ConsumerStatefulWidget {
  const _SettlementForm({
    required this.people,
    this.original,
    this.payerId,
    this.payeeId,
    this.amount,
  });

  final GroupPeople people;
  final SettlementDto? original;
  final String? payerId;
  final String? payeeId;
  final String? amount;

  @override
  ConsumerState<_SettlementForm> createState() => _SettlementFormState();
}

class _SettlementFormState extends ConsumerState<_SettlementForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();
  String? _payer;
  String? _payee;
  String _method = 'upi';
  String? _date;
  bool _proposed = false;
  String? _accountId;
  String? _receiptFileId;
  String? _receiptName;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'payer_user_id': 'payer',
    'payee_user_id': 'payee',
    'amount': 'amount',
    'method': 'method',
    'settled_on': 'date',
    'note': 'note',
    'account_id': 'account',
    'receipt_file_id': 'receipt',
  };

  GroupPeople get _people => widget.people;
  String get _groupId => _people.group.id;
  bool get _correcting => widget.original != null;

  @override
  void initState() {
    super.initState();
    final SettlementDto? s = widget.original;
    if (s != null) {
      _payer = s.payerUserId;
      _payee = s.payeeUserId;
      _amount.text = s.amount.amount;
      _method = s.method == SettlementDtoMethod.unrecognized
          ? 'other'
          : s.method.json;
      _date = s.settledOn;
      _note.text = s.note ?? '';
      _receiptFileId = s.receiptFileId;
    } else {
      _payer = widget.payerId ?? _people.me;
      _payee = widget.payeeId;
      final String? a = widget.amount;
      if (a != null && a.isNotEmpty) {
        _amount.text = a.startsWith('-') ? a.substring(1) : a;
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool payer}) async {
    final AppLocalizations l10n = context.l10n;
    final String? picked = await showMemberPicker(
      context,
      people: _people,
      title: payer ? l10n.gxWhoPaid : l10n.gxWhoReceived,
      includeFormer: true,
      exclude: <String>{?(payer ? _payee : _payer)},
    );
    if (picked != null && mounted) {
      setState(() => payer ? _payer = picked : _payee = picked);
    }
  }

  Future<void> _pickAccount() async {
    final AccountDto? picked = await showAccountPicker(
      context,
      selectedId: _accountId,
      currency: _people.currency,
      title: context.l10n.gxRecordInAccount,
    );
    if (picked != null && mounted) {
      setState(() => _accountId = picked.id);
    }
  }

  Future<void> _attach() async {
    final PickedFile? picked = await pickFileFor(
      context,
      ref,
      purpose: UploadPurpose.groupAttachment,
    );
    if (picked == null || !mounted) {
      return;
    }
    final FileDto? file = await uploadWithProgress(
      context,
      file: picked,
      purpose: UploadPurpose.groupAttachment,
      groupId: _groupId,
    );
    if (file != null && mounted) {
      setState(() {
        _receiptFileId = file.id;
        _receiptName = file.originalFilename ?? picked.name;
      });
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    final Map<String, String> missing = <String, String>{
      if (_payer == null) 'payer': l10n.validationRequired,
      if (_payee == null) 'payee': l10n.validationRequired,
    };
    final bool valid = _form.currentState?.validate() ?? false;
    if (missing.isNotEmpty) {
      setState(() => _errors = ServerFormErrors(fields: missing));
    }
    if (!valid || missing.isNotEmpty) {
      return;
    }
    final String? note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final SettlementInput input = SettlementInput(
      payerUserId: _payer!,
      payeeUserId: _payee!,
      amount:
          readAmount(
            context,
            ref,
            _amount.text,
            currency: _people.currency,
          ).value ??
          '',
      method: SettlementInputMethod.fromJson(_method),
      settledOn: _date,
      note: note,
      state: _correcting
          ? null
          : (_proposed ? SettlementInputState.proposed : null),
      accountId: !_proposed && _people.isMe(_payer) ? _accountId : null,
      receiptFileId: _receiptFileId,
    );
    final GroupMoneyApi api = ref.read(groupMoneyApiProvider);
    final GoRouter router = GoRouter.of(context);
    final SettlementDto? original = widget.original;
    try {
      final SettlementDto saved = original == null
          ? await api.createSettlement(
              _groupId,
              input,
              key: _submission.keyFor(input.toJson()),
            )
          : await api.correctSettlement(
              _groupId,
              original.id,
              input,
              key: _submission.keyFor(input.toJson()),
            );
      _submission.reset();
      if (!mounted) {
        return;
      }
      groupMoneyChanged(ref, _groupId);
      showSnack(
        context,
        _correcting ? l10n.gxCorrected : l10n.gxPaymentRecorded,
      );
      unawaited(
        router.pushReplacement(
          AppRoutes.groupSettlementDetail(_groupId, saved.id),
        ),
      );
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
    final ThemeData theme = Theme.of(context);
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(
        title: Text(_correcting ? l10n.gxCorrectTitle : l10n.gxRecordPayment),
      ),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            NoticeBanner(
              message: _correcting ? l10n.gxCorrectIntro : l10n.gxRecordIntro,
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
            SelectorField(
              label: l10n.gxWhoPaid,
              value: _payer == null ? null : _people.name(l10n, _payer),
              icon: Icons.north_east,
              errorText: _errors['payer'],
              onTap: () => _pick(payer: true),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.gxWhoReceived,
              value: _payee == null ? null : _people.name(l10n, _payee),
              icon: Icons.south_west,
              errorText: _errors['payee'],
              onTap: () => _pick(payer: false),
            ),
            if (_payee != null && !_people.isActiveMember(_payee)) ...<Widget>[
              const SizedBox(height: Insets.xs),
              Text(l10n.gxFormerPayeeNote, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _amount,
              label: l10n.amountLabel,
              currency: _people.currency,
              helperText: l10n.gxPartialAllowed,
              errorText: _errors['amount'],
            ),
            const SizedBox(height: Insets.md),
            Text(l10n.gxMethodLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: Insets.xs),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String m in <String>[
                  'cash',
                  'bank_transfer',
                  'upi',
                  'other',
                ])
                  ChoiceChip(
                    label: Text(settlementMethodLabel(l10n, m)),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            if (!_correcting) ...<Widget>[
              const SizedBox(height: Insets.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.gxProposedLabel),
                subtitle: Text(l10n.gxProposedHelp),
                value: _proposed,
                onChanged: (bool v) => setState(() => _proposed = v),
              ),
            ],
            const SizedBox(height: Insets.md),
            DateSelectorField(
              label: l10n.dateLabel,
              value: _date,
              emptyLabel: l10n.gxDateToday,
              errorText: _errors['date'],
              clearable: true,
              onChanged: (String? v) => setState(() => _date = v),
            ),
            if (!_proposed && _people.isMe(_payer)) ...<Widget>[
              const SizedBox(height: Insets.md),
              SelectorField(
                label: l10n.optionalLabel(l10n.gxRecordInAccount),
                value: _accountId == null ? null : accounts[_accountId]?.name,
                icon: Icons.account_balance_wallet_outlined,
                helperText: l10n.gxSettlementAccountHelp,
                errorText: _errors['account'],
                onTap: _pickAccount,
                onClear: () => setState(() => _accountId = null),
              ),
            ],
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _note,
              maxLength: SettlementInput.noteMaxLength,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.notesLabel),
                errorText: _errors['note'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Insets.sm),
            if (_receiptFileId == null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _attach,
                  icon: const Icon(Icons.attach_file),
                  label: Text(l10n.gxAttachProof),
                ),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file),
                title: Text(_receiptName ?? l10n.gxReceiptAttached),
                trailing: IconButton(
                  tooltip: l10n.gxReceiptRemove,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _receiptFileId = null;
                    _receiptName = null;
                  }),
                ),
              ),
            if (_errors['receipt'] case final String e)
              Text(
                e,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              label: _correcting ? l10n.gxCorrectButton : l10n.gxRecordPayment,
              onPressed: _submit,
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
