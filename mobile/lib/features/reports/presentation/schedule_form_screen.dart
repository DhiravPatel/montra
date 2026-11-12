import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/partial_patch.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/reports/application/reports_providers.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';
import 'package:montra_mobile/features/reports/domain/report_display.dart';
import 'package:montra_mobile/features/reports/presentation/report_widgets.dart';

/// Schedules a report (`POST /reports/schedules`): every week (covering the
/// previous full week) or every month (the previous full month). With
/// [scheduleId] it edits that schedule (`PATCH /reports/schedules/{id}`):
/// only the changed title, format and cadence are sent with the schedule's
/// `version`; a change made elsewhere reloads the form.
class ScheduleFormScreen extends ConsumerStatefulWidget {
  /// Creates the form; [scheduleId] edits an existing schedule.
  const ScheduleFormScreen({this.scheduleId, super.key});

  /// The schedule to edit; null to create one.
  final String? scheduleId;

  @override
  ConsumerState<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends ConsumerState<ScheduleFormScreen> {
  /// Whether a change made elsewhere reloaded the schedule.
  bool _conflict = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? id = widget.scheduleId;
    if (id == null) {
      return const _ScheduleForm();
    }
    Widget frame(Widget body) => Scaffold(
      appBar: AppBar(title: Text(l10n.scheduleEditTitle)),
      body: body,
    );
    // There is no single-schedule GET; the list holds every schedule.
    return ref
        .watch(reportSchedulesProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => frame(const LoadingStateView()),
          error: (Object error, StackTrace _) => frame(
            ErrorStateView(
              error: error,
              onRetry: () => ref.invalidate(reportSchedulesProvider),
            ),
          ),
          data: (List<ScheduleDto> list) {
            for (final ScheduleDto s in list) {
              if (s.id == id) {
                return _ScheduleForm(
                  key: ValueKey<int>(s.version),
                  original: s,
                  conflict: _conflict,
                  onConflict: () => setState(() => _conflict = true),
                );
              }
            }
            return frame(
              MessageStateView(
                icon: Icons.search_off,
                title: l10n.scheduleNotFound,
              ),
            );
          },
        );
  }
}

class _ScheduleForm extends ConsumerStatefulWidget {
  const _ScheduleForm({
    this.original,
    this.conflict = false,
    this.onConflict,
    super.key,
  });

  final ScheduleDto? original;

  /// Whether this is the reloaded version after a conflict.
  final bool conflict;

  /// Called when saving found a newer version (the list is re-read).
  final VoidCallback? onConflict;

  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(
    text: _initialTitle(),
  );
  late ReportInputReportType _type = widget.original == null
      ? ReportInputReportType.monthlySummary
      : ReportInputReportType.fromJson(widget.original!.reportType.json);
  late String _format =
      widget.original?.format.json ?? ReportInputFormat.csv.json;
  late String _cadence =
      widget.original?.cadence.json ?? ScheduleInputCadence.monthly.json;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'report_type': 'type',
    'format': 'format',
    'cadence': 'cadence',
    'title': 'title',
  };

  bool get _editing => widget.original != null;

  /// The schedule's own title; the server's English default is left empty
  /// (shown as the localized type name, and kept as the default).
  String _initialTitle() {
    final ScheduleDto? s = widget.original;
    if (s == null) {
      return '';
    }
    final String english = serverDefaultReportTitles[s.reportType.json] ?? '';
    return s.title == english || s.title == '$english (${s.cadence.json})'
        ? ''
        : s.title;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Map<String, Object?> _values() => <String, Object?>{
    'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
    'format': _format,
    'cadence': _cadence,
  };

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final ScheduleDto? original = widget.original;
    try {
      if (original == null) {
        final String title = _title.text.trim();
        await ref
            .read(reportsApiProvider)
            .createSchedule(
              ScheduleInput(
                reportType: ScheduleInputReportType.fromJson(_type.json),
                format: ScheduleInputFormat.fromJson(_format),
                cadence: ScheduleInputCadence.fromJson(_cadence),
                title: title.isEmpty ? null : title,
              ),
            );
      } else {
        final Map<String, Object?> before = <String, Object?>{
          'title': _initialTitle().isEmpty ? null : _initialTitle(),
          'format': original.format.json,
          'cadence': original.cadence.json,
        };
        final Map<String, Object?> body = partialPatch(
          before: before,
          after: <String, Object?>{..._values(), 'version': original.version},
          textFields: const <String>{'title'},
        );
        if (!patchHasChanges(body)) {
          showSnack(context, l10n.scheduleNothingChanged);
          return;
        }
        await ref
            .read(reportsApiProvider)
            .updateSchedule(original.id, SchedulePatch.fromJson(body));
      }
      ref.invalidate(reportSchedulesProvider);
      if (!mounted) {
        return;
      }
      showSnack(context, _editing ? l10n.scheduleSaved : l10n.scheduleCreated);
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == ErrorObjectCode.versionConflict && _editing) {
        widget.onConflict?.call();
        ref.invalidate(reportSchedulesProvider);
        return;
      }
      setState(
        () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.scheduleEditTitle : l10n.scheduleNewTitle),
      ),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            if (_editing && widget.conflict) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.warning,
                message: l10n.versionConflictReloaded,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (_editing) ...<Widget>[
              DetailRow(
                label: l10n.reportTypeLabel,
                value: reportTypeLabel(l10n, _type.json),
              ),
              Text(
                l10n.scheduleTypeFixed,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              ReportTypeField(
                value: _type,
                errorText: _errors['type'],
                onChanged: (ReportInputReportType t) =>
                    setState(() => _type = t),
              ),
            ReportFormatChips(
              value: _format,
              onChanged: (String f) => setState(() => _format = f),
            ),
            FormSectionHeader(l10n.scheduleCadenceLabel),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final ScheduleInputCadence c in <ScheduleInputCadence>[
                  ScheduleInputCadence.weekly,
                  ScheduleInputCadence.monthly,
                ])
                  ChoiceChip(
                    label: Text(cadenceLabel(l10n, c.json)),
                    selected: _cadence == c.json,
                    onSelected: (_) => setState(() => _cadence = c.json),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(
                _cadence == ScheduleInputCadence.weekly.json
                    ? l10n.scheduleWeeklyHelp
                    : l10n.scheduleMonthlyHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_errors['cadence'] case final String e)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: Insets.md),
            TextFormField(
              controller: _title,
              maxLength: ScheduleInput.titleMaxLength,
              decoration: InputDecoration(
                labelText: l10n.reportTitleLabel,
                helperText: l10n.reportTitleHelp,
                errorText: _errors['title'],
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              _editing ? l10n.scheduleEditNote : l10n.schedulesNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              icon: _editing
                  ? Icons.save_outlined
                  : Icons.event_repeat_outlined,
              label: _editing ? l10n.actionSave : l10n.scheduleCreate,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
