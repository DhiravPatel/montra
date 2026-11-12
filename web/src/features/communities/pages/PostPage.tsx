import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { communityPath, paths } from '@/shared/config/paths';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useNow } from '@/shared/hooks/useNow';
import { useT } from '@/shared/i18n/I18nContext';
import { canModerate, canParticipate, isStaff } from '../access';
import { communitiesApi, useCommunity, usePost } from '../api';
import { CommentsSection } from '../components/Comments';
import { BackToCommunities, BackToCommunity } from '../components/CommunityGate';
import { CommunityNotices } from '../components/CommunityNotices';
import { type ActionTarget, ActionDialog } from '../components/moderation/ActionDialog';
import { PollView } from '../components/PollView';
import { AuthorLine, ContentNotice, PostBadges } from '../components/PostParts';
import { ReactionBar } from '../components/ReactionBar';
import { ReportDialog } from '../components/ReportDialog';
import { ResourceLink, UserText } from '../components/UserText';
import { fieldProblems, splitFieldProblems, useCommunityError } from '../errors';
import { BODY_MAX, TITLE_MAX, validatePostText, validateResourceLink } from '../text/postRules';
import { communitiesKeys, patchPost, refreshContent } from '../keys';
import type { Community, PostDetail, PostInput } from '../types';

type EditField = 'title' | 'body' | 'link';

function PostEditForm({ post, onDone }: { post: PostDetail; onDone: () => void }) {
  const t = useT();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const titleRef = useRef<HTMLInputElement>(null);
  const [title, setTitle] = useState(post.title);
  const [body, setBody] = useState(post.body);
  const [link, setLink] = useState(post.link_url ?? '');
  const [errors, setErrors] = useState<Partial<Record<EditField, string>>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const resource = post.kind === 'resource';
  const update = useMutation({
    mutationFn: (input: PostInput) => communitiesApi.updatePost(post.id, input),
  });

  useEffect(() => {
    titleRef.current?.focus();
  }, []);

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (update.isPending) return;
    setFormError(null);
    const next: Partial<Record<EditField, string>> = validatePostText(title, body, t);
    if (resource) {
      const problem = validateResourceLink(link, t);
      if (problem) next.link = problem;
    }
    setErrors(next);
    if (Object.keys(next).length > 0) return;
    // The label stays as it is (verified guidance is set by moderators).
    const input: PostInput = {
      title: title.trim(),
      body: body.trim(),
      label: post.label,
      ...(resource ? { link_url: link.trim() } : {}),
    };
    update.mutate(input, {
      onSuccess: (updated) => {
        queryClient.setQueryData<PostDetail>(communitiesKeys.post(post.id), (old) =>
          old ? { ...old, ...updated, comments: old.comments } : old,
        );
        void refreshContent(queryClient, post.community_id);
        toast.show({ tone: 'success', title: t('communities.post.updated') });
        onDone();
      },
      onError: (error) => {
        const problems = fieldProblems(error, t);
        if (problems.length > 0) {
          const { byField, rest } = splitFieldProblems(problems, {
            title: 'title',
            body: 'body',
            link_url: 'link',
          } as const);
          setErrors(byField);
          setFormError(rest.length > 0 ? rest.join(' ') : null);
          return;
        }
        setFormError(describe(error));
        if (hasErrorCode(error, 'DOMAIN_RULE_VIOLATION') || hasErrorCode(error, 'FORBIDDEN')) {
          void queryClient.invalidateQueries({ queryKey: communitiesKeys.post(post.id) });
        }
      },
    });
  };

  return (
    <form noValidate onSubmit={submit} className="space-y-5">
      <FormAlert message={formError} />
      <TextField
        ref={titleRef}
        label={t('communities.composer.postTitle')}
        maxLength={TITLE_MAX}
        autoComplete="off"
        value={title}
        error={errors.title}
        onChange={(event) => {
          setTitle(event.target.value);
        }}
      />
      {resource ? (
        <TextField
          type="url"
          label={t('communities.composer.link')}
          help={t('communities.composer.linkHelp')}
          inputMode="url"
          autoComplete="off"
          spellCheck={false}
          value={link}
          error={errors.link}
          onChange={(event) => {
            setLink(event.target.value);
          }}
        />
      ) : null}
      <TextArea
        label={t('communities.composer.body')}
        help={t('communities.composer.bodyHelp')}
        optional
        rows={6}
        maxLength={BODY_MAX}
        value={body}
        error={errors.body}
        onChange={(event) => {
          setBody(event.target.value);
        }}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="ghost" disabled={update.isPending} onClick={onDone}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={update.isPending}>
          {t('communities.post.save')}
        </Button>
      </div>
    </form>
  );
}

function PostView({ post }: { post: PostDetail }) {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const user = useCurrentUser();
  const now = useNow();
  const communityQuery = useCommunity(post.community_id);
  const community: Community | null = communityQuery.data ?? null;
  const moderator = community ? canModerate(community) : isStaff(user);
  const participate = community ? canParticipate(community, now) : false;
  const published = post.status === 'published';
  const deleted = post.status === 'deleted';
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [reporting, setReporting] = useState(false);
  const [moderating, setModerating] = useState<ActionTarget | null>(null);
  const editButton = useRef<HTMLButtonElement>(null);
  const remove = useMutation({ mutationFn: () => communitiesApi.deletePost(post.id) });

  const backToCommunity = async () => {
    await navigate(communityPath(post.community_id), { replace: true });
    queryClient.removeQueries({ queryKey: communitiesKeys.post(post.id) });
    await refreshContent(queryClient, post.community_id);
  };

  const confirmDelete = () => {
    if (remove.isPending) return;
    setDeleteError(null);
    remove.mutate(undefined, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t('communities.post.deleted') });
        setDeleting(false);
        void backToCommunity();
      },
      onError: (error) => {
        setDeleteError(describe(error));
      },
    });
  };

  const actions = (
    <>
      {post.mine && published && participate && !editing ? (
        <Button
          ref={editButton}
          variant="secondary"
          onClick={() => {
            setEditing(true);
          }}
        >
          <Icon name="pencil" className="size-4" />
          {t('communities.post.edit')}
        </Button>
      ) : null}
      {post.mine && !deleted ? (
        <Button
          variant="secondary"
          onClick={() => {
            setDeleteError(null);
            setDeleting(true);
          }}
        >
          <Icon name="trash" className="size-4" />
          {t('communities.post.delete')}
        </Button>
      ) : null}
      {!post.mine && published ? (
        <Button
          variant="secondary"
          onClick={() => {
            setReporting(true);
          }}
        >
          <Icon name="flag" className="size-4" />
          {t('communities.report.post')}
        </Button>
      ) : null}
      {moderator && !deleted ? (
        <Button
          variant="secondary"
          onClick={() => {
            setModerating({
              type: 'post',
              id: post.id,
              postId: post.id,
              summary: t('communities.mod.postSummary', { title: post.title }),
              state: {
                status: post.status,
                pinned: post.pinned,
                locked: post.locked,
                own: post.mine,
              },
            });
          }}
        >
          <Icon name="shield" className="size-4" />
          {t('communities.mod.moderate')}
        </Button>
      ) : null}
    </>
  );

  // The community decides what the viewer may do here; show the post once it is known
  // (if it cannot be loaded, the post is shown read-only).
  if (communityQuery.isPending) return <PostSkeleton />;

  return (
    <>
      {community ? <BackToCommunity community={community} /> : <BackToCommunities />}
      <PageHeader
        title={deleted ? t('communities.post.deletedTitle') : post.title}
        description={
          <AuthorLine
            author={post.author}
            createdAt={post.created_at}
            editedAt={post.edited_at}
            mine={post.mine}
          />
        }
        actions={actions}
      />
      {community ? <CommunityNotices community={community} /> : null}
      <div className="space-y-6">
        <Card>
          <article aria-label={t('communities.post.articleLabel')} className="space-y-4">
            <PostBadges post={post} />
            <ContentNotice
              status={post.status}
              reason={post.removed_reason}
              target="post"
              mine={post.mine}
            />
            {editing ? (
              <PostEditForm
                post={post}
                onDone={() => {
                  setEditing(false);
                  window.setTimeout(() => {
                    editButton.current?.focus();
                  }, 0);
                }}
              />
            ) : (
              <>
                {post.body ? <UserText text={post.body} /> : null}
                {post.kind === 'resource' ? <ResourceLink url={post.link_url} /> : null}
              </>
            )}
            {post.poll && !deleted ? (
              <PollView
                postId={post.id}
                poll={post.poll}
                canVote={participate && published}
                onVoted={(poll) => {
                  patchPost(queryClient, post.community_id, post.id, (current) => ({
                    ...current,
                    poll,
                  }));
                }}
              />
            ) : null}
            {published ? (
              <ReactionBar
                target="post"
                id={post.id}
                reactions={post.reactions}
                mine={post.my_reactions}
                canAdd={participate}
                onChange={(reactions, mine) => {
                  patchPost(queryClient, post.community_id, post.id, (current) => ({
                    ...current,
                    reactions,
                    my_reactions: mine,
                  }));
                }}
              />
            ) : null}
          </article>
        </Card>
        <Card>
          <CommentsSection
            post={post}
            community={community}
            canParticipate={participate}
            moderator={moderator}
          />
        </Card>
      </div>
      <ConfirmDialog
        open={deleting}
        onOpenChange={setDeleting}
        title={t('communities.post.deleteTitle')}
        description={t('communities.post.deleteBody')}
        confirmLabel={t('communities.post.deleteConfirm')}
        pending={remove.isPending}
        error={deleteError}
        onConfirm={confirmDelete}
      />
      <ReportDialog
        target={{ type: 'post', id: post.id }}
        open={reporting}
        onOpenChange={setReporting}
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
    </>
  );
}

function PostSkeleton() {
  const t = useT();
  return (
    <LoadingState label={t('communities.post.loading')}>
      <div className="space-y-6" aria-hidden="true">
        <Skeleton className="h-9 w-2/3" />
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    </LoadingState>
  );
}

/**
 * A community post with its poll, reactions and comments. Authors edit or
 * delete their own posts; anyone can report a post or comment; moderators
 * act on them. Text is shown as text with safe links and @mentions.
 */
export function PostPage() {
  const t = useT();
  const { postId = '' } = useParams();
  useDocumentTitle(t('communities.post.documentTitle'));
  const post = usePost(postId);

  if (post.isPending) return <PostSkeleton />;
  if (post.isError) {
    let problem;
    if (hasErrorCode(post.error, 'NOT_FOUND')) {
      problem = (
        <EmptyState
          titleAs="h2"
          icon="message-square"
          title={t('communities.post.unavailable')}
          description={t('communities.post.unavailableBody')}
          action={<ButtonLink to={paths.communities}>{t('communities.backToList')}</ButtonLink>}
        />
      );
    } else if (hasErrorCode(post.error, 'FORBIDDEN')) {
      problem = <PermissionDenied titleAs="h2" description={t('communities.post.forbidden')} />;
    } else {
      problem = (
        <ErrorState
          titleAs="h2"
          title={t('communities.post.error')}
          error={post.error}
          retrying={post.isFetching}
          onRetry={() => {
            void post.refetch();
          }}
        />
      );
    }
    return (
      <>
        <BackToCommunities />
        <PageHeader title={t('communities.post.documentTitle')} />
        {problem}
      </>
    );
  }
  return <PostView post={post.data} />;
}
