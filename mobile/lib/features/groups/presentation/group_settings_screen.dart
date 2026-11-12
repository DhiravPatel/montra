import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/config/app_config.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/detail_rows.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/groups/application/groups_providers.dart';
import 'package:montra_mobile/features/groups/data/groups_api.dart';
import 'package:montra_mobile/features/groups/domain/group_display.dart';
import 'package:montra_mobile/features/groups/presentation/group_paths.dart';
import 'package:montra_mobile/features/groups/presentation/group_widgets.dart';
import 'package:montra_mobile/features/people/application/people_providers.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';
import 'package:montra_mobile/features/social/presentation/person_widgets.dart';

/// A group's settings, by role: everyone chooses their notifications,
/// invites (when the group allows it) and can leave; admins edit the
/// details, manage members, invitations and join requests; the owner
/// transfers ownership, archives, restores or deletes the group.
class GroupSettingsScreen extends ConsumerWidget {
  /// Creates the screen for [groupId].
  const GroupSettingsScreen({required this.groupId, super.key});

  /// The group.
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupSettingsTitle)),
      body: AsyncValueView<GroupDetail>(
        value: ref.watch(groupDetailProvider(groupId)),
        onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        data: (GroupDetail g) => RefreshIndicator(
          onRefresh: () async {
            refreshGroup(ref, groupId);
            try {
              await ref.read(groupDetailProvider(groupId).future);
            } on Object {
              // Shown by the screen state.
            }
          },
          child: _Settings(group: g),
        ),
      ),
    );
  }
}

enum _MemberAction { makeAdmin, makeMember, transfer, remove }

enum _AddBy { username, friend }

class _Settings extends ConsumerWidget {
  const _Settings({required this.group});

  final GroupDetail group;

  String get _role => group.myRole.json;
  bool get _admin => roleCanManage(_role);
  bool get _owner => _role == 'owner';
  bool get _active => group.status == GroupDetailStatus.active;
  bool get _canInvite => _active && (_admin || group.allowMemberInvites);

  Future<void> _memberActions(
    BuildContext context,
    WidgetRef ref,
    GroupMemberDto m,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final String target = m.role.json;
    final bool canChangeRole =
        target != 'owner' && (_owner || (_admin && target == 'member'));
    final _MemberAction? action = await showOptionSheet<_MemberAction>(
      context,
      title: m.displayName,
      options: <SheetOption<_MemberAction>>[
        if (canChangeRole && target == 'member')
          SheetOption<_MemberAction>(
            value: _MemberAction.makeAdmin,
            label: l10n.groupMakeAdmin,
            subtitle: l10n.groupAdminHelp,
            icon: Icons.admin_panel_settings_outlined,
          ),
        if (canChangeRole && target == 'admin')
          SheetOption<_MemberAction>(
            value: _MemberAction.makeMember,
            label: l10n.groupMakeMember,
            icon: Icons.person_outline,
          ),
        if (_owner)
          SheetOption<_MemberAction>(
            value: _MemberAction.transfer,
            label: l10n.groupTransferOwnership,
            icon: Icons.swap_horiz,
          ),
        if (canChangeRole)
          SheetOption<_MemberAction>(
            value: _MemberAction.remove,
            label: l10n.groupRemoveMember,
            icon: Icons.person_remove_outlined,
            destructive: true,
          ),
      ],
    );
    if (action == null || !context.mounted) {
      return;
    }
    final String name = m.displayName;
    switch (action) {
      case _MemberAction.makeAdmin || _MemberAction.makeMember:
        final GroupMemberUpdateRole role = action == _MemberAction.makeAdmin
            ? GroupMemberUpdateRole.admin
            : GroupMemberUpdateRole.member;
        await runGroupAction<GroupDetail>(
          context,
          ref,
          groupId: group.id,
          action: (GroupsApi api) => api.updateMember(
            group.id,
            m.userId,
            GroupMemberUpdate(role: role),
          ),
          success: (_) =>
              l10n.groupRoleChangedDone(name, groupRoleLabel(l10n, role.json)),
        );
      case _MemberAction.transfer:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.groupTransferConfirmTitle(name),
          body: l10n.groupTransferConfirmBody(name),
          confirmLabel: l10n.groupTransferOwnership,
          destructive: true,
        );
        if (ok && context.mounted) {
          await runGroupAction<GroupDetail>(
            context,
            ref,
            groupId: group.id,
            action: (GroupsApi api) =>
                api.transferOwnership(group.id, m.userId),
            success: (_) => l10n.groupTransferredDone(name),
          );
        }
      case _MemberAction.remove:
        final bool ok = await showConfirmDialog(
          context,
          title: l10n.groupRemoveConfirmTitle(name),
          body: l10n.groupRemoveConfirmBody(name),
          confirmLabel: l10n.groupRemoveMember,
          destructive: true,
        );
        if (ok && context.mounted) {
          await runGroupAction<void>(
            context,
            ref,
            groupId: group.id,
            action: (GroupsApi api) => api.removeMember(group.id, m.userId),
            success: (_) => l10n.groupRemovedDone(name),
          );
        }
    }
  }

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final _AddBy? by = await showOptionSheet<_AddBy>(
      context,
      title: l10n.groupAddMember,
      options: <SheetOption<_AddBy>>[
        SheetOption<_AddBy>(
          value: _AddBy.friend,
          label: l10n.groupAddFromFriends,
          subtitle: l10n.groupAddFromFriendsHelp,
          icon: Icons.people_outline,
        ),
        SheetOption<_AddBy>(
          value: _AddBy.username,
          label: l10n.groupAddByUsername,
          subtitle: l10n.groupAddByUsernameHelp,
          icon: Icons.alternate_email,
        ),
      ],
    );
    if (by == null || !context.mounted) {
      return;
    }
    AddMemberInput? input;
    String name;
    if (by == _AddBy.friend) {
      final PersonChoice? person = await showPersonPicker(
        context,
        excludeIds: <String>{
          for (final GroupMemberDto m in group.members)
            if (m.status == GroupMemberDtoStatus.active) m.userId,
        },
      );
      if (person == null) {
        return;
      }
      input = AddMemberInput(userId: person.userId);
      name = person.displayName;
    } else {
      final String? username = await _askUsername(context);
      if (username == null) {
        return;
      }
      input = AddMemberInput(username: username);
      name = '@$username';
    }
    if (!context.mounted) {
      return;
    }
    final AddMemberInput body = input;
    await runGroupAction<GroupInvitationDto>(
      context,
      ref,
      groupId: group.id,
      action: (GroupsApi api) => api.addMember(group.id, body),
      success: (_) => l10n.groupInvitedDone(name),
    );
  }

  Future<String?> _askUsername(BuildContext context) => showDialog<String>(
    context: context,
    builder: (BuildContext context) => const _UsernameDialog(),
  );

  Future<void> _createLink(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final ({int days, int? uses})? options =
        await showDialog<({int days, int? uses})>(
          context: context,
          builder: (BuildContext context) => const _LinkOptionsDialog(),
        );
    if (options == null || !context.mounted) {
      return;
    }
    final AppConfig config = ref.read(appConfigProvider);
    final GroupInvitationDto? created =
        await runGroupAction<GroupInvitationDto>(
          context,
          ref,
          groupId: group.id,
          action: (GroupsApi api) => api.createInvitation(
            group.id,
            GroupInvitationInput(
              kind: GroupInvitationInputKind.link,
              expiresInDays: options.days,
              maxUses: options.uses,
            ),
          ),
          success: (_) => l10n.groupLinkCreatedDone,
        );
    final String? token = created?.token;
    if (token == null || !context.mounted) {
      return;
    }
    // The token is shown once, here, and kept only in this dialog.
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _ShareLinkDialog(
        // The server's join link when it sent one; otherwise built here.
        link:
            InviteLinks.groupShareUrl(created?.shareUrl) ??
            InviteLinks.groupJoinLink(config, token).toString(),
        groupName: group.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.watch(currentUserIdProvider);
    final GroupMemberDto? mine = group.members
        .where((GroupMemberDto m) => m.userId == me)
        .firstOrNull;
    final List<GroupMemberDto> active = <GroupMemberDto>[
      for (final GroupMemberDto m in group.members)
        if (m.status == GroupMemberDtoStatus.active) m,
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Insets.md),
      children: <Widget>[
        if (!_active) ...<Widget>[
          NoticeBanner(
            tone: NoticeTone.warning,
            message: l10n.groupArchivedBanner,
          ),
          const SizedBox(height: Insets.md),
        ],
        if (_admin && _active) ...<Widget>[
          SectionCard(
            title: l10n.groupDetailsSection,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.groupEditTitle),
                subtitle: Text(
                  '${groupTypeLabel(l10n, group.groupType.json)} · '
                  '${group.baseCurrency} · '
                  '${splitMethodLabel(l10n, group.defaultSplitMethod.json)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(GroupPaths.edit(group.id)),
              ),
              DetailRow(
                label: l10n.groupRequireApprovalLabel,
                value: group.requireJoinApproval
                    ? l10n.statusOn
                    : l10n.statusOff,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
        ],
        SectionCard(
          title: l10n.groupMembersLabel,
          trailing: _admin && _active
              ? IconButton(
                  tooltip: l10n.groupAddMember,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: () => _addMember(context, ref),
                )
              : null,
          children: <Widget>[
            for (final GroupMemberDto m in active)
              ListTile(
                leading: InitialsAvatar(name: m.displayName),
                title: Text(
                  m.userId == me
                      ? l10n.groupMemberYou(m.displayName)
                      : m.displayName,
                ),
                subtitle: Text(
                  <String>[
                    groupRoleLabel(l10n, m.role.json),
                    ?usernameHandle(m.username),
                  ].join(' · '),
                ),
                trailing: _admin && _active && m.userId != me
                    ? const Icon(Icons.more_vert)
                    : null,
                onTap: _admin && _active && m.userId != me
                    ? () => _memberActions(context, ref, m)
                    : null,
              ),
            if (_admin && _active)
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Text(l10n.groupRemovalPolicy),
              ),
          ],
        ),
        if (_canInvite || _admin) ...<Widget>[
          const SizedBox(height: Insets.md),
          _InvitationsCard(
            group: group,
            canInvite: _canInvite,
            onCreateLink: () => _createLink(context, ref),
          ),
        ],
        if (_admin) ...<Widget>[
          const SizedBox(height: Insets.md),
          _JoinRequestsCard(group: group),
        ],
        if (mine != null && _active) ...<Widget>[
          const SizedBox(height: Insets.md),
          SectionCard(
            title: l10n.groupYourNotifications,
            children: <Widget>[
              for (final GroupMemberUpdateNotificationLevel level
                  in const <GroupMemberUpdateNotificationLevel>[
                    GroupMemberUpdateNotificationLevel.all,
                    GroupMemberUpdateNotificationLevel.important,
                    GroupMemberUpdateNotificationLevel.none,
                  ])
                ListTile(
                  leading: Icon(
                    mine.notificationLevel.json == level.json
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(notificationLevelLabel(l10n, level.json)),
                  selected: mine.notificationLevel.json == level.json,
                  onTap: mine.notificationLevel.json == level.json
                      ? null
                      : () => runGroupAction<GroupDetail>(
                          context,
                          ref,
                          groupId: group.id,
                          action: (GroupsApi api) => api.updateMember(
                            group.id,
                            mine.userId,
                            GroupMemberUpdate(notificationLevel: level),
                          ),
                          success: (_) => l10n.groupNotificationsSaved,
                        ),
                ),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        _GroupActions(group: group, me: me),
        const SizedBox(height: Insets.xl),
      ],
    );
  }
}

class _InvitationsCard extends ConsumerWidget {
  const _InvitationsCard({
    required this.group,
    required this.canInvite,
    required this.onCreateLink,
  });

  final GroupDetail group;
  final bool canInvite;
  final VoidCallback onCreateLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final AsyncValue<List<GroupInvitationDto>> invitations = ref.watch(
      groupInvitationsProvider(group.id),
    );
    final List<GroupInvitationDto> list =
        invitations.value ?? const <GroupInvitationDto>[];
    return SectionCard(
      title: l10n.groupInvitationsTitle,
      children: <Widget>[
        if (canInvite)
          ListTile(
            leading: const Icon(Icons.add_link),
            title: Text(l10n.groupCreateLink),
            subtitle: Text(l10n.groupCreateLinkHelp),
            onTap: onCreateLink,
          ),
        if (invitations.hasError && invitations.value == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.groupInvitationsUnavailable),
          )
        else if (invitations.value != null && list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.groupInvitationsEmpty),
          ),
        for (final GroupInvitationDto i in list)
          ListTile(
            leading: Icon(
              i.kind == GroupInvitationDtoKind.link
                  ? Icons.link
                  : Icons.alternate_email,
            ),
            title: Text(
              i.kind == GroupInvitationDtoKind.link
                  ? l10n.groupInvitationLinkTitle(i.useCount)
                  : l10n.groupInvitationForPerson(
                      i.invitee?.displayName ?? l10n.groupActivitySomeone,
                    ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.groupInvitationCreated(
                    i.invitedBy?.displayName ?? l10n.groupActivitySomeone,
                    formatShortDate(i.createdAt, locale: locale),
                  ),
                ),
                const SizedBox(height: Insets.xs),
                StatusLabel(
                  text: invitationStatusWord(l10n, i.status.json),
                  tone: i.status == GroupInvitationDtoStatus.active
                      ? StatusTone.positive
                      : StatusTone.neutral,
                ),
              ],
            ),
            trailing: i.status == GroupInvitationDtoStatus.active
                ? IconButton(
                    tooltip: l10n.groupInvitationRevoke,
                    icon: const Icon(Icons.link_off),
                    onPressed: () async {
                      final bool ok = await showConfirmDialog(
                        context,
                        title: l10n.groupInvitationRevokeTitle,
                        body: l10n.groupInvitationRevokeBody,
                        confirmLabel: l10n.groupInvitationRevoke,
                        destructive: true,
                      );
                      if (ok && context.mounted) {
                        await runGroupAction<void>(
                          context,
                          ref,
                          groupId: group.id,
                          action: (GroupsApi api) =>
                              api.revokeInvitation(group.id, i.id),
                          success: (_) => l10n.groupInvitationRevokedDone,
                        );
                      }
                    },
                  )
                : null,
          ),
      ],
    );
  }
}

class _JoinRequestsCard extends ConsumerWidget {
  const _JoinRequestsCard({required this.group});

  final GroupDetail group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<GroupJoinRequestDto>> requests = ref.watch(
      groupJoinRequestsProvider(group.id),
    );
    final List<GroupJoinRequestDto> pending = <GroupJoinRequestDto>[
      for (final GroupJoinRequestDto r
          in requests.value ?? const <GroupJoinRequestDto>[])
        if (r.status == GroupJoinRequestDtoStatus.pending) r,
    ];
    return SectionCard(
      title: l10n.groupJoinRequestsTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(
            group.requireJoinApproval
                ? l10n.groupJoinRequestsOnHelp
                : l10n.groupJoinRequestsOffHelp,
          ),
        ),
        if (requests.hasError && requests.value == null)
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(l10n.groupJoinRequestsUnavailable),
          )
        else if (requests.value != null && pending.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Text(l10n.groupJoinRequestsEmpty),
          ),
        for (final GroupJoinRequestDto r in pending)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ListTile(
                leading: InitialsAvatar(name: r.displayName),
                title: Text(r.displayName),
                subtitle: (r.message ?? '').isEmpty
                    ? null
                    : Text(l10n.friendRequestMessage(r.message!)),
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
                      onPressed: () => runGroupAction<GroupDetail>(
                        context,
                        ref,
                        groupId: group.id,
                        action: (GroupsApi api) =>
                            api.declineJoinRequest(group.id, r.id),
                        success: (_) =>
                            l10n.groupJoinRequestDeclinedDone(r.displayName),
                      ),
                      child: Text(l10n.groupJoinRequestDecline),
                    ),
                    FilledButton(
                      onPressed: () => runGroupAction<GroupDetail>(
                        context,
                        ref,
                        groupId: group.id,
                        action: (GroupsApi api) =>
                            api.approveJoinRequest(group.id, r.id),
                        success: (_) =>
                            l10n.groupJoinRequestApprovedDone(r.displayName),
                      ),
                      child: Text(l10n.groupJoinRequestApprove),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _GroupActions extends ConsumerWidget {
  const _GroupActions({required this.group, required this.me});

  final GroupDetail group;
  final String? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool owner = group.myRole == GroupDetailMyRole.owner;
    final bool archived = group.status == GroupDetailStatus.archived;
    final FinanceRevision finance = ref.read(financeRevisionProvider.notifier);
    return SectionCard(
      title: l10n.groupActionsSection,
      children: <Widget>[
        if (owner && !archived)
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(l10n.groupArchive),
            subtitle: Text(l10n.groupArchiveHelp),
            onTap: () async {
              final bool ok = await showConfirmDialog(
                context,
                title: l10n.groupArchiveConfirmTitle(group.name),
                body: l10n.groupArchiveHelp,
                confirmLabel: l10n.groupArchive,
              );
              if (ok && context.mounted) {
                await runGroupAction<GroupDto>(
                  context,
                  ref,
                  groupId: group.id,
                  action: (GroupsApi api) => api.archive(group.id),
                  success: (_) => l10n.groupArchivedDone,
                );
              }
            },
          ),
        if (owner && archived)
          ListTile(
            leading: const Icon(Icons.unarchive_outlined),
            title: Text(l10n.groupRestore),
            onTap: () => runGroupAction<GroupDto>(
              context,
              ref,
              groupId: group.id,
              action: (GroupsApi api) => api.restore(group.id),
              success: (_) => l10n.groupRestoredDone,
            ),
          ),
        if (!owner && me != null)
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.groupLeave),
            subtitle: Text(l10n.groupLeaveHelp),
            onTap: () async {
              final bool ok = await showConfirmDialog(
                context,
                title: l10n.groupLeaveConfirmTitle(group.name),
                body: l10n.groupLeaveHelp,
                confirmLabel: l10n.groupLeave,
                destructive: true,
              );
              if (!ok || !context.mounted) {
                return;
              }
              final GoRouter router = GoRouter.of(context);
              final bool? left = await runGroupAction<bool>(
                context,
                ref,
                action: (GroupsApi api) async {
                  await api.removeMember(group.id, me!);
                  return true;
                },
                success: (_) => l10n.groupLeftDone(group.name),
              );
              if (left ?? false) {
                router.go(AppRoutes.groups);
              }
            },
          ),
        if (owner)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(l10n.groupOwnerLeaveNote),
          ),
        if (owner)
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.groupDelete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(l10n.groupDeleteHelp),
            onTap: () async {
              final bool ok = await showConfirmDialog(
                context,
                title: l10n.groupDeleteConfirmTitle(group.name),
                body: l10n.groupDeleteHelp,
                confirmLabel: l10n.groupDelete,
                destructive: true,
              );
              if (!ok || !context.mounted) {
                return;
              }
              final GoRouter router = GoRouter.of(context);
              final GroupDto? deleted = await runGroupAction<GroupDto>(
                context,
                ref,
                action: (GroupsApi api) => api.delete(group.id),
                success: (_) => l10n.groupDeletedDone(group.name),
              );
              if (deleted != null) {
                finance.bump();
                router.go(AppRoutes.groups);
              }
            },
          ),
      ],
    );
  }
}

class _UsernameDialog extends StatefulWidget {
  const _UsernameDialog();

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  void _done() {
    if (_form.currentState?.validate() ?? false) {
      Navigator.of(context).pop(normalizeUsername(_username.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.groupAddByUsername),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.groupAddByUsernameHelp),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _username,
              autofocus: true,
              autocorrect: false,
              maxLength: AddMemberInput.usernameMaxLength,
              decoration: InputDecoration(
                labelText: l10n.usernameLabel,
                prefixText: '@',
              ),
              validator: (String? v) =>
                  normalizeUsername(v ?? '').length <
                      AddMemberInput.usernameMinLength
                  ? l10n.friendFindTooShort
                  : null,
              onFieldSubmitted: (_) => _done(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _done, child: Text(l10n.groupInvite)),
      ],
    );
  }
}

class _LinkOptionsDialog extends StatefulWidget {
  const _LinkOptionsDialog();

  @override
  State<_LinkOptionsDialog> createState() => _LinkOptionsDialogState();
}

class _LinkOptionsDialogState extends State<_LinkOptionsDialog> {
  int _days = 7;
  int? _uses;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.groupCreateLink),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.groupLinkExpiresLabel),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final int d in const <int>[1, 7, 30])
                ChoiceChip(
                  label: Text(l10n.groupLinkDays(d)),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(l10n.groupLinkUsesLabel),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final int? u in const <int?>[1, 5, 20, null])
                ChoiceChip(
                  label: Text(
                    u == null ? l10n.groupLinkUsesAny : l10n.groupLinkUses(u),
                  ),
                  selected: _uses == u,
                  onSelected: (_) => setState(() => _uses = u),
                ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((days: _days, uses: _uses)),
          child: Text(l10n.groupCreateLink),
        ),
      ],
    );
  }
}

class _ShareLinkDialog extends ConsumerWidget {
  const _ShareLinkDialog({required this.link, required this.groupName});

  final String link;
  final String groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.groupLinkReadyTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.groupLinkShownOnce),
          const SizedBox(height: Insets.sm),
          SelectableText(link),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => copyText(context, link),
          child: Text(l10n.actionCopy),
        ),
        TextButton(
          onPressed: () => ref.read(textSharerProvider)(
            l10n.groupLinkShareText(groupName, link),
          ),
          child: Text(l10n.fileShare),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionDone),
        ),
      ],
    );
  }
}
