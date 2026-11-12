import { Link } from 'react-router';
import { Alert } from '@/shared/components/Alert';
import { Card } from '@/shared/components/Card';
import { MoneyText } from '@/shared/components/MoneyText';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { paths, subscriptionPath } from '@/shared/config/paths';
import type { Subscription, SubscriptionCostTotal } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { useSubscriptionSummary } from '../api';

/**
 * Monthly and yearly costs per currency (server totals; currencies are never
 * added together), upcoming renewals, trials ending soon and how many
 * possible subscriptions are waiting for review.
 */
export function SummaryCard() {
  const { t } = useI18n();
  const summary = useSubscriptionSummary();

  if (summary.isPending) {
    return (
      <Card title={t('subscriptions.summary.title')} className="mb-6">
        <LoadingState label={t('subscriptions.summary.loading')} />
      </Card>
    );
  }
  if (summary.isError) {
    return (
      <Card title={t('subscriptions.summary.title')} className="mb-6">
        <ErrorState
          titleAs="p"
          title={t('subscriptions.summary.error')}
          error={summary.error}
          retrying={summary.isFetching}
          onRetry={() => {
            void summary.refetch();
          }}
        />
      </Card>
    );
  }
  const data = summary.data;
  const totals = data.totals;
  const renewals = data.upcoming_renewals;
  const trials = data.trials_ending_soon;
  const empty =
    totals.length === 0 &&
    data.pending_detections === 0 &&
    renewals.length === 0 &&
    trials.length === 0;
  if (empty) return null;
  return (
    <Card
      title={t('subscriptions.summary.title')}
      description={t('subscriptions.summary.description')}
      className="mb-6"
    >
      <div className="space-y-6">
        {data.pending_detections > 0 ? (
          <Alert tone="info" title={t('subscriptions.summary.foundTitle')}>
            <p>
              {t('subscriptions.summary.found', { count: data.pending_detections })}{' '}
              <TextLink to={paths.subscriptionReview}>
                {t('subscriptions.summary.reviewLink')}
              </TextLink>
            </p>
          </Alert>
        ) : null}
        <Totals totals={totals} />
        <div className="grid gap-6 md:grid-cols-2">
          <UpcomingList
            title={t('subscriptions.summary.renewals')}
            empty={t('subscriptions.summary.renewalsEmpty')}
            items={renewals}
            date={(item) => item.next_renewal_date}
          />
          <UpcomingList
            title={t('subscriptions.summary.trials')}
            empty={t('subscriptions.summary.trialsEmpty')}
            items={trials}
            date={(item) => item.trial_ends_on}
          />
        </div>
      </div>
    </Card>
  );
}

function Totals({ totals }: { totals: readonly SubscriptionCostTotal[] }) {
  const { t } = useI18n();
  if (totals.length === 0) {
    return <p className="text-sm text-fg-muted">{t('subscriptions.summary.noTotals')}</p>;
  }
  return (
    <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {totals.map((total) => (
        <li key={total.currency} className="rounded-lg border border-line p-4">
          <p className="text-sm font-medium text-fg-muted">
            {t('subscriptions.summary.currency', {
              currency: total.currency,
              count: total.count,
            })}
          </p>
          <p className="mt-2 text-2xl font-semibold text-fg">
            <MoneyText money={total.monthly} />
            <span className="ms-1 text-sm font-normal text-fg-muted">
              {t('subscriptions.summary.perMonth')}
            </span>
          </p>
          <p className="text-sm text-fg-muted">
            <MoneyText money={total.annual} /> {t('subscriptions.summary.perYear')}
          </p>
        </li>
      ))}
    </ul>
  );
}

function UpcomingList({
  title,
  empty,
  items,
  date,
}: {
  title: string;
  empty: string;
  items: readonly Subscription[];
  date: (item: Subscription) => string | undefined;
}) {
  const { formatLocale } = useI18n();
  return (
    <section className="space-y-3">
      <h3 className="text-sm font-semibold text-fg">{title}</h3>
      {items.length === 0 ? (
        <p className="text-sm text-fg-muted">{empty}</p>
      ) : (
        <ul className="divide-y divide-line">
          {items.map((item) => {
            const when = date(item);
            return (
              <li key={item.id} className="flex items-center gap-3 py-2 first:pt-0 last:pb-0">
                <div className="min-w-0 flex-1">
                  <Link
                    to={subscriptionPath(item.id)}
                    className="font-medium text-fg underline-offset-4 hover:underline"
                  >
                    {item.name}
                  </Link>
                  {when ? (
                    <p className="text-sm text-fg-muted">
                      {formatLocalDate(when, formatLocale, 'long')}
                    </p>
                  ) : null}
                </div>
                <MoneyText money={item.amount} className="shrink-0 text-sm font-medium" />
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
