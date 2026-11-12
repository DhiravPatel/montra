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
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/reports/application/reports_providers.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';
import 'package:montra_mobile/features/reports/domain/report_display.dart';
import 'package:montra_mobile/features/reports/presentation/report_widgets.dart';

/// One report: its status (re-read while it is being made), what it covers,
/// and — once ready — download to share or save. Downloads use a signed
/// link that is fetched on tap and never stored. An expired or failed
/// report can be made again.
class ReportDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [reportId]; [now] is injectable for tests.
  const ReportDetailScreen({required this.reportId, this.now, super.key});

  /// The report.
  final String reportId;

  /// Clock for expiry.
  final DateTime Function()? now;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  DownloadedFile? _file;
  bool _gone = false;
  bool _deleting = false;

  /// Downloads the report once; later actions reuse the bytes.
  Future<DownloadedFile?> _download() async {
    final DownloadedFile? cached = _file;
    if (cached != null) {
      return cached;
    }
    final AppLocalizations l10n = context.l10n;
    try {
      final Access access = await ref
          .read(reportsApiProvider)
          .download(widget.reportId);
      final DownloadedFile file = await ref
          .read(fileDownloaderProvider)
          .fetch(access);
      if (mounted) {
        setState(() => _file = file);
      }
      return file;
    } on ApiException catch (error) {
      if (!mounted) {
        return null;
      }
      if (error.code == ErrorObjectCode.gone) {
        setState(() => _gone = true);
        showSnack(context, l10n.reportExpiredBody);
      } else {
        showSnack(context, describeError(l10n, error));
      }
      return null;
    }
  }

  Future<void> _share() async {
    final DownloadedFile? file = await _download();
    if (file != null && mounted) {
      await shareDownloadedFile(context, ref, file);
    }
  }

  Future<void> _save() async {
    final DownloadedFile? file = await _download();
    if (file != null && mounted) {
      await saveDownloadedFile(context, ref, file);
    }
  }

  Future<void> _again(ReportDto report) async {
    final AppLocalizations l10n = context.l10n;
    try {
      final ReportDto created = await ref
          .read(reportsApiProvider)
          .create(
            ReportInput(
              reportType: ReportInputReportType.fromJson(
                report.reportType.json,
              ),
              format: ReportInputFormat.fromJson(report.format.json),
              title: report.title,
              filters: againFilters(report),
            ),
          );
      ref.invalidate(reportsProvider);
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.reportQueued);
      context.pushReplacement(AppRoutes.reportDetail(created.id));
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  /// Deletes the report after confirming (any status; a report being made
  /// is cancelled) and returns to the list.
  Future<void> _delete(ReportDto report) async {
    final AppLocalizations l10n = context.l10n;
    final String title = reportTitle(
      l10n,
      title: report.title,
      type: report.reportType.json,
    );
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.reportDeleteTitle,
      body: isGenerating(report)
          ? l10n.reportDeleteBodyRunning(title)
          : l10n.reportDeleteBody(title),
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await ref.read(reportsApiProvider).delete(report.id);
      ref.invalidate(reportsProvider);
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.reportDeleted);
      context.pop();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ReportDto> report = ref.watch(
      reportProvider(widget.reportId),
    );
    final ReportController controller = ref.read(
      reportProvider(widget.reportId).notifier,
    );
    final ReportDto? loaded = report.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          loaded == null
              ? l10n.entryReports
              : reportTitle(
                  l10n,
                  title: loaded.title,
                  type: loaded.reportType.json,
                ),
        ),
        bottom: _deleting
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          if (loaded != null)
            IconButton(
              tooltip: l10n.reportDeleteAction,
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : () => _delete(loaded),
            ),
        ],
      ),
      body: AsyncValueView<ReportDto>(
        value: report,
        onRetry: () => ref.invalidate(reportProvider(widget.reportId)),
        data: (ReportDto r) => RefreshIndicator(
          onRefresh: () async {
            try {
              await controller.refresh();
            } on Object {
              ref.invalidate(reportProvider(widget.reportId));
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              ContentFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Status(
                      report: r,
                      gone: _gone,
                      gaveUp: controller.gaveUp,
                      now: (widget.now ?? DateTime.now)(),
                      onShare: _share,
                      onSave: _save,
                      onAgain: () => _again(r),
                    ),
                    const SizedBox(height: Insets.md),
                    _Details(report: r),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.report,
    required this.gone,
    required this.gaveUp,
    required this.now,
    required this.onShare,
    required this.onSave,
    required this.onAgain,
  });

  final ReportDto report;
  final bool gone;
  final bool gaveUp;
  final DateTime now;
  final Future<void> Function() onShare;
  final Future<void> Function() onSave;
  final Future<void> Function() onAgain;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool expired = gone || isExpired(report, now);
    final Widget again = SubmitButton(
      kind: SubmitButtonKind.outlined,
      icon: Icons.refresh,
      label: l10n.reportGenerateAgain,
      onPressed: onAgain,
    );
    if (isGenerating(report)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ReportStatusLabel(status: report.status),
          ),
          const SizedBox(height: Insets.sm),
          Semantics(
            liveRegion: true,
            child: Text(gaveUp ? l10n.reportsStillWorking : l10n.reportMaking),
          ),
          const SizedBox(height: Insets.sm),
          const ExcludeSemantics(child: LinearProgressIndicator()),
        ],
      );
    }
    if (report.status == ReportDtoStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NoticeBanner(
            tone: NoticeTone.warning,
            title: l10n.reportStatusFailed,
            message: reportFailureText(l10n, report.errorCode),
          ),
          const SizedBox(height: Insets.md),
          again,
        ],
      );
    }
    if (expired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NoticeBanner(
            title: l10n.reportStatusExpired,
            message: l10n.reportExpiredBody,
          ),
          const SizedBox(height: Insets.md),
          again,
        ],
      );
    }
    if (report.status != ReportDtoStatus.completed) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: ReportStatusLabel(status: report.status),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ReportStatusLabel(status: report.status),
        ),
        const SizedBox(height: Insets.sm),
        Text(l10n.reportReadyBody),
        const SizedBox(height: Insets.md),
        SubmitButton(
          icon: Icons.share,
          label: l10n.fileShare,
          onPressed: onShare,
        ),
        const SizedBox(height: Insets.sm),
        SubmitButton(
          kind: SubmitButtonKind.outlined,
          icon: Icons.download,
          label: l10n.fileSave,
          onPressed: onSave,
        ),
      ],
    );
  }
}

/// Reports of the current state (no `window`).
bool _currentState(ReportDto report) => const <ReportDtoReportType>{
  ReportDtoReportType.account,
  ReportDtoReportType.budget,
  ReportDtoReportType.subscription,
  ReportDtoReportType.goal,
  ReportDtoReportType.recurring,
}.contains(report.reportType);

class _Details extends StatelessWidget {
  const _Details({required this.report});

  final ReportDto report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final Filters f = report.filters;
    return SectionCard(
      title: l10n.reportDetailsTitle,
      children: <Widget>[
        DetailRow(
          label: l10n.reportTypeLabel,
          value: reportTypeLabel(l10n, report.reportType.json),
        ),
        DetailRow(
          label: l10n.reportFormatLabel,
          value: reportFormatLabel(l10n, report.format.json),
        ),
        DetailRow(
          label: l10n.reportPeriodLabel,
          value: switch (report.window) {
            final Window w => l10n.reportWindowDays(
              LocalDates.displayRange(w.from, w.to, locale: locale),
              w.days,
            ),
            null when _currentState(report) => l10n.reportCurrentState,
            null => reportPeriodText(l10n, f, locale: locale),
          },
        ),
        if (f.includePending ?? false)
          DetailRow(label: l10n.reportIncludePending, value: l10n.statusOn),
        DetailRow(
          label: l10n.reportRequestedLabel,
          value: formatDateTime(report.requestedAt, locale: locale),
        ),
        if (report.completedAt case final DateTime done)
          DetailRow(
            label: l10n.reportCompletedLabel,
            value: formatDateTime(done, locale: locale),
          ),
        if (report.rowCount case final int rows)
          DetailRow(label: l10n.reportRowsLabel, value: l10n.reportRows(rows)),
        if (report.expiresAt case final DateTime until)
          DetailRow(
            label: l10n.reportExpiresLabel,
            value: formatDateTime(until, locale: locale),
          ),
        DetailRow(label: l10n.reportTimezoneLabel, value: report.timezone),
        const SizedBox(height: Insets.sm),
      ],
    );
  }
}
