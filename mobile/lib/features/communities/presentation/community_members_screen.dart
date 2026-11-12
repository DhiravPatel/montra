import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/presentation/community_widgets.dart';
import 'package:montra_mobile/features/people/presentation/people_pickers.dart';

/// Members of a community. Moderators see everyone by status (members,
/// requests waiting for approval, banned people) and can approve or reject
/// requests, warn, pause posting or ban; the owner also makes members
/// moderators. Everyone else sees who moderates the community.
class CommunityMembersScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [communityRef].
  const CommunityMembersScreen({required this.communityRef, super.key});

  /// The community's ID or URL name.
  final String communityRef;

  @override
  ConsumerState<CommunityMembersScreen> createState() =>
      _CommunityMembersScreenState();
}

class _CommunityMembersScreenState
    extends ConsumerState<CommunityMembersScreen> {
  String _status = 'active';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CommunityDto> community = ref.watch(
      communityProvider(widget.communityRef),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.communityMembersTitle)),
      body: AsyncValueView<CommunityDto>(
        value: community,
        onRetry: () => ref.invalidate(communityProvider(widget.communityRef)),
        data: (CommunityDto c) => _body(context, c),
      ),
    );
  }

  Widget _body(BuildContext context, CommunityDto c) {
    final AppLocalizations l10n = context.l10n;
    final MembersQuery query = (
      communityId: c.id,
      status: c.canModerate ? _status : '',
    );
    final AsyncValue<List<CommunityMemberDto>> members = ref.watch(
      communityMembersProvider(query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: c.canModerate
              ? Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    for (final (String value, String label)
                        in <(String, String)>[
                          ('active', l10n.communityMembersFilterActive),
                          ('pending', l10n.communityMembersFilterPending),
                          ('banned', l10n.communityMembersFilterBanned),
                        ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _status == value,
                        onSelected: (_) => setState(() => _status = value),
                      ),
                  ],
                )
              : Text(l10n.communityMembersModeratorsOnlyNote),
        ),
        Expanded(
          child: AsyncValueView<List<CommunityMemberDto>>(
            value: members,
            onRetry: () => ref.invalidate(communityMembersProvider(query)),
            isEmpty: (List<CommunityMemberDto> data) => data.isEmpty,
            empty: MessageStateView(
              icon: Icons.people_outline,
              title: _status == 'pending' && c.canModerate
                  ? l10n.communityMembersNoRequests
                  : l10n.communityMembersEmpty,
            ),
            data: (List<CommunityMemberDto> data) => RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(communityMembersProvider(query).future),
              child: ListView(
                children: <Widget>[
                  for (final CommunityMemberDto m in data)
                    _MemberTile(community: c, member: m),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _MemberChoice { makeModerator, makeMember, moderate }

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.community, required this.member});

  final CommunityDto community;
  final CommunityMemberDto member;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(CommunitiesApi api) task,
    String done,
  ) async {
    final AppLocalizations l10n = context.l10n;
    try {
      await task(ref.read(communitiesApiProvider));
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, done);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final CommunityMemberDto m = member;
    final String? me = ref.watch(currentUserIdProvider);
    final bool self = m.userId == me;
    final bool owner = community.myRole == CommunityDtoMyRole.owner;
    final bool isOwner = m.role == CommunityMemberDtoRole.owner;
    final bool moderator = community.canModerate;
    final DateTime? restricted = m.restrictedUntil;
    final String? handle = m.username == null || m.username!.isEmpty
        ? null
        : '@${m.username}';
    return ListTile(
      leading: InitialsAvatar(name: m.displayName),
      title: Text(
        self ? l10n.communityMemberYou(m.displayName) : m.displayName,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              ?handle,
              communityRoleLabel(l10n, m.role.json),
            ].join(' · '),
          ),
          if (m.status != CommunityMemberDtoStatus.active)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: StatusLabel(
                text: communityMemberStatusLabel(l10n, m.status.json),
                tone: StatusTone.caution,
              ),
            ),
          if (restricted != null && restricted.isAfter(DateTime.now()))
            Text(
              l10n.communityMemberRestrictedUntil(
                formatDateTime(restricted, locale: locale),
              ),
            ),
          if (moderator && m.status == CommunityMemberDtoStatus.pending)
            Wrap(
              spacing: Insets.sm,
              children: <Widget>[
                FilledButton(
                  onPressed: () => _run(
                    context,
                    ref,
                    (CommunitiesApi api) =>
                        api.approveMember(community.id, m.userId),
                    l10n.communityMemberApproved(m.displayName),
                  ),
                  child: Text(l10n.communityMemberApprove),
                ),
                OutlinedButton(
                  onPressed: () => _run(
                    context,
                    ref,
                    (CommunitiesApi api) =>
                        api.rejectMember(community.id, m.userId),
                    l10n.communityMemberRejected(m.displayName),
                  ),
                  child: Text(l10n.communityMemberReject),
                ),
              ],
            ),
        ],
      ),
      trailing:
          moderator &&
              !self &&
              !isOwner &&
              m.status != CommunityMemberDtoStatus.pending
          ? PopupMenuButton<_MemberChoice>(
              tooltip: l10n.communityMemberActions(m.displayName),
              onSelected: (_MemberChoice choice) async {
                switch (choice) {
                  case _MemberChoice.makeModerator:
                    await _run(
                      context,
                      ref,
                      (CommunitiesApi api) => api.setMemberRole(
                        community.id,
                        m.userId,
                        CommunityMemberRoleInputRole.moderator,
                      ),
                      l10n.communityMemberNowModerator(m.displayName),
                    );
                  case _MemberChoice.makeMember:
                    await _run(
                      context,
                      ref,
                      (CommunitiesApi api) => api.setMemberRole(
                        community.id,
                        m.userId,
                        CommunityMemberRoleInputRole.member,
                      ),
                      l10n.communityMemberNowMember(m.displayName),
                    );
                  case _MemberChoice.moderate:
                    await moderateTarget(
                      context,
                      ref,
                      communityId: community.id,
                      targetType: ModerationActionInputTargetType.member,
                      targetId: m.userId,
                      actions: actionsFor(
                        ModerationActionInputTargetType.member,
                        banned: m.status == CommunityMemberDtoStatus.banned,
                      ),
                    );
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_MemberChoice>>[
                    if (owner &&
                        m.status == CommunityMemberDtoStatus.active &&
                        m.role == CommunityMemberDtoRole.member)
                      PopupMenuItem<_MemberChoice>(
                        value: _MemberChoice.makeModerator,
                        child: Text(l10n.communityMemberMakeModerator),
                      ),
                    if (owner && m.role == CommunityMemberDtoRole.moderator)
                      PopupMenuItem<_MemberChoice>(
                        value: _MemberChoice.makeMember,
                        child: Text(l10n.communityMemberMakeMember),
                      ),
                    PopupMenuItem<_MemberChoice>(
                      value: _MemberChoice.moderate,
                      child: Text(l10n.moderationModerate),
                    ),
                  ],
            )
          : null,
    );
  }
}
