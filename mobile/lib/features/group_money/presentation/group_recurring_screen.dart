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
import 'package:montra_mobile/features/group_money/application/group_money_providers.dart';
import 'package:montra_mobile/features/group_money/domain/group_money_display.dart';
import 'package:montra_mobile/features/group_money/presentation/group_money_widgets.dart';
import 'package:montra_mobile/features/recurring/domain/recurring_display.dart';
import 'package:montra_mobile/features/recurring/domain/schedule.dart';

/// A group's recurring shared expenses (rent, cleaning, subscriptions):
/// each adds an expense on schedule, automatically or when a member adds
/// it.
class GroupRecurringScreen extends ConsumerWidget {
  /// Creates the screen.
  const GroupRecurringScreen({required this.groupId, super.key});

  /// The group.
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return GroupPeopleScope(
      groupId: groupId,
      title: l10n.gxRecurringTitle,
      builder: (BuildContext context, GroupPeople people) {
        final AsyncValue<List<GroupRecurringDto>> list = ref.watch(
          groupRecurringListProvider(groupId),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.gxRecurringTitle),
            actions: <Widget>[
              GroupMoneyMenu(
                groupId: groupId,
                current: GroupMoneyPage.recurring,
              ),
            ],
          ),
          floatingActionButton: people.canWrite
              ? FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: () =>
                      context.push(AppRoutes.newGroupRecurring(groupId)),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.gxRecurringAdd),
                )
              : null,
          body: AsyncValueView<List<GroupRecurringDto>>(
            value: list,
            onRetry: () => ref.invalidate(groupRecurringListProvider(groupId)),
            isEmpty: (List<GroupRecurringDto> l) => l.isEmpty,
            empty: MessageStateView(
              icon: Icons.event_repeat,
              title: l10n.gxRecurringEmptyTitle,
              body: l10n.gxRecurringEmptyBody,
            ),
            data: (List<GroupRecurringDto> l) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(groupRecurringListProvider(groupId));
                try {
                  await ref.read(groupRecurringListProvider(groupId).future);
                } on Object {
                  // Shown by the list state.
                }
              },
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: l.length,
                separatorBuilder: (BuildContext context, int i) =>
                    const Divider(height: 1),
                itemBuilder: (BuildContext context, int i) =>
                    _RuleTile(rule: l[i], groupId: groupId),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.groupId});

  final GroupRecurringDto rule;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final RecurringRuleDto r = rule.rule;
    final (String status, StatusTone tone) = recurringStatusLabel(
      l10n,
      r.status.json,
    );
    final String? next = r.nextOccurrence;
    final Money? amount = r.amount;
    return ListTile(
      leading: const Icon(Icons.event_repeat),
      title: Text(r.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (amount != null) MoneyText(amount),
          Text(
            scheduleSummary(l10n, ScheduleValue.fromRule(r), locale: locale),
          ),
          if (next != null && r.status == RecurringRuleDtoStatus.active)
            Text(l10n.gxNextOn(LocalDates.display(next, locale: locale))),
          Text(rule.autoAdd ? l10n.gxAutoAddOn : l10n.gxAutoAddOff),
          const SizedBox(height: Insets.xs),
          StatusLabel(text: status, tone: tone),
        ],
      ),
      isThreeLine: true,
      onTap: () => context.push(AppRoutes.groupRecurringDetail(groupId, r.id)),
    );
  }
}
