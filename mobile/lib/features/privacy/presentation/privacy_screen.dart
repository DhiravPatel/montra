import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/help/help_guide.dart';
import 'package:montra_mobile/core/help/help_guide_button.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/privacy/application/privacy_providers.dart';
import 'package:montra_mobile/features/privacy/data/privacy_api.dart';
import 'package:montra_mobile/features/privacy/domain/privacy_display.dart';
import 'package:montra_mobile/features/settings/presentation/reauth_sheet.dart';

/// Privacy & data: consents (versions from `GET /legal`), a copy of all
/// the user's data (exports are made in the background and downloaded
/// through a short-lived link, then shared or saved), and closing or
/// deleting the account. [exportId] (from a notification) highlights one
/// export.
class PrivacyScreen extends ConsumerWidget {
  /// Creates the screen.
  const PrivacyScreen({this.exportId, super.key});

  /// The export to highlight, if any.
  final String? exportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        actions: const <Widget>[HelpGuideButton(HelpGuide.privacy)],
        title: Text(l10n.privacyTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(consentsProvider)
            ..invalidate(legalProvider)
            ..invalidate(deletionProvider);
          await ref.read(exportsProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: Insets.xl),
          children: <Widget>[
            ContentFrame(child: Text(l10n.privacyIntro)),
            const ContentFrame(child: _ConsentsSection()),
            ContentFrame(child: _ExportsSection(highlight: exportId)),
            const ContentFrame(child: _AccountSection()),
          ],
        ),
      ),
    );
  }
}

/// A section body for an async value inside a scrolling list.
Widget _asyncSection<T>(
  AsyncValue<T> value, {
  required Widget Function(T data) data,
  required VoidCallback onRetry,
}) {
  final T? current = value.value;
  if (current == null && value.hasError && !value.isLoading) {
    return SizedBox(
      height: 320,
      child: ErrorStateView(error: value.error!, onRetry: onRetry),
    );
  }
  if (current == null) {
    return const Padding(
      padding: EdgeInsets.all(Insets.lg),
      child: LoadingStateView(),
    );
  }
  return data(current);
}

class _ConsentsSection extends ConsumerWidget {
  const _ConsentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<ConsentDto>> consents = ref.watch(consentsProvider);
    final LegalDto? legal = ref.watch(legalProvider).value;
    return SectionCard(
      title: l10n.privacyConsentsTitle,
      children: <Widget>[
        _asyncSection<List<ConsentDto>>(
          consents,
          onRetry: () => ref.invalidate(consentsProvider),
          data: (List<ConsentDto> list) {
            ConsentDto? given(ConsentVersionDtoType type) => list
                .where(
                  (ConsentDto c) =>
                      c.consentType == type.json && c.revokedAt == null,
                )
                .firstOrNull;
            String? versionOf(ConsentVersionDtoType type) => legal?.consents
                .where((ConsentVersionDto v) => v.typeValue == type)
                .firstOrNull
                ?.version;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final ConsentVersionDtoType type in requiredConsents)
                  ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: Text(consentTitle(l10n, type)),
                    subtitle: Text(
                      given(type) == null
                          ? consentBody(l10n, type)
                          : '${l10n.privacyConsentAccepted(given(type)!.version)}\n'
                                '${consentBody(l10n, type)}',
                    ),
                  ),
                const Divider(),
                for (final OptionalConsent c in optionalConsents)
                  if (c.grantable || given(c.type) != null)
                    _ConsentSwitch(
                      consent: c,
                      given: given(c.type),
                      version: versionOf(c.type),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ConsentSwitch extends ConsumerStatefulWidget {
  const _ConsentSwitch({required this.consent, this.given, this.version});

  final OptionalConsent consent;
  final ConsentDto? given;
  final String? version;

  @override
  ConsumerState<_ConsentSwitch> createState() => _ConsentSwitchState();
}

class _ConsentSwitchState extends ConsumerState<_ConsentSwitch> {
  bool _busy = false;

  Future<void> _change(bool on) async {
    final AppLocalizations l10n = context.l10n;
    final ConsentVersionDtoType type = widget.consent.type;
    final String? version = widget.version;
    if (on && version == null) {
      showSnack(context, l10n.privacyConsentVersionMissing);
      return;
    }
    setState(() => _busy = true);
    try {
      final PrivacyApi api = ref.read(privacyApiProvider);
      if (on) {
        await api.grant(grantTypeOf(type), version!);
      } else {
        await api.revoke(type.json);
      }
      ref.invalidate(consentsProvider);
      if (mounted) {
        showSnack(
          context,
          on ? l10n.privacyConsentGiven : l10n.privacyConsentWithdrawn,
        );
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.validationError) {
        // A newer wording version: read it again before the next try.
        ref.invalidate(legalProvider);
      }
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool on = widget.given != null;
    final bool canChange = on || widget.consent.grantable;
    return SwitchListTile(
      value: on,
      title: Text(consentTitle(l10n, widget.consent.type)),
      subtitle: Text(consentBody(l10n, widget.consent.type)),
      onChanged: _busy || !canChange ? null : _change,
    );
  }
}

class _ExportsSection extends ConsumerWidget {
  const _ExportsSection({this.highlight});

  final String? highlight;

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    try {
      final ExportDto? created = await runWithReauth<ExportDto>(
        context,
        () => ref.read(privacyApiProvider).requestExport(),
      );
      if (created == null) {
        return;
      }
      ref.read(exportsProvider.notifier).added(created);
      if (context.mounted) {
        showSnack(context, l10n.privacyExportRequested);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<ExportDto>> exports = ref.watch(exportsProvider);
    final bool gaveUp = ref.read(exportsProvider.notifier).gaveUp;
    return SectionCard(
      title: l10n.privacyExportTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(l10n.privacyExportIntro),
        ),
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: SubmitButton(
            kind: SubmitButtonKind.outlined,
            icon: Icons.download_outlined,
            label: l10n.privacyExportRequest,
            onPressed: () => _request(context, ref),
          ),
        ),
        _asyncSection<List<ExportDto>>(
          exports,
          onRetry: () => ref.invalidate(exportsProvider),
          data: (List<ExportDto> list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Text(l10n.privacyExportNone),
                ),
              if (gaveUp)
                Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: NoticeBanner(message: l10n.privacyExportStillWorking),
                ),
              for (final ExportDto e in list)
                _ExportTile(export: e, highlighted: e.id == highlight),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportTile extends ConsumerStatefulWidget {
  const _ExportTile({required this.export, required this.highlighted});

  final ExportDto export;
  final bool highlighted;

  @override
  ConsumerState<_ExportTile> createState() => _ExportTileState();
}

enum _FileChoice { share, save }

class _ExportTileState extends ConsumerState<_ExportTile> {
  bool _downloading = false;

  Future<void> _download() async {
    final AppLocalizations l10n = context.l10n;
    final String? fileId = widget.export.fileId;
    if (fileId == null) {
      return;
    }
    setState(() => _downloading = true);
    DownloadedFile? file;
    try {
      file = await ref.read(fileDownloaderProvider).download(fileId);
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.gone ||
          error.code == ErrorObjectCode.notFound) {
        await ref.read(exportsProvider.notifier).refresh();
      }
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
    if (file == null || !mounted) {
      return;
    }
    final _FileChoice? choice = await showOptionSheet<_FileChoice>(
      context,
      title: l10n.privacyExportReadyTitle,
      options: <SheetOption<_FileChoice>>[
        SheetOption<_FileChoice>(
          value: _FileChoice.share,
          label: l10n.fileShare,
          icon: Icons.share_outlined,
        ),
        SheetOption<_FileChoice>(
          value: _FileChoice.save,
          label: l10n.fileSave,
          icon: Icons.save_alt_outlined,
        ),
      ],
    );
    if (!mounted || choice == null) {
      return;
    }
    switch (choice) {
      case _FileChoice.share:
        await shareDownloadedFile(context, ref, file);
      case _FileChoice.save:
        await saveDownloadedFile(context, ref, file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ExportDto e = widget.export;
    final (String status, StatusTone tone) = exportStatus(l10n, e);
    final DateTime? expires = e.expiresAt;
    return Container(
      color: widget.highlighted
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: ListTile(
        title: Text(
          l10n.privacyExportRequestedOn(
            formatDateTime(e.requestedAt, locale: locale),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: Insets.xs),
            StatusLabel(text: status, tone: tone),
            if (e.status == ExportDtoStatus.completed && expires != null)
              Text(
                l10n.privacyExportExpires(
                  formatShortDate(expires, locale: locale),
                ),
              ),
            if (e.status == ExportDtoStatus.failed)
              Text(l10n.privacyExportFailedHelp),
            if (e.status == ExportDtoStatus.expired)
              Text(l10n.privacyExportExpiredHelp),
          ],
        ),
        trailing: e.status == ExportDtoStatus.completed && e.fileId != null
            ? (_downloading
                  ? Semantics(
                      label: l10n.fileDownloading,
                      child: const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  : IconButton(
                      tooltip: l10n.privacyExportDownload,
                      icon: const Icon(Icons.download),
                      onPressed: _download,
                    ))
            : null,
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final DeletionDto? deletion = ref.watch(deletionProvider).value;
    final bool scheduled = deletion?.status == DeletionDtoStatus.scheduled;
    return SectionCard(
      title: l10n.privacyAccountTitle,
      children: <Widget>[
        if (scheduled && deletion?.scheduledFor != null)
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.deletionScheduledFor(
                formatShortDate(deletion!.scheduledFor!, locale: locale),
              ),
            ),
          ),
        ListTile(
          leading: const Icon(Icons.speed_outlined),
          title: Text(l10n.limitsTitle),
          subtitle: Text(l10n.privacyLimitsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.limits),
        ),
        ListTile(
          leading: const Icon(Icons.pause_circle_outline),
          title: Text(l10n.deactivateTitle),
          subtitle: Text(l10n.privacyDeactivateSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.deactivateAccount),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            scheduled ? l10n.deletionScheduledTitle : l10n.deletionTitle,
          ),
          subtitle: Text(
            scheduled
                ? l10n.privacyDeletionScheduledSubtitle
                : l10n.privacyDeletionSubtitle,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.deleteAccount),
        ),
      ],
    );
  }
}
