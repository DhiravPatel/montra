import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/features/communities/application/communities_providers.dart';
import 'package:montra_mobile/features/communities/data/communities_api.dart';
import 'package:montra_mobile/features/communities/domain/community_display.dart';
import 'package:montra_mobile/features/communities/presentation/community_paths.dart';
import 'package:montra_mobile/features/communities/presentation/community_screen.dart';
import 'package:montra_mobile/features/communities/presentation/community_widgets.dart';

/// A post with its threaded comments. Text is shown exactly as written
/// (plain text); a resource link opens in the browser only when it is a
/// web link. Members can vote in polls, react, comment and reply; authors
/// edit or delete their own posts and comments; moderators act on them.
class PostScreen extends ConsumerWidget {
  /// Creates the screen for [postId].
  const PostScreen({required this.postId, super.key});

  /// The post.
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CommunityPostDetail> post = ref.watch(
      postDetailProvider(postId),
    );
    final CommunityPostDetail? loaded = post.value;
    final CommunityDto? community = loaded == null
        ? null
        : ref.watch(communityProvider(loaded.communityId)).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.postTitle),
        actions: <Widget>[
          if (loaded != null)
            _PostMenu(
              post: loaded,
              canModerate: community?.canModerate ?? false,
            ),
        ],
      ),
      body: AsyncValueView<CommunityPostDetail>(
        value: post,
        onRetry: () => ref.invalidate(postDetailProvider(postId)),
        data: (CommunityPostDetail p) =>
            _PostBody(post: p, community: community),
      ),
    );
  }
}

enum _PostChoice { open, edit, delete, report, moderate }

class _PostMenu extends ConsumerWidget {
  const _PostMenu({required this.post, required this.canModerate});

  final CommunityPostDetail post;
  final bool canModerate;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.postDeleteTitle,
      body: l10n.postDeleteBody,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(communitiesApiProvider).deletePost(post.id);
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, l10n.postDeletedDone);
        router.pop();
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
    final bool published = post.status == CommunityPostDetailStatus.published;
    return PopupMenuButton<_PostChoice>(
      tooltip: l10n.actionMore,
      onSelected: (_PostChoice choice) async {
        switch (choice) {
          case _PostChoice.open:
            await context.push(AppRoutes.communityPage(post.communityId));
          case _PostChoice.edit:
            await context.push(CommunityPaths.editPost(post.id));
          case _PostChoice.delete:
            await _delete(context, ref);
          case _PostChoice.report:
            await showReportSheet(
              context,
              ref,
              kind: ReportTargetKind.post,
              targetId: post.id,
            );
          case _PostChoice.moderate:
            await moderateTarget(
              context,
              ref,
              communityId: post.communityId,
              targetType: ModerationActionInputTargetType.post,
              targetId: post.id,
              actions: actionsFor(
                ModerationActionInputTargetType.post,
                pinned: post.pinned,
                locked: post.locked,
                hidden: post.status != CommunityPostDetailStatus.published,
              ),
            );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_PostChoice>>[
        PopupMenuItem<_PostChoice>(
          value: _PostChoice.open,
          child: Text(l10n.postOpenCommunity),
        ),
        if (post.mine && published && !post.locked)
          PopupMenuItem<_PostChoice>(
            value: _PostChoice.edit,
            child: Text(l10n.actionEdit),
          ),
        if (post.mine && post.status != CommunityPostDetailStatus.deleted)
          PopupMenuItem<_PostChoice>(
            value: _PostChoice.delete,
            child: Text(l10n.actionDelete),
          ),
        if (!post.mine && published)
          PopupMenuItem<_PostChoice>(
            value: _PostChoice.report,
            child: Text(l10n.contentReportTitle),
          ),
        if (canModerate)
          PopupMenuItem<_PostChoice>(
            value: _PostChoice.moderate,
            child: Text(l10n.moderationModerate),
          ),
      ],
    );
  }
}

class _PostBody extends ConsumerStatefulWidget {
  const _PostBody({required this.post, required this.community});

  final CommunityPostDetail post;
  final CommunityDto? community;

  @override
  ConsumerState<_PostBody> createState() => _PostBodyState();
}

class _PostBodyState extends ConsumerState<_PostBody> {
  final TextEditingController _comment = TextEditingController();
  CommunityCommentDto? _replyTo;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _participate {
    final CommunityDto? c = widget.community;
    return c != null && canParticipate(c, DateTime.now());
  }

  bool get _canComment =>
      _participate &&
      !widget.post.locked &&
      widget.post.status == CommunityPostDetailStatus.published;

  Future<void> _send() async {
    final AppLocalizations l10n = context.l10n;
    final String text = _comment.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(communitiesApiProvider)
          .comment(
            widget.post.id,
            CommunityCommentInput(body: text, parentCommentId: _replyTo?.id),
          );
      ref.read(communityRevisionProvider.notifier).bump();
      if (mounted) {
        _comment.clear();
        setState(() => _replyTo = null);
        showSnack(context, l10n.commentPosted);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showSnack(context, describeError(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final CommunityPostDetail p = widget.post;
    final Uri? link = safeLink(p.linkUrl);
    final List<({CommunityCommentDto comment, int depth})> thread =
        threadComments(p.comments);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(postDetailProvider(p.id)),
      child: ListView(
        padding: const EdgeInsets.all(Insets.md),
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
            child: Text(p.title, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: Insets.sm),
          AuthorLine(
            author: p.author,
            createdAt: p.createdAt,
            edited: p.editedAt != null,
          ),
          PostStateLabels(
            pinned: p.pinned,
            locked: p.locked,
            status: p.status.json,
          ),
          if (p.removedReason case final String reason
              when reason.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.sm),
            NoticeBanner(
              tone: NoticeTone.warning,
              message: l10n.postRemovedReason(reason),
            ),
          ],
          if (p.body.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            SelectableText(p.body, style: theme.textTheme.bodyLarge),
          ],
          if (p.linkUrl case final String url when url.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            if (link != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => openCommunityLink(context, url),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.postOpenLink(link.host)),
                ),
              )
            else
              Text(l10n.communityLinkNotOpened),
          ],
          if (p.poll case final CommunityPollDto poll) ...<Widget>[
            const SizedBox(height: Insets.md),
            PollView(postId: p.id, poll: poll, canVote: _participate),
          ],
          const SizedBox(height: Insets.md),
          ReactionBar(
            target: ReactionTarget.post,
            id: p.id,
            counts: p.reactions,
            mine: p.myReactions,
            enabled: _participate,
          ),
          const Divider(height: Insets.xl),
          SectionHeadingRow(title: l10n.commentsTitle(p.commentCount)),
          const SizedBox(height: Insets.sm),
          if (_canComment)
            _CommentComposer(
              controller: _comment,
              replyTo: _replyTo,
              sending: _sending,
              onCancelReply: () => setState(() => _replyTo = null),
              onSend: _send,
            )
          else if (p.locked)
            NoticeBanner(message: l10n.communityErrorCommentsClosed)
          else if (!_participate)
            NoticeBanner(message: l10n.commentJoinToComment),
          const SizedBox(height: Insets.sm),
          if (thread.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.md),
              child: Text(l10n.commentsEmpty),
            ),
          for (final ({CommunityCommentDto comment, int depth}) item in thread)
            CommentTile(
              comment: item.comment,
              depth: item.depth,
              communityId: p.communityId,
              canModerate: widget.community?.canModerate ?? false,
              canReply: _canComment,
              canReact: _participate,
              onReply: () => setState(() => _replyTo = item.comment),
            ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.replyTo,
    required this.sending,
    required this.onCancelReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final CommunityCommentDto? replyTo;
  final bool sending;
  final VoidCallback onCancelReply;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CommunityCommentDto? to = replyTo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (to != null)
          InputChip(
            label: Text(l10n.commentReplyingTo(to.author.displayName)),
            onDeleted: onCancelReply,
            deleteButtonTooltipMessage: l10n.commentCancelReply,
          ),
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: 5,
          maxLength: CommunityCommentInput.bodyMaxLength,
          decoration: InputDecoration(
            labelText: to == null
                ? l10n.commentAddLabel
                : l10n.commentReplyLabel,
            helperText: l10n.commentPlainTextHelp,
            helperMaxLines: 2,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.send_outlined),
            label: Text(l10n.commentSend),
          ),
        ),
      ],
    );
  }
}

enum _CommentChoice { edit, delete, report, moderate }

/// One comment of a thread, indented by its depth (capped so deep replies
/// stay readable at large text sizes).
class CommentTile extends ConsumerWidget {
  /// Creates the tile.
  const CommentTile({
    required this.comment,
    required this.depth,
    required this.communityId,
    required this.canModerate,
    required this.canReply,
    required this.canReact,
    required this.onReply,
    super.key,
  });

  /// The comment.
  final CommunityCommentDto comment;

  /// Reply depth (0 = top level).
  final int depth;

  /// The community (for moderation).
  final String communityId;

  /// Whether the user moderates the community.
  final bool canModerate;

  /// Whether the user can reply.
  final bool canReply;

  /// Whether the user can react.
  final bool canReact;

  /// Starts a reply to this comment.
  final VoidCallback onReply;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _EditCommentDialog(initial: comment.body),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(communitiesApiProvider)
          .updateComment(comment.id, CommunityCommentInput(body: text.trim()));
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, l10n.commentSaved);
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showSnack(context, describeError(l10n, error));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.commentDeleteTitle,
      body: l10n.commentDeleteBody,
      confirmLabel: l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(communitiesApiProvider).deleteComment(comment.id);
      ref.read(communityRevisionProvider.notifier).bump();
      if (context.mounted) {
        showSnack(context, l10n.commentDeletedDone);
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
    final ThemeData theme = Theme.of(context);
    final CommunityCommentDto c = comment;
    final bool published = c.status == CommunityCommentDtoStatus.published;
    final bool gone =
        c.status == CommunityCommentDtoStatus.removed ||
        c.status == CommunityCommentDtoStatus.deleted;
    final double indent = (depth.clamp(0, 3)) * Insets.lg;
    final bool hasMenu = published || canModerate;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, bottom: Insets.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: depth > 0
                  ? theme.colorScheme.outlineVariant
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: Insets.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: AuthorLine(
                      author: c.author,
                      createdAt: c.createdAt,
                      edited: c.editedAt != null,
                    ),
                  ),
                  if (hasMenu)
                    PopupMenuButton<_CommentChoice>(
                      tooltip: l10n.commentActions,
                      onSelected: (_CommentChoice choice) async {
                        switch (choice) {
                          case _CommentChoice.edit:
                            await _edit(context, ref);
                          case _CommentChoice.delete:
                            await _delete(context, ref);
                          case _CommentChoice.report:
                            await showReportSheet(
                              context,
                              ref,
                              kind: ReportTargetKind.comment,
                              targetId: c.id,
                            );
                          case _CommentChoice.moderate:
                            await moderateTarget(
                              context,
                              ref,
                              communityId: communityId,
                              targetType:
                                  ModerationActionInputTargetType.comment,
                              targetId: c.id,
                              actions: actionsFor(
                                ModerationActionInputTargetType.comment,
                                hidden: !published,
                              ),
                            );
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<_CommentChoice>>[
                            if (c.mine &&
                                published) ...<PopupMenuEntry<_CommentChoice>>[
                              PopupMenuItem<_CommentChoice>(
                                value: _CommentChoice.edit,
                                child: Text(l10n.actionEdit),
                              ),
                              PopupMenuItem<_CommentChoice>(
                                value: _CommentChoice.delete,
                                child: Text(l10n.actionDelete),
                              ),
                            ],
                            if (!c.mine && published)
                              PopupMenuItem<_CommentChoice>(
                                value: _CommentChoice.report,
                                child: Text(l10n.contentReportTitle),
                              ),
                            if (canModerate)
                              PopupMenuItem<_CommentChoice>(
                                value: _CommentChoice.moderate,
                                child: Text(l10n.moderationModerate),
                              ),
                          ],
                    ),
                ],
              ),
              if (c.status == CommunityCommentDtoStatus.hidden)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.xs),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StatusLabel(
                      text: l10n.commentHiddenLabel,
                      tone: StatusTone.caution,
                      icon: Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              const SizedBox(height: Insets.xs),
              if (gone || c.body.isEmpty)
                Text(
                  c.status == CommunityCommentDtoStatus.deleted
                      ? l10n.commentDeletedText
                      : l10n.commentRemovedText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                SelectableText(c.body),
              if (published) ...<Widget>[
                const SizedBox(height: Insets.xs),
                ReactionBar(
                  target: ReactionTarget.comment,
                  id: c.id,
                  counts: c.reactions,
                  mine: c.myReactions,
                  enabled: canReact,
                ),
                if (canReply)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: onReply,
                      icon: const Icon(Icons.reply_outlined),
                      label: Text(l10n.commentReply),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initial});

  final String initial;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.commentEditTitle),
      content: TextField(
        controller: _text,
        minLines: 2,
        maxLines: 6,
        maxLength: CommunityCommentInput.bodyMaxLength,
        decoration: InputDecoration(labelText: l10n.commentAddLabel),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}
