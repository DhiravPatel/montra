import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/money_formatter.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_widgets.dart';
import 'package:montra_mobile/features/labels/application/labels_providers.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/domain/label_display.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';
import 'package:montra_mobile/features/transactions/presentation/transaction_tile.dart';

/// The calendar day before [date] (`YYYY-MM-DD`), or null if unreadable.
String? dayBefore(String date) {
  final DateTime? d = LocalDates.parse(date);
  return d == null
      ? null
      : LocalDates.format(DateTime(d.year, d.month, d.day - 1));
}

/// Member names of [budget] by user ID, with the group's members for
/// group budgets.
Map<String, String> budgetMemberNames(WidgetRef ref, BudgetDto budget) {
  final String? group = budget.groupId;
  return <String, String>{
    if (group != null)
      for (final GroupMemberDto m
          in ref.watch(groupMembersProvider(group)).value ??
              const <GroupMemberDto>[])
        m.userId: m.displayName,
    for (final MemberDto m in budget.members) m.userId: m.displayName,
  };
}

/// An exact amount string in [currency], formatted for [locale] (the
/// amount and code as they are when the currency is unknown here).
String formatAmountText(String amount, String currency, String locale) {
  try {
    return MoneyFormatter.formatAmount(amount, currency, locale: locale);
  } on FormatException {
    return '$amount $currency';
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

/// Type, period, status and this period's progress.
class BudgetSummaryCard extends ConsumerWidget {
  /// Creates the card.
  const BudgetSummaryCard({required this.budget, super.key});

  /// The budget.
  final BudgetDto budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).toString();
    final ProgressDto? progress = budget.progress;
    final String? groupId = budget.groupId;
    final String? groupName = groupId == null
        ? null
        : ref.watch(groupIndexProvider)[groupId]?.name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              budgetSubtitle(l10n, budget, groupName: groupName),
              style: text.bodyMedium,
            ),
            if (budget.status != BudgetDtoStatus.active) ...<Widget>[
              const SizedBox(height: Insets.sm),
              StatusLabel(
                text: budgetStatusLabel(l10n, budget.status),
                icon: budget.status == BudgetDtoStatus.paused
                    ? Icons.pause_circle_outline
                    : Icons.inventory_2_outlined,
              ),
            ],
            if (progress != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              Semantics(
                header: true,
                child: Text(l10n.budgetThisPeriod, style: text.titleSmall),
              ),
              Text(
                '${LocalDates.displayRange(progress.periodStart, progress.periodEnd, locale: locale)}'
                ' · ${l10n.budgetDayOf(progress.elapsedDays, progress.totalDays)}',
                style: text.bodySmall,
              ),
              const SizedBox(height: Insets.sm),
              BudgetProgressSummary(progress: progress),
            ],
          ],
        ),
      ),
    );
  }
}

/// The figures behind this period's progress and how they are calculated.
class BudgetProgressDetailsCard extends ConsumerWidget {
  /// Creates the card.
  const BudgetProgressDetailsCard({required this.budget, super.key});

  /// The budget (with progress).
  final BudgetDto budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ProgressDto? progress = budget.progress;
    if (progress == null) {
      return const SizedBox.shrink();
    }
    final String locale = Localizations.localeOf(context).toString();
    final String numberLocale = numberLocaleOf(context, ref);
    final bool over = progress.overspent.amountMinor > 0;
    final DateTime? asOf = progress.asOf;
    final List<String> notes = budgetExplanation(
      l10n,
      budget: budget,
      progress: progress,
      money: (String amount, String currency) =>
          formatAmountText(amount, currency, numberLocale),
      date: (String d) => LocalDates.display(d, locale: locale),
    );
    return SectionCard(
      title: l10n.budgetThisPeriod,
      children: <Widget>[
        if (over)
          _MoneyRow(label: l10n.budgetOverspentLabel, money: progress.overspent)
        else
          _MoneyRow(
            label: l10n.budgetRemainingLabel,
            money: progress.remaining,
          ),
        if (!over && progress.elapsedDays < progress.totalDays)
          _MoneyRow(
            label: l10n.budgetDailyAllowanceLabel,
            money: progress.dailyAllowance,
          ),
        _MoneyRow(
          label: l10n.budgetExpectedByNowLabel,
          money: progress.expectedByNow,
        ),
        _MoneyRow(label: l10n.budgetProjectedLabel, money: progress.projected),
        if (progress.projectedOver.amountMinor > 0)
          _MoneyRow(
            label: l10n.budgetProjectedOverLabel,
            money: progress.projectedOver,
          ),
        if (progress.rolloverIn.amountMinor != 0) ...<Widget>[
          _MoneyRow(
            label: l10n.budgetBaseLimitLabel,
            money: progress.baseLimit,
          ),
          _MoneyRow(
            label: l10n.budgetRolloverInLabel,
            money: progress.rolloverIn,
          ),
        ],
        DetailRow(
          label: l10n.budgetCountedLabel,
          value: '${progress.transactionCount}',
        ),
        if (asOf != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              0,
            ),
            child: Text(
              l10n.budgetAsOf(formatDateTime(asOf, locale: locale)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ExpansionTile(
          title: Text(l10n.budgetHowCalculated),
          childrenPadding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.md,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final String note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.xs),
                child: Text('• $note'),
              ),
          ],
        ),
      ],
    );
  }
}

/// A period and the one before it side by side, with buttons to step
/// through earlier periods.
class BudgetHistoryCard extends ConsumerWidget {
  /// Creates the card for the period containing [date] (null: current).
  const BudgetHistoryCard({
    required this.budget,
    required this.date,
    required this.onEarlier,
    required this.onLater,
    super.key,
  });

  /// The budget.
  final BudgetDto budget;

  /// A day inside the period shown, or null for the current one.
  final String? date;

  /// Shows the period containing the given day.
  final ValueChanged<String> onEarlier;

  /// Goes back toward the current period; null when it is shown.
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final BudgetPeriodKey key = (budgetId: budget.id, date: date);
    final AsyncValue<List<ProgressDto>> history = ref.watch(
      budgetHistoryProvider(key),
    );
    final List<ProgressDto>? data = history.value;
    return SectionCard(
      title: l10n.budgetHistoryTitle,
      children: <Widget>[
        if (history.hasError && !history.isLoading)
          SizedBox(
            height: 260,
            child: ErrorStateView(
              error: history.error!,
              onRetry: () => ref.invalidate(budgetHistoryProvider(key)),
            ),
          )
        else if (data != null)
          _content(context, ref, data)
        else
          const SizedBox(height: 120, child: LoadingStateView()),
      ],
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, List<ProgressDto> data) {
    final AppLocalizations l10n = context.l10n;
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Text(l10n.budgetHistoryEmpty),
      );
    }
    final String locale = Localizations.localeOf(context).toString();
    final String numberLocale = numberLocaleOf(context, ref);
    final ProgressDto shown = data.first;
    String range(ProgressDto p) =>
        LocalDates.displayRange(p.periodStart, p.periodEnd, locale: locale);
    final bool custom = budget.period == BudgetDtoPeriod.custom;
    final String? earlier = dayBefore(shown.periodStart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!custom)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: l10n.budgetHistoryEarlier,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: earlier == null ? null : () => onEarlier(earlier),
                ),
                Expanded(
                  child: Text(
                    range(shown),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.budgetHistoryLater,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onLater,
                ),
              ],
            ),
          ),
        AccessibleChart(
          summary: <String>[
            for (final ProgressDto p in data)
              l10n.budgetHistoryRow(
                range(p),
                formatMoneyText(p.spent, numberLocale),
                formatMoneyText(p.limit, numberLocale),
              ),
          ].join(' '),
          chart: HorizontalBars(
            entries: <BarEntry>[
              for (final ProgressDto p in data)
                BarEntry(
                  label: range(p),
                  valueText: budgetPercent(p.percentBp, numberLocale),
                  fraction: budgetBarFraction(p.percentBp),
                  detail: l10n.budgetSpentOf(
                    formatMoneyText(p.spent, numberLocale),
                    formatMoneyText(p.limit, numberLocale),
                  ),
                  style: identical(p, shown)
                      ? BarStyle.filled
                      : BarStyle.outlined,
                ),
            ],
          ),
          table: Column(
            children: <Widget>[
              for (final ProgressDto p in data)
                ListTile(
                  title: Text(range(p)),
                  subtitle: Text(
                    '${l10n.budgetSpentOf(formatMoneyText(p.spent, numberLocale), formatMoneyText(p.limit, numberLocale))}'
                    ' · ${l10n.budgetPercentUsed(budgetPercent(p.percentBp, numberLocale))}'
                    ' · ${budgetPaceLabel(l10n, p.pace)}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The transactions counted in the period shown, page by page with "Load
/// more" (owner only; collaborators see the totals; group budgets count
/// group expenses instead).
class BudgetTransactionsCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const BudgetTransactionsCard({
    required this.budget,
    required this.date,
    super.key,
  });

  /// The budget.
  final BudgetDto budget;

  /// A day inside the period shown, or null for the current one.
  final String? date;

  @override
  ConsumerState<BudgetTransactionsCard> createState() =>
      _BudgetTransactionsCardState();
}

class _BudgetTransactionsCardState
    extends ConsumerState<BudgetTransactionsCard> {
  static const int _preview = 5;

  bool _expanded = false;

  Widget _note(String text) =>
      Padding(padding: const EdgeInsets.all(Insets.md), child: Text(text));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final BudgetDto budget = widget.budget;
    if (budget.groupId != null) {
      return SectionCard(
        title: l10n.budgetTransactionsTitle,
        children: <Widget>[_note(l10n.budgetTransactionsGroup)],
      );
    }
    if (budget.access != BudgetDtoAccess.owner) {
      return SectionCard(
        title: l10n.budgetTransactionsTitle,
        children: <Widget>[_note(l10n.budgetTransactionsOwnerOnly)],
      );
    }
    final BudgetPeriodKey key = (budgetId: budget.id, date: widget.date);
    final AsyncValue<PagedList<TransactionDto>> list = ref.watch(
      budgetTransactionsProvider(key),
    );
    final PagedList<TransactionDto>? data = list.value;
    final Object? error = list.error;
    final int? total = widget.date == null
        ? budget.progress?.transactionCount
        : null;
    return SectionCard(
      title: l10n.budgetTransactionsTitle,
      children: <Widget>[
        if (error is ApiException && error.isPermissionDenied)
          _note(l10n.budgetTransactionsOwnerOnlyError)
        else if (list.hasError && !list.isLoading)
          SizedBox(
            height: 260,
            child: ErrorStateView(
              error: error!,
              onRetry: () => ref.invalidate(budgetTransactionsProvider(key)),
            ),
          )
        else if (data == null)
          const SizedBox(height: 120, child: LoadingStateView())
        else if (data.items.isEmpty)
          _note(l10n.budgetTransactionsEmpty)
        else ...<Widget>[
          for (final TransactionDto t
              in _expanded ? data.items : data.items.take(_preview))
            TransactionTile(
              transaction: t,
              onTap: () => context.push(AppRoutes.transactionDetail(t.id)),
            ),
          if (!_expanded && (data.items.length > _preview || data.hasMore))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                child: TextButton(
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(
                    l10n.budgetTransactionsShowAll(total ?? data.items.length),
                  ),
                ),
              ),
            ),
          if (_expanded) ...<Widget>[
            if (total != null && data.hasMore)
              _note(l10n.budgetTransactionsShowing(data.items.length, total)),
            LoadMoreFooter(
              list: data,
              onLoadMore: () =>
                  ref.read(budgetTransactionsProvider(key).notifier).loadMore(),
            ),
          ],
        ],
      ],
    );
  }
}

/// The allocations (sub-limits or envelopes) with their own progress.
class BudgetAllocationsCard extends ConsumerWidget {
  /// Creates the card.
  const BudgetAllocationsCard({required this.budget, super.key});

  /// The budget.
  final BudgetDto budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<AllocationDto> allocations = budget.allocations;
    if (allocations.isEmpty) {
      return const SizedBox.shrink();
    }
    final String numberLocale = numberLocaleOf(context, ref);
    final Map<String, String> names = budgetMemberNames(ref, budget);
    final BudgetInputBudgetType type = budgetInputType(budget.budgetType);
    final bool envelopes =
        type == BudgetInputBudgetType.envelope ||
        type == BudgetInputBudgetType.zeroBased;
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      title: envelopes
          ? l10n.budgetEnvelopesTitle
          : l10n.budgetAllocationsTitle,
      children: <Widget>[
        for (final AllocationDto a in allocations)
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                Insets.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AllocationTitle(
                    label: a.label,
                    categoryId: a.categoryId,
                    merchantId: a.merchantId,
                    accountId: a.accountId,
                    memberUserId: a.memberUserId,
                    memberNames: names,
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: Insets.xs),
                  Builder(
                    builder: (BuildContext context) {
                      final SpokenMoney spent = spokenMoney(
                        context,
                        ref,
                        a.spent,
                      );
                      final SpokenMoney limit = spokenMoney(
                        context,
                        ref,
                        a.limit,
                      );
                      return Text(
                        l10n.budgetAllocationValue(spent.text, limit.text),
                        semanticsLabel: l10n.budgetAllocationValue(
                          spent.spoken,
                          limit.spoken,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: Insets.xs),
                  BudgetProgressBar(
                    basisPoints: a.percentBp,
                    over: a.overspent.amountMinor > 0,
                  ),
                  const SizedBox(height: Insets.xs),
                  Builder(
                    builder: (BuildContext context) {
                      final bool over = a.overspent.amountMinor > 0;
                      final SpokenMoney rest = spokenMoney(
                        context,
                        ref,
                        over ? a.overspent : a.remaining,
                      );
                      final String used = l10n.budgetPercentUsed(
                        budgetPercent(a.percentBp, numberLocale),
                      );
                      return Text(
                        over
                            ? '$used · ${l10n.budgetOverBy(rest.text)}'
                            : '$used · ${l10n.budgetLeft(rest.text)}',
                        semanticsLabel: over
                            ? '$used · ${l10n.budgetOverBy(rest.spoken)}'
                            : '$used · ${l10n.budgetLeft(rest.spoken)}',
                        style: text.bodySmall,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The people the budget is shared with, and sharing actions.
class BudgetMembersCard extends ConsumerWidget {
  /// Creates the card.
  const BudgetMembersCard({
    required this.budget,
    required this.onAdd,
    required this.onEdit,
    required this.onLeave,
    super.key,
  });

  /// The budget.
  final BudgetDto budget;

  /// Shares with someone new (owner), or null when not possible.
  final VoidCallback? onAdd;

  /// Changes a member (owner), or null when not possible.
  final ValueChanged<MemberDto>? onEdit;

  /// Leaves the budget (a member), or null when not possible.
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<MemberDto> members = budget.members;
    final bool owner = budget.access == BudgetDtoAccess.owner;
    final String numberLocale = numberLocaleOf(context, ref);
    final ValueChanged<MemberDto>? edit = onEdit;
    return SectionCard(
      title: l10n.budgetMembersTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.sm,
          ),
          child: Text(
            owner
                ? (members.isEmpty
                      ? (budget.groupId != null
                            ? l10n.budgetMembersGroupNote
                            : l10n.budgetMembersEmpty)
                      : l10n.budgetYouOwn)
                : (budgetSharedByLabel(l10n, budget) ??
                      l10n.budgetAccessViewer),
          ),
        ),
        for (final MemberDto m in members)
          ListTile(
            leading: InitialsAvatar(name: m.displayName),
            title: Text(m.displayName),
            subtitle: Text(
              <String>[
                budgetRoleLabel(l10n, m.role),
                if (m.allocation case final Money share)
                  l10n.budgetMemberShare(formatMoneyText(share, numberLocale)),
              ].join(' · '),
            ),
            trailing: edit == null ? null : const Icon(Icons.chevron_right),
            onTap: edit == null ? null : () => edit(m),
          ),
        if (onAdd != null || onLeave != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              Insets.sm,
            ),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                if (onAdd != null)
                  OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.person_add_alt_outlined),
                    label: Text(l10n.budgetMemberAdd),
                  ),
                if (onLeave != null)
                  OutlinedButton.icon(
                    onPressed: onLeave,
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.budgetLeave),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Every setting of the budget, as stored.
class BudgetSettingsCard extends ConsumerWidget {
  /// Creates the card.
  const BudgetSettingsCard({required this.budget, super.key});

  /// The budget.
  final BudgetDto budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final bool group = budget.groupId != null;
    final BudgetInputBudgetType type = budgetInputType(budget.budgetType);
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final Map<String, CategoryDto> categories = ref.watch(
      categoryIndexProvider,
    );
    final List<String> accountIds = budget.includedAccountIds;
    final List<String> excluded = budget.excludedCategoryIds;
    final List<String> merchants = budget.merchantIds;
    final List<int> thresholds = budget.alertThresholds;
    final String? groupId = budget.groupId;
    final Money? cap = budget.rolloverCap;
    final String? notes = budget.notes;
    String onOff(bool v) => v ? l10n.statusOn : l10n.statusOff;
    return SectionCard(
      title: l10n.budgetSettingsTitle,
      children: <Widget>[
        DetailRow(
          label: l10n.budgetTypeLabel,
          value: budgetTypeLabel(l10n, type),
        ),
        DetailRow(
          label: l10n.budgetPeriodLabel,
          value: budgetPeriodLabel(l10n, budgetInputPeriod(budget.period)),
        ),
        DetailRow(
          label: l10n.budgetStartsOnLabel,
          value: LocalDates.display(budget.startsOn, locale: locale),
        ),
        if (budget.endsOn case final String ends)
          DetailRow(
            label: l10n.budgetEndsOnLabel,
            value: LocalDates.display(ends, locale: locale),
          ),
        _MoneyRow(label: l10n.budgetLimitLabel, money: budget.limit),
        if (budget.period != BudgetDtoPeriod.custom)
          DetailRow(
            label: l10n.budgetRolloverLabel,
            value: budgetRolloverLabel(
              l10n,
              budgetInputRollover(budget.rolloverPolicy),
            ),
          ),
        if (cap != null &&
            budget.rolloverPolicy != BudgetDtoRolloverPolicy.none)
          _MoneyRow(label: l10n.budgetRolloverCapLabel, money: cap),
        if (groupId != null) ...<Widget>[
          DetailRow(
            label: l10n.budgetGroupField,
            value:
                ref.watch(groupIndexProvider)[groupId]?.name ??
                l10n.budgetGroupUnknown,
          ),
          DetailRow(
            label: l10n.budgetVisibilityLabel,
            value: budget.visibility == BudgetDtoVisibility.members
                ? l10n.budgetVisibilityMembers
                : l10n.budgetVisibilityPrivate,
          ),
        ],
        if (!group) ...<Widget>[
          if (type == BudgetInputBudgetType.merchant)
            DetailRow(
              label: l10n.budgetMerchantsLabel,
              value: <String>[
                for (final String id in merchants)
                  ref.watch(budgetMerchantProvider(id)).value?.name ??
                      l10n.loadingLabel,
              ].join(', '),
            ),
          DetailRow(
            label: l10n.budgetAccountsLabel,
            value: accountIds.isEmpty
                ? l10n.budgetAccountsAll
                : <String>[
                    for (final String id in accountIds)
                      accounts[id]?.name ?? l10n.budgetAllocationRemoved,
                  ].join(', '),
          ),
          DetailRow(
            label: l10n.budgetExcludedLabel,
            value: excluded.isEmpty
                ? l10n.budgetNothingExcluded
                : <String>[
                    for (final String id in excluded)
                      if (categories[id] case final CategoryDto c)
                        categoryName(l10n, c)
                      else
                        l10n.budgetAllocationRemoved,
                  ].join(', '),
          ),
          DetailRow(
            label: l10n.budgetIncludePending,
            value: onOff(budget.includePending),
          ),
          DetailRow(
            label: l10n.budgetRefundsRestore,
            value: onOff(budget.refundsRestore),
          ),
          DetailRow(
            label: l10n.budgetCountGroupShares,
            value: onOff(budget.countGroupShares),
          ),
        ],
        DetailRow(
          label: l10n.budgetThresholdsShort,
          value: thresholds.isEmpty
              ? l10n.budgetThresholdsNone
              : (List<int>.of(
                  thresholds,
                )..sort()).map(l10n.budgetThresholdValue).join(', '),
        ),
        DetailRow(
          label: l10n.budgetForecastShort,
          value: onOff(budget.alertForecast),
        ),
        DetailRow(label: l10n.budgetTimezoneLabel, value: budget.timezone),
        if (notes != null && notes.isNotEmpty)
          DetailRow(label: l10n.notesLabel, value: notes),
      ],
    );
  }
}

/// The budget's active alerts (`GET /budget-alerts?budget_id=`), with a
/// link to every alert. Nothing is shown when there are none or they
/// cannot be read (the alerts screen has them too).
class BudgetOwnAlerts extends ConsumerWidget {
  /// Creates the section for [budgetId].
  const BudgetOwnAlerts({required this.budgetId, super.key});

  /// The budget.
  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<AlertDto> alerts =
        ref.watch(budgetOwnAlertsProvider(budgetId)).value ??
        const <AlertDto>[];
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: SectionCard(
        title: l10n.budgetOwnAlertsTitle(alerts.length),
        children: <Widget>[
          for (final AlertDto a in alerts)
            ListTile(
              leading: const ExcludeSemantics(
                child: Icon(Icons.notifications_active_outlined),
              ),
              title: Text(budgetAlertTitle(l10n, a)),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.budgetAlerts),
              child: Text(l10n.budgetAlertsBannerReview),
            ),
          ),
        ],
      ),
    );
  }
}
