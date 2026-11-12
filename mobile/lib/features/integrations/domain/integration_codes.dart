import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart' show Detail;

/// Coded errors of the integration endpoints (docs/API.md "Notifications
/// and integrations notes"); null for codes this area does not own.
String? integrationDetailMessage(AppLocalizations l10n, Detail detail) =>
    switch (detail.code) {
      'consent_expired' => l10n.integrationConsentExpired,
      'reconnect_required' => l10n.integrationReconnectRequired,
      'linked_not_reversible' => l10n.integrationLinkedNotReversible,
      _ => null,
    };
