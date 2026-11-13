import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/integrations/application/integrations_providers.dart';
import 'package:montra_mobile/features/integrations/data/integrations_api.dart';
import 'package:montra_mobile/features/integrations/domain/integration_display.dart';

/// Bank and card connections (`GET /integrations`): every provider with
/// its honest availability ("not configured" is shown as such) and the
/// user's connections. Connecting asks for an explicit consent, then opens
/// the provider's page in the system browser; the provider sends the user
/// back to the Montra web app, which finishes the connection. Montra never
/// asks for bank credentials, and works fully without connections.
class IntegrationsScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [accountId] preselects the account to connect.
  const IntegrationsScreen({this.accountId, super.key});

  /// Account to connect, when opened from an account.
  final String? accountId;

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  bool _connecting = false;

  Future<void> _refresh() async {
    ref.invalidate(integrationsOverviewProvider);
    try {
      await ref.read(integrationsOverviewProvider.future);
    } on Object {
      // Shown by the screen state.
    }
  }

  Future<void> _connect(ProviderInfo provider) async {
    if (_connecting) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final bool consented = await _askConsent(provider);
    if (!consented || !mounted) {
      return;
    }
    final AccountDto? account = await showAccountPicker(
      context,
      selectedId: widget.accountId,
      title: l10n.integrationChooseAccount,
    );
    if (account == null || !mounted) {
      return;
    }
    setState(() => _connecting = true);
    try {
      final ConnectResult result = await ref
          .read(integrationsApiProvider)
          .connect(provider.id, account.id);
      ref.invalidate(integrationsOverviewProvider);
      final bool opened = await ref.read(browserLauncherProvider)(
        result.authorizeUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() => _connecting = false);
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(
            opened
                ? l10n.integrationContinueTitle
                : l10n.integrationOpenFailedTitle,
          ),
          content: Text(
            opened
                ? l10n.integrationContinueBody(provider.name)
                : l10n.integrationOpenFailedBody,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.actionDone),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<bool> _askConsent(ProviderInfo provider) async {
    final AppLocalizations l10n = context.l10n;
    bool agreed = false;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setInner) => AlertDialog(
          title: Text(l10n.integrationConsentTitle(provider.name)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.integrationConsentPurpose),
                const SizedBox(height: Insets.xs),
                Text(provider.consentPurpose),
                const SizedBox(height: Insets.sm),
                Text(
                  l10n.integrationConsentScope(
                    provider.consentScope
                        .map((String s) => integrationScopeLabel(l10n, s))
                        .join(', '),
                  ),
                ),
                const SizedBox(height: Insets.sm),
                Text(l10n.integrationConsentDays(provider.consentDays)),
                const SizedBox(height: Insets.sm),
                Text(l10n.integrationNoCredentials),
                const SizedBox(height: Insets.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: agreed,
                  onChanged: (bool? v) => setInner(() => agreed = v ?? false),
                  title: Text(l10n.integrationConsentCheck),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: agreed
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: Text(l10n.integrationConnect),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Overview> overview = ref.watch(
      integrationsOverviewProvider,
    );
    return Scaffold(
      appBar: AppBar(
        actions: const <Widget>[HelpGuideButton(HelpGuide.noBank)],
        title: Text(l10n.integrationsTitle),
        bottom: _connecting || (overview.isLoading && overview.hasValue)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: AsyncValueView<Overview>(
        value: overview,
        onRetry: () => ref.invalidate(integrationsOverviewProvider),
        data: (Overview o) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: Insets.xl),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.md,
                  Insets.md,
                  0,
                ),
                child: NoticeBanner(message: l10n.integrationIntro),
              ),
              SectionCard(
                title: l10n.integrationConnectionsTitle,
                children: <Widget>[
                  if (o.connections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.xs,
                      ),
                      child: Text(l10n.integrationNoConnections),
                    ),
                  for (final ConnectionDto c in o.connections)
                    _ConnectionTile(
                      connection: c,
                      providerName: o.providers
                          .where((ProviderInfo p) => p.id == c.provider)
                          .map((ProviderInfo p) => p.name)
                          .firstOrNull,
                    ),
                ],
              ),
              SectionCard(
                title: l10n.integrationProvidersTitle,
                children: <Widget>[
                  if (o.providers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.xs,
                      ),
                      child: Text(l10n.integrationNoProviders),
                    ),
                  for (final ProviderInfo p in o.providers)
                    _ProviderTile(
                      provider: p,
                      busy: _connecting,
                      onConnect: () => _connect(p),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(
                  l10n.integrationCallbackNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.busy,
    required this.onConnect,
  });

  final ProviderInfo provider;
  final bool busy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final (String status, StatusTone tone) = providerStatusLabel(
      l10n,
      provider.status,
    );
    final bool available = provider.status == ProviderInfoStatus.available;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(provider.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: Insets.xs),
          Text(
            <String>[
              providerKindLabel(l10n, provider.kind),
              if (provider.countries.isNotEmpty)
                l10n.integrationCountries(provider.countries.join(', ')),
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (provider.capabilities.isNotEmpty)
            Text(
              l10n.integrationCapabilities(
                provider.capabilities
                    .map((String c) => integrationScopeLabel(l10n, c))
                    .join(', '),
              ),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: Insets.xs),
          StatusLabel(text: status, tone: tone),
          if (!available) ...<Widget>[
            const SizedBox(height: Insets.xs),
            Text(
              provider.status == ProviderInfoStatus.notConfigured
                  ? l10n.integrationNotConfiguredHelp
                  : l10n.integrationUnavailableHelp,
            ),
            if (provider.statusReason case final String reason
                when reason.isNotEmpty)
              Text(
                l10n.integrationReason(reason),
                style: theme.textTheme.bodySmall,
              ),
          ],
          if (available) ...<Widget>[
            const SizedBox(height: Insets.sm),
            FilledButton.icon(
              onPressed: busy ? null : onConnect,
              icon: const Icon(Icons.link),
              label: Text(l10n.integrationConnect),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.connection, this.providerName});

  final ConnectionDto connection;
  final String? providerName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final (String status, StatusTone tone) = connectionStatusLabel(
      l10n,
      connection.status.json,
    );
    final DateTime? lastSync = connection.lastSyncAt;
    return ListTile(
      title: Text(providerName ?? connection.provider),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xs),
            child: StatusLabel(text: status, tone: tone),
          ),
          Text(
            lastSync == null
                ? l10n.integrationNeverSynced
                : l10n.integrationLastSync(
                    formatDateTime(lastSync, locale: locale),
                  ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(IntegrationPaths.connection(connection.id)),
    );
  }
}
