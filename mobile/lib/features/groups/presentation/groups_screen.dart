import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/groups/application/groups_providers.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';
import 'package:montra_mobile/features/groups/presentation/group_widgets.dart';

/// The user's groups with their balance in each (`my_net`, as the server
/// computed it), invitations addressed to them, and ways to create or
/// join a group.
class GroupsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  bool _showArchived = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(allGroupsProvider)
      ..invalidate(myGroupInvitationsProvider);
    try {
      await ref.read(allGroupsProvider.future);
    } on Object {
      // Shown by the screen state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<GroupInvitationDto> invitations =
        ref.watch(myGroupInvitationsProvider).value ??
        const <GroupInvitationDto>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.groupJoinTitle,
            icon: const Icon(Icons.link),
            onPressed: () => context.push(AppRoutes.joinGroup),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push(AppRoutes.newGroup),
        icon: const Icon(Icons.add),
        label: Text(l10n.groupNew),
      ),
      body: AsyncValueView<List<GroupDto>>(
        value: ref.watch(allGroupsProvider),
        onRetry: _refresh,
        data: (List<GroupDto> all) {
          final List<GroupDto> shown = <GroupDto>[
            for (final GroupDto g in all)
              if (_showArchived || g.status == GroupDtoStatus.active) g,
          ];
          final bool hasArchived = all.any(
            (GroupDto g) => g.status == GroupDtoStatus.archived,
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: <Widget>[
                if (invitations.isNotEmpty) ...<Widget>[
                  ContentFrame(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.md,
                      Insets.md,
                      Insets.md,
                      0,
                    ),
                    child: SectionHeading(l10n.groupInvitationsForYou),
                  ),
                  for (final GroupInvitationDto i in invitations)
                    _InvitationTile(invitation: i),
                  const Divider(),
                ],
                if (hasArchived)
                  SwitchListTile(
                    title: Text(l10n.groupsShowArchived),
                    value: _showArchived,
                    onChanged: (bool v) => setState(() => _showArchived = v),
                  ),
                if (shown.isEmpty)
                  MessageStateView(
                    icon: Icons.groups_outlined,
                    title: l10n.groupsEmptyTitle,
                    body: l10n.groupsEmptyBody,
                    action: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.joinGroup),
                      icon: const Icon(Icons.link),
                      label: Text(l10n.groupJoinTitle),
                    ),
                  )
                else
                  for (final GroupDto g in shown) _GroupTile(group: g),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final GroupDto group;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool archived = group.status == GroupDtoStatus.archived;
    return ListTile(
      leading: const Icon(Icons.groups_outlined),
      title: Text(group.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.groupTypeAndMembers(
              groupTypeLabel(l10n, group.groupType.json),
              group.memberCount,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              GroupNetLabel(group.myNet),
              if (archived)
                StatusLabel(
                  text: l10n.groupArchivedLabel,
                  icon: Icons.archive_outlined,
                ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.groupDetail(group.id)),
    );
  }
}

class _InvitationTile extends ConsumerWidget {
  const _InvitationTile({required this.invitation});

  final GroupInvitationDto invitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? inviter = invitation.invitedBy?.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.mail_outline),
          title: Text(invitation.groupName),
          subtitle: Text(
            inviter == null
                ? l10n.groupInvitationReceived
                : l10n.groupInvitationFrom(inviter),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            0,
            Insets.md,
            Insets.sm,
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => runGroupAction<void>(
                  context,
                  ref,
                  action: (GroupsApi api) =>
                      api.declineInvitation(invitation.id),
                  success: (_) => l10n.groupInvitationDeclinedDone,
                ),
                child: Text(l10n.groupInvitationDecline),
              ),
              FilledButton(
                onPressed: () async {
                  final GroupDetail? joined = await runGroupAction<GroupDetail>(
                    context,
                    ref,
                    action: (GroupsApi api) =>
                        api.acceptInvitation(invitation.id),
                    success: (GroupDetail g) => l10n.groupJoinedDone(g.name),
                  );
                  if (joined != null && context.mounted) {
                    await context.push(AppRoutes.groupDetail(joined.id));
                  }
                },
                child: Text(l10n.groupInvitationAccept),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
