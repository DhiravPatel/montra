import type { InfiniteData, UseInfiniteQueryResult } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { ChallengeCard } from '../components/ChallengeCard';
import { useChallengeList } from '../hooks';
import type { Challenge, ChallengePage } from '../types';

type ListQuery = UseInfiniteQueryResult<InfiniteData<ChallengePage>>;

function isFinished(challenge: Challenge): boolean {
  return challenge.status !== 'active' || challenge.ended;
}

/** Challenges you take part in or created; ones you left show under "Open to join". */
function isYours(challenge: Challenge): boolean {
  return challenge.mine || (challenge.me !== undefined && challenge.me.status !== 'left');
}

/** The challenges on every loaded page, once each. */
function loaded(query: ListQuery): Challenge[] {
  const seen = new Set<string>();
  const challenges: Challenge[] = [];
  for (const page of query.data?.pages ?? []) {
    for (const challenge of page.items) {
      if (seen.has(challenge.id)) continue;
      seen.add(challenge.id);
      challenges.push(challenge);
    }
  }
  return challenges;
}

function ChallengeGrid({ challenges, today }: { challenges: Challenge[]; today: string }) {
  return (
    <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {challenges.map((challenge) => (
        <li key={challenge.id}>
          <ChallengeCard challenge={challenge} today={today} />
        </li>
      ))}
    </ul>
  );
}

/** "Load more" for the next cursor page of a list, while the API reports more. */
function LoadMore({ query }: { query: ListQuery }) {
  const t = useT();
  const announce = useAnnounce();
  if (!query.hasNextPage) return null;
  return (
    <div className="mt-6 space-y-3">
      {query.isFetchNextPageError ? (
        <p role="alert" className="flex items-start gap-1.5 text-sm text-danger">
          <Icon name="alert-circle" className="mt-0.5 size-4 shrink-0" />
          {t('challenges.list.moreFailed')}
        </p>
      ) : null}
      <div className="flex justify-center">
        <Button
          variant="secondary"
          loading={query.isFetchingNextPage}
          onClick={() => {
            if (query.isFetchingNextPage) return;
            void query.fetchNextPage().then((result) => {
              if (!result.isError) announce(t('challenges.list.moreLoaded'));
            });
          }}
        >
          <Icon name="arrow-down" className="size-4" />
          {t('challenges.list.more')}
        </Button>
      </div>
    </div>
  );
}

function ListContent({
  query,
  errorTitle,
  loadingLabel,
  children,
}: {
  query: ListQuery;
  errorTitle: string;
  loadingLabel: string;
  children: (challenges: Challenge[]) => ReactNode;
}) {
  if (query.isPending) return <LoadingState label={loadingLabel} />;
  if (query.isLoadingError) {
    return (
      <ErrorState
        title={errorTitle}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }
  return (
    <>
      {children(loaded(query))}
      <LoadMore query={query} />
    </>
  );
}

/**
 * Opt-in challenges (spec §4.16): yours, ones open to you, and past ones.
 * Progress is counted in days or check-ins, never money, and stays private
 * unless you share it. Lists load a page at a time.
 */
export function ChallengesPage() {
  const t = useT();
  useDocumentTitle(t('challenges.title'));
  const user = useCurrentUser();
  const today = todayInTimeZone(user.timezone);
  const mine = useChallengeList('mine');
  const discover = useChallengeList('discover');
  const forbidden =
    hasErrorCode(mine.error, 'FORBIDDEN') || hasErrorCode(discover.error, 'FORBIDDEN');

  const createAction = (
    <ButtonLink to={paths.challengeNew}>
      <Icon name="plus" className="size-4" />
      {t('challenges.create.action')}
    </ButtonLink>
  );

  const yours = loaded(mine).filter(isYours);
  const past = yours.filter(isFinished);

  return (
    <>
      <PageHeader
        title={t('challenges.title')}
        description={t('challenges.description')}
        actions={forbidden ? null : createAction}
      />
      {forbidden ? (
        <PermissionDenied titleAs="h2" />
      ) : (
        <div className="space-y-6">
          <Card title={t('challenges.mine.title')} description={t('challenges.mine.description')}>
            <ListContent
              query={mine}
              errorTitle={t('challenges.mine.error')}
              loadingLabel={t('challenges.mine.loading')}
            >
              {(list) => {
                const current = list.filter(
                  (challenge) => isYours(challenge) && !isFinished(challenge),
                );
                if (current.length > 0) return <ChallengeGrid challenges={current} today={today} />;
                return (
                  <EmptyState
                    icon="flag"
                    title={t('challenges.mine.empty.title')}
                    description={t('challenges.mine.empty.body')}
                    action={createAction}
                  />
                );
              }}
            </ListContent>
          </Card>
          <Card
            title={t('challenges.discover.title')}
            description={t('challenges.discover.description')}
          >
            <ListContent
              query={discover}
              errorTitle={t('challenges.discover.error')}
              loadingLabel={t('challenges.discover.loading')}
            >
              {(list) =>
                list.length > 0 ? (
                  <ChallengeGrid challenges={list} today={today} />
                ) : (
                  <EmptyState
                    icon="users"
                    title={t('challenges.discover.empty.title')}
                    description={t('challenges.discover.empty.body')}
                  />
                )
              }
            </ListContent>
          </Card>
          {past.length > 0 ? (
            <Card title={t('challenges.past.title')} description={t('challenges.past.description')}>
              <ChallengeGrid challenges={past} today={today} />
            </Card>
          ) : null}
        </div>
      )}
    </>
  );
}
