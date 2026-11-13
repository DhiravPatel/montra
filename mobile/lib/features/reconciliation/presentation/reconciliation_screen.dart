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
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';
import 'package:montra_mobile/features/reconciliation/domain/reconciliation_display.dart';
import 'package:montra_mobile/features/reconciliation/presentation/reconciliation_paths.dart';

/// Reconciliation for one account: statement balance checks (the server
/// computes the difference), suggested matches with reasons (nothing
/// changes until the user confirms one) and confirmed matches, which can be
/// undone.
class ReconciliationScreen extends ConsumerWidget {
  /// Creates the screen for [accountId].
  const ReconciliationScreen({required this.accountId, super.key});

  /// The account.
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AccountDto? account = ref
        .watch(accountDetailProvider(accountId))
        .value;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          actions: const <Widget>[HelpGuideButton(HelpGuide.reconciliation)],
          title: Text(
            account == null ? l10n.reconTitle : l10n.reconTitleOf(account.name),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: l10n.reconTabBalances),
              Tab(text: l10n.reconTabSuggestions),
              Tab(text: l10n.reconTabMatched),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _Balances(accountId: accountId),
            _Suggestions(accountId: accountId),
            _Matches(accountId: accountId),
          ],
        ),
      ),
    );
  }
}

/// A paged list that refreshes when pulled and loads more on request.
class _PagedRefreshList<T> extends ConsumerWidget {
  const _PagedRefreshList({
    required this.provider,
    required this.header,
    required this.empty,
    required this.item,
    required this.loadingLabel,
  });

  final AsyncNotifierProvider<PagedListController<T>, PagedList<T>> provider;
  final List<Widget> header;
  final Widget empty;
  final Widget Function(T item) item;
  final String loadingLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } on Object {
        // Shown by the view.
      }
    }

    return AsyncValueView<PagedList<T>>(
      value: ref.watch(provider),
      onRetry: refresh,
      loadingLabel: loadingLabel,
      data: (PagedList<T> data) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.md,
            Insets.md,
            Insets.xl,
          ),
          children: <Widget>[
            ...header,
            if (data.items.isEmpty)
              empty
            else
              for (final T i in data.items) ...<Widget>[
                item(i),
                const SizedBox(height: Insets.sm),
              ],
            LoadMoreFooter(
              list: data,
              onLoadMore: () => ref.read(provider.notifier).loadMore(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list that refreshes [provider] when pulled.
class _RefreshList<T> extends ConsumerWidget {
  const _RefreshList({
    required this.provider,
    required this.builder,
    required this.loadingLabel,
  });

  final FutureProvider<T> provider;
  final List<Widget> Function(T data) builder;
  final String loadingLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } on Object {
        // Shown by the view.
      }
    }

    return AsyncValueView<T>(
      value: ref.watch(provider),
      onRetry: refresh,
      loadingLabel: loadingLabel,
      data: (T data) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.md,
            Insets.md,
            Insets.xl,
          ),
          children: builder(data),
        ),
      ),
    );
  }
}

class _Balances extends StatelessWidget {
  const _Balances({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _PagedRefreshList<ReconBalanceDto>(
      provider: reconBalancesProvider(accountId),
      loadingLabel: l10n.reconLoading,
      header: <Widget>[
        Text(l10n.reconBalancesIntro),
        const SizedBox(height: Insets.md),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.newReconciliation(accountId)),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(l10n.reconCheckBalance),
        ),
        const SizedBox(height: Insets.md),
      ],
      empty: MessageStateView(
        icon: Icons.fact_check_outlined,
        title: l10n.reconBalancesEmpty,
      ),
      item: (ReconBalanceDto b) => ReconBalanceCard(balance: b),
    );
  }
}

/// One statement balance check: balanced or the difference, and what it
/// changed.
class ReconBalanceCard extends ConsumerWidget {
  /// Creates the card.
  const ReconBalanceCard({required this.balance, super.key});

  /// The check.
  final ReconBalanceDto balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ReconBalanceDto b = balance;
    final bool balanced = b.status == ReconBalanceDtoStatus.balanced;
    final String? notes = b.notes;
    return SectionCard(
      title: l10n.reconStatementOf(
        LocalDates.display(b.statementDate, locale: locale),
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusLabel(
              text: balanced
                  ? l10n.reconBalanced
                  : l10n.reconOffBy(formatMoney(context, ref, b.difference)),
              tone: balanced ? StatusTone.positive : StatusTone.caution,
            ),
          ),
        ),
        DetailRow(
          label: l10n.reconStatementBalance,
          semanticsValue: formatMoney(context, ref, b.statementBalance),
          child: MoneyText(b.statementBalance),
        ),
        DetailRow(
          label: l10n.reconLedgerBalance,
          semanticsValue: formatMoney(context, ref, b.ledgerBalance),
          child: MoneyText(b.ledgerBalance),
        ),
        DetailRow(
          label: l10n.reconDifference,
          semanticsValue: formatMoney(context, ref, b.difference),
          child: MoneyText(b.difference),
        ),
        if (b.reconciledCount > 0)
          _Note(l10n.reconReconciledCount(b.reconciledCount)),
        if (b.unreconciledTransactions > 0)
          _Note(l10n.reconUnreconciledCount(b.unreconciledTransactions)),
        if (b.unmatchedStatementRows > 0)
          _Note(l10n.reconUnmatchedRows(b.unmatchedStatementRows)),
        if (!balanced) _Note(l10n.reconOffByHelp),
        if (notes != null && notes.isNotEmpty) _Note(notes),
        const SizedBox(height: Insets.sm),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, 0),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _Suggestions extends ConsumerStatefulWidget {
  const _Suggestions({required this.accountId});

  final String accountId;

  @override
  ConsumerState<_Suggestions> createState() => _SuggestionsState();
}

class _SuggestionsState extends ConsumerState<_Suggestions> {
  /// The candidate being confirmed (one at a time).
  ReconCandidate? _busy;

  Future<void> _confirm(ReconCandidate c) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    String? keep;
    switch (c.kind) {
      case ReconCandidateKind.pendingToPosted:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.reconConfirmPendingTitle,
          body: l10n.reconConfirmPendingBody,
          confirmLabel: l10n.reconConfirm,
        );
        if (!ok) {
          return;
        }
      case ReconCandidateKind.manualToImported:
        keep = await _chooseKeep(c);
        if (keep == null) {
          return;
        }
      case ReconCandidateKind.statementToLedger:
      case ReconCandidateKind.unrecognized:
        break;
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = c);
    try {
      await ref
          .read(reconciliationApiProvider)
          .confirm(confirmInput(widget.accountId, c, keepTransactionId: keep));
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.reconMatched);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  /// Asks which of two duplicates to keep; the other is removed (undoing
  /// the match brings it back).
  Future<String?> _chooseKeep(ReconCandidate c) {
    final AppLocalizations l10n = context.l10n;
    final List<ReconCandidateItem> items = <ReconCandidateItem>[
      c.left,
      ...c.right,
    ];
    return showOptionSheet<String>(
      context,
      title: l10n.reconKeepTitle,
      options: <SheetOption<String>>[
        for (final ReconCandidateItem i in items)
          if (i.transactionId != null)
            SheetOption<String>(
              value: i.transactionId!,
              label: reconItemImported(i)
                  ? l10n.reconKeepImported
                  : l10n.reconKeepManual,
              subtitle: _itemSummary(context, i),
              icon: reconItemImported(i)
                  ? Icons.upload_file_outlined
                  : Icons.edit_note_outlined,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _RefreshList<List<ReconCandidate>>(
      provider: reconCandidatesProvider(widget.accountId),
      loadingLabel: l10n.reconLoading,
      builder: (List<ReconCandidate> list) => <Widget>[
        Text(l10n.reconSuggestionsIntro),
        const SizedBox(height: Insets.sm),
        OutlinedButton.icon(
          onPressed: () =>
              context.push(ReconciliationPaths.lines(widget.accountId)),
          icon: const Icon(Icons.rule_outlined),
          label: Text(l10n.reconMatchByHand),
        ),
        const SizedBox(height: Insets.md),
        if (list.isEmpty)
          MessageStateView(
            icon: Icons.link_off,
            title: l10n.reconSuggestionsEmpty,
            body: l10n.reconSuggestionsEmptyBody,
          )
        else
          for (final ReconCandidate c in list) ...<Widget>[
            _CandidateCard(
              candidate: c,
              busy: identical(_busy, c),
              onConfirm: _busy == null ? () => _confirm(c) : null,
            ),
            const SizedBox(height: Insets.sm),
          ],
      ],
    );
  }
}

String _itemSummary(BuildContext context, ReconCandidateItem i) {
  final String locale = Localizations.localeOf(context).toString();
  final String date = LocalDates.display(i.date, locale: locale);
  final String? description = i.description;
  return description == null || description.isEmpty
      ? date
      : '$date · $description';
}

class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({
    required this.candidate,
    required this.busy,
    required this.onConfirm,
  });

  final ReconCandidate candidate;
  final bool busy;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ReconCandidate c = candidate;
    final int? percent = confidencePercent(c.confidence);
    final List<String> reasons = reconReasons(
      l10n,
      codes: <String>[
        for (final ReconCandidateReasonCodesItem r in c.reasonCodes) r.json,
      ],
      reasons: c.reasons,
      params: c.reasonParams,
      money: (String amount, String currency) =>
          formatMoneyAmount(context, ref, amount, currency),
    );
    return SectionCard(
      title: reconKindLabel(l10n, c.kind.json),
      children: <Widget>[
        if (percent != null) _Note(l10n.reconConfidence(percent)),
        _Note(reconKindHelp(l10n, c.kind.json)),
        const SizedBox(height: Insets.xs),
        _ItemRow(item: c.left),
        for (final ReconCandidateItem i in c.right) _ItemRow(item: i),
        if (reasons.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              0,
            ),
            child: Text(
              l10n.reconWhy(reasons.join('; ')),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: _ActionButton(
            icon: Icons.link,
            label: l10n.reconConfirm,
            busy: busy,
            onPressed: onConfirm,
          ),
        ),
      ],
    );
  }
}

/// A full-width outlined action that may first ask for confirmation; it
/// shows progress only while the request runs.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    ),
  );
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});

  final ReconCandidateItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final MoneyFlow flow = item.direction == ReconCandidateItemDirection.inflow
        ? MoneyFlow.inflow
        : MoneyFlow.outflow;
    return ListTile(
      dense: false,
      leading: ExcludeSemantics(
        child: Icon(
          item.side == ReconCandidateItemSide.statement
              ? Icons.description_outlined
              : Icons.receipt_long_outlined,
        ),
      ),
      title: Text(reconItemRole(l10n, item)),
      subtitle: Text(_itemSummary(context, item)),
      trailing: MoneyText(item.amount, flow: flow),
    );
  }
}

class _Matches extends ConsumerStatefulWidget {
  const _Matches({required this.accountId});

  final String accountId;

  @override
  ConsumerState<_Matches> createState() => _MatchesState();
}

class _MatchesState extends ConsumerState<_Matches> {
  /// The match being undone.
  String? _busy;

  Future<void> _undo(ReconMatchDto m) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.reconUndoTitle,
      body: l10n.reconUndoBody,
      confirmLabel: l10n.reconUndo,
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() => _busy = m.id);
    try {
      await ref.read(reconciliationApiProvider).unmatch(m.id);
      finance.bump();
      if (mounted) {
        showSnack(context, l10n.reconUndone);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return _PagedRefreshList<ReconMatchDto>(
      provider: reconMatchesProvider(widget.accountId),
      loadingLabel: l10n.reconLoading,
      header: const <Widget>[],
      empty: MessageStateView(icon: Icons.link, title: l10n.reconMatchesEmpty),
      item: (ReconMatchDto m) => ReconMatchCard(
        match: m,
        busy: _busy == m.id,
        onUndo: _busy == null && m.status == ReconMatchDtoStatus.confirmed
            ? () => _undo(m)
            : null,
      ),
    );
  }
}

/// One match: kind, status, when, both sides (date, description and what
/// the match did), the amount kept and why; confirmed matches can be
/// undone.
class ReconMatchCard extends ConsumerWidget {
  /// Creates the card.
  const ReconMatchCard({
    required this.match,
    this.busy = false,
    this.onUndo,
    super.key,
  });

  /// The match.
  final ReconMatchDto match;

  /// Whether it is being undone.
  final bool busy;

  /// Undoes it (null when it cannot be undone now).
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ReconMatchDto m = match;
    final List<String> reasons = reconReasons(
      l10n,
      codes: <String>[
        for (final ReconMatchDtoReasonCodesItem r in m.reasonCodes) r.json,
      ],
      reasons: m.reasons,
      params: m.reasonParams,
      money: (String amount, String currency) =>
          formatMoneyAmount(context, ref, amount, currency),
    );
    return SectionCard(
      title: reconKindLabel(l10n, m.kind),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusLabel(
              text: reconMatchStatusLabel(l10n, m.status),
              tone: m.status == ReconMatchDtoStatus.confirmed
                  ? StatusTone.positive
                  : StatusTone.neutral,
            ),
          ),
        ),
        _Note(
          l10n.reconMatchedOn(
            formatDateTime(m.confirmedAt ?? m.createdAt, locale: locale),
          ),
        ),
        for (final ReconMatchItemDto i in m.items)
          ListTile(
            leading: ExcludeSemantics(
              child: Icon(
                i.side == ReconMatchItemDtoSide.statement
                    ? Icons.description_outlined
                    : Icons.receipt_long_outlined,
              ),
            ),
            title: Text(reconMatchItemRole(l10n, i)),
            subtitle: Text(
              <String>[
                LocalDates.display(i.date, locale: locale),
                if ((i.description ?? '').trim().isNotEmpty)
                  i.description!.trim(),
                ?reconEffectLabel(l10n, i.effect),
              ].join(' · '),
            ),
            trailing: MoneyText(
              i.amount,
              flow: i.direction == ReconMatchItemDtoDirection.inflow
                  ? MoneyFlow.inflow
                  : MoneyFlow.outflow,
            ),
          ),
        if (m.total case final Money total)
          DetailRow(
            label: l10n.reconMatchTotal,
            semanticsValue: formatMoney(context, ref, total),
            child: MoneyText(total),
          ),
        if (reasons.isNotEmpty) _Note(l10n.reconWhy(reasons.join('; '))),
        if (onUndo != null || busy)
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: _ActionButton(
              icon: Icons.undo,
              label: l10n.reconUndo,
              busy: busy,
              onPressed: onUndo,
            ),
          )
        else
          const SizedBox(height: Insets.sm),
      ],
    );
  }
}
