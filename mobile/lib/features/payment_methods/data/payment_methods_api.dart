import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for payment methods (masked metadata only; never full card
/// numbers, CVVs or PINs).
class PaymentMethodsApi {
  /// Creates the API over [client].
  PaymentMethodsApi(this._client);

  final ApiClient _client;

  /// `GET /payment-methods` (default first).
  Future<List<PaymentMethodDto>> list({bool includeArchived = false}) =>
      _client.send(
        ApiEndpoints.listPaymentMethods,
        query: <String, Object?>{if (includeArchived) 'include_archived': true},
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeListPaymentMethodDto(json).data,
      );

  /// `GET /payment-methods/{id}`.
  Future<PaymentMethodDto> get(String id) => _client.send(
    ApiEndpoints.getPaymentMethod,
    pathParameters: <String, String>{'id': id},
    decode: _decodeMethod,
  );

  /// `POST /payment-methods`.
  Future<PaymentMethodDto> create(PaymentMethodInput input) => _client.send(
    ApiEndpoints.createPaymentMethod,
    body: input.toJson(),
    decode: _decodeMethod,
  );

  /// `PATCH /payment-methods/{id}` — only the members set in [patch]
  /// change; with `version`, a concurrent edit answers `VERSION_CONFLICT`.
  Future<PaymentMethodDto> update(String id, PaymentMethodPatch patch) =>
      _client.send(
        ApiEndpoints.updatePaymentMethod,
        pathParameters: <String, String>{'id': id},
        body: patch.toJson(),
        decode: _decodeMethod,
      );

  /// `DELETE /payment-methods/{id}` — deletes an unused method or archives
  /// one that transactions use (the result says which).
  Future<PaymentMethodDeleteResult> remove(String id) => _client.send(
    ApiEndpoints.deletePaymentMethod,
    pathParameters: <String, String>{'id': id},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopePaymentMethodDeleteResult(json).data,
  );

  /// `POST /payment-methods/{id}/restore`.
  Future<PaymentMethodDto> restore(String id) => _client.send(
    ApiEndpoints.restorePaymentMethod,
    pathParameters: <String, String>{'id': id},
    decode: _decodeMethod,
  );

  static PaymentMethodDto _decodeMethod(Map<String, Object?> json) =>
      decodeEnvelopePaymentMethodDto(json).data;
}

/// Payment method endpoints. Overridden in tests.
final Provider<PaymentMethodsApi> paymentMethodsApiProvider =
    Provider<PaymentMethodsApi>(
      (Ref ref) => PaymentMethodsApi(ref.watch(apiClientProvider)),
    );
