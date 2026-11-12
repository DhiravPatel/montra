import 'package:montra_mobile/app/l10n/l10n.dart';

/// What a moderation action did (wire value of `action`).
String moderationActionLabel(AppLocalizations l10n, String action) =>
    switch (action) {
      'hide' => l10n.moderationActionHide,
      'remove' => l10n.moderationActionRemove,
      'restore' => l10n.moderationActionRestore,
      'pin' => l10n.moderationActionPin,
      'unpin' => l10n.moderationActionUnpin,
      'lock' => l10n.moderationActionLock,
      'unlock' => l10n.moderationActionUnlock,
      'warn' => l10n.moderationActionWarn,
      'restrict' => l10n.moderationActionRestrict,
      'ban' => l10n.moderationActionBan,
      'unban' => l10n.moderationActionUnban,
      'dismiss_report' => l10n.moderationActionDismissReport,
      'escalate' => l10n.moderationActionEscalate,
      'suspend' => l10n.moderationActionSuspend,
      'unsuspend' => l10n.moderationActionUnsuspend,
      _ => action.replaceAll('_', ' '),
    };

/// What a moderation action was about (wire value of `target_type`).
String moderationTargetLabel(AppLocalizations l10n, String targetType) =>
    switch (targetType) {
      'post' => l10n.moderationTargetPost,
      'comment' => l10n.moderationTargetComment,
      'member' => l10n.moderationTargetMember,
      'profile' => l10n.moderationTargetProfile,
      'group' => l10n.moderationTargetGroup,
      'community' => l10n.moderationTargetCommunity,
      _ => l10n.statusWordUnknown,
    };

/// An appeal's state in words (wire value of `status`): `upheld` means the
/// action stands, `overturned` that it was reversed.
String appealStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'open' => l10n.appealStatusOpen,
      'upheld' => l10n.appealStatusUpheld,
      'overturned' => l10n.appealStatusOverturned,
      _ => l10n.statusWordUnknown,
    };

/// What an appeal's state means for the person who appealed.
String appealStatusHelp(AppLocalizations l10n, String status) =>
    switch (status) {
      'open' => l10n.appealStatusOpenHelp,
      'upheld' => l10n.appealStatusUpheldHelp,
      'overturned' => l10n.appealStatusOverturnedHelp,
      _ => '',
    };

/// A report's state in words (wire value of `status`).
String reportStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'open' => l10n.contentReportStatusOpen,
      'under_review' => l10n.contentReportStatusUnderReview,
      'actioned' => l10n.contentReportStatusActioned,
      'dismissed' => l10n.contentReportStatusDismissed,
      'escalated' => l10n.contentReportStatusEscalated,
      _ => l10n.statusWordUnknown,
    };

/// What a report's state means for the person who filed it.
String reportStatusHelp(AppLocalizations l10n, String status) =>
    switch (status) {
      'open' || 'under_review' => l10n.contentReportStatusOpenHelp,
      'actioned' => l10n.contentReportStatusActionedHelp,
      'dismissed' => l10n.contentReportStatusDismissedHelp,
      'escalated' => l10n.contentReportStatusEscalatedHelp,
      _ => '',
    };
