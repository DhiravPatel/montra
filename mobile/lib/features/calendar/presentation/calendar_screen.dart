import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/calendar/application/calendar_providers.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';

/// Text of a calendar item's kind.
String calendarKindLabel(AppLocalizations l10n, CalendarItemKind kind) =>
    switch (kind) {
      CalendarItemKind.recurring => l10n.calendarKindRecurring,
      CalendarItemKind.bill => l10n.calendarKindBill,
      CalendarItemKind.groupExpense => l10n.calendarKindGroupExpense,
      CalendarItemKind.subscriptionRenewal => l10n.calendarKindRenewal,
      CalendarItemKind.trialEnd => l10n.calendarKindTrialEnd,
      CalendarItemKind.goalTarget => l10n.calendarKindGoal,
      CalendarItemKind.unrecognized => l10n.calendarKindOther,
    };

/// Icon of a calendar item's kind.
IconData calendarKindIcon(CalendarItemKind kind) => switch (kind) {
  CalendarItemKind.recurring => Icons.repeat,
  CalendarItemKind.bill => Icons.receipt_long_outlined,
  CalendarItemKind.groupExpense => Icons.groups_outlined,
  CalendarItemKind.subscriptionRenewal => Icons.autorenew,
  CalendarItemKind.trialEnd => Icons.hourglass_bottom,
  CalendarItemKind.goalTarget => Icons.flag_outlined,
  CalendarItemKind.unrecognized => Icons.event_outlined,
};

/// Text, tone and icon of a calendar item's status: an occurrence status,
/// `projected` beyond the generated horizon, `expected` for subscription
/// renewals or `target` for a goal's target date.
(String, StatusTone, IconData) calendarStatusLabel(
  AppLocalizations l10n,
  CalendarItemStatus status,
) => switch (status) {
  CalendarItemStatus.projected => (
    l10n.calendarStatusProjected,
    StatusTone.neutral,
    Icons.event_note_outlined,
  ),
  CalendarItemStatus.expected => (
    l10n.calendarStatusExpected,
    StatusTone.neutral,
    Icons.event_outlined,
  ),
  CalendarItemStatus.target => (
    l10n.calendarStatusTarget,
    StatusTone.neutral,
    Icons.flag_outlined,
  ),
  CalendarItemStatus.scheduled => occurrenceStatusLabel(
    l10n,
    OccurrenceDtoStatus.scheduled,
  ),
  CalendarItemStatus.posted => occurrenceStatusLabel(
    l10n,
    OccurrenceDtoStatus.posted,
  ),
  CalendarItemStatus.paid => occurrenceStatusLabel(
    l10n,
    OccurrenceDtoStatus.paid,
  ),
  CalendarItemStatus.skipped => occurrenceStatusLabel(
    l10n,
    OccurrenceDtoStatus.skipped,
  ),
  CalendarItemStatus.overdue => occurrenceStatusLabel(
    l10n,
    OccurrenceDtoStatus.overdue,
  ),
  CalendarItemStatus.unrecognized => occurrenceStatusLabel(
    l10n,
    OccurrenceDtoStatus.unrecognized,
  ),
};

/// The route that shows a calendar item's source, if the app has one.
String? calendarItemLocation(CalendarItem item) => switch (item.entityType) {
  CalendarItemEntityType.recurringRule => AppRoutes.recurringDetail(
    item.entityId,
  ),
  CalendarItemEntityType.bill => AppRoutes.billDetail(item.entityId),
  CalendarItemEntityType.subscription => AppRoutes.subscriptionDetail(
    item.entityId,
  ),
  CalendarItemEntityType.goal => AppRoutes.goalDetail(item.entityId),
  CalendarItemEntityType.groupRecurringExpense ||
  CalendarItemEntityType.unrecognized => null,
};

/// A month of upcoming bills, recurring items, subscription renewals,
/// trial ends and goal dates, grouped by day. [initialMonth] is a `YYYY-MM`
/// key (default: this month).
class CalendarScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CalendarScreen({this.initialMonth, super.key});

  /// Month to open, `YYYY-MM`.
  final String? initialMonth;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final DateTime today = LocalDates.today();
    _month =
        parseMonthKey(widget.initialMonth) ?? DateTime(today.year, today.month);
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  Future<void> _refresh() async {
    final String key = monthKey(_month);
    ref.invalidate(calendarMonthProvider(key));
    try {
      await ref.read(calendarMonthProvider(key).future);
    } on Object {
      // Shown by the list state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String key = monthKey(_month);
    final AsyncValue<List<CalendarItem>> items = ref.watch(
      calendarMonthProvider(key),
    );
    final DateTime today = LocalDates.today();
    final bool thisMonth =
        _month.year == today.year && _month.month == today.month;
    final String monthName = DateFormat.yMMMM(locale).format(_month);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendarTitle),
        bottom: items.isLoading && items.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: l10n.calendarPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      monthName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.calendarNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
          ),
          if (!thisMonth)
            Align(
              child: TextButton(
                onPressed: () =>
                    setState(() => _month = DateTime(today.year, today.month)),
                child: Text(l10n.calendarThisMonth),
              ),
            ),
          Expanded(
            child: AsyncValueView<List<CalendarItem>>(
              value: items,
              onRetry: _refresh,
              data: (List<CalendarItem> list) => RefreshIndicator(
                onRefresh: _refresh,
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          const SizedBox(height: Insets.lg),
                          MessageStateView(
                            icon: Icons.event_available_outlined,
                            title: l10n.calendarEmptyTitle(monthName),
                            body: l10n.calendarEmptyBody,
                          ),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: Insets.xl),
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Insets.md,
                              0,
                              Insets.md,
                              Insets.sm,
                            ),
                            child: Text(l10n.calendarMonthCount(list.length)),
                          ),
                          for (final (String date, List<CalendarItem> day)
                              in groupByDate(list)) ...<Widget>[
                            _DayHeader(
                              date: date,
                              isToday: date == LocalDates.format(today),
                            ),
                            for (final CalendarItem item in day)
                              CalendarItemTile(item: item),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.isToday});

  final String date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String text = LocalDates.displayLong(date, locale: locale);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.md,
        Insets.md,
        Insets.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          isToday ? l10n.calendarTodayHeading(text) : text,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

/// One calendar entry: title, kind, status and amount; opens its source
/// when the app has a screen for it.
class CalendarItemTile extends StatelessWidget {
  /// Creates the tile.
  const CalendarItemTile({required this.item, super.key});

  /// The entry.
  final CalendarItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final (String statusText, StatusTone tone, IconData icon) =
        calendarStatusLabel(l10n, item.status);
    final String? location = calendarItemLocation(item);
    final Money? amount = item.amount;
    final String locale = Localizations.localeOf(context).toString();
    final String? movedFrom = item.postponedTo != null
        ? item.scheduledOn
        : null;
    return ListTile(
      onTap: location == null ? null : () => context.push(location),
      leading: CircleAvatar(
        child: ExcludeSemantics(child: Icon(calendarKindIcon(item.kind))),
      ),
      title: Text(item.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Insets.xs),
        child: Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(calendarKindLabel(l10n, item.kind)),
            StatusLabel(text: statusText, tone: tone, icon: icon),
            if (movedFrom != null)
              Text(
                l10n.calendarMovedFrom(
                  LocalDates.display(movedFrom, locale: locale),
                ),
              ),
          ],
        ),
      ),
      trailing: amount == null ? null : MoneyText(amount),
    );
  }
}
