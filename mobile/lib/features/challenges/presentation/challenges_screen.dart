import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/challenges/application/challenges_providers.dart';
import 'package:montra_mobile/features/challenges/domain/challenge_display.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';

/// Challenges: the user's own (created or joined) and ones they can join,
/// active first, page by page. Progress is private unless shared.
class ChallengesScreen extends StatelessWidget {
  /// Creates the screen.
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.challengesTitle),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: l10n.challengesTabMine),
              Tab(text: l10n.challengesTabDiscover),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => context.push(AppRoutes.newChallenge),
          icon: const Icon(Icons.add),
          label: Text(l10n.challengeCreate),
        ),
        body: const TabBarView(
          children: <Widget>[
            _ChallengeList(scope: 'mine'),
            _ChallengeList(scope: 'discover'),
          ],
        ),
      ),
    );
  }
}

class _ChallengeList extends ConsumerWidget {
  const _ChallengeList({required this.scope});

  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<PagedList<ChallengeDto>> list = ref.watch(
      challengesProvider(scope),
    );
    return AsyncValueView<PagedList<ChallengeDto>>(
      value: list,
      onRetry: () => ref.invalidate(challengesProvider(scope)),
      isEmpty: (PagedList<ChallengeDto> data) => data.items.isEmpty,
      empty: MessageStateView(
        icon: Icons.flag_outlined,
        title: scope == 'mine'
            ? l10n.challengesMineEmptyTitle
            : l10n.challengesDiscoverEmptyTitle,
        body: scope == 'mine'
            ? l10n.challengesMineEmptyBody
            : l10n.challengesDiscoverEmptyBody,
      ),
      data: (PagedList<ChallengeDto> data) => RefreshIndicator(
        onRefresh: () => ref.refresh(challengesProvider(scope).future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: <Widget>[
            for (final ChallengeDto c in data.items)
              ChallengeTile(challenge: c),
            LoadMoreFooter(
              list: data,
              onLoadMore: () =>
                  ref.read(challengesProvider(scope).notifier).loadMore(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A challenge in a list: title, type, dates, where it runs, status and
/// the user's progress when they take part.
class ChallengeTile extends StatelessWidget {
  /// Creates the tile.
  const ChallengeTile({required this.challenge, super.key});

  /// The challenge.
  final ChallengeDto challenge;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).toString();
    final ChallengeDto c = challenge;
    final ChallengeParticipationDto? me = c.me;
    final String? scope = c.group?.name ?? c.community?.name;
    return ListTile(
      leading: const Icon(Icons.flag_outlined),
      title: Text(c.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              challengeTypeLabel(l10n, c.challengeType),
              LocalDates.displayRange(c.startsOn, c.endsOn, locale: locale),
            ].join(' · '),
          ),
          Text(
            <String>[
              ?scope,
              l10n.challengeParticipants(c.participantCount),
            ].join(' · '),
          ),
          if (me != null && me.status != ChallengeParticipationDtoStatus.left)
            Text(l10n.challengeYourProgress(me.percentComplete)),
          const SizedBox(height: Insets.xs),
          StatusLabel(
            text: challengeStatusLabel(l10n, c),
            tone: challengeIsOpen(c) ? StatusTone.positive : StatusTone.neutral,
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.challengeDetail(c.id)),
    );
  }
}
