import { useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { type GoalStatusFilter, useGoalReport, useGoals } from '../api';
import { GoalCard } from '../components/GoalCard';
import { GOAL_STATUS_FILTERS, goalFilterLabel, isGoalStatusFilter } from '../labels';
import { HelpGuideLink } from '@/shared/help/HelpGuideLink';

/** Saved and target per currency (the API never adds currencies together). */
function GoalTotals() {
  const t = useT();
  const formatMoney = useFormatMoney();
  const report = useGoalReport();
  if (report.isPending) return null;
  if (report.isError) {
    return (
      <div
        role="status"
        className="mb-6 flex flex-wrap items-center gap-3 rounded-lg border border-line bg-surface-muted px-4 py-3 text-sm text-fg-muted"
      >
        <Icon name="info" className="size-4" />
        <span className="flex-1">{t('goals.totals.error')}</span>
        <Button
          variant="ghost"
          size="sm"
          loading={report.isFetching}
          onClick={() => {
            void report.refetch();
          }}
        >
          {t('common.retry')}
        </Button>
      </div>
    );
  }
  const totals = report.data.totals;
  if (totals.length === 0) return null;
  return (
    <Card
      title={t('goals.totals.title')}
      description={t('goals.totals.description')}
      className="mb-6"
    >
      <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {totals.map((total) => (
          <li key={total.currency} className="space-y-1 rounded-lg bg-surface-muted p-4">
            <p className="text-sm font-medium text-fg-muted">{total.currency}</p>
            <p className="text-lg font-semibold text-fg">
              {t('goals.totals.line', {
                saved: formatMoney(total.saved),
                target: formatMoney(total.target),
              })}
            </p>
            <p className="text-sm text-fg-muted">
              {[
                t('goals.totals.count', { count: total.count }),
                t('goals.totals.achieved', { count: total.achieved }),
              ].join(' · ')}
            </p>
          </li>
        ))}
      </ul>
    </Card>
  );
}

export function GoalsPage() {
  const t = useT();
  useDocumentTitle(t('goals.title'));
  const [searchParams, setSearchParams] = useSearchParams();
  const requested = searchParams.get('status');
  const status: GoalStatusFilter = isGoalStatusFilter(requested) ? requested : 'active';
  const goals = useGoals(status);

  const addButton = (
    <ButtonLink to={paths.goalNew}>
      <Icon name="plus" className="size-4" />
      {t('goals.add')}
    </ButtonLink>
  );

  let content;
  if (goals.isPending) {
    content = <LoadingState label={t('goals.list.loading')} />;
  } else if (goals.isError) {
    content = hasErrorCode(goals.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('goals.list.error')}
        error={goals.error}
        retrying={goals.isFetching}
        onRetry={() => {
          void goals.refetch();
        }}
      />
    );
  } else if (goals.data.length === 0) {
    content =
      status === 'active' || status === 'all' ? (
        <EmptyState
          icon="target"
          title={t('goals.empty.title')}
          description={t('goals.empty.body')}
          action={
            <ButtonLink to={paths.goalNew}>
              <Icon name="plus" className="size-4" />
              {t('goals.empty.action')}
            </ButtonLink>
          }
        />
      ) : (
        <EmptyState
          icon="target"
          title={t('goals.empty.filtered')}
          description={t('goals.empty.filteredBody')}
        />
      );
  } else {
    content = (
      <ul className="grid gap-4 md:grid-cols-2">
        {goals.data.map((goal) => (
          <li key={goal.id}>
            <GoalCard goal={goal} />
          </li>
        ))}
      </ul>
    );
  }

  return (
    <>
      <PageHeader
        help={<HelpGuideLink guide="goals" />}
        title={t('goals.title')}
        description={t('goals.description')}
        actions={addButton}
      />
      <GoalTotals />
      <section aria-labelledby="goals-list-heading" className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <h2 id="goals-list-heading" className="text-lg font-semibold text-fg">
            {t('goals.list.heading')}
          </h2>
          <Select
            label={t('goals.list.filter')}
            className="w-full sm:w-56"
            value={status}
            options={GOAL_STATUS_FILTERS.map((value) => ({
              value,
              label: t(goalFilterLabel[value]),
            }))}
            onChange={(event) => {
              const next = event.target.value;
              setSearchParams(next === 'active' ? {} : { status: next }, { replace: true });
            }}
          />
        </div>
        {content}
      </section>
    </>
  );
}
