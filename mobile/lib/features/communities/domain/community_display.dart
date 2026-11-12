import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';

/// Wire values of the visibility choices, in the order offered.
const List<String> communityVisibilities = <String>[
  'public',
  'private',
  'invite_only',
];

/// Name of a community visibility (wire value).
String communityVisibilityLabel(AppLocalizations l10n, String visibility) =>
    switch (visibility) {
      'public' => l10n.communityVisibilityPublic,
      'private' => l10n.communityVisibilityPrivate,
      'invite_only' => l10n.communityVisibilityInviteOnly,
      _ => l10n.statusWordUnknown,
    };

/// What a community visibility means for people who want to join.
String communityVisibilityHelp(AppLocalizations l10n, String visibility) =>
    switch (visibility) {
      'public' => l10n.communityVisibilityPublicHelp,
      'private' => l10n.communityVisibilityPrivateHelp,
      'invite_only' => l10n.communityVisibilityInviteOnlyHelp,
      _ => '',
    };

/// Name of a member role (wire value).
String communityRoleLabel(AppLocalizations l10n, String role) => switch (role) {
  'owner' => l10n.communityRoleOwner,
  'moderator' => l10n.communityRoleModerator,
  'member' => l10n.communityRoleMember,
  _ => l10n.statusWordUnknown,
};

/// Name of a membership status (wire value).
String communityMemberStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'active' => l10n.communityMemberStatusActive,
      'pending' => l10n.communityMemberStatusPending,
      'banned' => l10n.communityMemberStatusBanned,
      'left' => l10n.communityMemberStatusLeft,
      _ => l10n.statusWordUnknown,
    };

/// Kinds a member can post (wire values), in the order offered.
const List<String> postKinds = <String>[
  'discussion',
  'question',
  'resource',
  'poll',
];

/// Name of a post kind (wire value).
String postKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'discussion' => l10n.postKindDiscussion,
  'question' => l10n.postKindQuestion,
  'resource' => l10n.postKindResource,
  'poll' => l10n.postKindPoll,
  'challenge_update' => l10n.postKindChallengeUpdate,
  _ => l10n.postKindDiscussion,
};

/// Labels a member can choose (wire values); `verified_guidance` is for
/// moderators only.
List<String> postLabelsFor({required bool moderator}) => <String>[
  'personal_experience',
  'question',
  'resource',
  if (moderator) 'verified_guidance',
];

/// Name of a post label (wire value).
String postLabelText(AppLocalizations l10n, String label) => switch (label) {
  'personal_experience' => l10n.postLabelPersonalExperience,
  'verified_guidance' => l10n.postLabelVerifiedGuidance,
  'question' => l10n.postLabelQuestion,
  'resource' => l10n.postLabelResource,
  _ => l10n.postLabelPersonalExperience,
};

/// Reaction kinds in display order.
const List<CommunityReactionInputKind> reactionKinds =
    <CommunityReactionInputKind>[
      CommunityReactionInputKind.like,
      CommunityReactionInputKind.helpful,
      CommunityReactionInputKind.insightful,
      CommunityReactionInputKind.support,
    ];

/// Name of a reaction.
String reactionLabel(AppLocalizations l10n, CommunityReactionInputKind kind) =>
    switch (kind) {
      CommunityReactionInputKind.like => l10n.reactionLike,
      CommunityReactionInputKind.helpful => l10n.reactionHelpful,
      CommunityReactionInputKind.insightful => l10n.reactionInsightful,
      CommunityReactionInputKind.support => l10n.reactionSupport,
      CommunityReactionInputKind.unrecognized => l10n.statusWordUnknown,
    };

/// The count of [kind] in [counts].
int reactionCount(
  CommunityReactionCounts counts,
  CommunityReactionInputKind kind,
) => switch (kind) {
  CommunityReactionInputKind.like => counts.like,
  CommunityReactionInputKind.helpful => counts.helpful,
  CommunityReactionInputKind.insightful => counts.insightful,
  CommunityReactionInputKind.support => counts.support,
  CommunityReactionInputKind.unrecognized => 0,
};

/// Report reasons in the order offered.
const List<PostReportInputReason> reportReasons = <PostReportInputReason>[
  PostReportInputReason.spam,
  PostReportInputReason.abuse,
  PostReportInputReason.harassment,
  PostReportInputReason.scam,
  PostReportInputReason.impersonation,
  PostReportInputReason.misinformation,
  PostReportInputReason.privacy,
  PostReportInputReason.other,
];

/// Name of a report reason (wire value).
String reportReasonLabel(AppLocalizations l10n, String reason) =>
    switch (reason) {
      'spam' => l10n.contentReportReasonSpam,
      'abuse' => l10n.contentReportReasonAbuse,
      'harassment' => l10n.contentReportReasonHarassment,
      'scam' => l10n.contentReportReasonScam,
      'impersonation' => l10n.contentReportReasonImpersonation,
      'misinformation' => l10n.contentReportReasonMisinformation,
      'privacy' => l10n.contentReportReasonPrivacy,
      _ => l10n.contentReportReasonOther,
    };

/// The URL of a resource link when it is safe to open: only `http` and
/// `https` links with a host and no `user:password@` part are ever opened
/// (in the system browser). Credentials in a link can disguise the real
/// host (`https://bank.example@evil.example`), so they are refused, as on
/// the web.
Uri? safeLink(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  final Uri? uri = Uri.tryParse(text);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final String scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https' ? uri : null;
}

/// Topics typed as a comma-separated list: trimmed, without blanks or
/// repeats (case-insensitive), in the order typed.
List<String> parseTopics(String text) {
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final String raw in text.split(',')) {
    final String topic = raw.trim();
    if (topic.isNotEmpty && seen.add(topic.toLowerCase())) {
      out.add(topic);
    }
  }
  return out;
}

/// Contract pattern of a community URL name (`CommunityInput.slug`).
final RegExp communitySlugPattern = RegExp(CommunityInput.slugPattern);

/// Comments ordered as threads: each top-level comment followed by its
/// replies (depth-first, oldest first), with their nesting depth. Replies
/// whose parent is not in the list are shown as top-level comments.
List<({CommunityCommentDto comment, int depth})> threadComments(
  List<CommunityCommentDto> comments,
) {
  final Set<String> ids = <String>{
    for (final CommunityCommentDto c in comments) c.id,
  };
  final Map<String, List<CommunityCommentDto>> children =
      <String, List<CommunityCommentDto>>{};
  final List<CommunityCommentDto> roots = <CommunityCommentDto>[];
  for (final CommunityCommentDto c in comments) {
    final String? parent = c.parentCommentId;
    if (parent != null && parent != c.id && ids.contains(parent)) {
      (children[parent] ??= <CommunityCommentDto>[]).add(c);
    } else {
      roots.add(c);
    }
  }
  int byTime(CommunityCommentDto a, CommunityCommentDto b) =>
      a.createdAt.compareTo(b.createdAt);
  roots.sort(byTime);
  final List<({CommunityCommentDto comment, int depth})> out =
      <({CommunityCommentDto comment, int depth})>[];
  final Set<String> placed = <String>{};
  void visit(CommunityCommentDto c, int depth) {
    if (!placed.add(c.id)) {
      return;
    }
    out.add((comment: c, depth: depth));
    final List<CommunityCommentDto> replies =
        (children[c.id] ?? <CommunityCommentDto>[])..sort(byTime);
    for (final CommunityCommentDto r in replies) {
      visit(r, depth + 1);
    }
  }

  for (final CommunityCommentDto root in roots) {
    visit(root, 0);
  }
  // Anything left (a reply cycle) is still shown.
  for (final CommunityCommentDto c in comments) {
    visit(c, 0);
  }
  return out;
}

/// An invitation's state in words (wire value).
String invitationStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'active' => l10n.communityInvitationStatusActive,
      'used' => l10n.communityInvitationStatusUsed,
      'declined' => l10n.communityInvitationStatusDeclined,
      'revoked' => l10n.communityInvitationStatusRevoked,
      'expired' => l10n.communityInvitationStatusExpired,
      _ => l10n.statusWordUnknown,
    };
