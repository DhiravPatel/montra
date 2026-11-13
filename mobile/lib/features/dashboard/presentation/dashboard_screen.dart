import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_alerts_banner.dart';
import 'package:montra_mobile/features/dashboard/application/dashboard_providers.dart';
import 'package:montra_mobile/features/dashboard/domain/widget_info.dart';
import 'package:montra_mobile/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:montra_mobile/features/dashboard/presentation/planning_cards.dart';
import 'package:montra_mobile/features/notifications/presentation/notification_bell.dart';
import 'package:montra_mobile/features/transactions/presentation/transactions_screen.dart';

/// Home: the server-computed dashboard for a period, drawn in the user's
/// widget order. Amounts in different currencies are never added together;
/// one currency is shown at a time when several exist. Every figure says
/// when it was computed, and stale data after a failed refresh is labelled.
class DashboardScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [now] is injectable for tests.
  const DashboardScreen({this.now, super.key});

  /// Clock for "updated … ago".
  final DateTime Function()? now;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _currency;

  Future<void> _refresh(DateRangeChoice range) async {
    ref
      ..invalidate(dashboardSummaryProvider(range))
      ..invalidate(dashboardPlanningProvider)
      ..invalidate(dashboardLayoutProvider);
    try {
      await ref.read(dashboardSummaryProvider(range).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  Future<void> _pickRange(DateRangeChoice current) async {
    final DateRangeChoice? next = await showRangePicker(
      context,
      current: current,
    );
    if (next != null && mounted) {
      ref.read(dashboardRangeProvider.notifier).choose(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final DateRangeChoice range = ref.watch(dashboardRangeProvider);
    final AsyncValue<DashboardSummary> summary = ref.watch(
      dashboardSummaryProvider(range),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navHome),
        bottom: summary.isLoading && summary.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.searchTitle,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
          ),
          const NotificationBell(),
          IconButton(
            tooltip: l10n.dashboardCustomize,
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => context.push(AppRoutes.dashboardWidgets),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showQuickAdd(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.actionAdd),
        tooltip: l10n.quickAddTitle,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              Insets.xs,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ActionChip(
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(rangeChoiceLabel(l10n, range, locale: locale)),
                tooltip: l10n.dashboardChangePeriod,
                onPressed: () => _pickRange(range),
              ),
            ),
          ),
          Expanded(child: _body(context, range, summary)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    DateRangeChoice range,
    AsyncValue<DashboardSummary> summary,
  ) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final DashboardSummary? data = summary.value;
    if (data == null) {
      if (summary.hasError && !summary.isLoading) {
        return ErrorStateView(
          error: summary.error!,
          onRetry: () => ref.invalidate(dashboardSummaryProvider(range)),
        );
      }
      return LoadingStateView(label: l10n.dashboardLoading);
    }
    final DateTime now = (widget.now ?? DateTime.now)();
    final String updated = formatRelativeTime(
      l10n,
      data.generatedAt,
      now: now,
      locale: locale,
    );
    final AuthState auth = ref.watch(authControllerProvider);
    final String? base = auth is SignedIn ? auth.user.baseCurrency : null;
    final List<String> currencies = dashboardCurrencies(data, base);
    final String? currency = currencies.contains(_currency)
        ? _currency
        : (currencies.isEmpty ? null : currencies.first);
    final bool firstUse =
        data.balances.isEmpty && data.coverage.transactionCount == 0;
    final AsyncValue<List<DashboardWidget>> layout = ref.watch(
      dashboardLayoutProvider,
    );
    // On first use only the planning cards with something in them are
    // shown (a new member of a group sees what they owe, for example).
    final DashboardPlanning? planning = firstUse
        ? ref.watch(dashboardPlanningProvider).value
        : null;
    final List<DashboardWidgetKind> kinds = <DashboardWidgetKind>[
      for (final DashboardWidget w in layout.value ?? defaultLayout)
        if (w.kind case final DashboardWidgetKind kind when w.visible)
          if (!firstUse ||
              (planning != null && planningHasContent(planning, kind)))
            kind,
    ];
    final DashboardContext ctx = DashboardContext(
      summary: data,
      currency: currency,
    );
    return RefreshIndicator(
      onRefresh: () => _refresh(range),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, 96),
        children: <Widget>[
          if (summary.hasError && !summary.isLoading) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.refreshFailedStale(updated),
              action: OutlinedButton(
                onPressed: () => _refresh(range),
                child: Text(l10n.actionRetry),
              ),
            ),
            const SizedBox(height: Insets.sm),
          ],
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.updatedAt(updated),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: Insets.sm),
          if (layout.hasError && !layout.isLoading) ...<Widget>[
            NoticeBanner(
              message: l10n.dashboardLayoutFallback,
              action: TextButton(
                onPressed: () => ref.invalidate(dashboardLayoutProvider),
                child: Text(l10n.actionRetry),
              ),
            ),
            const SizedBox(height: Insets.sm),
          ],
          const BudgetAlertsBanner(padding: EdgeInsets.only(bottom: Insets.sm)),
          if (firstUse) ...<Widget>[
            const _GetStarted(),
            const SizedBox(height: Insets.md),
          ],
          const PlanningShortcuts(),
          const SizedBox(height: Insets.md),
          const ReviewShortcuts(),
          const SizedBox(height: Insets.md),
          if (currencies.length > 1) ...<Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.dashboardCurrencyTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String c in currencies)
                  ChoiceChip(
                    label: Text(c),
                    selected: c == currency,
                    tooltip: l10n.dashboardCurrencyChip(c),
                    onSelected: (_) => setState(() => _currency = c),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(
                l10n.dashboardCurrencyNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: Insets.sm),
          ],
          for (final DashboardWidgetKind kind in kinds) ...<Widget>[
            DashboardWidgetCard(kind: kind, data: ctx),
            const SizedBox(height: Insets.md),
          ],
        ],
      ),
    );
  }
}

/// Shortcuts to the planning screens (budgets, goals, bills,
/// subscriptions, recurring payments and the calendar).
class PlanningShortcuts extends StatelessWidget {
  /// Creates the shortcuts.
  const PlanningShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ShortcutRow(
      title: l10n.homePlanTitle,
      items: <(IconData, String, String)>[
        (Icons.savings_outlined, l10n.homePlanBudgets, AppRoutes.budgets),
        (Icons.flag_outlined, l10n.homePlanGoals, AppRoutes.goals),
        (Icons.receipt_long_outlined, l10n.homePlanBills, AppRoutes.bills),
        (
          Icons.subscriptions_outlined,
          l10n.homePlanSubscriptions,
          AppRoutes.subscriptions,
        ),
        (
          Icons.event_repeat_outlined,
          l10n.homePlanRecurring,
          AppRoutes.recurring,
        ),
        (
          Icons.calendar_month_outlined,
          l10n.homePlanCalendar,
          AppRoutes.calendar,
        ),
      ],
    );
  }
}

/// Shortcuts to the record-keeping and insight screens (receipts,
/// statement imports, analytics and reports).
class ReviewShortcuts extends StatelessWidget {
  /// Creates the shortcuts.
  const ReviewShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ShortcutRow(
      title: l10n.homeToolsTitle,
      items: <(IconData, String, String)>[
        (Icons.receipt_outlined, l10n.entryReceipts, AppRoutes.receipts),
        (
          Icons.upload_file_outlined,
          l10n.entryImportsShort,
          AppRoutes.newImport,
        ),
        (Icons.insights_outlined, l10n.entryAnalytics, AppRoutes.analytics),
        (Icons.summarize_outlined, l10n.entryReports, AppRoutes.reports),
      ],
    );
  }
}

/// A titled, horizontally scrolling row of shortcut chips.
class ShortcutRow extends StatelessWidget {
  /// Creates the row.
  const ShortcutRow({required this.title, required this.items, super.key});

  /// Heading (announced as a header).
  final String title;

  /// Icon, label and route of each shortcut.
  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      const SizedBox(height: Insets.xs),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final (IconData icon, String label, String route) in items)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Insets.sm),
                child: ActionChip(
                  avatar: Icon(icon),
                  label: Text(label),
                  onPressed: () => context.push(route),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _GetStarted extends StatelessWidget {
  const _GetStarted();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.dashboardGetStartedTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(l10n.dashboardGetStartedBody),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.newAccount),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(l10n.accountAddFirst),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.newTransactionOf('expense')),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: Text(l10n.transactionAddExpense),
                ),
                TextButton.icon(
                  onPressed: () => context.push(HelpGuide.gettingStarted.path),
                  icon: const Icon(Icons.help_outline),
                  label: Text(HelpGuide.gettingStarted.title(l10n)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
