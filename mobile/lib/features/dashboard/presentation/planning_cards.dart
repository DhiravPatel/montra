import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/finance/number_locale.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/analytics/domain/analytics_query.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_alert_actions.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_widgets.dart';
import 'package:montra_mobile/features/calendar/presentation/calendar_screen.dart';
import 'package:montra_mobile/features/dashboard/application/dashboard_providers.dart';
import 'package:montra_mobile/features/dashboard/domain/widget_info.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';
import 'package:montra_mobile/features/goals/presentation/goal_widgets.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';

/// Whether [planning] has anything to show for [kind] (used on first use,
/// when Home shows only the planning cards that have content).
bool planningHasContent(DashboardPlanning planning, DashboardWidgetKind kind) =>
    switch (kind) {
      DashboardWidgetKind.alerts => planning.alerts.isNotEmpty,
      DashboardWidgetKind.budgets => planning.budgets.isNotEmpty,
      DashboardWidgetKind.upcoming => planning.upcoming.isNotEmpty,
      DashboardWidgetKind.renewals => planning.renewals.isNotEmpty,
      DashboardWidgetKind.recurring => planning.recurring.isNotEmpty,
      DashboardWidgetKind.goals => planning.goals.isNotEmpty,
      DashboardWidgetKind.groupBalances => planning.groupBalances.isNotEmpty,
      _ => false,
    };

/// One planning card on Home (budget alerts, budgets, coming up,
/// renewals, recurring commitments, goals or group balances).
///
/// Every card reads the same `GET /dashboard/planning` answer
/// ([dashboardPlanningProvider]), so the seven cards cost one request. Each
/// has its own loading, empty and error state, opens its full screen and
/// says every status in words; amounts are the server's, in their own
/// currency (never added across currencies).
class PlanningCard extends ConsumerWidget {
  /// Creates the card for a planning [kind].
  const PlanningCard({required this.kind, super.key})
    : assert(
        kind == DashboardWidgetKind.alerts ||
            kind == DashboardWidgetKind.budgets ||
            kind == DashboardWidgetKind.upcoming ||
            kind == DashboardWidgetKind.renewals ||
            kind == DashboardWidgetKind.recurring ||
            kind == DashboardWidgetKind.goals ||
            kind == DashboardWidgetKind.groupBalances,
        'not a planning widget',
      );

  /// Which card.
  final DashboardWidgetKind kind;

  /// The card's full screen.
  String get _route => switch (kind) {
    DashboardWidgetKind.alerts => AppRoutes.budgetAlerts,
    DashboardWidgetKind.budgets => AppRoutes.budgets,
    DashboardWidgetKind.upcoming => AppRoutes.calendar,
    DashboardWidgetKind.renewals => AppRoutes.subscriptions,
    DashboardWidgetKind.recurring => AppRoutes.analyticsReport('recurring'),
    DashboardWidgetKind.goals => AppRoutes.goals,
    _ => AppRoutes.groups,
  };

  String _seeAll(AppLocalizations l10n) => switch (kind) {
    DashboardWidgetKind.alerts => l10n.dashPlanAlertsSeeAll,
    DashboardWidgetKind.budgets => l10n.dashPlanBudgetsSeeAll,
    DashboardWidgetKind.upcoming => l10n.dashPlanUpcomingSeeAll,
    DashboardWidgetKind.renewals => l10n.dashPlanRenewalsSeeAll,
    DashboardWidgetKind.recurring => l10n.dashPlanRecurringSeeAll,
    DashboardWidgetKind.goals => l10n.dashPlanGoalsSeeAll,
    _ => l10n.dashPlanGroupsSeeAll,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<DashboardPlanning> planning = ref.watch(
      dashboardPlanningProvider,
    );
    final DashboardPlanning? data = planning.value;
    final Widget body;
    if (data != null) {
      body = switch (kind) {
        DashboardWidgetKind.alerts => _Alerts(planning: data),
        DashboardWidgetKind.budgets => _Budgets(planning: data),
        DashboardWidgetKind.upcoming => _Upcoming(planning: data),
        DashboardWidgetKind.renewals => _Renewals(planning: data),
        DashboardWidgetKind.recurring => _Recurring(planning: data),
        DashboardWidgetKind.goals => _Goals(planning: data),
        _ => _GroupBalances(planning: data),
      };
    } else if (planning.hasError && !planning.isLoading) {
      body = _CardError(
        error: planning.error!,
        onRetry: () => ref.invalidate(dashboardPlanningProvider),
      );
    } else {
      body = const _CardLoading();
    }
    return SectionCard(
      title: widgetTitle(l10n, kind),
      trailing: TextButton(
        onPressed: () => context.push(_route),
        child: Text(l10n.actionSeeAll, semanticsLabel: _seeAll(l10n)),
      ),
      children: <Widget>[body],
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Insets.md,
      Insets.sm,
      Insets.md,
      Insets.md,
    ),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: <Widget>[
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(context.l10n.dashPlanLoading)),
        ],
      ),
    ),
  );
}

class _CardError extends StatelessWidget {
  const _CardError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.md,
        Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: StatusLabel(
              text: l10n.dashPlanError(describeError(l10n, error)),
              tone: StatusTone.caution,
            ),
          ),
          const SizedBox(height: Insets.xs),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
        ],
      ),
    );
  }
}

/// A line of text under the card title.
class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.xs),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// An empty card: what is missing and, when there is one, what to do.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text, this.action, this.route});

  final String text;
  final String? action;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final String? label = action;
    final String? target = route;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.md,
        Insets.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
          if (label != null && target != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            OutlinedButton.icon(
              onPressed: () => context.push(target),
              icon: const Icon(Icons.add),
              label: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Showing 5 of 7" when the server sent only the first items.
class _ShowingFirst extends StatelessWidget {
  const _ShowingFirst({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) => shown >= total
      ? const SizedBox(height: Insets.xs)
      : Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.xs,
            Insets.md,
            Insets.sm,
          ),
          child: Text(
            context.l10n.dashPlanShowingFirst(shown, total),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
}

/// A tappable row inside a card (one budget, goal or group).
class _Row extends StatelessWidget {
  const _Row({required this.onTap, required this.children});

  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _Budgets extends ConsumerWidget {
  const _Budgets({required this.planning});

  final DashboardPlanning planning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final List<BudgetDto> budgets = planning.budgets;
    if (budgets.isEmpty) {
      return _EmptyCard(
        text: l10n.dashPlanBudgetsEmpty,
        action: l10n.dashPlanBudgetsCreate,
        route: AppRoutes.newBudget,
      );
    }
    final int over = planning.overBudgetCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Line(
          '${l10n.dashPlanBudgetsSummary(planning.budgetCount)} · '
          '${over > 0 ? l10n.dashPlanBudgetsOver(over) : l10n.dashPlanBudgetsNoneOver}',
        ),
        for (final BudgetDto b in budgets)
          _Row(
            onTap: () => context.push(AppRoutes.budgetDetail(b.id)),
            children: <Widget>[
              Text(b.name, style: text.titleSmall),
              const SizedBox(height: Insets.xs),
              if (b.progress case final ProgressDto p) ...<Widget>[
                _BudgetSpent(progress: p),
                const SizedBox(height: Insets.xs),
                BudgetProgressBar(
                  basisPoints: p.percentBp,
                  over: p.overspent.amountMinor > 0,
                ),
                const SizedBox(height: Insets.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BudgetPaceLabel(pace: p.pace),
                ),
              ] else
                Text(l10n.dashPlanBudgetPaused, style: text.bodySmall),
            ],
          ),
        _ShowingFirst(shown: budgets.length, total: planning.budgetCount),
      ],
    );
  }
}

class _BudgetSpent extends ConsumerWidget {
  const _BudgetSpent({required this.progress});

  final ProgressDto progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SpokenMoney spent = spokenMoney(context, ref, progress.spent);
    final SpokenMoney limit = spokenMoney(context, ref, progress.limit);
    return Text(
      l10n.budgetSpentOf(spent.text, limit.text),
      semanticsLabel: l10n.budgetSpentOf(spent.spoken, limit.spoken),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.planning});

  final DashboardPlanning planning;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final List<CalendarItem> items = planning.upcoming;
    if (items.isEmpty) {
      return _EmptyCard(
        text: l10n.dashPlanUpcomingEmpty,
        action: l10n.dashPlanUpcomingAddBill,
        route: AppRoutes.newBill,
      );
    }
    final int overdue = planning.overdueCount;
    final int more = planning.upcomingCount - items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Line(
          '${l10n.dashPlanUpcomingSummary(planning.upcomingCount, LocalDates.display(planning.upcomingThrough, locale: locale))} · '
          '${overdue > 0 ? l10n.dashPlanUpcomingOverdue(overdue) : l10n.dashPlanUpcomingNoneOverdue}',
        ),
        for (final CalendarItem item in items)
          _UpcomingTile(item: item, today: planning.today),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              Insets.sm,
            ),
            child: Text(
              l10n.dashPlanUpcomingMore(more),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          const SizedBox(height: Insets.xs),
      ],
    );
  }
}

/// One upcoming item: what it is, when it is due, its status in words and
/// the amount; opens its source when the app has a screen for it.
/// [renewal] words the date as a renewal or trial end ("On 20 Nov")
/// instead of a due date.
class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({
    required this.item,
    required this.today,
    this.renewal = false,
  });

  final CalendarItem item;
  final String today;
  final bool renewal;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final (String statusText, StatusTone tone, IconData icon) =
        calendarStatusLabel(l10n, item.status);
    final String? location = calendarItemLocation(item);
    final Money? amount = item.amount;
    final String date = LocalDates.display(item.date, locale: locale);
    final String due = renewal
        ? (item.date == today
              ? l10n.dashPlanRenewalToday
              : l10n.dashPlanRenewalOn(date))
        : item.date == today
        ? l10n.dashPlanDueToday
        : item.date.compareTo(today) < 0
        ? l10n.dashPlanWasDue(date)
        : l10n.dashPlanDueOn(date);
    return MergeSemantics(
      child: ListTile(
        onTap: location == null ? null : () => context.push(location),
        leading: CircleAvatar(
          child: ExcludeSemantics(child: Icon(calendarKindIcon(item.kind))),
        ),
        title: Text(item.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: Insets.xs),
          child: Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('${calendarKindLabel(l10n, item.kind)} · $due'),
              StatusLabel(text: statusText, tone: tone, icon: icon),
            ],
          ),
        ),
        trailing: amount == null ? null : MoneyText(amount),
      ),
    );
  }
}

class _Goals extends ConsumerWidget {
  const _Goals({required this.planning});

  final DashboardPlanning planning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String numbers = numberLocaleOf(context, ref);
    final String locale = Localizations.localeOf(context).toString();
    final List<GoalDto> goals = planning.goals;
    if (goals.isEmpty) {
      return _EmptyCard(
        text: l10n.dashPlanGoalsEmpty,
        action: l10n.dashPlanGoalsCreate,
        route: AppRoutes.newGoal,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Line(l10n.dashPlanGoalsSummary(planning.goalCount)),
        for (final GoalDto g in goals)
          _Row(
            onTap: () => context.push(AppRoutes.goalDetail(g.id)),
            children: <Widget>[
              Text(g.name, style: text.titleSmall),
              const SizedBox(height: Insets.xs),
              GoalProgressBar(percentBp: g.progress.percentBp),
              const SizedBox(height: Insets.xs),
              Text(
                l10n.goalProgressSummary(
                  formatGoalPercent(g.progress.percentBp, numbers),
                  formatMoneyText(g.progress.saved, numbers),
                  formatMoneyText(g.target, numbers),
                ),
                style: text.bodyMedium,
              ),
              Text(switch (g.targetDate) {
                final String date => l10n.goalTargetDateShort(
                  LocalDates.display(date, locale: locale),
                ),
                null => l10n.dashPlanGoalNoDate,
              }, style: text.bodySmall),
            ],
          ),
        _ShowingFirst(shown: goals.length, total: planning.goalCount),
      ],
    );
  }
}

class _GroupBalances extends ConsumerWidget {
  const _GroupBalances({required this.planning});

  final DashboardPlanning planning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final List<GroupBalance> groups = planning.groupBalances;
    if (groups.isEmpty) {
      return _EmptyCard(text: l10n.dashPlanGroupsEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Line(l10n.dashPlanGroupsSummary(planning.groupCount)),
        for (final GroupBalance g in groups)
          _Row(
            onTap: () => context.push(AppRoutes.groupBalances(g.groupId)),
            children: <Widget>[
              Text(g.name, style: text.titleSmall),
              Text(
                groupTypeLabel(l10n, g.groupType.json),
                style: text.bodySmall,
              ),
              const SizedBox(height: Insets.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _NetLabel(net: g.myNet),
              ),
            ],
          ),
        _ShowingFirst(shown: groups.length, total: planning.groupCount),
      ],
    );
  }
}

/// "You are owed ₹…" / "You owe ₹…" / "Settled up", in words with an icon.
class _NetLabel extends ConsumerWidget {
  const _NetLabel({required this.net});

  final Money net;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = numberLocaleOf(context, ref);
    final Money amount = unsignedNet(net);
    String words(String Function(Money) format) => net.amountMinor > 0
        ? l10n.groupNetOwedToYou(format(amount))
        : net.amountMinor < 0
        ? l10n.groupNetYouOwe(format(amount))
        : l10n.dashPlanGroupSettled;
    return StatusLabel(
      text: words((Money m) => formatMoneyText(m, locale)),
      semanticsLabel: words((Money m) => moneySemantics(l10n, m, locale)),
      tone: net.amountMinor > 0
          ? StatusTone.positive
          : net.amountMinor < 0
          ? StatusTone.caution
          : StatusTone.neutral,
      icon: net.amountMinor > 0
          ? Icons.call_received
          : net.amountMinor < 0
          ? Icons.call_made
          : Icons.check_circle_outline,
    );
  }
}

/// Active budget alerts in words, newest first, each with snooze and
/// dismiss (`PATCH /budget-alerts/{id}`); afterwards the planning answer
/// is read again so the card, the banner and the counts agree.
class _Alerts extends ConsumerStatefulWidget {
  const _Alerts({required this.planning});

  final DashboardPlanning planning;

  @override
  ConsumerState<_Alerts> createState() => _AlertsState();
}

class _AlertsState extends ConsumerState<_Alerts> {
  String? _busyId;

  Future<void> _change(
    AlertDto alert,
    BudgetAlertsUpdateRequestStatus status,
  ) async {
    if (_busyId != null) {
      return;
    }
    try {
      if (await changeBudgetAlert(
        context,
        ref,
        alert,
        status,
        onSending: () => setState(() => _busyId = alert.id),
      )) {
        // The budget revision re-reads planning; make sure even a cached
        // answer is not shown again.
        ref.invalidate(dashboardPlanningProvider);
      }
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).toString();
    final DashboardPlanning planning = widget.planning;
    final List<AlertDto> alerts = planning.alerts;
    if (alerts.isEmpty) {
      return _EmptyCard(text: l10n.dashPlanAlertsEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Line(l10n.dashPlanAlertsSummary(planning.alertCount)),
        for (final AlertDto a in alerts) ...<Widget>[
          _Row(
            onTap: () => context.push(AppRoutes.budgetDetail(a.budgetId)),
            children: <Widget>[
              Text(budgetAlertTitle(l10n, a), style: text.titleSmall),
              const SizedBox(height: Insets.xs),
              Text(
                l10n.budgetAlertTriggered(
                  formatDateTime(a.triggeredAt, locale: locale),
                ),
                style: text.bodySmall,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: Insets.xs,
              children: <Widget>[
                TextButton(
                  onPressed: _busyId != null
                      ? null
                      : () =>
                            _change(a, BudgetAlertsUpdateRequestStatus.snoozed),
                  child: Text(
                    l10n.budgetAlertSnooze,
                    semanticsLabel: l10n.dashPlanAlertSnoozeFor(a.budgetName),
                  ),
                ),
                TextButton(
                  onPressed: _busyId != null
                      ? null
                      : () => _change(
                          a,
                          BudgetAlertsUpdateRequestStatus.dismissed,
                        ),
                  child: Text(
                    l10n.budgetAlertDismiss,
                    semanticsLabel: l10n.dashPlanAlertDismissFor(a.budgetName),
                  ),
                ),
              ],
            ),
          ),
        ],
        _ShowingFirst(shown: alerts.length, total: planning.alertCount),
      ],
    );
  }
}

/// Subscription renewals and trial ends from today through
/// `renewals_through`, soonest first, with their amounts.
class _Renewals extends StatelessWidget {
  const _Renewals({required this.planning});

  final DashboardPlanning planning;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final List<CalendarItem> items = planning.renewals;
    if (items.isEmpty) {
      return _EmptyCard(
        text: l10n.dashPlanRenewalsEmpty,
        action: l10n.dashPlanRenewalsAdd,
        route: AppRoutes.newSubscription,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Line(
          l10n.dashPlanRenewalsSummary(
            planning.renewalCount,
            LocalDates.display(planning.renewalsThrough, locale: locale),
          ),
        ),
        for (final CalendarItem item in items)
          _UpcomingTile(item: item, today: planning.today, renewal: true),
        _ShowingFirst(shown: items.length, total: planning.renewalCount),
      ],
    );
  }
}

/// Recurring commitments as monthly amounts per kind, each currency on
/// its own (never added across currencies), with how the figures are
/// calculated.
class _Recurring extends ConsumerWidget {
  const _Recurring({required this.planning});

  final DashboardPlanning planning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String numbers = numberLocaleOf(context, ref);
    final List<RecurringCommitment> commitments = planning.recurring;
    final String? note = switch (planning.recurringNoteCode) {
      DashboardPlanningRecurringNoteCode.fixedAmountsExpectations =>
        l10n.analyticsRecurringNote,
      DashboardPlanningRecurringNoteCode.unrecognized => null,
    };
    if (commitments.isEmpty) {
      return _EmptyCard(
        text: l10n.analyticsRecurringEmpty,
        action: l10n.analyticsRecurringCreate,
        route: AppRoutes.newRecurring,
      );
    }
    final AuthState auth = ref.watch(authControllerProvider);
    final List<String> currencies = orderCurrencies(<String>[
      for (final RecurringCommitment c in commitments) c.currency,
    ], auth is SignedIn ? auth.user.baseCurrency : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final String currency in currencies) ...<Widget>[
          if (currencies.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.xs,
                Insets.md,
                0,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.currencyHeading(currency),
                  style: text.labelLarge,
                ),
              ),
            ),
          for (final RecurringCommitment c in commitments)
            if (c.currency == currency)
              MergeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        commitmentKindLabel(l10n, c.kind),
                        style: text.titleSmall,
                      ),
                      Text(
                        l10n.analyticsPerMonth(
                          formatMoneyText(c.monthlyEquivalent, numbers),
                        ),
                        semanticsLabel: l10n.analyticsPerMonth(
                          moneySemantics(l10n, c.monthlyEquivalent, numbers),
                        ),
                        style: text.bodyMedium,
                      ),
                      Text(
                        l10n.analyticsRecurringRules(c.ruleCount),
                        style: text.bodySmall,
                      ),
                      if (c.variableCount > 0)
                        Text(
                          l10n.analyticsVariableRules(c.variableCount),
                          style: text.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
        ],
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              Insets.md,
            ),
            child: Text(note, style: text.bodySmall),
          )
        else
          const SizedBox(height: Insets.sm),
      ],
    );
  }
}
