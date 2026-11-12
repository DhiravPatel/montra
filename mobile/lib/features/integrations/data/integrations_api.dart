import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Integrations` tag: bank and card data providers
/// with their honest availability, and the user's connections. The
/// provider sends the user back to the Montra web app
/// (`<web>/integrations/{provider}/callback`), which finishes the
/// connection; the app never calls the callback endpoint itself.
class IntegrationsApi {
  /// Creates the API over [client].
  IntegrationsApi(this._client);

  final ApiClient _client;

  /// `GET /integrations`: providers and the user's connections.
  Future<Overview> overview() => _client.send(
    ApiEndpoints.listIntegrations,
    decode: (Map<String, Object?> json) => decodeEnvelopeOverview(json).data,
  );

  /// `POST /integrations/{providerId}/connect`: starts connecting
  /// [accountId] after the user accepted the consent. Returns the
  /// provider's page to approve access at.
  Future<ConnectResult> connect(String providerId, String accountId) =>
      _client.send(
        ApiEndpoints.connectIntegration,
        pathParameters: <String, String>{'ref': providerId},
        body: ConnectInput(accountId: accountId, consentConfirm: true).toJson(),
        decode: (Map<String, Object?> json) =>
            decodeEnvelopeConnectResult(json).data,
      );

  /// `GET /integrations/{connectionId}/status`: the connection and its
  /// last 20 syncs.
  Future<ConnectionStatus> status(String connectionId) => _client.send(
    ApiEndpoints.integrationStatus,
    pathParameters: <String, String>{'ref': connectionId},
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeConnectionStatus(json).data,
  );

  /// `POST /integrations/{connectionId}/sync` (202: queued).
  Future<SyncRunDto> sync(String connectionId) => _client.send(
    ApiEndpoints.syncIntegration,
    pathParameters: <String, String>{'ref': connectionId},
    decode: (Map<String, Object?> json) => decodeEnvelopeSyncRunDto(json).data,
  );

  /// `DELETE /integrations/{connectionId}?confirm=true`: revokes access and
  /// deletes stored credentials; with [deleteData] the transactions this
  /// connection imported are voided too.
  Future<DisconnectResult> disconnect(
    String connectionId, {
    required bool deleteData,
  }) => _client.send(
    ApiEndpoints.disconnectIntegration,
    pathParameters: <String, String>{'ref': connectionId},
    query: <String, Object?>{
      'confirm': true,
      if (deleteData) 'delete_data': true,
    },
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeDisconnectResult(json).data,
  );
}

/// Integration endpoints. Overridden in tests.
final Provider<IntegrationsApi> integrationsApiProvider =
    Provider<IntegrationsApi>(
      (Ref ref) => IntegrationsApi(ref.watch(apiClientProvider)),
    );
