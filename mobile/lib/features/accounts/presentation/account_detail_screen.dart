import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/domain/account_types.dart';
import 'package:montra_mobile/features/accounts/presentation/account_widgets.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_tile.dart';

enum _AccountAction { edit, adjust, archive, restore, close }

/// One account: tracked balance (with liability details for cards and
/// loans), 30-day balance history, recent transactions and lifecycle
/// actions (edit, adjust, archive/restore, close).
class AccountDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [accountId].
  const AccountDetailScreen({required this.accountId, super.key});

  /// The account.
  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _busy = false;

  Future<void> _run(_AccountAction action, AccountDto account) async {
    final AppLocalizations l10n = context.l10n;
    switch (action) {
      case _AccountAction.edit:
        await context.push(AppRoutes.editAccount(account.id));
        return;
      case _AccountAction.adjust:
        await context.push(AppRoutes.adjustAccount(account.id));
        return;
      case _AccountAction.archive:
      case _AccountAction.restore:
      case _AccountAction.close:
        break;
    }
    if (_busy || !mounted) {
      return;
    }
    bool confirmed = true;
    if (action == _AccountAction.archive) {
      confirmed = await showConfirmDialog(
        context,
        title: l10n.accountArchiveConfirmTitle,
        body: l10n.accountArchiveConfirmBody(account.name),
        confirmLabel: l10n.accountArchive,
        destructive: true,
      );
    } else if (action == _AccountAction.close) {
      confirmed = await showConfirmDialog(
        context,
        title: l10n.accountCloseConfirmTitle,
        body: l10n.accountCloseConfirmBody(account.name),
        confirmLabel: l10n.accountClose,
        destructive: true,
      );
    }
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    final AccountDetailController controller = ref.read(
      accountDetailProvider(widget.accountId).notifier,
    );
    try {
      switch (action) {
        case _AccountAction.archive:
          await controller.archive();
        case _AccountAction.restore:
          await controller.restore();
        case _AccountAction.close:
          await controller.close();
        case _AccountAction.edit:
        case _AccountAction.adjust:
          break;
      }
      if (mounted) {
        showSnack(context, switch (action) {
          _AccountAction.archive => l10n.accountArchived,
          _AccountAction.restore => l10n.accountRestored,
          _ => l10n.accountClosed,
        });
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(accountDetailProvider(widget.accountId));
      }
      if (mounted) {
        showSnack(
          context,
          error.code == ErrorObjectCode.versionConflict
              ? l10n.versionConflictReloaded
              : describeError(l10n, error),
        );
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
    final AsyncValue<AccountDto> account = ref.watch(
      accountDetailProvider(widget.accountId),
    );
    final AccountDto? loaded = account.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? l10n.accountDetailTitle),
        bottom: _busy || (account.isLoading && account.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          if (loaded != null && loaded.owned)
            PopupMenuButton<_AccountAction>(
              tooltip: l10n.actionMore,
              enabled: !_busy,
              onSelected: (_AccountAction a) => _run(a, loaded),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_AccountAction>>[
                    PopupMenuItem<_AccountAction>(
                      value: _AccountAction.edit,
                      child: Text(l10n.actionEdit),
                    ),
                    if (loaded.status == AccountDtoStatus.active)
                      PopupMenuItem<_AccountAction>(
                        value: _AccountAction.adjust,
                        child: Text(l10n.accountAdjustBalance),
                      ),
                    if (loaded.status == AccountDtoStatus.active)
                      PopupMenuItem<_AccountAction>(
                        value: _AccountAction.archive,
                        child: Text(l10n.accountArchive),
                      ),
                    if (loaded.status != AccountDtoStatus.active)
                      PopupMenuItem<_AccountAction>(
                        value: _AccountAction.restore,
                        child: Text(l10n.actionRestore),
                      ),
                    if (loaded.status != AccountDtoStatus.closed)
                      PopupMenuItem<_AccountAction>(
                        value: _AccountAction.close,
                        child: Text(l10n.accountClose),
                      ),
                  ],
            ),
        ],
      ),
      body: AsyncValueView<AccountDto>(
        value: account,
        onRetry: () => ref.invalidate(accountDetailProvider(widget.accountId)),
        data: (AccountDto a) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(accountDetailProvider(widget.accountId))
              ..invalidate(accountHistoryProvider(widget.accountId))
              ..invalidate(accountRecentTransactionsProvider(widget.accountId));
            try {
              await ref.read(accountDetailProvider(widget.accountId).future);
            } on Object {
              // Shown by the screen state.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(Insets.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              _BalanceCard(account: a),
              if (a.status == AccountDtoStatus.active && a.owned) ...<Widget>[
                const SizedBox(height: Insets.md),
                _QuickActions(account: a),
              ],
              if (a.status != AccountDtoStatus.active) ...<Widget>[
                const SizedBox(height: Insets.md),
                NoticeBanner(
                  message: a.status == AccountDtoStatus.closed
                      ? l10n.accountClosedNotice
                      : l10n.accountArchivedNotice,
                ),
              ],
              const SizedBox(height: Insets.md),
              _HistoryCard(account: a),
              const SizedBox(height: Insets.md),
              _RecentCard(account: a),
              const SizedBox(height: Insets.md),
              _DetailsCard(account: a),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.account});

  final AccountDto account;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AccountInputAccountType type = accountTypeOf(account);
    final String? masked = maskedNumberText(account.maskedNumber);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                ExcludeSemantics(child: Icon(accountTypeIcon(type))),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    <String>[
                      accountTypeLabel(l10n, type),
                      ?account.institutionLabel,
                      ?masked,
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            AccountBalanceText(
              account,
              textAlign: TextAlign.start,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                StatusLabel(
                  text: balanceSourceLabel(l10n, account.balanceSource),
                  icon:
                      account.balanceSource == AccountDtoBalanceSource.provider
                      ? Icons.verified_outlined
                      : Icons.edit_note,
                ),
                if (account.status != AccountDtoStatus.active)
                  StatusLabel(
                    text: accountStatusLabel(l10n, account.status),
                    tone: StatusTone.caution,
                  ),
                if (!account.owned)
                  StatusLabel(
                    text: l10n.accountSharedReadOnly,
                    icon: Icons.group_outlined,
                  ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Text(
              account.balanceSource == AccountDtoBalanceSource.provider
                  ? l10n.providerBalanceNote
                  : l10n.trackedBalanceNote,
              style: theme.textTheme.bodySmall,
            ),
            if (account.isLiability) ...<Widget>[
              const Divider(height: Insets.lg),
              if (account.creditLimit case final Money limit)
                _MoneyRow(label: l10n.creditLimitLabel, money: limit),
              if (account.availableCredit case final Money available)
                _MoneyRow(label: l10n.availableCreditLabel, money: available),
              if (account.statementDay case final int day)
                DetailRow(
                  label: l10n.statementDayLabel,
                  value: l10n.dayOfMonth(day),
                ),
              if (account.paymentDueDay case final int day)
                DetailRow(
                  label: l10n.paymentDueDayLabel,
                  value: l10n.dayOfMonth(day),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoneyRow extends ConsumerWidget {
  const _MoneyRow({required this.label, required this.money});

  final String label;
  final Money money;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DetailRow(
    label: label,
    semanticsValue: formatMoney(context, ref, money),
    child: MoneyText(money),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.account});

  final AccountDto account;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => context.push(
            AppRoutes.newTransactionOf('expense', accountId: account.id),
          ),
          icon: const Icon(Icons.remove_circle_outline),
          label: Text(l10n.transactionAddExpense),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(
            AppRoutes.newTransactionOf('income', accountId: account.id),
          ),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n.transactionAddIncome),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(
            Uri(
              path: AppRoutes.newTransfer,
              queryParameters: <String, String>{'from': account.id},
            ).toString(),
          ),
          icon: const Icon(Icons.swap_horiz),
          label: Text(l10n.transferAdd),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.reconcileAccount(account.id)),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(l10n.entryReconcile),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              context.push(AppRoutes.newImportFor(accountId: account.id)),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l10n.entryImportStatement),
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.integrationsFor(account.id)),
          icon: const Icon(Icons.link),
          label: Text(l10n.entryConnectAccount),
        ),
      ],
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.account});

  final AccountDto account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<BalanceReport> report = ref.watch(
      accountHistoryProvider(account.id),
    );
    return SectionCard(
      title: l10n.balanceHistoryTitle,
      children: <Widget>[
        if (report.hasError && !report.isLoading)
          SizedBox(
            height: 260,
            child: ErrorStateView(
              error: report.error!,
              onRetry: () => ref.invalidate(accountHistoryProvider(account.id)),
            ),
          )
        else if (report.value case final BalanceReport data)
          _history(context, ref, data, locale)
        else
          const SizedBox(height: 120, child: LoadingStateView()),
      ],
    );
  }

  Widget _history(
    BuildContext context,
    WidgetRef ref,
    BalanceReport data,
    String locale,
  ) {
    final AppLocalizations l10n = context.l10n;
    final List<BalancePoint> points = data.history;
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Text(l10n.balanceHistoryEmpty),
      );
    }
    BalancePoint low = points.first;
    BalancePoint high = points.first;
    for (final BalancePoint p in points) {
      if (p.balance.amountMinor < low.balance.amountMinor) {
        low = p;
      }
      if (p.balance.amountMinor > high.balance.amountMinor) {
        high = p;
      }
    }
    final String summary = l10n.balanceHistorySummary(
      LocalDates.display(points.first.date, locale: locale),
      formatMoney(context, ref, points.first.balance),
      LocalDates.display(points.last.date, locale: locale),
      formatMoney(context, ref, points.last.balance),
      formatMoney(context, ref, low.balance),
      formatMoney(context, ref, high.balance),
    );
    return AccessibleChart(
      summary: summary,
      chart: Sparkline(
        values: <int>[
          for (final BalancePoint p in points) p.balance.amountMinor,
        ],
      ),
      table: Column(
        children: <Widget>[
          for (final BalancePoint p in points.reversed)
            DetailRow(
              label: LocalDates.display(p.date, locale: locale),
              semanticsValue: formatMoney(context, ref, p.balance),
              child: MoneyText(p.balance),
            ),
        ],
      ),
    );
  }
}

class _RecentCard extends ConsumerWidget {
  const _RecentCard({required this.account});

  final AccountDto account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CursorPage<TransactionDto>> recent = ref.watch(
      accountRecentTransactionsProvider(account.id),
    );
    final String allLink = TransactionFilter(accountIds: <String>{account.id})
        .toLocation();
    return SectionCard(
      title: l10n.recentTransactionsTitle,
      trailing: TextButton(
        onPressed: () => context.go(allLink),
        child: Text(
          l10n.actionSeeAll,
          semanticsLabel: l10n.accountSeeAllTransactions(account.name),
        ),
      ),
      children: <Widget>[
        if (recent.hasError && !recent.isLoading)
          SizedBox(
            height: 260,
            child: ErrorStateView(
              error: recent.error!,
              onRetry: () =>
                  ref.invalidate(accountRecentTransactionsProvider(account.id)),
            ),
          )
        else if (recent.value case final CursorPage<TransactionDto> page)
          if (page.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(l10n.accountNoTransactions),
            )
          else
            for (final TransactionDto t in page.items)
              TransactionTile(
                transaction: t,
                showAccount: false,
                onTap: () => context.push(AppRoutes.transactionDetail(t.id)),
              )
        else
          const SizedBox(height: 120, child: LoadingStateView()),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.account});

  final AccountDto account;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    return SectionCard(
      title: l10n.accountDetailsTitle,
      children: <Widget>[
        DetailRow(label: l10n.currencyFieldLabel, value: account.currency),
        DetailRow(
          label: l10n.openingDateLabel,
          value: LocalDates.display(account.openingDate, locale: locale),
        ),
        DetailRow(
          label: l10n.includeInOverviewLabel,
          value: account.includeInOverview ? l10n.statusOn : l10n.statusOff,
        ),
        if (account.lastReconciledAt case final DateTime at)
          DetailRow(
            label: l10n.lastReconciledLabel,
            value: formatDateTime(at, locale: locale),
          ),
        if (account.lastReconciledBalance case final Money balance)
          DetailRow(
            label: l10n.lastReconciledBalanceLabel,
            child: MoneyText(balance, label: l10n.lastReconciledBalanceLabel),
          ),
        if (account.lastImportAt case final DateTime at)
          DetailRow(
            label: l10n.lastImportLabel,
            value: formatDateTime(at, locale: locale),
          ),
        if (account.notes case final String notes when notes.isNotEmpty)
          DetailRow(label: l10n.notesLabel, value: notes),
      ],
    );
  }
}
