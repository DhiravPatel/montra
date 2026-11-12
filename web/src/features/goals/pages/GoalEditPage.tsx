import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { TextLink } from '@/shared/components/TextLink';
import { useToast } from '@/shared/components/toast/ToastContext';
import { goalPath, paths } from '@/shared/config/paths';
import { financeKeys, invalidateFinance } from '@/shared/finance/keys';
import type { GoalPatch } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { goalsApi, useGoal } from '../api';
import { GoalForm } from '../components/GoalForm';
import { goalToValues, toGoalPatch } from '../formValues';

export function GoalEditPage() {
  const { t, formatLocale } = useI18n();
  const { goalId = '' } = useParams();
  useDocumentTitle(t('goals.edit.title'));
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const query = useGoal(goalId);
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (patch: GoalPatch) => goalsApi.update(goalId, patch),
    onSuccess: (goal) => {
      queryClient.setQueryData(financeKeys.goal(goal.id), goal);
      void invalidateFinance(queryClient);
    },
  });

  const backLink = (
    <p className="mb-2">
      <TextLink to={query.data ? goalPath(query.data.id) : paths.goals}>
        <Icon name="arrow-left" className="me-1 inline size-4" />
        {query.data ? query.data.name : t('goals.backToList')}
      </TextLink>
    </p>
  );

  let problem = null;
  if (query.isPending) {
    problem = <LoadingState label={t('goals.detail.loading')} />;
  } else if (query.isError) {
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
  } else if (query.data.access !== 'owner') {
    problem = (
      <PermissionDenied
        titleAs="h2"
        title={t('goals.edit.ownerOnlyTitle')}
        description={t('goals.edit.ownerOnlyBody')}
      />
    );
  }
  if (problem || !query.data) {
    return (
      <>
        {backLink}
        <PageHeader title={t('goals.edit.title')} />
        {problem}
      </>
    );
  }

  const goal = query.data;
  return (
    <>
      {backLink}
      <PageHeader title={t('goals.edit.title')} description={t('goals.edit.contributionsKept')} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-6" title={t('finance.conflict.title')}>
          {t('goals.edit.conflict')}
        </Alert>
      ) : null}
      <Card>
        <GoalForm
          // Remount with the latest values after a version conflict reload.
          key={goal.version}
          mode="edit"
          lockedCurrency={goal.target.currency}
          initialValues={goalToValues(goal, formatLocale)}
          submitLabel={t('goals.edit.submit')}
          secondaryAction={
            <ButtonLink to={goalPath(goal.id)} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onError={(error) => {
            if (!hasErrorCode(error, 'VERSION_CONFLICT')) return false;
            setConflict(true);
            void query.refetch();
            return true;
          }}
          onSubmit={async (values, amounts) => {
            if (update.isPending) return;
            setConflict(false);
            // Only what changed is sent (with the version that was edited).
            const patch = toGoalPatch(values, amounts, goal);
            if (Object.keys(patch).length === 1) {
              toast.show({ tone: 'info', title: t('goals.edit.noChanges') });
              void navigate(goalPath(goal.id));
              return;
            }
            await update.mutateAsync(patch);
            toast.show({ tone: 'success', title: t('goals.edit.done') });
            void navigate(goalPath(goal.id));
          }}
        />
      </Card>
    </>
  );
}
