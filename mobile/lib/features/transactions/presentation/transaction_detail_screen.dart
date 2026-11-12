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
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/file_size.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/payment_methods/application/payment_methods_providers.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';
import 'package:montra_mobile/features/transactions/application/transactions_providers.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';

enum _TxAction { edit, duplicate, refund, reimburse, delete, restore }

/// One transaction: amount and direction, every recorded field, links to
/// the transfer or original it belongs to, attachments and the audit
/// history. Actions: edit, duplicate, refund/reimburse, delete (void) and
/// restore — each confirmed when destructive.
class TransactionDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [transactionId].
  const TransactionDetailScreen({required this.transactionId, super.key});

  /// The transaction.
  final String transactionId;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  final IdempotentSubmission _duplicateKey = IdempotentSubmission();
  bool _busy = false;

  TransactionDetailController get _controller =>
      ref.read(transactionDetailProvider(widget.transactionId).notifier);

  Future<void> _run(_TxAction action, TransactionDto t) async {
    switch (action) {
      case _TxAction.edit:
        await context.push(AppRoutes.editTransaction(t.id));
      case _TxAction.refund:
        await context.push(AppRoutes.refundTransaction(t.id));
      case _TxAction.reimburse:
        await context.push(
          AppRoutes.refundTransaction(t.id, reimbursement: true),
        );
      case _TxAction.duplicate:
        await _duplicate(t);
      case _TxAction.delete:
        await _delete(t);
      case _TxAction.restore:
        await _guarded(_controller.restore, context.l10n.transactionRestored);
    }
  }

  Future<void> _guarded(Future<void> Function() action, String done) async {
    final AppLocalizations l10n = context.l10n;
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        showSnack(context, done);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(TransactionDto t) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.transactionDeleteConfirmTitle,
      body: t.transferId != null
          ? l10n.transactionDeleteTransferBody
          : l10n.transactionDeleteConfirmBody,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (confirmed && mounted) {
      await _guarded(_controller.delete, l10n.transactionDeleted);
    }
  }

  Future<void> _duplicate(TransactionDto t) async {
    final AppLocalizations l10n = context.l10n;
    final DateTime today = LocalDates.today();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      helpText: l10n.duplicateDateTitle,
      confirmText: l10n.duplicateConfirm,
    );
    if (date == null || !mounted) {
      return;
    }
    final String localDate = LocalDates.format(date);
    final String key = _duplicateKey.keyFor(<String, Object?>{
      'source': t.id,
      'local_date': localDate,
    });
    final GoRouter router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final CreateResult result = await _controller.duplicate(
        localDate: localDate,
        key: key,
      );
      _duplicateKey.reset();
      if (mounted) {
        showSnack(context, l10n.duplicateCreated);
        await router.push(AppRoutes.transactionDetail(result.transaction.id));
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _duplicateKey.reset();
      }
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<TransactionDto> tx = ref.watch(
      transactionDetailProvider(widget.transactionId),
    );
    final TransactionDto? t = tx.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t == null
              ? l10n.transactionDetailTitle
              : transactionTypeLabel(l10n, t.typeValue),
        ),
        bottom: _busy || (tx.isLoading && tx.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[if (t != null) _menu(context, t)],
      ),
      body: AsyncValueView<TransactionDto>(
        value: tx,
        onRetry: () =>
            ref.invalidate(transactionDetailProvider(widget.transactionId)),
        data: (TransactionDto t) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(transactionDetailProvider(t.id))
              ..invalidate(transactionAuditProvider(t.id))
              ..invalidate(transactionAttachmentsProvider(t.id));
            try {
              await ref.read(transactionDetailProvider(t.id).future);
            } on Object {
              // Shown by the screen state.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(Insets.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              _Header(transaction: t),
              if (t.status == TransactionDtoStatus.voided) ...<Widget>[
                const SizedBox(height: Insets.md),
                NoticeBanner(
                  tone: NoticeTone.warning,
                  message: l10n.transactionDeletedNotice,
                  action: t.owned
                      ? OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(_TxAction.restore, t),
                          icon: const Icon(Icons.restore),
                          label: Text(l10n.actionRestore),
                        )
                      : null,
                ),
              ],
              if (!t.owned) ...<Widget>[
                const SizedBox(height: Insets.md),
                NoticeBanner(message: l10n.transactionSharedReadOnly),
              ],
              const SizedBox(height: Insets.md),
              _Links(transaction: t),
              _Details(transaction: t),
              const SizedBox(height: Insets.md),
              _Attachments(transaction: t),
              const SizedBox(height: Insets.md),
              _History(transaction: t),
              const SizedBox(height: Insets.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, TransactionDto t) {
    final AppLocalizations l10n = context.l10n;
    final List<PopupMenuEntry<_TxAction>> items = <PopupMenuEntry<_TxAction>>[
      if (isEditable(t))
        PopupMenuItem<_TxAction>(
          value: _TxAction.edit,
          child: Text(l10n.actionEdit),
        ),
      if (canDuplicate(t))
        PopupMenuItem<_TxAction>(
          value: _TxAction.duplicate,
          child: Text(l10n.duplicateAction),
        ),
      if (canRefund(t)) ...<PopupMenuEntry<_TxAction>>[
        PopupMenuItem<_TxAction>(
          value: _TxAction.refund,
          child: Text(l10n.refundAction),
        ),
        PopupMenuItem<_TxAction>(
          value: _TxAction.reimburse,
          child: Text(l10n.reimbursementAction),
        ),
      ],
      if (isDeletable(t))
        PopupMenuItem<_TxAction>(
          value: _TxAction.delete,
          child: Text(l10n.actionDelete),
        ),
      if (t.owned && t.status == TransactionDtoStatus.voided)
        PopupMenuItem<_TxAction>(
          value: _TxAction.restore,
          child: Text(l10n.actionRestore),
        ),
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<_TxAction>(
      tooltip: l10n.actionMore,
      enabled: !_busy,
      onSelected: (_TxAction a) => _run(a, t),
      itemBuilder: (BuildContext context) => items,
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.transaction});

  final TransactionDto transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final TransactionDto t = transaction;
    final String? category = t.category == null
        ? null
        : categoryRefDisplay(l10n, t.category!);
    final bool voided = t.status == TransactionDtoStatus.voided;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              transactionTitle(l10n, t, categoryName: category),
              style: theme.textTheme.titleLarge?.copyWith(
                decoration: voided ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: Insets.sm),
            MoneyText(
              t.amount,
              flow: flowOf(t),
              colored: true,
              style: theme.textTheme.headlineMedium,
            ),
            if (t.personalShare case final Money share) ...<Widget>[
              const SizedBox(height: Insets.xs),
              Text(
                l10n.personalShareLabel(formatMoney(context, ref, share)),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                StatusLabel(
                  text: transactionTypeLabel(l10n, t.typeValue),
                  icon: transactionTypeIcon(t.typeValue),
                ),
                StatusLabel(
                  text: transactionStatusLabel(l10n, t.status),
                  tone: voided
                      ? StatusTone.caution
                      : (t.status == TransactionDtoStatus.posted
                            ? StatusTone.positive
                            : StatusTone.neutral),
                ),
                if (t.refundedTotal.amountMinor > 0)
                  StatusLabel(
                    text: l10n.txRefundedAmount(
                      formatMoney(context, ref, t.refundedTotal),
                    ),
                    icon: Icons.undo,
                  ),
                if (t.isCorrection)
                  StatusLabel(
                    text: l10n.correctionLabel,
                    icon: Icons.build_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.transaction});

  final TransactionDto transaction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TransactionDto t = transaction;
    final List<Widget> links = <Widget>[
      if (t.transferId case final String transferId)
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: Text(l10n.partOfTransfer),
          subtitle: Text(l10n.partOfTransferHelp),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.transferDetail(transferId)),
        ),
      if (t.originalTransactionId case final String originalId)
        ListTile(
          leading: const Icon(Icons.link),
          title: Text(
            t.typeValue == TransactionDtoType.reimbursement
                ? l10n.reimbursementOf
                : l10n.refundOf,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.transactionDetail(originalId)),
        ),
      if (t.receiptId case final String receiptId)
        ListTile(
          leading: const Icon(Icons.receipt_outlined),
          title: Text(l10n.attachmentReceiptLink),
          subtitle: Text(l10n.attachmentReceiptLinkHelp),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.receiptDetail(receiptId)),
        ),
      if (groupRecordLocation(t) case final String location)
        ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: Text(l10n.groupLinkedRecord),
          subtitle: Text(l10n.groupLinkedRecordHelp),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(location),
        ),
    ];
    if (links.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Card(child: Column(children: links)),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.transaction});

  final TransactionDto transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final TransactionDto t = transaction;
    final Map<String, PaymentMethodDto> methods = ref.watch(
      paymentMethodIndexProvider,
    );
    final List<TagRef> tags = t.tags;
    return SectionCard(
      title: l10n.accountDetailsTitle,
      children: <Widget>[
        DetailRow(
          label: l10n.dateLabel,
          value: LocalDates.display(t.localDate, locale: locale),
        ),
        DetailRow(
          label: l10n.accountFieldLabel,
          value: t.accountName,
          onTap: () => context.push(AppRoutes.accountDetail(t.accountId)),
        ),
        DetailRow(
          label: l10n.categoryFieldLabel,
          value: t.category == null
              ? l10n.categoryUncategorized
              : categoryRefDisplay(l10n, t.category!),
        ),
        if (t.merchant case final MerchantRef m)
          DetailRow(label: l10n.merchantFieldLabel, value: m.name),
        if (t.paymentMethodId case final String pm)
          DetailRow(
            label: l10n.paymentMethodFieldLabel,
            value: methods[pm]?.label ?? l10n.paymentAccountUnknown,
          ),
        if (tags.isNotEmpty)
          DetailRow(
            label: l10n.tagsLabel,
            value: tags.map((TagRef tag) => tag.name).join(', '),
          ),
        if (t.description case final String d when d.isNotEmpty)
          DetailRow(label: l10n.descriptionLabel, value: d),
        if (t.notes case final String n when n.isNotEmpty)
          DetailRow(label: l10n.notesLabel, value: n),
        if (t.locationText case final String loc when loc.isNotEmpty)
          DetailRow(label: l10n.locationLabel, value: loc),
        if (t.originalAmount case final Money original)
          DetailRow(
            label: l10n.originalAmountLabel,
            semanticsValue: formatMoney(context, ref, original),
            child: MoneyText(original),
          ),
        if (t.fxRate case final String rate)
          DetailRow(
            label: l10n.fxRateLabel,
            value: t.fxRateSource == null
                ? rate
                : l10n.rateWithSource(rate, t.fxRateSource!),
          ),
        DetailRow(
          label: l10n.sourceLabel,
          value: transactionSourceLabel(l10n, t.source),
        ),
        DetailRow(
          label: l10n.reconciliationLabel,
          value: reconciliationLabel(l10n, t.reconciliationState),
        ),
        DetailRow(
          label: l10n.createdLabel,
          value: formatDateTime(t.createdAt, locale: locale),
        ),
        if (t.updatedAt != t.createdAt)
          DetailRow(
            label: l10n.updatedLabel,
            value: formatDateTime(t.updatedAt, locale: locale),
          ),
      ],
    );
  }
}

class _Attachments extends ConsumerStatefulWidget {
  const _Attachments({required this.transaction});

  final TransactionDto transaction;

  @override
  ConsumerState<_Attachments> createState() => _AttachmentsState();
}

class _AttachmentsState extends ConsumerState<_Attachments> {
  String? _removing;
  bool _adding = false;

  Future<void> _add() async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    if (_adding) {
      return;
    }
    final PickedFile? picked = await pickFileFor(
      context,
      ref,
      purpose: UploadPurpose.transactionAttachment,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _adding = true);
    try {
      final FileDto? file = await uploadWithProgress(
        context,
        file: picked,
        purpose: UploadPurpose.transactionAttachment,
      );
      if (file == null || !mounted) {
        return;
      }
      await ref
          .read(transactionsApiProvider)
          .attach(widget.transaction.id, file.id);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.attachmentAdded);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _detach(AttachmentDto a) async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    final String name = a.filename ?? l10n.attachmentUnnamed;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.attachmentRemoveConfirmTitle,
      body: l10n.attachmentRemoveConfirmBody(name),
      confirmLabel: l10n.attachmentRemove,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _removing = a.fileId);
    try {
      await ref
          .read(transactionsApiProvider)
          .detach(widget.transaction.id, a.fileId);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.attachmentRemoved);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _removing = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final TransactionDto t = widget.transaction;
    final AsyncValue<List<AttachmentDto>> files = ref.watch(
      transactionAttachmentsProvider(t.id),
    );
    final bool canChange = t.owned && t.status != TransactionDtoStatus.voided;
    return SectionCard(
      title: l10n.attachmentsTitle,
      trailing: canChange
          ? TextButton.icon(
              onPressed: _adding || _removing != null ? null : _add,
              icon: _adding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
              label: Text(l10n.attachmentAdd),
            )
          : null,
      children: <Widget>[
        if (files.hasError && !files.isLoading)
          SizedBox(
            height: 260,
            child: ErrorStateView(
              error: files.error!,
              onRetry: () =>
                  ref.invalidate(transactionAttachmentsProvider(t.id)),
            ),
          )
        else if (files.value case final List<AttachmentDto> list)
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(
                canChange ? l10n.attachmentsEmptyAdd : l10n.attachmentsEmpty,
              ),
            )
          else
            for (final AttachmentDto a in list)
              ListTile(
                onTap: () => openPrivateFile(
                  context,
                  fileId: a.fileId,
                  name: a.filename ?? l10n.attachmentUnnamed,
                ),
                leading: ExcludeSemantics(
                  child: Icon(
                    (a.contentType ?? '').startsWith('image/')
                        ? Icons.image_outlined
                        : Icons.description_outlined,
                  ),
                ),
                title: Text(a.filename ?? l10n.attachmentUnnamed),
                subtitle: Text(
                  <String>[
                    ?a.contentType,
                    if (a.sizeBytes != null) formatFileSize(l10n, a.sizeBytes),
                    l10n.attachedOn(
                      formatDateTime(a.attachedAt, locale: locale),
                    ),
                  ].join(' · '),
                ),
                trailing: !canChange
                    ? const Icon(Icons.open_in_new)
                    : _removing == a.fileId
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: l10n.attachmentRemoveLabel(
                          a.filename ?? l10n.attachmentUnnamed,
                        ),
                        icon: const Icon(Icons.link_off),
                        onPressed: _removing == null && !_adding
                            ? () => _detach(a)
                            : null,
                      ),
              )
        else
          const SizedBox(height: 96, child: LoadingStateView()),
      ],
    );
  }
}

/// Localized audit action.
String auditActionLabel(AppLocalizations l10n, AuditEventDtoAction action) =>
    switch (action) {
      AuditEventDtoAction.created => l10n.auditCreated,
      AuditEventDtoAction.updated => l10n.auditUpdated,
      AuditEventDtoAction.voided => l10n.auditVoided,
      AuditEventDtoAction.restored => l10n.auditRestored,
      AuditEventDtoAction.refundAdded => l10n.auditRefundAdded,
      AuditEventDtoAction.reimbursementAdded => l10n.auditReimbursementAdded,
      AuditEventDtoAction.reconciled => l10n.auditReconciled,
      AuditEventDtoAction.unreconciled => l10n.auditUnreconciled,
      AuditEventDtoAction.attachmentAdded => l10n.auditAttachmentAdded,
      AuditEventDtoAction.attachmentRemoved => l10n.auditAttachmentRemoved,
      AuditEventDtoAction.bulkUpdated => l10n.auditBulkUpdated,
      AuditEventDtoAction.duplicated => l10n.auditDuplicated,
      AuditEventDtoAction.imported => l10n.auditImported,
      AuditEventDtoAction.ruleCategorized => l10n.auditRuleCategorized,
      AuditEventDtoAction.receiptLinked => l10n.auditReceiptLinked,
      AuditEventDtoAction.tagsChanged => l10n.auditTagsChanged,
      AuditEventDtoAction.unrecognized => l10n.auditOther,
    };

/// Who made an audited change.
String auditActorLabel(AppLocalizations l10n, AuditEventDtoActorKind actor) =>
    switch (actor) {
      AuditEventDtoActorKind.user => l10n.auditActorYou,
      AuditEventDtoActorKind.importValue => l10n.auditActorImport,
      AuditEventDtoActorKind.recurring => l10n.auditActorRecurring,
      AuditEventDtoActorKind.integration => l10n.auditActorIntegration,
      AuditEventDtoActorKind.system ||
      AuditEventDtoActorKind.unrecognized => l10n.auditActorMontra,
    };

/// Localized name of a changed field in an audit entry.
String auditFieldLabel(AppLocalizations l10n, String key) => switch (key) {
  'amount_minor' => l10n.amountLabel,
  'account_id' => l10n.accountFieldLabel,
  'local_date' => l10n.dateLabel,
  'status' => l10n.statusLabel,
  'category_id' => l10n.categoryFieldLabel,
  'merchant_id' => l10n.merchantFieldLabel,
  'payment_method_id' => l10n.paymentMethodFieldLabel,
  'description' => l10n.descriptionLabel,
  'notes_changed' => l10n.notesLabel,
  'original_amount_minor' => l10n.originalAmountLabel,
  'tags_added' => l10n.auditTagsAdded,
  'tags_removed' => l10n.auditTagsRemoved,
  _ => key.replaceAll('_', ' '),
};

/// Readable lines for an audit entry's `changes` (the contract leaves it
/// untyped). Amounts are minor units of the transaction's currency and are
/// formatted, never recomputed.
List<String> auditChangeLines(
  AppLocalizations l10n,
  AuditEventDto event, {
  required String currency,
  required String numberLocale,
  required String dateLocale,
}) {
  final Object? changes = event.changes;
  if (changes is! Map<String, Object?>) {
    return const <String>[];
  }
  String money(Object? minor) {
    if (minor is! int) {
      return '';
    }
    try {
      return formatMoneyText(
        Money(
          amount: MoneyFormatter.decimalFromMinorUnits(minor, currency),
          amountMinor: minor,
          currency: currency,
        ),
        numberLocale,
      );
    } on FormatException {
      return '$minor';
    }
  }

  String value(String key, Object? v) => switch (key) {
    'amount_minor' || 'original_amount_minor' => money(v),
    'local_date' =>
      v is String ? LocalDates.display(v, locale: dateLocale) : '',
    'status' =>
      v is String
          ? transactionStatusLabel(l10n, TransactionDtoStatus.fromJson(v))
          : '',
    _ => '',
  };

  final List<String> lines = <String>[];
  if (event.action == AuditEventDtoAction.refundAdded ||
      event.action == AuditEventDtoAction.reimbursementAdded) {
    final String amount = money(changes['amount_minor']);
    if (amount.isNotEmpty) {
      lines.add(l10n.auditLinkedAmount(amount));
    }
    return lines;
  }
  if (event.action == AuditEventDtoAction.duplicated ||
      event.action == AuditEventDtoAction.created) {
    return lines;
  }
  for (final MapEntry<String, Object?> e in changes.entries) {
    final String label = auditFieldLabel(l10n, e.key);
    final Object? change = e.value;
    if (change is Map<String, Object?> &&
        change.containsKey('from') &&
        change.containsKey('to')) {
      final String from = value(e.key, change['from']);
      final String to = value(e.key, change['to']);
      lines.add(
        from.isNotEmpty && to.isNotEmpty
            ? l10n.auditChangedFromTo(label, from, to)
            : l10n.auditChanged(label),
      );
    } else if (e.key != 'reason' && e.key != 'previous_status') {
      lines.add(l10n.auditChanged(label));
    }
  }
  return lines;
}

class _History extends ConsumerWidget {
  const _History({required this.transaction});

  final TransactionDto transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String dateLocale = Localizations.localeOf(context).toString();
    final String numberLocale = numberLocaleOf(context, ref);
    final TransactionDto t = transaction;
    final AsyncValue<List<AuditEventDto>> audit = ref.watch(
      transactionAuditProvider(t.id),
    );
    return SectionCard(
      title: l10n.historyTitle,
      children: <Widget>[
        if (audit.hasError && !audit.isLoading)
          SizedBox(
            height: 260,
            child: ErrorStateView(
              error: audit.error!,
              onRetry: () => ref.invalidate(transactionAuditProvider(t.id)),
            ),
          )
        else if (audit.value case final List<AuditEventDto> events)
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(l10n.historyEmpty),
            )
          else
            for (final AuditEventDto e in events.reversed)
              ListTile(
                leading: const ExcludeSemantics(child: Icon(Icons.history)),
                title: Text(auditActionLabel(l10n, e.action)),
                subtitle: Text(
                  <String>[
                    l10n.auditWhenWho(
                      formatDateTime(e.createdAt, locale: dateLocale),
                      auditActorLabel(l10n, e.actorKind),
                    ),
                    ...auditChangeLines(
                      l10n,
                      e,
                      currency: t.amount.currency,
                      numberLocale: numberLocale,
                      dateLocale: dateLocale,
                    ),
                  ].join('\n'),
                ),
              )
        else
          const SizedBox(height: 96, child: LoadingStateView()),
      ],
    );
  }
}

/// Where a transaction linked to a group expense or settlement leads: that
/// expense or settlement in its group (`group_id` is sent while the user
/// can still see the group), otherwise the groups list. Null when the
/// transaction is not linked to a group.
String? groupRecordLocation(TransactionDto t) {
  final String? expenseId = t.groupExpenseId;
  final String? settlementId = t.settlementId;
  if (expenseId == null && settlementId == null) {
    return null;
  }
  final String? groupId = t.groupId;
  if (groupId == null || groupId.isEmpty) {
    return AppRoutes.groups;
  }
  if (expenseId != null) {
    return AppRoutes.groupExpenseDetail(groupId, expenseId);
  }
  return AppRoutes.groupSettlementDetail(groupId, settlementId!);
}
