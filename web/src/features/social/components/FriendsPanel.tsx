import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useT } from '@/shared/i18n/I18nContext';
import { useSocialActions } from '../actions/SocialActionsContext';
import { useFriendsList } from '../hooks';
import { PersonActionsMenu } from './PersonActionsMenu';
import { PersonSummary } from './PersonSummary';

/** Your friends (GET /connections), with remove, mute and block. */
export function FriendsPanel({ onFindPeople }: { onFindPeople: () => void }) {
  const t = useT();
  const friends = useFriendsList();
  const actions = useSocialActions();

  let content;
  if (friends.isPending) {
    content = <LoadingState label={t('social.friends.loading')} />;
  } else if (friends.isError) {
    content = hasErrorCode(friends.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('social.friends.error')}
        error={friends.error}
        retrying={friends.isFetching}
        onRetry={() => {
          void friends.refetch();
        }}
      />
    );
  } else if (friends.data.length === 0) {
    content = (
      <EmptyState
        icon="users"
        title={t('social.friends.empty.title')}
        description={t('social.friends.empty.body')}
        action={
          <Button onClick={onFindPeople}>
            <Icon name="user-plus" className="size-4" />
            {t('social.friends.empty.action')}
          </Button>
        }
      />
    );
  } else {
    content = (
      <>
        <p className="mb-4 text-sm text-fg-muted">
          {t('social.friends.count', { count: friends.data.length })}
        </p>
        <ul className="divide-y divide-line">
          {friends.data.map((friend) => (
            <li
              key={friend.user_id}
              className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between"
            >
              <PersonSummary person={friend}>
                {friend.muted ? (
                  <StatusBadge tone="neutral" icon="bell-off">
                    {t('social.muted.badge')}
                  </StatusBadge>
                ) : null}
              </PersonSummary>
              <div className="flex shrink-0 gap-2">
                <Button
                  variant="secondary"
                  size="sm"
                  aria-label={t('social.remove.actionFor', { name: friend.display_name })}
                  onClick={() => {
                    actions.confirmRemove(friend);
                  }}
                >
                  <Icon name="x" className="size-4" />
                  {t('social.remove.action')}
                </Button>
                <PersonActionsMenu person={friend} />
              </div>
            </li>
          ))}
        </ul>
      </>
    );
  }

  return (
    <Card title={t('social.friends.title')} description={t('social.friends.description')}>
      {content}
    </Card>
  );
}
