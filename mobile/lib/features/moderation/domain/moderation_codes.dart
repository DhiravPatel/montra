import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;

/// Localized text for the coded answers of moderation and appeals
/// (docs/API.md "Domain rule codes"); null for other codes.
String? moderationDetailMessage(AppLocalizations l10n, Detail detail) =>
    switch (detail.code) {
      'appeal_needs_other_moderator' => l10n.moderationErrorOtherModerator,
      'appeal_window_passed' => l10n.moderationErrorAppealWindowPassed,
      'not_appealable' => l10n.moderationErrorNotAppealable,
      'appeal_pending' => l10n.appealAlreadySent,
      'appeal_already_decided' => l10n.moderationErrorAppealDecided,
      'already_reported' => l10n.codeAlreadyReported,
      _ => null,
    };
