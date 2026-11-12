import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/integrations/application/integrations_providers.dart';
import 'package:montra_mobile/features/integrations/data/integrations_api.dart';
import 'package:montra_mobile/features/integrations/domain/integration_display.dart';

/// One connection (`GET /integrations/{id}/status`): its state, consent,
/// linked account and the last syncs with their counts and error codes;
/// "Sync now" and "Disconnect" (which can also void the transactions it
/// imported).
class ConnectionScreen extends ConsumerWidget {
  /// Creates the screen.
  const ConnectionScreen({required this.connectionId, super.key});

  /// The connection.
  final String connectionId;

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    try {
      await ref.read(integrationsApiProvider).sync(connectionId);
      ref.invalidate(connectionStatusProvider(connectionId));
      if (context.mounted) {
        showSnack(context, l10n.integrationSyncStarted);
      }
    } on ApiException catch (error) {
      if (!context.mounted) {
        return;
      }
      // 409 without a detail code: a sync is already running.
      final bool running =
          error.code == ErrorObjectCode.conflict &&
          error.details.every((Detail d) => d.code == null);
      showSnack(
        context,
        running ? l10n.integrationSyncRunning : describeError(l10n, error),
      );
    }
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    bool deleteData = false;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setInner) => AlertDialog(
          title: Text(l10n.integrationDisconnectTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.integrationDisconnectBody),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: deleteData,
                  onChanged: (bool? v) =>
                      setInner(() => deleteData = v ?? false),
                  title: Text(l10n.integrationDeleteData),
                  subtitle: Text(l10n.integrationDeleteDataHelp),
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.integrationDisconnect),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final DisconnectResult result = await ref
          .read(integrationsApiProvider)
          .disconnect(connectionId, deleteData: deleteData);
      if (deleteData) {
        ref.financeChanged();
      }
      ref
        ..invalidate(integrationsOverviewProvider)
        ..invalidate(connectionStatusProvider(connectionId));
      if (!context.mounted) {
        return;
      }
      showSnack(
        context,
        deleteData
            ? l10n.integrationDisconnectedVoided(result.deletedRecords)
            : l10n.integrationDisconnected,
      );
      if (router.canPop()) {
        router.pop();
      }
    } on Object catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<ConnectionStatus> status = ref.watch(
      connectionStatusProvider(connectionId),
    );
    final String? providerName = ref
        .watch(integrationsOverviewProvider)
        .value
        ?.providers
        .where((ProviderInfo p) => p.id == status.value?.provider)
        .map((ProviderInfo p) => p.name)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(providerName ?? l10n.integrationConnectionTitle),
      ),
      body: AsyncValueView<ConnectionStatus>(
        value: status,
        onRetry: () => ref.invalidate(connectionStatusProvider(connectionId)),
        data: (ConnectionStatus c) {
          final (String label, StatusTone tone) = connectionStatusLabel(
            l10n,
            c.status.json,
          );
          final bool open = isConnectionOpen(c.status.json);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(connectionStatusProvider(connectionId));
              try {
                await ref.read(connectionStatusProvider(connectionId).future);
              } on Object {
                // Shown by the screen state.
              }
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: Insets.xl),
              children: <Widget>[
                SectionCard(
                  title: l10n.integrationConnectionTitle,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.xs,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: StatusLabel(text: label, tone: tone),
                      ),
                    ),
                    if (c.consentScope.isNotEmpty)
                      DetailRow(
                        label: l10n.integrationScopeLabel,
                        value: c.consentScope
                            .map((String s) => integrationScopeLabel(l10n, s))
                            .join(', '),
                      ),
                    if (c.consentGrantedAt case final DateTime at)
                      DetailRow(
                        label: l10n.integrationConsentGranted,
                        value: formatDateTime(at, locale: locale),
                      ),
                    if (c.consentExpiresAt case final DateTime at)
                      DetailRow(
                        label: l10n.integrationConsentExpires,
                        value: formatDateTime(at, locale: locale),
                      ),
                    if (c.linkedAccountId case final String accountId)
                      DetailRow(
                        label: l10n.integrationLinkedAccount,
                        value: l10n.integrationOpenAccount,
                        onTap: () =>
                            context.push(AppRoutes.accountDetail(accountId)),
                      ),
                    DetailRow(
                      label: l10n.integrationLastSyncLabel,
                      value: c.lastSyncAt == null
                          ? l10n.integrationNeverSynced
                          : formatDateTime(c.lastSyncAt!, locale: locale),
                    ),
                    if (c.lastErrorCode case final String code
                        when code.isNotEmpty)
                      DetailRow(
                        label: l10n.integrationLastProblem,
                        value: integrationErrorLabel(l10n, code),
                      ),
                  ],
                ),
                if (open)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SubmitButton(
                          label: l10n.integrationSyncNow,
                          icon: Icons.sync,
                          onPressed: () => _sync(context, ref),
                        ),
                        const SizedBox(height: Insets.sm),
                        // Not a SubmitButton: the confirmation dialog
                        // already prevents a second tap.
                        OutlinedButton.icon(
                          onPressed: () => _disconnect(context, ref),
                          icon: const Icon(Icons.link_off),
                          label: Text(l10n.integrationDisconnect),
                        ),
                      ],
                    ),
                  ),
                SectionCard(
                  title: l10n.integrationRunsTitle,
                  children: <Widget>[
                    if (c.runs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.md,
                          vertical: Insets.xs,
                        ),
                        child: Text(l10n.integrationNoRuns),
                      ),
                    for (final SyncRunDto run in c.runs)
                      _RunTile(run: run, locale: locale),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run, required this.locale});

  final SyncRunDto run;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final (String label, StatusTone tone) = syncRunStatusLabel(
      l10n,
      run.status,
    );
    return ListTile(
      title: Text(
        '${formatDateTime(run.createdAt, locale: locale)} · '
        '${syncTriggerLabel(l10n, run.trigger)}',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xs),
            child: StatusLabel(text: label, tone: tone),
          ),
          Text(
            l10n.integrationRunCounts(
              run.itemsFetched,
              run.itemsCreated,
              run.itemsUpdated,
              run.itemsSkipped,
            ),
          ),
          if (run.errorCode case final String code when code.isNotEmpty)
            Text(integrationErrorLabel(l10n, code)),
        ],
      ),
    );
  }
}
