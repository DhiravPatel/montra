import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_api.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/auth/credential_store.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/storage/secure_store.dart';

/// Credentials (memory access token + secure refresh token).
final Provider<CredentialStore> credentialStoreProvider =
    Provider<CredentialStore>(
      (Ref ref) => CredentialStore(ref.watch(secureStoreProvider)),
    );

/// Dio used only for `POST /auth/refresh` (no auth interceptor).
final Provider<Dio> refreshDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = createApiDio(ref.watch(appConfigProvider));
  ref.onDispose(dio.close);
  return dio;
});

/// Token lifetime manager shared by the interceptor and the controller.
final Provider<SessionTokenManager> sessionTokenManagerProvider =
    Provider<SessionTokenManager>((Ref ref) {
      final AuthApi refreshApi = AuthApi(
        ApiClient(ref.watch(refreshDioProvider)),
      );
      return SessionTokenManager(
        store: ref.watch(credentialStoreProvider),
        refresh: refreshApi.refresh,
      );
    });

/// Dio for every other API call (with the auth interceptor).
final Provider<Dio> apiDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = createApiDio(
    ref.watch(appConfigProvider),
    tokens: ref.watch(sessionTokenManagerProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// Typed API client.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (Ref ref) => ApiClient(ref.watch(apiDioProvider)),
);

/// Auth endpoints.
final Provider<AuthApi> authApiProvider = Provider<AuthApi>(
  (Ref ref) => AuthApi(ref.watch(apiClientProvider)),
);

/// The session state machine.
final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Owns sign-in, sign-out and session restoration. Screens call these
/// methods and handle [ApiException]s; routing reacts to [state].
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final SessionTokenManager tokens = ref.watch(sessionTokenManagerProvider);
    tokens.onSessionEnded = _handleSessionEnded;
    ref.onDispose(() {
      if (tokens.onSessionEnded == _handleSessionEnded) {
        tokens.onSessionEnded = null;
      }
    });
    return const AuthRestoring();
  }

  AuthApi get _api => ref.read(authApiProvider);

  SessionTokenManager get _tokens => ref.read(sessionTokenManagerProvider);

  /// The signed-in user, if any.
  UserDto? get currentUser => switch (state) {
    SignedIn(:final UserDto user) => user,
    _ => null,
  };

  /// Restores a stored session: refresh, then `GET /auth/session`.
  Future<void> restore() async {
    state = const AuthRestoring();
    final TokenRefreshResult result = await _tokens.refresh();
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case TokenRefreshNoCredentials():
        state = const SignedOut();
      case TokenRefreshRejected():
        state = const SignedOut(reason: SessionEndReason.expired);
      case TokenRefreshUnavailable(:final ApiException error):
        state = AuthRestoreFailed(error);
      case TokenRefreshSucceeded(result: final AuthResult? refreshed):
        await _loadSession(fallback: refreshed);
    }
  }

  /// Gives up on a session that could not be restored and forgets it.
  Future<void> discardStoredSession() async {
    await _tokens.clear();
    if (ref.mounted) {
      state = const SignedOut();
    }
  }

  /// First sign-in step. Throws [ApiException] on failure.
  Future<SignInOutcome> signIn({
    required String email,
    required String password,
  }) async {
    final AuthResult result = await _api.login(
      LoginBody(
        email: email,
        password: password,
        deviceName: ref.read(appConfigProvider).deviceName,
      ),
    );
    if (result.status == AuthResultStatus.mfaRequired) {
      final String? token = result.mfaToken;
      if (token == null || token.isEmpty) {
        throw const ApiException.invalidResponse();
      }
      return SignInNeedsMfa(token);
    }
    await _completeSignIn(result);
    return const SignInCompleted();
  }

  /// Second sign-in step with a TOTP [code] or a [recoveryCode].
  Future<void> verifyMfa({
    required String mfaToken,
    String? code,
    String? recoveryCode,
  }) async {
    final AuthResult result = await _api.verifyMfa(
      MfaVerifyBody(
        mfaToken: mfaToken,
        code: code,
        recoveryCode: recoveryCode,
        deviceName: ref.read(appConfigProvider).deviceName,
      ),
    );
    await _completeSignIn(result);
  }

  /// Signs out this device. The server call is best effort: this device is
  /// signed out even when offline. Returns false when the server could not
  /// confirm, so the UI can say the server session will simply expire.
  Future<bool> signOut() async {
    bool confirmed = true;
    if (_tokens.hasAccessToken) {
      try {
        await _api.logout();
      } on ApiException catch (error) {
        confirmed = error.kind == ApiErrorKind.sessionEnded;
      }
    }
    await _tokens.clear();
    if (ref.mounted) {
      state = const SignedOut(reason: SessionEndReason.signedOut);
    }
    return confirmed;
  }

  /// Signs out every device, including this one. Throws [ApiException] when
  /// the server cannot be reached; the user then stays signed in here.
  Future<void> signOutEverywhere() async {
    await _api.logoutAll();
    await _tokens.clear();
    if (ref.mounted) {
      state = const SignedOut(reason: SessionEndReason.signedOutEverywhere);
    }
  }

  /// Ends the local session after the server already revoked it (e.g. a
  /// password reset signs out every device).
  Future<void> endLocalSession(SessionEndReason reason) async {
    await _tokens.clear();
    if (ref.mounted) {
      state = SignedOut(reason: reason);
    }
  }

  /// Re-reads the account summary (e.g. after enabling two-step
  /// verification). Throws [ApiException].
  Future<void> refreshAccount() async {
    final AuthResult session = await _api.currentSession();
    final UserDto? user = session.user;
    final AuthState current = state;
    if (!ref.mounted || user == null || current is! SignedIn) {
      return;
    }
    state = SignedIn(user: user, session: session.session ?? current.session);
  }

  /// Applies a server-confirmed change to the signed-in user's summary
  /// (for example onboarding completed or a new base currency) without
  /// another round trip. Does nothing when signed out.
  void updateUser(UserDto Function(UserDto current) change) {
    final AuthState current = state;
    if (current is SignedIn) {
      state = SignedIn(user: change(current.user), session: current.session);
    }
  }

  Future<void> _completeSignIn(AuthResult result) async {
    final UserDto? user = result.user;
    if (result.status != AuthResultStatus.authenticated || user == null) {
      throw const ApiException.invalidResponse();
    }
    await _tokens.adopt(result);
    if (ref.mounted) {
      state = SignedIn(user: user, session: result.session);
    }
  }

  Future<void> _loadSession({AuthResult? fallback}) async {
    try {
      final AuthResult session = await _api.currentSession();
      final UserDto? user = session.user ?? fallback?.user;
      if (!ref.mounted) {
        return;
      }
      if (user == null) {
        state = const AuthRestoreFailed(ApiException.invalidResponse());
        return;
      }
      state = SignedIn(
        user: user,
        session: session.session ?? fallback?.session,
      );
    } on ApiException catch (error) {
      if (!ref.mounted) {
        return;
      }
      if (error.kind == ApiErrorKind.sessionEnded) {
        state = const SignedOut(reason: SessionEndReason.expired);
        return;
      }
      // The refresh already proved the session; use its account summary when
      // the follow-up lookup fails transiently.
      final UserDto? user = fallback?.user;
      state = user != null
          ? SignedIn(user: user, session: fallback?.session)
          : AuthRestoreFailed(error);
    }
  }

  void _handleSessionEnded(SessionEndReason reason) {
    if (ref.mounted) {
      state = SignedOut(reason: reason);
    }
  }
}
