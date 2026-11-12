import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PageHeader } from '@/shared/components/PageHeader';
import { EmptyState, ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { useToast } from '@/shared/components/toast/ToastContext';
import { paths, recurringPath } from '@/shared/config/paths';
import { invalidateFinance } from '@/shared/finance/keys';
import type { RecurringRuleDetail, RecurringRulePatch } from '@/shared/finance/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useI18n } from '@/shared/i18n/I18nContext';
import { planningApi, useRecurringRule } from '../api';
import { BackLink } from '../components/BackLink';
import { BillScheduleNotice } from '../components/BillScheduleNotice';
import { RecurringRuleForm } from '../components/RecurringRuleForm';
import { ruleToValues } from '../formValues';
import { isEditableKind } from '../labels';
import { isEmptyPatch } from '../patches';

export function RecurringRuleEditPage() {
  const { t } = useI18n();
  useDocumentTitle(t('recurring.edit.title'));
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

  const rule = query.data;
  if (!rule.owned) {
    return (
      <PermissionDenied
        titleAs="h2"
        title={t('recurring.readOnlyTitle')}
        description={t('recurring.readOnly')}
      />
    );
  }
  if (!isEditableKind(rule.kind)) {
    return (
      <>
        <PageHeader title={t('recurring.edit.title')} description={rule.name} />
        <BillScheduleNotice rule={rule} />
      </>
    );
  }
  return (
    <RuleEditor
      rule={rule}
      onReload={() => {
        void query.refetch();
      }}
    />
  );
}

/** Edits send only what changed; the payee comes with the rule (`merchant`). */
function RuleEditor({ rule, onReload }: { rule: RecurringRuleDetail; onReload: () => void }) {
  const { t, formatLocale } = useI18n();
  const toast = useToast();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [conflict, setConflict] = useState(false);
  const update = useMutation({
    mutationFn: (patch: RecurringRulePatch) => planningApi.updateRule(rule.id, patch),
    onSuccess: () => invalidateFinance(queryClient),
  });

  return (
    <>
      <BackLink to={recurringPath(rule.id)} label={t('recurring.backToRule')} />
      <PageHeader title={t('recurring.edit.title')} description={rule.name} />
      {conflict ? (
        <Alert tone="warning" live="assertive" className="mb-6" title={t('finance.conflict.title')}>
          {t('finance.conflict.body')}
        </Alert>
      ) : null}
      <Card>
        <RecurringRuleForm
          // Remount with the latest values after a version conflict reload.
          key={rule.version}
          mode="edit"
          rule={rule}
          initialValues={ruleToValues(rule, formatLocale)}
          submitLabel={t('recurring.edit.submit')}
          secondaryAction={
            <ButtonLink to={recurringPath(rule.id)} variant="ghost">
              {t('common.cancel')}
            </ButtonLink>
          }
          onError={(error) => {
            if (!hasErrorCode(error, 'VERSION_CONFLICT')) return false;
            setConflict(true);
            onReload();
            return true;
          }}
          onSubmit={async (patch) => {
            if (update.isPending) return;
            setConflict(false);
            if (isEmptyPatch(patch)) {
              toast.show({ tone: 'info', title: t('recurring.edit.noChanges') });
              void navigate(recurringPath(rule.id));
              return;
            }
            await update.mutateAsync(patch);
            toast.show({ tone: 'success', title: t('recurring.edit.done') });
            void navigate(recurringPath(rule.id));
          }}
        />
      </Card>
    </>
  );
}
