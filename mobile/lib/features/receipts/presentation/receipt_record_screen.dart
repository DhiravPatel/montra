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
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/selection_sheet.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/label_pickers.dart';
import 'package:montra_mobile/features/receipts/application/receipts_providers.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_display.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

/// Records a reviewed receipt as a new expense
/// (`POST /receipts/{id}/create-transaction`, with an Idempotency-Key so a
/// retry after a lost connection can never record it twice). The amount,
/// date and merchant come from the values the user reviewed by hand (the
/// server records nothing else); the user picks the account (in the receipt
/// currency) and, optionally, a category.
class ReceiptRecordScreen extends ConsumerWidget {
  /// Creates the form for [receiptId].
  const ReceiptRecordScreen({required this.receiptId, super.key});

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
      data: (ReceiptView view) {
        final ReceiptDetail r = view.detail;
        final ReceiptExtractionDto? e = r.current;
        final String status = r.status.json;
        if (!canRecordReceipt(status, r.transactionId, e) ||
            e == null ||
            e.total == null ||
            e.receiptDate == null) {
          // Values read automatically are checked by hand first.
          final bool needsCheck =
              canLinkReceipt(status, r.transactionId) && !isManualReview(e);
          return Scaffold(
            appBar: AppBar(title: Text(l10n.receiptRecordTitle)),
            body: MessageStateView(
              icon: Icons.info_outline,
              title: l10n.receiptRecordUnavailable,
              body: needsCheck
                  ? l10n.receiptHelpCheckManual
                  : receiptStatusHelp(l10n, status),
              action: canReviewReceipt(status)
                  ? FilledButton.icon(
                      onPressed: () => context.pushReplacement(
                        AppRoutes.reviewReceipt(r.id),
                      ),
                      icon: const Icon(Icons.edit_note),
                      label: Text(
                        e == null
                            ? l10n.receiptEnterDetails
                            : l10n.receiptCheckDetails,
                      ),
                    )
                  : null,
            ),
          );
        }
        return _RecordForm(receipt: r, values: e);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.receiptRecordTitle)),
        body: const LoadingStateView(),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: Text(l10n.receiptRecordTitle)),
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(receiptProvider(receiptId)),
        ),
      ),
    );
  }
}

class _RecordForm extends ConsumerStatefulWidget {
  const _RecordForm({required this.receipt, required this.values});

  final ReceiptDetail receipt;
  final ReceiptExtractionDto values;

  @override
  ConsumerState<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends ConsumerState<_RecordForm> {
  final TextEditingController _description = TextEditingController();
  final IdempotentSubmission _submission = IdempotentSubmission();
  String? _accountId;
  String? _categoryId;
  String? _accountError;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'account_id': 'account',
    'category_id': 'category',
    'description': 'description',
  };

  String get _currency => widget.values.total!.currency;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickAccount() async {
    final AccountDto? picked = await showAccountPicker(
      context,
      selectedId: _accountId,
      currency: _currency,
      title: context.l10n.receiptRecordAccount,
    );
    if (picked != null && mounted) {
      setState(() {
        _accountId = picked.id;
        _accountError = null;
      });
    }
  }

  Future<void> _pickCategory() async {
    final Picked<CategoryDto>? picked = await showCategoryPicker(
      context,
      kind: CategoryKindFilter.spending,
      selectedId: _categoryId,
    );
    if (picked != null && mounted) {
      setState(() => _categoryId = picked.value?.id);
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _errors = ServerFormErrors.none;
      _accountError = _accountId == null ? l10n.receiptAccountRequired : null;
    });
    final String? accountId = _accountId;
    if (accountId == null) {
      return;
    }
    final String description = _description.text.trim();
    final ReceiptCreateTransactionInput input = ReceiptCreateTransactionInput(
      accountId: accountId,
      categoryId: _categoryId,
      description: description.isEmpty ? null : description,
    );
    try {
      await ref
          .read(receiptsApiProvider)
          .createTransaction(
            widget.receipt.id,
            input,
            key: _submission.keyFor(input.toJson()),
          );
      _submission.reset();
      ref.financeChanged();
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.receiptRecorded);
      leaveToReceipt(context, widget.receipt.id);
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _submission.reset();
      }
      // Linked, discarded or changed elsewhere: reload; the screen then
      // explains why it can't be recorded.
      if (receiptChangedUnderneath(error)) {
        ref.invalidate(receiptProvider(widget.receipt.id));
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
    final String locale = Localizations.localeOf(context).toString();
    final ReceiptExtractionDto e = widget.values;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final AccountDto? account = _accountId == null
        ? null
        : accounts[_accountId];
    final CategoryDto? category = _categoryId == null
        ? null
        : categories[_categoryId];
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.receiptRecordTitle)),
      body: ScrollableContent(
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    receiptTitle(l10n, e),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(LocalDates.display(e.receiptDate!, locale: locale)),
                  const SizedBox(height: Insets.xs),
                  MoneyText(
                    e.total!,
                    flow: MoneyFlow.outflow,
                    label: l10n.receiptTotal,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(l10n.receiptRecordIntro),
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
            label: l10n.receiptRecordAccount,
            icon: Icons.account_balance_wallet_outlined,
            value: account?.name,
            placeholder: l10n.receiptChooseAccount,
            helperText: l10n.receiptRecordAccountHelp(_currency),
            errorText: _accountError ?? _errors['account'],
            onTap: _pickAccount,
          ),
          const SizedBox(height: Insets.md),
          SelectorField(
            label: l10n.receiptRecordCategory,
            icon: Icons.category_outlined,
            value: category == null ? null : categoryName(l10n, category),
            placeholder: l10n.categoryNone,
            errorText: _errors['category'],
            onTap: _pickCategory,
            onClear: _categoryId == null
                ? null
                : () => setState(() => _categoryId = null),
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _description,
            maxLength: ReceiptCreateTransactionInput.descriptionMaxLength,
            decoration: InputDecoration(
              labelText: l10n.receiptRecordDescription,
              helperText: l10n.receiptRecordDescriptionHelp,
              errorText: _errors['description'],
            ),
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(label: l10n.receiptRecordSave, onPressed: _submit),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}
