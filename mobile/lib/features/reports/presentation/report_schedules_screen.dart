import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/reports/application/reports_providers.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';
import 'package:montra_mobile/features/reports/domain/report_display.dart';
import 'package:montra_mobile/features/reports/presentation/report_paths.dart';

enum _ScheduleAction { edit, pause, resume, delete }

/// Scheduled reports (`GET /reports/schedules`): each makes a report every
/// week or month. A schedule can be edited, paused, resumed (it starts
/// again from the next week or month; missed periods are not made) or
/// deleted after confirming.
class ReportSchedulesScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ReportSchedulesScreen({super.key});

  @override
  ConsumerState<ReportSchedulesScreen> createState() =>
      _ReportSchedulesScreenState();
}

class _ReportSchedulesScreenState extends ConsumerState<ReportSchedulesScreen> {
  String? _deleting;

  Future<void> _refresh() async {
    ref.invalidate(reportSchedulesProvider);
    try {
      await ref.read(reportSchedulesProvider.future);
    } on Object {
      // Shown by the list state.
    }
  }

  /// Pauses ([enabled] false) or resumes a schedule (`PATCH` with
  /// `enabled` and `version`); a change made elsewhere reloads the list.
  Future<void> _setEnabled(ScheduleDto s, {required bool enabled}) async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _deleting = s.id);
    try {
      await ref
          .read(reportsApiProvider)
          .updateSchedule(
            s.id,
            SchedulePatch(enabled: enabled, version: s.version),
          );
      ref.invalidate(reportSchedulesProvider);
      if (mounted) {
        showSnack(
          context,
          enabled ? l10n.scheduleResumed : l10n.schedulePaused,
        );
      }
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.versionConflict) {
        ref.invalidate(reportSchedulesProvider);
      }
      if (mounted) {
        showSnack(
          context,
          error.code == ErrorObjectCode.versionConflict
              ? l10n.versionConflictReloaded
              : describeError(l10n, error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = null);
      }
    }
  }

  Future<void> _actions(ScheduleDto s, String title) async {
    final AppLocalizations l10n = context.l10n;
    final _ScheduleAction? action = await showOptionSheet<_ScheduleAction>(
      context,
      title: title,
      options: <SheetOption<_ScheduleAction>>[
        SheetOption<_ScheduleAction>(
          value: _ScheduleAction.edit,
          label: l10n.actionEdit,
          icon: Icons.edit_outlined,
        ),
        if (s.enabled)
          SheetOption<_ScheduleAction>(
            value: _ScheduleAction.pause,
            label: l10n.schedulePause,
            subtitle: l10n.schedulePauseHelp,
            icon: Icons.pause_circle_outline,
          )
        else
          SheetOption<_ScheduleAction>(
            value: _ScheduleAction.resume,
            label: l10n.scheduleResume,
            subtitle: l10n.scheduleResumeHelp,
            icon: Icons.play_circle_outline,
          ),
        SheetOption<_ScheduleAction>(
          value: _ScheduleAction.delete,
          label: l10n.actionDelete,
          icon: Icons.delete_outline,
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _ScheduleAction.edit:
        await context.push(ReportPaths.editSchedule(s.id));
      case _ScheduleAction.pause:
        await _setEnabled(s, enabled: false);
      case _ScheduleAction.resume:
        await _setEnabled(s, enabled: true);
      case _ScheduleAction.delete:
        await _delete(s, title);
    }
  }

  Future<void> _delete(ScheduleDto s, String title) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.scheduleDeleteTitle,
      body: l10n.scheduleDeleteBody(title),
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = s.id);
    try {
      await ref.read(reportsApiProvider).deleteSchedule(s.id);
      ref.invalidate(reportSchedulesProvider);
      if (mounted) {
        showSnack(context, l10n.scheduleDeleted);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<ScheduleDto>> schedules = ref.watch(
      reportSchedulesProvider,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportSchedulesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newReportSchedule),
        icon: const Icon(Icons.add),
        label: Text(l10n.scheduleNew),
      ),
      body: AsyncValueView<List<ScheduleDto>>(
        value: schedules,
        onRetry: _refresh,
        data: (List<ScheduleDto> list) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: <Widget>[
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.lg),
                  child: MessageStateView(
                    icon: Icons.event_repeat_outlined,
                    title: l10n.schedulesEmptyTitle,
                    body: l10n.schedulesEmptyBody,
                    action: FilledButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.newReportSchedule),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.scheduleNew),
                    ),
                  ),
                )
              else ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.md,
                    Insets.sm,
                    Insets.md,
                    Insets.sm,
                  ),
                  child: Text(l10n.schedulesNote),
                ),
                for (final ScheduleDto s in list)
                  Builder(
                    builder: (BuildContext context) {
                      final String title = reportTitle(
                        l10n,
                        title: s.title,
                        type: s.reportType.json,
                        cadence: s.cadence.json,
                      );
                      return ListTile(
                        leading: const CircleAvatar(
                          child: ExcludeSemantics(
                            child: Icon(Icons.event_repeat_outlined),
                          ),
                        ),
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.scheduleCadenceAndFormat(
                                cadenceLabel(l10n, s.cadence.json),
                                reportFormatLabel(l10n, s.format.json),
                              ),
                            ),
                            if (s.enabled)
                              Text(
                                l10n.scheduleNextRun(
                                  formatDateTime(s.nextRunAt, locale: locale),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: Insets.xs),
                                child: StatusLabel(
                                  text: l10n.scheduleOff,
                                  icon: Icons.pause_circle_outline,
                                ),
                              ),
                          ],
                        ),
                        trailing: _deleting == s.id
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                tooltip: l10n.scheduleActionsLabel(title),
                                icon: const Icon(Icons.more_vert),
                                onPressed: _deleting == null
                                    ? () => _actions(s, title)
                                    : null,
                              ),
                        onTap: _deleting == null
                            ? () => context.push(ReportPaths.editSchedule(s.id))
                            : null,
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
