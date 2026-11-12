import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/relative_time.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';

/// Communities: discover and search, the user's own communities, and
/// invitations addressed to them. "Join with a link" opens the invitation
/// link flow; anyone can start a community.
class CommunitiesScreen extends ConsumerStatefulWidget {
  /// Creates the screen, opened on [initialTab] (`discover`, `yours` or
  /// `invitations`).
  const CommunitiesScreen({this.initialTab, super.key});

  /// Tab to open first.
  final String? initialTab;

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  static const List<String> _tabs = <String>[
    'discover',
    'yours',
    'invitations',
  ];

  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int initial = _tabs.indexOf(widget.initialTab ?? '');
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initial < 0 ? 0 : initial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.communitiesTitle),
          actions: <Widget>[
            IconButton(
              tooltip: l10n.communityJoinWithLink,
              icon: const Icon(Icons.link),
              onPressed: () => context.push(AppRoutes.joinCommunity),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: l10n.communitiesTabDiscover),
              Tab(text: l10n.communitiesTabYours),
              Tab(text: l10n.communitiesTabInvitations),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => context.push(AppRoutes.newCommunity),
          icon: const Icon(Icons.add),
          label: Text(l10n.communityCreate),
        ),
        body: TabBarView(
          children: <Widget>[
            _DiscoverTab(
              search: _search,
              query: _query,
              onSearch: (String q) => setState(() => _query = q.trim()),
            ),
            const _YoursTab(),
            const _InvitationsTab(),
          ],
        ),
      ),
    );
  }
}

class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab({
    required this.search,
    required this.query,
    required this.onSearch,
  });

  final TextEditingController search;
  final String query;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<CommunityDto>> list = ref.watch(
      discoverCommunitiesProvider(query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.sm,
            Insets.md,
            Insets.xs,
          ),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: onSearch,
            decoration: InputDecoration(
              labelText: l10n.communitiesSearchLabel,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.actionClear,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        search.clear();
                        onSearch('');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: AsyncValueView<List<CommunityDto>>(
            value: list,
            onRetry: () => ref.invalidate(discoverCommunitiesProvider(query)),
            isEmpty: (List<CommunityDto> data) => data.isEmpty,
            empty: MessageStateView(
              icon: Icons.forum_outlined,
              title: query.isEmpty
                  ? l10n.communitiesEmptyTitle
                  : l10n.communitiesNoMatches(query),
              body: l10n.communitiesEmptyBody,
            ),
            data: (List<CommunityDto> data) => RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(discoverCommunitiesProvider(query).future),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: <Widget>[
                  for (final CommunityDto c in data)
                    CommunityTile(community: c),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _YoursTab extends ConsumerWidget {
  const _YoursTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<CommunityDto>> list = ref.watch(
      myCommunitiesProvider,
    );
    return AsyncValueView<List<CommunityDto>>(
      value: list,
      onRetry: () => ref.invalidate(myCommunitiesProvider),
      isEmpty: (List<CommunityDto> data) => data.isEmpty,
      empty: MessageStateView(
        icon: Icons.forum_outlined,
        title: l10n.communitiesYoursEmptyTitle,
        body: l10n.communitiesYoursEmptyBody,
      ),
      data: (List<CommunityDto> data) => RefreshIndicator(
        onRefresh: () => ref.refresh(myCommunitiesProvider.future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: <Widget>[
            for (final CommunityDto c in data) CommunityTile(community: c),
          ],
        ),
      ),
    );
  }
}

class _InvitationsTab extends ConsumerStatefulWidget {
  const _InvitationsTab();

  @override
  ConsumerState<_InvitationsTab> createState() => _InvitationsTabState();
}

class _InvitationsTabState extends ConsumerState<_InvitationsTab> {
  final Set<String> _busy = <String>{};

  Future<void> _accept(CommunityInvitationDto invitation) async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    setState(() => _busy.add(invitation.id));
    try {
      final CommunityDto community = await ref
          .read(communitiesApiProvider)
          .acceptInvitation(invitation.id);
      ref.read(communityRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.communityJoinedDone(community.name));
        await router.push(AppRoutes.communityPage(community.id));
      }
    } on ApiException catch (error) {
      ref.invalidate(myCommunityInvitationsProvider);
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(invitation.id));
      }
    }
  }

  Future<void> _decline(CommunityInvitationDto invitation) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.communityInvitationDeclineTitle,
      body: l10n.communityInvitationDeclineBody(
        invitation.communityName ?? l10n.communityUnnamed,
      ),
      confirmLabel: l10n.communityInvitationDecline,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy.add(invitation.id));
    try {
      await ref.read(communitiesApiProvider).declineInvitation(invitation.id);
      ref.read(communityRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(context, l10n.communityInvitationDeclined);
      }
    } on ApiException catch (error) {
      ref.invalidate(myCommunityInvitationsProvider);
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(invitation.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<CommunityInvitationDto>> list = ref.watch(
      myCommunityInvitationsProvider,
    );
    final String locale = Localizations.localeOf(context).toString();
    return AsyncValueView<List<CommunityInvitationDto>>(
      value: list,
      onRetry: () => ref.invalidate(myCommunityInvitationsProvider),
      isEmpty: (List<CommunityInvitationDto> data) => data.isEmpty,
      empty: MessageStateView(
        icon: Icons.mail_outline,
        title: l10n.communityInvitationsEmptyTitle,
        body: l10n.communityInvitationsEmptyBody,
      ),
      data: (List<CommunityInvitationDto> data) => RefreshIndicator(
        onRefresh: () => ref.refresh(myCommunityInvitationsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(Insets.md),
          children: <Widget>[
            for (final CommunityInvitationDto inv in data)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          inv.communityName ?? l10n.communityUnnamed,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      if (inv.invitedBy case final CommunityPersonDto by)
                        Text(l10n.communityInvitedBy(by.displayName)),
                      Text(
                        l10n.communityInvitationExpires(
                          formatShortDate(inv.expiresAt, locale: locale),
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      if (inv.status == CommunityInvitationDtoStatus.active)
                        Wrap(
                          spacing: Insets.sm,
                          runSpacing: Insets.xs,
                          children: <Widget>[
                            FilledButton(
                              onPressed: _busy.contains(inv.id)
                                  ? null
                                  : () => _accept(inv),
                              child: Text(l10n.communityInvitationAccept),
                            ),
                            OutlinedButton(
                              onPressed: _busy.contains(inv.id)
                                  ? null
                                  : () => _decline(inv),
                              child: Text(l10n.communityInvitationDecline),
                            ),
                          ],
                        )
                      else
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: StatusLabel(
                            text: invitationStatusLabel(l10n, inv.status.json),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One community in a list: name, visibility, members, topics and the
/// user's membership. Opens the community page.
class CommunityTile extends StatelessWidget {
  /// Creates the tile.
  const CommunityTile({required this.community, super.key});

  /// The community.
  final CommunityDto community;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CommunityDto c = community;
    final String? membership = switch (c.myStatus) {
      CommunityDtoMyStatus.active => communityRoleLabel(l10n, c.myRole.json),
      CommunityDtoMyStatus.pending => l10n.communityMemberStatusPending,
      CommunityDtoMyStatus.banned => l10n.communityMemberStatusBanned,
      _ => null,
    };
    return ListTile(
      leading: const Icon(Icons.forum_outlined),
      title: Text(c.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              communityVisibilityLabel(l10n, c.visibility.json),
              l10n.communityMemberCount(c.memberCount),
              if (c.status == CommunityDtoStatus.archived)
                l10n.communityStatusArchived,
              if (c.status == CommunityDtoStatus.suspended)
                l10n.communityStatusSuspended,
            ].join(' · '),
          ),
          if (c.topics.isNotEmpty)
            Text(
              c.topics.join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (membership != null) ...<Widget>[
            const SizedBox(height: Insets.xs),
            StatusLabel(
              text: membership,
              tone: c.myStatus == CommunityDtoMyStatus.active
                  ? StatusTone.positive
                  : StatusTone.caution,
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.communityPage(c.id)),
    );
  }
}
