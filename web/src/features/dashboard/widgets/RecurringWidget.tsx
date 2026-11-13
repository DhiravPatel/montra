import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { EmptyState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { CommitmentList } from '@/features/planning/components/CommitmentList';
import { PlanningWidgetCard, type PlanningWidgetProps } from '../components/PlanningWidgetCard';

/**
 * Active recurring commitments as monthly equivalents per kind and
 * currency (as GET /analytics/recurring computes them), with what the
 * figures count, localized from `recurring_note_code`.
 */
export function RecurringWidget({ title, planning }: PlanningWidgetProps) {
  const t = useT();
  return (
    <PlanningWidgetCard
      title={title}
      planning={planning}
      scopeLabel={() => t('dashboard.recurring.scope')}
      loadingLabel={t('dashboard.recurring.loading')}
      errorTitle={t('dashboard.recurring.error')}
      // Every kind and currency is listed, so there is no "x of y" count.
      total={(data) => data.recurring.length}
      viewAll={{
        to: paths.recurring,
        label: () => t('dashboard.recurring.viewAll'),
      }}
      empty={
        <EmptyState
          titleAs="p"
          icon="repeat"
          title={t('dashboard.recurring.empty')}
          description={t('dashboard.recurring.emptyBody')}
          action={
            <ButtonLink to={paths.recurringNew} variant="secondary">
              <Icon name="plus" className="size-4" />
              {t('dashboard.recurring.add')}
            </ButtonLink>
          }
        />
      }
    >
      {(data) => (
        <CommitmentList commitments={data.recurring} noteCode={data.recurring_note_code} />
      )}
    </PlanningWidgetCard>
  );
}
