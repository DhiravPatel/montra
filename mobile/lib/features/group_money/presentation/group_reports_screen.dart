import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/charts.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/domain/group_export.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';

/// A group's spending report from the server for a period (all time by
/// default): totals, per category, per member, per month, amounts paid in
/// other currencies, settlements and trip figures. Every chart has a text
/// summary and a list. The expenses and settlements can be exported as
/// CSV to share or save.
class GroupReportsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GroupReportsScreen({required this.groupId, super.key});

  /// The group.
  final String groupId;

  @override
  ConsumerState<GroupReportsScreen> createState() => _GroupReportsScreenState();
}

class _GroupReportsScreenState extends ConsumerState<GroupReportsScreen> {
  String? _from;
  String? _to;
  bool _exporting = false;

  GroupReportQuery get _query =>
      (groupId: widget.groupId, from: _from, to: _to);

  Future<void> _pickPeriod() async {
    final AppLocalizations l10n = context.l10n;
    final DateTime now = LocalDates.today();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: l10n.gxReportPeriod,
    );
    if (range != null && mounted) {
      setState(() {
        _from = LocalDates.format(range.start);
        _to = LocalDates.format(range.end);
      });
    }
  }

  Future<void> _export() async {
    if (_exporting) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    setState(() => _exporting = true);
    try {
      ref.invalidate(groupExportProvider(widget.groupId));
      final GroupExport export = await ref.read(
        groupExportProvider(widget.groupId).future,
      );
      if (!mounted) {
        return;
      }
      setState(() => _exporting = false);
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) => _ExportSheet(export: export),
      );
    } on Object catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    return GroupPeopleScope(
      groupId: widget.groupId,
      title: l10n.gxReportsTitle,
      builder: (BuildContext context, GroupPeople people) {
        final AsyncValue<GroupReportDto> report = ref.watch(
          groupReportProvider(_query),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.gxReportsTitle),
            bottom: _exporting
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4),
                    child: LinearProgressIndicator(),
                  )
                : null,
            actions: <Widget>[
              IconButton(
                tooltip: l10n.gxExport,
                icon: const Icon(Icons.file_download_outlined),
                onPressed: _exporting ? null : _export,
              ),
              GroupMoneyMenu(
                groupId: widget.groupId,
                current: GroupMoneyPage.reports,
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.md,
                  Insets.sm,
                  Insets.md,
                  0,
                ),
                child: Wrap(
                  spacing: Insets.sm,
                  children: <Widget>[
                    InputChip(
                      avatar: const Icon(Icons.date_range_outlined, size: 18),
                      label: Text(
                        _from == null
                            ? l10n.gxAllTime
                            : LocalDates.displayRange(
                                _from!,
                                _to ?? _from!,
                                locale: locale,
                              ),
                      ),
                      tooltip: l10n.gxReportPeriod,
                      onPressed: _pickPeriod,
                      onDeleted: _from == null
                          ? null
                          : () => setState(() {
                              _from = null;
                              _to = null;
                            }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncValueView<GroupReportDto>(
                  value: report,
                  onRetry: () => ref.invalidate(groupReportProvider(_query)),
                  isEmpty: (GroupReportDto r) => r.expenseCount == 0,
                  empty: MessageStateView(
                    icon: Icons.summarize_outlined,
                    title: l10n.gxReportEmptyTitle,
                    body: l10n.gxReportEmptyBody,
                  ),
                  data: (GroupReportDto r) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(groupReportProvider(_query));
                      try {
                        await ref.read(groupReportProvider(_query).future);
                      } on Object {
                        // Shown by the screen state.
                      }
                    },
                    child: _body(context, r, people),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, GroupReportDto r, GroupPeople people) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    String money(Money m) => formatMoney(context, ref, m);
    DetailRow moneyRow(String label, Money m) =>
        DetailRow(label: label, semanticsValue: money(m), child: MoneyText(m));
    final GroupTripSummary? trip = r.trip;
    return ScrollableContent(
      children: <Widget>[
        SectionCard(
          title: l10n.gxReportSummary,
          children: <Widget>[
            moneyRow(l10n.gxTotalSpent, r.totalSpent),
            DetailRow(
              label: l10n.gxExpenseCount,
              value: l10n.gxExpensesCount(r.expenseCount),
            ),
            if (r.disputedCount > 0)
              DetailRow(
                label: l10n.gxDisputedLabel,
                value: l10n.gxExpensesCount(r.disputedCount),
              ),
            DetailRow(
              label: l10n.gxParticipants,
              value: l10n.gxPeopleCount(r.participantCount),
            ),
            moneyRow(l10n.gxPerPerson, r.perPersonAverage),
            moneyRow(l10n.gxYouPaid, r.myPaid),
            moneyRow(l10n.gxYourShare, r.myShare),
          ],
        ),
        if (trip != null) ...<Widget>[
          const SizedBox(height: Insets.md),
          SectionCard(
            title: l10n.gxTripTitle,
            children: <Widget>[
              if (trip.destination case final String d when d.isNotEmpty)
                DetailRow(label: l10n.gxDestination, value: d),
              if (trip.startDate case final String s)
                DetailRow(
                  label: l10n.gxTripDates,
                  value: LocalDates.displayRange(
                    s,
                    trip.endDate ?? s,
                    locale: locale,
                  ),
                ),
              DetailRow(
                label: l10n.gxTripDays,
                value: l10n.gxDaysCount(trip.days),
              ),
              moneyRow(l10n.gxDailyAverage, trip.dailyAverage),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        _barSection(
          context,
          title: l10n.gxByCategory,
          entries: <(String, Money, String)>[
            for (final GroupCategoryTotal c in r.byCategory)
              (
                groupCategoryLabel(l10n, c.categoryKey),
                c.total,
                l10n.gxExpensesCount(c.count),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxByMember,
          children: <Widget>[
            for (final GroupMemberTotal m in r.byMember)
              ListTile(
                title: Text(
                  people.name(l10n, m.userId, fallback: m.displayName),
                ),
                subtitle: Text(
                  l10n.gxMemberPaidShare(money(m.paid), money(m.share)),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _barSection(
          context,
          title: l10n.gxByMonth,
          entries: <(String, Money, String)>[
            for (final GroupMonthTotal m in r.byMonth)
              (
                LocalDates.displayMonth('${m.month}-01', locale: locale),
                m.total,
                l10n.gxExpensesCount(m.count),
              ),
          ],
        ),
        if (r.originalCurrencies.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.md),
          SectionCard(
            title: l10n.gxOriginalCurrencies,
            children: <Widget>[
              for (final GroupCurrencyTotal c in r.originalCurrencies)
                ListTile(
                  title: Text(
                    l10n.gxOriginalConverted(
                      money(c.original),
                      money(c.converted),
                    ),
                  ),
                  subtitle: Text(l10n.gxExpensesCount(c.count)),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Text(
                  l10n.gxOriginalCurrenciesHelp,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        SectionCard(
          title: l10n.gxSettlementsTitle,
          children: <Widget>[
            moneyRow(l10n.gxSettlementsConfirmed, r.settlements.confirmed),
            moneyRow(l10n.gxSettlementsPending, r.settlements.pending),
            DetailRow(
              label: l10n.gxSettlementsDisputedCount,
              value: '${r.settlements.disputed}',
            ),
            DetailRow(
              label: l10n.gxSettlementsCount,
              value: '${r.settlements.count}',
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        OutlinedButton.icon(
          onPressed: _exporting ? null : _export,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(l10n.gxExport),
        ),
        const SizedBox(height: Insets.lg),
      ],
    );
  }

  Widget _barSection(
    BuildContext context, {
    required String title,
    required List<(String, Money, String)> entries,
  }) {
    final AppLocalizations l10n = context.l10n;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    int max = 0;
    for (final (String _, Money m, String _) in entries) {
      if (m.amountMinor.abs() > max) {
        max = m.amountMinor.abs();
      }
    }
    final (String topLabel, Money topMoney, String _) = entries.reduce(
      (a, b) => b.$2.amountMinor > a.$2.amountMinor ? b : a,
    );
    String money(Money m) => formatMoney(context, ref, m);
    return SectionCard(
      title: title,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: AccessibleChart(
            summary: l10n.gxChartSummary(topLabel, money(topMoney)),
            chart: HorizontalBars(
              entries: <BarEntry>[
                for (final (String label, Money m, String detail) in entries)
                  BarEntry(
                    label: label,
                    valueText: money(m),
                    fraction: max == 0 ? 0 : m.amountMinor.abs() / max,
                    detail: detail,
                  ),
              ],
            ),
            table: Column(
              children: <Widget>[
                for (final (String label, Money m, String detail) in entries)
                  DetailRow(
                    label: '$label · $detail',
                    semanticsValue: money(m),
                    child: MoneyText(m),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportSheet extends ConsumerWidget {
  const _ExportSheet({required this.export});

  final GroupExport export;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(l10n.gxExportTitle, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: Insets.sm),
          Text(l10n.gxExportIntro),
          const SizedBox(height: Insets.sm),
          if (export.fileName case final String name)
            DetailRow(label: l10n.gxExportFile, value: name),
          DetailRow(
            label: l10n.gxExportRowsLabel,
            value: l10n.gxExportRows(export.rowCount),
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              Builder(
                builder: (BuildContext context) => FilledButton.icon(
                  onPressed: () =>
                      shareDownloadedFile(context, ref, export.toFile()),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l10n.fileShare),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    saveDownloadedFile(context, ref, export.toFile()),
                icon: const Icon(Icons.save_alt),
                label: Text(l10n.fileSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
