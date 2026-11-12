import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ChartTable } from '@/shared/components/charts/ChartFrame';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { ProgressMeter } from '@/shared/components/ProgressMeter';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { EmptyState, LoadingState } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { budgetPath, goalPath, paths, subscriptionPath } from '@/shared/config/paths';
import {
  formatBasisPoints,
  formatLocalDate,
  formatLocalDateRange,
} from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import {
  useBudgetPerformance,
  useGoalReport,
  useRecurringReport,
  useSubscriptionSummary,
} from '../api';
import { CurrencySection, QueryError, RefreshFailed, StatTile } from '../components/Blocks';
import { groupByCurrency } from '../categoryNames';
import { isPace, PACES, paceDisplay, recurringKindLabel } from '../labels';
import type { RecurringReport, SubscriptionSummaryItem } from '../types';

interface LoadableQuery {
  isPending: boolean;
  isError: boolean;
  isFetching: boolean;
  error: unknown;
  refetch: () => unknown;
}

/** Loading or error content for a summary card. */
function CardState({ query }: { query: LoadableQuery }) {
  const { t } = useI18n();
  if (query.isPending) return <LoadingState label={t('analytics.loading')} />;
  return (
    <QueryError
      error={query.error}
      title={t('analytics.error')}
      retrying={query.isFetching}
      onRetry={() => {
        void query.refetch();
      }}
    />
  );
}

/** Earlier figures stay on screen when a background refresh fails. */
function Stale({ query }: { query: LoadableQuery & { data: unknown } }) {
  const { t } = useI18n();
  if (!query.isError || query.data === undefined) return null;
  return (
    <RefreshFailed
      message={t('analytics.stale.figures')}
      retrying={query.isFetching}
      onRetry={() => {
        void query.refetch();
      }}
    />
  );
}

function ViewLink({ to, label }: { to: string; label: string }) {
  return (
    <ButtonLink to={to} variant="ghost" size="sm">
      {label}
      <Icon name="arrow-right" className="size-4" />
    </ButtonLink>
  );
}

/** Active budgets in their current periods, with the API's pace for each. */
function BudgetsCard() {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const report = useBudgetPerformance();
  let content;
  if (!report.data) {
    content = <CardState query={report} />;
  } else {
    const budgets = report.data.budgets.filter(
      (budget) => budget.status === 'active' && budget.progress,
    );
    const counts = PACES.map((pace) => [pace, report.data.by_pace[pace] ?? 0] as const).filter(
      ([, count]) => count > 0,
    );
    content =
      budgets.length === 0 ? (
        <EmptyState
          icon="pie-chart"
          title={t('analytics.budgets.empty')}
          description={t('analytics.budgets.emptyBody')}
          action={
            <ButtonLink to={paths.budgetNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('analytics.budgets.create')}
            </ButtonLink>
          }
        />
      ) : (
        <div className="space-y-5">
          {counts.length > 0 ? (
            <ul aria-label={t('analytics.budgets.paceSummary')} className="flex flex-wrap gap-2">
              {counts.map(([pace, count]) => (
                <li key={pace}>
                  <StatusBadge tone={paceDisplay[pace].tone} icon={paceDisplay[pace].icon}>
                    {t('analytics.budgets.paceCount', { label: t(paceDisplay[pace].label), count })}
                  </StatusBadge>
                </li>
              ))}
            </ul>
          ) : null}
          <ul className="divide-y divide-line">
            {budgets.map((budget) => {
              const progress = budget.progress;
              if (!progress) return null;
              const pace = isPace(progress.pace) ? paceDisplay[progress.pace] : null;
              const spentOf = t('analytics.budgets.spentOf', {
                spent: format(progress.spent),
                limit: format(progress.limit),
              });
              return (
                <li key={budget.id} className="space-y-2 py-4 first:pt-0 last:pb-0">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <TextLink to={budgetPath(budget.id)}>{budget.name}</TextLink>
                    {pace ? (
                      <StatusBadge tone={pace.tone} icon={pace.icon}>
                        {t(pace.label)}
                      </StatusBadge>
                    ) : null}
                  </div>
                  <ProgressMeter
                    percentBp={progress.percent_bp}
                    label={t('analytics.budgets.meterLabel', { name: budget.name })}
                    valueText={spentOf}
                    tone={pace?.meter ?? 'accent'}
                    size="sm"
                  />
                  <p className="text-sm text-fg-muted">
                    {spentOf} ({formatBasisPoints(progress.percent_bp, formatLocale)}) ·{' '}
                    {formatLocalDateRange(progress.period_start, progress.period_end, formatLocale)}
                  </p>
                </li>
              );
            })}
          </ul>
        </div>
      );
  }
  return (
    <Card
      title={t('analytics.budgets.title')}
      description={t('analytics.budgets.description')}
      actions={<ViewLink to={paths.budgets} label={t('analytics.budgets.view')} />}
    >
      <Stale query={report} />
      {content}
    </Card>
  );
}

/** Saved toward goals per currency (the API's totals), plus active goals' progress. */
function GoalsCard() {
  const { t, formatLocale } = useI18n();
  const format = useFormatMoney();
  const report = useGoalReport();
  let content;
  if (!report.data) {
    content = <CardState query={report} />;
  } else if (report.data.totals.length === 0) {
    content = (
      <EmptyState
        icon="target"
        title={t('analytics.goals.empty')}
        description={t('analytics.goals.emptyBody')}
        action={
          <ButtonLink to={paths.goalNew} variant="secondary">
            <Icon name="plus" className="size-4" />
            {t('analytics.goals.create')}
          </ButtonLink>
        }
      />
    );
  } else {
    const totals = report.data.totals;
    const active = report.data.goals.filter((goal) => goal.status === 'active');
    content = (
      <div className="space-y-6">
        {totals.map((total) => (
          <CurrencySection
            key={total.currency}
            currency={total.currency}
            showHeading={totals.length > 1}
          >
            <dl className="grid gap-3 sm:grid-cols-3">
              <StatTile label={t('analytics.goals.saved')}>
                <MoneyText money={total.saved} />
              </StatTile>
              <StatTile label={t('analytics.goals.target')}>
                <MoneyText money={total.target} />
              </StatTile>
              <StatTile label={t('analytics.goals.count')}>
                {t('analytics.goals.countValue', { count: total.count, achieved: total.achieved })}
              </StatTile>
            </dl>
          </CurrencySection>
        ))}
        {active.length > 0 ? (
          <ul className="divide-y divide-line" aria-label={t('analytics.goals.activeList')}>
            {active.map((goal) => {
              const savedOf = t('analytics.goals.savedOf', {
                saved: format(goal.progress.saved),
                target: format(goal.target),
              });
              return (
                <li key={goal.id} className="space-y-2 py-4 first:pt-0 last:pb-0">
                  <div className="flex flex-wrap items-baseline justify-between gap-2">
                    <TextLink to={goalPath(goal.id)}>{goal.name}</TextLink>
                    <span className="text-sm text-fg-muted">
                      {formatBasisPoints(goal.progress.percent_bp, formatLocale)}
                    </span>
                  </div>
                  <ProgressMeter
                    percentBp={goal.progress.percent_bp}
                    label={t('analytics.goals.meterLabel', { name: goal.name })}
                    valueText={savedOf}
                    size="sm"
                  />
                  <p className="text-sm text-fg-muted">{savedOf}</p>
                </li>
              );
            })}
          </ul>
        ) : null}
      </div>
    );
  }
  return (
    <Card
      title={t('analytics.goals.title')}
      description={t('analytics.goals.description')}
      actions={<ViewLink to={paths.goals} label={t('analytics.goals.view')} />}
    >
      <Stale query={report} />
      {content}
    </Card>
  );
}

function SubscriptionList({
  label,
  items,
  date,
}: {
  label: string;
  items: readonly SubscriptionSummaryItem[];
  date: (item: SubscriptionSummaryItem) => string | undefined;
}) {
  const { formatLocale } = useI18n();
  if (items.length === 0) return null;
  return (
    <div>
      <h3 className="mb-2 text-sm font-semibold text-fg">{label}</h3>
      <ul className="divide-y divide-line">
        {items.map((item) => {
          const when = date(item);
          return (
            <li
              key={item.id}
              className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 py-2.5"
            >
              <TextLink to={subscriptionPath(item.id)}>{item.name}</TextLink>
              <span className="text-sm text-fg-muted">
                {when ? `${formatLocalDate(when, formatLocale)} · ` : null}
                <MoneyText money={item.amount} />
              </span>
            </li>
          );
        })}
      </ul>
    </div>
  );
}

/** Subscription costs per currency, renewals in the next 30 days and trials ending soon. */
function SubscriptionsCard() {
  const { t } = useI18n();
  const report = useSubscriptionSummary();
  let content;
  if (!report.data) {
    content = <CardState query={report} />;
  } else {
    const data = report.data;
    const nothing =
      data.totals.length === 0 &&
      data.upcoming_renewals.length === 0 &&
      data.trials_ending_soon.length === 0;
    content = (
      <div className="space-y-6">
        {data.pending_detections > 0 ? (
          <Alert
            tone="info"
            title={t('analytics.subscriptions.detections', { count: data.pending_detections })}
          >
            <TextLink to={paths.subscriptionReview}>{t('analytics.subscriptions.review')}</TextLink>
          </Alert>
        ) : null}
        {nothing ? (
          <EmptyState
            icon="repeat"
            title={t('analytics.subscriptions.empty')}
            description={t('analytics.subscriptions.emptyBody')}
            action={
              <ButtonLink to={paths.subscriptionNew} variant="secondary">
                <Icon name="plus" className="size-4" />
                {t('analytics.subscriptions.create')}
              </ButtonLink>
            }
          />
        ) : (
          <>
            {data.totals.map((total) => (
              <CurrencySection
                key={total.currency}
                currency={total.currency}
                showHeading={data.totals.length > 1}
              >
                <dl className="grid gap-3 sm:grid-cols-3">
                  <StatTile label={t('analytics.subscriptions.monthly')}>
                    <MoneyText money={total.monthly} />
                  </StatTile>
                  <StatTile label={t('analytics.subscriptions.annual')}>
                    <MoneyText money={total.annual} />
                  </StatTile>
                  <StatTile label={t('analytics.subscriptions.count')}>
                    <span>{total.count}</span>
                  </StatTile>
                </dl>
              </CurrencySection>
            ))}
            <SubscriptionList
              label={t('analytics.subscriptions.renewals')}
              items={data.upcoming_renewals}
              date={(item) => item.next_renewal_date}
            />
            <SubscriptionList
              label={t('analytics.subscriptions.trials')}
              items={data.trials_ending_soon}
              date={(item) => item.trial_ends_on}
            />
          </>
        )}
      </div>
    );
  }
  return (
    <Card
      title={t('analytics.subscriptions.title')}
      description={t('analytics.subscriptions.description')}
      actions={<ViewLink to={paths.subscriptions} label={t('analytics.subscriptions.view')} />}
    >
      <Stale query={report} />
      {content}
    </Card>
  );
}

const recurringNotes: Readonly<Partial<Record<string, MessageKey>>> = {
  fixed_amounts_expectations: 'analytics.recurring.note.fixed_amounts_expectations',
};

/** "Monthly equivalents use fixed amounts only…", localized by note_code (API text otherwise). */
function recurringNote(report: RecurringReport, t: Translate): string {
  const key = recurringNotes[report.note_code];
  return key ? t(key) : report.note;
}

/** Active recurring rules normalized to a month, per kind and currency. */
function RecurringCard() {
  const { t } = useI18n();
  const report = useRecurringReport();
  let content;
  if (!report.data) {
    content = <CardState query={report} />;
  } else if (report.data.commitments.length === 0) {
    content = (
      <EmptyState
        icon="repeat"
        title={t('analytics.recurring.empty')}
        description={t('analytics.recurring.emptyBody')}
        action={
          <ButtonLink to={paths.recurringNew} variant="secondary">
            <Icon name="plus" className="size-4" />
            {t('analytics.recurring.create')}
          </ButtonLink>
        }
      />
    );
  } else {
    const groups = groupByCurrency(report.data.commitments);
    content = (
      <div className="space-y-6">
        {groups.map(([currency, commitments]) => (
          <CurrencySection key={currency} currency={currency} showHeading={groups.length > 1}>
            <div className="overflow-x-auto">
              <ChartTable
                caption={t('analytics.recurring.tableLabel', { currency })}
                columns={[
                  t('analytics.recurring.kind'),
                  t('analytics.recurring.monthly'),
                  t('analytics.recurring.next30'),
                  t('analytics.recurring.rules'),
                ]}
                rows={commitments.map((commitment) => ({
                  key: commitment.kind,
                  cells: [
                    t(recurringKindLabel[commitment.kind]),
                    <MoneyText key="monthly" money={commitment.monthly_equivalent} />,
                    <MoneyText key="next" money={commitment.next_30_days} />,
                    commitment.variable_count > 0
                      ? t('analytics.recurring.rulesVariable', {
                          count: commitment.rule_count,
                          variable: commitment.variable_count,
                        })
                      : commitment.rule_count,
                  ],
                }))}
              />
            </div>
          </CurrencySection>
        ))}
        <p className="text-sm text-fg-muted">{recurringNote(report.data, t)}</p>
      </div>
    );
  }
  return (
    <Card
      title={t('analytics.recurring.title')}
      description={t('analytics.recurring.description')}
      actions={<ViewLink to={paths.recurring} label={t('analytics.recurring.view')} />}
    >
      <Stale query={report} />
      {content}
    </Card>
  );
}

/** Budgets, goals, subscriptions and recurring commitments as they stand today. */
export function PlansView() {
  const { t } = useI18n();
  return (
    <div className="grid gap-6">
      <p className="text-fg-muted">{t('analytics.plans.intro')}</p>
      <BudgetsCard />
      <GoalsCard />
      <SubscriptionsCard />
      <RecurringCard />
    </div>
  );
}
