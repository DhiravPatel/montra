import { Alert } from '@/shared/components/Alert';
import { PageHeader } from '@/shared/components/PageHeader';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { AddRateCard } from '../components/AddRateCard';
import { ConverterCard } from '../components/ConverterCard';
import { RatesCard } from '../components/RatesCard';

/**
 * Exchange rates (spec §4.19, §20B.20): your manual rates and provider
 * rates, and a converter that discloses the rate it used. Rates only affect
 * how amounts are shown or converted; recorded transactions never change.
 */
export function ExchangeRatesPage() {
  const t = useT();
  useDocumentTitle(t('fx.title'));
  return (
    <>
      <PageHeader title={t('fx.title')} description={t('fx.description')} />
      <Alert tone="info" title={t('fx.explain.title')} className="mb-6">
        <p>{t('fx.explain.body')}</p>
        <p>{t('fx.explain.history')}</p>
      </Alert>
      <div className="grid gap-6 lg:grid-cols-2">
        <ConverterCard />
        <AddRateCard />
      </div>
      <div className="mt-6">
        <RatesCard />
      </div>
    </>
  );
}
