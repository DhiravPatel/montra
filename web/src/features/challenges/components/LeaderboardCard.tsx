import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, ErrorState, LoadingState } from '@/shared/components/states';
import { useT } from '@/shared/i18n/I18nContext';
import { challengeErrorMessage, isLeaderboardNote } from '../errors';
import { useLeaderboard } from '../hooks';
import type { Challenge } from '../types';

/**
 * Participants who chose to appear, ranked by the API by percentage of the
 * target (raw values are never shown). Requested only while you appear on
 * it yourself: the leaderboard is mutual and opt-in, and the API's
 * `leaderboard_opt_in_required` answer is explained in place.
 */
export function LeaderboardCard({ challenge }: { challenge: Challenge }) {
  const t = useT();
  const board = useLeaderboard(challenge.id, true);

  let content;
  if (board.isPending) {
    content = <LoadingState label={t('challenges.leaderboard.loading')} />;
  } else if (board.isError) {
    content = isLeaderboardNote(board.error) ? (
      <Alert tone="info">{challengeErrorMessage(board.error, t)}</Alert>
    ) : (
      <ErrorState
        title={t('challenges.leaderboard.error')}
        error={board.error}
        retrying={board.isFetching}
        onRetry={() => {
          void board.refetch();
        }}
      />
    );
  } else if (board.data.length === 0) {
    content = (
      <EmptyState
        icon="users"
        title={t('challenges.leaderboard.empty.title')}
        description={t('challenges.leaderboard.empty.body')}
      />
    );
  } else {
    content = (
      <div className="overflow-x-auto">
        <table className="w-full text-start text-sm">
          <caption className="sr-only">{t('challenges.leaderboard.caption')}</caption>
          <thead>
            <tr className="border-b border-line text-fg-muted">
              <th scope="col" className="py-2 pe-3 text-start font-medium">
                {t('challenges.leaderboard.rank')}
              </th>
              <th scope="col" className="py-2 pe-3 text-start font-medium">
                {t('challenges.leaderboard.person')}
              </th>
              <th scope="col" className="py-2 pe-3 text-start font-medium">
                {t('challenges.leaderboard.progress')}
              </th>
              <th scope="col" className="py-2 text-start font-medium">
                {t('challenges.leaderboard.streak')}
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-line">
            {board.data.map((entry) => (
              <tr key={entry.rank}>
                <td className="py-3 pe-3 align-top text-fg">{entry.rank}</td>
                <th scope="row" className="py-3 pe-3 text-start align-top font-normal">
                  <span className={entry.is_me ? 'font-semibold text-fg' : 'text-fg'}>
                    {entry.display_name}
                  </span>
                  {entry.username ? (
                    <span className="block text-fg-muted">@{entry.username}</span>
                  ) : null}
                  {entry.is_me ? (
                    <span className="block text-fg-muted">{t('challenges.leaderboard.you')}</span>
                  ) : null}
                </th>
                <td className="py-3 pe-3 align-top">
                  <span className="block text-fg">
                    {t('challenges.progress.percentComplete', { percent: entry.percent_complete })}
                  </span>
                  {entry.completed ? (
                    <span className="mt-1 inline-block">
                      <StatusBadge tone="success" icon="check-circle">
                        {t('challenges.leaderboard.completed')}
                      </StatusBadge>
                    </span>
                  ) : null}
                </td>
                <td className="py-3 align-top text-fg">
                  {t('challenges.streak.days', { count: entry.current_streak })}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  }

  return (
    <Card
      title={t('challenges.leaderboard.title')}
      description={t('challenges.leaderboard.description')}
    >
      {content}
    </Card>
  );
}
