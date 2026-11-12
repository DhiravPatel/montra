import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Lifecycle actions on a subscription (`POST /subscriptions/{id}/<action>`).
///
/// Montra never cancels anything with the provider: [cancelled] records
/// that the provider confirmed the cancellation (`confirm: true`).
enum SubscriptionAction {
  /// Marks the details as checked today.
  verify,

  /// Pauses tracking (trial or active).
  pause,

  /// Resumes a paused subscription.
  resume,

  /// The user started cancelling with the provider.
  cancellationStarted,

  /// The provider confirmed the cancellation.
  cancelled,

  /// Tracks a cancelled (or cancelling) subscription again.
  reactivate,
}

/// Subscriptions: manual entries, their price and payment history,
/// lifecycle actions and the review of possible subscriptions found in the
/// user's transactions.
class SubscriptionsApi {
  /// Creates the API over [client].
  SubscriptionsApi(this._client);

  final ApiClient _client;

  /// `GET /subscriptions/summary`: cost per currency (never converted),
  /// renewals in the next 30 days, trials ending within 14 days and the
  /// number of possible subscriptions waiting for review.
  Future<SubscriptionSummary> summary() => _client.send(
    ApiEndpoints.subscriptionsSummary,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeSubscriptionSummary(json).data,
  );

  /// `GET /subscriptions`. Without [status] everything but cancelled ones
  /// is listed; `all` includes them. The server returns at most
  /// [listCap] subscriptions.
  Future<List<SubscriptionDto>> list({String? status}) => _client.send(
    ApiEndpoints.listSubscriptions,
    query: <String, Object?>{'status': status},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListSubscriptionDto(json).data,
  );

  /// `GET /subscriptions/{id}` with its history.
  Future<SubscriptionDetail> get(String id) => _client.send(
    ApiEndpoints.getSubscription,
    pathParameters: <String, String>{'id': id},
    decode: _decodeDetail,
  );

  /// Most subscriptions `GET /subscriptions` returns.
  static const int listCap = 500;

  /// `POST /subscriptions` (idempotent: a retry with the same [key] and
  /// body returns the subscription added first).
  Future<SubscriptionDetail> create(
    SubscriptionInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.createSubscription,
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeDetail,
  );

  /// `PATCH /subscriptions/{id}`: only the fields in [patch] change;
  /// optional links named in `clear` are removed. It carries the `version`
  /// shown.
  Future<SubscriptionDetail> update(String id, SubscriptionPatch patch) =>
      _client.send(
        ApiEndpoints.updateSubscription,
        pathParameters: <String, String>{'id': id},
        body: patch.toJson(),
        decode: _decodeDetail,
      );

  /// `PATCH /subscriptions/{id}/cancellation-checklist/{index}`: ticks,
  /// unticks or renames one checklist step (from 0) without touching the
  /// rest of the subscription.
  Future<SubscriptionDetail> updateChecklistItem(
    String id,
    int index,
    ChecklistItemPatch patch,
  ) => _client.send(
    ApiEndpoints.updateSubscriptionChecklistItem,
    pathParameters: <String, String>{'id': id, 'index': '$index'},
    body: patch.toJson(),
    decode: _decodeDetail,
  );

  /// `GET /subscriptions/{id}/payment-candidates`: recent expenses in the
  /// subscription's currency, not linked to any subscription, that look
  /// like its payment (with stable `reason_codes`; at most 20).
  Future<List<SubscriptionPaymentCandidate>> paymentCandidates(String id) =>
      _client.send(
        ApiEndpoints.subscriptionPaymentCandidates,
        pathParameters: <String, String>{'id': id},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListSubscriptionPaymentCandidate(json).data,
      );

  /// `DELETE /subscriptions/{id}/payments/{transactionId}`: unlinks a
  /// recorded payment. The transaction itself does not change and can be
  /// linked again; the history gains a `payment_unlinked` entry.
  Future<SubscriptionDetail> unlinkPayment(String id, String transactionId) =>
      _client.send(
        ApiEndpoints.unlinkSubscriptionPayment,
        pathParameters: <String, String>{
          'id': id,
          'transactionId': transactionId,
        },
        decode: _decodeDetail,
      );

  /// `POST /subscriptions/{id}/payments`: links one of the user's expenses
  /// as a payment (idempotent; retries with [key] return the first result).
  Future<SubscriptionDetail> recordPayment(
    String id,
    SubscriptionPaymentInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.recordSubscriptionPayment,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeDetail,
  );

  /// Applies a lifecycle [action]. [version] is the version shown: a
  /// subscription changed meanwhile answers `VERSION_CONFLICT`; a move the
  /// current status does not allow answers `invalid_status_transition`.
  Future<SubscriptionDetail> act(
    String id,
    SubscriptionAction action, {
    SubscriptionActionInput input = const SubscriptionActionInput(),
    int? version,
  }) => _client.send(
    switch (action) {
      SubscriptionAction.verify => ApiEndpoints.verifySubscription,
      SubscriptionAction.pause => ApiEndpoints.pauseSubscription,
      SubscriptionAction.resume => ApiEndpoints.resumeSubscription,
      SubscriptionAction.cancellationStarted =>
        ApiEndpoints.subscriptionCancellationStarted,
      SubscriptionAction.cancelled => ApiEndpoints.subscriptionCancelled,
      SubscriptionAction.reactivate => ApiEndpoints.reactivateSubscription,
    },
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'version': version},
    body: input.toJson(),
    decode: _decodeDetail,
  );

  /// `GET /subscriptions/detections` (pending ones by default).
  Future<List<DetectionCandidateDto>> detections({String status = 'pending'}) =>
      _client.send(
        ApiEndpoints.listSubscriptionDetections,
        query: <String, Object?>{'status': status},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListDetectionCandidateDto(json).data,
      );

  /// `POST /subscriptions/detections/refresh`: asks the server to look for
  /// new recurring charges in the background (202).
  Future<void> refreshDetections() => _client.send(
    ApiEndpoints.refreshSubscriptionDetections,
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /subscriptions/detections/{id}/confirm`: creates a subscription
  /// from a possible one; unset [input] values use the detected ones.
  Future<SubscriptionDetail> confirmDetection(
    String id,
    DetectionConfirmInput input,
  ) => _client.send(
    ApiEndpoints.confirmSubscriptionDetection,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    decode: _decodeDetail,
  );

  /// `POST /subscriptions/detections/{id}/dismiss`.
  Future<void> dismissDetection(String id) => _client.send(
    ApiEndpoints.dismissSubscriptionDetection,
    pathParameters: <String, String>{'id': id},
    decode: decodeEnvelopeEmpty,
  );

  static SubscriptionDetail _decodeDetail(Map<String, Object?> json) =>
      decodeEnvelopeSubscriptionDetail(json).data;
}

/// The [SubscriptionsApi] over the shared client.
final Provider<SubscriptionsApi> subscriptionsApiProvider =
    Provider<SubscriptionsApi>(
      (Ref ref) => SubscriptionsApi(ref.watch(apiClientProvider)),
    );
