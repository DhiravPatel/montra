import type { UseInfiniteQueryResult } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon, type IconName } from '@/shared/components/Icon';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { formatDate, parseTimestamp } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { useSocialActions } from '../actions/SocialActionsContext';
import { useBlocks, useMutes } from '../hooks';
import type { BlockedPerson, MutedPerson, PeoplePage } from '../types';
import { PersonSummary } from './PersonSummary';

interface ListCopy {
  loading: MessageKey;
  error: MessageKey;
  empty: MessageKey;
  emptyBody: MessageKey;
  /** "Blocked {date}" / "Muted {date}". */
  since: MessageKey;
  loadMore: MessageKey;
  emptyIcon: IconName;
}

const blockedCopy: ListCopy = {
  loading: 'social.blocked.loading',
  error: 'social.blocked.error',
  empty: 'social.blocked.empty',
  emptyBody: 'social.blocked.emptyBody',
  since: 'social.blocked.since',
  loadMore: 'social.blocked.loadMore',
  emptyIcon: 'ban',
};

const mutedCopy: ListCopy = {
  loading: 'social.muted.loading',
  error: 'social.muted.error',
  empty: 'social.muted.empty',
  emptyBody: 'social.muted.emptyBody',
  since: 'social.muted.since',
  loadMore: 'social.muted.loadMore',
  emptyIcon: 'bell-off',
};

/**
 * A cursor list of people (GET /blocks or GET /mutes) with its loading,
 * error and empty states and a "show more" for older pages.
 */
function PeopleList<T extends BlockedPerson | MutedPerson>({
  query,
  copy,
  action,
}: {
  query: UseInfiniteQueryResult<{ pages: PeoplePage<T>[] }>;
  copy: ListCopy;
  /** The undo action for one person (unblock / unmute). */
  action: (person: T) => ReactNode;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();

  if (query.isPending) return <LoadingState label={t(copy.loading)} />;
  if (query.isLoadingError) {
    return hasErrorCode(query.error, 'FORBIDDEN') ? (
      <PermissionDenied titleAs="p" />
    ) : (
      <ErrorState
        titleAs="p"
        title={t(copy.error)}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }
  const people = query.data.pages.flatMap((page) => page.items);
  if (people.length === 0) {
    return (
      <EmptyState
        titleAs="p"
        icon={copy.emptyIcon}
        title={t(copy.empty)}
        description={t(copy.emptyBody)}
      />
    );
  }
  return (
    <div className="space-y-4">
      <ul className="divide-y divide-line">
        {people.map((person) => {
          const since = parseTimestamp(person.created_at);
          return (
            <li
              key={person.user_id}
              className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between"
            >
              <PersonSummary person={person}>
                {since ? (
                  <p className="text-sm text-fg-muted">
                    <time dateTime={person.created_at}>
                      {t(copy.since, { date: formatDate(since, formatLocale, user.timezone) })}
                    </time>
                  </p>
                ) : null}
              </PersonSummary>
              {action(person)}
            </li>
          );
        })}
      </ul>
      {query.isFetchNextPageError ? (
        <p role="alert" className="flex items-start gap-1.5 text-sm text-danger">
          <Icon name="alert-circle" className="mt-0.5 size-4 shrink-0" />
          {t('social.loadMoreFailed')}
        </p>
      ) : null}
      {query.hasNextPage ? (
        <Button
          variant="secondary"
          size="sm"
          loading={query.isFetchingNextPage}
          onClick={() => {
            void query.fetchNextPage();
          }}
        >
          {t(copy.loadMore)}
        </Button>
      ) : null}
    </div>
  );
}

/**
 * What blocking and muting do, and the people you blocked or muted (from
 * the API's own lists, newest first), with unblock and unmute.
 */
export function BlockedMutedPanel() {
  const { t } = useI18n();
  const actions = useSocialActions();
  const blocks = useBlocks();
  const mutes = useMutes();

  return (
    <>
      <Card title={t('social.blocked.title')} description={t('social.blocked.description')}>
        <PeopleList
          query={blocks}
          copy={blockedCopy}
          action={(person) => (
            <Button
              variant="secondary"
              size="sm"
              aria-label={t('social.unblock.actionFor', { name: person.display_name })}
              onClick={() => {
                actions.confirmUnblock(person);
              }}
            >
              <Icon name="undo" className="size-4" />
              {t('social.unblock.action')}
            </Button>
          )}
        />
      </Card>

      <Card title={t('social.muted.title')} description={t('social.muted.description')}>
        <PeopleList
          query={mutes}
          copy={mutedCopy}
          action={(person) => (
            <Button
              variant="secondary"
              size="sm"
              loading={actions.isMuting(person.user_id)}
              aria-label={t('social.unmute.actionFor', { name: person.display_name })}
              onClick={() => {
                actions.setMuted(person, false);
              }}
            >
              <Icon name="bell" className="size-4" />
              {t('social.unmute.action')}
            </Button>
          )}
        />
      </Card>
    </>
  );
}
