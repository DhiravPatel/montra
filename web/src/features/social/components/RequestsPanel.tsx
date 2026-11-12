import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useSocialActions } from '../actions/SocialActionsContext';
import { useFriendRequests } from '../hooks';
import { splitRequests } from '../people';
import type { FriendRequest } from '../types';
import { PersonActionsMenu } from './PersonActionsMenu';
import { PersonSummary } from './PersonSummary';

type Direction = 'incoming' | 'outgoing';

function RequestItem({ request, direction }: { request: FriendRequest; direction: Direction }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const actions = useSocialActions();
  const person = direction === 'incoming' ? request.from : request.to;
  const name = person.display_name;
  const running = actions.respondingTo(request.id);
  const sentAt = parseTimestamp(request.created_at);
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0 space-y-2">
        <PersonSummary person={person}>
          {sentAt ? (
            <p className="text-sm text-fg-muted">
              <time dateTime={request.created_at}>
                {t('social.requests.sentOn', {
                  date: formatDate(sentAt, formatLocale, user.timezone),
                })}
              </time>
            </p>
          ) : null}
        </PersonSummary>
        {request.message ? (
          <p className="flex gap-2 text-sm text-fg">
            <Icon name="message-square" className="mt-0.5 size-4 shrink-0 text-fg-muted" />
            <span className="min-w-0 break-words">
              <span className="font-medium">{t('social.requests.note')}</span> {request.message}
            </span>
          </p>
        ) : null}
      </div>
      <div className="flex shrink-0 flex-wrap gap-2">
        {direction === 'incoming' ? (
          <>
            <Button
              size="sm"
              loading={running === 'accept'}
              disabled={running === 'decline'}
              aria-label={t('social.requests.acceptFrom', { name })}
              onClick={() => {
                actions.respond(request, 'accept');
              }}
            >
              <Icon name="check" className="size-4" />
              {t('social.requests.accept')}
            </Button>
            <Button
              variant="secondary"
              size="sm"
              loading={running === 'decline'}
              disabled={running === 'accept'}
              aria-label={t('social.requests.declineFrom', { name })}
              onClick={() => {
                actions.respond(request, 'decline');
              }}
            >
              {t('social.requests.decline')}
            </Button>
          </>
        ) : (
          <Button
            variant="secondary"
            size="sm"
            loading={running === 'cancel'}
            aria-label={t('social.requests.cancelTo', { name })}
            onClick={() => {
              actions.respond(request, 'cancel');
            }}
          >
            {t('social.requests.cancel')}
          </Button>
        )}
        <PersonActionsMenu person={person} />
      </div>
    </li>
  );
}

function RequestList({
  requests,
  direction,
}: {
  requests: readonly FriendRequest[];
  direction: Direction;
}) {
  return (
    <ul className="divide-y divide-line">
      {requests.map((request) => (
        <RequestItem key={request.id} request={request} direction={direction} />
      ))}
    </ul>
  );
}

/** Pending requests you received (accept or decline) and sent (cancel). */
export function RequestsPanel({ onFindPeople }: { onFindPeople: () => void }) {
  const { t } = useI18n();
  const user = useCurrentUser();
  const requests = useFriendRequests();

  if (requests.isPending || requests.isError) {
    return (
      <Card title={t('social.requests.title')}>
        {requests.isPending ? (
          <LoadingState label={t('social.requests.loading')} />
        ) : hasErrorCode(requests.error, 'FORBIDDEN') ? (
          <PermissionDenied />
        ) : (
          <ErrorState
            title={t('social.requests.error')}
            error={requests.error}
            retrying={requests.isFetching}
            onRetry={() => {
              void requests.refetch();
            }}
          />
        )}
      </Card>
    );
  }

  const { incoming, outgoing } = splitRequests(requests.data, user.id);
  return (
    <>
      <Card
        title={t('social.requests.incomingTitle')}
        description={t('social.requests.incomingDescription')}
      >
        {incoming.length === 0 ? (
          <EmptyState
            icon="inbox"
            title={t('social.requests.incomingEmpty')}
            description={t('social.requests.incomingEmptyBody')}
          />
        ) : (
          <RequestList requests={incoming} direction="incoming" />
        )}
      </Card>
      <Card
        title={t('social.requests.outgoingTitle')}
        description={t('social.requests.outgoingDescription')}
      >
        {outgoing.length === 0 ? (
          <EmptyState
            icon="user-plus"
            title={t('social.requests.outgoingEmpty')}
            action={
              <Button variant="secondary" onClick={onFindPeople}>
                <Icon name="search" className="size-4" />
                {t('social.friends.empty.action')}
              </Button>
            }
          />
        ) : (
          <RequestList requests={outgoing} direction="outgoing" />
        )}
      </Card>
    </>
  );
}
