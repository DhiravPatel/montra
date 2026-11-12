import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;

/// Coded errors of the notification endpoints (docs/API.md "Notifications
/// and integrations notes"); null for codes this area does not own.
String? notificationDetailMessage(AppLocalizations l10n, Detail detail) =>
    switch (detail.code) {
      'always_on_category' => l10n.notifAlwaysOnError,
      _ => null,
    };
