import { useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { goalEditPath, paths } from '@/shared/config/paths';
import type { GoalStatus } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { canContribute } from '../access';
import { useGoal } from '../api';
import { ContributionDialog } from '../components/ContributionDialog';
import { GoalBadges } from '../components/GoalBadges';
import { GoalContributionsCard } from '../components/GoalContributionsCard';
import { GoalDetailsCard } from '../components/GoalDetailsCard';
import { GoalForecastCard } from '../components/GoalForecastCard';
import { GoalManageCard } from '../components/GoalManageCard';
import { GoalMembersCard } from '../components/GoalMembersCard';
import { GoalProgressCard } from '../components/GoalProgressCard';
import { goalTypeName } from '../labels';

const statusNote: Readonly<Partial<Record<GoalStatus, MessageKey>>> = {
  paused: 'goals.detail.statusNote.paused',
  achieved: 'goals.detail.statusNote.achieved',
  cancelled: 'goals.detail.statusNote.cancelled',
  archived: 'goals.detail.statusNote.archived',
};

function DetailSkeleton() {
  const { t } = useI18n();
  return (
    <LoadingState label={t('goals.detail.loading')}>
      <div className="space-y-6" aria-hidden="true">
        <Skeleton className="h-9 w-1/2" />
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    </LoadingState>
  );
}

export function GoalDetailPage() {
  const { t, formatLocale } = useI18n();
  const { goalId = '' } = useParams();
  // The title never carries the goal's name (personal data).
  useDocumentTitle(t('goals.detail.documentTitle'));
  const query = useGoal(goalId);
  const [contributing, setContributing] = useState(false);

  if (query.isPending) return <DetailSkeleton />;
  if (query.isError) {
    let problem;
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      problem = (
        <EmptyState
          titleAs="h2"
          icon="target"
          title={t('goals.detail.notFound')}
          description={t('goals.detail.notFoundBody')}
          action={<ButtonLink to={paths.goals}>{t('goals.backToList')}</ButtonLink>}
        />
      );
    } else if (hasErrorCode(query.error, 'FORBIDDEN')) {
      problem = <PermissionDenied titleAs="h2" />;
    } else {
      problem = (
        <ErrorState
          titleAs="h2"
          title={t('goals.detail.error')}
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
        <p className="mb-2">
          <TextLink to={paths.goals}>
            <Icon name="arrow-left" className="me-1 inline size-4" />
            {t('goals.backToList')}
          </TextLink>
        </p>
        <PageHeader title={t('goals.detail.documentTitle')} />
        {problem}
      </>
    );
  }

  const goal = query.data;
  const owner = goal.access === 'owner';
  const allowed = canContribute(goal);
  const note = statusNote[goal.status];
  const details = [
    goalTypeName(goal.goal_type, t),
    goal.target_date
      ? t('goals.card.byDate', { date: formatLocalDate(goal.target_date, formatLocale) })
      : null,
  ].filter(Boolean);
  const openContribution = () => {
    setContributing(true);
  };

  return (
    <>
      <p className="mb-2">
        <TextLink to={paths.goals}>
          <Icon name="arrow-left" className="me-1 inline size-4" />
          {t('goals.backToList')}
        </TextLink>
      </p>
      <PageHeader
        title={goal.name}
        description={details.join(' · ')}
        actions={
          <>
            {allowed ? (
              <Button onClick={openContribution}>
                <Icon name="plus" className="size-4" />
                {t('goals.contributions.add')}
              </Button>
            ) : null}
            {owner && goal.status !== 'archived' ? (
              <ButtonLink to={goalEditPath(goal.id)} variant="secondary">
                <Icon name="pencil" className="size-4" />
                {t('goals.edit.action')}
              </ButtonLink>
            ) : null}
          </>
        }
      />
      <div className="mb-6">
        <GoalBadges goal={goal} />
      </div>
      {goal.access === 'viewer' ? (
        <Alert tone="info" className="mb-6" title={t('goals.detail.viewerTitle')}>
          {t('goals.detail.viewerBody')}
        </Alert>
      ) : null}
      {goal.access === 'contributor' ? (
        <Alert tone="info" className="mb-6" title={t('goals.detail.contributorTitle')}>
          {t('goals.detail.contributorBody')}
        </Alert>
      ) : null}
      {note ? (
        <Alert tone={goal.status === 'achieved' ? 'success' : 'info'} className="mb-6">
          {t(note)}
        </Alert>
      ) : null}
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <GoalProgressCard goal={goal} />
          <GoalForecastCard goal={goal} />
          <GoalContributionsCard goal={goal} onAdd={openContribution} />
        </div>
        <div className="space-y-6">
          <GoalDetailsCard goal={goal} />
          <GoalMembersCard goal={goal} />
          {owner ? <GoalManageCard goal={goal} /> : null}
        </div>
      </div>
      {allowed ? (
        <ContributionDialog goal={goal} open={contributing} onOpenChange={setContributing} />
      ) : null}
    </>
  );
}
