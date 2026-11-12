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
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/transactions/application/transactions_providers.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';

/// A transfer between two of the user's accounts: both sides, fee and
/// exchange rate. Deleting voids both legs and the fee together; restoring
/// brings them all back.
class TransferDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [transferId].
  const TransferDetailScreen({required this.transferId, super.key});

  /// The transfer.
  final String transferId;

  @override
  ConsumerState<TransferDetailScreen> createState() =>
      _TransferDetailScreenState();
}

class _TransferDetailScreenState extends ConsumerState<TransferDetailScreen> {
  bool _busy = false;

  Future<void> _delete(TransferDto transfer) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.transferDeleteConfirmTitle,
      body: transfer.fee == null
          ? l10n.transferDeleteConfirmBody
          : l10n.transferDeleteConfirmBodyFee,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _act(
      () => ref.read(transactionsApiProvider).deleteTransfer(transfer.id),
      l10n.transferDeleted,
    );
  }

  Future<void> _restore(TransferDto transfer) => _act(
    () => ref.read(transactionsApiProvider).restoreTransfer(transfer.id),
    context.l10n.transferRestored,
  );

  Future<void> _act(Future<Object?> Function() action, String done) async {
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final AppLocalizations l10n = context.l10n;
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      finance.bump();
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<TransferDto> view = ref.watch(
      transferDetailProvider(widget.transferId),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transferDetailTitle),
        bottom: _busy || (view.isLoading && view.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: AsyncValueView<TransferDto>(
        value: view,
        onRetry: () =>
            ref.invalidate(transferDetailProvider(widget.transferId)),
        data: (TransferDto t) => _body(context, t),
      ),
    );
  }

  Widget _body(BuildContext context, TransferDto t) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final bool voided = t.status == TransferDtoStatus.voided;
    final String fromName =
        accounts[t.fromAccountId]?.name ?? l10n.accountDetailTitle;
    final String toName =
        accounts[t.toAccountId]?.name ?? l10n.accountDetailTitle;
    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: <Widget>[
        if (voided) ...<Widget>[
          NoticeBanner(
            tone: NoticeTone.warning,
            message: l10n.transferVoidedNotice,
          ),
          const SizedBox(height: Insets.md),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const ExcludeSemantics(child: Icon(Icons.swap_horiz)),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        l10n.transferBetween(fromName, toName),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                StatusLabel(
                  text: voided ? l10n.txStatusDeleted : l10n.txStatusPosted,
                  tone: voided ? StatusTone.caution : StatusTone.positive,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  l10n.transferNotIncomeNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          children: <Widget>[
            DetailRow(
              label: l10n.transferSentFrom(fromName),
              semanticsValue: formatMoney(context, ref, t.fromAmount),
              onTap: () =>
                  context.push(AppRoutes.accountDetail(t.fromAccountId)),
              child: MoneyText(t.fromAmount, flow: MoneyFlow.outflow),
            ),
            DetailRow(
              label: l10n.transferReceivedIn(toName),
              semanticsValue: formatMoney(context, ref, t.toAmount),
              onTap: () => context.push(AppRoutes.accountDetail(t.toAccountId)),
              child: MoneyText(t.toAmount, flow: MoneyFlow.inflow),
            ),
            if (t.fee case final Money fee)
              DetailRow(
                label: l10n.transferFeeLabel,
                semanticsValue: formatMoney(context, ref, fee),
                onTap: t.feeTransactionId == null
                    ? null
                    : () => context.push(
                        AppRoutes.transactionDetail(t.feeTransactionId!),
                      ),
                child: MoneyText(fee, flow: MoneyFlow.outflow),
              ),
            if (t.fxRate case final String rate)
              DetailRow(
                label: l10n.transferRateShown(
                  t.fromAmount.currency,
                  t.toAmount.currency,
                ),
                value: t.fxRateSource == null
                    ? rate
                    : l10n.rateWithSource(rate, t.fxRateSource!),
              ),
            DetailRow(
              label: l10n.dateLabel,
              value: LocalDates.display(t.localDate, locale: locale),
            ),
            if (t.description case final String d when d.isNotEmpty)
              DetailRow(label: l10n.descriptionLabel, value: d),
            if (t.notes case final String n when n.isNotEmpty)
              DetailRow(label: l10n.notesLabel, value: n),
            DetailRow(
              label: l10n.createdLabel,
              value: formatDateTime(t.createdAt, locale: locale),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.transferLegsTitle,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.north_east),
              title: Text(l10n.transferLegOut),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                AppRoutes.transactionDetail(t.fromTransactionId),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.south_west),
              title: Text(l10n.transferLegIn),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push(AppRoutes.transactionDetail(t.toTransactionId)),
            ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        voided
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busy ? null : () => _restore(t),
                icon: const Icon(Icons.restore),
                label: Text(l10n.transferRestore),
              )
            : FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: _busy ? null : () => _delete(t),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.transferDelete),
              ),
        const SizedBox(height: Insets.lg),
      ],
    );
  }
}
