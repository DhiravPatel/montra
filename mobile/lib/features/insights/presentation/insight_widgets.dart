import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/insights/domain/insight_messages.dart';

/// The severity of an insight as a status label (icon + text).
class InsightSeverityLabel extends StatelessWidget {
  /// Creates the label.
  const InsightSeverityLabel(this.severity, {super.key});

  /// The severity.
  final InsightDtoSeverity severity;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return StatusLabel(
      text: insightSeverityLabel(l10n, severity),
      tone: severity == InsightDtoSeverity.warning
          ? StatusTone.caution
          : StatusTone.neutral,
      icon: switch (severity) {
        InsightDtoSeverity.warning => Icons.warning_amber_outlined,
        InsightDtoSeverity.notice => Icons.visibility_outlined,
        _ => Icons.info_outline,
      },
    );
  }
}

/// One insight in a list: severity, status when not active, the localized
/// title and body.
class InsightTile extends StatelessWidget {
  /// Creates the tile.
  const InsightTile({required this.insight, required this.onTap, super.key});

  /// The insight.
  final InsightDto insight;

  /// Opens it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final InsightText text = insightText(l10n, insight, locale: locale);
    return ListTile(
      onTap: onTap,
      title: Text(text.title, style: theme.textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Text(
              text.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                InsightSeverityLabel(insight.severity),
                if (insight.status != InsightDtoStatus.active)
                  StatusLabel(text: insightStatusLabel(l10n, insight.status)),
              ],
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// The record an insight is about, from its `message_params`, as a route
/// and a label; null when it names none the app can open.
({String route, String label, bool tab})? insightRecordLink(
  AppLocalizations l10n,
  InsightParams p,
) {
  if (p.text('transaction_id') case final String id) {
    return (
      route: AppRoutes.transactionDetail(id),
      label: l10n.insightOpenTransaction,
      tab: false,
    );
  }
  if (p.text('budget_id') case final String id) {
    return (
      route: AppRoutes.budgetDetail(id),
      label: l10n.insightOpenBudget,
      tab: false,
    );
  }
  if (p.text('subscription_id') case final String id) {
    return (
      route: AppRoutes.subscriptionDetail(id),
      label: l10n.insightOpenSubscription,
      tab: false,
    );
  }
  if (p.text('recurring_rule_id') case final String id) {
    return (
      route: AppRoutes.recurringDetail(id),
      label: l10n.insightOpenRecurring,
      tab: false,
    );
  }
  if (p.text('merchant_id') case final String id) {
    return (
      route: AppRoutes.merchantDetail(id),
      label: l10n.insightOpenMerchant,
      tab: false,
    );
  }
  if (p.text('category_id') case final String id) {
    return (
      route: Uri(
        path: AppRoutes.transactions,
        queryParameters: <String, String>{'category_id': id},
      ).toString(),
      label: l10n.insightOpenCategory,
      tab: true,
    );
  }
  if (p.text('account_id') case final String id) {
    return (
      route: AppRoutes.accountDetail(id),
      label: l10n.insightOpenAccount,
      tab: false,
    );
  }
  return null;
}
