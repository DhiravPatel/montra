import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_alert_actions.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';

/// Which alerts the screen lists.
enum BudgetAlertFilter {
  /// Waiting for a look.
  active('active'),

  /// Snoozed for a while.
  snoozed('snoozed'),

  /// Dismissed.
  dismissed('dismissed'),

  /// Everything.
  all(null);

  const BudgetAlertFilter(this.status);

  /// The `status` query value (null for all).
  final String? status;
}

/// Budget alerts: thresholds reached, likely overspending and unusual
/// spending. Each can be dismissed, snoozed or shown again, and opens its
/// budget.
class BudgetAlertsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const BudgetAlertsScreen({super.key});

  @override
  ConsumerState<BudgetAlertsScreen> createState() => _BudgetAlertsScreenState();
}

class _BudgetAlertsScreenState extends ConsumerState<BudgetAlertsScreen> {
  BudgetAlertFilter _filter = BudgetAlertFilter.active;
  String? _busyId;

  String _filterLabel(AppLocalizations l10n, BudgetAlertFilter f) =>
      switch (f) {
        BudgetAlertFilter.active => l10n.budgetAlertStatusActive,
        BudgetAlertFilter.snoozed => l10n.budgetAlertStatusSnoozed,
        BudgetAlertFilter.dismissed => l10n.budgetAlertStatusDismissed,
        BudgetAlertFilter.all => l10n.budgetAlertStatusAll,
      };

  Future<void> _update(
    AlertDto alert,
    BudgetAlertsUpdateRequestStatus status,
  ) async {
    if (_busyId != null) {
      return;
    }
    try {
      await changeBudgetAlert(
        context,
        ref,
        alert,
        status,
        onSending: () => setState(() => _busyId = alert.id),
      );
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(budgetAlertsPageProvider(_filter.status))
      ..invalidate(budgetAlertsProvider('active'));
    try {
      await ref.read(budgetAlertsPageProvider(_filter.status).future);
    } on Object {
      // Shown by the list state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<PagedList<AlertDto>> alerts = ref.watch(
      budgetAlertsPageProvider(_filter.status),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.budgetAlertsTitle),
        bottom: _busyId != null || (alerts.isLoading && alerts.hasValue)
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
            child: Semantics(
              label: l10n.budgetAlertFilterLabel,
              container: true,
              child: Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: <Widget>[
                  for (final BudgetAlertFilter f in BudgetAlertFilter.values)
                    ChoiceChip(
                      label: Text(_filterLabel(l10n, f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<PagedList<AlertDto>>(
              value: alerts,
              onRetry: _refresh,
              data: (PagedList<AlertDto> page) => RefreshIndicator(
                onRefresh: _refresh,
                child: page.items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          const SizedBox(height: Insets.lg),
                          MessageStateView(
                            icon: Icons.notifications_none,
                            title: _filter == BudgetAlertFilter.active
                                ? l10n.budgetAlertsEmptyActive
                                : l10n.budgetAlertsEmptyOther,
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(Insets.md),
                        itemCount: page.items.length + 1,
                        itemBuilder: (BuildContext context, int i) =>
                            i == page.items.length
                            ? LoadMoreFooter(
                                list: page,
                                onLoadMore: () => ref
                                    .read(
                                      budgetAlertsPageProvider(_filter.status)
                                          .notifier,
                                    )
                                    .loadMore(),
                              )
                            : _AlertCard(
                                alert: page.items[i],
                                busy: _busyId == page.items[i].id,
                                onUpdate: (BudgetAlertsUpdateRequestStatus s) =>
                                    _update(page.items[i], s),
                              ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.busy,
    required this.onUpdate,
  });

  final AlertDto alert;
  final bool busy;
  final ValueChanged<BudgetAlertsUpdateRequestStatus> onUpdate;

  IconData get _icon => switch (alert.kind) {
    AlertDtoKind.threshold => Icons.data_usage,
    AlertDtoKind.forecastOverspend => Icons.trending_up,
    AlertDtoKind.unusualSpend => Icons.insights_outlined,
    AlertDtoKind.unrecognized => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).toString();
    final DateTime? snoozedUntil = alert.snoozedUntil;
    final List<Widget> actions = <Widget>[
      if (alert.status == AlertDtoStatus.active)
        TextButton(
          onPressed: busy
              ? null
              : () => onUpdate(BudgetAlertsUpdateRequestStatus.snoozed),
          child: Text(l10n.budgetAlertSnooze),
        ),
      if (alert.status != AlertDtoStatus.active)
        TextButton(
          onPressed: busy
              ? null
              : () => onUpdate(BudgetAlertsUpdateRequestStatus.active),
          child: Text(l10n.budgetAlertReactivate),
        ),
      if (alert.status != AlertDtoStatus.dismissed)
        TextButton(
          onPressed: busy
              ? null
              : () => onUpdate(BudgetAlertsUpdateRequestStatus.dismissed),
          child: Text(l10n.budgetAlertDismiss),
        ),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MergeSemantics(
            child: InkWell(
              onTap: () => context.push(AppRoutes.budgetDetail(alert.budgetId)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.md,
                  Insets.md,
                  Insets.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ExcludeSemantics(child: Icon(_icon)),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            budgetAlertTitle(l10n, alert),
                            style: text.titleSmall,
                          ),
                          if (alert.kind == AlertDtoKind.forecastOverspend)
                            Padding(
                              padding: const EdgeInsets.only(top: Insets.xs),
                              child: Text(
                                l10n.budgetAlertForecastBody,
                                style: text.bodyMedium,
                              ),
                            ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            '${l10n.budgetAlertPeriod(LocalDates.display(alert.periodStart, locale: locale))} · '
                            '${l10n.budgetAlertTriggered(formatDateTime(alert.triggeredAt, locale: locale))}',
                            style: text.bodySmall,
                          ),
                          if (alert.status == AlertDtoStatus.snoozed &&
                              snoozedUntil != null)
                            Text(
                              l10n.budgetAlertSnoozedUntil(
                                formatDateTime(snoozedUntil, locale: locale),
                              ),
                              style: text.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: Insets.xs,
              children: actions,
            ),
          ),
        ],
      ),
    );
  }
}
