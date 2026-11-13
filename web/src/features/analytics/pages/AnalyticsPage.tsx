import type { JSX } from 'react';
import { useSearchParams } from 'react-router';
import { Alert } from '@/shared/components/Alert';
import { PageHeader } from '@/shared/components/PageHeader';
import { usePreferences } from '@/shared/finance/reference';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { AnalyticsFilterBar } from '../components/AnalyticsFilterBar';
import { AnalyticsTabs } from '../components/AnalyticsTabs';
import {
  type AnalyticsFilters,
  type AnalyticsView,
  PERIOD_VIEWS,
  periodReady,
  preferredRange,
  readAnalyticsFilters,
  writeAnalyticsFilters,
} from '../filters';
import { AccountsView } from '../views/AccountsView';
import { CashFlowView, type ViewProps } from '../views/CashFlowView';
import { CategoriesView } from '../views/CategoriesView';
import { CompareView } from '../views/CompareView';
import { MerchantsView } from '../views/MerchantsView';
import { PaymentMethodsView } from '../views/PaymentMethodsView';
import { PlansView } from '../views/PlansView';

const periodViews: Readonly<
  Record<Exclude<AnalyticsView, 'plans'>, (props: ViewProps) => JSX.Element>
> = {
  'cash-flow': CashFlowView,
  categories: CategoriesView,
  merchants: MerchantsView,
  'payment-methods': PaymentMethodsView,
  compare: CompareView,
  accounts: AccountsView,
};

/**
 * The analytics workspace (spec §4.11, §20B.12): one period and filter row
 * for cash flow, categories, merchants and period comparisons, plus account
 * balances and plan summaries. Every figure comes from the API, per currency.
 */
export function AnalyticsPage() {
  const t = useT();
  useDocumentTitle(t('analytics.title'));
  const preferences = usePreferences();
  const [searchParams, setSearchParams] = useSearchParams();
  const filters = readAnalyticsFilters(
    searchParams,
    preferredRange(preferences.data?.default_date_range),
  );
  // Without a period in the address, wait for the preferred default period
  // so the figures are not computed twice.
  const explicitPeriod = searchParams.has('range') || searchParams.has('from');
  const enabled = explicitPeriod || !preferences.isPending;
  const ready = periodReady(filters);

  const setFilters = (next: AnalyticsFilters) => {
    setSearchParams(writeAnalyticsFilters(next), { replace: true });
  };

  let content;
  if (filters.view === 'plans') {
    content = <PlansView />;
  } else if (PERIOD_VIEWS.has(filters.view) && !ready) {
    content = (
      <Alert tone="info" title={t('analytics.chooseDates')}>
        {t('analytics.chooseDatesBody')}
      </Alert>
    );
  } else {
    const View = periodViews[filters.view];
    content = <View filters={filters} onChange={setFilters} enabled={enabled} />;
  }

  return (
    <>
      <PageHeader title={t('analytics.title')} description={t('analytics.description')} />
      <AnalyticsTabs filters={filters} />
      {PERIOD_VIEWS.has(filters.view) ? (
        <AnalyticsFilterBar value={filters} onChange={setFilters} />
      ) : null}
      {content}
    </>
  );
}
