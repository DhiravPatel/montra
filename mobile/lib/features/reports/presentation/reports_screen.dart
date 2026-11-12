import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/reports/application/reports_providers.dart';
import 'package:montra_mobile/features/reports/domain/report_display.dart';
import 'package:montra_mobile/features/reports/presentation/report_widgets.dart';

/// Reports and exports (`GET /reports`). The list re-reads itself every few
/// seconds while a report is being made, and stops when none is, when the
/// screen is left, or after a few minutes (then pull to refresh).
class ReportsScreen extends ConsumerWidget {
  /// Creates the screen; [now] is injectable for tests.
  const ReportsScreen({this.now, super.key});

  /// Clock for expiry.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<ReportDto>> reports = ref.watch(reportsProvider);
    final ReportsController controller = ref.read(reportsProvider.notifier);
    Future<void> refresh() async {
      try {
        await controller.refresh();
      } on Object {
        ref.invalidate(reportsProvider);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.entryReports),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.reportSchedulesTitle,
            icon: const Icon(Icons.event_repeat_outlined),
            onPressed: () => context.push(AppRoutes.reportSchedules),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newReport),
        icon: const Icon(Icons.add),
        label: Text(l10n.reportNew),
      ),
      body: AsyncValueView<List<ReportDto>>(
        value: reports,
        onRetry: () => ref.invalidate(reportsProvider),
        loadingLabel: l10n.reportsLoading,
        data: (List<ReportDto> list) {
          final bool working = list.any(isGenerating);
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Insets.lg),
                    child: MessageStateView(
                      icon: Icons.summarize_outlined,
                      title: l10n.reportsEmptyTitle,
                      body: l10n.reportsEmptyBody,
                      action: FilledButton.icon(
                        onPressed: () => context.push(AppRoutes.newReport),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.reportNew),
                      ),
                    ),
                  )
                else ...<Widget>[
                  if (working)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.md,
                        Insets.sm,
                        Insets.md,
                        0,
                      ),
                      child: NoticeBanner(
                        message: controller.gaveUp
                            ? l10n.reportsStillWorking
                            : l10n.reportsWorkingNote,
                      ),
                    ),
                  for (final ReportDto r in list)
                    ReportTile(
                      report: r,
                      now: (now ?? DateTime.now)(),
                      onTap: () => context.push(AppRoutes.reportDetail(r.id)),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One report: title, type and format, when it was requested, its status
/// and how long it can be downloaded.
class ReportTile extends StatelessWidget {
  /// Creates the tile.
  const ReportTile({
    required this.report,
    required this.now,
    this.onTap,
    super.key,
  });

  /// The report.
  final ReportDto report;

  /// The current time (for expiry).
  final DateTime now;

  /// Opens the report.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final DateTime? expires = report.expiresAt;
    final bool expired = isExpired(report, now);
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        child: ExcludeSemantics(child: Icon(Icons.summarize_outlined)),
      ),
      title: Text(
        reportTitle(l10n, title: report.title, type: report.reportType.json),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.reportTypeAndFormat(
              reportTypeLabel(l10n, report.reportType.json),
              reportFormatLabel(l10n, report.format.json),
            ),
          ),
          Text(
            l10n.reportRequestedAt(
              formatDateTime(report.requestedAt, locale: locale),
            ),
          ),
          if (report.status == ReportDtoStatus.completed &&
              !expired &&
              expires != null)
            Text(
              l10n.reportAvailableUntil(
                formatDateTime(expires, locale: locale),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: Insets.xs),
            child: ReportStatusLabel(
              status: expired && report.status == ReportDtoStatus.completed
                  ? ReportDtoStatus.expired
                  : report.status,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
