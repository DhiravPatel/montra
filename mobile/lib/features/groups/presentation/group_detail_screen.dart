import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/money_text.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/groups/application/groups_providers.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';
import 'package:montra_mobile/features/groups/presentation/group_widgets.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

/// Names of a group's members by user ID (former members included), for
/// activity sentences.
Map<String, String> memberNames(GroupDetail group) => <String, String>{
  for (final GroupMemberDto m in group.members) m.userId: m.displayName,
};

/// One group: the user's balance and everyone's, the money screens,
/// trip details, members and recent activity. Settings, invitations and
/// leaving are under the settings button.
class GroupDetailScreen extends ConsumerWidget {
  /// Creates the screen for [groupId].
  const GroupDetailScreen({required this.groupId, super.key});

  /// The group.
  final String groupId;

  Future<void> _refresh(WidgetRef ref) async {
    refreshGroup(ref, groupId);
    try {
      await ref.read(groupDetailProvider(groupId).future);
    } on Object {
      // Shown by the screen state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<GroupDetail> group = ref.watch(
      groupDetailProvider(groupId),
    );
    final GroupDetail? loaded = group.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? l10n.groupsTitle),
        actions: <Widget>[
          if (loaded != null)
            IconButton(
              tooltip: l10n.groupSettingsTitle,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(AppRoutes.groupSettings(groupId)),
            ),
        ],
      ),
      body: AsyncValueView<GroupDetail>(
        value: group,
        onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        data: (GroupDetail g) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Insets.md),
            children: <Widget>[
              Text(
                l10n.groupTypeAndMembers(
                  groupTypeLabel(l10n, g.groupType.json),
                  g.memberCount,
                ),
              ),
              if (g.status == GroupDetailStatus.archived) ...<Widget>[
                const SizedBox(height: Insets.sm),
                NoticeBanner(
                  tone: NoticeTone.warning,
                  message: l10n.groupArchivedBanner,
                ),
              ],
              const SizedBox(height: Insets.md),
              _BalanceCard(group: g),
              const SizedBox(height: Insets.md),
              _MoneyLinks(groupId: g.id),
              if (groupTypeHasDates(g.groupType.json) &&
                  (g.destination != null ||
                      g.startDate != null ||
                      g.endDate != null)) ...<Widget>[
                const SizedBox(height: Insets.md),
                _TripCard(group: g),
              ],
              if ((g.description ?? '').isNotEmpty ||
                  (g.rules ?? '').isNotEmpty) ...<Widget>[
                const SizedBox(height: Insets.md),
                SectionCard(
                  title: l10n.groupAboutSection,
                  children: <Widget>[
                    if ((g.description ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.md,
                          vertical: Insets.xs,
                        ),
                        child: Text(g.description!),
                      ),
                    if ((g.rules ?? '').isNotEmpty)
                      DetailRow(label: l10n.groupRulesLabel, value: g.rules),
                  ],
                ),
              ],
              const SizedBox(height: Insets.md),
              _MembersCard(group: g),
              const SizedBox(height: Insets.md),
              _RecentActivity(group: g),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<GroupBalancesDto> balances = ref.watch(
      groupBalancesProvider(group.id),
    );
    final GroupBalancesDto? data = balances.value;
    final String? me = ref.watch(currentUserIdProvider);
    return SectionCard(
      title: l10n.groupBalanceTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.xs,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: GroupNetLabel(data?.myNet ?? group.myNet),
          ),
        ),
        if (data != null)
          for (final GroupMemberBalance b in data.balances)
            if (b.userId != me && b.net.amountMinor != 0)
              DetailRow(
                label: b.memberStatus == GroupMemberBalanceMemberStatus.active
                    ? b.displayName
                    : l10n.groupFormerMember(b.displayName),
                child: _MemberNet(net: b.net),
              ),
        if (data != null && data.disputedExpenses > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.groupDisputedExpenses(data.disputedExpenses)),
          ),
        if (balances.hasError && data == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.groupBalancesUnavailable),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.sm,
            Insets.md,
            0,
          ),
          child: FilledButton.tonalIcon(
            onPressed: () => context.push(AppRoutes.groupBalances(group.id)),
            icon: const Icon(Icons.handshake_outlined),
            label: Text(l10n.groupSettleUp),
          ),
        ),
      ],
    );
  }
}

class _MemberNet extends ConsumerWidget {
  const _MemberNet({required this.net});

  final Money net;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String amount = formatMoney(context, ref, unsignedNet(net));
    return Text(
      net.amountMinor > 0
          ? l10n.groupMemberIsOwed(amount)
          : l10n.groupMemberOwes(amount),
    );
  }
}

class _MoneyLinks extends StatelessWidget {
  const _MoneyLinks({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    Widget link(IconData icon, String title, String location) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(location),
    );
    return SectionCard(
      title: l10n.groupMoneySection,
      children: <Widget>[
        link(
          Icons.receipt_long_outlined,
          l10n.groupLinkExpenses,
          AppRoutes.groupExpenses(groupId),
        ),
        link(
          Icons.balance_outlined,
          l10n.groupLinkBalances,
          AppRoutes.groupBalances(groupId),
        ),
        link(
          Icons.handshake_outlined,
          l10n.groupLinkSettlements,
          AppRoutes.groupSettlements(groupId),
        ),
        link(
          Icons.event_repeat_outlined,
          l10n.groupLinkRecurring,
          AppRoutes.groupRecurring(groupId),
        ),
        link(
          Icons.summarize_outlined,
          l10n.groupLinkReports,
          AppRoutes.groupReports(groupId),
        ),
        link(
          Icons.emoji_events_outlined,
          l10n.challengeCreate,
          AppRoutes.newGroupChallenge(groupId),
        ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    return SectionCard(
      title: l10n.groupTripSection,
      children: <Widget>[
        if (group.destination != null)
          DetailRow(
            label: l10n.groupDestinationLabel,
            value: group.destination,
          ),
        if (group.startDate case final String start)
          DetailRow(
            label: l10n.groupStartDateLabel,
            value: LocalDates.display(start, locale: locale),
          ),
        if (group.endDate case final String end)
          DetailRow(
            label: l10n.groupEndDateLabel,
            value: LocalDates.display(end, locale: locale),
          ),
      ],
    );
  }
}

class _MembersCard extends ConsumerWidget {
  const _MembersCard({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.watch(currentUserIdProvider);
    final List<GroupMemberDto> active = <GroupMemberDto>[
      for (final GroupMemberDto m in group.members)
        if (m.status == GroupMemberDtoStatus.active) m,
    ];
    final List<GroupMemberDto> former = <GroupMemberDto>[
      for (final GroupMemberDto m in group.members)
        if (m.status != GroupMemberDtoStatus.active) m,
    ];
    return SectionCard(
      title: l10n.groupMembersLabel,
      children: <Widget>[
        for (final GroupMemberDto m in <GroupMemberDto>[...active, ...former])
          ListTile(
            leading: InitialsAvatar(name: m.displayName),
            title: Text(
              m.userId == me
                  ? l10n.groupMemberYou(m.displayName)
                  : m.displayName,
            ),
            subtitle: Wrap(
              spacing: Insets.xs,
              runSpacing: Insets.xs,
              children: <Widget>[
                Text(groupRoleLabel(l10n, m.role.json)),
                if (m.status == GroupMemberDtoStatus.left)
                  StatusLabel(text: l10n.groupMemberLeft, icon: Icons.logout),
                if (m.status == GroupMemberDtoStatus.removed)
                  StatusLabel(
                    text: l10n.groupMemberRemoved,
                    icon: Icons.person_remove_outlined,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ActivityFeed> feed = ref.watch(
      groupActivityProvider(group.id),
    );
    final List<GroupActivityDto> events =
        feed.value?.events ?? const <GroupActivityDto>[];
    return SectionCard(
      title: l10n.groupActivityTitle,
      children: <Widget>[
        if (feed.hasError && feed.value == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.groupActivityUnavailable),
          )
        else if (feed.value != null && events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.groupActivityEmpty),
          ),
        for (final GroupActivityDto e in events.take(5))
          ActivityTile(event: e, names: memberNames(group), groupId: group.id),
        if (events.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.groupActivity(group.id)),
              child: Text(l10n.actionSeeAll),
            ),
          ),
      ],
    );
  }
}

/// One activity event as a sentence with its time.
class ActivityTile extends StatelessWidget {
  /// Creates the tile.
  const ActivityTile({
    required this.event,
    required this.names,
    this.groupId,
    super.key,
  });

  /// The event.
  final GroupActivityDto event;

  /// The group, to open the expense, payment or recurring expense an event
  /// is about.
  final String? groupId;

  /// Member names by user ID.
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final String someone = l10n.groupActivitySomeone;
    final String actor = names[event.actorId] ?? someone;
    final String target = names[event.entityId] ?? someone;
    final String? link = groupId == null ? null : activityLink(groupId!, event);
    return ListTile(
      dense: true,
      leading: const Icon(Icons.history, size: 20),
      trailing: link == null ? null : const Icon(Icons.chevron_right),
      onTap: link == null ? null : () => context.push(link),
      title: Text(activitySentence(l10n, event, actor: actor, target: target)),
      subtitle: Text(
        formatRelativeTime(
          l10n,
          event.createdAt,
          now: DateTime.now(),
          locale: locale,
        ),
      ),
    );
  }
}
