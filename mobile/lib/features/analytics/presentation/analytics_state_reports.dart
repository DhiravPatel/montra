import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/analytics/application/analytics_providers.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';
import 'package:montra_mobile/features/analytics/presentation/analytics_widgets.dart';
import 'package:montra_mobile/features/dashboard/presentation/dashboard_widgets.dart'
    show formatBasisPoints;
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';

/// The body of a report about the current state (not a period): each
/// currency is shown on its own, never added to another.
class StateReportBody extends ConsumerStatefulWidget {
  /// Creates the body.
  const StateReportBody({required this.report, super.key});

  /// The report.
  final AnalyticsReport report;

  @override
  ConsumerState<StateReportBody> createState() => _StateReportBodyState();
}

class _StateReportBodyState extends ConsumerState<StateReportBody> {
  bool _overviewOnly = false;

  @override
  Widget build(BuildContext context) => switch (widget.report) {
    AnalyticsReport.accounts => _view<AccountsReport>(
      analyticsAccountsProvider(_overviewOnly),
      (AccountsReport r) => _Accounts(
        report: r,
        overviewOnly: _overviewOnly,
        onOverviewOnly: (bool v) => setState(() => _overviewOnly = v),
      ),
    ),
    AnalyticsReport.budgets => _view<BudgetPerformance>(
      analyticsBudgetsProvider,
      (BudgetPerformance r) => _Budgets(report: r),
    ),
    AnalyticsReport.goals => _view<GoalReport>(
      analyticsGoalsProvider,
      (GoalReport r) => _Goals(report: r),
    ),
    AnalyticsReport.subscriptions => _view<SubscriptionSummary>(
      analyticsSubscriptionsProvider,
      (SubscriptionSummary r) => _Subscriptions(report: r),
    ),
    _ => _view<RecurringReport>(
      analyticsRecurringProvider,
      (RecurringReport r) => _Recurring(report: r),
    ),
  };

  Widget _view<T>(FutureProvider<T> provider, Widget Function(T data) builder) {
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
      loadingLabel: context.l10n.analyticsLoading,
      data: (T data) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Insets.xl),
          children: <Widget>[ContentFrame(child: builder(data))],
        ),
      ),
    );
  }
}

/// Assets, liabilities and net worth per currency.
class _Accounts extends StatelessWidget {
  const _Accounts({
    required this.report,
    required this.overviewOnly,
    required this.onOverviewOnly,
  });

  final AccountsReport report;
  final bool overviewOnly;
  final ValueChanged<bool> onOverviewOnly;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SwitchListTile(
          value: overviewOnly,
          title: Text(l10n.analyticsOverviewOnly),
          subtitle: Text(l10n.analyticsOverviewOnlyHelp),
          onChanged: onOverviewOnly,
        ),
        if (report.totals.isEmpty)
          MessageStateView(
            icon: Icons.account_balance_outlined,
            title: l10n.dashboardNoAccounts,
            action: OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.newAccount),
              icon: const Icon(Icons.add),
              label: Text(l10n.accountAdd),
            ),
          )
        else ...<Widget>[
          for (final BalanceTotals t in report.totals) ...<Widget>[
            SectionCard(
              title: l10n.currencyHeading(t.currency),
              children: <Widget>[
                AnalyticsMoneyRow(label: l10n.netWorthLabel, money: t.netWorth),
                AnalyticsMoneyRow(label: l10n.assetsLabel, money: t.assets),
                AnalyticsMoneyRow(
                  label: l10n.liabilitiesLabel,
                  money: t.liabilities,
                ),
                AnalyticsNote(l10n.dashboardAccountCount(t.accountCount)),
                const SizedBox(height: Insets.sm),
              ],
            ),
            const SizedBox(height: Insets.md),
          ],
          if (report.totals.length > 1)
            Text(
              l10n.dashboardCurrencyNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: Insets.sm),
          Text(
            l10n.trackedBalanceNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Text of a budget's pace.
String paceLabel(AppLocalizations l10n, ProgressDtoPace pace) => switch (pace) {
  ProgressDtoPace.underPace => l10n.budgetPaceUnder,
  ProgressDtoPace.onTrack => l10n.budgetPaceOnTrack,
  ProgressDtoPace.aheadOfPace => l10n.budgetPaceAhead,
  ProgressDtoPace.overBudget => l10n.budgetPaceOver,
  ProgressDtoPace.unrecognized => l10n.budgetPaceUnknown,
};

StatusTone _paceTone(ProgressDtoPace pace) => switch (pace) {
  ProgressDtoPace.overBudget ||
  ProgressDtoPace.aheadOfPace => StatusTone.caution,
  ProgressDtoPace.underPace || ProgressDtoPace.onTrack => StatusTone.positive,
  ProgressDtoPace.unrecognized => StatusTone.neutral,
};

/// Budget performance: how many are on track or over, and each budget's
/// use of its limit (in its own currency).
class _Budgets extends ConsumerWidget {
  const _Budgets({required this.report});

  final BudgetPerformance report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String numberLocale = numberLocaleOf(context, ref);
    final List<BudgetDto> tracked = <BudgetDto>[
      for (final BudgetDto b in report.budgets)
        if (b.progress != null) b,
    ];
    if (report.budgets.isEmpty) {
      return MessageStateView(
        icon: Icons.savings_outlined,
        title: l10n.analyticsBudgetsEmpty,
        action: OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.newBudget),
          icon: const Icon(Icons.add),
          label: Text(l10n.analyticsBudgetsCreate),
        ),
      );
    }
    String percent(BudgetDto b) =>
        formatBasisPoints(b.progress!.percentBp, numberLocale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: l10n.analyticsBudgetsPaceTitle,
          children: <Widget>[
            for (final ProgressDtoPace pace in <ProgressDtoPace>[
              ProgressDtoPace.onTrack,
              ProgressDtoPace.underPace,
              ProgressDtoPace.aheadOfPace,
              ProgressDtoPace.overBudget,
            ])
              DetailRow(
                label: paceLabel(l10n, pace),
                value: '${report.byPace[pace.json] ?? 0}',
              ),
            AnalyticsNote(l10n.analyticsBudgetsOverCount(report.overCount)),
            const SizedBox(height: Insets.sm),
          ],
        ),
        const SizedBox(height: Insets.md),
        if (tracked.isNotEmpty)
          SectionCard(
            title: l10n.analyticsBudgetsUseTitle,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: AccessibleChart(
                  summary: l10n.analyticsBudgetsSummary(
                    tracked.length,
                    report.overCount,
                  ),
                  chart: HorizontalBars(
                    entries: <BarEntry>[
                      for (final BudgetDto b in tracked)
                        BarEntry(
                          label: b.name,
                          valueText: l10n.budgetPercentUsed(percent(b)),
                          detail: l10n.budgetSpentOf(
                            formatMoney(context, ref, b.progress!.spent),
                            formatMoney(context, ref, b.progress!.limit),
                          ),
                          fraction: b.progress!.percentBp / 10000,
                          style: b.progress!.pace == ProgressDtoPace.overBudget
                              ? BarStyle.outlined
                              : BarStyle.filled,
                          onTap: () =>
                              context.push(AppRoutes.budgetDetail(b.id)),
                        ),
                    ],
                  ),
                  legend: Wrap(
                    spacing: Insets.md,
                    runSpacing: Insets.xs,
                    children: <Widget>[
                      LegendItem(
                        style: BarStyle.filled,
                        label: l10n.analyticsWithinLimit,
                      ),
                      LegendItem(
                        style: BarStyle.outlined,
                        label: l10n.budgetPaceOver,
                      ),
                    ],
                  ),
                  table: Column(
                    children: <Widget>[
                      for (final BudgetDto b in tracked)
                        DetailRow(
                          label: b.name,
                          value: l10n.analyticsBudgetRow(
                            formatMoney(context, ref, b.progress!.spent),
                            formatMoney(context, ref, b.progress!.limit),
                            percent(b),
                            paceLabel(l10n, b.progress!.pace),
                          ),
                          onTap: () =>
                              context.push(AppRoutes.budgetDetail(b.id)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: Insets.md),
        for (final BudgetDto b in report.budgets)
          ListTile(
            title: Text(b.name),
            subtitle: b.progress == null
                ? Text(l10n.analyticsBudgetNoProgress)
                : Padding(
                    padding: const EdgeInsets.only(top: Insets.xs),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: StatusLabel(
                        text: paceLabel(l10n, b.progress!.pace),
                        tone: _paceTone(b.progress!.pace),
                      ),
                    ),
                  ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.budgetDetail(b.id)),
          ),
      ],
    );
  }
}

String _goalStatus(AppLocalizations l10n, GoalDtoStatus status) =>
    switch (status) {
      GoalDtoStatus.active => l10n.goalStatusActive,
      GoalDtoStatus.paused => l10n.goalStatusPaused,
      GoalDtoStatus.achieved => l10n.goalStatusAchieved,
      GoalDtoStatus.cancelled => l10n.goalStatusCancelled,
      GoalDtoStatus.archived => l10n.goalStatusArchived,
      GoalDtoStatus.unrecognized => l10n.goalStatusUnknown,
    };

/// Goal progress per currency and per goal.
class _Goals extends ConsumerWidget {
  const _Goals({required this.report});

  final GoalReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String numberLocale = numberLocaleOf(context, ref);
    if (report.goals.isEmpty) {
      return MessageStateView(
        icon: Icons.flag_outlined,
        title: l10n.analyticsGoalsEmpty,
        action: OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.newGoal),
          icon: const Icon(Icons.add),
          label: Text(l10n.analyticsGoalsCreate),
        ),
      );
    }
    String percent(GoalDto g) =>
        formatBasisPoints(g.progress.percentBp, numberLocale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final GoalTotal t in report.totals) ...<Widget>[
          SectionCard(
            title: l10n.currencyHeading(t.currency),
            children: <Widget>[
              AnalyticsMoneyRow(label: l10n.goalSavedLabel, money: t.saved),
              AnalyticsMoneyRow(label: l10n.goalTargetLabel, money: t.target),
              AnalyticsNote(l10n.analyticsGoalsCount(t.count, t.achieved)),
              const SizedBox(height: Insets.sm),
            ],
          ),
          const SizedBox(height: Insets.md),
        ],
        SectionCard(
          title: l10n.analyticsGoalsProgressTitle,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: AccessibleChart(
                summary: l10n.analyticsGoalsSummary(report.goals.length),
                chart: HorizontalBars(
                  entries: <BarEntry>[
                    for (final GoalDto g in report.goals)
                      BarEntry(
                        label: g.name,
                        valueText: percent(g),
                        detail: l10n.goalSavedOfTarget(
                          formatMoney(context, ref, g.progress.saved),
                          formatMoney(context, ref, g.target),
                        ),
                        fraction: g.progress.percentBp / 10000,
                        onTap: () => context.push(AppRoutes.goalDetail(g.id)),
                      ),
                  ],
                ),
                table: Column(
                  children: <Widget>[
                    for (final GoalDto g in report.goals)
                      DetailRow(
                        label: g.name,
                        value: l10n.analyticsGoalRow(
                          formatMoney(context, ref, g.progress.saved),
                          formatMoney(context, ref, g.target),
                          percent(g),
                          _goalStatus(l10n, g.status),
                        ),
                        onTap: () => context.push(AppRoutes.goalDetail(g.id)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Subscription costs per currency, upcoming renewals and trials.
class _Subscriptions extends ConsumerWidget {
  const _Subscriptions({required this.report});

  final SubscriptionSummary report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    if (report.totals.isEmpty && report.pendingDetections == 0) {
      return MessageStateView(
        icon: Icons.subscriptions_outlined,
        title: l10n.analyticsSubscriptionsEmpty,
        action: OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.newSubscription),
          icon: const Icon(Icons.add),
          label: Text(l10n.analyticsSubscriptionsCreate),
        ),
      );
    }
    Widget tile(SubscriptionDto s, String when) => ListTile(
      title: Text(s.name),
      subtitle: Text(when),
      trailing: MoneyText(s.amount),
      onTap: () => context.push(AppRoutes.subscriptionDetail(s.id)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final SubscriptionCostTotal t in report.totals) ...<Widget>[
          SectionCard(
            title: l10n.subscriptionTotalCount(t.count, t.currency),
            children: <Widget>[
              AnalyticsMoneyRow(
                label: l10n.subscriptionMonthlyCost,
                money: t.monthly,
              ),
              AnalyticsMoneyRow(
                label: l10n.subscriptionAnnualCost,
                money: t.annual,
              ),
              const SizedBox(height: Insets.sm),
            ],
          ),
          const SizedBox(height: Insets.md),
        ],
        if (report.totals.isNotEmpty) ...<Widget>[
          Text(
            l10n.subscriptionTotalsNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Insets.md),
        ],
        if (report.pendingDetections > 0) ...<Widget>[
          Card(
            child: ListTile(
              leading: const ExcludeSemantics(child: Icon(Icons.search)),
              title: Text(
                l10n.subscriptionDetectionsPending(report.pendingDetections),
              ),
              subtitle: Text(l10n.subscriptionDetectionsReview),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.subscriptionDetections),
            ),
          ),
          const SizedBox(height: Insets.md),
        ],
        if (report.trialsEndingSoon.isNotEmpty) ...<Widget>[
          SectionCard(
            title: l10n.subscriptionTrialsTitle,
            children: <Widget>[
              for (final SubscriptionDto s in report.trialsEndingSoon)
                tile(
                  s,
                  s.trialEndsOn == null
                      ? ''
                      : l10n.subscriptionTrialEnds(
                          LocalDates.display(s.trialEndsOn!, locale: locale),
                        ),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
        ],
        SectionCard(
          title: l10n.subscriptionRenewalsTitle,
          children: <Widget>[
            if (report.upcomingRenewals.isEmpty)
              AnalyticsEmpty(l10n.analyticsNoRenewals)
            else
              for (final SubscriptionDto s in report.upcomingRenewals)
                tile(
                  s,
                  s.nextRenewalDate == null
                      ? ''
                      : l10n.subscriptionRenews(
                          LocalDates.display(
                            s.nextRenewalDate!,
                            locale: locale,
                          ),
                        ),
                ),
          ],
        ),
      ],
    );
  }
}

/// The localized note of a recurring report (server English otherwise).
String recurringNote(AppLocalizations l10n, RecurringReport report) =>
    switch (report.noteCode) {
      RecurringReportNoteCode.fixedAmountsExpectations =>
        l10n.analyticsRecurringNote,
      RecurringReportNoteCode.unrecognized => report.note,
    };

/// Recurring commitments per month, each currency on its own.
class _Recurring extends ConsumerWidget {
  const _Recurring({required this.report});

  final RecurringReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    if (report.commitments.isEmpty) {
      return MessageStateView(
        icon: Icons.event_repeat_outlined,
        title: l10n.analyticsRecurringEmpty,
        body: recurringNote(l10n, report),
        action: OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.newRecurring),
          icon: const Icon(Icons.add),
          label: Text(l10n.analyticsRecurringCreate),
        ),
      );
    }
    final List<String> currencies = orderCurrencies(<String>[
      for (final RecurringCommitment c in report.commitments) c.currency,
    ], ref.watch(analyticsBaseCurrencyProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          recurringNote(l10n, report),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Insets.md),
        for (final String currency in currencies) ...<Widget>[
          _RecurringCurrency(
            currency: currency,
            commitments: <RecurringCommitment>[
              for (final RecurringCommitment c in report.commitments)
                if (c.currency == currency) c,
            ],
          ),
          const SizedBox(height: Insets.md),
        ],
        if (currencies.length > 1)
          Text(
            l10n.dashboardCurrencyNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _RecurringCurrency extends ConsumerWidget {
  const _RecurringCurrency({required this.currency, required this.commitments});

  final String currency;
  final List<RecurringCommitment> commitments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    int max = 0;
    RecurringCommitment top = commitments.first;
    for (final RecurringCommitment c in commitments) {
      if (c.monthlyEquivalent.amountMinor > max) {
        max = c.monthlyEquivalent.amountMinor;
        top = c;
      }
    }
    return SectionCard(
      title: l10n.currencyHeading(currency),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.sm),
          child: AccessibleChart(
            summary: l10n.analyticsRecurringSummary(
              commitmentKindLabel(l10n, top.kind),
              formatMoney(context, ref, top.monthlyEquivalent),
            ),
            chart: HorizontalBars(
              entries: <BarEntry>[
                for (final RecurringCommitment c in commitments)
                  BarEntry(
                    label: commitmentKindLabel(l10n, c.kind),
                    valueText: l10n.analyticsPerMonth(
                      formatMoney(context, ref, c.monthlyEquivalent),
                    ),
                    detail: l10n.analyticsRecurringRules(c.ruleCount),
                    fraction: barFraction(c.monthlyEquivalent.amountMinor, max),
                    style: c.kind == RecurringCommitmentKind.income
                        ? BarStyle.filled
                        : BarStyle.outlined,
                  ),
              ],
            ),
            legend: Wrap(
              spacing: Insets.md,
              runSpacing: Insets.xs,
              children: <Widget>[
                LegendItem(
                  style: BarStyle.filled,
                  label: l10n.recurringKindIncome,
                ),
                LegendItem(style: BarStyle.outlined, label: l10n.directionOut),
              ],
            ),
            table: Column(
              children: <Widget>[
                for (final RecurringCommitment c in commitments)
                  DetailRow(
                    label: commitmentKindLabel(l10n, c.kind),
                    value: l10n.analyticsPerMonth(
                      formatMoney(context, ref, c.monthlyEquivalent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final RecurringCommitment c in commitments) ...<Widget>[
          AnalyticsMoneyRow(
            label: l10n.analyticsNext30Days(commitmentKindLabel(l10n, c.kind)),
            money: c.next30Days,
          ),
          if (c.variableCount > 0)
            AnalyticsNote(l10n.analyticsVariableRules(c.variableCount)),
        ],
        const SizedBox(height: Insets.sm),
      ],
    );
  }
}
