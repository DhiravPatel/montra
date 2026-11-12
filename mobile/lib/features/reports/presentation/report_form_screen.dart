import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/form_errors.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/range_picker.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/reports/application/reports_providers.dart';
import 'package:montra_mobile/features/reports/presentation/report_widgets.dart';

/// Requests a report (`POST /reports`): type, file format, period and an
/// optional title. It is made in the background; the report's screen shows
/// when it is ready.
class ReportFormScreen extends ConsumerStatefulWidget {
  /// Creates the form.
  const ReportFormScreen({super.key});

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  ReportInputReportType _type = ReportInputReportType.monthlySummary;
  String _format = ReportInputFormat.csv.json;
  DateRangeChoice? _range;
  bool _pending = false;
  ServerFormErrors _errors = ServerFormErrors.none;

  static const Map<String, String> _fields = <String, String>{
    'report_type': 'type',
    'format': 'format',
    'title': 'title',
    'filters': 'period',
  };

  /// The period shown: the user's choice, or this year for yearly
  /// summaries and this month otherwise (the server's defaults).
  DateRangeChoice get _period =>
      _range ??
      DateRangeChoice.named(
        _type == ReportInputReportType.yearlySummary
            ? 'this_year'
            : 'this_month',
      );

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _errors = ServerFormErrors.none);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final DateRangeChoice period = _period;
    final String title = _title.text.trim();
    final ReportInput input = ReportInput(
      reportType: _type,
      format: ReportInputFormat.fromJson(_format),
      title: title.isEmpty ? null : title,
      filters: Filters(
        range: period.range == null
            ? null
            : FiltersRange.fromJson(period.range!),
        from: period.range == null ? period.from : null,
        to: period.range == null ? period.to : null,
        includePending: _pending ? true : null,
      ),
    );
    try {
      final ReportDto created = await ref
          .read(reportsProvider.notifier)
          .create(input);
      if (!mounted) {
        return;
      }
      showSnack(context, l10n.reportQueued);
      context.pushReplacement(AppRoutes.reportDetail(created.id));
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _errors = ServerFormErrors.from(l10n, error, fieldMap: _fields),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String? general = _errors.general;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportNewTitle)),
      body: Form(
        key: _form,
        child: ScrollableContent(
          children: <Widget>[
            if (general != null) ...<Widget>[
              NoticeBanner(
                tone: NoticeTone.error,
                message: general,
                requestId: _errors.requestId,
              ),
              const SizedBox(height: Insets.md),
            ],
            Text(l10n.reportNewIntro),
            const SizedBox(height: Insets.md),
            ReportTypeField(
              value: _type,
              errorText: _errors['type'],
              onChanged: (ReportInputReportType t) => setState(() => _type = t),
            ),
            ReportFormatChips(
              value: _format,
              onChanged: (String f) => setState(() => _format = f),
            ),
            if (_errors['format'] case final String e)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: Insets.md),
            SelectorField(
              label: l10n.reportPeriodLabel,
              icon: Icons.date_range_outlined,
              value: rangeChoiceLabel(l10n, _period, locale: locale),
              errorText: _errors['period'],
              onTap: () async {
                final DateRangeChoice? next = await showRangePicker(
                  context,
                  current: _period,
                );
                if (next != null && mounted) {
                  setState(() => _range = next);
                }
              },
            ),
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _pending,
              title: Text(l10n.reportIncludePending),
              subtitle: Text(l10n.reportIncludePendingHelp),
              onChanged: (bool v) => setState(() => _pending = v),
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _title,
              maxLength: ReportInput.titleMaxLength,
              decoration: InputDecoration(
                labelText: l10n.reportTitleLabel,
                helperText: l10n.reportTitleHelp,
                errorText: _errors['title'],
              ),
            ),
            const SizedBox(height: Insets.lg),
            SubmitButton(
              icon: Icons.summarize_outlined,
              label: l10n.reportCreate,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
