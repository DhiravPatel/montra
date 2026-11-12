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
import { isGroupAdmin } from '../../access';
import { groupsApi, useJoinRequests } from '../../api';
import { groupErrorMessage, shouldReloadGroup } from '../../errors';
import { groupsKeys, refreshGroups } from '../../keys';
import { actionFor } from '../../people';
import type { GroupDetail, JoinRequest } from '../../types';

interface Decision {
  request: JoinRequest;
  approve: boolean;
}

/** People asking to join (owners and admins approve or decline). */
export function JoinRequestsSection({ group, reload }: { group: GroupDetail; reload: () => void }) {
  const { t, formatLocale } = useI18n();
  const me = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const admin = isGroupAdmin(group.my_role);
  const requests = useJoinRequests(group.id, admin);
  const decide = useMutation({
    mutationFn: ({ request, approve }: Decision) =>
      groupsApi.decideJoinRequest(group.id, request.id, approve),
    onSuccess: (updated) => {
      queryClient.setQueryData(groupsKeys.group(updated.id), updated);
    },
    onSettled: () => refreshGroups(queryClient),
  });

  if (!admin) return null;

  const onDecide = (decision: Decision) => {
    if (decide.isPending) return;
    decide.mutate(decision, {
      onSuccess: () => {
        toast.show({
          tone: 'success',
          title: decision.approve
            ? t('groups.requests.approved', { name: decision.request.display_name })
            : t('groups.requests.declined', { name: decision.request.display_name }),
        });
      },
      onError: (error) => {
        const handled = hasErrorCode(error, 'NOT_FOUND');
        toast.show({
          tone: handled ? 'info' : 'danger',
          title: handled ? t('groups.requests.alreadyHandled') : t('groups.requests.failed'),
          description: handled
            ? undefined
            : groupErrorMessage(error, t, {
                conflicts: { already_member: 'groups.requests.alreadyMember' },
              }),
        });
        if (shouldReloadGroup(error)) reload();
      },
    });
  };

  let content;
  if (requests.isPending) {
    content = <LoadingState label={t('groups.requests.loading')} />;
  } else if (requests.isError) {
    content = (
      <ErrorState
        titleAs="p"
        title={t('groups.requests.error')}
        error={requests.error}
        retrying={requests.isFetching}
        onRetry={() => {
          void requests.refetch();
        }}
      />
    );
  } else if (requests.data.length === 0) {
    content = <EmptyState titleAs="p" icon="inbox" title={t('groups.requests.empty')} />;
  } else {
    const active = group.status === 'active';
    content = (
      <ul className="divide-y divide-line">
        {requests.data.map((request) => {
          const when = parseTimestamp(request.created_at);
          const pending = decide.isPending && decide.variables.request.id === request.id;
          return (
            <li
              key={request.id}
              className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start"
            >
              <div className="min-w-0 flex-1 space-y-1">
                <p className="font-medium break-words text-fg">{request.display_name}</p>
                {when || request.invitation_id ? (
                  <p className="text-sm text-fg-muted">
                    {[
                      when
                        ? t('groups.requests.asked', {
                            date: formatDateTime(when, formatLocale, me.timezone),
                          })
                        : null,
                      request.invitation_id ? t('groups.requests.viaLink') : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </p>
                ) : null}
                {request.message ? (
                  <blockquote className="border-s-4 border-line ps-3 text-sm break-words whitespace-pre-line text-fg">
                    {request.message}
                  </blockquote>
                ) : null}
              </div>
              {active ? (
                <div className="flex shrink-0 gap-2">
                  <Button
                    size="sm"
                    loading={pending && decide.variables.approve}
                    disabled={pending && !decide.variables.approve}
                    aria-label={actionFor(t('groups.requests.approve'), request.display_name)}
                    onClick={() => {
                      onDecide({ request, approve: true });
                    }}
                  >
                    <Icon name="check" className="size-4" />
                    {t('groups.requests.approve')}
                  </Button>
                  <Button
                    size="sm"
                    variant="secondary"
                    loading={pending && !decide.variables.approve}
                    disabled={pending && decide.variables.approve}
                    aria-label={actionFor(t('groups.requests.decline'), request.display_name)}
                    onClick={() => {
                      onDecide({ request, approve: false });
                    }}
                  >
                    {t('groups.requests.decline')}
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
    <Card title={t('groups.requests.title')} description={t('groups.requests.description')}>
      {content}
    </Card>
  );
}
