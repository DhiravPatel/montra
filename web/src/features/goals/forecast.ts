import type { GoalForecast } from '@/shared/finance/types';
import type { Translate } from '@/shared/i18n/types';

type AssumptionCode = GoalForecast['assumption_codes'][number];

/*
 * The API explains its forecast with stable codes (`assumption_codes`) and
 * their values (`assumption_params`); the English `assumptions` sentences
 * are only a fallback. Codes are typed against the contract, so a new code
 * fails compilation until it has a sentence here.
 */
function wholeNumber(value: string | undefined, fallback: number): number {
  return value !== undefined && /^\d+$/.test(value) ? Number(value) : fallback;
}

const sentences: Readonly<
  Record<AssumptionCode, (forecast: GoalForecast, t: Translate) => string>
> = {
  exact_amounts_no_growth: (forecast, t) =>
    t('goals.forecast.assumption.exact', {
      currency: forecast.assumption_params.currency ?? forecast.target.currency,
    }),
  recent_pace_window: (forecast, t) =>
    t('goals.forecast.assumption.paceWindow', {
      count: wholeNumber(forecast.assumption_params.window_days, 90),
      months: wholeNumber(forecast.assumption_params.months, 3),
    }),
  planned_not_counted: (_forecast, t) => t('goals.forecast.assumption.planned'),
};

export interface Assumption {
  text: string;
  lang?: string;
}

export function forecastAssumptions(forecast: GoalForecast, t: Translate): Assumption[] {
  const shown = new Set<AssumptionCode>();
  const result: Assumption[] = [];
  for (const code of forecast.assumption_codes) {
    if (shown.has(code)) continue;
    shown.add(code);
    result.push({ text: sentences[code](forecast, t) });
  }
  if (result.length === 0) {
    // An API without codes: show its sentences as sent, marked as English.
    for (const sentence of forecast.assumptions) result.push({ text: sentence, lang: 'en' });
  }
  return result;
}
