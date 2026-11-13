import type { UseQueryResult } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { ButtonLink } from '@/shared/components/Button';
import { Icon } from '@/shared/components/Icon';
import { Skeleton } from '@/shared/components/Skeleton';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import type { DashboardPlanning } from '@/shared/finance/types';
import type { PlanningResult } from '../api';
import { WidgetCard } from './WidgetCard';

export interface PlanningWidgetProps {
  title: string;
  /** The one GET /dashboard/planning query shared by every planning card. */
  planning: UseQueryResult<PlanningResult>;
}

interface PlanningWidgetCardProps extends PlanningWidgetProps {
  /** What the card covers, e.g. "Active budgets, fullest first" (null while loading or failed). */
  scopeLabel: (planning: DashboardPlanning | null) => string;
  loadingLabel: string;
  errorTitle: string;
  /** How many exist in all (the API's count, which may exceed the items listed). */
  total: (planning: DashboardPlanning) => number;
  /**
   * e.g. "5 of 7 active budgets" (the items shown and the API's count);
   * omitted when the card lists everything the API counted.
   */
  countText?: (planning: DashboardPlanning) => string;
  /** The full screen and the link text, e.g. "View all 7 budgets". */
  viewAll: { to: string; label: (total: number) => string };
  /** The card's empty state (nothing to show). */
  empty: ReactNode;
  children: (planning: DashboardPlanning) => ReactNode;
}

/**
 * A planning card: loading, permission, error and empty states from the
 * shared query, then the items as the API sent them, a "View all" link to
 * the full screen and the count. Nothing is totalled here.
 */
export function PlanningWidgetCard({
  title,
  planning,
  scopeLabel,
  loadingLabel,
  errorTitle,
  total,
  countText,
  viewAll,
  empty,
  children,
}: PlanningWidgetCardProps) {
  if (planning.isPending) {
    return (
      <WidgetCard title={title} scopeLabel={scopeLabel(null)}>
        <LoadingState label={loadingLabel}>
          <div className="space-y-3" aria-hidden="true">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        </LoadingState>
      </WidgetCard>
    );
  }
  if (planning.isError) {
    return (
      <WidgetCard title={title} scopeLabel={scopeLabel(null)}>
        {hasErrorCode(planning.error, 'FORBIDDEN') ? (
          <PermissionDenied titleAs="p" />
        ) : (
          <ErrorState
            titleAs="p"
            title={errorTitle}
            error={planning.error}
            retrying={planning.isFetching}
            onRetry={() => {
              void planning.refetch();
            }}
          />
        )}
      </WidgetCard>
    );
  }
  const data = planning.data.planning;
  const count = total(data);
  return (
    <WidgetCard title={title} scopeLabel={scopeLabel(data)} generatedAt={planning.data.generatedAt}>
      {count === 0 ? (
        empty
      ) : (
        <>
          {children(data)}
          <div className="mt-4 flex flex-wrap items-center justify-between gap-3 border-t border-line pt-4">
            {countText ? <p className="text-sm text-fg-muted">{countText(data)}</p> : null}
            <ButtonLink
              to={viewAll.to}
              variant="ghost"
              size="sm"
              className={countText ? undefined : 'ms-auto'}
            >
              {viewAll.label(count)}
              <Icon name="arrow-right" className="size-4" />
            </ButtonLink>
          </div>
        </>
      )}
    </WidgetCard>
  );
}
