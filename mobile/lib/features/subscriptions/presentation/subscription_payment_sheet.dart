import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/features/subscriptions/application/subscriptions_providers.dart';
import 'package:montra_mobile/features/subscriptions/domain/subscription_display.dart';

/// A charge chosen as a subscription payment.
@immutable
class ChargeChoice {
  /// Creates the choice.
  const ChargeChoice({
    required this.transactionId,
    required this.title,
    required this.date,
    required this.amount,
  });

  /// The transaction to link.
  final String transactionId;

  /// What to call it (merchant, description or account).
  final String title;

  /// Its date (`YYYY-MM-DD`).
  final String date;

  /// What was charged.
  final Money amount;
}

/// What the user picked in [showSubscriptionPaymentSheet].
sealed class PaymentSheetResult {
  const PaymentSheetResult();
}

/// One of the suggested charges.
final class PickedCharge extends PaymentSheetResult {
  /// Wraps [charge].
  const PickedCharge(this.charge);

  /// The suggestion.
  final ChargeChoice charge;
}

/// "Choose another transaction": search the ledger instead.
final class PickOtherCharge extends PaymentSheetResult {
  /// Creates the result.
  const PickOtherCharge();
}

/// Suggests recorded charges that look like [subscription]'s payment
/// (`GET /subscriptions/{id}/payment-candidates`), each with its reasons in
/// words, and offers to choose any other transaction. Nothing is linked
/// until the user confirms. Returns null when dismissed.
Future<PaymentSheetResult?> showSubscriptionPaymentSheet(
  BuildContext context, {
  required SubscriptionDetail subscription,
}) => showModalBottomSheet<PaymentSheetResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) =>
      _PaymentSheet(subscriptionId: subscription.id),
);

class _PaymentSheet extends ConsumerWidget {
  const _PaymentSheet({required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<SubscriptionPaymentCandidate>> candidates = ref.watch(
      subscriptionPaymentCandidatesProvider(subscriptionId),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (BuildContext context, ScrollController scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.lg),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.subscriptionPaymentPickerTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(l10n.subscriptionCandidatesIntro),
          const SizedBox(height: Insets.md),
          ...candidates.when(
            skipLoadingOnReload: true,
            loading: () => <Widget>[
              const Padding(
                padding: EdgeInsets.all(Insets.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (Object error, StackTrace _) => <Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: l10n.subscriptionCandidatesError,
                action: TextButton(
                  onPressed: () => ref.invalidate(
                    subscriptionPaymentCandidatesProvider(subscriptionId),
                  ),
                  child: Text(l10n.actionRetry),
                ),
              ),
            ],
            data: (List<SubscriptionPaymentCandidate> list) => list.isEmpty
                ? <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                      child: Text(l10n.subscriptionCandidatesEmpty),
                    ),
                  ]
                : <Widget>[
                    for (final SubscriptionPaymentCandidate c in list)
                      _CandidateTile(candidate: c, locale: locale),
                  ],
          ),
          const SizedBox(height: Insets.md),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(const PickOtherCharge()),
            icon: const Icon(Icons.search),
            label: Text(l10n.subscriptionChooseOtherCharge),
          ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate, required this.locale});

  final SubscriptionPaymentCandidate candidate;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SubscriptionPaymentCandidate c = candidate;
    final String title =
        <String?>[
          c.merchant,
          c.description,
        ].whereType<String>().where((String v) => v.isNotEmpty).firstOrNull ??
        c.accountName;
    final String? expected = c.expectedDate;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        <String>[
          LocalDates.display(c.localDate, locale: locale),
          c.accountName,
          ...subscriptionCandidateReasons(l10n, c),
          if (expected != null)
            l10n.subscriptionCandidateExpected(
              LocalDates.display(expected, locale: locale),
            ),
        ].join(' · '),
      ),
      trailing: MoneyText(c.amount),
      onTap: () => Navigator.of(context).pop(
        PickedCharge(
          ChargeChoice(
            transactionId: c.transactionId,
            title: title,
            date: c.localDate,
            amount: c.amount,
          ),
        ),
      ),
    );
  }
}
