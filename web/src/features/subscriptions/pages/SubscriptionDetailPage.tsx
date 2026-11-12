import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, subscriptionEditPath, subscriptionPath } from '@/shared/config/paths';
import { categoriesById, categoryName } from '@/shared/finance/categories';
import { isStaleRecordError } from '@/shared/finance/domainErrors';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import { useGroups } from '@/shared/finance/sharing';
import type { SubscriptionDetail } from '@/shared/finance/types';
import { formatDate, formatLocalDate, parseTimestamp } from '@/shared/formatting/dates';
import { useFormatMoney } from '@/shared/formatting/useFormatMoney';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { type SubscriptionAction, subscriptionsApi, useSubscription } from '../api';
import { CancellationCard } from '../components/CancellationCard';
import { MarkCancelledDialog, StartCancellationDialog } from '../components/CancellationDialogs';
import { LinkPaymentFlow } from '../components/LinkPaymentFlow';
import { PaymentsCard, PriceHistoryCard, TimelineCard } from '../components/SubscriptionHistory';
import { SubscriptionStatusBadge } from '../components/SubscriptionStatusBadge';
import { subscriptionErrorMessage } from '../errors';
import { cycleLabel, duplicateReason, pricePerCycle, remindersText } from '../labels';

type QuickAction = Extract<SubscriptionAction, 'verify' | 'pause' | 'resume' | 'reactivate'>;

const quickDone: Readonly<Record<QuickAction, MessageKey>> = {
  verify: 'subscriptions.manage.verifyDone',
  pause: 'subscriptions.manage.pauseDone',
  resume: 'subscriptions.manage.resumeDone',
  reactivate: 'subscriptions.manage.reactivateDone',
};

/** A subscription with its costs, payments, price history and lifecycle. */
export function SubscriptionDetailPage() {
  const { t } = useI18n();
  const { subscriptionId = '' } = useParams();
  useDocumentTitle(t('subscriptions.detail.title'));
  const query = useSubscription(subscriptionId);

  if (query.isPending) return <LoadingState label={t('subscriptions.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="repeat"
          title={t('subscriptions.detail.notFound')}
          description={t('subscriptions.detail.notFoundBody')}
          action={<ButtonLink to={paths.subscriptions}>{t('subscriptions.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('subscriptions.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }
  return (
    <SubscriptionDetailView
      subscription={query.data}
      onReload={() => {
        void query.refetch();
      }}
    />
  );
}

function SubscriptionDetailView({
  subscription,
  onReload,
}: {
  subscription: SubscriptionDetail;
  onReload: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const toast = useToast();
  const queryClient = useQueryClient();
  const formatMoney = useFormatMoney();
  const [linkOpen, setLinkOpen] = useState(false);
  const [startOpen, setStartOpen] = useState(false);
  const [doneOpen, setDoneOpen] = useState(false);
  const editable = subscription.owned;
  const status = subscription.status;
  const canLink = editable && status !== 'cancelled';

  const quick = useMutation({
    // The version on screen: a change made elsewhere meanwhile answers 409.
    mutationFn: (action: QuickAction) =>
      subscriptionsApi.act(subscription.id, action, subscription.version),
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.subscription(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });
  const run = (action: QuickAction) => {
    if (quick.isPending) return;
    quick.mutate(action, {
      onSuccess: () => {
        toast.show({ tone: 'success', title: t(quickDone[action]) });
      },
      onError: (error) => {
        const stale = isStaleRecordError(error);
        toast.show({
          tone: stale ? 'warning' : 'danger',
          title: stale ? t('finance.conflict.title') : t('subscriptions.manage.failed'),
          description: subscriptionErrorMessage(error, t, formatLocale),
        });
        // Changed elsewhere (stale version or status): show the latest version.
        if (stale) onReload();
      },
    });
  };

  const details = [
    subscription.plan_name,
    subscription.merchant?.name,
    cycleLabel(subscription, t),
  ].filter(Boolean);

  return (
    <>
      <p className="mb-2">
        <TextLink to={paths.subscriptions}>
          <Icon name="arrow-left" className="me-1 inline size-4" />
          {t('subscriptions.backToList')}
        </TextLink>
      </p>
      <PageHeader
        title={subscription.name}
        description={details.join(' · ')}
        actions={
          editable ? (
            <>
              {canLink ? (
                <Button
                  onClick={() => {
                    setLinkOpen(true);
                  }}
                >
                  <Icon name="link" className="size-4" />
                  {t('subscriptions.payments.link')}
                </Button>
              ) : null}
              <ButtonLink to={subscriptionEditPath(subscription.id)} variant="secondary">
                <Icon name="pencil" className="size-4" />
                {t('common.edit')}
              </ButtonLink>
            </>
          ) : null
        }
      />
      <div className="mb-6 flex flex-wrap gap-2">
        <SubscriptionStatusBadge status={status} />
        {subscription.source === 'detected' ? (
          <StatusBadge tone="info" icon="search">
            {t('subscriptions.source.detected')}
          </StatusBadge>
        ) : null}
        {editable ? null : (
          <StatusBadge tone="neutral" icon="users">
            {t('subscriptions.sharedWithYou')}
          </StatusBadge>
        )}
      </div>
      {editable ? null : (
        <Alert tone="info" className="mb-6" title={t('subscriptions.readOnly.title')}>
          {t('subscriptions.readOnly.body')}
        </Alert>
      )}
      {subscription.duplicate_warnings.length > 0 ? (
        <Alert tone="warning" className="mb-6" title={t('subscriptions.duplicate.title')}>
          <p>{t('subscriptions.duplicate.body')}</p>
          <ul className="list-disc space-y-1 ps-5">
            {subscription.duplicate_warnings.map((warning) => (
              <li key={warning.subscription_id}>
                <Link
                  to={subscriptionPath(warning.subscription_id)}
                  className="font-medium underline underline-offset-4"
                >
                  {warning.name}
                </Link>{' '}
                · {duplicateReason(warning, t, formatLocale)}
              </li>
            ))}
          </ul>
        </Alert>
      ) : null}
      {status === 'cancellation_pending' ? (
        <Alert tone="info" className="mb-6" title={t('subscriptions.cancellation.pendingTitle')}>
          {t('subscriptions.cancellation.pendingBody')}
        </Alert>
      ) : null}

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Card
            title={t('subscriptions.cost.title')}
            description={t('subscriptions.cost.description')}
          >
            <dl className="grid gap-4 sm:grid-cols-3">
              <div className="rounded-lg border border-line p-4">
                <dt className="text-sm text-fg-muted">{t('subscriptions.cost.price')}</dt>
                <dd className="mt-1 font-semibold text-fg">
                  {pricePerCycle(subscription, formatMoney(subscription.amount), t)}
                </dd>
              </div>
              <div className="rounded-lg border border-line p-4">
                <dt className="text-sm text-fg-muted">{t('subscriptions.cost.monthly')}</dt>
                <dd className="mt-1 text-xl font-semibold text-fg">
                  <MoneyText money={subscription.monthly_cost} />
                </dd>
              </div>
              <div className="rounded-lg border border-line p-4">
                <dt className="text-sm text-fg-muted">{t('subscriptions.cost.yearly')}</dt>
                <dd className="mt-1 text-xl font-semibold text-fg">
                  <MoneyText money={subscription.annual_cost} />
                </dd>
              </div>
            </dl>
          </Card>
          <RenewalCard subscription={subscription} />
          <PaymentsCard
            subscription={subscription}
            canLink={canLink}
            canUnlink={editable}
            onLink={() => {
              setLinkOpen(true);
            }}
          />
          <PriceHistoryCard subscription={subscription} />
          <TimelineCard subscription={subscription} />
        </div>
        <div className="space-y-6">
          <DetailsCard subscription={subscription} />
          {editable ? (
            <Card title={t('subscriptions.manage.title')}>
              <div className="flex flex-col gap-3">
                <Button
                  variant="secondary"
                  loading={quick.isPending && quick.variables === 'verify'}
                  onClick={() => {
                    run('verify');
                  }}
                >
                  <Icon name="shield-check" className="size-4" />
                  {t('subscriptions.manage.verify')}
                </Button>
                <p className="text-sm text-fg-muted">
                  {subscription.last_verified_at
                    ? t('subscriptions.manage.lastVerified', {
                        date: formatTimestamp(
                          subscription.last_verified_at,
                          formatLocale,
                          user.timezone,
                        ),
                      })
                    : t('subscriptions.manage.verifyHelp')}
                </p>
                {status === 'trial' || status === 'active' ? (
                  <Button
                    variant="secondary"
                    loading={quick.isPending && quick.variables === 'pause'}
                    onClick={() => {
                      run('pause');
                    }}
                  >
                    <Icon name="pause" className="size-4" />
                    {t('subscriptions.manage.pause')}
                  </Button>
                ) : null}
                {status === 'paused' ? (
                  <Button
                    variant="secondary"
                    loading={quick.isPending && quick.variables === 'resume'}
                    onClick={() => {
                      run('resume');
                    }}
                  >
                    <Icon name="play" className="size-4" />
                    {t('subscriptions.manage.resume')}
                  </Button>
                ) : null}
                {status === 'trial' || status === 'active' || status === 'paused' ? (
                  <Button
                    variant="secondary"
                    onClick={() => {
                      setStartOpen(true);
                    }}
                  >
                    <Icon name="flag" className="size-4" />
                    {t('subscriptions.manage.startCancel')}
                  </Button>
                ) : null}
                {status !== 'cancelled' ? (
                  <Button
                    variant="secondary"
                    onClick={() => {
                      setDoneOpen(true);
                    }}
                  >
                    <Icon name="x-circle" className="size-4" />
                    {t('subscriptions.manage.markCancelled')}
                  </Button>
                ) : null}
                {status === 'cancelled' || status === 'cancellation_pending' ? (
                  <Button
                    variant="secondary"
                    loading={quick.isPending && quick.variables === 'reactivate'}
                    onClick={() => {
                      run('reactivate');
                    }}
                  >
                    <Icon name="refresh" className="size-4" />
                    {t('subscriptions.manage.reactivate')}
                  </Button>
                ) : null}
                <p className="text-sm text-fg-muted">{t('subscriptions.manage.neverCancels')}</p>
              </div>
            </Card>
          ) : null}
          <CancellationCard subscription={subscription} editable={editable} onReload={onReload} />
        </div>
      </div>

      {canLink ? (
        <LinkPaymentFlow subscription={subscription} open={linkOpen} onOpenChange={setLinkOpen} />
      ) : null}
      {editable ? (
        <>
          <StartCancellationDialog
            subscription={subscription}
            open={startOpen}
            onOpenChange={setStartOpen}
          />
          <MarkCancelledDialog
            subscription={subscription}
            open={doneOpen}
            onOpenChange={setDoneOpen}
          />
        </>
      ) : null}
    </>
  );
}

/** An instant as a date in the user's time zone. */
function formatTimestamp(value: string, locale: string, timeZone: string): string {
  const date = parseTimestamp(value);
  return date ? formatDate(date, locale, timeZone) : value;
}

function RenewalCard({ subscription }: { subscription: SubscriptionDetail }) {
  const { t, formatLocale } = useI18n();
  const long = (value: string) => formatLocalDate(value, formatLocale, 'long');
  return (
    <Card title={t('subscriptions.renewal.title')}>
      <Facts>
        <Fact label={t('subscriptions.renewal.next')}>
          {subscription.next_renewal_date
            ? long(subscription.next_renewal_date)
            : t('subscriptions.renewal.noNext')}
        </Fact>
        {subscription.trial_ends_on ? (
          <Fact label={t('subscriptions.renewal.trialEnds')}>
            {long(subscription.trial_ends_on)}
          </Fact>
        ) : null}
        <Fact label={t('subscriptions.renewal.reminders')}>
          {remindersText(subscription.reminder_days_before, t)}
        </Fact>
        {subscription.cancelled_on ? (
          <Fact label={t('subscriptions.renewal.cancelledOn')}>
            {long(subscription.cancelled_on)}
          </Fact>
        ) : null}
      </Facts>
    </Card>
  );
}

function DetailsCard({ subscription }: { subscription: SubscriptionDetail }) {
  const { t, formatLocale } = useI18n();
  const user = useCurrentUser();
  const accounts = useAccounts(true);
  const categories = useCategories(true);
  const groups = useGroups();
  const account = (accounts.data ?? []).find((item) => item.id === subscription.payment_account_id);
  const category = subscription.category_id
    ? categoriesById(categories.data).get(subscription.category_id)
    : undefined;
  const group = (groups.data ?? []).find((item) => item.id === subscription.group_id);
  const pending = t('common.loading');
  return (
    <Card title={t('subscriptions.details.title')}>
      <Facts>
        <Fact label={t('subscriptions.details.cycle')}>{cycleLabel(subscription, t)}</Fact>
        <Fact label={t('subscriptions.details.started')}>
          {formatLocalDate(subscription.start_date, formatLocale, 'long')}
        </Fact>
        <Fact label={t('subscriptions.details.account')}>
          {subscription.payment_account_id
            ? (account?.name ?? (accounts.isPending ? pending : t('subscriptions.details.unknown')))
            : t('subscriptions.details.notSet')}
        </Fact>
        <Fact label={t('subscriptions.details.category')}>
          {category
            ? categoryName(category, t)
            : subscription.category_id && categories.isPending
              ? pending
              : t('categories.uncategorized')}
        </Fact>
        {subscription.group_id ? (
          <Fact label={t('subscriptions.details.group')}>
            {group?.name ?? (groups.isPending ? pending : t('subscriptions.details.groupHidden'))}
          </Fact>
        ) : null}
        <Fact label={t('subscriptions.details.source')}>
          {subscription.source === 'detected'
            ? t('subscriptions.source.detected')
            : t('subscriptions.source.manual')}
        </Fact>
        <Fact label={t('subscriptions.details.added')}>
          {formatTimestamp(subscription.created_at, formatLocale, user.timezone)}
        </Fact>
        {subscription.notes ? (
          <Fact label={t('subscriptions.details.notes')}>
            <span className="whitespace-pre-line">{subscription.notes}</span>
          </Fact>
        ) : null}
      </Facts>
    </Card>
  );
}
