import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/receipts/application/receipts_providers.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_codes.dart';
import 'package:montra_mobile/features/receipts/domain/receipt_display.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_picker.dart';

/// Links a reviewed receipt to an expense that is already recorded:
/// suggestions from `GET /receipts/{id}/match-candidates` (same currency,
/// close amount and date) or any expense chosen from the ledger. Linking
/// records no new money (`POST /receipts/{id}/match-transaction`).
class ReceiptMatchScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [receiptId].
  const ReceiptMatchScreen({required this.receiptId, super.key});

  /// The receipt.
  final String receiptId;

  @override
  ConsumerState<ReceiptMatchScreen> createState() => _ReceiptMatchScreenState();
}

class _ReceiptMatchScreenState extends ConsumerState<ReceiptMatchScreen> {
  String? _linking;

  Future<void> _link(String transactionId) async {
    final AppLocalizations l10n = context.l10n;
    if (_linking != null) {
      return;
    }
    setState(() => _linking = transactionId);
    try {
      await ref
          .read(receiptsApiProvider)
          .match(widget.receiptId, transactionId);
      ref.financeChanged();
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.receiptLinked);
      leaveToReceipt(context, widget.receiptId);
    } on ApiException catch (error) {
      // Linked, discarded or edited elsewhere: show the current state (and
      // drop suggestions that no longer apply).
      if (receiptChangedUnderneath(error)) {
        ref
          ..invalidate(receiptProvider(widget.receiptId))
          ..invalidate(receiptCandidatesProvider(widget.receiptId));
      }
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _linking = null);
      }
    }
  }

  Future<void> _chooseOther(ReceiptExtractionDto? current) async {
    final AppLocalizations l10n = context.l10n;
    final TransactionDto? picked = await showTransactionPicker(
      context,
      filter: TransactionFilter(
        types: const <String>{'expense'},
        currency: current?.total?.currency ?? current?.currency,
      ),
      title: l10n.receiptChooseTransaction,
    );
    if (picked != null && mounted) {
      await _link(picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<ReceiptView> receipt = ref.watch(
      receiptProvider(widget.receiptId),
    );
    final AsyncValue<List<ReceiptMatchCandidate>> candidates = ref.watch(
      receiptCandidatesProvider(widget.receiptId),
    );
    final ReceiptDetail? r = receipt.value?.detail;
    final ReceiptExtractionDto? current = r?.current;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.receiptMatchTitle),
        bottom: _linking != null
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: AsyncValueView<List<ReceiptMatchCandidate>>(
        value: candidates,
        onRetry: () =>
            ref.invalidate(receiptCandidatesProvider(widget.receiptId)),
        data: (List<ReceiptMatchCandidate> list) => ListView(
          padding: const EdgeInsets.all(Insets.md),
          children: <Widget>[
            if (current != null &&
                current.total != null &&
                current.receiptDate != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        receiptTitle(l10n, current),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Insets.xs),
                      Wrap(
                        spacing: Insets.sm,
                        children: <Widget>[
                          Text(
                            LocalDates.display(
                              current.receiptDate!,
                              locale: locale,
                            ),
                          ),
                          MoneyText(current.total!, label: l10n.receiptTotal),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Insets.md),
            Text(
              list.isEmpty ? l10n.receiptMatchNone : l10n.receiptMatchIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Insets.sm),
            for (final ReceiptMatchCandidate c in list)
              _CandidateCard(
                candidate: c,
                busy: _linking != null,
                linking: _linking == c.transactionId,
                onLink: () => _link(c.transactionId),
              ),
            const SizedBox(height: Insets.md),
            OutlinedButton.icon(
              onPressed: _linking != null ? null : () => _chooseOther(current),
              icon: const Icon(Icons.search),
              label: Text(l10n.receiptChooseTransaction),
            ),
            const SizedBox(height: Insets.sm),
            TextButton.icon(
              onPressed: _linking != null
                  ? null
                  : () => context.pushReplacement(
                      AppRoutes.recordReceipt(widget.receiptId),
                    ),
              icon: const Icon(Icons.add_card_outlined),
              label: Text(l10n.receiptRecordAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.busy,
    required this.linking,
    required this.onLink,
  });

  final ReceiptMatchCandidate candidate;
  final bool busy;
  final bool linking;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ReceiptMatchCandidate c = candidate;
    final List<String> reasons = receiptSuggestionReasons(l10n, candidate);
    final String title = (c.merchant ?? '').trim().isNotEmpty
        ? c.merchant!.trim()
        : ((c.description ?? '').trim().isNotEmpty
              ? c.description!.trim()
              : l10n.receiptUnnamedTransaction);
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Insets.xs),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                MoneyText(
                  c.amount,
                  flow: MoneyFlow.outflow,
                  label: l10n.receiptCandidateAmount,
                ),
                Text(LocalDates.display(c.localDate, locale: locale)),
                Text(c.accountName),
              ],
            ),
            if (reasons.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.xs),
              Text(
                reasons.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: Insets.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: busy ? null : onLink,
                icon: linking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link),
                label: Text(l10n.receiptLinkThis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
