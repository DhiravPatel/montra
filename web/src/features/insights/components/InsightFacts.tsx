import { Fact, Facts } from '@/shared/components/Facts';
import { MoneyText } from '@/shared/components/MoneyText';
import { formatLocalDate, formatLocalDateRange } from '@/shared/formatting/dates';
import { useI18n } from '@/shared/i18n/I18nContext';
import { type FactValue, insightFacts, insightPeriods, type MoneyValue } from '../evidence';
import { ruleLabel } from '../labels';
import type { Insight } from '../types';

function FactValueText({ value }: { value: FactValue }) {
  const { t, formatLocale } = useI18n();
  switch (value.type) {
    case 'money':
      return <MoneyText money={value.money} />;
    case 'text':
      return value.text;
    case 'number':
      return new Intl.NumberFormat(formatLocale).format(value.value);
    case 'days':
      return t('insights.fact.daysValue', { count: value.count });
    case 'months':
      return t('insights.fact.monthsValue', { count: value.count });
    case 'percent':
      return t('insights.fact.percentValue', { value: value.value });
    case 'perWeek':
      return t('insights.fact.perWeekValue', { value: value.value });
    case 'date':
      return formatLocalDate(value.date, formatLocale);
  }
}

function Amount({ money }: { money: MoneyValue | null }) {
  return money ? <MoneyText money={money} /> : <span aria-hidden="true">—</span>;
}

/**
 * The evidence behind an insight: the period, every number the rule used
 * (amounts exactly as the server sent them, each with its own currency),
 * how sure the rule is, and the rule itself.
 */
export function InsightFacts({ insight }: { insight: Insight }) {
  const { t, formatLocale } = useI18n();
  const rule = ruleLabel(insight.rule_code);
  // The rule in the interface language when known; the server's own words otherwise.
  const facts = insightFacts(insight).map((fact) =>
    fact.key === 'rule' && rule
      ? { ...fact, value: { type: 'text' as const, text: t(rule) } }
      : fact,
  );
  const periods = insightPeriods(insight);
  return (
    <div className="space-y-5">
      <Facts>
        {insight.period_start && insight.period_end ? (
          <Fact label={t('finance.range.label')}>
            {formatLocalDateRange(insight.period_start, insight.period_end, formatLocale)}
          </Fact>
        ) : null}
        {facts.map((fact) => (
          <Fact key={fact.key} label={fact.labelKey ? t(fact.labelKey) : fact.fallbackLabel}>
            <FactValueText value={fact.value} />
          </Fact>
        ))}
        {typeof insight.confidence === 'number' ? (
          <Fact label={t('insights.facts.confidence')}>
            {new Intl.NumberFormat(formatLocale, {
              style: 'percent',
              maximumFractionDigits: 0,
            }).format(insight.confidence)}
          </Fact>
        ) : null}
        <Fact label={t('insights.facts.source')}>
          {insight.source === 'rules'
            ? t('insights.facts.source.rules')
            : t('insights.facts.source.other')}
        </Fact>
      </Facts>
      {periods.length > 0 ? (
        <div className="overflow-x-auto">
          <table className="w-full min-w-80 text-sm">
            <caption className="mb-2 text-start font-medium text-fg">
              {t('insights.periods.caption')}
            </caption>
            <thead>
              <tr className="border-b border-line text-fg-muted">
                <th scope="col" className="py-2 pe-4 text-start font-medium">
                  {t('finance.range.label')}
                </th>
                <th scope="col" className="py-2 pe-4 text-end font-medium">
                  {t('budgets.detail.limit')}
                </th>
                <th scope="col" className="py-2 text-end font-medium">
                  {t('budgets.detail.spent')}
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {periods.map((row) => (
                <tr key={`${row.start}-${row.end}`}>
                  <th scope="row" className="py-2 pe-4 text-start font-normal text-fg">
                    {formatLocalDateRange(row.start, row.end, formatLocale)}
                  </th>
                  <td className="py-2 pe-4 text-end">
                    <Amount money={row.limit} />
                  </td>
                  <td className="py-2 text-end">
                    <Amount money={row.spent} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}
    </div>
  );
}
