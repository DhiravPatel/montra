import { useMutation, useQueryClient } from '@tanstack/react-query';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { formatDateTime, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { communitiesApi, useCommunityMembers } from '../../api';
import { useCommunityError } from '../../errors';
import { communitiesKeys } from '../../keys';
import type { Community, CommunityMember } from '../../types';
import { PersonName } from '../PersonName';

interface Decision {
  member: CommunityMember;
  approve: boolean;
}

/**
 * People asking to join (private communities). Moderators approve or
 * decline; the person is told either way and may ask again later.
 */
export function JoinRequestsSection({ community }: { community: Community }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const describe = useCommunityError();
  const queryClient = useQueryClient();
  const requests = useCommunityMembers(community.id, 'pending');
  const decide = useMutation({
    mutationFn: ({ member, approve }: Decision) =>
      communitiesApi.decideMember(community.id, member.user_id, approve),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: communitiesKeys.membersOf(community.id) }),
        queryClient.invalidateQueries({ queryKey: communitiesKeys.communities() }),
        queryClient.invalidateQueries({ queryKey: communitiesKeys.moderation(community.id) }),
      ]),
  });

  const onDecide = (decision: Decision) => {
    if (decide.isPending) return;
    const name = decision.member.display_name;
    decide.mutate(decision, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: decision.approve
            ? t('communities.settings.requests.approved', { name })
            : t('communities.settings.requests.declined', { name }),
        });
      },
      onError: (error) => {
        const handled = hasErrorCode(error, 'NOT_FOUND');
        toast.show({
          tone: handled ? 'info' : 'danger',
          title: handled
            ? t('communities.settings.requests.alreadyHandled')
            : t('communities.settings.requests.failed'),
          description: handled ? undefined : describe(error),
        });
      },
    });
  };

  let content;
  if (requests.isPending) {
    content = <LoadingState label={t('communities.settings.requests.loading')} />;
  } else if (requests.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('communities.settings.requests.error')}
        error={requests.error}
        retrying={requests.isFetching}
        onRetry={() => {
          void requests.refetch();
        }}
      />
    );
  } else if (requests.data.length === 0) {
    content = (
      <EmptyState titleAs="p" icon="inbox" title={t('communities.settings.requests.empty')} />
    );
  } else {
    content = (
      <ul className="divide-y divide-line">
        {requests.data.map((member) => {
          const asked = parseTimestamp(member.joined_at);
          const pending = decide.isPending && decide.variables.member.user_id === member.user_id;
          const name = member.display_name;
          return (
            <li
              key={member.user_id}
              className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center"
            >
              <div className="min-w-0 flex-1 space-y-1">
                <PersonName name={name} username={member.username} />
                {asked ? (
                  <p className="text-sm text-fg-muted">
                    {t('communities.settings.requests.asked', {
                      date: formatDateTime(asked, formatLocale, user.timezone),
                    })}
                  </p>
                ) : null}
              </div>
              {community.status === 'active' ? (
                <div className="flex shrink-0 gap-2">
                  <Button
                    size="sm"
                    loading={pending && decide.variables.approve}
                    disabled={pending && !decide.variables.approve}
                    aria-label={t('communities.settings.requests.approveNamed', { name })}
                    onClick={() => {
                      onDecide({ member, approve: true });
                    }}
                  >
                    <Icon name="check" className="size-4" />
                    {t('communities.settings.requests.approve')}
                  </Button>
                  <Button
                    size="sm"
                    variant="secondary"
                    loading={pending && !decide.variables.approve}
                    disabled={pending && decide.variables.approve}
                    aria-label={t('communities.settings.requests.declineNamed', { name })}
                    onClick={() => {
                      onDecide({ member, approve: false });
                    }}
                  >
                    {t('communities.settings.requests.decline')}
                  </Button>
                </div>
              ) : null}
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <Card
      title={t('communities.settings.requests.title')}
      description={t('communities.settings.requests.description')}
    >
      {content}
    </Card>
  );
}
