import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/settings/application/sessions_controller.dart';

/// Settings → Security → Devices and sessions.
///
/// Lists active sessions with a "This device" marker and lets the user sign
/// out any other session after confirming. Handles loading, empty, error
/// (with reference and retry), offline and permission-denied states.
class SessionsScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [now] is injectable for tests.
  const SessionsScreen({this.now, super.key});

  /// Clock used for "last active" labels.
  final DateTime Function()? now;

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  String? _revokingId;

  Future<void> _revoke(SessionDto session, String deviceLabel) async {
    final AppLocalizations l10n = context.l10n;
    if (_revokingId != null) {
      return;
    }
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.sessionRevokeConfirmTitle,
      body: l10n.sessionRevokeConfirmBody(deviceLabel),
      confirmLabel: l10n.sessionRevoke,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _revokingId = session.id);
    try {
      final bool revoked = await ref
          .read(sessionsControllerProvider.notifier)
          .revoke(session);
      if (mounted) {
        showSnack(
          context,
          revoked ? l10n.sessionRevoked : l10n.sessionAlreadyEnded,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _revokingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<SessionDto>> sessions = ref.watch(
      sessionsControllerProvider,
    );
    final bool refreshing = sessions.isLoading && sessions.hasValue;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionsTitle),
        bottom: refreshing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: AsyncValueView<List<SessionDto>>(
        value: sessions,
        onRetry: () => ref.invalidate(sessionsControllerProvider),
        isEmpty: (List<SessionDto> list) => list.isEmpty,
        empty: MessageStateView(
          icon: Icons.devices_other_outlined,
          title: l10n.sessionsEmpty,
          action: OutlinedButton.icon(
            onPressed: () => ref.invalidate(sessionsControllerProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.actionRetry),
          ),
        ),
        data: (List<SessionDto> list) => RefreshIndicator(
          onRefresh: () =>
              ref.read(sessionsControllerProvider.notifier).reload(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            itemCount: list.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(),
            itemBuilder: (BuildContext context, int index) {
              final SessionDto session = list[index];
              return _SessionTile(
                session: session,
                now: (widget.now ?? DateTime.now)(),
                busy: _revokingId == session.id,
                onRevoke: session.current || _revokingId != null
                    ? null
                    : (String label) => _revoke(session, label),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.now,
    required this.busy,
    required this.onRevoke,
  });

  final SessionDto session;
  final DateTime now;
  final bool busy;
  final ValueChanged<String>? onRevoke;

  static String clientLabel(AppLocalizations l10n, SessionDtoClientKind kind) =>
      switch (kind) {
        SessionDtoClientKind.android => l10n.sessionClientAndroid,
        SessionDtoClientKind.ios => l10n.sessionClientIos,
        SessionDtoClientKind.web => l10n.sessionClientWeb,
        SessionDtoClientKind.unknown ||
        SessionDtoClientKind.unrecognized => l10n.sessionClientUnknown,
      };

  static IconData clientIcon(SessionDtoClientKind kind) => switch (kind) {
    SessionDtoClientKind.android => Icons.phone_android,
    SessionDtoClientKind.ios => Icons.phone_iphone,
    SessionDtoClientKind.web => Icons.laptop,
    SessionDtoClientKind.unknown ||
    SessionDtoClientKind.unrecognized => Icons.devices_other,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final String client = clientLabel(l10n, session.clientKind);
    final String? deviceName = session.deviceName?.trim();
    final String title = deviceName == null || deviceName.isEmpty
        ? client
        : deviceName;
    final ValueChanged<String>? revoke = onRevoke;
    return ListTile(
      leading: ExcludeSemantics(child: Icon(clientIcon(session.clientKind))),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != client) Text(client),
          Text(
            l10n.sessionLastActive(
              formatRelativeTime(
                l10n,
                session.lastSeenAt,
                now: now,
                locale: locale,
              ),
            ),
          ),
          Text(
            l10n.sessionSignedInOn(
              formatShortDate(session.createdAt, locale: locale),
            ),
          ),
          if (session.mfaVerified)
            Text(l10n.sessionTwoStepVerified, style: theme.textTheme.bodySmall),
          if (session.current) ...<Widget>[
            const SizedBox(height: Insets.xs),
            StatusLabel(
              text: l10n.sessionCurrentDevice,
              tone: StatusTone.positive,
              icon: Icons.smartphone,
            ),
          ],
        ],
      ),
      isThreeLine: true,
      trailing: session.current
          ? null
          : busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: revoke == null ? null : () => revoke(title),
              // Screen readers hear which device is affected.
              child: Text(
                l10n.sessionRevoke,
                semanticsLabel: l10n.sessionRevokeLabel(title),
              ),
            ),
    );
  }
}
