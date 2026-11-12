import { Link, useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { Select } from '@/shared/components/Select';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { paths, subscriptionPath } from '@/shared/config/paths';
import type { Subscription } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type SubscriptionListStatus, useSubscriptions } from '../api';
import { SubscriptionStatusBadge } from '../components/SubscriptionStatusBadge';
import { SubscriptionsSubNav } from '../components/SubscriptionsSubNav';
import { SummaryCard } from '../components/SummaryCard';
import { LIST_FILTERS, cycleLabel, isListFilter, listFilterLabel, pricePerCycle } from '../labels';

/** GET /subscriptions answers at most this many (ordered by next renewal, then name). */
const LIST_LIMIT = 500;

/** Subscriptions with the server's normalized monthly and yearly costs. */
export function SubscriptionsPage() {
  const { t } = useI18n();
  useDocumentTitle(t('subscriptions.title'));
  const [params, setParams] = useSearchParams();
  const raw = params.get('status') ?? '';
  const status: SubscriptionListStatus = isListFilter(raw) ? raw : '';
  const list = useSubscriptions(status);

  const setStatus = (next: string) => {
    setParams(
      (current) => {
        const updated = new URLSearchParams(current);
        if (next) updated.set('status', next);
        else updated.delete('status');
        return updated;
      },
      { replace: true },
    );
  };

  let content;
  if (list.isPending) {
    content = <LoadingState label={t('subscriptions.list.loading')} />;
  } else if (list.isError) {
    content = hasErrorCode(list.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('subscriptions.list.error')}
        error={list.error}
        retrying={list.isFetching}
        onRetry={() => {
          void list.refetch();
        }}
      />
    );
  } else if (list.data.length === 0) {
    content =
      status === '' ? (
        <EmptyState
          icon="repeat"
          title={t('subscriptions.empty.title')}
          description={t('subscriptions.empty.body')}
          action={
            <>
              <ButtonLink to={paths.subscriptionNew}>
                <Icon name="plus" className="size-4" />
                {t('subscriptions.add')}
              </ButtonLink>
              <ButtonLink to={paths.subscriptionReview} variant="secondary">
                <Icon name="search" className="size-4" />
                {t('subscriptions.empty.review')}
              </ButtonLink>
            </>
          }
        />
      ) : (
        <EmptyState
          icon="filter"
          title={t('subscriptions.empty.filteredTitle')}
          description={t('subscriptions.empty.filteredBody')}
          action={
            <Button
              variant="secondary"
              onClick={() => {
                setStatus('all');
              }}
            >
              {t('subscriptions.empty.showAll')}
            </Button>
          }
        />
      );
  } else {
    content = (
      <>
        {list.data.length >= LIST_LIMIT ? (
          <Alert tone="info" className="mb-4">
            {t('subscriptions.list.capped', { max: LIST_LIMIT })}
          </Alert>
        ) : null}
        <ul className="divide-y divide-line">
          {list.data.map((subscription) => (
            <SubscriptionRow key={subscription.id} subscription={subscription} />
          ))}
        </ul>
      </>
    );
  }

  return (
    <>
      <PageHeader
        title={t('subscriptions.title')}
        description={t('subscriptions.description')}
        actions={
          <ButtonLink to={paths.subscriptionNew}>
            <Icon name="plus" className="size-4" />
            {t('subscriptions.add')}
          </ButtonLink>
        }
      />
      <SubscriptionsSubNav />
      <SummaryCard />
      <Card
        title={t('subscriptions.list.title')}
        actions={
          <Select
            label={t('subscriptions.filter.label')}
            hideLabel
            value={status}
            onChange={(event) => {
              setStatus(event.target.value);
            }}
            options={LIST_FILTERS.map((value) => ({
              value,
              label: t(listFilterLabel[value]),
            }))}
          />
        }
      >
        {content}
      </Card>
    </>
  );
}

function SubscriptionRow({ subscription }: { subscription: Subscription }) {
  const { t, formatLocale } = useI18n();
  const formatMoney = useFormatMoney();
  const details = [
    subscription.plan_name,
    subscription.merchant?.name,
    cycleLabel(subscription, t),
  ].filter(Boolean);
  let when: string | null = null;
  if (subscription.status === 'trial' && subscription.trial_ends_on) {
    when = t('subscriptions.list.trialEnds', {
      date: formatLocalDate(subscription.trial_ends_on, formatLocale, 'long'),
    });
  } else if (subscription.status === 'cancelled' && subscription.cancelled_on) {
    when = t('subscriptions.list.cancelledOn', {
      date: formatLocalDate(subscription.cancelled_on, formatLocale, 'long'),
    });
  } else if (subscription.next_renewal_date) {
    when = t('subscriptions.list.renews', {
      date: formatLocalDate(subscription.next_renewal_date, formatLocale, 'long'),
    });
  }
  return (
    <li className="flex flex-col gap-3 py-4 first:pt-0 last:pb-0 sm:flex-row sm:items-start">
      <div className="min-w-0 flex-1 space-y-1">
        <Link
          to={subscriptionPath(subscription.id)}
          className="font-medium text-fg underline-offset-4 hover:underline"
        >
          {subscription.name}
        </Link>
        {details.length > 0 ? <p className="text-sm text-fg-muted">{details.join(' · ')}</p> : null}
        <div className="flex flex-wrap gap-2">
          <SubscriptionStatusBadge status={subscription.status} />
          {subscription.duplicate_warnings.length > 0 ? (
            <StatusBadge tone="warning" icon="copy">
              {t('subscriptions.duplicate.badge')}
            </StatusBadge>
          ) : null}
          {subscription.owned ? null : (
            <StatusBadge tone="neutral" icon="users">
              {t('subscriptions.sharedWithYou')}
            </StatusBadge>
          )}
        </div>
        {when ? <p className="text-sm text-fg-muted">{when}</p> : null}
      </div>
      <div className="shrink-0 space-y-1 sm:text-end">
        <p className="font-semibold text-fg">
          {pricePerCycle(subscription, formatMoney(subscription.amount), t)}
        </p>
        <p className="text-sm text-fg-muted">
          {t('subscriptions.list.normalizedMonthly')}{' '}
          <MoneyText money={subscription.monthly_cost} />
        </p>
        <p className="text-sm text-fg-muted">
          {t('subscriptions.list.normalizedYearly')} <MoneyText money={subscription.annual_cost} />
        </p>
      </div>
    </li>
  );
}
