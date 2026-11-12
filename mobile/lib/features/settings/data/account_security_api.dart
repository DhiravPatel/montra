import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';

/// Typed calls for the `Account security` tag of the contract.
class AccountSecurityApi {
  /// Creates the API over [client].
  AccountSecurityApi(this._client);

  final ApiClient _client;

  /// `GET /me/sessions`.
  Future<List<SessionDto>> listSessions() => _client.send(
    ApiEndpoints.listSessions,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeListSessionDto(json).data,
  );

  /// `DELETE /me/sessions/{sessionId}`.
  Future<void> revokeSession(String sessionId) => _client.send(
    ApiEndpoints.revokeSession,
    pathParameters: <String, String>{'sessionId': sessionId},
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /me/password` — signs out the user's other sessions.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _client.send(
    ApiEndpoints.changePassword,
    body: ChangePasswordBody(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ).toJson(),
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /me/mfa/totp/setup` — requires recent re-authentication.
  Future<MfaSetup> startTotpSetup() => _client.send(
    ApiEndpoints.totpSetup,
    decode: (Map<String, Object?> json) => decodeEnvelopeMfaSetup(json).data,
  );

  /// `POST /me/mfa/totp/activate` — returns the one-time recovery codes.
  Future<List<String>> activateTotp(String code) => _client.send(
    ApiEndpoints.totpActivate,
    body: CodeBody(code: code).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeMfaActivation(json).data.recoveryCodes,
  );

  /// `POST /me/mfa/totp/disable` — requires recent re-authentication plus a
  /// TOTP or recovery code.
  Future<void> disableTotp({String? code, String? recoveryCode}) =>
      _client.send(
        ApiEndpoints.totpDisable,
        body: DisableMfaBody(code: code, recoveryCode: recoveryCode).toJson(),
        decode: decodeEnvelopeEmpty,
      );

  /// `POST /me/mfa/recovery-codes` — replaces every recovery code.
  Future<List<String>> regenerateRecoveryCodes() => _client.send(
    ApiEndpoints.regenerateRecoveryCodes,
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeMfaActivation(json).data.recoveryCodes,
  );
}

/// Account security endpoints. Overridden in tests.
final Provider<AccountSecurityApi> accountSecurityApiProvider =
    Provider<AccountSecurityApi>(
      (Ref ref) => AccountSecurityApi(ref.watch(apiClientProvider)),
    );
