import 'package:flutter/foundation.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/config/app_config.dart';

/// `@username`, or null without a username.
String? usernameHandle(String? username) =>
    username == null || username.isEmpty ? null : '@$username';

/// The user's relationship with a person, in words (null for none).
String? connectionLabel(AppLocalizations l10n, PublicProfileConnection c) =>
    switch (c) {
      PublicProfileConnection.self => l10n.friendConnectionSelf,
      PublicProfileConnection.friend => l10n.friendConnectionFriend,
      PublicProfileConnection.requestSent => l10n.friendConnectionRequestSent,
      PublicProfileConnection.requestReceived =>
        l10n.friendConnectionRequestReceived,
      PublicProfileConnection.none ||
      PublicProfileConnection.unrecognized => null,
    };

/// The "who may send me friend requests" choices, in words.
String friendRequestPolicyLabel(
  AppLocalizations l10n,
  ProfileDtoAllowFriendRequests value,
) => switch (value) {
  ProfileDtoAllowFriendRequests.everyone => l10n.socialRequestsEveryone,
  ProfileDtoAllowFriendRequests.friendsOfFriends =>
    l10n.socialRequestsFriendsOfFriends,
  ProfileDtoAllowFriendRequests.nobody => l10n.socialRequestsNobody,
  ProfileDtoAllowFriendRequests.unrecognized => value.json,
};

/// The username rules of `PATCH /me`: 3–30 letters, digits, `_` and `.`
/// (the server stores them in lowercase and ignores a leading `@`).
/// Returns a localized problem, or null when [input] is acceptable (an
/// empty value clears the username).
String? usernameProblem(AppLocalizations l10n, String input) {
  String value = input.trim();
  if (value.startsWith('@')) {
    value = value.substring(1);
  }
  if (value.isEmpty) {
    return null;
  }
  if (value.length < 3 || value.length > 30) {
    return l10n.usernameLengthRule;
  }
  if (!RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(value)) {
    return l10n.usernameCharactersRule;
  }
  return null;
}

/// Invitation links (`…/groups/join#token=…`): the token lives in the URL
/// fragment so it never reaches a server log. Tokens are shown once and
/// are never stored or logged by the app.
abstract final class InviteLinks {
  static final RegExp _tokenShape = RegExp(r'^[A-Za-z0-9_\-]{16,128}$');

  /// Whether [token] has the shape of an invitation token.
  static bool isPlausibleToken(String token) => _tokenShape.hasMatch(token);

  /// The token in a pasted link (`#token=` or `?token=`) or a bare token;
  /// whitespace from wrapped messages is ignored. Null when [input] is
  /// neither.
  static String? tokenFrom(String input) {
    final String compact = input.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) {
      return null;
    }
    if (isPlausibleToken(compact)) {
      return compact;
    }
    final Uri? uri = Uri.tryParse(compact);
    if (uri == null) {
      return null;
    }
    return tokenFromUri(uri);
  }

  /// The token carried by [uri] (fragment first, then query), or null.
  static String? tokenFromUri(Uri uri) {
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

  /// A shareable group link for [token]: `/groups/join` with the token in
  /// the fragment, on the web portal's origin when the build sets
  /// `--dart-define=WEB_APP_URL` (as community links do), otherwise on the
  /// API's origin (the backend's `WEB_APP_URL` is expected to be the same
  /// https domain in production, which the app claims through App Links).
  static Uri groupJoinLink(AppConfig config, String token) {
    final Uri? web = Uri.tryParse(
      const String.fromEnvironment('WEB_APP_URL').trim(),
    );
    final Uri api =
        web != null &&
            (web.scheme == 'https' || web.scheme == 'http') &&
            web.host.isNotEmpty
        ? web
        : config.apiBaseUrl;
    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
      path: '/groups/join',
      fragment: 'token=$token',
    );
  }
}

/// A person as shown in lists (friends, requests, blocks, mutes, search),
/// whatever DTO the server used.
@immutable
class PersonView {
  /// Creates the view.
  const PersonView({
    required this.userId,
    required this.displayName,
    this.username,
    this.bio,
    this.connection = PublicProfileConnection.none,
    this.muted = false,
    this.blockedByMe = false,
  });

  /// From a `PublicProfile`.
  PersonView.ofProfile(PublicProfile p)
    : this(
        userId: p.userId,
        displayName: p.displayName,
        username: p.username,
        bio: p.bio,
        connection: p.connection,
        muted: p.muted,
        blockedByMe: p.blockedByMe,
      );

  /// From a `BlockDTO`.
  PersonView.ofBlock(BlockDto b)
    : this(
        userId: b.userId,
        displayName: b.displayName,
        username: b.username,
        bio: b.bio,
        connection: PublicProfileConnection.fromJson(b.connection.json),
        muted: b.muted,
        blockedByMe: b.blockedByMe,
      );

  /// From a `MuteDTO`.
  PersonView.ofMute(MuteDto m)
    : this(
        userId: m.userId,
        displayName: m.displayName,
        username: m.username,
        bio: m.bio,
        connection: PublicProfileConnection.fromJson(m.connection.json),
        muted: m.muted,
        blockedByMe: m.blockedByMe,
      );

  /// The person's user ID.
  final String userId;

  /// Name shown in the app.
  final String displayName;

  /// Public handle, if any.
  final String? username;

  /// Short bio, if shared.
  final String? bio;

  /// Relationship with the signed-in user.
  final PublicProfileConnection connection;

  /// Whether the signed-in user muted them.
  final bool muted;

  /// Whether the signed-in user blocked them.
  final bool blockedByMe;

  @override
  String toString() => 'PersonView($userId)';
}
