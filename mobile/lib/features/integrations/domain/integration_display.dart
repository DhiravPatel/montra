import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the integration screens live beyond [AppRoutes.integrations].
abstract final class IntegrationPaths {
  /// One connection's status, syncs and disconnect.
  static String connection(String id) =>
      '/integrations/connections/${Uri.encodeComponent(id)}';
}

/// A provider's availability in words, with its tone.
(String, StatusTone) providerStatusLabel(
  AppLocalizations l10n,
  ProviderInfoStatus status,
) => switch (status) {
  ProviderInfoStatus.available => (
    l10n.integrationStatusAvailable,
    StatusTone.positive,
  ),
  ProviderInfoStatus.notConfigured => (
    l10n.integrationStatusNotConfigured,
    StatusTone.neutral,
  ),
  ProviderInfoStatus.unavailable => (
    l10n.integrationStatusUnavailable,
    StatusTone.caution,
  ),
  ProviderInfoStatus.unrecognized => (
    l10n.integrationStatusUnavailable,
    StatusTone.caution,
  ),
};

/// What kind of provider it is.
String providerKindLabel(AppLocalizations l10n, ProviderInfoKind kind) =>
    switch (kind) {
      ProviderInfoKind.bankData => l10n.integrationKindBankData,
      ProviderInfoKind.accountAggregator =>
        l10n.integrationKindAccountAggregator,
      ProviderInfoKind.card => l10n.integrationKindCard,
      ProviderInfoKind.payments => l10n.integrationKindPayments,
      ProviderInfoKind.unrecognized => l10n.integrationKindOther,
    };

/// A data scope or capability (`transactions`, `balances`, …).
String integrationScopeLabel(AppLocalizations l10n, String scope) =>
    switch (scope) {
      'transactions' => l10n.integrationScopeTransactions,
      'balances' => l10n.integrationScopeBalances,
      'accounts' => l10n.integrationScopeAccounts,
      'statements' => l10n.integrationScopeStatements,
      _ => scope.replaceAll('_', ' '),
    };

/// A connection's state in words, with its tone.
(String, StatusTone) connectionStatusLabel(
  AppLocalizations l10n,
  String status,
) => switch (status) {
  'pending' => (l10n.integrationConnPending, StatusTone.neutral),
  'connected' => (l10n.integrationConnConnected, StatusTone.positive),
  'syncing' => (l10n.integrationConnSyncing, StatusTone.neutral),
  'partial' => (l10n.integrationConnPartial, StatusTone.caution),
  'failed' => (l10n.integrationConnFailed, StatusTone.caution),
  'consent_expired' => (l10n.integrationConnConsentExpired, StatusTone.caution),
  'disconnected' => (l10n.integrationConnDisconnected, StatusTone.neutral),
  'revoked' => (l10n.integrationConnRevoked, StatusTone.neutral),
  _ => (status.replaceAll('_', ' '), StatusTone.neutral),
};

/// Whether a connection can still sync or be disconnected.
bool isConnectionOpen(String status) =>
    status != 'revoked' && status != 'disconnected';

/// A sync run's outcome in words, with its tone.
(String, StatusTone) syncRunStatusLabel(
  AppLocalizations l10n,
  SyncRunDtoStatus status,
) => switch (status) {
  SyncRunDtoStatus.queued => (l10n.integrationRunQueued, StatusTone.neutral),
  SyncRunDtoStatus.running => (l10n.integrationRunRunning, StatusTone.neutral),
  SyncRunDtoStatus.succeeded => (
    l10n.integrationRunSucceeded,
    StatusTone.positive,
  ),
  SyncRunDtoStatus.partial => (l10n.integrationRunPartial, StatusTone.caution),
  SyncRunDtoStatus.failed => (l10n.integrationRunFailed, StatusTone.caution),
  SyncRunDtoStatus.unrecognized => (status.json, StatusTone.neutral),
};

/// What started a sync.
String syncTriggerLabel(AppLocalizations l10n, SyncRunDtoTrigger trigger) =>
    switch (trigger) {
      SyncRunDtoTrigger.manual => l10n.integrationTriggerManual,
      SyncRunDtoTrigger.scheduled => l10n.integrationTriggerScheduled,
      SyncRunDtoTrigger.webhook => l10n.integrationTriggerWebhook,
      SyncRunDtoTrigger.backfill => l10n.integrationTriggerBackfill,
      SyncRunDtoTrigger.unrecognized => trigger.json,
    };

/// A connection or sync error code in words; unknown codes are shown as
/// they are.
String integrationErrorLabel(AppLocalizations l10n, String code) =>
    switch (code) {
      'consent_expired' => l10n.integrationConsentExpired,
      'provider_unavailable' => l10n.integrationErrorProviderUnavailable,
      'reconnect_required' => l10n.integrationReconnectRequired,
      _ => l10n.integrationErrorCode(code),
    };

/// Opens [url] in the system browser. Only `https` (and, for development
/// servers, `http`) links are opened; returns whether it opened.
Future<bool> openInBrowser(String url) async {
  final Uri? uri = Uri.tryParse(url.trim());
  if (uri == null ||
      !(uri.scheme == 'https' || uri.scheme == 'http') ||
      uri.host.isEmpty) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}

/// Opens a URL in the system browser ([openInBrowser]); overridden in
/// tests.
final Provider<Future<bool> Function(String url)> browserLauncherProvider =
    Provider<Future<bool> Function(String url)>((Ref ref) => openInBrowser);
