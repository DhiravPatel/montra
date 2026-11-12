import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/recurring/application/recurring_providers.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';

/// Kind filters of the list, as wire values (null = all).
const List<String?> _kinds = <String?>[
  null,
  'expense',
  'income',
  'transfer',
  'bill',
];

/// Status filters of the list, as wire values (null = all).
const List<String?> _statuses = <String?>[null, 'active', 'paused', 'ended'];

const Map<String, int> _statusOrder = <String, int>{
  'active': 0,
  'paused': 1,
  'ended': 2,
};

/// Recurring expenses, income, transfers and bill schedules, filtered by
/// kind and status. Active rules come first, by next date.
class RecurringListScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RecurringListScreen({super.key});

  @override
  ConsumerState<RecurringListScreen> createState() =>
      _RecurringListScreenState();
}

class _RecurringListScreenState extends ConsumerState<RecurringListScreen> {
  String? _kind;
  String? _status;

  RecurringQuery get _query => (kind: _kind, status: _status);

  Future<void> _refresh() async {
    ref.invalidate(recurringRulesProvider(_query));
    try {
      await ref.read(recurringRulesProvider(_query).future);
    } on Object {
      // Shown by the list state.
    }
  }

  String _kindChip(AppLocalizations l10n, String? kind) => switch (kind) {
    null => l10n.recurringFilterAllKinds,
    'expense' => l10n.recurringFilterExpenses,
    'income' => l10n.recurringFilterIncome,
    'transfer' => l10n.recurringFilterTransfers,
    _ => l10n.recurringFilterBills,
  };

  String _statusChip(AppLocalizations l10n, String? status) => status == null
      ? l10n.recurringFilterAllStatuses
      : recurringStatusLabel(l10n, status).$1;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<RecurringRuleDto>> rules = ref.watch(
      recurringRulesProvider(_query),
    );
    final bool filtered = _kind != null || _status != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recurringTitle),
        bottom: rules.isLoading && rules.hasValue
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.calendarTitle,
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => context.push(AppRoutes.calendar),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newRecurring),
        icon: const Icon(Icons.add),
        label: Text(l10n.recurringAdd),
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
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String? k in _kinds)
                  ChoiceChip(
                    label: Text(_kindChip(l10n, k)),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.xs,
              Insets.md,
              Insets.xs,
            ),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String? s in _statuses)
                  ChoiceChip(
                    label: Text(_statusChip(l10n, s)),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<RecurringRuleDto>>(
              value: rules,
              onRetry: _refresh,
              data: (List<RecurringRuleDto> list) {
                final List<RecurringRuleDto> sorted =
                    List<RecurringRuleDto>.of(list)
                      ..sort((RecurringRuleDto a, RecurringRuleDto b) {
                        final int byStatus = (_statusOrder[a.status.json] ?? 3)
                            .compareTo(_statusOrder[b.status.json] ?? 3);
                        if (byStatus != 0) {
                          return byStatus;
                        }
                        return (a.nextOccurrence ?? '9999').compareTo(
                          b.nextOccurrence ?? '9999',
                        );
                      });
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 96),
                    children: <Widget>[
                      if (sorted.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: Insets.lg),
                          child: filtered
                              ? MessageStateView(
                                  icon: Icons.filter_alt_off_outlined,
                                  title: l10n.recurringNoMatchTitle,
                                  body: l10n.recurringNoMatchBody,
                                )
                              : MessageStateView(
                                  icon: Icons.repeat,
                                  title: l10n.recurringEmptyTitle,
                                  body: l10n.recurringEmptyBody,
                                  action: FilledButton.icon(
                                    onPressed: () =>
                                        context.push(AppRoutes.newRecurring),
                                    icon: const Icon(Icons.add),
                                    label: Text(l10n.recurringAddFirst),
                                  ),
                                ),
                        )
                      else
                        for (final RecurringRuleDto r in sorted)
                          RecurringRuleTile(
                            rule: r,
                            onTap: () =>
                                context.push(AppRoutes.recurringDetail(r.id)),
                          ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One rule in the list: name, schedule, next date, status and amount.
class RecurringRuleTile extends StatelessWidget {
  /// Creates the tile.
  const RecurringRuleTile({required this.rule, this.onTap, super.key});

  /// The rule.
  final RecurringRuleDto rule;

  /// Opens the rule.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String kind = rule.kind.json;
    final Money? amount = rule.amount;
    final String? next = rule.nextOccurrence;
    final bool active = rule.status == RecurringRuleDtoStatus.active;
    final (String statusText, StatusTone tone) = recurringStatusLabel(
      l10n,
      rule.status.json,
    );
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Icon(
          recurringKindIcon(kind),
          semanticLabel: recurringKindLabel(l10n, kind),
        ),
      ),
      title: Text(rule.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (rule.merchant case final MerchantRef m) Text(m.name),
          Text(
            scheduleSummary(l10n, ScheduleValue.fromRule(rule), locale: locale),
          ),
          if (active && next != null)
            Text(
              l10n.recurringNextOn(LocalDates.display(next, locale: locale)),
            ),
          if (!active)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: StatusLabel(text: statusText, tone: tone),
            ),
        ],
      ),
      trailing: amount != null && !rule.amountIsVariable
          ? MoneyText(amount)
          : Text(l10n.recurringVaries),
    );
  }
}
