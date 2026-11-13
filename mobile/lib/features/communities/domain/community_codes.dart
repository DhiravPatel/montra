import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;
import 'package:montra_mobile/core/formatting/dates.dart';

/// Localized text for the coded `DOMAIN_RULE_VIOLATION` (422) and
/// `CONFLICT` (409) answers of communities, posts, comments and
/// invitations (docs/API.md "Domain rule codes"); null for other codes.
String? communityDetailMessage(AppLocalizations l10n, Detail detail) {
  final Map<String, String> p = detail.params ?? const <String, String>{};
  return switch (detail.code) {
    'account_restricted' => l10n.communityErrorAccountRestricted,
    'already_deleted' => l10n.communityErrorAlreadyDeleted,
    'comment_locked' => l10n.communityErrorCommentLocked,
    'comments_closed' => l10n.communityErrorCommentsClosed,
    'community_suspended' => l10n.communityErrorSuspended,
    'content_unavailable' => l10n.communityErrorContentUnavailable,
    'invitation_only' => l10n.communityErrorInvitationOnly,
    'join_community_first' => l10n.communityErrorJoinFirst,
    'new_account_links' => l10n.communityErrorNewAccountLinks,
    'not_accepting_members' => l10n.communityErrorNotAcceptingMembers,
    'not_accepting_posts' => l10n.communityErrorNotAcceptingPosts,
    'own_content' => l10n.communityErrorOwnContent,
    'owner_protected' => l10n.communityErrorOwnerProtected,
    'poll_closed' => l10n.communityErrorPollClosed,
    'post_locked' => l10n.communityErrorPostLocked,
    'posting_restricted' when p['until'] != null =>
      l10n.communityErrorPostingRestrictedUntil(_instant(l10n, p['until']!)),
    'posting_restricted' => l10n.communityErrorPostingRestricted,
    _ => null,
  };
}

/// An RFC 3339 instant from error params, in the user's locale and time
/// zone; the raw value when it cannot be parsed.
String _instant(AppLocalizations l10n, String value) {
  final DateTime? at = DateTime.tryParse(value);
  if (at == null) {
    return value;
  }
  try {
    return formatDateTime(at, locale: l10n.localeName);
  } on Object {
    // Date symbols for the locale are not loaded (outside the app).
    return value;
  }
}
