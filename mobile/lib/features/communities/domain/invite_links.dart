import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:share_plus/share_plus.dart';

/// The web portal's origin used to build shareable invitation links
/// (`--dart-define=WEB_APP_URL=https://app.example`). Only `http(s)`
/// origins are used; without one the app shares the invitation code
/// itself, which people paste into "Join with a link". Overridden in tests.
final Provider<String?> webAppOriginProvider = Provider<String?>(
  (Ref ref) => webOriginFrom(const String.fromEnvironment('WEB_APP_URL')),
);

/// [value] as an `http(s)` origin without a trailing slash, or null.
String? webOriginFrom(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty) {
    return null;
  }
  return '${uri.scheme}://${uri.authority}';
}

/// The shareable join link for an invitation [token]: the token travels in
/// the URL fragment (`/communities/join#token=…`), so it never reaches a web
/// server log. Null without a web [origin].
String? communityJoinLink(String? origin, String token) =>
    origin == null ? null : '$origin/communities/join#token=$token';

final RegExp _tokenShape = RegExp(r'^[A-Za-z0-9_-]+$');

/// Whether [token] has the shape of a community invitation token.
bool isInviteToken(String token) =>
    token.length >= CommunityTokenInput.tokenMinLength &&
    token.length <= CommunityTokenInput.tokenMaxLength &&
    _tokenShape.hasMatch(token);

/// The invitation token of an opened or pasted join link
/// (`…/communities/join#token=…`, `?token=` accepted too), or of a bare
/// pasted code. Whitespace from wrapped messages is ignored. Null when
/// [input] is neither.
String? inviteTokenFrom(String input) {
  final String compact = input.replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) {
    return null;
  }
  if (isInviteToken(compact)) {
    return compact;
  }
  final Uri? uri = Uri.tryParse(compact);
  if (uri == null) {
    return null;
  }
  return inviteTokenOfUri(uri);
}

/// The token in [uri]'s fragment (or query) when its path is a community
/// join link.
String? inviteTokenOfUri(Uri uri) {
  final String path = uri.path.endsWith('/') && uri.path.length > 1
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  if (!path.endsWith('/communities/join')) {
    return null;
  }
  String? candidate;
  if (uri.fragment.isNotEmpty) {
    try {
      candidate = Uri.splitQueryString(uri.fragment)['token'];
    } on FormatException {
      candidate = null;
    }
  }
  candidate ??= uri.queryParameters['token'];
  return candidate != null && isInviteToken(candidate) ? candidate : null;
}

/// Shares text (an invitation link) through the system share sheet.
/// Overridden in tests.
final Provider<Future<void> Function(String text)> shareTextProvider =
    Provider<Future<void> Function(String text)>(
      (Ref ref) => (String text) async {
        await SharePlus.instance.share(ShareParams(text: text));
      },
    );
