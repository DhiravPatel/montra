import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Lifecycle actions on a bill (`POST /bills/{id}/<action>`): pause from
/// active, resume from paused, archive from active or paused, restore from
/// archived. Anything else answers `invalid_status_transition`.
enum BillAction {
  /// Stops reminders and due dates until resumed.
  pause,

  /// Resumes a paused bill.
  resume,

  /// Archives the bill (its payments are kept).
  archive,

  /// Brings an archived bill back (fair-use cap: `record_limit_reached`).
  restore,
}

/// Bills: their schedule, payment state and payments.
class BillsApi {
  /// Creates the API over [client].
  BillsApi(this._client);

  final ApiClient _client;

  /// `GET /bills`, filtered by [status] (`active`, `paused`, `archived` or
  /// `all`; the server default leaves archived bills out).
  Future<List<BillDto>> list({String? status}) => _client.send(
    ApiEndpoints.listBills,
    query: <String, Object?>{'status': status},
    decode: (Map<String, Object?> json) => decodeEnvelopeListBillDto(json).data,
  );

  /// `GET /bills/{id}` with its payment history.
  Future<BillDetail> get(String id) => _client.send(
    ApiEndpoints.getBill,
    pathParameters: <String, String>{'id': id},
    decode: _decodeDetail,
  );

  /// `POST /bills` (idempotent: a retry with the same [key] and body
  /// returns the bill created first).
  Future<BillDetail> create(BillInput input, {required String key}) =>
      _client.send(
        ApiEndpoints.createBill,
        body: input.toJson(),
        headers: <String, String>{Idempotency.header: key},
        decode: _decodeDetail,
      );

  /// `PATCH /bills/{id}`: only the fields in [patch] change; optional ones
  /// named in `clear` are removed. Never used for the status (see [act]).
  Future<BillDetail> update(String id, BillPatch patch) => _client.send(
    ApiEndpoints.updateBill,
    pathParameters: <String, String>{'id': id},
    body: patch.toJson(),
    decode: _decodeDetail,
  );

  /// Applies a lifecycle [action]. [version] is the version on screen: a
  /// bill changed meanwhile answers `VERSION_CONFLICT`.
  Future<BillDetail> act(String id, BillAction action, {int? version}) =>
      _client.send(
        switch (action) {
          BillAction.pause => ApiEndpoints.pauseBill,
          BillAction.resume => ApiEndpoints.resumeBill,
          BillAction.archive => ApiEndpoints.archiveBill,
          BillAction.restore => ApiEndpoints.restoreBill,
        },
        pathParameters: <String, String>{'id': id},
        query: <String, Object?>{'version': version},
        decode: _decodeDetail,
      );

  /// `POST /bills/{id}/mark-paid` (idempotent with [key]): links a payment
  /// already recorded or records a new one.
  Future<BillDetail> markPaid(
    String id,
    MarkPaidInput input, {
    required String key,
  }) => _client.send(
    ApiEndpoints.markBillPaid,
    pathParameters: <String, String>{'id': id},
    body: input.toJson(),
    headers: <String, String>{Idempotency.header: key},
    decode: _decodeDetail,
  );

  /// `GET /bills/{id}/payment-candidates`: recorded payments that look like
  /// this bill's (for [occurrenceId], default the oldest unpaid one), with
  /// stable `reason_codes`. Empty when nothing is unpaid; 409
  /// `occurrence_not_open` when [occurrenceId] is already paid or skipped.
  Future<List<BillPaymentCandidate>> paymentCandidates(
    String id, {
    String? occurrenceId,
  }) => _client.send(
    ApiEndpoints.billPaymentCandidates,
    pathParameters: <String, String>{'id': id},
    query: <String, Object?>{'occurrence_id': occurrenceId},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListBillPaymentCandidate(json).data,
  );

  /// `POST /bills/{id}/skip` for [occurrenceId] (default the oldest unpaid).
  Future<BillDetail> skip(String id, {String? occurrenceId}) => _client.send(
    ApiEndpoints.skipBill,
    pathParameters: <String, String>{'id': id},
    body: BillsSkipRequest(occurrenceId: occurrenceId).toJson(),
    decode: _decodeDetail,
  );

  static BillDetail _decodeDetail(Map<String, Object?> json) =>
      decodeEnvelopeBillDetail(json).data;
}

/// The [BillsApi] over the shared client.
final Provider<BillsApi> billsApiProvider = Provider<BillsApi>(
  (Ref ref) => BillsApi(ref.watch(apiClientProvider)),
);
