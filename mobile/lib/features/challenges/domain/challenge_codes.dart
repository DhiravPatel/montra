import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;

/// Localized text for the coded answers of challenges (docs/API.md "Domain
/// rule codes"); null for other codes.
String? challengeDetailMessage(AppLocalizations l10n, Detail detail) =>
    switch (detail.code) {
      'challenge_cancelled' => l10n.challengeErrorCancelled,
      'challenge_inactive' => l10n.challengeErrorInactive,
      'challenge_not_open' => l10n.challengeErrorNotOpen,
      'join_challenge_first' => l10n.challengeErrorJoinFirst,
      'leaderboard_opt_in_required' => l10n.challengeErrorLeaderboardOptIn,
      'no_leaderboard' => l10n.challengeErrorNoLeaderboard,
      _ => null,
    };
