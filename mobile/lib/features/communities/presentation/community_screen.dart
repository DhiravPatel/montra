import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/formatting/dates.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/presentation/community_paths.dart';
import 'package:montra_mobile/features/communities/presentation/community_widgets.dart';
import 'package:montra_mobile/features/labels/application/paged_list.dart';
import 'package:montra_mobile/features/labels/presentation/load_more_footer.dart';

/// Whether the user takes part in [c] (an active member).
bool isActiveMember(CommunityDto c) =>
    c.myStatus == CommunityDtoMyStatus.active;

/// Whether the user can post and react in [c] now.
bool canParticipate(CommunityDto c, DateTime now) =>
    isActiveMember(c) &&
    c.status == CommunityDtoStatus.active &&
    (c.restrictedUntil == null || c.restrictedUntil!.isBefore(now));

/// A community: what it is about, the user's membership (join, ask to
/// join, waiting for approval, leave), and its feed (new, top or active
/// posts, searchable, page by page). Moderators also reach the settings and
/// the moderation queue from here.
class CommunityScreen extends ConsumerWidget {
  /// Creates the screen for [communityRef] (ID or URL name).
  const CommunityScreen({required this.communityRef, super.key});

  /// The community's ID or URL name.
  final String communityRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CommunityDto> community = ref.watch(
      communityProvider(communityRef),
    );
    final CommunityDto? loaded = community.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? l10n.communitiesTitle),
        actions: <Widget>[
          if (loaded != null) _CommunityMenu(community: loaded),
        ],
      ),
      floatingActionButton:
          loaded != null && canParticipate(loaded, DateTime.now())
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => context.push(CommunityPaths.newPost(loaded.id)),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.postNew),
            )
          : null,
      body: AsyncValueView<CommunityDto>(
        value: community,
        onRetry: () => ref.invalidate(communityProvider(communityRef)),
        data: (CommunityDto c) => _CommunityBody(community: c),
      ),
    );
  }
}

enum _MenuChoice { members, settings, moderation, challenge, report, leave }

class _CommunityMenu extends ConsumerWidget {
  const _CommunityMenu({required this.community});

  final CommunityDto community;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.communityLeaveTitle(community.name),
      body: l10n.communityLeaveBody,
      confirmLabel: l10n.communityLeave,
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(communitiesApiProvider).leave(community.id);
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, l10n.communityLeftDone);
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
    final CommunityDto c = community;
    final bool owner = c.myRole == CommunityDtoMyRole.owner;
    return PopupMenuButton<_MenuChoice>(
      tooltip: l10n.actionMore,
      onSelected: (_MenuChoice choice) async {
        switch (choice) {
          case _MenuChoice.members:
            await context.push(AppRoutes.communityMembers(c.id));
          case _MenuChoice.settings:
            await context.push(AppRoutes.communitySettings(c.id));
          case _MenuChoice.moderation:
            await context.push(AppRoutes.communityModeration(c.id));
          case _MenuChoice.challenge:
            await context.push(CommunityPaths.newChallengeFor(c.id));
          case _MenuChoice.report:
            await showReportSheet(
              context,
              ref,
              kind: ReportTargetKind.community,
              targetId: c.id,
            );
          case _MenuChoice.leave:
            await _leave(context, ref);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_MenuChoice>>[
        PopupMenuItem<_MenuChoice>(
          value: _MenuChoice.members,
          child: Text(l10n.communityMembersTitle),
        ),
        if (c.canModerate) ...<PopupMenuEntry<_MenuChoice>>[
          PopupMenuItem<_MenuChoice>(
            value: _MenuChoice.settings,
            child: Text(l10n.communitySettingsTitle),
          ),
          PopupMenuItem<_MenuChoice>(
            value: _MenuChoice.moderation,
            child: Text(l10n.communityModerationTitle),
          ),
        ],
        if (canParticipate(c, DateTime.now()))
          PopupMenuItem<_MenuChoice>(
            value: _MenuChoice.challenge,
            child: Text(l10n.communityStartChallenge),
          ),
        if (!owner)
          PopupMenuItem<_MenuChoice>(
            value: _MenuChoice.report,
            child: Text(l10n.communityReport),
          ),
        if (isActiveMember(c) && !owner)
          PopupMenuItem<_MenuChoice>(
            value: _MenuChoice.leave,
            child: Text(l10n.communityLeave),
          ),
      ],
    );
  }
}

class _CommunityBody extends ConsumerStatefulWidget {
  const _CommunityBody({required this.community});

  final CommunityDto community;

  @override
  ConsumerState<_CommunityBody> createState() => _CommunityBodyState();
}

class _CommunityBodyState extends ConsumerState<_CommunityBody> {
  String _sort = 'new';
  String _query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  FeedQuery get _feed =>
      (communityId: widget.community.id, sort: _sort, q: _query);

  bool get _canSeeFeed {
    final CommunityDto c = widget.community;
    return c.visibility == CommunityDtoVisibility.public ||
        isActiveMember(c) ||
        c.canModerate;
  }

  Future<void> _join() async {
    final AppLocalizations l10n = context.l10n;
    final CommunityDto c = widget.community;
    try {
      final CommunityDto after = await ref
          .read(communitiesApiProvider)
          .join(c.id);
      ref.read(communityRevisionProvider.notifier).bump();
      if (mounted) {
        showSnack(
          context,
          after.myStatus == CommunityDtoMyStatus.pending
              ? l10n.communityJoinRequested
              : l10n.communityJoinedDone(after.name),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CommunityDto c = widget.community;
    final AsyncValue<PagedList<CommunityPostDto>>? feed = _canSeeFeed
        ? ref.watch(communityFeedProvider(_feed))
        : null;
    final PagedList<CommunityPostDto>? posts = feed?.value;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(communityProvider(c.id));
        if (_canSeeFeed) {
          ref.invalidate(communityFeedProvider(_feed));
        }
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          _Header(community: c, onJoin: _join),
          if (_canSeeFeed) ...<Widget>[
            _FeedControls(
              sort: _sort,
              search: _search,
              query: _query,
              onSort: (String s) => setState(() => _sort = s),
              onSearch: (String q) => setState(() => _query = q.trim()),
            ),
            ..._feedItems(context, c, feed!, posts),
          ] else
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: NoticeBanner(
                message: context.l10n.communityFeedMembersOnly,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _feedItems(
    BuildContext context,
    CommunityDto c,
    AsyncValue<PagedList<CommunityPostDto>> feed,
    PagedList<CommunityPostDto>? posts,
  ) {
    final AppLocalizations l10n = context.l10n;
    if (feed.hasError && !feed.isLoading && posts == null) {
      return <Widget>[
        SizedBox(
          height: 320,
          child: ErrorStateView(
            error: feed.error!,
            onRetry: () => ref.invalidate(communityFeedProvider(_feed)),
          ),
        ),
      ];
    }
    if (posts == null) {
      return const <Widget>[
        Padding(padding: EdgeInsets.all(Insets.lg), child: LoadingStateView()),
      ];
    }
    if (posts.items.isEmpty) {
      return <Widget>[
        MessageStateView(
          icon: Icons.chat_bubble_outline,
          title: _query.isEmpty
              ? l10n.communityFeedEmptyTitle
              : l10n.communityFeedNoMatches(_query),
          body: canParticipate(c, DateTime.now())
              ? l10n.communityFeedEmptyBody
              : null,
        ),
      ];
    }
    return <Widget>[
      for (final CommunityPostDto p in posts.items)
        PostCard(post: p, canReact: canParticipate(c, DateTime.now())),
      LoadMoreFooter(
        list: posts,
        onLoadMore: () =>
            ref.read(communityFeedProvider(_feed).notifier).loadMore(),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.community, required this.onJoin});

  final CommunityDto community;
  final Future<void> Function() onJoin;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final CommunityDto c = community;
    final String locale = Localizations.localeOf(context).toString();
    final DateTime now = DateTime.now();
    final DateTime? restricted = c.restrictedUntil;
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(c.name, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            <String>[
              communityVisibilityLabel(l10n, c.visibility.json),
              l10n.communityMemberCount(c.memberCount),
            ].join(' · '),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              if (isActiveMember(c))
                StatusLabel(
                  text: communityRoleLabel(l10n, c.myRole.json),
                  tone: StatusTone.positive,
                ),
              if (c.myStatus == CommunityDtoMyStatus.pending)
                StatusLabel(
                  text: l10n.communityMemberStatusPending,
                  tone: StatusTone.caution,
                ),
              if (c.status == CommunityDtoStatus.archived)
                StatusLabel(text: l10n.communityStatusArchived),
              if (c.status == CommunityDtoStatus.suspended)
                StatusLabel(
                  text: l10n.communityStatusSuspended,
                  tone: StatusTone.caution,
                ),
              if (c.canModerate && c.myRole == CommunityDtoMyRole.none)
                StatusLabel(text: l10n.communityStaffModerates),
            ],
          ),
          if (c.description case final String d when d.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(d),
          ],
          if (c.topics.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(l10n.communityTopicsLine(c.topics.join(', '))),
          ],
          if (c.rules case final String rules when rules.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l10n.communityRulesTitle),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[Text(rules)],
            ),
          const SizedBox(height: Insets.sm),
          if (c.status == CommunityDtoStatus.archived)
            NoticeBanner(message: l10n.communityArchivedNote)
          else if (c.status == CommunityDtoStatus.suspended)
            NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.communityErrorSuspended,
            )
          else if (restricted != null && restricted.isAfter(now))
            NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.communityErrorPostingRestrictedUntil(
                formatDateTime(restricted, locale: locale),
              ),
            )
          else
            ..._membership(context, c),
        ],
      ),
    );
  }

  List<Widget> _membership(BuildContext context, CommunityDto c) {
    final AppLocalizations l10n = context.l10n;
    return switch (c.myStatus) {
      CommunityDtoMyStatus.active => const <Widget>[],
      CommunityDtoMyStatus.pending => <Widget>[
        NoticeBanner(message: l10n.communityPendingNote),
      ],
      CommunityDtoMyStatus.banned => <Widget>[
        NoticeBanner(
          tone: NoticeTone.warning,
          message: l10n.communityBannedNote,
        ),
      ],
      _ when c.visibility == CommunityDtoVisibility.inviteOnly => <Widget>[
        NoticeBanner(message: l10n.communityErrorInvitationOnly),
      ],
      _ => <Widget>[
        if (c.visibility == CommunityDtoVisibility.private)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Text(l10n.communityAskToJoinHelp),
          ),
        SubmitButton(
          label: c.visibility == CommunityDtoVisibility.private
              ? l10n.communityAskToJoin
              : l10n.communityJoin,
          icon: Icons.group_add_outlined,
          onPressed: onJoin,
        ),
      ],
    };
  }
}

class _FeedControls extends StatelessWidget {
  const _FeedControls({
    required this.sort,
    required this.search,
    required this.query,
    required this.onSort,
    required this.onSearch,
  });

  final String sort;
  final TextEditingController search;
  final String query;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Divider(),
          SectionHeadingRow(title: l10n.communityFeedTitle),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              for (final (String value, String label) in <(String, String)>[
                ('new', l10n.communityFeedSortNew),
                ('top', l10n.communityFeedSortTop),
                ('active', l10n.communityFeedSortActive),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: sort == value,
                  onSelected: (_) => onSort(value),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: onSearch,
            decoration: InputDecoration(
              labelText: l10n.communityFeedSearchLabel,
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
          const SizedBox(height: Insets.sm),
        ],
      ),
    );
  }
}

/// A heading line used above lists.
class SectionHeadingRow extends StatelessWidget {
  /// Creates the heading.
  const SectionHeadingRow({required this.title, super.key});

  /// Heading text.
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// A post in a feed: kind and label, title, an excerpt (plain text), its
/// state for moderators and the author, comments and reactions.
class PostCard extends StatelessWidget {
  /// Creates the card.
  const PostCard({required this.post, required this.canReact, super.key});

  /// The post.
  final CommunityPostDto post;

  /// Whether the user may react.
  final bool canReact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final CommunityPostDto p = post;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      child: InkWell(
        onTap: () => context.push(AppRoutes.postDetail(p.id)),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                <String>[
                  postKindLabel(l10n, p.kind.json),
                  postLabelText(l10n, p.label.json),
                ].join(' · '),
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: Insets.xs),
              Semantics(
                header: true,
                child: Text(p.title, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: Insets.xs),
              AuthorLine(
                author: p.author,
                createdAt: p.createdAt,
                edited: p.editedAt != null,
              ),
              if (p.body.isNotEmpty) ...<Widget>[
                const SizedBox(height: Insets.sm),
                Text(p.body, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              PostStateLabels(
                pinned: p.pinned,
                locked: p.locked,
                status: p.status.json,
              ),
              const SizedBox(height: Insets.sm),
              Text(l10n.postCommentCount(p.commentCount)),
              const SizedBox(height: Insets.xs),
              ReactionBar(
                target: ReactionTarget.post,
                id: p.id,
                counts: p.reactions,
                mine: p.myReactions,
                enabled: canReact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned, locked, hidden or removed, as labels with icons.
class PostStateLabels extends StatelessWidget {
  /// Creates the labels.
  const PostStateLabels({
    required this.pinned,
    required this.locked,
    required this.status,
    super.key,
  });

  /// Pinned to the top.
  final bool pinned;

  /// Comments closed.
  final bool locked;

  /// `published`, `hidden`, `removed` or `deleted`.
  final String status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<Widget> labels = <Widget>[
      if (pinned)
        StatusLabel(text: l10n.postPinned, icon: Icons.push_pin_outlined),
      if (locked) StatusLabel(text: l10n.postLocked, icon: Icons.lock_outline),
      if (status == 'hidden')
        StatusLabel(
          text: l10n.postHidden,
          tone: StatusTone.caution,
          icon: Icons.visibility_off_outlined,
        ),
      if (status == 'removed')
        StatusLabel(text: l10n.postRemoved, tone: StatusTone.caution),
      if (status == 'deleted') StatusLabel(text: l10n.postDeleted),
    ];
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Wrap(spacing: Insets.xs, runSpacing: Insets.xs, children: labels),
    );
  }
}
