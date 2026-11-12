import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { communityPath } from '@/shared/config/paths';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { communitiesApi, useInvitationsToMe } from '../api';
import { conflictCode, useCommunityError } from '../errors';
import { communitiesKeys, refreshCommunity, storeCommunity } from '../keys';
import type { CommunityInvitation } from '../types';

/**
 * Invitations addressed to you by username (GET /community-invitations),
 * with who sent them. Shown only while there is something to answer: join,
 * or decline (the person who invited you is not told why).
 */
export function InvitationsToYouCard() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const invitations = useInvitationsToMe();
  const accept = useMutation({
    mutationFn: (invitation: CommunityInvitation) => communitiesApi.acceptInvitation(invitation.id),
  });
  const decline = useMutation({
    mutationFn: (invitation: CommunityInvitation) =>
      communitiesApi.declineInvitation(invitation.id),
  });
  const busy = accept.isPending || decline.isPending;

  const forget = () =>
    queryClient.invalidateQueries({ queryKey: communitiesKeys.invitationsToMe() });

  const onAccept = (invitation: CommunityInvitation) => {
    if (busy) return;
    accept.mutate(invitation, {
      onSuccess: (community) => {
        storeCommunity(queryClient, community);
        void refreshCommunity(queryClient, community.id);
        toast.show({
          tone: 'success',
          title: t('communities.membership.joined', { name: community.name }),
        });
        void navigate(communityPath(community.id));
      },
      onError: (error) => {
        if (hasErrorCode(error, 'CONFLICT')) {
          void forget();
          toast.show({ tone: 'info', title: t('communities.invitations.alreadyMember') });
          void navigate(communityPath(invitation.community_id));
          return;
        }
        if (hasErrorCode(error, 'GONE') || hasErrorCode(error, 'NOT_FOUND')) void forget();
        toast.show({
          tone: 'danger',
          title: t('communities.invitations.acceptFailed'),
          description: describe(error, {
            codes: {
              GONE: 'communities.invitations.gone',
              NOT_FOUND: 'communities.invitations.gone',
            },
          }),
        });
      },
    });
  };

  const onDecline = (invitation: CommunityInvitation) => {
    if (busy) return;
    decline.mutate(invitation, {
      onSuccess: () => {
        void forget();
        toast.show({ tone: 'success', title: t('communities.invitations.declined') });
      },
      onError: (error) => {
        // Already declined or answered: nothing left to do here.
        if (conflictCode(error) === 'invitation_used' || hasErrorCode(error, 'NOT_FOUND')) {
          void forget();
          toast.show({ tone: 'info', title: t('communities.invitations.alreadyAnswered') });
          return;
        }
        if (hasErrorCode(error, 'GONE')) void forget();
        toast.show({
          tone: 'danger',
          title: t('communities.invitations.declineFailed'),
          description: describe(error, { codes: { GONE: 'communities.invitations.gone' } }),
        });
      },
    });
  };

  if (invitations.isPending) {
    return (
      <Card title={t('communities.invitations.title')}>
        <LoadingState label={t('communities.invitations.loading')} />
      </Card>
    );
  }
  if (invitations.isError) {
    return (
      <Card title={t('communities.invitations.title')}>
        <ErrorState
          titleAs="p"
          title={t('communities.invitations.error')}
          error={invitations.error}
          retrying={invitations.isFetching}
          onRetry={() => {
            void invitations.refetch();
          }}
        />
      </Card>
    );
  }
  if (invitations.data.length === 0) return null;

  return (
    <Card
      title={t('communities.invitations.title')}
      description={t('communities.invitations.description')}
    >
      <ul className="divide-y divide-line">
        {invitations.data.map((invitation) => {
          const expires = parseTimestamp(invitation.expires_at);
          const name = invitation.community_name || t('communities.invitations.unnamed');
          const joining = accept.isPending && accept.variables.id === invitation.id;
          const declining = decline.isPending && decline.variables.id === invitation.id;
          const inviter = invitation.invited_by;
          return (
            <li
              key={invitation.id}
              className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
            >
              <div className="flex min-w-0 flex-1 gap-3">
                <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-surface-muted text-fg-muted">
                  <Icon name="mail" />
                </span>
                <div className="min-w-0 space-y-1">
                  <p className="font-medium break-words text-fg">
                    {t('communities.invitations.to', { name })}
                  </p>
                  {inviter ? (
                    <p className="text-sm break-words text-fg-muted">
                      {t('communities.invitations.from', {
                        name: inviter.username
                          ? `${inviter.display_name} (@${inviter.username})`
                          : inviter.display_name,
                      })}
                    </p>
                  ) : null}
                  {expires ? (
                    <p className="text-sm text-fg-muted">
                      {t('communities.invitations.expires', {
                        date: formatDateTime(expires, formatLocale, user.timezone),
                      })}
                    </p>
                  ) : null}
                </div>
              </div>
              <div className="flex shrink-0 flex-wrap gap-2">
                <Button
                  size="sm"
                  loading={joining}
                  disabled={busy && !joining}
                  aria-label={t('communities.invitations.acceptNamed', { name })}
                  onClick={() => {
                    onAccept(invitation);
                  }}
                >
                  <Icon name="check" className="size-4" />
                  {t('communities.invitations.accept')}
                </Button>
                <Button
                  size="sm"
                  variant="secondary"
                  loading={declining}
                  disabled={busy && !declining}
                  aria-label={t('communities.invitations.declineNamed', { name })}
                  onClick={() => {
                    onDecline(invitation);
                  }}
                >
                  {t('communities.invitations.decline')}
                </Button>
              </div>
            </li>
          );
        })}
      </ul>
    </Card>
  );
}
