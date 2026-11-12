import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';
import 'package:montra_mobile/features/social/application/social_providers.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';
import 'package:montra_mobile/features/social/domain/social_display.dart';
import 'package:montra_mobile/features/social/presentation/person_widgets.dart';

/// People the user blocked and muted (`GET /blocks`, `GET /mutes`, newest
/// first, page by page), with unblock and unmute. Blocked people look
/// absent everywhere else; muted people stay connected but quiet.
class BlockedMutedScreen extends ConsumerWidget {
  /// Creates the screen.
  const BlockedMutedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.friendsBlockedAndMutedTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.friendsBlockedTab),
              Tab(text: l10n.friendsMutedTab),
            ],
          ),
        ),
        body: const TabBarView(children: <Widget>[_Blocked(), _Muted()]),
      ),
    );
  }
}

class _Blocked extends ConsumerWidget {
  const _Blocked();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return AsyncValueView<PagedList<BlockDto>>(
      value: ref.watch(blocksProvider),
      onRetry: () => ref.invalidate(blocksProvider),
      isEmpty: (PagedList<BlockDto> p) => p.items.isEmpty,
      empty: MessageStateView(
        icon: Icons.block,
        title: l10n.friendsBlockedEmptyTitle,
        body: l10n.friendsBlockedHelp,
      ),
      data: (PagedList<BlockDto> page) => ListView(
        children: <Widget>[
          ContentFrame(child: Text(l10n.friendsBlockedHelp)),
          for (final BlockDto b in page.items)
            _PersonWithAction(
              person: PersonView.ofBlock(b),
              action: TextButton(
                onPressed: () => runSocialAction(
                  context,
                  ref,
                  action: (SocialApi api) async {
                    await api.unblock(b.userId);
                    return l10n.friendUnblockedDone(b.displayName);
                  },
                ),
                child: Text(l10n.friendUnblock),
              ),
            ),
          LoadMoreFooter(
            list: page,
            onLoadMore: () => ref.read(blocksProvider.notifier).loadMore(),
          ),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}

class _Muted extends ConsumerWidget {
  const _Muted();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return AsyncValueView<PagedList<MuteDto>>(
      value: ref.watch(mutesProvider),
      onRetry: () => ref.invalidate(mutesProvider),
      isEmpty: (PagedList<MuteDto> p) => p.items.isEmpty,
      empty: MessageStateView(
        icon: Icons.volume_off_outlined,
        title: l10n.friendsMutedEmptyTitle,
        body: l10n.friendMuteHelp,
      ),
      data: (PagedList<MuteDto> page) => ListView(
        children: <Widget>[
          ContentFrame(child: Text(l10n.friendMuteHelp)),
          for (final MuteDto m in page.items)
            _PersonWithAction(
              person: PersonView.ofMute(m),
              action: TextButton(
                onPressed: () => runSocialAction(
                  context,
                  ref,
                  action: (SocialApi api) async {
                    await api.setMuted(m.userId, muted: false);
                    return l10n.friendUnmutedDone(m.displayName);
                  },
                ),
                child: Text(l10n.friendUnmute),
              ),
            ),
          LoadMoreFooter(
            list: page,
            onLoadMore: () => ref.read(mutesProvider.notifier).loadMore(),
          ),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}

/// A person with one action button under the row (room for 200 % text).
class _PersonWithAction extends StatelessWidget {
  const _PersonWithAction({required this.person, required this.action});

  final PersonView person;
  final Widget action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      PersonTile(person: person),
      Padding(
        padding: const EdgeInsets.only(right: Insets.md, left: Insets.md),
        child: Align(alignment: AlignmentDirectional.centerEnd, child: action),
      ),
    ],
  );
}
