import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/endpoints.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Typed calls for the `Auth` tag of the contract.
class AuthApi {
  /// Creates the API over [client].
  AuthApi(this._client);

  final ApiClient _client;

  /// `POST /auth/register` — always 202; a verification email follows.
  Future<AcceptedMessage> register(RegisterBody body) => _client.send(
    ApiEndpoints.register,
    body: body.toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeAcceptedMessage(json).data,
  );

  /// `POST /auth/login` — tokens, or `status: mfa_required` + `mfa_token`.
  Future<AuthResult> login(LoginBody body) => _client.send(
    ApiEndpoints.login,
    body: body.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeAuthResult(json).data,
  );

  /// `POST /auth/mfa/verify` — completes an MFA sign-in.
  Future<AuthResult> verifyMfa(MfaVerifyBody body) => _client.send(
    ApiEndpoints.verifyMfa,
    body: body.toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeAuthResult(json).data,
  );

  /// `POST /auth/refresh` — rotates both tokens.
  Future<AuthResult> refresh(String refreshToken) => _client.send(
    ApiEndpoints.refresh,
    body: RefreshBody(refreshToken: refreshToken).toJson(),
    decode: (Map<String, Object?> json) => decodeEnvelopeAuthResult(json).data,
  );

  /// `POST /auth/logout` — revokes the current session.
  Future<void> logout() =>
      _client.send(ApiEndpoints.logout, decode: decodeEnvelopeEmpty);

  /// `POST /auth/logout-all` — revokes every session of the user.
  Future<void> logoutAll() =>
      _client.send(ApiEndpoints.logoutAll, decode: decodeEnvelopeEmpty);

  /// `POST /auth/password/forgot` — always 202 (no account enumeration).
  Future<AcceptedMessage> forgotPassword(String email) => _client.send(
    ApiEndpoints.forgotPassword,
    body: EmailBody(email: email).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeAcceptedMessage(json).data,
  );

  /// `POST /auth/password/reset` — sets a new password; revokes sessions.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _client.send(
    ApiEndpoints.resetPassword,
    body: ResetBody(token: token, newPassword: newPassword).toJson(),
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /auth/email/verify`.
  Future<void> verifyEmail(String token) => _client.send(
    ApiEndpoints.verifyEmail,
    body: TokenBody(token: token).toJson(),
    decode: decodeEnvelopeEmpty,
  );

  /// `POST /auth/email/resend` — always 202.
  Future<AcceptedMessage> resendVerification(String email) => _client.send(
    ApiEndpoints.resendVerification,
    body: EmailBody(email: email).toJson(),
    decode: (Map<String, Object?> json) =>
        decodeEnvelopeAcceptedMessage(json).data,
  );

  /// `POST /auth/reauthenticate` — confirms the password before sensitive
  /// actions. With two-step verification on, also send an authenticator
  /// [code] or a single-use [recoveryCode].
  Future<void> reauthenticate({
    required String password,
    String? code,
    String? recoveryCode,
  }) => _client.send(
    ApiEndpoints.reauthenticate,
    body: ReauthBody(
      password: password,
      code: code,
      recoveryCode: recoveryCode,
    ).toJson(),
    decode: decodeEnvelopeEmpty,
  );

  /// `GET /auth/session` — current session and account summary.
  Future<AuthResult> currentSession() => _client.send(
    ApiEndpoints.currentSession,
    decode: (Map<String, Object?> json) => decodeEnvelopeAuthResult(json).data,
  );
}
