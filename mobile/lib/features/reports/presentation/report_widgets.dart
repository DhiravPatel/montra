import 'package:flutter/material.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/reports/domain/report_display.dart';

/// A report's status as text with an icon (never colour alone).
class ReportStatusLabel extends StatelessWidget {
  /// Creates the label.
  const ReportStatusLabel({required this.status, super.key});

  /// The status.
  final ReportDtoStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final (String text, StatusTone tone, IconData icon) = reportStatusLabel(
      l10n,
      status,
    );
    return StatusLabel(
      text: text,
      tone: tone,
      icon: icon,
      semanticsLabel: l10n.reportStatusSemantics(text),
    );
  }
}

/// Picks a report type from a sheet listing every type with what it
/// contains.
class ReportTypeField extends StatelessWidget {
  /// Creates the field.
  const ReportTypeField({
    required this.value,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  /// The chosen type.
  final ReportInputReportType value;

  /// Called with the new type.
  final ValueChanged<ReportInputReportType> onChanged;

  /// Server error for the field.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SelectorField(
      label: l10n.reportTypeLabel,
      icon: Icons.summarize_outlined,
      value: reportTypeLabel(l10n, value.json),
      helperText: reportTypeHelp(l10n, value.json),
      errorText: errorText,
      onTap: () async {
        final ReportInputReportType? picked =
            await showOptionSheet<ReportInputReportType>(
              context,
              title: l10n.reportTypeLabel,
              selected: value,
              options: <SheetOption<ReportInputReportType>>[
                for (final ReportInputReportType t in reportTypes)
                  SheetOption<ReportInputReportType>(
                    value: t,
                    label: reportTypeLabel(l10n, t.json),
                    subtitle: reportTypeHelp(l10n, t.json),
                  ),
              ],
            );
        if (picked != null) {
          onChanged(picked);
        }
      },
    );
  }
}

/// Chips for the file format, with what each is good for.
class ReportFormatChips extends StatelessWidget {
  /// Creates the chips.
  const ReportFormatChips({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The chosen format (wire value).
  final String value;

  /// Called with the new format.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FormSectionHeader(l10n.reportFormatLabel),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          children: <Widget>[
            for (final ReportInputFormat f in reportFormats)
              ChoiceChip(
                label: Text(reportFormatLabel(l10n, f.json)),
                selected: value == f.json,
                onSelected: (_) => onChanged(f.json),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: Insets.xs),
          child: Text(switch (value) {
            'xlsx' => l10n.reportFormatXlsxHelp,
            'pdf' => l10n.reportFormatPdfHelp,
            'json' => l10n.reportFormatJsonHelp,
            _ => l10n.reportFormatCsvHelp,
          }, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

/// The period a report covers, from its stored filters.
String reportPeriodText(
  AppLocalizations l10n,
  Filters filters, {
  required String locale,
}) {
  final String? from = filters.from;
  final String? to = filters.to;
  if (from != null && to != null) {
    return LocalDates.displayRange(from, to, locale: locale);
  }
  final FiltersRange? range = filters.range;
  if (range != null && range != FiltersRange.unrecognized) {
    return switch (range) {
      FiltersRange.today => l10n.rangeToday,
      FiltersRange.yesterday => l10n.rangeYesterday,
      FiltersRange.thisWeek => l10n.rangeThisWeek,
      FiltersRange.lastWeek => l10n.rangeLastWeek,
      FiltersRange.thisMonth => l10n.rangeThisMonth,
      FiltersRange.lastMonth => l10n.rangeLastMonth,
      FiltersRange.thisYear => l10n.rangeThisYear,
      FiltersRange.lastYear => l10n.rangeLastYear,
      FiltersRange.last7Days => l10n.rangeLast7Days,
      FiltersRange.last30Days => l10n.rangeLast30Days,
      FiltersRange.last90Days => l10n.rangeLast90Days,
      FiltersRange.unrecognized => l10n.rangeAnyTime,
    };
  }
  return l10n.reportPeriodDefault;
}
