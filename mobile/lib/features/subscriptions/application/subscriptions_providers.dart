import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/subscriptions/data/subscriptions_api.dart';

/// Status filters of the subscriptions list, in display order. The empty
/// value is the server default: every subscription except cancelled ones.
const List<String> subscriptionListFilters = <String>[
  '',
  'trial',
  'active',
  'paused',
  'cancellation_pending',
  'cancelled',
  'all',
];

/// The overview figures (cost per currency, renewals, trials, possible
/// subscriptions). Re-read after every finance write, which includes
/// subscription changes.
final FutureProvider<SubscriptionSummary> subscriptionSummaryProvider =
    FutureProvider.autoDispose<SubscriptionSummary>((Ref ref) async {
      ref.watch(financeRevisionProvider);
      return ref.read(subscriptionsApiProvider).summary();
    });

/// Subscriptions with status [status] (see [subscriptionListFilters]).
final FutureProviderFamily<List<SubscriptionDto>, String>
subscriptionsProvider = FutureProvider.autoDispose
    .family<List<SubscriptionDto>, String>((Ref ref, String status) async {
      ref.watch(financeRevisionProvider);
      return ref
          .read(subscriptionsApiProvider)
          .list(status: status.isEmpty ? null : status);
    });

/// One subscription with its history.
final FutureProviderFamily<SubscriptionDetail, String>
subscriptionDetailProvider = FutureProvider.autoDispose
    .family<SubscriptionDetail, String>((Ref ref, String id) async {
      ref.watch(financeRevisionProvider);
      return ref.read(subscriptionsApiProvider).get(id);
    });

/// Possible subscriptions waiting for the user's review.
final FutureProvider<List<DetectionCandidateDto>> pendingDetectionsProvider =
    FutureProvider.autoDispose<List<DetectionCandidateDto>>((Ref ref) async {
      ref.watch(financeRevisionProvider);
      return ref.read(subscriptionsApiProvider).detections();
    });

/// Recorded charges that may be a subscription's payment (owner only).
final FutureProviderFamily<List<SubscriptionPaymentCandidate>, String>
subscriptionPaymentCandidatesProvider = FutureProvider.autoDispose
    .family<List<SubscriptionPaymentCandidate>, String>((
      Ref ref,
      String id,
    ) async {
      ref.watch(financeRevisionProvider);
      return ref.read(subscriptionsApiProvider).paymentCandidates(id);
    });
