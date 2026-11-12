import 'package:flutter/foundation.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Which flow an emailed link belongs to.
enum AuthLinkKind {
  /// `/verify-email#token=...`
  verifyEmail,

  /// `/reset-password#token=...`
  resetPassword,
}

/// A verification or password-reset link from an email.
@immutable
class AuthLink {
  /// Creates the link.
  const AuthLink(this.kind, this.token);

  /// Flow.
  final AuthLinkKind kind;

  /// Single-use token (never logged).
  final String token;

  @override
  bool operator ==(Object other) =>
      other is AuthLink && other.kind == kind && other.token == token;

  @override
  int get hashCode => Object.hash(kind, token);

  @override
  String toString() => 'AuthLink($kind)';
}

/// Parses emailed links such as
/// `https://app.example/verify-email#token=...` or
/// `http://localhost:5173/reset-password#token=...`.
///
/// Tokens travel in the URL fragment so they never reach web servers or
/// proxy logs; `?token=` is accepted as a fallback. Whitespace that email
/// clients insert when wrapping long links is removed.
abstract final class AuthLinks {
  static final RegExp _tokenShape = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Extracts a plausible token from [uri], or null.
  static String? tokenFrom(Uri uri) {
    String? candidate;
    if (uri.fragment.isNotEmpty) {
      try {
        candidate = Uri.splitQueryString(uri.fragment)['token'];
      } on FormatException {
        candidate = null;
      }
    }
    candidate ??= uri.queryParameters['token'];
    if (candidate == null || !isPlausibleToken(candidate)) {
      return null;
    }
    return candidate;
  }

  /// Whether [token] has the shape of a Montra link token.
  static bool isPlausibleToken(String token) =>
      token.length >= 16 &&
      token.length <= TokenBody.tokenMaxLength &&
      _tokenShape.hasMatch(token);

  /// Parses a pasted link. Returns null when it is not a Montra auth link.
  static AuthLink? parse(String input) {
    final String compact = input.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(compact);
    if (uri == null) {
      return null;
    }
    final String path = uri.path.endsWith('/') && uri.path.length > 1
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    final AuthLinkKind? kind = path.endsWith('/verify-email')
        ? AuthLinkKind.verifyEmail
        : path.endsWith('/reset-password')
        ? AuthLinkKind.resetPassword
        : null;
    final String? token = tokenFrom(uri);
    if (kind == null || token == null) {
      return null;
    }
    return AuthLink(kind, token);
  }
}
