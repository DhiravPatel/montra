import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;

/// Localized text for the coded answers of the social area (docs/API.md
/// "Social and groups notes"); null for codes it does not own.
String? socialDetailMessage(AppLocalizations l10n, Detail detail) =>
    switch (detail.code) {
      'already_friends' => l10n.friendCodeAlreadyFriends,
      'request_pending' => l10n.friendCodeRequestPending,
      'requests_closed' => l10n.friendCodeRequestsClosed,
      'username_taken' => l10n.usernameTaken,
      'username_invalid' => l10n.codeUsernameInvalid,
      'username_reserved' => l10n.codeUsernameReserved,
      'avatar_file_invalid' => l10n.codeAvatarFileInvalid,
      'query_too_short' => l10n.codeQueryTooShort(detail.params?['min'] ?? '3'),
      _ => null,
    };
