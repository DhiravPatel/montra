import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useNow } from '@/shared/hooks/useNow';
import { useT } from '@/shared/i18n/I18nContext';
import { MyActionsList } from '../components/MyActionsList';
import { MyAppealsList } from '../components/MyAppealsList';
import { MyReportsList } from '../components/MyReportsList';
import { StandingCard } from '../components/StandingCard';
import { useMyAppeals, useMyModeration, useMyReports } from '../hooks';
import { APPEAL_WINDOW_DAYS } from '../standing';

/**
 * Your moderation (Settings → Moderation): where you stand, decisions that
 * affected your posts, comments or account (with a review request until
 * the API's `appeal_until`, and the review's state and outcome), the
 * reviews you asked for, and the reports you filed.
 */
export function MyModerationPage() {
  const t = useT();
  useDocumentTitle(t('moderation.my.title'));
  const user = useCurrentUser();
  const now = useNow();
  const actions = useMyModeration();
  const reports = useMyReports();
  const appeals = useMyAppeals();
  const forbidden =
    hasErrorCode(actions.error, 'FORBIDDEN') || hasErrorCode(reports.error, 'FORBIDDEN');

  let decisions;
  if (actions.isPending) {
    decisions = <LoadingState label={t('moderation.mine.loading')} />;
  } else if (actions.isError) {
    decisions = (
      <ErrorState
        title={t('moderation.mine.error')}
        error={actions.error}
        retrying={actions.isFetching}
        onRetry={() => {
          void actions.refetch();
        }}
      />
    );
  } else if (actions.data.length === 0) {
    decisions = (
      <EmptyState
        icon="shield-check"
        title={t('moderation.mine.empty.title')}
        description={t('moderation.mine.empty.body')}
      />
    );
  } else {
    decisions = <MyActionsList actions={actions.data} now={now} timeZone={user.timezone} />;
  }

  let reviews;
  if (appeals.isPending) {
    reviews = <LoadingState label={t('moderation.appeals.loading')} />;
  } else if (appeals.isError) {
    reviews = (
      <ErrorState
        title={t('moderation.appeals.error')}
        error={appeals.error}
        retrying={appeals.isFetching}
        onRetry={() => {
          void appeals.refetch();
        }}
      />
    );
  } else if (appeals.data.length === 0) {
    reviews = (
      <EmptyState
        icon="message-square"
        title={t('moderation.appeals.empty.title')}
        description={t('moderation.appeals.empty.body')}
      />
    );
  } else {
    reviews = <MyAppealsList appeals={appeals.data} timeZone={user.timezone} />;
  }

  let filed;
  if (reports.isPending) {
    filed = <LoadingState label={t('moderation.reports.loading')} />;
  } else if (reports.isError) {
    filed = (
      <ErrorState
        title={t('moderation.reports.error')}
        error={reports.error}
        retrying={reports.isFetching}
        onRetry={() => {
          void reports.refetch();
        }}
      />
    );
  } else if (reports.data.length === 0) {
    filed = (
      <EmptyState
        icon="flag"
        title={t('moderation.reports.empty.title')}
        description={t('moderation.reports.empty.body')}
      />
    );
  } else {
    filed = <MyReportsList reports={reports.data} timeZone={user.timezone} />;
  }

  return (
    <>
      <PageHeader title={t('moderation.my.title')} description={t('moderation.my.description')} />
      {forbidden ? (
        <PermissionDenied titleAs="h2" />
      ) : (
        <div className="space-y-6">
          {actions.isSuccess ? (
            <StandingCard actions={actions.data} now={now} timeZone={user.timezone} />
          ) : null}
          <Card
            title={t('moderation.mine.title')}
            description={t('moderation.mine.description', { days: APPEAL_WINDOW_DAYS })}
          >
            {decisions}
          </Card>
          <Card
            title={t('moderation.appeals.title')}
            description={t('moderation.appeals.description')}
          >
            {reviews}
          </Card>
          <Card
            title={t('moderation.reports.title')}
            description={t('moderation.reports.description')}
          >
            {filed}
          </Card>
        </div>
      )}
    </>
  );
}
