import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { useToast } from '@/shared/components/toast/ToastContext';
import { transactionPath } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { LinkedPayment, SubscriptionDetail, SubscriptionEvent } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { subscriptionsApi } from '../api';
import { subscriptionErrorMessage } from '../errors';
import { eventIcon, eventLabel, eventNote } from '../labels';

/** Newest first (the API already sends them so; kept stable for equal dates). */
function newestFirst(events: readonly SubscriptionEvent[]): SubscriptionEvent[] {
  return [...events].sort(
    (a, b) =>
      b.occurred_on.localeCompare(a.occurred_on) || b.created_at.localeCompare(a.created_at),
  );
}

/** The payment also recorded a price change (unlinking keeps that price). */
function changedPrice(events: readonly SubscriptionEvent[], transactionId?: string): boolean {
  return Boolean(
    transactionId &&
    events.some(
      (event) => event.kind === 'price_changed' && event.transaction_id === transactionId,
    ),
  );
}

/** How a payment came to be linked (e.g. matched by a detection), from its link event. */
function paymentNote(
  payment: LinkedPayment,
  events: readonly SubscriptionEvent[],
  t: ReturnType<typeof useI18n>['t'],
): string | null {
  const event = [...events]
    .reverse()
    .find(
      (item) => item.kind === 'payment_recorded' && item.transaction_id === payment.transaction_id,
    );
  return event ? eventNote(event, t) : null;
}

/**
 * Payments linked from the ledger now (`payments`, newest first; an
 * unlinked one stays in the history), with ways to link another one or
 * unlink a wrong match.
 */
export function PaymentsCard({
  subscription,
  canLink,
  canUnlink,
  onLink,
}: {
  subscription: SubscriptionDetail;
  canLink: boolean;
  /** The owner can unlink payments (the transaction itself is not changed). */
  canUnlink: boolean;
  onLink: () => void;
}) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [unlinking, setUnlinking] = useState<LinkedPayment | null>(null);
  const [unlinkError, setUnlinkError] = useState<string | null>(null);
  const unlink = useMutation({
    mutationFn: (transactionId: string) =>
      subscriptionsApi.unlinkPayment(subscription.id, transactionId),
    onSuccess: (updated) => {
      queryClient.setQueryData(financeKeys.subscription(updated.id), updated);
      void invalidateFinance(queryClient);
    },
  });
  const payments = subscription.payments;
  const last = subscription.last_payment;

  const confirmUnlink = () => {
    const transactionId = unlinking?.transaction_id;
    if (!transactionId || unlink.isPending) return;
    setUnlinkError(null);
    unlink.mutate(transactionId, {
      onSuccess: () => {
        setUnlinking(null);
        toast.show({ tone: 'success', title: t('subscriptions.payments.unlinked') });
      },
      onError: (error) => {
        if (hasErrorCode(error, 'NOT_FOUND')) {
          // Already unlinked somewhere else: show the current history.
          setUnlinking(null);
          toast.show({ tone: 'info', title: t('subscriptions.payments.alreadyUnlinked') });
          void queryClient.invalidateQueries({
            queryKey: financeKeys.subscription(subscription.id),
          });
          return;
        }
        setUnlinkError(subscriptionErrorMessage(error, t, formatLocale));
      },
    });
  };

  return (
    <Card
      title={t('subscriptions.payments.title')}
      description={t('subscriptions.payments.description')}
      actions={
        canLink ? (
          <Button variant="secondary" size="sm" onClick={onLink}>
            <Icon name="link" className="size-4" />
            {t('subscriptions.payments.link')}
          </Button>
        ) : null
      }
    >
      {last ? (
        <p className="mb-4 text-sm text-fg">
          {t('subscriptions.payments.last', {
            date: formatLocalDate(last.occurred_on, formatLocale, 'long'),
          })}{' '}
          {last.amount ? <MoneyText money={last.amount} className="font-semibold" /> : null}
        </p>
      ) : null}
      {payments.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('subscriptions.payments.empty')}</p>
      ) : (
        <ul className="divide-y divide-line">
          {payments.map((payment) => {
            const note = paymentNote(payment, subscription.events, t);
            const date = formatLocalDate(payment.local_date, formatLocale, 'long');
            return (
              <li
                key={payment.transaction_id}
                className="flex flex-wrap items-start gap-x-3 gap-y-2 py-3 first:pt-0 last:pb-0"
              >
                <Icon name="receipt" className="mt-0.5 size-4 text-fg-muted" />
                <div className="min-w-0 flex-1">
                  <p className="text-fg">
                    {payment.account_name ? `${date} · ${payment.account_name}` : date}
                  </p>
                  {note ? <p className="text-sm text-fg-muted">{note}</p> : null}
                  <Link
                    to={transactionPath(payment.transaction_id)}
                    className="text-sm font-medium text-accent underline underline-offset-4"
                  >
                    {t('subscriptions.payments.viewTransaction')}
                  </Link>
                </div>
                <MoneyText money={payment.amount} className="shrink-0 font-medium" />
                {canUnlink ? (
                  <Button
                    variant="ghost"
                    size="sm"
                    aria-label={t('subscriptions.payments.unlinkFor', { date })}
                    onClick={() => {
                      setUnlinkError(null);
                      setUnlinking(payment);
                    }}
                  >
                    <Icon name="x" className="size-4" />
                    {t('subscriptions.payments.unlink')}
                  </Button>
                ) : null}
              </li>
            );
          })}
        </ul>
      )}
      <ConfirmDialog
        open={unlinking !== null}
        onOpenChange={(open) => {
          if (!open && !unlink.isPending) setUnlinking(null);
        }}
        title={t('subscriptions.payments.unlinkTitle')}
        description={
          unlinking ? (
            <>
              <span className="block">
                {t('subscriptions.payments.unlinkBody', {
                  date: formatLocalDate(unlinking.local_date, formatLocale, 'long'),
                })}
              </span>
              {changedPrice(subscription.events, unlinking.transaction_id) ? (
                <span className="mt-2 block">{t('subscriptions.payments.unlinkPriceNote')}</span>
              ) : null}
            </>
          ) : (
            ''
          )
        }
        confirmLabel={t('subscriptions.payments.unlinkConfirm')}
        pending={unlink.isPending}
        error={unlinkError}
        onConfirm={confirmUnlink}
      />
    </Card>
  );
}

/** The starting price and every price change (old → new). */
export function PriceHistoryCard({ subscription }: { subscription: SubscriptionDetail }) {
  const { t, formatLocale } = useI18n();
  const changes = newestFirst(
    subscription.events.filter(
      (event) => event.kind === 'price_changed' || (event.kind === 'created' && event.new_amount),
    ),
  );
  return (
    <Card
      title={t('subscriptions.priceHistory.title')}
      description={t('subscriptions.priceHistory.description')}
    >
      {changes.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('subscriptions.priceHistory.empty')}</p>
      ) : (
        <ol className="divide-y divide-line">
          {changes.map((event) => (
            <li
              key={event.id}
              className="flex flex-wrap items-baseline gap-x-3 gap-y-1 py-3 first:pt-0 last:pb-0"
            >
              <span className="min-w-0 flex-1 text-sm text-fg-muted">
                {formatLocalDate(event.occurred_on, formatLocale, 'long')}
              </span>
              {event.kind === 'price_changed' && event.old_amount && event.new_amount ? (
                <span className="text-fg">
                  {t('subscriptions.priceHistory.changed')} <MoneyText money={event.old_amount} />{' '}
                  <Icon
                    name="arrow-right"
                    className="inline size-4"
                    title={t('subscriptions.priceHistory.to')}
                  />{' '}
                  <MoneyText money={event.new_amount} className="font-semibold" />
                </span>
              ) : event.new_amount ? (
                <span className="text-fg">
                  {t('subscriptions.priceHistory.started')}{' '}
                  <MoneyText money={event.new_amount} className="font-semibold" />
                </span>
              ) : null}
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}

/** Everything that happened, newest first. */
export function TimelineCard({ subscription }: { subscription: SubscriptionDetail }) {
  const { t, formatLocale } = useI18n();
  const events = newestFirst(subscription.events);
  return (
    <Card title={t('subscriptions.timeline.title')}>
      {events.length === 0 ? (
        <p className="text-sm text-fg-muted">{t('subscriptions.timeline.empty')}</p>
      ) : (
        <ol className="space-y-4">
          {events.map((event) => {
            const note = eventNote(event, t);
            return (
              <li key={event.id} className="flex gap-3">
                <span className="mt-0.5 inline-flex size-8 shrink-0 items-center justify-center rounded-full bg-surface-muted text-fg-muted">
                  <Icon name={eventIcon(event)} className="size-4" />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="font-medium text-fg">{eventLabel(event, t)}</p>
                  <p className="text-sm text-fg-muted">
                    {formatLocalDate(event.occurred_on, formatLocale, 'long')}
                  </p>
                  {event.kind === 'price_changed' && event.old_amount && event.new_amount ? (
                    <p className="text-sm text-fg">
                      <MoneyText money={event.old_amount} />{' '}
                      <Icon
                        name="arrow-right"
                        className="inline size-4"
                        title={t('subscriptions.priceHistory.to')}
                      />{' '}
                      <MoneyText money={event.new_amount} />
                    </p>
                  ) : event.new_amount ? (
                    <p className="text-sm text-fg">
                      <MoneyText money={event.new_amount} />
                    </p>
                  ) : null}
                  {note ? <p className="text-sm text-fg-muted">{note}</p> : null}
                </div>
              </li>
            );
          })}
        </ol>
      )}
    </Card>
  );
}
