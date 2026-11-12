import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_alerts_banner.dart';
import 'package:montra_mobile/features/budgets/presentation/budget_widgets.dart';

/// Budgets with their current progress and pace (server figures), active
/// alerts at the top and an option to include archived budgets.
class BudgetsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  bool _showArchived = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(budgetsProvider(_showArchived))
      ..invalidate(budgetAlertsProvider('active'));
    try {
      await ref.read(budgetsProvider(_showArchived).future);
    } on Object {
      // Shown by the list state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<BudgetDto>> budgets = ref.watch(
      budgetsProvider(_showArchived),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.budgetsTitle),
        bottom: budgets.isLoading && budgets.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.budgetAlertsTitle,
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push(AppRoutes.budgetAlerts),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newBudget),
        icon: const Icon(Icons.add),
        label: Text(l10n.budgetAdd),
      ),
      body: AsyncValueView<List<BudgetDto>>(
        value: budgets,
        onRetry: _refresh,
        data: (List<BudgetDto> list) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              96,
            ),
            children: <Widget>[
              const BudgetAlertsBanner(
                padding: EdgeInsets.only(bottom: Insets.sm),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.budgetsShowArchived),
                value: _showArchived,
                onChanged: (bool value) =>
                    setState(() => _showArchived = value),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.lg),
                  child: MessageStateView(
                    icon: Icons.savings_outlined,
                    title: l10n.budgetsEmptyTitle,
                    body: l10n.budgetsEmptyBody,
                    action: FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.newBudget),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.budgetAddFirst),
                    ),
                  ),
                )
              else
                for (final BudgetDto budget in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: BudgetTile(
                      budget: budget,
                      onTap: () =>
                          context.push(AppRoutes.budgetDetail(budget.id)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
