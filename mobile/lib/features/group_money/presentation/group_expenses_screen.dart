import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/data/group_money_api.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';

/// A group's shared expenses, newest first, 50 at a time, with filters
/// (status, dates, who paid, category). Links to balances, payments,
/// recurring expenses and reports.
class GroupExpensesScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [groupId].
  const GroupExpensesScreen({required this.groupId, super.key});

  /// The group.
  final String groupId;

  @override
  ConsumerState<GroupExpensesScreen> createState() =>
      _GroupExpensesScreenState();
}

class _GroupExpensesScreenState extends ConsumerState<GroupExpensesScreen> {
  GroupExpenseFilter _filter = const GroupExpenseFilter();

  GroupExpensesQuery get _query => (groupId: widget.groupId, filter: _filter);

  Future<void> _refresh() async {
    ref.invalidate(groupExpensesProvider(_query));
    try {
      await ref.read(groupExpensesProvider(_query).future);
    } on Object {
      // Shown by the list state.
    }
  }

  Future<void> _pickPayer(GroupPeople people) async {
    final AppLocalizations l10n = context.l10n;
    final String? picked = await showMemberPicker(
      context,
      people: people,
      title: l10n.gxFilterPayer,
      includeFormer: true,
    );
    if (picked != null && mounted) {
      setState(() => _filter = _filter.copyWith(payerUserId: picked));
    }
  }

  Future<void> _pickCategory() async {
    final AppLocalizations l10n = context.l10n;
    final String? picked = await showOptionSheet<String>(
      context,
      title: l10n.gxFilterCategory,
      selected: _filter.categoryKey,
      options: <SheetOption<String>>[
        SheetOption<String>(
          value: 'uncategorized',
          label: l10n.categoryUncategorized,
        ),
        for (final String key in groupCategoryKeys)
          SheetOption<String>(value: key, label: groupCategoryLabel(l10n, key)),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _filter = _filter.copyWith(categoryKey: picked));
    }
  }

  Future<void> _pickDates() async {
    final AppLocalizations l10n = context.l10n;
    final DateTime now = LocalDates.today();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _filter.from == null || _filter.to == null
          ? null
          : DateTimeRange(
              start: LocalDates.parse(_filter.from)!,
              end: LocalDates.parse(_filter.to)!,
            ),
      helpText: l10n.gxFilterDates,
    );
    if (range != null && mounted) {
      setState(
        () => _filter = _filter.copyWith(
          from: LocalDates.format(range.start),
          to: LocalDates.format(range.end),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return GroupPeopleScope(
      groupId: widget.groupId,
      title: l10n.gxExpensesTitle,
      builder: _scaffold,
    );
  }

  Widget _scaffold(BuildContext context, GroupPeople people) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<PagedList<GroupExpenseDto>> list = ref.watch(
      groupExpensesProvider(_query),
    );
    final String? payer = _filter.payerUserId;
    final String? category = _filter.categoryKey;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gxExpensesTitleOf(people.group.name)),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.gxBalancesTitle,
            icon: const Icon(Icons.balance_outlined),
            onPressed: () =>
                context.push(AppRoutes.groupBalances(widget.groupId)),
          ),
          GroupMoneyMenu(
            groupId: widget.groupId,
            current: GroupMoneyPage.expenses,
          ),
        ],
      ),
      floatingActionButton: people.canWrite
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () =>
                  context.push(AppRoutes.newGroupExpense(widget.groupId)),
              icon: const Icon(Icons.add),
              label: Text(l10n.gxAddExpense),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.xs,
            ),
            child: Row(
              children: <Widget>[
                for (final (String? value, String label) in <(String?, String)>[
                  (null, l10n.gxFilterAll),
                  ('disputed', l10n.gxStatusDisputed),
                  ('deleted', l10n.gxStatusDeleted),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.xs),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter.status == value,
                      onSelected: (_) => setState(
                        () => _filter = value == null
                            ? _filter.copyWith(clearStatus: true)
                            : _filter.copyWith(status: value),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: Insets.xs),
                  child: InputChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(
                      payer == null
                          ? l10n.gxFilterPayer
                          : l10n.gxFilterPaidBy(people.name(l10n, payer)),
                    ),
                    selected: payer != null,
                    onPressed: () => _pickPayer(people),
                    onDeleted: payer == null
                        ? null
                        : () => setState(
                            () => _filter = _filter.copyWith(clearPayer: true),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: Insets.xs),
                  child: InputChip(
                    avatar: const Icon(Icons.category_outlined, size: 18),
                    label: Text(
                      category == null
                          ? l10n.gxFilterCategory
                          : groupCategoryLabel(l10n, category),
                    ),
                    selected: category != null,
                    onPressed: _pickCategory,
                    onDeleted: category == null
                        ? null
                        : () => setState(
                            () =>
                                _filter = _filter.copyWith(clearCategory: true),
                          ),
                  ),
                ),
                InputChip(
                  avatar: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    _filter.from == null
                        ? l10n.gxFilterDates
                        : LocalDates.displayRange(
                            _filter.from!,
                            _filter.to ?? _filter.from!,
                            locale: locale,
                          ),
                  ),
                  selected: _filter.from != null,
                  onPressed: _pickDates,
                  onDeleted: _filter.from == null
                      ? null
                      : () => setState(
                          () => _filter = _filter.copyWith(clearDates: true),
                        ),
                ),
              ],
            ),
          ),
          if (!people.isActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              child: Text(
                l10n.gxArchivedReadOnly,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: AsyncValueView<PagedList<GroupExpenseDto>>(
              value: list,
              onRetry: () => ref.invalidate(groupExpensesProvider(_query)),
              isEmpty: (PagedList<GroupExpenseDto> l) => l.items.isEmpty,
              empty: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  children: <Widget>[
                    MessageStateView(
                      icon: Icons.receipt_long_outlined,
                      title: _filter.isEmpty
                          ? l10n.gxExpensesEmptyTitle
                          : l10n.gxExpensesEmptyFiltered,
                      body: _filter.isEmpty ? l10n.gxExpensesEmptyBody : null,
                    ),
                  ],
                ),
              ),
              data: (PagedList<GroupExpenseDto> l) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: l.items.length + 1,
                  separatorBuilder: (BuildContext context, int i) =>
                      const Divider(height: 1),
                  itemBuilder: (BuildContext context, int i) {
                    if (i == l.items.length) {
                      return LoadMoreFooter(
                        list: l,
                        onLoadMore: () => ref
                            .read(groupExpensesProvider(_query).notifier)
                            .loadMore(),
                      );
                    }
                    return ExpenseSummaryTile(
                      expense: l.items[i],
                      people: people,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
