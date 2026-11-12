import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/subscriptions/domain/subscription_display.dart';

/// User-facing text for a failed subscription request. Coded answers
/// (`subscription_inactive`, `invalid_status_transition`,
/// `payment_already_linked`, `payment_linked_elsewhere`,
/// `detection_already_decided`, `record_limit_reached`, …) are localized by
/// [describeError]; uncoded conflicts and duplicates get calm wording of
/// their own, and field problems show the field's message.
String subscriptionErrorText(AppLocalizations l10n, Object error) {
  if (error is ApiException && error.kind == ApiErrorKind.server) {
    final bool coded = error.details.any(
      (Detail d) => (d.code ?? '').isNotEmpty,
    );
    switch (error.code) {
      case ErrorObjectCode.duplicate when !coded:
        return l10n.subscriptionPaymentDuplicate;
      case ErrorObjectCode.conflict when !coded:
        return l10n.subscriptionActionUnavailable;
      case ErrorObjectCode.validationError
          when error.details.isNotEmpty && !coded:
        return detailMessage(l10n, error.details.first);
      default:
        break;
    }
  }
  return describeError(l10n, error);
}

/// A subscription status as text with an icon (never colour alone).
class SubscriptionStatusLabel extends StatelessWidget {
  /// Creates the label for [status] (wire value).
  const SubscriptionStatusLabel({required this.status, super.key});

  /// Wire value of the status.
  final String status;

  @override
  Widget build(BuildContext context) => StatusLabel(
    text: subscriptionStatusText(context.l10n, status),
    tone: subscriptionStatusTone(status),
    icon: subscriptionStatusIcon(status),
  );
}

/// The next date that matters for a subscription in [status]: "Trial ends
/// 12 Nov 2026", "Renews 10 Nov 2026" or "Next charge …"; null when there
/// is none.
String? subscriptionWhenText(
  AppLocalizations l10n, {
  required String status,
  required String? nextRenewalDate,
  required String? trialEndsOn,
  required String locale,
}) {
  final String? trial = trialEndsOn;
  if (status == 'trial' && trial != null) {
    return l10n.subscriptionTrialEnds(
      LocalDates.display(trial, locale: locale),
    );
  }
  final String? next = nextRenewalDate;
  if (next == null) {
    return null;
  }
  final String date = LocalDates.display(next, locale: locale);
  return switch (status) {
    'trial' || 'active' => l10n.subscriptionRenews(date),
    'paused' || 'cancellation_pending' => l10n.subscriptionNextCharge(date),
    _ => null,
  };
}

/// One subscription in a list: name, price per cycle, next date and status.
class SubscriptionTile extends StatelessWidget {
  /// Creates the tile.
  const SubscriptionTile({required this.subscription, this.onTap, super.key});

  /// The subscription.
  final SubscriptionDto subscription;

  /// Opens the subscription.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final SubscriptionDto s = subscription;
    final String status = s.status.json;
    final String? when = subscriptionWhenText(
      l10n,
      status: status,
      nextRenewalDate: s.nextRenewalDate,
      trialEndsOn: s.trialEndsOn,
      locale: locale,
    );
    final String? plan = s.planName;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm + Insets.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.subscriptions_outlined),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(s.name, style: theme.textTheme.titleMedium),
                    if (plan != null && plan.isNotEmpty)
                      Text(plan, style: theme.textTheme.bodySmall),
                    const SizedBox(height: Insets.xs),
                    Wrap(
                      spacing: Insets.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        MoneyText(s.amount),
                        Text(
                          '· ${billingCycleText(l10n, s.billingFrequency.json, s.intervalCount, s.intervalUnit?.json)}',
                        ),
                      ],
                    ),
                    if (when != null)
                      Text(when, style: theme.textTheme.bodySmall),
                    const SizedBox(height: Insets.xs),
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.xs,
                      children: <Widget>[
                        SubscriptionStatusLabel(status: status),
                        if (!s.owned)
                          StatusLabel(
                            text: l10n.subscriptionSharedLabel,
                            icon: Icons.group_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cost per currency as the server totals it (never converted or mixed).
class SubscriptionTotalsCard extends ConsumerWidget {
  /// Creates the card.
  const SubscriptionTotalsCard({required this.totals, super.key});

  /// One entry per currency.
  final List<SubscriptionCostTotal> totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      title: l10n.subscriptionTotalsTitle,
      children: <Widget>[
        for (final SubscriptionCostTotal t in totals) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              0,
            ),
            child: Text(
              l10n.subscriptionTotalCount(t.count, t.currency),
              style: text.titleSmall,
            ),
          ),
          DetailRow(
            label: l10n.subscriptionMonthlyCost,
            semanticsValue: formatMoney(context, ref, t.monthly),
            child: MoneyText(t.monthly),
          ),
          DetailRow(
            label: l10n.subscriptionAnnualCost,
            semanticsValue: formatMoney(context, ref, t.annual),
            child: MoneyText(t.annual),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.xs,
            Insets.md,
            Insets.sm,
          ),
          child: Text(l10n.subscriptionTotalsNote, style: text.bodySmall),
        ),
      ],
    );
  }
}
