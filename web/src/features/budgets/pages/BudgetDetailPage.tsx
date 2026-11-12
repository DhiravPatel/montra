import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { useToast } from '@/shared/components/toast/ToastContext';
import { budgetEditPath, paths } from '@/shared/config/paths';
import { financeErrorMessage, isStaleRecordError } from '@/shared/finance/domainErrors';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type BudgetStatusAction, budgetsApi, useBudget } from '../api';
import { BudgetAlertsCard } from '../components/BudgetAlertsCard';
import { BudgetAllocationsCard } from '../components/BudgetAllocationsCard';
import { BudgetHistoryCard } from '../components/BudgetHistoryCard';
import { BudgetMembersCard } from '../components/BudgetMembersCard';
import { BudgetProgressCard } from '../components/BudgetProgressCard';
import { BudgetTransactionsCard } from '../components/BudgetTransactionsCard';
import { accessLabel, budgetStatusLabel, budgetTypeLabel, periodLabel } from '../labels';

interface StatusChange {
  action: BudgetStatusAction;
  /** The version on screen: a concurrent change answers 409 VERSION_CONFLICT. */
  version: number;
}

/** One budget: progress, history, what was counted, sharing and alerts. */
export function BudgetDetailPage() {
  const { t, formatLocale } = useI18n();
  const { budgetId = '' } = useParams();
  // The title never carries the budget's name (spec §20B.23).
  useDocumentTitle(t('budgets.detail.title'));
  const toast = useToast();
  const queryClient = useQueryClient();
  const query = useBudget(budgetId);
  const [historyDate, setHistoryDate] = useState('');
  const [archiving, setArchiving] = useState(false);
  const [archiveError, setArchiveError] = useState<string | null>(null);
  const status = useMutation({
    mutationFn: ({ action, version }: StatusChange) =>
      budgetsApi.setStatus(budgetId, action, version),
    onSuccess: (budget) => {
      queryClient.setQueryData(financeKeys.budget(budget.id), budget);
      void invalidateFinance(queryClient);
    },
  });

  if (query.isPending) return <LoadingState label={t('budgets.detail.loading')} />;
  if (query.isError) {
    if (hasErrorCode(query.error, 'NOT_FOUND')) {
      return (
        <EmptyState
          titleAs="h2"
          icon="pie-chart"
          title={t('budgets.notFound')}
          description={t('budgets.notFoundBody')}
          action={<ButtonLink to={paths.budgets}>{t('budgets.backToList')}</ButtonLink>}
        />
      );
    }
    if (hasErrorCode(query.error, 'FORBIDDEN')) return <PermissionDenied titleAs="h2" />;
    return (
      <ErrorState
        titleAs="h2"
        title={t('budgets.detail.error')}
        error={query.error}
        retrying={query.isFetching}
        onRetry={() => {
          void query.refetch();
        }}
      />
    );
  }

  const budget = query.data;
  const archived = budget.status === 'archived';
  const editor = budget.access !== 'viewer';
  const canChange = editor && !archived;
  const done: Record<BudgetStatusAction, string> = {
    pause: t('budgets.paused'),
    resume: t('budgets.resumed'),
    archive: t('budgets.archived'),
    restore: t('budgets.restored'),
  };
  const pendingAction = status.isPending ? status.variables.action : null;

  const act = (action: BudgetStatusAction) => {
    if (status.isPending) return;
    setArchiveError(null);
    status.mutate(
      { action, version: budget.version },
      {
        onSuccess: () => {
          toast.show({ tone: 'success', title: done[action] });
          setArchiving(false);
        },
        onError: (error) => {
          const stale = isStaleRecordError(error);
          // Changed somewhere else: show the budget as it is now.
          if (stale) void query.refetch();
          const message = hasErrorCode(error, 'FORBIDDEN')
            ? t('budgets.form.forbidden')
            : hasErrorCode(error, 'VERSION_CONFLICT')
              ? t('budgets.statusChangedElsewhere')
              : financeErrorMessage(error, t, formatLocale);
          if (action === 'archive' && !stale) {
            setArchiveError(message);
            return;
          }
          setArchiving(false);
          toast.show({
            tone: stale ? 'warning' : 'danger',
            title: stale ? t('finance.conflict.title') : t('budgets.statusFailed'),
            description: message,
          });
        },
      },
    );
  };

  return (
    <>
      <PageHeader
        title={budget.name}
        description={`${t(budgetTypeLabel[budget.budget_type])} · ${t(periodLabel[budget.period])}`}
        actions={
          canChange ? (
            <>
              <ButtonLink to={budgetEditPath(budget.id)} variant="secondary">
                <Icon name="pencil" className="size-4" />
                {t('common.edit')}
              </ButtonLink>
              {budget.status === 'paused' ? (
                <Button
                  variant="secondary"
                  loading={pendingAction === 'resume'}
                  onClick={() => {
                    act('resume');
                  }}
                >
                  <Icon name="play" className="size-4" />
                  {t('budgets.resume')}
                </Button>
              ) : (
                <Button
                  variant="secondary"
                  loading={pendingAction === 'pause'}
                  onClick={() => {
                    act('pause');
                  }}
                >
                  <Icon name="pause" className="size-4" />
                  {t('budgets.pause')}
                </Button>
              )}
              <Button
                variant="secondary"
                onClick={() => {
                  setArchiveError(null);
                  setArchiving(true);
                }}
              >
                <Icon name="archive" className="size-4" />
                {t('budgets.archive')}
              </Button>
            </>
          ) : editor && archived ? (
            <Button
              variant="secondary"
              loading={pendingAction === 'restore'}
              onClick={() => {
                act('restore');
              }}
            >
              <Icon name="archive-restore" className="size-4" />
              {t('budgets.restore')}
            </Button>
          ) : null
        }
      />
      <div className="space-y-6">
        {budget.status !== 'active' || budget.access !== 'owner' ? (
          <div className="flex flex-wrap gap-2">
            {budget.status !== 'active' ? (
              <StatusBadge tone="neutral" icon={budget.status === 'paused' ? 'pause' : 'archive'}>
                {t(budgetStatusLabel[budget.status])}
              </StatusBadge>
            ) : null}
            {budget.access !== 'owner' ? (
              <StatusBadge tone="info" icon="users">
                {t('budgets.sharedBy', {
                  name: budget.owner_display_name,
                  access: t(accessLabel[budget.access]),
                })}
              </StatusBadge>
            ) : null}
          </div>
        ) : null}
        {archived ? (
          <Alert tone="info">
            {editor ? t('budgets.detail.archivedRestore') : t('budgets.detail.archivedNotice')}
          </Alert>
        ) : null}
        {budget.status === 'paused' ? (
          <Alert tone="info">{t('budgets.detail.pausedNotice')}</Alert>
        ) : null}
        {budget.access === 'viewer' ? (
          <Alert tone="info" title={t('budgets.readOnlyTitle')}>
            {t('budgets.readOnlyBody')}
          </Alert>
        ) : null}
        <BudgetProgressCard budget={budget} />
        {budget.allocations.length > 0 ? <BudgetAllocationsCard budget={budget} /> : null}
        <BudgetHistoryCard budget={budget} date={historyDate} onDateChange={setHistoryDate} />
        <BudgetTransactionsCard budget={budget} date={historyDate} />
        <BudgetAlertsCard budgetId={budget.id} />
        <BudgetMembersCard budget={budget} />
        {budget.notes ? (
          <Card title={t('budgets.form.notes')}>
            <p className="text-sm whitespace-pre-line text-fg">{budget.notes}</p>
          </Card>
        ) : null}
      </div>
      <ConfirmDialog
        open={archiving}
        onOpenChange={setArchiving}
        title={t('budgets.archiveTitle')}
        description={t('budgets.archiveBody', { name: budget.name })}
        confirmLabel={t('budgets.archive')}
        onConfirm={() => {
          act('archive');
        }}
        pending={pendingAction === 'archive'}
        error={archiveError}
      />
    </>
  );
}
