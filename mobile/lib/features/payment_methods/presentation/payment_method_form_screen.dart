import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/payment_methods/application/payment_methods_providers.dart';
import 'package:montra_mobile/features/payment_methods/data/payment_methods_api.dart';

/// Creates or edits a payment method. Only a label and masked hints are
/// stored; the form warns against full numbers, CVVs and PINs and the
/// server rejects hints with more than four digits.
class PaymentMethodFormScreen extends ConsumerWidget {
  /// Creates the form; [methodId] switches to edit mode.
  const PaymentMethodFormScreen({this.methodId, super.key});

  /// Method to edit, or null to create one.
  final String? methodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = methodId;
    final AppLocalizations l10n = context.l10n;
    if (id == null) {
      return const _MethodForm();
    }
    final AsyncValue<PaymentMethodDto> method = ref.watch(
      paymentMethodProvider(id),
    );
    return method.when(
      skipLoadingOnReload: true,
      data: (PaymentMethodDto m) => _MethodForm(original: m),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.paymentEditTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.paymentEditTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(paymentMethodProvider(id)),
        ),
      ),
    );
  }
}

class _MethodForm extends ConsumerStatefulWidget {
  const _MethodForm({this.original});

  final PaymentMethodDto? original;

  @override
  ConsumerState<_MethodForm> createState() => _MethodFormState();
}

class _MethodFormState extends ConsumerState<_MethodForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _label = TextEditingController();
  final TextEditingController _hint = TextEditingController();
  PaymentMethodInputKind _kind = PaymentMethodInputKind.upi;
  PaymentMethodInputNetwork? _network;
  String? _accountId;
  bool _isDefault = false;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'label': 'label',
    'kind': 'kind',
    'masked_hint': 'hint',
    'network': 'network',
    'account_id': 'account',
  };

  @override
  void initState() {
    super.initState();
    _load(widget.original);
  }

  @override
  void didUpdateWidget(covariant _MethodForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final PaymentMethodDto? next = widget.original;
    if (next != null && next.version != oldWidget.original?.version) {
      _load(next);
    }
  }

  void _load(PaymentMethodDto? o) {
    if (o == null) {
      return;
    }
    _label.text = o.label;
    _hint.text = o.maskedHint ?? '';
    _kind = kindOf(o);
    _network = networkOf(o);
    _accountId = o.accountId;
    _isDefault = o.isDefault;
  }

  @override
  void dispose() {
    _label.dispose();
    _hint.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
    });
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final String hint = _hint.text.trim();
    final PaymentMethodInputNetwork? network = hasNetwork(_kind)
        ? _network
        : null;
    final PaymentMethodsApi api = ref.read(paymentMethodsApiProvider);
    try {
      final PaymentMethodDto? o = widget.original;
      if (o == null) {
        await api.create(
          PaymentMethodInput(
            kind: _kind,
            label: _label.text.trim(),
            maskedHint: hint.isEmpty ? null : hint,
            network: network,
            accountId: _accountId,
            isDefault: _isDefault,
          ),
        );
      } else {
        // Only what changed is sent; the version detects concurrent edits.
        final bool kindChanged = _kind != kindOf(o);
        final bool networkChanged = network != networkOf(o);
        final bool accountChanged = _accountId != o.accountId;
        await api.update(
          o.id,
          PaymentMethodPatch(
            version: o.version,
            label: _label.text.trim() == o.label ? null : _label.text.trim(),
            kind: kindChanged ? patchKind(_kind) : null,
            maskedHint: hint == (o.maskedHint ?? '') ? null : hint,
            network: networkChanged ? patchNetwork(network) : null,
            accountId: accountChanged ? _accountId : null,
            clearAccount: accountChanged && _accountId == null ? true : null,
            isDefault: _isDefault == o.isDefault ? null : _isDefault,
          ),
        );
      }
      finance.bump();
      if (mounted) {
        showSnack(context, o == null ? l10n.paymentCreated : l10n.paymentSaved);
        context.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final PaymentMethodDto? o = widget.original;
      if (error.code == ErrorObjectCode.versionConflict && o != null) {
        ref.invalidate(paymentMethodProvider(o.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  Future<void> _pickAccount() async {
    final AccountDto? account = await showAccountPicker(
      context,
      selectedId: _accountId,
    );
    if (account != null && mounted) {
      setState(() => _accountId = account.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.original == null
              ? l10n.paymentNewTitle
              : l10n.paymentEditTitle,
        ),
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
            DropdownButtonFormField<PaymentMethodInputKind>(
              // Rebuilt when a newer version is loaded after a conflict.
              key: ValueKey<int?>(widget.original?.version),
              initialValue: _kind,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.paymentKindLabel,
                errorText: _errors['kind'],
              ),
              items: <DropdownMenuItem<PaymentMethodInputKind>>[
                for (final PaymentMethodInputKind k
                    in PaymentMethodInputKind.values)
                  if (k != PaymentMethodInputKind.unrecognized)
                    DropdownMenuItem<PaymentMethodInputKind>(
                      value: k,
                      child: Row(
                        children: <Widget>[
                          Icon(paymentKindIcon(k), size: 20),
                          const SizedBox(width: Insets.sm),
                          Flexible(child: Text(paymentKindLabel(l10n, k))),
                        ],
                      ),
                    ),
              ],
              onChanged: (PaymentMethodInputKind? k) {
                if (k != null) {
                  setState(() => _kind = k);
                }
              },
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _label,
              maxLength: PaymentMethodInput.labelMaxLength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.paymentLabelLabel,
                helperText: l10n.paymentLabelHelp,
                errorText: _errors['label'],
                counterText: '',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? l10n.validationRequired : null,
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _hint,
              maxLength: PaymentMethodInput.maskedHintMaxLength,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.optionalLabel(l10n.paymentHintLabel),
                helperText: l10n.paymentHintHelp,
                errorText: _errors['hint'],
                counterText: '',
              ),
              validator: (String? v) =>
                  RegExp(r'\d').allMatches(v ?? '').length > 4
                  ? l10n.paymentHintTooManyDigits
                  : null,
            ),
            if (hasNetwork(_kind)) ...<Widget>[
              const SizedBox(height: Insets.md),
              DropdownButtonFormField<PaymentMethodInputNetwork?>(
                key: ValueKey<String>('network-${widget.original?.version}'),
                initialValue: _network,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.optionalLabel(l10n.paymentNetworkLabel),
                  errorText: _errors['network'],
                ),
                items: <DropdownMenuItem<PaymentMethodInputNetwork?>>[
                  DropdownMenuItem<PaymentMethodInputNetwork?>(
                    child: Text(l10n.notSetLabel),
                  ),
                  for (final PaymentMethodInputNetwork n
                      in PaymentMethodInputNetwork.values)
                    if (n != PaymentMethodInputNetwork.unrecognized)
                      DropdownMenuItem<PaymentMethodInputNetwork?>(
                        value: n,
                        child: Text(networkLabel(l10n, n)),
                      ),
                ],
                onChanged: (PaymentMethodInputNetwork? n) =>
                    setState(() => _network = n),
              ),
            ],
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.optionalLabel(l10n.paymentAccountLabel),
              value: _accountId == null
                  ? null
                  : (accounts[_accountId]?.name ?? l10n.paymentAccountUnknown),
              placeholder: l10n.notSetLabel,
              icon: Icons.account_balance_wallet_outlined,
              helperText: l10n.paymentAccountHelp,
              errorText: _errors['account'],
              onTap: _pickAccount,
              onClear: () => setState(() => _accountId = null),
            ),
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.paymentMakeDefault),
              value: _isDefault,
              onChanged: (bool v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.actionSave, onPressed: _submit),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}
