import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { groupPath } from '@/shared/config/paths';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { groupsApi, useMyInvitations } from '../api';
import { groupConflictCode, groupErrorMessage } from '../errors';
import { groupsKeys, refreshGroups } from '../keys';
import { actionFor, personName } from '../people';
import type { GroupInvitation } from '../types';

/**
 * Username invitations addressed to the user (GET /group-invitations).
 * Shown only while there is something to answer.
 */
export function InvitationsToMeCard() {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const invitations = useMyInvitations();
  const [declining, setDeclining] = useState<GroupInvitation | null>(null);
  const [declineError, setDeclineError] = useState<string | null>(null);

  const accept = useMutation({
    mutationFn: (invitation: GroupInvitation) => groupsApi.acceptInvitation(invitation.id),
  });
  const decline = useMutation({
    mutationFn: (invitation: GroupInvitation) => groupsApi.declineInvitation(invitation.id),
  });

  const forget = () => queryClient.invalidateQueries({ queryKey: groupsKeys.myInvitations() });

  const onAccept = (invitation: GroupInvitation) => {
    if (accept.isPending) return;
    accept.mutate(invitation, {
      onSuccess: (group) => {
        queryClient.setQueryData(groupsKeys.group(group.id), group);
        void refreshGroups(queryClient);
        toast.show({
          tone: 'success',
          title: t('groups.invitations.joined', { name: group.name }),
        });
        void navigate(groupPath(group.id));
      },
      onError: (error) => {
        const conflict = groupConflictCode(error);
        if (conflict === 'already_member' || (hasErrorCode(error, 'CONFLICT') && !conflict)) {
          // Already a member: the group is there already.
          void forget();
          toast.show({ tone: 'info', title: t('groups.invitations.alreadyMember') });
          void navigate(groupPath(invitation.group_id));
          return;
        }
        if (conflict === 'invitation_used') {
          void forget();
          toast.show({ tone: 'info', title: t('groups.conflict.invitation_used') });
          return;
        }
        if (hasErrorCode(error, 'GONE') || hasErrorCode(error, 'NOT_FOUND')) void forget();
        toast.show({
          tone: 'danger',
          title: t('groups.invitations.acceptFailed'),
          description: groupErrorMessage(error, t, {
            codes: {
              GONE: 'groups.invitations.gone',
              NOT_FOUND: 'groups.invitations.gone',
            },
          }),
        });
      },
    });
  };

  const confirmDecline = () => {
    if (!declining || decline.isPending) return;
    setDeclineError(null);
    decline.mutate(declining, {
      onSuccess: () => {
        void forget();
        toast.show({ tone: 'success', title: t('groups.invitations.declined') });
        setDeclining(null);
      },
      onError: (error) => {
        if (
          hasErrorCode(error, 'NOT_FOUND') ||
          hasErrorCode(error, 'GONE') ||
          groupConflictCode(error) === 'invitation_used'
        ) {
          void forget();
          toast.show({ tone: 'info', title: t('groups.invitations.gone') });
          setDeclining(null);
          return;
        }
        setDeclineError(groupErrorMessage(error, t));
      },
    });
  };

  if (invitations.isPending) {
    return (
      <Card title={t('groups.invitations.title')}>
        <LoadingState label={t('groups.invitations.loading')} />
      </Card>
    );
  }
  if (invitations.isError) {
    return (
      <Card title={t('groups.invitations.title')}>
        <ErrorState
          titleAs="p"
          title={t('groups.invitations.error')}
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
    <Card title={t('groups.invitations.title')} description={t('groups.invitations.description')}>
      <ul className="divide-y divide-line">
        {invitations.data.map((invitation) => {
          const expires = parseTimestamp(invitation.expires_at);
          const joiningThis = accept.isPending && accept.variables.id === invitation.id;
          const decliningThis = decline.isPending && decline.variables.id === invitation.id;
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
                    {t('groups.invitations.to', { name: invitation.group_name })}
                  </p>
                  {invitation.invited_by ? (
                    <p className="text-sm break-words text-fg-muted">
                      {t('groups.invitations.invitedBy', {
                        name: personName(invitation.invited_by),
                      })}
                    </p>
                  ) : null}
                  {expires ? (
                    <p className="text-sm text-fg-muted">
                      {t('groups.invitations.expires', {
                        date: formatDateTime(expires, formatLocale, user.timezone),
                      })}
                    </p>
                  ) : null}
                </div>
              </div>
              <div className="flex shrink-0 gap-2">
                <Button
                  size="sm"
                  loading={joiningThis}
                  disabled={decliningThis}
                  aria-label={actionFor(t('groups.invitations.accept'), invitation.group_name)}
                  onClick={() => {
                    onAccept(invitation);
                  }}
                >
                  <Icon name="check" className="size-4" />
                  {t('groups.invitations.accept')}
                </Button>
                <Button
                  size="sm"
                  variant="secondary"
                  disabled={joiningThis || decliningThis}
                  aria-label={actionFor(t('groups.invitations.decline'), invitation.group_name)}
                  onClick={() => {
                    setDeclineError(null);
                    setDeclining(invitation);
                  }}
                >
                  {t('groups.invitations.decline')}
                </Button>
              </div>
            </li>
          );
        })}
      </ul>
      <ConfirmDialog
        open={declining !== null}
        onOpenChange={(open) => {
          if (!open) setDeclining(null);
        }}
        title={t('groups.invitations.declineTitle')}
        description={t('groups.invitations.declineBody', { name: declining?.group_name ?? '' })}
        confirmLabel={t('groups.invitations.declineConfirm')}
        onConfirm={confirmDecline}
        pending={decline.isPending}
        error={declineError}
      />
    </Card>
  );
}
