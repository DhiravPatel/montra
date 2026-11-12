import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useEffect, useId, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { EmptyState } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { useToast } from '@/shared/components/toast/ToastContext';
import { communityPath } from '@/shared/config/paths';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useT } from '@/shared/i18n/I18nContext';
import type { Translate } from '@/shared/i18n/types';
import { cx } from '@/shared/utils/cx';
import { communitiesApi } from '../api';
import { fieldProblems, useCommunityError } from '../errors';
import { communitiesKeys, patchComment, refreshContent } from '../keys';
import { countLinks, excerpt, looksSecret } from '../text/userText';
import type { Community, PostComment, PostDetail } from '../types';
import { type ActionTarget, ActionDialog } from './moderation/ActionDialog';
import { AuthorLine, ContentNotice } from './PostParts';
import { ReactionBar } from './ReactionBar';
import { ReportDialog } from './ReportDialog';
import { UserText } from './UserText';

const COMMENT_MAX = 4000;
const MAX_LINKS = 3;
/** Deeper replies keep the indentation of this level. */
const MAX_INDENT = 3;

function validateComment(text: string, t: Translate): string | null {
  const body = text.trim();
  if (!body) return t('communities.comments.required');
  if (Array.from(body).length > COMMENT_MAX) return t('validation.maxLength', { max: COMMENT_MAX });
  if (countLinks(body) > MAX_LINKS) return t('communities.field.links');
  if (looksSecret(body)) return t('communities.field.secret');
  return null;
}

interface Tree {
  roots: PostComment[];
  replies: ReadonlyMap<string, PostComment[]>;
}

/** Comments arrive flat, oldest first; replies carry `parent_comment_id`. */
function buildTree(comments: readonly PostComment[]): Tree {
  const ids = new Set(comments.map((comment) => comment.id));
  const replies = new Map<string, PostComment[]>();
  const roots: PostComment[] = [];
  for (const comment of comments) {
    const parent = comment.parent_comment_id;
    if (parent && parent !== comment.id && ids.has(parent)) {
      const list = replies.get(parent) ?? [];
      list.push(comment);
      replies.set(parent, list);
    } else {
      roots.push(comment);
    }
  }
  return { roots, replies };
}

/** Writes a comment or a reply (plain text, checked like the API does). */
function CommentForm({
  postId,
  communityId,
  parent,
  onDone,
}: {
  postId: string;
  communityId: string;
  /** Replying to this comment; a top-level comment when absent. */
  parent?: PostComment;
  onDone?: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const fieldRef = useRef<HTMLTextAreaElement>(null);
  const [text, setText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const add = useMutation({
    mutationFn: (body: string) => communitiesApi.addComment(postId, body, parent?.id),
    onSuccess: () => refreshContent(queryClient, communityId, postId),
  });

  // Focus the reply field when it opens (not again when the post refreshes).
  const replyingTo = parent?.id;
  useEffect(() => {
    if (replyingTo) fieldRef.current?.focus();
  }, [replyingTo]);

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (add.isPending) return;
    setFormError(null);
    const problem = validateComment(text, t);
    setError(problem);
    if (problem) return;
    add.mutate(text.trim(), {
      onSuccess: () => {
        setText('');
        toast.show({
          tone: 'success',
          title: parent ? t('communities.comments.replied') : t('communities.comments.posted'),
        });
        onDone?.();
      },
      onError: (failure) => {
        const forBody = fieldProblems(failure, t).find((item) => item.field === 'body');
        if (forBody) {
          setError(forBody.message);
          return;
        }
        setFormError(
          describe(failure, {
            codes: {
              CONFLICT: 'communities.comments.duplicate',
              NOT_FOUND: 'communities.comments.postGone',
            },
          }),
        );
      },
    });
  };

  return (
    <form noValidate onSubmit={submit} className="space-y-3">
      <FormAlert message={formError} />
      <TextArea
        ref={fieldRef}
        label={
          parent
            ? t('communities.comments.replyLabel', { name: parent.author.display_name })
            : t('communities.comments.label')
        }
        help={t('communities.comments.help')}
        rows={parent ? 3 : 4}
        maxLength={COMMENT_MAX}
        value={text}
        error={error ?? undefined}
        onChange={(event) => {
          setText(event.target.value);
        }}
      />
      <div className="flex flex-wrap gap-3">
        <Button type="submit" size="sm" loading={add.isPending}>
          <Icon name="message-square" className="size-4" />
          {parent ? t('communities.comments.replySubmit') : t('communities.comments.submit')}
        </Button>
        {onDone ? (
          <Button size="sm" variant="ghost" disabled={add.isPending} onClick={onDone}>
            {t('common.cancel')}
          </Button>
        ) : null}
      </div>
    </form>
  );
}

function CommentEditForm({
  comment,
  postId,
  onDone,
}: {
  comment: PostComment;
  postId: string;
  onDone: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const fieldRef = useRef<HTMLTextAreaElement>(null);
  const [text, setText] = useState(comment.body);
  const [error, setError] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const update = useMutation({
    mutationFn: (body: string) => communitiesApi.updateComment(comment.id, body),
  });

  useEffect(() => {
    fieldRef.current?.focus();
  }, []);

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (update.isPending) return;
    setFormError(null);
    const problem = validateComment(text, t);
    setError(problem);
    if (problem) return;
    update.mutate(text.trim(), {
      onSuccess: (updated) => {
        patchComment(queryClient, postId, comment.id, () => updated);
        toast.show({ tone: 'success', title: t('communities.comments.updated') });
        onDone();
      },
      onError: (failure) => {
        const forBody = fieldProblems(failure, t).find((item) => item.field === 'body');
        if (forBody) {
          setError(forBody.message);
          return;
        }
        setFormError(describe(failure));
        if (hasErrorCode(failure, 'NOT_FOUND') || hasErrorCode(failure, 'DOMAIN_RULE_VIOLATION')) {
          void queryClient.invalidateQueries({ queryKey: communitiesKeys.post(postId) });
        }
      },
    });
  };

  return (
    <form noValidate onSubmit={submit} className="space-y-3">
      <FormAlert message={formError} />
      <TextArea
        ref={fieldRef}
        label={t('communities.comments.editLabel')}
        rows={3}
        maxLength={COMMENT_MAX}
        value={text}
        error={error ?? undefined}
        onChange={(event) => {
          setText(event.target.value);
        }}
      />
      <div className="flex flex-wrap gap-3">
        <Button type="submit" size="sm" loading={update.isPending}>
          {t('common.save')}
        </Button>
        <Button size="sm" variant="ghost" disabled={update.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
      </div>
    </form>
  );
}

interface CommentHandlers {
  postId: string;
  communityId: string;
  canComment: boolean;
  canReact: boolean;
  moderator: boolean;
  replyingTo: string | null;
  editing: string | null;
  setReplyingTo: (id: string | null) => void;
  setEditing: (id: string | null) => void;
  onDelete: (comment: PostComment) => void;
  onReport: (comment: PostComment) => void;
  onModerate: (comment: PostComment) => void;
}

function CommentItem({
  comment,
  tree,
  depth,
  handlers,
}: {
  comment: PostComment;
  tree: Tree;
  depth: number;
  handlers: CommentHandlers;
}) {
  const t = useT();
  const queryClient = useQueryClient();
  const replyButtonId = useId();
  const published = comment.status === 'published';
  const name = comment.author.display_name;
  const children = tree.replies.get(comment.id) ?? [];
  const editing = handlers.editing === comment.id;
  const replying = handlers.replyingTo === comment.id;

  return (
    <li>
      <article aria-label={t('communities.comments.by', { name })} className="space-y-2 py-4">
        <AuthorLine
          author={comment.author}
          createdAt={comment.created_at}
          editedAt={comment.edited_at}
          mine={comment.mine}
        />
        <ContentNotice status={comment.status} target="comment" mine={comment.mine} />
        {editing ? (
          <CommentEditForm
            comment={comment}
            postId={handlers.postId}
            onDone={() => {
              handlers.setEditing(null);
            }}
          />
        ) : comment.body ? (
          <UserText text={comment.body} />
        ) : null}
        {published && !editing ? (
          <div className="flex flex-wrap items-center gap-2">
            <ReactionBar
              target="comment"
              id={comment.id}
              reactions={comment.reactions}
              mine={comment.my_reactions}
              canAdd={handlers.canReact}
              onChange={(reactions, mine) => {
                patchComment(queryClient, handlers.postId, comment.id, (current) => ({
                  ...current,
                  reactions,
                  my_reactions: mine,
                }));
              }}
            />
            {handlers.canComment ? (
              <Button
                id={replyButtonId}
                size="sm"
                variant="ghost"
                aria-expanded={replying}
                aria-label={t('communities.comments.replyTo', { name })}
                onClick={() => {
                  handlers.setReplyingTo(replying ? null : comment.id);
                }}
              >
                <Icon name="message-square" className="size-4" />
                {t('communities.comments.reply')}
              </Button>
            ) : null}
            {comment.mine && handlers.canReact ? (
              <Button
                size="sm"
                variant="ghost"
                aria-label={t('communities.comments.editMine')}
                onClick={() => {
                  handlers.setEditing(comment.id);
                }}
              >
                <Icon name="pencil" className="size-4" />
                {t('common.edit')}
              </Button>
            ) : null}
            {comment.mine ? (
              <Button
                size="sm"
                variant="ghost"
                aria-label={t('communities.comments.deleteMine')}
                onClick={() => {
                  handlers.onDelete(comment);
                }}
              >
                <Icon name="trash" className="size-4" />
                {t('common.delete')}
              </Button>
            ) : (
              <Button
                size="sm"
                variant="ghost"
                aria-label={t('communities.report.actionComment', { name })}
                onClick={() => {
                  handlers.onReport(comment);
                }}
              >
                <Icon name="flag" className="size-4" />
                {t('communities.report.action')}
              </Button>
            )}
            {handlers.moderator && !comment.mine ? (
              <Button
                size="sm"
                variant="ghost"
                aria-label={t('communities.mod.moderateComment', { name })}
                onClick={() => {
                  handlers.onModerate(comment);
                }}
              >
                <Icon name="shield" className="size-4" />
                {t('communities.mod.moderate')}
              </Button>
            ) : null}
          </div>
        ) : null}
        {!published && handlers.moderator && !comment.mine && comment.status !== 'deleted' ? (
          <Button
            size="sm"
            variant="ghost"
            aria-label={t('communities.mod.moderateComment', { name })}
            onClick={() => {
              handlers.onModerate(comment);
            }}
          >
            <Icon name="shield" className="size-4" />
            {t('communities.mod.moderate')}
          </Button>
        ) : null}
        {replying ? (
          <div className="border-s-4 border-line ps-4">
            <CommentForm
              postId={handlers.postId}
              communityId={handlers.communityId}
              parent={comment}
              onDone={() => {
                handlers.setReplyingTo(null);
                window.setTimeout(() => {
                  document.getElementById(replyButtonId)?.focus();
                }, 0);
              }}
            />
          </div>
        ) : null}
      </article>
      {children.length > 0 ? (
        <ul
          aria-label={t('communities.comments.replies', { name })}
          className={cx(
            'divide-y divide-line border-s-2 border-line',
            depth < MAX_INDENT ? 'ms-2 ps-4 sm:ms-4' : 'ps-3',
          )}
        >
          {children.map((child) => (
            <CommentItem
              key={child.id}
              comment={child}
              tree={tree}
              depth={depth + 1}
              handlers={handlers}
            />
          ))}
        </ul>
      ) : null}
    </li>
  );
}

/**
 * Comments and replies on a post, with reactions, Reply, Edit and Delete
 * for your own, Report for others' and Moderate for moderators. Removed
 * and deleted comments keep their place in the thread without their text.
 */
export function CommentsSection({
  post,
  community,
  canParticipate,
  moderator,
}: {
  post: PostDetail;
  community: Community | null;
  canParticipate: boolean;
  moderator: boolean;
}) {
  const t = useT();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const headingId = useId();
  const tree = useMemo(() => buildTree(post.comments), [post.comments]);
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [editing, setEditing] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<PostComment | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [reporting, setReporting] = useState<PostComment | null>(null);
  const [moderating, setModerating] = useState<ActionTarget | null>(null);
  const remove = useMutation({
    mutationFn: (comment: PostComment) => communitiesApi.deleteComment(comment.id),
    onSettled: () => refreshContent(queryClient, post.community_id, post.id),
  });

  const open = post.status === 'published' && !post.locked;
  const canComment = canParticipate && open;

  const confirmDelete = () => {
    if (!deleting || remove.isPending) return;
    setDeleteError(null);
    remove.mutate(deleting, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('communities.comments.deleted') });
        setDeleting(null);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          setDeleting(null);
          return;
        }
        setDeleteError(describe(error));
      },
    });
  };

  const handlers: CommentHandlers = {
    postId: post.id,
    communityId: post.community_id,
    canComment,
    canReact: canParticipate,
    moderator,
    replyingTo,
    editing,
    setReplyingTo: (id) => {
      setEditing(null);
      setReplyingTo(id);
    },
    setEditing: (id) => {
      setReplyingTo(null);
      setEditing(id);
    },
    onDelete: (comment) => {
      setDeleteError(null);
      setDeleting(comment);
    },
    onReport: setReporting,
    onModerate: (comment) => {
      setModerating({
        type: 'comment',
        id: comment.id,
        postId: post.id,
        summary: comment.body
          ? t('communities.mod.commentSummary', {
              name: comment.author.display_name,
              text: excerpt(comment.body.replace(/\s+/gu, ' '), 140),
            })
          : t('communities.mod.commentSummaryEmpty', { name: comment.author.display_name }),
        state: { status: comment.status },
      });
    },
  };

  let notice = null;
  if (post.status === 'published') {
    if (post.locked) {
      notice = (
        <Alert tone="neutral" title={t('communities.comments.closed')}>
          {t('communities.comments.closedBody')}
        </Alert>
      );
    } else if (community && community.my_status !== 'active' && community.status === 'active') {
      notice = (
        <p className="text-sm text-fg-muted">
          {t('communities.comments.joinToComment')}{' '}
          <Link
            to={communityPath(community.id)}
            className="font-medium text-accent underline decoration-1 underline-offset-4 hover:text-accent-hover"
          >
            {t('communities.comments.goToCommunity')}
          </Link>
        </p>
      );
    }
  }

  return (
    <section aria-labelledby={headingId} className="space-y-4">
      <h2 id={headingId} className="text-lg font-semibold text-fg">
        {t('communities.comments.title', { count: post.comment_count })}
      </h2>
      {canComment ? <CommentForm postId={post.id} communityId={post.community_id} /> : notice}
      {tree.roots.length === 0 ? (
        <EmptyState
          titleAs="p"
          icon="message-square"
          title={t('communities.comments.empty')}
          description={canComment ? t('communities.comments.emptyBody') : undefined}
        />
      ) : (
        <ul className="divide-y divide-line">
          {tree.roots.map((comment) => (
            <CommentItem
              key={comment.id}
              comment={comment}
              tree={tree}
              depth={0}
              handlers={handlers}
            />
          ))}
        </ul>
      )}
      <ConfirmDialog
        open={deleting !== null}
        onOpenChange={(next) => {
          if (!next) setDeleting(null);
        }}
        title={t('communities.comments.deleteTitle')}
        description={t('communities.comments.deleteBody')}
        confirmLabel={t('communities.comments.deleteConfirm')}
        pending={remove.isPending}
        error={deleteError}
        onConfirm={confirmDelete}
      />
      <ReportDialog
        target={reporting ? { type: 'comment', id: reporting.id } : null}
        open={reporting !== null}
        onOpenChange={(next) => {
          if (!next) setReporting(null);
        }}
      />
      {moderator ? (
        <ActionDialog
          communityId={post.community_id}
          target={moderating}
          open={moderating !== null}
          onOpenChange={(next) => {
            if (!next) setModerating(null);
          }}
        />
      ) : null}
    </section>
  );
}
