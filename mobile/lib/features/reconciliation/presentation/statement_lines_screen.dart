import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/cursor_page.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';
import 'package:montra_mobile/features/reconciliation/data/reconciliation_api.dart';
import 'package:montra_mobile/features/reconciliation/domain/reconciliation_display.dart';
import 'package:montra_mobile/features/transactions/data/transactions_api.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_tile.dart';

/// Matching by hand (`GET /accounts/{id}/statement-lines`): statement lines
/// that were neither imported nor matched, including lines with no
/// suggestion. Choosing a line lists the account's unreconciled
/// transactions in the same direction; the chosen ones are matched with
/// the line (`POST /reconciliation/matches`, `statement_to_ledger`). The
/// server checks that the amounts add up. Lines matched by hand can be
/// unmatched again.
class StatementLinesScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [accountId]; [matched] opens the lines already
  /// matched by hand.
  const StatementLinesScreen({
    required this.accountId,
    this.matched = false,
    super.key,
  });

  /// The account.
  final String accountId;

  /// Whether to start on the matched lines.
  final bool matched;

  @override
  ConsumerState<StatementLinesScreen> createState() =>
      _StatementLinesScreenState();
}

class _StatementLinesScreenState extends ConsumerState<StatementLinesScreen> {
  late bool _matched = widget.matched;

  /// The line being matched or unmatched.
  String? _busy;

  StatementLinesQuery get _query =>
      (accountId: widget.accountId, matched: _matched);

  Future<void> _refresh() async {
    ref.invalidate(statementLinesProvider(_query));
    try {
      await ref.read(statementLinesProvider(_query).future);
    } on Object {
      // Shown by the list state.
    }
  }

  Future<void> _match(StatementLineDto line) async {
    final AppLocalizations l10n = context.l10n;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    final List<String>? ids = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          _LedgerChoiceSheet(accountId: widget.accountId, line: line),
    );
    if (ids == null || ids.isEmpty || !mounted) {
      return;
    }
    setState(() => _busy = line.importRowId);
    try {
      await ref
          .read(reconciliationApiProvider)
          .confirm(manualMatchInput(widget.accountId, line, ids));
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

  Future<void> _unmatch(StatementLineDto line) async {
    final String? matchId = line.matchId;
    if (matchId == null) {
      return;
    }
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
    setState(() => _busy = line.importRowId);
    try {
      await ref.read(reconciliationApiProvider).unmatch(matchId);
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
    final AsyncValue<PagedList<StatementLineDto>> lines = ref.watch(
      statementLinesProvider(_query),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reconMatchByHand),
        bottom: _busy != null || (lines.isLoading && lines.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              0,
            ),
            child: SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(l10n.reconLinesUnmatched),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(l10n.reconLinesMatched),
                ),
              ],
              selected: <bool>{_matched},
              onSelectionChanged: (Set<bool> s) =>
                  setState(() => _matched = s.first),
            ),
          ),
          Expanded(
            child: AsyncValueView<PagedList<StatementLineDto>>(
              value: lines,
              onRetry: _refresh,
              loadingLabel: l10n.reconLoading,
              data: (PagedList<StatementLineDto> list) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: Insets.xl),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(Insets.md),
                      child: Text(
                        _matched
                            ? l10n.reconLinesMatchedIntro
                            : l10n.reconLinesIntro,
                      ),
                    ),
                    if (list.items.isEmpty)
                      MessageStateView(
                        icon: Icons.rule_outlined,
                        title: _matched
                            ? l10n.reconLinesMatchedEmpty
                            : l10n.reconLinesEmpty,
                      )
                    else
                      for (final StatementLineDto line in list.items)
                        StatementLineTile(
                          line: line,
                          busy: _busy == line.importRowId,
                          onTap: _busy != null
                              ? null
                              : () => line.matchId != null
                                    ? _unmatch(line)
                                    : _match(line),
                        ),
                    LoadMoreFooter(
                      list: list,
                      onLoadMore: () => ref
                          .read(statementLinesProvider(_query).notifier)
                          .loadMore(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One statement line: description, date, row and what happened on import,
/// with its amount and direction.
class StatementLineTile extends StatelessWidget {
  /// Creates the tile.
  const StatementLineTile({
    required this.line,
    this.busy = false,
    this.onTap,
    super.key,
  });

  /// The line.
  final StatementLineDto line;

  /// Whether a change is being saved.
  final bool busy;

  /// Matches (or unmatches) the line.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String description = (line.description ?? '').trim();
    final bool matched = line.matchId != null;
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        child: ExcludeSemantics(child: Icon(Icons.description_outlined)),
      ),
      title: Text(
        description.isEmpty ? l10n.reconLineNoDescription : description,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              LocalDates.display(line.date, locale: locale),
              l10n.importRowNumber(line.rowNumber),
            ].join(' · '),
          ),
          const SizedBox(height: Insets.xs),
          StatusLabel(
            text: matched
                ? l10n.reconLineMatched
                : statementLineStatusLabel(l10n, line.recordStatus),
            tone: matched ? StatusTone.positive : StatusTone.neutral,
            icon: matched ? Icons.link : Icons.link_off,
          ),
        ],
      ),
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : MoneyText(
              line.amount,
              flow: line.direction == StatementLineDtoDirection.inflow
                  ? MoneyFlow.inflow
                  : MoneyFlow.outflow,
            ),
    );
  }
}

/// The account's unreconciled transactions (first page), for matching a
/// statement line by hand.
final FutureProviderFamily<CursorPage<TransactionDto>, String>
unreconciledTransactionsProvider = FutureProvider.autoDispose
    .family<CursorPage<TransactionDto>, String>((Ref ref, String accountId) {
      ref.watch(financeRevisionProvider);
      return ref
          .read(transactionsApiProvider)
          .list(
            TransactionFilter(
              accountIds: <String>{accountId},
              reconciliationState: 'unreconciled',
            ),
            limit: 100,
          );
    });

/// Chooses the transactions a statement line stands for: unreconciled
/// transactions of the account in the line's direction (several when the
/// line is a total of them).
class _LedgerChoiceSheet extends ConsumerStatefulWidget {
  const _LedgerChoiceSheet({required this.accountId, required this.line});

  final String accountId;
  final StatementLineDto line;

  @override
  ConsumerState<_LedgerChoiceSheet> createState() => _LedgerChoiceSheetState();
}

class _LedgerChoiceSheetState extends ConsumerState<_LedgerChoiceSheet> {
  final Set<String> _chosen = <String>{};

  bool _sameDirection(TransactionDto t) =>
      t.direction.json == widget.line.direction.json;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<CursorPage<TransactionDto>> page = ref.watch(
      unreconciledTransactionsProvider(widget.accountId),
    );
    final String? account = ref
        .watch(accountDetailProvider(widget.accountId))
        .value
        ?.name;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Semantics(
              header: true,
              child: Text(
                l10n.reconChooseTransactionsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(
              l10n.reconChooseTransactionsIntro(
                LocalDates.display(widget.line.date, locale: locale),
                account ?? '',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: MoneyText(
                widget.line.amount,
                label: l10n.reconStatementLineAmount,
                style: Theme.of(context).textTheme.titleMedium,
                flow: widget.line.direction == StatementLineDtoDirection.inflow
                    ? MoneyFlow.inflow
                    : MoneyFlow.outflow,
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<CursorPage<TransactionDto>>(
              value: page,
              onRetry: () => ref.invalidate(
                unreconciledTransactionsProvider(widget.accountId),
              ),
              data: (CursorPage<TransactionDto> data) {
                final List<TransactionDto> shown = <TransactionDto>[
                  for (final TransactionDto t in data.items)
                    if (_sameDirection(t)) t,
                ];
                if (shown.isEmpty) {
                  return MessageStateView(
                    icon: Icons.search_off,
                    title: l10n.reconNoUnreconciled,
                  );
                }
                return ListView(
                  children: <Widget>[
                    for (final TransactionDto t in shown)
                      TransactionTile(
                        transaction: t,
                        showAccount: false,
                        selected: _chosen.contains(t.id),
                        onTap: () => setState(() {
                          if (!_chosen.remove(t.id)) {
                            _chosen.add(t.id);
                          }
                        }),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: SubmitButton(
              icon: Icons.link,
              label: l10n.reconMatchChosen(_chosen.length),
              onPressed: _chosen.isEmpty
                  ? null
                  : () async =>
                        Navigator.of(context).pop(_chosen.toList()..sort()),
            ),
          ),
        ],
      ),
    );
  }
}
