import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { communitiesApi } from '../api';
import { useCommunityError } from '../errors';
import { communitiesKeys, refreshCommunity, storeCommunity } from '../keys';
import type { Community } from '../types';

/**
 * Join, ask to join, cancel a request or leave. Leaving and cancelling are
 * confirmed; the owner hands the community over before leaving (settings).
 */
export function MembershipActions({
  community,
  reload,
}: {
  community: Community;
  reload: () => void;
}) {
  const t = useT();
  const toast = useToast();
  const navigate = useNavigate();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const [leaving, setLeaving] = useState(false);
  const [leaveError, setLeaveError] = useState<string | null>(null);

  const join = useMutation({
    mutationFn: () => communitiesApi.join(community.id),
    onSuccess: (updated) => {
      storeCommunity(queryClient, updated);
    },
    onSettled: () => refreshCommunity(queryClient, community.id),
  });
  const leave = useMutation({ mutationFn: () => communitiesApi.leave(community.id) });

  const onJoin = () => {
    if (join.isPending) return;
    join.mutate(undefined, {
      onSuccess: (updated) => {
        toast.show(
          updated.my_status === 'pending'
            ? {
                tone: 'success',
                title: t('communities.membership.requested'),
                description: t('communities.membership.requestedBody'),
              }
            : {
                tone: 'success',
                title: t('communities.membership.joined', { name: updated.name }),
              },
        );
      },
      onError: (error) => {
        if (hasErrorCode(error, 'CONFLICT')) {
          toast.show({ tone: 'info', title: t('communities.membership.alreadyJoined') });
        } else {
          toast.show({
            tone: 'danger',
            title: t('communities.membership.joinFailed'),
            description: describe(error),
          });
        }
        if (hasErrorCode(error, 'FORBIDDEN') || hasErrorCode(error, 'CONFLICT')) reload();
      },
    });
  };

  /** Non-members cannot see an invitation-only community: go to the list, then forget it. */
  const leaveInvitationOnly = async () => {
    await navigate(paths.communities, { replace: true });
    queryClient.removeQueries({
      queryKey: communitiesKeys.communities(),
      predicate: (query) => (query.state.data as Community | undefined)?.id === community.id,
    });
    await refreshCommunity(queryClient, community.id);
  };

  const pending = community.my_status === 'pending';
  const confirmLeave = () => {
    if (leave.isPending) return;
    setLeaveError(null);
    leave.mutate(undefined, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: pending
            ? t('communities.membership.cancelled')
            : t('communities.membership.left', { name: community.name }),
        });
        setLeaving(false);
        if (community.visibility === 'invite_only') {
          // Non-members cannot see an invitation-only community: go to the list first.
          void leaveInvitationOnly();
          return;
        }
        void refreshCommunity(queryClient, community.id);
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          // Already not a member (left elsewhere or the request was decided).
          setLeaving(false);
          void refreshCommunity(queryClient, community.id);
          return;
        }
        setLeaveError(describe(error));
      },
    });
  };

  let action = null;
  if (community.my_status === 'active') {
    if (community.my_role === 'owner') return null;
    action = (
      <Button
        variant="secondary"
        onClick={() => {
          setLeaveError(null);
          setLeaving(true);
        }}
      >
        <Icon name="log-out" className="size-4" />
        {t('communities.membership.leave')}
      </Button>
    );
  } else if (pending) {
    action = (
      <Button
        variant="secondary"
        onClick={() => {
          setLeaveError(null);
          setLeaving(true);
        }}
      >
        <Icon name="x" className="size-4" />
        {t('communities.membership.cancel')}
      </Button>
    );
  } else if (community.my_status !== 'banned' && community.status === 'active') {
    if (community.visibility === 'invite_only') {
      return <p className="text-sm text-fg-muted">{t('communities.membership.inviteOnly')}</p>;
    }
    action = (
      <Button loading={join.isPending} onClick={onJoin}>
        <Icon name="user-plus" className="size-4" />
        {community.visibility === 'private'
          ? t('communities.membership.ask')
          : t('communities.membership.join')}
      </Button>
    );
  }
  if (!action) return null;

  const leaveBody =
    community.visibility === 'public'
      ? t('communities.membership.leaveBodyPublic')
      : community.visibility === 'private'
        ? t('communities.membership.leaveBodyPrivate')
        : t('communities.membership.leaveBodyInvite');

  return (
    <>
      {action}
      <ConfirmDialog
        open={leaving}
        onOpenChange={setLeaving}
        title={
          pending
            ? t('communities.membership.cancelTitle')
            : t('communities.membership.leaveTitle', { name: community.name })
        }
        description={pending ? t('communities.membership.cancelBody') : leaveBody}
        confirmLabel={
          pending ? t('communities.membership.cancelConfirm') : t('communities.membership.leave')
        }
        cancelLabel={pending ? t('communities.membership.keepRequest') : undefined}
        pending={leave.isPending}
        error={leaveError}
        onConfirm={confirmLeave}
      />
    </>
  );
}
