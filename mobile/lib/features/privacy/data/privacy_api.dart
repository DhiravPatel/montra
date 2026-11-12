import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Privacy` tag and `GET /legal`: consents, data
/// exports, deactivation and account deletion. Exporting, deleting and
/// deactivating need a recent re-authentication (`REAUTH_REQUIRED`; the
/// screens use `runWithReauth`).
class PrivacyApi {
  /// Creates the API over [client].
  PrivacyApi(this._client);

  final ApiClient _client;

  /// `GET /legal`: current terms/privacy versions and the wording version
  /// of every consent type (`POST /me/consents` accepts only these).
  Future<LegalDto> legal() => _client.send(
    ApiEndpoints.legal,
    decode: (Map<String, Object?> json) => decodeEnvelopeLegalDto(json).data,
  );

  /// `GET /me/consents`: the consents in force.
  Future<List<ConsentDto>> consents() => _client.send(
    ApiEndpoints.listConsents,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListConsentDto(json).data,
  );

  /// `POST /me/consents` with the [version] from [legal].
  Future<ConsentDto> grant(
    MeConsentsGrantRequestConsentType type,
    String version,
  ) => _client.send(
    ApiEndpoints.grantConsent,
    body: MeConsentsGrantRequest(consentType: type, version: version).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeConsentDto(json).data,
  );

  /// `DELETE /me/consents/{consentType}`.
  Future<void> revoke(String type) => _client.send(
    ApiEndpoints.revokeConsent,
    pathParameters: <String, String>{'consentType': type},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /me/export` (`202`; made in the background).
  Future<ExportDto> requestExport() => _client.send(
    ApiEndpoints.requestExport,
    decode: (Map<String, Object?> json) => decodeEnvelopeExportDto(json).data,
  );

  /// `GET /me/exports`: newest first; a completed export past its expiry
  /// reads as `expired`.
  Future<List<ExportDto>> exports() => _client.send(
    ApiEndpoints.listExports,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListExportDto(json).data,
  );

  /// `GET /me/export/{exportId}`.
  Future<ExportDto> export(String id) => _client.send(
    ApiEndpoints.getExport,
    pathParameters: <String, String>{'exportId': id},
    decode: (Map<String, Object?> json) => decodeEnvelopeExportDto(json).data,
  );

  /// `POST /me/deactivate`: closes the account until the user signs in
  /// again.
  Future<void> deactivate() =>
      _client.send(ApiEndpoints.deactivateAccount, decode: decodeEnvelopeEmpty);

  /// `GET /me/deletion-request`: status, consequences and what is kept.
  Future<DeletionDto> deletion() => _client.send(
    ApiEndpoints.deletionStatus,
    decode: (Map<String, Object?> json) => decodeEnvelopeDeletionDto(json).data,
  );

  /// `POST /me/deletion-request` (`confirm` must be `DELETE`).
  Future<DeletionDto> requestDeletion({String? reason}) => _client.send(
    ApiEndpoints.requestDeletion,
    body: MeDeletionRequestRequest(
      confirm: deletionConfirmWord,
      reason: reason == null || reason.trim().isEmpty ? null : reason.trim(),
    ).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeDeletionDto(json).data,
  );

  /// `DELETE /me/deletion-request`.
  Future<DeletionDto> cancelDeletion() => _client.send(
    ApiEndpoints.cancelDeletion,
    decode: (Map<String, Object?> json) => decodeEnvelopeDeletionDto(json).data,
  );

  /// The word the API expects in `confirm` (the user types it too).
  static const String deletionConfirmWord = 'DELETE';
}

/// The [PrivacyApi] over the shared client. Overridden in tests.
final Provider<PrivacyApi> privacyApiProvider = Provider<PrivacyApi>(
  (Ref ref) => PrivacyApi(ref.watch(apiClientProvider)),
);
