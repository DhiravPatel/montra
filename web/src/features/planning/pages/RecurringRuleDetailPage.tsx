import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Fact, Facts } from '@/shared/components/Facts';
import { Icon } from '@/shared/components/Icon';
import { MoneyText } from '@/shared/components/MoneyText';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, recurringEditPath } from '@/shared/config/paths';
import { categoriesById, categoryName } from '@/shared/finance/categories';
import { isStaleRecordError } from '@/shared/finance/domainErrors';
import { invalidateFinance } from '@/shared/finance/keys';
import { useAccounts, useCategories } from '@/shared/finance/reference';
import type { RecurringRuleDetail } from '@/shared/finance/types';
import { formatLocalDate } from '@/shared/formatting/dates';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { type RuleStatusAction, planningApi, useRecurringRule } from '../api';
import { BackLink } from '../components/BackLink';
import { BillScheduleNotice } from '../components/BillScheduleNotice';
import { RuleOccurrences } from '../components/RuleOccurrences';
import { RuleStatusBadge } from '../components/StatusBadges';
import { planningErrorMessage } from '../errors';
import { isEditableKind, recurringKindLabel } from '../labels';
import { describeEnd, describeReminders, describeSchedule } from '../schedule';

type Confirmable = 'skip-next' | 'stop' | 'delete';

const actionDone: Readonly<Record<RuleStatusAction, MessageKey>> = {
  pause: 'recurring.pause.done',
  resume: 'recurring.resume.done',
  stop: 'recurring.stop.done',
  'skip-next': 'recurring.skipNext.done',
};

const confirmCopy = {
  'skip-next': {
    title: 'recurring.skipNext.title',
    confirm: 'recurring.skipNext.confirm',
  },
  stop: { title: 'recurring.stop.title', confirm: 'recurring.stop.confirm' },
  delete: { title: 'recurring.delete.title', confirm: 'recurring.delete.confirm' },
} as const;

/** A recurring item: its schedule, occurrences and lifecycle actions. */
export function RecurringRuleDetailPage() {
  const { t } = useI18n();
  useDocumentTitle(t('recurring.detail.documentTitle'));
  const { ruleId = '' } = useParams();
  const query = useRecurringRule(ruleId);

  if (query.isPending) return <LoadingState label={t('recurring.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="repeat"
          title={t('recurring.detail.notFound')}
          description={t('recurring.detail.notFoundBody')}
          action={<ButtonLink to={paths.recurring}>{t('recurring.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('recurring.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }
  return <RuleDetailView rule={query.data} />;
}

function RuleDetailView({ rule }: { rule: RecurringRuleDetail }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const accounts = useAccounts(true);
  const categories = useCategories(true);
  const [confirming, setConfirming] = useState<Confirmable | null>(null);
  const [confirmError, setConfirmError] = useState<string | null>(null);

  // Lifecycle actions send the version on screen; finance data (this rule
  // included) is refreshed when they settle, so a stale screen updates.
  const action = useMutation({
    mutationFn: (next: RuleStatusAction) => planningApi.ruleAction(rule.id, next, rule.version),
    onSettled: () => invalidateFinance(queryClient),
  });
  const remove = useMutation({
    mutationFn: () => planningApi.deleteRule(rule.id),
    onSettled: () => invalidateFinance(queryClient),
  });

  const managed = !isEditableKind(rule.kind);
  const editable = rule.owned && !managed;
  const pending = action.isPending || remove.isPending;
  const accountName = (id?: string) =>
    id ? (accounts.data?.find((account) => account.id === id)?.name ?? null) : null;
  const category = rule.category_id ? categoriesById(categories.data).get(rule.category_id) : null;
  const nextDate = rule.next_occurrence
    ? formatLocalDate(rule.next_occurrence, formatLocale, 'long')
    : null;

  const run = (next: RuleStatusAction) => {
    if (pending) return;
    setConfirmError(null);
    action.mutate(next, {
      onSuccess: () => {
        setConfirming(null);
        toast.show({ tone: 'success', title: t(actionDone[next]) });
      },
      onError: (error) => {
        const message = planningErrorMessage(error, t, formatLocale);
        if (next === 'stop' || next === 'skip-next') setConfirmError(message);
        else
          toast.show({
            tone: isStaleRecordError(error) ? 'warning' : 'danger',
            title: t('recurring.actionFailed'),
            description: message,
          });
      },
    });
  };

  const confirm = () => {
    if (!confirming) return;
    if (confirming !== 'delete') {
      run(confirming);
      return;
    }
    if (pending) return;
    setConfirmError(null);
    remove.mutate(undefined, {
      onSuccess: (result) => {
        setConfirming(null);
        if (result.outcome === 'deleted') {
          toast.show({ tone: 'success', title: t('recurring.delete.deleted') });
          void navigate(paths.recurring);
        } else {
          toast.show({ tone: 'success', title: t('recurring.delete.ended') });
        }
      },
      onError: (error) => {
        setConfirmError(planningErrorMessage(error, t, formatLocale));
      },
    });
  };

  const confirmBody =
    confirming === 'skip-next'
      ? nextDate
        ? t('recurring.skipNext.body', { date: nextDate })
        : t('recurring.skipNext.bodyNoDate')
      : confirming === 'stop'
        ? t('recurring.stop.body')
        : t('recurring.delete.body');

  return (
    <>
      <BackLink to={paths.recurring} label={t('recurring.backToList')} />
      <PageHeader
        title={rule.name}
        description={t(recurringKindLabel[rule.kind])}
        actions={
          editable ? (
            <>
              <ButtonLink to={recurringEditPath(rule.id)} variant="secondary">
                <Icon name="pencil" className="size-4" />
                {t('common.edit')}
              </ButtonLink>
              {rule.status === 'active' ? (
                <>
                  <Button
                    variant="secondary"
                    onClick={() => {
                      setConfirmError(null);
                      setConfirming('skip-next');
                    }}
                  >
                    <Icon name="skip-forward" className="size-4" />
                    {t('recurring.skipNext.action')}
                  </Button>
                  <Button
                    variant="secondary"
                    loading={action.isPending && action.variables === 'pause'}
                    onClick={() => {
                      run('pause');
                    }}
                  >
                    <Icon name="pause" className="size-4" />
                    {t('recurring.pause.action')}
                  </Button>
                </>
              ) : null}
              {rule.status === 'paused' ? (
                <Button
                  variant="secondary"
                  loading={action.isPending && action.variables === 'resume'}
                  onClick={() => {
                    run('resume');
                  }}
                >
                  <Icon name="play" className="size-4" />
                  {t('recurring.resume.action')}
                </Button>
              ) : null}
              {rule.status === 'ended' ? null : (
                <Button
                  variant="secondary"
                  onClick={() => {
                    setConfirmError(null);
                    setConfirming('stop');
                  }}
                >
                  <Icon name="flag" className="size-4" />
                  {t('recurring.stop.action')}
                </Button>
              )}
              <Button
                variant="secondary"
                onClick={() => {
                  setConfirmError(null);
                  setConfirming('delete');
                }}
              >
                <Icon name="trash" className="size-4" />
                {t('recurring.delete.action')}
              </Button>
            </>
          ) : null
        }
      />
      {managed ? <BillScheduleNotice rule={rule} /> : null}
      {!rule.owned ? (
        <Alert tone="info" className="mb-6">
          {t('recurring.readOnly')}
        </Alert>
      ) : null}
      <div className="grid items-start gap-6 lg:grid-cols-3">
        <Card title={t('recurring.detail.summary')}>
          <div className="mb-4 flex flex-wrap gap-2">
            <RuleStatusBadge status={rule.status} />
          </div>
          <Facts>
            <Fact label={t('recurring.detail.amount')}>
              {rule.amount && !rule.amount_is_variable ? (
                <MoneyText money={rule.amount} className="font-medium" />
              ) : (
                t('recurring.amountVaries')
              )}
            </Fact>
            <Fact label={t('recurring.detail.next')}>{nextDate ?? t('recurring.noNext')}</Fact>
            <Fact label={t('recurring.detail.completed')}>
              {t('recurring.detail.completedCount', { count: rule.completed_count })}
            </Fact>
            <Fact label={t('recurring.detail.autoPost')}>
              {rule.auto_post
                ? t('recurring.detail.autoPostOn')
                : t('recurring.detail.autoPostOff')}
            </Fact>
          </Facts>
        </Card>
        <Card title={t('recurring.detail.details')} className="lg:col-span-2">
          <Facts>
            <Fact label={t('recurring.detail.repeats')}>
              {describeSchedule(rule, t, formatLocale)}
            </Fact>
            <Fact label={t('recurring.detail.dueTime')}>{rule.local_time}</Fact>
            <Fact label={t('recurring.detail.ends')}>{describeEnd(rule, t, formatLocale)}</Fact>
            <Fact label={t('recurring.detail.reminders')}>
              {describeReminders(rule.reminder_days_before, t, formatLocale)}
            </Fact>
            <Fact
              label={
                rule.kind === 'transfer'
                  ? t('recurring.form.fromAccount')
                  : t('recurring.form.account')
              }
            >
              {accountName(rule.account_id) ?? t('recurring.detail.noAccount')}
            </Fact>
            {rule.kind === 'transfer' ? (
              <Fact label={t('recurring.form.toAccount')}>
                {accountName(rule.to_account_id) ?? t('recurring.detail.noAccount')}
              </Fact>
            ) : null}
            {category ? (
              <Fact label={t('recurring.form.category')}>{categoryName(category, t)}</Fact>
            ) : null}
            {rule.merchant ? (
              <Fact
                label={
                  rule.kind === 'income' ? t('recurring.form.payer') : t('recurring.form.payee')
                }
              >
                {rule.merchant.name}
              </Fact>
            ) : null}
            {rule.description ? (
              <Fact label={t('recurring.form.description')}>{rule.description}</Fact>
            ) : null}
            {rule.notes ? (
              <Fact label={t('recurring.form.notes')}>
                <span className="whitespace-pre-line">{rule.notes}</span>
              </Fact>
            ) : null}
          </Facts>
        </Card>
      </div>

      <Card
        title={t('recurring.occurrences.title')}
        description={t('recurring.occurrences.description')}
        className="mt-6"
      >
        <RuleOccurrences rule={rule} editable={editable} />
      </Card>

      <ConfirmDialog
        open={confirming !== null}
        onOpenChange={(open) => {
          if (!open) setConfirming(null);
        }}
        tone={confirming === 'skip-next' ? 'primary' : 'danger'}
        title={confirming ? t(confirmCopy[confirming].title) : ''}
        description={confirmBody}
        confirmLabel={confirming ? t(confirmCopy[confirming].confirm) : ''}
        pending={pending}
        error={confirmError}
        onConfirm={confirm}
      />
    </>
  );
}
