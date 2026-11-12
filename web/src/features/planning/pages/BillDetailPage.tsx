import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useIdempotencyKey } from '@/shared/api/idempotency';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { billEditPath, paths, transactionPath } from '@/shared/config/paths';
import { categoriesById, categoryName } from '@/shared/finance/categories';
import { isStaleRecordError } from '@/shared/finance/domainErrors';
import { invalidateFinance } from '@/shared/finance/keys';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import type { BillDetail, Occurrence } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type BillStatusAction, planningApi, useBill } from '../api';
import { BackLink } from '../components/BackLink';
import { MarkPaidFlow } from '../components/MarkPaidFlow';
import { BillStateBadge, MovedBadge, OccurrenceStatusBadge } from '../components/StatusBadges';
import { planningErrorMessage } from '../errors';
import { isOpenOccurrence, occurrenceRowDate } from '../labels';
import { describeEnd, describeReminders, describeSchedule } from '../schedule';

const statusDone = {
  pause: 'bills.pause.done',
  resume: 'bills.resume.done',
  archive: 'bills.archive.done',
  restore: 'bills.restore.done',
} as const;

/** A bill: what is due, how it repeats, and its payment history. */
export function BillDetailPage() {
  const { t } = useI18n();
  useDocumentTitle(t('bills.detail.documentTitle'));
  const { billId = '' } = useParams();
  const query = useBill(billId);

  if (query.isPending) return <LoadingState label={t('bills.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="receipt"
          title={t('bills.detail.notFound')}
          description={t('bills.detail.notFoundBody')}
          action={<ButtonLink to={paths.bills}>{t('bills.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('bills.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }
  return (
    <BillDetailView
      bill={query.data}
      onReload={() => {
        void query.refetch();
      }}
    />
  );
}

function BillDetailView({ bill, onReload }: { bill: BillDetail; onReload: () => void }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const queryClient = useQueryClient();
  const accounts = useAccounts(true);
  const categories = useCategories(true);
  const idempotency = useIdempotencyKey();
  const [paying, setPaying] = useState<Occurrence | null>(null);
  const [skipping, setSkipping] = useState<Occurrence | null>(null);
  const [skipError, setSkipError] = useState<string | null>(null);
  const [confirmStatus, setConfirmStatus] = useState<'archive' | null>(null);
  const [statusError, setStatusError] = useState<string | null>(null);

  // Lifecycle actions send the version on screen; a stale one answers 409.
  const status = useMutation({
    mutationFn: (change: BillStatusAction) => planningApi.billAction(bill.id, change, bill.version),
    onSettled: () => invalidateFinance(queryClient),
  });
  const skip = useMutation({
    mutationFn: (occurrence: Occurrence) => planningApi.skipBill(bill.id, occurrence.id),
    onSettled: () => invalidateFinance(queryClient),
  });
  const reopen = useMutation({
    mutationFn: (occurrence: Occurrence) =>
      planningApi.occurrenceAction(occurrence.id, { action: 'reopen' }, idempotency.key),
    onSettled: () => invalidateFinance(queryClient),
  });

  const changeStatus = (change: BillStatusAction) => {
    if (status.isPending) return;
    setStatusError(null);
    status.mutate(change, {
      onSuccess: () => {
        setConfirmStatus(null);
        toast.show({ tone: 'success', title: t(statusDone[change]) });
      },
      onError: (error) => {
        // Changed somewhere else (stale version or a status that no longer
        // fits): show the latest bill and say why nothing happened.
        const stale = isStaleRecordError(error);
        const message = hasErrorCode(error, 'VERSION_CONFLICT')
          ? t('bills.status.changedElsewhere')
          : planningErrorMessage(error, t, formatLocale);
        if (stale) onReload();
        if (change === 'archive') setStatusError(message);
        else
          toast.show({
            tone: stale ? 'warning' : 'danger',
            title: t('bills.status.failed'),
            description: message,
          });
      },
    });
  };

  const editable = bill.owned;
  const archived = bill.status === 'archived';
  const account = accounts.data?.find((item) => item.id === bill.payment_account_id);
  const category = bill.category_id ? categoriesById(categories.data).get(bill.category_id) : null;
  const nextAmount = bill.next_due?.amount ?? bill.expected_amount;
  const occurrences = bill.occurrences;

  return (
    <>
      <BackLink to={paths.bills} label={t('bills.backToList')} />
      <PageHeader
        title={bill.name}
        description={bill.provider_name}
        actions={
          editable ? (
            <>
              {bill.next_due && !archived ? (
                <Button
                  onClick={() => {
                    if (bill.next_due) setPaying(bill.next_due);
                  }}
                >
                  <Icon name="check" className="size-4" />
                  {t('bills.markPaid.action')}
                </Button>
              ) : null}
              <ButtonLink to={billEditPath(bill.id)} variant="secondary">
                <Icon name="pencil" className="size-4" />
                {t('common.edit')}
              </ButtonLink>
              {bill.status === 'active' ? (
                <Button
                  variant="secondary"
                  loading={status.isPending && status.variables === 'pause'}
                  onClick={() => {
                    changeStatus('pause');
                  }}
                >
                  <Icon name="pause" className="size-4" />
                  {t('bills.pause.action')}
                </Button>
              ) : null}
              {bill.status === 'paused' ? (
                <Button
                  variant="secondary"
                  loading={status.isPending && status.variables === 'resume'}
                  onClick={() => {
                    changeStatus('resume');
                  }}
                >
                  <Icon name="play" className="size-4" />
                  {t('bills.resume.action')}
                </Button>
              ) : null}
              {archived ? (
                <Button
                  variant="secondary"
                  loading={status.isPending && status.variables === 'restore'}
                  onClick={() => {
                    changeStatus('restore');
                  }}
                >
                  <Icon name="archive-restore" className="size-4" />
                  {t('bills.restore.action')}
                </Button>
              ) : (
                <Button
                  variant="secondary"
                  onClick={() => {
                    setStatusError(null);
                    setConfirmStatus('archive');
                  }}
                >
                  <Icon name="archive" className="size-4" />
                  {t('bills.archive.action')}
                </Button>
              )}
            </>
          ) : null
        }
      />
      {editable ? null : (
        <Alert tone="info" className="mb-6">
          {t('bills.readOnly')}
        </Alert>
      )}
      <div className="grid items-start gap-6 lg:grid-cols-3">
        <Card title={t('bills.detail.summary')} className="lg:col-span-1">
          <div className="mb-4">
            <BillStateBadge state={bill.state} />
          </div>
          <Facts>
            <Fact label={t('bills.detail.nextDue')}>
              {bill.next_due ? (
                <>
                  {formatLocalDate(bill.next_due.effective_date, formatLocale, 'long')}
                  {' · '}
                  {nextAmount ? (
                    <MoneyText money={nextAmount} className="font-medium" />
                  ) : (
                    t('bills.amountVaries')
                  )}
                </>
              ) : (
                t('bills.detail.nothingDue')
              )}
            </Fact>
            <Fact label={t('bills.detail.lastPaid')}>
              {bill.last_paid ? (
                <>
                  {formatLocalDate(bill.last_paid.effective_date, formatLocale, 'long')}
                  {bill.last_paid.transaction_id ? (
                    <>
                      {' · '}
                      <TextLink to={transactionPath(bill.last_paid.transaction_id)}>
                        {t('bills.detail.viewPayment')}
                      </TextLink>
                    </>
                  ) : null}
                </>
              ) : (
                t('bills.detail.neverPaid')
              )}
            </Fact>
            <Fact label={t('bills.detail.expected')}>
              {bill.expected_amount && !bill.amount_is_variable ? (
                <MoneyText money={bill.expected_amount} />
              ) : (
                t('bills.amountVaries')
              )}
            </Fact>
          </Facts>
        </Card>
        <Card title={t('bills.detail.details')} className="lg:col-span-2">
          <Facts>
            <Fact label={t('bills.detail.repeats')}>
              {describeSchedule(bill.schedule, t, formatLocale)}
            </Fact>
            <Fact label={t('bills.detail.dueTime')}>{bill.schedule.local_time}</Fact>
            <Fact label={t('bills.detail.ends')}>
              {describeEnd(bill.schedule, t, formatLocale)}
            </Fact>
            <Fact label={t('bills.detail.reminders')}>
              {describeReminders(bill.schedule.reminder_days_before, t, formatLocale)}
            </Fact>
            <Fact label={t('bills.detail.account')}>
              {account ? account.name : t('bills.detail.noAccount')}
            </Fact>
            {category ? (
              <Fact label={t('bills.form.category')}>{categoryName(category, t)}</Fact>
            ) : null}
            {bill.provider_name ? (
              <Fact label={t('bills.form.provider')}>{bill.provider_name}</Fact>
            ) : null}
            {bill.notes ? (
              <Fact label={t('bills.form.notes')}>
                <span className="whitespace-pre-line">{bill.notes}</span>
              </Fact>
            ) : null}
          </Facts>
        </Card>
      </div>

      <Card title={t('bills.history.title')} className="mt-6">
        {occurrences.length === 0 ? (
          <p className="text-sm text-fg-muted">{t('bills.history.empty')}</p>
        ) : (
          <ul className="divide-y divide-line">
            {occurrences.map((occurrence) => {
              // Actions name the date it is due (the new date when it was moved).
              const date = formatLocalDate(occurrence.effective_date, formatLocale, 'long');
              const open = isOpenOccurrence(occurrence.status);
              return (
                <li
                  key={occurrence.id}
                  className="flex flex-wrap items-center gap-x-4 gap-y-2 py-3 first:pt-0 last:pb-0"
                >
                  <div className="min-w-0 flex-1 space-y-1">
                    <p className="font-medium text-fg">
                      {formatLocalDate(occurrenceRowDate(occurrence), formatLocale, 'long')}
                    </p>
                    <div className="flex flex-wrap items-center gap-2">
                      <OccurrenceStatusBadge status={occurrence.status} />
                      <MovedBadge occurrence={occurrence} />
                      {occurrence.transaction_id ? (
                        <TextLink
                          to={transactionPath(occurrence.transaction_id)}
                          className="text-sm"
                        >
                          {t('bills.detail.viewPayment')}
                        </TextLink>
                      ) : null}
                    </div>
                  </div>
                  {occurrence.amount ? (
                    <MoneyText money={occurrence.amount} className="font-medium text-fg" />
                  ) : (
                    <span className="text-sm text-fg-muted">{t('bills.amountVaries')}</span>
                  )}
                  {editable && open && !archived ? (
                    <div className="flex gap-2">
                      <Button
                        variant="secondary"
                        size="sm"
                        aria-label={t('bills.history.payFor', { date })}
                        onClick={() => {
                          setPaying(occurrence);
                        }}
                      >
                        {t('bills.markPaid.action')}
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        aria-label={t('bills.history.skipFor', { date })}
                        onClick={() => {
                          setSkipError(null);
                          setSkipping(occurrence);
                        }}
                      >
                        {t('bills.skip.action')}
                      </Button>
                    </div>
                  ) : null}
                  {editable && occurrence.status === 'skipped' && !archived ? (
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label={t('bills.history.undoSkipFor', { date })}
                      loading={reopen.isPending && reopen.variables.id === occurrence.id}
                      onClick={() => {
                        if (reopen.isPending) return;
                        reopen.mutate(occurrence, {
                          onSuccess: () => {
                            idempotency.renew();
                            toast.show({ tone: 'success', title: t('bills.skip.undone') });
                          },
                          onError: (error) => {
                            toast.show({
                              tone: 'danger',
                              title: t('bills.skip.undoFailed'),
                              description: planningErrorMessage(error, t, formatLocale),
                            });
                          },
                        });
                      }}
                    >
                      <Icon name="undo" className="size-4" />
                      {t('bills.skip.undo')}
                    </Button>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </Card>

      {paying ? (
        <MarkPaidFlow
          bill={bill}
          occurrence={paying}
          onClose={() => {
            setPaying(null);
          }}
        />
      ) : null}

      <ConfirmDialog
        open={skipping !== null}
        onOpenChange={(open) => {
          if (!open) setSkipping(null);
        }}
        tone="primary"
        title={t('bills.skip.title')}
        description={
          skipping
            ? t('bills.skip.body', {
                date: formatLocalDate(skipping.effective_date, formatLocale, 'long'),
              })
            : ''
        }
        confirmLabel={t('bills.skip.confirm')}
        pending={skip.isPending}
        error={skipError}
        onConfirm={() => {
          if (!skipping || skip.isPending) return;
          setSkipError(null);
          skip.mutate(skipping, {
            onSuccess: () => {
              setSkipping(null);
              toast.show({ tone: 'success', title: t('bills.skip.done') });
            },
            onError: (error) => {
              setSkipError(planningErrorMessage(error, t, formatLocale));
            },
          });
        }}
      />

      <ConfirmDialog
        open={confirmStatus === 'archive'}
        onOpenChange={(open) => {
          if (!open) setConfirmStatus(null);
        }}
        title={t('bills.archive.title')}
        description={t('bills.archive.body')}
        confirmLabel={t('bills.archive.confirm')}
        pending={status.isPending}
        error={statusError}
        onConfirm={() => {
          changeStatus('archive');
        }}
      />
    </>
  );
}
