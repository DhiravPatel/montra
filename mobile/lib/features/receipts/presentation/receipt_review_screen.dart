import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/amount_field.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/auth/presentation/currency_picker.dart';
import 'package:montra_mobile/features/receipts/application/receipts_providers.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_display.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

/// Manual review of a receipt (`PATCH /receipts/{id}/review`): the user
/// types or corrects every value from the paper receipt. Amounts are exact
/// decimals in the receipt currency; the receipt's `version` guards against
/// changes made elsewhere.
class ReceiptReviewScreen extends ConsumerWidget {
  /// Creates the form for [receiptId].
  const ReceiptReviewScreen({required this.receiptId, super.key});

  /// The receipt.
  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ReceiptView> receipt = ref.watch(
      receiptProvider(receiptId),
    );
    return receipt.when(
      skipLoadingOnReload: true,
      data: (ReceiptView view) => canReviewReceipt(view.detail.status.json)
          ? _ReviewForm(receipt: view.detail)
          : Scaffold(
              appBar: AppBar(title: Text(l10n.receiptReviewTitle)),
              body: MessageStateView(
                icon: Icons.lock_outline,
                title: l10n.receiptReviewUnavailable,
                body: receiptStatusHelp(l10n, view.detail.status.json),
              ),
            ),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.receiptReviewTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.receiptReviewTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(receiptProvider(receiptId)),
        ),
      ),
    );
  }
}

/// Editable copy of one line item.
class _LineDraft {
  _LineDraft([ReceiptLineItemDto? item])
    : description = TextEditingController(text: item?.description ?? ''),
      quantity = TextEditingController(text: item?.quantity ?? ''),
      unitPrice = TextEditingController(text: item?.unitPrice?.amount ?? ''),
      amount = TextEditingController(text: item?.amount?.amount ?? ''),
      tax = TextEditingController(text: item?.tax?.amount ?? '');

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController amount;
  final TextEditingController tax;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    amount.dispose();
    tax.dispose();
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.receipt});

  final ReceiptDetail receipt;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _merchant = TextEditingController();
  final TextEditingController _total = TextEditingController();
  final TextEditingController _subtotal = TextEditingController();
  final TextEditingController _tax = TextEditingController();
  final TextEditingController _tip = TextEditingController();
  final TextEditingController _discount = TextEditingController();
  final TextEditingController _number = TextEditingController();
  final TextEditingController _payment = TextEditingController();
  final List<_LineDraft> _lines = <_LineDraft>[];
  String? _date;
  String? _time;
  String? _currency;
  String? _dateError;
  ServerFormErrors _errors = ServerFormErrors.none;
  bool _conflictReloaded = false;

  static const Map<String, String> _fields = <String, String>{
    'merchant_name': 'merchant',
    'receipt_date': 'date',
    'receipt_time': 'time',
    'currency': 'currency',
    'total': 'total',
    'subtotal': 'subtotal',
    'tax': 'tax',
    'tip': 'tip',
    'discount': 'discount',
    'receipt_number': 'number',
    'payment_hint': 'payment',
    'line_items': 'lines',
  };

  @override
  void initState() {
    super.initState();
    _load(widget.receipt);
  }

  @override
  void didUpdateWidget(covariant _ReviewForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.receipt.version != oldWidget.receipt.version) {
      _load(widget.receipt);
    }
  }

  void _load(ReceiptDetail r) {
    final ReceiptExtractionDto? e = r.current;
    _merchant.text = e?.merchantName ?? '';
    _total.text = e?.total?.amount ?? '';
    _subtotal.text = e?.subtotal?.amount ?? '';
    _tax.text = e?.tax?.amount ?? '';
    _tip.text = e?.tip?.amount ?? '';
    _discount.text = e?.discount?.amount ?? '';
    _number.text = e?.receiptNumber ?? '';
    _payment.text = e?.paymentHint ?? '';
    _date = e?.receiptDate;
    _time = e?.receiptTime;
    final AuthState auth = ref.read(authControllerProvider);
    _currency =
        e?.currency ??
        e?.total?.currency ??
        (auth is SignedIn ? auth.user.baseCurrency : null);
    for (final _LineDraft l in _lines) {
      l.dispose();
    }
    _lines
      ..clear()
      ..addAll(<_LineDraft>[
        for (final ReceiptLineItemDto item
            in e?.lineItems ?? const <ReceiptLineItemDto>[])
          _LineDraft(item),
      ]);
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _merchant,
      _total,
      _subtotal,
      _tax,
      _tip,
      _discount,
      _number,
      _payment,
    ]) {
      c.dispose();
    }
    for (final _LineDraft l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  String? _amount(TextEditingController c) {
    if (c.text.trim().isEmpty) {
      return null;
    }
    return readAmount(
      context,
      ref,
      c.text,
      currency: _currency,
      allowZero: true,
    ).value;
  }

  String? _text(TextEditingController c) {
    final String v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _pickTime() async {
    final List<String> parts = (_time ?? '').split(':');
    final TimeOfDay initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 12,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null && mounted) {
      String two(int v) => v.toString().padLeft(2, '0');
      setState(() => _time = '${two(picked.hour)}:${two(picked.minute)}');
    }
  }

  Future<void> _pickCurrency() async {
    final String? picked = await showCurrencyPicker(
      context,
      selected: _currency,
    );
    if (picked != null && mounted) {
      setState(() => _currency = picked);
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _conflictReloaded = false;
      _dateError = _date == null ? l10n.receiptDateRequired : null;
    });
    final bool valid = _form.currentState?.validate() ?? false;
    if (!valid || _date == null) {
      return;
    }
    final ReceiptDetail r = widget.receipt;
    final ReceiptReviewInput input = ReceiptReviewInput(
      receiptDate: _date!,
      total: _amount(_total) ?? '',
      version: r.version,
      merchantName: _text(_merchant),
      receiptTime: _time,
      currency: _currency,
      subtotal: _amount(_subtotal),
      tax: _amount(_tax),
      tip: _amount(_tip),
      discount: _amount(_discount),
      receiptNumber: _text(_number),
      paymentHint: _text(_payment),
      lineItems: <ReceiptLineItemInput>[
        for (final _LineDraft l in _lines)
          if (_text(l.description) != null ||
              _amount(l.amount) != null ||
              _amount(l.unitPrice) != null)
            ReceiptLineItemInput(
              description: _text(l.description),
              quantity: _text(l.quantity),
              unitPrice: _amount(l.unitPrice),
              amount: _amount(l.amount),
              tax: _amount(l.tax),
            ),
      ],
    );
    try {
      await ref.read(receiptsApiProvider).review(r.id, input);
      ref.financeChanged();
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.receiptReviewSaved);
      leaveToReceipt(context, r.id);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(receiptProvider(r.id));
        setState(() => _conflictReloaded = true);
        return;
      }
      // Linked, discarded or being read elsewhere: reload (the screen then
      // explains that the details can't be changed now).
      if (receiptChangedUnderneath(error)) {
        ref.invalidate(receiptProvider(r.id));
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    final String? currency = _currency;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.receiptReviewTitle)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            Text(l10n.receiptReviewIntro),
            const SizedBox(height: Insets.md),
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
            TextFormField(
              controller: _merchant,
              maxLength: ReceiptReviewInput.merchantNameMaxLength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.receiptMerchant,
                helperText: l10n.receiptMerchantHelp,
                errorText: _errors['merchant'],
              ),
            ),
            const SizedBox(height: Insets.sm),
            DateSelectorField(
              label: l10n.receiptDate,
              value: _date,
              emptyLabel: l10n.receiptDateChoose,
              lastDate: DateTime.now(),
              errorText: _dateError ?? _errors['date'],
              onChanged: (String? d) => setState(() {
                _date = d;
                _dateError = null;
              }),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.receiptTime,
              icon: Icons.schedule,
              value: _time,
              placeholder: l10n.receiptTimeNone,
              errorText: _errors['time'],
              onTap: _pickTime,
              onClear: _time == null
                  ? null
                  : () => setState(() => _time = null),
            ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.receiptCurrency,
              icon: Icons.currency_exchange,
              value: currency,
              helperText: l10n.receiptCurrencyHelp,
              errorText: _errors['currency'],
              onTap: _pickCurrency,
            ),
            const SizedBox(height: Insets.md),
            AmountField(
              controller: _total,
              label: l10n.receiptTotal,
              currency: currency,
              errorText: _errors['total'],
            ),
            const SizedBox(height: Insets.md),
            FormSectionHeader(l10n.receiptBreakdownTitle),
            Text(
              l10n.receiptBreakdownHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.sm),
            AmountField(
              controller: _subtotal,
              label: l10n.receiptSubtotal,
              currency: currency,
              isRequired: false,
              allowZero: true,
              errorText: _errors['subtotal'],
            ),
            const SizedBox(height: Insets.sm),
            AmountField(
              controller: _tax,
              label: l10n.receiptTax,
              currency: currency,
              isRequired: false,
              allowZero: true,
              errorText: _errors['tax'],
            ),
            const SizedBox(height: Insets.sm),
            AmountField(
              controller: _tip,
              label: l10n.receiptTip,
              currency: currency,
              isRequired: false,
              allowZero: true,
              errorText: _errors['tip'],
            ),
            const SizedBox(height: Insets.sm),
            AmountField(
              controller: _discount,
              label: l10n.receiptDiscount,
              currency: currency,
              isRequired: false,
              allowZero: true,
              errorText: _errors['discount'],
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _number,
              maxLength: ReceiptReviewInput.receiptNumberMaxLength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.receiptNumber,
                errorText: _errors['number'],
              ),
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _payment,
              maxLength: ReceiptReviewInput.paymentHintMaxLength,
              decoration: InputDecoration(
                labelText: l10n.receiptPaymentHint,
                helperText: l10n.receiptPaymentMethodHelp,
                helperMaxLines: 3,
                errorText: _errors['payment'],
              ),
            ),
            const SizedBox(height: Insets.md),
            FormSectionHeader(l10n.receiptLineItemsTitle),
            if (_errors['lines'] case final String linesError)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  linesError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            for (int i = 0; i < _lines.length; i++)
              _LineEditor(
                key: ObjectKey(_lines[i]),
                index: i + 1,
                draft: _lines[i],
                currency: currency,
                onRemove: () => setState(() {
                  _lines.removeAt(i).dispose();
                }),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _lines.add(_LineDraft())),
                icon: const Icon(Icons.add),
                label: Text(l10n.receiptAddLineItem),
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(label: l10n.receiptReviewSave, onPressed: _submit),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.index,
    required this.draft,
    required this.currency,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _LineDraft draft;
  final String? currency;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.receiptLineItemTitle(index),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.receiptRemoveLineItem(index),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
              ],
            ),
            TextFormField(
              controller: draft.description,
              maxLength: ReceiptLineItemInput.descriptionMaxLength,
              decoration: InputDecoration(
                labelText: l10n.receiptLineDescription,
              ),
            ),
            TextFormField(
              controller: draft.quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.receiptQuantity),
              validator: (String? v) {
                final String text = (v ?? '').trim();
                if (text.isEmpty ||
                    RegExp(ReceiptLineItemInput.quantityPattern)
                        .hasMatch(text)) {
                  return null;
                }
                return l10n.receiptQuantityInvalid;
              },
            ),
            const SizedBox(height: Insets.sm),
            AmountField(
              controller: draft.unitPrice,
              label: l10n.receiptUnitPrice,
              currency: currency,
              isRequired: false,
              allowZero: true,
            ),
            const SizedBox(height: Insets.sm),
            AmountField(
              controller: draft.amount,
              label: l10n.receiptLineAmount,
              currency: currency,
              isRequired: false,
              allowZero: true,
            ),
            const SizedBox(height: Insets.sm),
            AmountField(
              controller: draft.tax,
              label: l10n.receiptLineTax,
              currency: currency,
              isRequired: false,
              allowZero: true,
            ),
          ],
        ),
      ),
    );
  }
}
