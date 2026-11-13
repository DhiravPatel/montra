import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/saved_filters/saved_filters.dart';
import 'package:montra_mobile/core/saved_filters/saved_filters_sheet.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/payment_methods/application/payment_methods_providers.dart';
import 'package:montra_mobile/features/transactions/application/transactions_providers.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_display.dart';
import 'package:montra_mobile/features/transactions/domain/transaction_filter.dart';
import 'package:montra_mobile/features/transactions/presentation/bulk_edit_sheet.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_filter_screen.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_tile.dart';

/// Opens the quick-add choice (expense, income, transfer).
Future<void> showQuickAdd(BuildContext context, {String? accountId}) async {
  final AppLocalizations l10n = context.l10n;
  final String? choice = await showOptionSheet<String>(
    context,
    title: l10n.quickAddTitle,
    options: <SheetOption<String>>[
      SheetOption<String>(
        value: 'expense',
        label: l10n.txTypeExpense,
        subtitle: l10n.quickAddExpenseHelp,
        icon: Icons.remove_circle_outline,
      ),
      SheetOption<String>(
        value: 'income',
        label: l10n.txTypeIncome,
        subtitle: l10n.quickAddIncomeHelp,
        icon: Icons.add_circle_outline,
      ),
      SheetOption<String>(
        value: 'transfer',
        label: l10n.txTypeTransfer,
        subtitle: l10n.quickAddTransferHelp,
        icon: Icons.swap_horiz,
      ),
    ],
  );
  if (choice == null || !context.mounted) {
    return;
  }
  if (choice == 'transfer') {
    await context.push(AppRoutes.newTransfer);
  } else {
    await context.push(
      AppRoutes.newTransactionOf(choice, accountId: accountId),
    );
  }
}

/// Transactions tab: search, filters (date range, type, account, category,
/// merchant, tag, amount, source, status, direction…), cursor-paginated
/// infinite scroll, and multi-select for bulk changes.
///
/// The filter lives in the route (`/transactions?…`), so dashboard
/// drill-down links and the back stack always match what is shown.
class TransactionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen showing [filter].
  const TransactionsScreen({required this.filter, super.key});

  /// Current filter (from the route's query parameters).
  final TransactionFilter filter;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final ScrollController _scroll = ScrollController();
  late final TextEditingController _search = TextEditingController(
    text: widget.filter.query ?? '',
  );
  late bool _searching = widget.filter.hasQuery;
  Timer? _debounce;
  final Set<String> _selected = <String>{};
  bool _bulkBusy = false;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _selected.clear();
      final String q = widget.filter.query ?? '';
      if (_search.text.trim() != q) {
        _search.text = q;
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) {
      return;
    }
    final ScrollPosition p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 600) {
      unawaited(
        ref.read(transactionsListProvider(widget.filter).notifier).loadMore(),
      );
    }
  }

  void _go(TransactionFilter filter) => context.go(filter.toLocation());

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) {
        return;
      }
      final String q = text.trim();
      _go(
        q.isEmpty
            ? widget.filter.copyWith(clearQuery: true)
            : widget.filter.copyWith(query: q),
      );
    });
  }

  Future<void> _openFilters(String? merchantName) async {
    final TransactionFilter? next = await showTransactionFilters(
      context,
      widget.filter,
      merchantName: merchantName,
    );
    if (next != null && mounted) {
      _go(next);
    }
  }

  /// Saved filters: save this list's filters, or apply or delete one.
  Future<void> _openSaved() async {
    final AppLocalizations l10n = context.l10n;
    final TransactionFilter filter = widget.filter;
    final AppliedSavedFilter? chosen = await showSavedFiltersSheet(
      context,
      scope: SavedFilterScope.transactions,
      current: filter.isEmpty && filter.sort == 'date_desc'
          ? null
          : filter.toSavedJson(),
      describe: (Map<String, Object?> json) {
        final TransactionFilter? saved = TransactionFilter.fromSavedJson(json);
        return saved == null ? null : describeSavedFilter(l10n, saved);
      },
    );
    if (chosen == null || !mounted) {
      return;
    }
    final TransactionFilter next = TransactionFilter.fromSavedJson(
      chosen.filter,
    )!;
    setState(() => _searching = next.hasQuery);
    _go(next);
    showSnack(context, l10n.savedFiltersApplied(chosen.name));
  }

  void _toggle(TransactionDto t) => setState(() {
    if (!_selected.remove(t.id)) {
      _selected.add(t.id);
    }
  });

  Future<void> _bulkEdit() async {
    final AppLocalizations l10n = context.l10n;
    final List<String> ids = _selected.toList();
    final int? updated = await showBulkEditSheet(context, ids);
    if (updated != null && mounted) {
      setState(_selected.clear);
      showSnack(context, l10n.bulkUpdated(updated));
    }
  }

  Future<void> _bulkDelete() async {
    final AppLocalizations l10n = context.l10n;
    final List<String> ids = _selected.toList();
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.bulkDeleteConfirmTitle(ids.length),
      body: l10n.bulkDeleteConfirmBody,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _bulkBusy = true);
    try {
      final int deleted = await bulkDelete(ref, ids);
      if (mounted) {
        setState(_selected.clear);
        showSnack(context, l10n.bulkDeleted(deleted));
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _bulkBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TransactionFilter filter = widget.filter;
    final AsyncValue<TransactionListState> list = ref.watch(
      transactionsListProvider(filter),
    );
    final String? merchantName = filter.merchantId == null
        ? null
        : list.value?.items
              .map((TransactionDto t) => t.merchant)
              .whereType<MerchantRef>()
              .where((MerchantRef m) => m.id == filter.merchantId)
              .map((MerchantRef m) => m.name)
              .firstOrNull;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && _selecting) {
          setState(_selected.clear);
        }
      },
      child: Scaffold(
        appBar: _selecting
            ? _selectionBar(context)
            : _normalBar(context, merchantName),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => showQuickAdd(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.actionAdd),
                tooltip: l10n.quickAddTitle,
              ),
        body: Column(
          children: <Widget>[
            if (filter.activeCount > 0)
              _ActiveFilters(
                filter: filter,
                merchantName: merchantName,
                onChanged: _go,
              ),
            Expanded(
              child: AsyncValueView<TransactionListState>(
                value: list,
                onRetry: () => ref.invalidate(transactionsListProvider(filter)),
                isEmpty: (TransactionListState s) => s.items.isEmpty,
                empty: filter.isEmpty
                    ? MessageStateView(
                        icon: Icons.receipt_long_outlined,
                        title: l10n.transactionsEmptyTitle,
                        body: l10n.transactionsEmptyBody,
                        action: FilledButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.newTransactionOf('expense'),
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.transactionAddFirst),
                        ),
                      )
                    : MessageStateView(
                        icon: Icons.filter_alt_off_outlined,
                        title: l10n.transactionsNoMatchTitle,
                        body: l10n.transactionsNoMatchBody,
                        action: OutlinedButton.icon(
                          onPressed: () => _go(filter.cleared()),
                          icon: const Icon(Icons.clear_all),
                          label: Text(l10n.filtersClearAll),
                        ),
                      ),
                data: (TransactionListState state) => RefreshIndicator(
                  onRefresh: () => ref
                      .read(transactionsListProvider(filter).notifier)
                      .refresh(),
                  child: _list(context, state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _normalBar(BuildContext context, String? merchantName) {
    final AppLocalizations l10n = context.l10n;
    final int active = widget.filter.activeCount;
    return AppBar(
      title: _searching
          ? TextField(
              controller: _search,
              autofocus: !widget.filter.hasQuery,
              textInputAction: TextInputAction.search,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: l10n.transactionsSearchHint,
                border: InputBorder.none,
                counterText: '',
              ),
              onChanged: _onSearchChanged,
              onSubmitted: (String v) {
                _debounce?.cancel();
                final String q = v.trim();
                _go(
                  q.isEmpty
                      ? widget.filter.copyWith(clearQuery: true)
                      : widget.filter.copyWith(query: q),
                );
              },
            )
          : Text(l10n.navTransactions),
      actions: <Widget>[
        IconButton(
          tooltip: l10n.savedFiltersOpen,
          icon: const Icon(Icons.bookmarks_outlined),
          onPressed: _openSaved,
        ),
        if (!_searching)
          IconButton(
            tooltip: l10n.recurringOpenTooltip,
            icon: const Icon(Icons.event_repeat_outlined),
            onPressed: () => context.push(AppRoutes.recurring),
          ),
        IconButton(
          tooltip: _searching ? l10n.searchClose : l10n.searchOpen,
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () {
            if (_searching) {
              _debounce?.cancel();
              _search.clear();
              setState(() => _searching = false);
              if (widget.filter.hasQuery) {
                _go(widget.filter.copyWith(clearQuery: true));
              }
            } else {
              setState(() => _searching = true);
            }
          },
        ),
        IconButton(
          tooltip: active == 0
              ? l10n.filtersTitle
              : l10n.filtersActiveTooltip(active),
          onPressed: () => _openFilters(merchantName),
          icon: Badge(
            isLabelVisible: active > 0,
            label: Text('$active'),
            child: const Icon(Icons.tune),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _selectionBar(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppBar(
      leading: IconButton(
        tooltip: l10n.selectionCancel,
        icon: const Icon(Icons.close),
        onPressed: () => setState(_selected.clear),
      ),
      title: Semantics(
        liveRegion: true,
        child: Text(l10n.selectionCount(_selected.length)),
      ),
      bottom: _bulkBusy
          ? const PreferredSize(
              preferredSize: Size.fromHeight(4),
              child: LinearProgressIndicator(),
            )
          : null,
      actions: <Widget>[
        IconButton(
          tooltip: l10n.bulkEditTitle,
          icon: const Icon(Icons.edit_outlined),
          onPressed: _bulkBusy ? null : _bulkEdit,
        ),
        IconButton(
          tooltip: l10n.bulkDeleteTooltip,
          icon: const Icon(Icons.delete_outline),
          onPressed: _bulkBusy ? null : _bulkDelete,
        ),
      ],
    );
  }

  Widget _list(BuildContext context, TransactionListState state) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final bool byDate =
        widget.filter.sort == 'date_desc' || widget.filter.sort == 'date_asc';
    final List<Widget> rows = <Widget>[];
    String? lastDate;
    for (final TransactionDto t in state.items) {
      if (byDate && t.localDate != lastDate) {
        lastDate = t.localDate;
        rows.add(
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
                LocalDates.displayLong(t.localDate, locale: locale),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        );
      }
      rows.add(
        TransactionTile(
          transaction: t,
          showDate: !byDate,
          selected: _selecting ? _selected.contains(t.id) : null,
          onTap: _selecting
              ? () => _toggle(t)
              : () => context.push(AppRoutes.transactionDetail(t.id)),
          onLongPress: _selecting ? null : () => _toggle(t),
        ),
      );
    }
    final Object? loadError = state.loadMoreError;
    rows.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, 96),
        child: state.loadingMore
            ? LoadingStateView(label: l10n.loadingMore)
            : loadError != null
            ? NoticeBanner(
                tone: NoticeTone.error,
                message: describeError(l10n, loadError),
                action: OutlinedButton(
                  onPressed: () => ref
                      .read(transactionsListProvider(widget.filter).notifier)
                      .loadMore(),
                  child: Text(l10n.actionRetry),
                ),
              )
            : state.hasMore
            ? OutlinedButton(
                onPressed: () => ref
                    .read(transactionsListProvider(widget.filter).notifier)
                    .loadMore(),
                child: Text(l10n.actionLoadMore),
              )
            : Text(
                l10n.transactionsEnd(state.items.length),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      children: rows,
    );
  }
}

class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({
    required this.filter,
    required this.merchantName,
    required this.onChanged,
  });

  final TransactionFilter filter;
  final String? merchantName;
  final ValueChanged<TransactionFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final List<TagDto> tags = ref.watch(tagsProvider).value ?? <TagDto>[];
    final Map<String, PaymentMethodDto> methods = ref.watch(
      paymentMethodIndexProvider,
    );
    String names(
      Set<String> ids,
      String? Function(String id) nameOf,
      String Function(int n) many,
    ) => ids.length == 1
        ? (nameOf(ids.first) ?? l10n.filterOneSelected)
        : many(ids.length);
    final List<(String, TransactionFilter)>
    chips = <(String, TransactionFilter)>[
      if (filter.range != null || filter.from != null || filter.to != null)
        (
          rangeChoiceLabel(
            l10n,
            DateRangeChoice(
              range: filter.range,
              from: filter.from,
              to: filter.to,
            ),
            locale: locale,
          ),
          filter.copyWith(clearDates: true),
        ),
      if (filter.types.isNotEmpty)
        (
          filter.types
              .map(
                (String t) =>
                    transactionTypeLabel(l10n, TransactionDtoType.fromJson(t)),
              )
              .join(', '),
          filter.copyWith(types: <String>{}),
        ),
      if (filter.direction != null)
        (
          filter.direction == 'inflow' ? l10n.directionIn : l10n.directionOut,
          filter.copyWith(clearDirection: true),
        ),
      if (filter.accountIds.isNotEmpty)
        (
          names(
            filter.accountIds,
            (String id) => accounts[id]?.name,
            l10n.filterAccountsCount,
          ),
          filter.copyWith(accountIds: <String>{}),
        ),
      if (filter.categoryIds.isNotEmpty)
        (
          names(
            filter.categoryIds,
            (String id) => categories[id] == null
                ? null
                : categoryName(l10n, categories[id]!),
            l10n.filterCategoriesCount,
          ),
          filter.copyWith(categoryIds: <String>{}),
        ),
      if (filter.uncategorized)
        (l10n.filterUncategorized, filter.copyWith(uncategorized: false)),
      if (filter.tagIds.isNotEmpty)
        (
          names(
            filter.tagIds,
            (String id) =>
                tags.where((TagDto t) => t.id == id).firstOrNull?.name,
            l10n.filterTagsCount,
          ),
          filter.copyWith(tagIds: <String>{}),
        ),
      if (filter.merchantId != null)
        (
          merchantName ?? l10n.filterMerchant,
          filter.copyWith(clearMerchant: true),
        ),
      if (filter.paymentMethodId != null)
        (
          filter.withoutPaymentMethod
              ? l10n.paymentNone
              : methods[filter.paymentMethodId]?.label ??
                    l10n.filterPaymentMethod,
          filter.copyWith(clearPaymentMethod: true),
        ),
      if (filter.minAmount != null || filter.maxAmount != null)
        (
          l10n.filterAmountChip(
            filter.minAmount ?? '…',
            filter.maxAmount ?? '…',
            filter.currency ?? '',
          ),
          filter.copyWith(clearAmounts: true),
        ),
      if (filter.status != null)
        (
          statusFilterLabel(l10n, filter.status),
          filter.copyWith(clearStatus: true),
        ),
      if (filter.source != null)
        (
          transactionSourceLabel(l10n, filter.source!),
          filter.copyWith(clearSource: true),
        ),
      if (filter.reconciliationState != null)
        (
          reconciliationLabel(
            l10n,
            TransactionDtoReconciliationState.fromJson(
              filter.reconciliationState!,
            ),
          ),
          filter.copyWith(clearReconciliation: true),
        ),
      if (filter.hasAttachment != null)
        (
          filter.hasAttachment == 'true'
              ? l10n.filterWithAttachments
              : l10n.filterWithoutAttachments,
          filter.copyWith(clearHasAttachment: true),
        ),
      if (filter.recurring != null)
        (
          filter.recurring == 'true'
              ? l10n.filterRecurringOnly
              : l10n.filterNotRecurring,
          filter.copyWith(clearRecurring: true),
        ),
    ];
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.xs,
          Insets.md,
          Insets.xs,
        ),
        child: Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final (String label, TransactionFilter without) in chips)
              InputChip(
                label: Text(label),
                onDeleted: () => onChanged(without),
                deleteButtonTooltipMessage: l10n.filterRemove(label),
              ),
            ActionChip(
              avatar: const Icon(Icons.clear_all, size: 18),
              label: Text(l10n.filtersClearAll),
              onPressed: () =>
                  onChanged(filter.cleared().copyWith(query: filter.query)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line describing a saved transactions filter.
String describeSavedFilter(AppLocalizations l10n, TransactionFilter filter) =>
    <String>[
      if (filter.hasQuery) l10n.savedFiltersSearchFor(filter.query!.trim()),
      if (filter.activeCount > 0 || !filter.hasQuery)
        l10n.savedFiltersCount(filter.activeCount),
    ].join(' · ');
