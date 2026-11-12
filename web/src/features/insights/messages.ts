import { formatLocalDate, isLocalDate } from '@/shared/formatting/dates';
import { formatMoney } from '@/shared/formatting/money';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { parseMoneyText, readMoney } from './evidence';
import type { Insight } from './types';

/*
 * Insights carry `message_code` and `message_params` so the title and body
 * can be shown in the interface language (docs/API.md "AI and insights
 * notes"). Each known code has a template whose placeholders are filled
 * from the params: Money objects are formatted exactly as the server sent
 * them, dates and months in the user's locale, counts as numbers. When a
 * code is unknown, or a value the template needs is missing, the English
 * title and body from the server are shown unchanged.
 */

type ParamType =
  'money' | 'text' | 'count' | 'decimal' | 'signedDecimal' | 'date' | 'month' | 'frequency';

interface MessagePart {
  key: MessageKey;
  /** Placeholders of the template and how to read them from message_params. */
  params: Readonly<Record<string, ParamType>>;
}

interface MessageSpec {
  title: MessagePart;
  body: MessagePart;
  /** Used for the body when one of its params is absent (optional values). */
  bodyFallback?: MessagePart;
}

const SPECS: Readonly<Record<string, MessageSpec>> = {
  unusual_amount: {
    title: { key: 'insights.message.unusual_amount.title', params: { category_name: 'text' } },
    body: {
      key: 'insights.message.unusual_amount.body',
      params: {
        amount: 'money',
        label: 'text',
        local_date: 'date',
        ratio: 'decimal',
        category_name: 'text',
        baseline_median: 'money',
        history_count: 'count',
        window_months: 'count',
      },
    },
  },
  category_spike: {
    title: { key: 'insights.message.category_spike.title', params: { category_name: 'text' } },
    body: {
      key: 'insights.message.category_spike.body',
      params: {
        so_far: 'money',
        category_name: 'text',
        monthly_average: 'money',
        months_compared: 'count',
      },
    },
  },
  new_merchant_large: {
    title: { key: 'insights.message.new_merchant_large.title', params: { merchant_name: 'text' } },
    body: {
      key: 'insights.message.new_merchant_large.body',
      params: {
        amount: 'money',
        merchant_name: 'text',
        local_date: 'date',
        typical_expense: 'money',
      },
    },
  },
  possible_duplicate: {
    title: { key: 'insights.message.possible_duplicate.title', params: { label: 'text' } },
    body: {
      key: 'insights.message.possible_duplicate.body',
      params: { amount: 'money', label: 'text', first_date: 'date', second_date: 'date' },
    },
  },
  subscription_price_increase: {
    title: { key: 'insights.message.subscription_price_increase.title', params: { name: 'text' } },
    body: {
      key: 'insights.message.subscription_price_increase.body',
      params: {
        name: 'text',
        old: 'money',
        new: 'money',
        billing_frequency: 'frequency',
        percent: 'decimal',
        local_date: 'date',
      },
    },
  },
  missing_recurring_payment: {
    title: { key: 'insights.message.missing_recurring_payment.title', params: { name: 'text' } },
    body: {
      key: 'insights.message.missing_recurring_payment.body',
      params: { name: 'text', amount: 'money', due: 'date' },
    },
    bodyFallback: {
      key: 'insights.message.missing_recurring_payment.bodyNoAmount',
      params: { name: 'text', due: 'date' },
    },
  },
  cash_flow_change_spending: {
    title: { key: 'insights.message.cash_flow_change.title', params: {} },
    body: {
      key: 'insights.message.cash_flow_change_spending.body',
      params: {
        month: 'month',
        spending: 'money',
        usual_spending: 'money',
        months_compared: 'count',
      },
    },
  },
  cash_flow_change_income: {
    title: { key: 'insights.message.cash_flow_change.title', params: {} },
    body: {
      key: 'insights.message.cash_flow_change_income.body',
      params: { month: 'month', income: 'money', usual_income: 'money', months_compared: 'count' },
    },
  },
  cash_flow_change_both: {
    title: { key: 'insights.message.cash_flow_change.title', params: {} },
    body: {
      key: 'insights.message.cash_flow_change_both.body',
      params: {
        month: 'month',
        spending: 'money',
        usual_spending: 'money',
        income: 'money',
        usual_income: 'money',
        months_compared: 'count',
      },
    },
  },
  subscription_costs: {
    title: {
      key: 'insights.message.subscription_costs.title',
      params: { count: 'count', monthly: 'money' },
    },
    body: { key: 'insights.message.subscription_costs.body', params: { yearly: 'money' } },
  },
  unusual_frequency: {
    title: { key: 'insights.message.unusual_frequency.title', params: { merchant_name: 'text' } },
    body: {
      key: 'insights.message.unusual_frequency.body',
      params: {
        recent_count: 'count',
        merchant_name: 'text',
        window_days: 'count',
        baseline_weekly_average: 'decimal',
        baseline_weeks: 'count',
      },
    },
  },
  recurring_amount_change_higher: {
    title: {
      key: 'insights.message.recurring_amount_change_higher.title',
      params: { name: 'text' },
    },
    body: {
      key: 'insights.message.recurring_amount_change.body',
      params: {
        name: 'text',
        amount: 'money',
        local_date: 'date',
        usual_amount: 'money',
        history_count: 'count',
        change_percent: 'signedDecimal',
      },
    },
  },
  recurring_amount_change_lower: {
    title: {
      key: 'insights.message.recurring_amount_change_lower.title',
      params: { name: 'text' },
    },
    body: {
      key: 'insights.message.recurring_amount_change.body',
      params: {
        name: 'text',
        amount: 'money',
        local_date: 'date',
        usual_amount: 'money',
        history_count: 'count',
        change_percent: 'signedDecimal',
      },
    },
  },
  repeated_budget_overspend: {
    title: {
      key: 'insights.message.repeated_budget_overspend.title',
      params: { budget_name: 'text', over_count: 'count', periods: 'count' },
    },
    body: {
      key: 'insights.message.repeated_budget_overspend.body',
      params: {
        periods: 'count',
        average_spent: 'money',
        limit: 'money',
        average_overspend: 'money',
      },
    },
  },
};

const frequencyLabel: Readonly<Record<string, MessageKey>> = {
  weekly: 'subscriptions.frequency.weekly',
  monthly: 'subscriptions.frequency.monthly',
  quarterly: 'subscriptions.frequency.quarterly',
  semiannual: 'subscriptions.frequency.semiannual',
  yearly: 'subscriptions.frequency.yearly',
  custom: 'subscriptions.frequency.custom',
};

const DECIMAL = /^[+-]?\d+(?:\.\d+)?$/;
const MONTH = /^(\d{4})-(\d{2})$/;

/** "2026-10" as "October 2026" in the user's locale; null when malformed. */
export function formatMonth(value: string, locale: string): string | null {
  const match = MONTH.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (month < 1 || month > 12) return null;
  return new Intl.DateTimeFormat(locale, {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(Date.UTC(year, month - 1, 1)));
}

function decimalOf(raw: unknown): number | null {
  if (typeof raw === 'number') return Number.isFinite(raw) ? raw : null;
  if (typeof raw === 'string' && DECIMAL.test(raw.trim())) return Number(raw.trim());
  return null;
}

interface Context {
  t: Translate;
  locale: string;
}

/** One placeholder value in the interface language; null when the param is unusable. */
function readParam(raw: unknown, type: ParamType, { t, locale }: Context): string | number | null {
  switch (type) {
    case 'money': {
      const value = readMoney(raw) ?? parseMoneyText(raw);
      if (!value) return null;
      try {
        return formatMoney(value.amount, value.currency, locale);
      } catch {
        return `${value.amount} ${value.currency}`;
      }
    }
    case 'text':
      return typeof raw === 'string' && raw.trim() ? raw.trim() : null;
    case 'count': {
      const value = decimalOf(raw);
      return value !== null && Number.isInteger(value) && value >= 0 ? value : null;
    }
    case 'decimal':
      return decimalOf(raw);
    case 'signedDecimal': {
      const value = decimalOf(raw);
      if (value === null) return null;
      return new Intl.NumberFormat(locale, { signDisplay: 'exceptZero' }).format(value);
    }
    case 'date':
      return typeof raw === 'string' && isLocalDate(raw) ? formatLocalDate(raw, locale) : null;
    case 'month':
      return typeof raw === 'string' ? formatMonth(raw, locale) : null;
    case 'frequency': {
      const key = typeof raw === 'string' ? frequencyLabel[raw] : undefined;
      return key ? t(key) : null;
    }
  }
}

function fill(
  part: MessagePart,
  params: Readonly<Record<string, unknown>>,
  context: Context,
): string | null {
  const values: Record<string, string | number> = {};
  for (const [name, type] of Object.entries(part.params)) {
    const value = readParam(params[name], type, context);
    if (value === null) return null;
    values[name] = value;
  }
  return context.t(part.key, values);
}

export interface InsightText {
  title: string;
  body: string;
  /** False when the server's English text is shown (no or unknown code, or missing values). */
  localized: boolean;
}

/** The title and body of an insight in the interface language, or the server's English text. */
export function insightText(insight: Insight, t: Translate, locale: string): InsightText {
  const english: InsightText = { title: insight.title, body: insight.body, localized: false };
  const spec = insight.message_code ? SPECS[insight.message_code] : undefined;
  if (!spec) return english;
  const params: Readonly<Record<string, unknown>> = insight.message_params ?? {};
  const context = { t, locale };
  const title = fill(spec.title, params, context);
  const body =
    fill(spec.body, params, context) ??
    (spec.bodyFallback ? fill(spec.bodyFallback, params, context) : null);
  if (title === null || body === null) return english;
  return { title, body, localized: true };
}

/** Whether this client knows a message code (tests and the fallback note). */
export function knowsMessageCode(code: string | undefined): boolean {
  return code !== undefined && Object.hasOwn(SPECS, code);
}
