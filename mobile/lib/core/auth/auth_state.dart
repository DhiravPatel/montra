import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/session_tokens.dart';

/// Authentication state that drives routing.
@immutable
sealed class AuthState {
  const AuthState();
}

/// Restoring a stored session at startup (splash screen).
final class AuthRestoring extends AuthState {
  /// Creates the state.
  const AuthRestoring();
}

/// A stored session exists but could not be confirmed (offline, outage).
/// Credentials are kept; the splash screen offers a retry.
final class AuthRestoreFailed extends AuthState {
  /// Creates the state.
  const AuthRestoreFailed(this.error);

  /// What went wrong.
  final ApiException error;
}

/// No session. [reason] explains why one ended, when it did.
final class SignedOut extends AuthState {
  /// Creates the state.
  const SignedOut({this.reason});

  /// Why the previous session ended, if it did.
  final SessionEndReason? reason;
}

/// Signed in as [user].
final class SignedIn extends AuthState {
  /// Creates the state.
  const SignedIn({required this.user, this.session});

  /// Account summary from the server.
  final UserDto user;

  /// The current session, when known.
  final SessionDto? session;
}

/// Result of the first sign-in step.
sealed class SignInOutcome {
  const SignInOutcome();
}

/// Signed in; routing moves on automatically.
final class SignInCompleted extends SignInOutcome {
  /// Creates the outcome.
  const SignInCompleted();
}

/// A second factor is needed: call `verifyMfa` with [mfaToken].
final class SignInNeedsMfa extends SignInOutcome {
  /// Creates the outcome.
  const SignInNeedsMfa(this.mfaToken);

  /// Short-lived challenge token (5 minutes, 5 attempts).
  final String mfaToken;
}
