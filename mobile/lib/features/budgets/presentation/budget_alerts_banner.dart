import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/budgets/application/budgets_providers.dart';
import 'package:montra_mobile/features/budgets/domain/budget_display.dart';

/// A calm notice with the number of active budget alerts and a way to
/// review them. Shows nothing while loading, on errors or when there are
/// no active alerts, so it can sit on any screen (Home, Budgets).
class BudgetAlertsBanner extends ConsumerWidget {
  /// Creates the banner.
  const BudgetAlertsBanner({this.padding = EdgeInsets.zero, super.key});

  /// Space around the banner when it is shown.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AlertDto>? alerts = ref
        .watch(budgetAlertsProvider('active'))
        .value;
    if (alerts == null || alerts.isEmpty) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.budgetAlertsBannerTitle(alerts.length),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        budgetAlertTitle(l10n, alerts.first),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              TextButton(
                onPressed: () => context.push(AppRoutes.budgetAlerts),
                child: Text(l10n.budgetAlertsBannerReview),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
