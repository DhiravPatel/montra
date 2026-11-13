import { type JSX, useState } from 'react';
import { useSearchParams } from 'react-router';
import { hasErrorCode } from '@/shared/api/errors';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { Disclosure } from '@/shared/components/Disclosure';
import { Icon } from '@/shared/components/Icon';
import { PageHeader } from '@/shared/components/PageHeader';
import { Skeleton } from '@/shared/components/Skeleton';
import { ErrorState, LoadingState, PermissionDenied } from '@/shared/components/states';
import { paths, withQuery } from '@/shared/config/paths';
import { useAccounts, usePreferences } from '@/shared/finance/reference';
import type { DashboardSummary, Widget } from '@/shared/finance/types';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { useDashboardPlanning, useDashboardSummary, useWidgetLayout } from '../api';
import type { PlanningWidgetProps } from '../components/PlanningWidgetCard';
import { DashboardFilters } from '../components/DashboardFilters';
import { WidgetSettingsDialog } from '../components/WidgetSettingsDialog';
import {
  customRangeComplete,
  type DashboardFilters as Filters,
  preferredRange,
  readDashboardFilters,
  toDashboardQuery,
  writeDashboardFilters,
} from '../filters';
import {
  DEFAULT_WIDGET_ORDER,
  isKnownWidget,
  isPlanningWidget,
  type PlanningWidgetKey,
  type SummaryWidgetKey,
  widgetLabels,
} from '../registry';
import { AlertsWidget } from '../widgets/AlertsWidget';
import { BalancesWidget } from '../widgets/BalancesWidget';
import { BudgetsWidget } from '../widgets/BudgetsWidget';
import { CashFlowTrendWidget } from '../widgets/CashFlowTrendWidget';
import { CashFlowWidget } from '../widgets/CashFlowWidget';
import { CategoryBreakdownWidget } from '../widgets/CategoryBreakdownWidget';
import { DataCoverageWidget } from '../widgets/DataCoverageWidget';
import { GoalsWidget } from '../widgets/GoalsWidget';
import { GroupBalancesWidget } from '../widgets/GroupBalancesWidget';
import { IncomeVsExpenseWidget } from '../widgets/IncomeVsExpenseWidget';
import { RecentTransactionsWidget } from '../widgets/RecentTransactionsWidget';
import { RecurringWidget } from '../widgets/RecurringWidget';
import { RenewalsWidget } from '../widgets/RenewalsWidget';
import { TopMerchantsWidget } from '../widgets/TopMerchantsWidget';
import type { WidgetProps } from '../widgets/types';
import { UpcomingWidget } from '../widgets/UpcomingWidget';

/** Widgets computed from the summary (period and filters). */
const summaryComponents: Readonly<Record<SummaryWidgetKey, (props: WidgetProps) => JSX.Element>> = {
  balances: BalancesWidget,
  cash_flow: CashFlowWidget,
  income_vs_expense: IncomeVsExpenseWidget,
  cash_flow_trend: CashFlowTrendWidget,
  category_breakdown: CategoryBreakdownWidget,
  top_merchants: TopMerchantsWidget,
  recent_transactions: RecentTransactionsWidget,
  data_coverage: DataCoverageWidget,
};

/** Widgets drawn from the one planning request (not tied to the period). */
const planningComponents: Readonly<
  Record<PlanningWidgetKey, (props: PlanningWidgetProps) => JSX.Element>
> = {
  alerts: AlertsWidget,
  budgets: BudgetsWidget,
  upcoming: UpcomingWidget,
  renewals: RenewalsWidget,
  recurring: RecurringWidget,
  goals: GoalsWidget,
  group_balances: GroupBalancesWidget,
};

const fallbackLayout: Widget[] = DEFAULT_WIDGET_ORDER.map((key, position) => ({
  key,
  position,
  visible: true,
  settings: {},
}));

type NoteCode = DashboardSummary['note_codes'][number];

/** Typed against the contract enum: a new code fails compilation until it has a message. */
const noteKeys: Readonly<Record<NoteCode, MessageKey>> = {
  excludes_transfers_adjustments: 'dashboard.notes.transfers',
  refunds_reduce_spending: 'dashboard.notes.refunds',
  currencies_separate: 'dashboard.notes.currencies',
  balances_tracked_not_verified: 'dashboard.notes.tracked',
};

function noteKey(code: string): MessageKey | null {
  return Object.hasOwn(noteKeys, code) ? noteKeys[code as NoteCode] : null;
}

/**
 * How the figures are calculated: localized by `note_codes`. A code newer
 * than this client falls back to the API's text at the same position.
 */
function dashboardNotes(summary: DashboardSummary, t: Translate): string[] {
  const texts = summary.notes;
  if (summary.note_codes.length === 0) return texts;
  return summary.note_codes.map((code, index) => {
    const key = noteKey(code);
    return key ? t(key) : (texts[index] ?? code);
  });
}

function DashboardSkeleton() {
  return (
    <div className="grid gap-6" aria-hidden="true">
      <Skeleton className="h-40 w-full" />
      <Skeleton className="h-56 w-full" />
      <Skeleton className="h-72 w-full" />
    </div>
  );
}

/** The computed personal-finance dashboard (spec §4.2, §20B.3). */
export function DashboardPage() {
  const t = useT();
  useDocumentTitle(t('dashboard.title'));
  const user = useCurrentUser();
  const preferences = usePreferences();
  const accounts = useAccounts();
  const layout = useWidgetLayout();
  const [searchParams, setSearchParams] = useSearchParams();
  const [settingsOpen, setSettingsOpen] = useState(false);
  const filters = readDashboardFilters(
    searchParams,
    preferredRange(preferences.data?.default_date_range),
  );
  const rangeReady = customRangeComplete(filters);
  // Wait for the preferred default period before the first computation.
  const summary = useDashboardSummary(
    toDashboardQuery(filters),
    rangeReady && !preferences.isPending,
  );

  const setFilters = (next: Filters) => {
    setSearchParams(writeDashboardFilters(next), { replace: true });
  };

  const widgets = (layout.data ?? (layout.isError ? fallbackLayout : []))
    .filter((widget) => widget.visible && isKnownWidget(widget.key))
    .sort((a, b) => a.position - b.position);
  // One request for every planning card, and only while one of them is shown.
  const planning = useDashboardPlanning(widgets.some((widget) => isPlanningWidget(widget.key)));

  let content;
  if (!rangeReady) {
    content = (
      <Alert tone="info" title={t('dashboard.chooseDates')}>
        {t('dashboard.chooseDatesBody')}
      </Alert>
    );
  } else if (summary.isPending || layout.isPending) {
    content = (
      <LoadingState label={t('dashboard.loading')}>
        <DashboardSkeleton />
      </LoadingState>
    );
  } else if (summary.isError) {
    content = hasErrorCode(summary.error, 'FORBIDDEN') ? (
      <PermissionDenied />
    ) : (
      <ErrorState
        title={t('dashboard.error')}
        error={summary.error}
        description={
          hasErrorCode(summary.error, 'VALIDATION_ERROR') ? t('dashboard.badFilters') : undefined
        }
        retrying={summary.isFetching}
        onRetry={() => {
          void summary.refetch();
        }}
      />
    );
  } else {
    const data = summary.data;
    const drill: WidgetProps['drill'] = (extra = {}) =>
      withQuery(paths.transactions, {
        from: data.window.from,
        to: data.window.to,
        account_id: filters.accountId || undefined,
        // The API refuses `uncategorized` together with a category filter.
        category_id: extra.uncategorized ? undefined : filters.categoryId || undefined,
        ...extra,
      });
    content = (
      <div
        className={cx(
          'grid gap-6 transition-opacity motion-reduce:transition-none',
          summary.isPlaceholderData && 'opacity-60',
        )}
        aria-busy={summary.isFetching || undefined}
      >
        {layout.isError ? (
          <Alert tone="warning" title={t('dashboard.layoutError')}>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                void layout.refetch();
              }}
            >
              {t('common.retry')}
            </Button>
          </Alert>
        ) : null}
        {widgets.length === 0 ? (
          <Card>
            <p className="text-fg-muted">{t('dashboard.allHidden')}</p>
          </Card>
        ) : null}
        {widgets.map((widget) => {
          if (!isKnownWidget(widget.key)) return null;
          const title = t(widgetLabels[widget.key].title);
          if (isPlanningWidget(widget.key)) {
            const Planning = planningComponents[widget.key];
            return <Planning key={widget.key} title={title} planning={planning} />;
          }
          const Component = summaryComponents[widget.key];
          return <Component key={widget.key} summary={data} title={title} drill={drill} />;
        })}
        <Card title={t('dashboard.notes.title')}>
          <Disclosure summary={t('dashboard.notes.show')}>
            <ul className="list-disc space-y-1 ps-5 text-sm text-fg">
              {dashboardNotes(data, t).map((note) => (
                <li key={note}>{note}</li>
              ))}
            </ul>
          </Disclosure>
        </Card>
      </div>
    );
  }

  const noAccounts = accounts.isSuccess && accounts.data.length === 0;

  return (
    <>
      <PageHeader
        title={t('dashboard.title')}
        description={t('dashboard.greeting', { name: user.display_name })}
        actions={
          <>
            <ButtonLink to={paths.transactionNew}>
              <Icon name="plus" className="size-4" />
              {t('transactions.add')}
            </ButtonLink>
            <Button
              variant="secondary"
              disabled={layout.isPending}
              onClick={() => {
                setSettingsOpen(true);
              }}
            >
              <Icon name="sliders" className="size-4" />
              {t('dashboard.customize')}
            </Button>
          </>
        }
      />
      {!user.onboarding_completed ? (
        <Alert tone="info" className="mb-6" title={t('dashboard.setup.title')}>
          <p>{t('dashboard.setup.body')}</p>
          <ButtonLink to={paths.onboarding} size="sm">
            {t('dashboard.setup.action')}
          </ButtonLink>
        </Alert>
      ) : null}
      {noAccounts ? (
        <Card
          className="mb-6"
          title={t('dashboard.firstUse.title')}
          description={t('dashboard.firstUse.body')}
        >
          <div className="flex flex-wrap gap-3">
            <ButtonLink to={paths.accountNew}>
              <Icon name="wallet" className="size-4" />
              {t('accounts.add')}
            </ButtonLink>
          </div>
        </Card>
      ) : null}
      <DashboardFilters
        value={filters}
        onChange={setFilters}
        rangeError={
          filters.range === 'custom' && filters.from && filters.to && filters.from > filters.to
            ? t('validation.dateOrder')
            : undefined
        }
      />
      {content}
      <WidgetSettingsDialog
        open={settingsOpen}
        onOpenChange={setSettingsOpen}
        layout={layout.data ?? fallbackLayout}
      />
    </>
  );
}
