import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/receipts/application/receipts_providers.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_display.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

enum _ReceiptAction { review, match, record, open, unlink, discard, restore }

/// One receipt: its pages (photos shown in the app, PDFs opened elsewhere),
/// the details the user entered, duplicate warnings, the linked transaction
/// and the version history. Next steps depend on the status: enter the
/// details, link an existing expense or record a new one (only values the
/// user reviewed by hand), unlink, discard and restore. When the server
/// says the receipt changed underneath (linked, discarded, edited
/// elsewhere), the reason is shown and the receipt is reloaded.
class ReceiptDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [receiptId].
  const ReceiptDetailScreen({required this.receiptId, super.key});

  /// The receipt.
  final String receiptId;

  @override
  ConsumerState<ReceiptDetailScreen> createState() =>
      _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<ReceiptDetailScreen> {
  bool _busy = false;

  Future<void> _run(_ReceiptAction action, ReceiptDetail r) async {
    final AppLocalizations l10n = context.l10n;
    switch (action) {
      case _ReceiptAction.review:
        await context.push(AppRoutes.reviewReceipt(r.id));
        return;
      case _ReceiptAction.match:
        await context.push(AppRoutes.matchReceipt(r.id));
        return;
      case _ReceiptAction.record:
        await context.push(AppRoutes.recordReceipt(r.id));
        return;
      case _ReceiptAction.open:
        final String? txId = r.transactionId;
        if (txId != null) {
          await context.push(AppRoutes.transactionDetail(txId));
        }
        return;
      case _ReceiptAction.unlink:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.receiptUnlinkConfirmTitle,
          body: l10n.receiptUnlinkConfirmBody,
          confirmLabel: l10n.receiptUnlink,
        );
        if (ok && mounted) {
          await _write(
            () => ref.read(receiptsApiProvider).unlink(r.id),
            l10n.receiptUnlinked,
          );
        }
        return;
      case _ReceiptAction.discard:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.receiptDiscardConfirmTitle,
          body: r.transactionId == null
              ? l10n.receiptDiscardBodyRestorable
              : l10n.receiptDiscardLinkedBodyRestorable,
          confirmLabel: l10n.receiptDiscard,
          destructive: true,
        );
        if (ok && mounted) {
          await _write(
            () =>
                ref.read(receiptsApiProvider).discard(r.id, version: r.version),
            l10n.receiptDiscarded,
          );
        }
        return;
      case _ReceiptAction.restore:
        await _write(
          () => ref.read(receiptsApiProvider).restore(r.id, version: r.version),
          l10n.receiptRestored,
        );
        return;
    }
  }

  Future<void> _write(Future<ReceiptDto> Function() call, String done) async {
    final AppLocalizations l10n = context.l10n;
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await call();
      ref.financeChanged();
      if (mounted) {
        showSnack(context, done);
      }
    } on ApiException catch (error) {
      if (receiptChangedUnderneath(error)) {
        ref.invalidate(receiptProvider(widget.receiptId));
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

  /// An amount from a warning's values in the user's notation.
  String _money(String amount, String currency) {
    try {
      return MoneyFormatter.formatAmount(
        amount,
        currency,
        locale: numberLocaleOf(context, ref),
      );
    } on FormatException {
      return '$amount $currency';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ReceiptView> receipt = ref.watch(
      receiptProvider(widget.receiptId),
    );
    final ReceiptDetail? r = receipt.value?.detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          r == null ? l10n.receiptTitle : receiptTitle(l10n, r.current),
        ),
        bottom: _busy || (receipt.isLoading && receipt.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[if (r != null) _menu(r)],
      ),
      body: AsyncValueView<ReceiptView>(
        value: receipt,
        onRetry: () => ref.invalidate(receiptProvider(widget.receiptId)),
        data: _body,
      ),
    );
  }

  Widget _body(ReceiptView view) {
    final AppLocalizations l10n = context.l10n;
    final ReceiptDetail r = view.detail;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(receiptProvider(r.id));
        try {
          await ref.read(receiptProvider(r.id).future);
        } on Object {
          // Shown by the screen state.
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(Insets.md),
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _StatusCard(
            receipt: r,
            busy: _busy,
            onAction: (_ReceiptAction a) => _run(a, r),
          ),
          if (r.duplicateOfId case final String other) ...<Widget>[
            const SizedBox(height: Insets.md),
            NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.receiptDuplicateNotice,
              action: TextButton(
                onPressed: () => context.push(AppRoutes.receiptDetail(other)),
                child: Text(l10n.receiptOpenOther),
              ),
            ),
          ],
          for (final ReceiptWarning warning in view.warnings) ...<Widget>[
            const SizedBox(height: Insets.md),
            NoticeBanner(
              message: receiptWarningMessage(l10n, warning, money: _money),
            ),
          ],
          const SizedBox(height: Insets.md),
          _Pages(receipt: r),
          const SizedBox(height: Insets.md),
          _Values(receipt: r),
          if ((r.notes ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            SectionCard(
              title: l10n.receiptNotes,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.sm,
                  ),
                  child: Text(r.notes!.trim()),
                ),
              ],
            ),
          ],
          if (r.history.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            _History(receipt: r),
          ],
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }

  Widget _menu(ReceiptDetail r) {
    final AppLocalizations l10n = context.l10n;
    final String status = r.status.json;
    final List<PopupMenuEntry<_ReceiptAction>> items =
        <PopupMenuEntry<_ReceiptAction>>[
          if (canReviewReceipt(status))
            PopupMenuItem<_ReceiptAction>(
              value: _ReceiptAction.review,
              child: Text(
                r.current == null
                    ? l10n.receiptEnterDetails
                    : l10n.receiptEditDetails,
              ),
            ),
          if (canLinkReceipt(status, r.transactionId))
            PopupMenuItem<_ReceiptAction>(
              value: _ReceiptAction.match,
              child: Text(l10n.receiptMatchAction),
            ),
          if (canRecordReceipt(status, r.transactionId, r.current))
            PopupMenuItem<_ReceiptAction>(
              value: _ReceiptAction.record,
              child: Text(l10n.receiptRecordAction),
            ),
          if (r.transactionId != null)
            PopupMenuItem<_ReceiptAction>(
              value: _ReceiptAction.unlink,
              child: Text(l10n.receiptUnlink),
            ),
          if (status != 'discarded')
            PopupMenuItem<_ReceiptAction>(
              value: _ReceiptAction.discard,
              child: Text(l10n.receiptDiscard),
            ),
          if (status == 'discarded')
            PopupMenuItem<_ReceiptAction>(
              value: _ReceiptAction.restore,
              child: Text(l10n.receiptRestore),
            ),
        ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<_ReceiptAction>(
      tooltip: l10n.actionMore,
      enabled: !_busy,
      onSelected: (_ReceiptAction a) => _run(a, r),
      itemBuilder: (BuildContext context) => items,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.receipt,
    required this.busy,
    required this.onAction,
  });

  final ReceiptDetail receipt;
  final bool busy;
  final ValueChanged<_ReceiptAction> onAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ReceiptDetail r = receipt;
    final String status = r.status.json;
    final bool manual = isManualReview(r.current);
    final List<Widget> actions = <Widget>[
      if (canReviewReceipt(status) && (status != 'reviewed' || !manual))
        FilledButton.icon(
          onPressed: busy ? null : () => onAction(_ReceiptAction.review),
          icon: const Icon(Icons.edit_note),
          label: Text(
            r.current == null
                ? l10n.receiptEnterDetails
                : (status == 'reviewed'
                      ? l10n.receiptCheckDetails
                      : l10n.receiptEditDetails),
          ),
        ),
      if (canLinkReceipt(status, r.transactionId))
        (manual ? FilledButton.icon : OutlinedButton.icon)(
          onPressed: busy ? null : () => onAction(_ReceiptAction.match),
          icon: const Icon(Icons.link),
          label: Text(l10n.receiptMatchAction),
        ),
      if (canRecordReceipt(status, r.transactionId, r.current)) ...<Widget>[
        OutlinedButton.icon(
          onPressed: busy ? null : () => onAction(_ReceiptAction.record),
          icon: const Icon(Icons.add_card_outlined),
          label: Text(l10n.receiptRecordAction),
        ),
        TextButton.icon(
          onPressed: busy ? null : () => onAction(_ReceiptAction.review),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.receiptEditDetails),
        ),
      ],
      if (status == 'discarded')
        FilledButton.icon(
          onPressed: busy ? null : () => onAction(_ReceiptAction.restore),
          icon: const Icon(Icons.restore),
          label: Text(l10n.receiptRestore),
        ),
      if (r.transactionId != null) ...<Widget>[
        FilledButton.icon(
          onPressed: busy ? null : () => onAction(_ReceiptAction.open),
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.receiptOpenTransaction),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => onAction(_ReceiptAction.unlink),
          icon: const Icon(Icons.link_off),
          label: Text(l10n.receiptUnlink),
        ),
      ],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            StatusLabel(
              text: receiptStatusLabel(l10n, status),
              tone: receiptStatusTone(status),
              icon: receiptStatusIcon(status),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              status == 'reviewed' && !manual && r.transactionId == null
                  ? l10n.receiptHelpCheckManual
                  : receiptStatusHelp(l10n, status),
              style: theme.textTheme.bodyMedium,
            ),
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.md),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pages extends StatelessWidget {
  const _Pages({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ReceiptFile> files = receipt.files;
    return SectionCard(
      title: l10n.receiptPagesTitle,
      children: <Widget>[
        if (files.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(l10n.receiptNoPages),
          ),
        for (int i = 0; i < files.length; i++)
          ReceiptPagePreview(file: files[i], index: i + 1, count: files.length),
      ],
    );
  }
}

/// One receipt page: a photo is shown in the app (tap for full screen);
/// a PDF opens the viewer with Share and Save.
class ReceiptPagePreview extends ConsumerWidget {
  /// Creates the preview of page [index] of [count].
  const ReceiptPagePreview({
    required this.file,
    required this.index,
    required this.count,
    super.key,
  });

  /// The page.
  final ReceiptFile file;

  /// Page number (1-based).
  final int index;

  /// Number of pages.
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String label = l10n.receiptPageLabel(index, count);
    void open() => openPrivateFile(context, fileId: file.fileId, name: label);
    final bool image = (file.contentType ?? '').startsWith('image/');
    if (!image) {
      return ListTile(
        leading: const ExcludeSemantics(
          child: Icon(Icons.picture_as_pdf_outlined),
        ),
        title: Text(label),
        subtitle: Text(
          (file.contentType ?? '').contains('pdf')
              ? l10n.receiptPdfPage
              : l10n.receiptFilePage,
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: open,
      );
    }
    final AsyncValue<DownloadedFile> content = ref.watch(
      privateFileProvider(file.fileId),
    );
    final DownloadedFile? loaded = content.value;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (content.hasError && !content.isLoading)
            Row(
              children: <Widget>[
                Expanded(child: Text(describeError(l10n, content.error!))),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(privateFileProvider(file.fileId)),
                  child: Text(l10n.actionRetry),
                ),
              ],
            )
          else if (loaded == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.lg),
              child: Column(
                children: <Widget>[
                  const CircularProgressIndicator(),
                  const SizedBox(height: Insets.sm),
                  Text(l10n.fileDownloading, textAlign: TextAlign.center),
                ],
              ),
            )
          else
            InkWell(
              onTap: open,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: Image.memory(
                  loaded.bytes,
                  fit: BoxFit.contain,
                  semanticLabel: label,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? _,
                  ) => Text(l10n.receiptPreviewUnavailable),
                ),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: open,
              icon: const Icon(Icons.fullscreen),
              label: Text(l10n.receiptOpenPage(index)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Values extends StatelessWidget {
  const _Values({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ReceiptExtractionDto? e = receipt.current;
    if (e == null) {
      return SectionCard(
        title: l10n.receiptDetailsTitle,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(l10n.receiptNoDetails),
          ),
        ],
      );
    }
    Widget money(String label, Money? m) => m == null
        ? const SizedBox.shrink()
        : DetailRow(
            label: label,
            child: MoneyText(m, label: label),
          );
    return SectionCard(
      title: l10n.receiptDetailsTitle,
      children: <Widget>[
        if ((e.merchantName ?? '').isNotEmpty)
          DetailRow(label: l10n.receiptMerchant, value: e.merchantName!),
        if (e.receiptDate case final String d)
          DetailRow(
            label: l10n.receiptDate,
            value: LocalDates.display(d, locale: locale),
          ),
        if ((e.receiptTime ?? '').isNotEmpty)
          DetailRow(label: l10n.receiptTime, value: e.receiptTime!),
        money(l10n.receiptTotal, e.total),
        money(l10n.receiptSubtotal, e.subtotal),
        money(l10n.receiptTax, e.tax),
        money(l10n.receiptTip, e.tip),
        money(l10n.receiptDiscount, e.discount),
        if ((e.receiptNumber ?? '').isNotEmpty)
          DetailRow(label: l10n.receiptNumber, value: e.receiptNumber!),
        if ((e.paymentHint ?? '').isNotEmpty)
          DetailRow(label: l10n.receiptPaymentHint, value: e.paymentHint!),
        if (receipt.transactionId case final String txId)
          DetailRow(
            label: l10n.receiptLinkedTransaction,
            value: l10n.receiptOpenTransaction,
            onTap: () => context.push(AppRoutes.transactionDetail(txId)),
          ),
        if (e.lineItems.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.md,
              Insets.md,
              Insets.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.receiptLineItemsTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          for (final ReceiptLineItemDto item in e.lineItems)
            _LineItemRow(item: item),
        ],
      ],
    );
  }
}

class _LineItemRow extends ConsumerWidget {
  const _LineItemRow({required this.item});

  final ReceiptLineItemDto item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String description = (item.description ?? '').trim().isEmpty
        ? l10n.receiptLineItemUnnamed(item.position)
        : item.description!.trim();
    final List<String> parts = <String>[
      if (item.quantity case final String q) l10n.receiptQuantityValue(q),
      if (item.unitPrice case final Money p)
        l10n.receiptUnitPriceValue(formatMoney(context, ref, p)),
      if (item.tax case final Money t)
        l10n.receiptTaxValue(formatMoney(context, ref, t)),
    ];
    return ListTile(
      title: Text(description),
      subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
      trailing: item.amount == null
          ? null
          : MoneyText(item.amount!, label: description),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    return SectionCard(
      title: l10n.receiptHistoryTitle,
      children: <Widget>[
        for (final ReceiptExtractionSummary h in receipt.history)
          ListTile(
            leading: ExcludeSemantics(
              child: Icon(
                h.method == 'manual' ? Icons.edit_note : Icons.description,
              ),
            ),
            title: Text(
              l10n.receiptVersionTitle(
                h.version,
                receiptMethodLabel(l10n, h.method),
              ),
            ),
            subtitle: Text(formatDateTime(h.createdAt, locale: locale)),
          ),
      ],
    );
  }
}
