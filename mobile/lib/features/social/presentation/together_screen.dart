import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/features/groups/application/groups_providers.dart';
import 'package:montra_mobile/features/social/application/social_providers.dart';

/// Together tab: friends, groups, communities and challenges, plus
/// joining a group or community with a link. Counts are shown when they
/// load; the hub works without them (nothing here depends on the API).
class TogetherScreen extends ConsumerWidget {
  /// Creates the screen.
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? me = ref.watch(currentUserIdProvider);
    final List<FriendRequestDto>? requests = ref
        .watch(friendRequestsProvider)
        .value;
    final int incoming = requests == null
        ? 0
        : incomingRequests(requests, me).length;
    final List<GroupDto>? groups = ref.watch(allGroupsProvider).value;
    final int activeGroups = groups == null
        ? 0
        : groups
              .where((GroupDto g) => g.status == GroupDtoStatus.active)
              .length;
    final int invitations =
        ref.watch(myGroupInvitationsProvider).value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTogether)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(friendRequestsProvider)
            ..invalidate(allGroupsProvider)
            ..invalidate(myGroupInvitationsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            ContentFrame(child: Text(l10n.togetherIntro)),
            _HubTile(
              icon: Icons.people_outline,
              title: l10n.friendsTitle,
              subtitle: incoming > 0
                  ? l10n.togetherFriendRequests(incoming)
                  : l10n.togetherFriendsSubtitle,
              badge: incoming,
              onTap: () => context.push(
                incoming > 0
                    ? AppRoutes.friendsTab('requests')
                    : AppRoutes.friends,
              ),
            ),
            _HubTile(
              icon: Icons.groups_outlined,
              title: l10n.groupsTitle,
              subtitle: invitations > 0
                  ? l10n.togetherGroupInvitations(invitations)
                  : groups == null || activeGroups == 0
                  ? l10n.togetherGroupsSubtitle
                  : l10n.togetherGroupsCount(activeGroups),
              badge: invitations,
              onTap: () => context.push(AppRoutes.groups),
            ),
            _HubTile(
              icon: Icons.forum_outlined,
              title: l10n.togetherCommunities,
              subtitle: l10n.togetherCommunitiesSubtitle,
              onTap: () => context.push(AppRoutes.communities),
            ),
            _HubTile(
              icon: Icons.flag_outlined,
              title: l10n.togetherChallenges,
              subtitle: l10n.togetherChallengesSubtitle,
              onTap: () => context.push(AppRoutes.challenges),
            ),
            const Divider(),
            ContentFrame(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                0,
              ),
              child: SectionHeading(l10n.togetherJoinSection),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.groupJoinTitle),
              subtitle: Text(l10n.togetherJoinGroupSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.joinGroup),
            ),
            ListTile(
              leading: const Icon(Icons.add_link),
              title: Text(l10n.togetherJoinCommunity),
              subtitle: Text(l10n.togetherJoinCommunitySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.joinCommunity),
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: badge > 0
        ? Badge.count(count: badge, child: Icon(icon))
        : Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
