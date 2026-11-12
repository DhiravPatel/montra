import type { IconName } from '@/shared/components/Icon';
import type { Tone } from '@/shared/components/tones';
import type { MessageKey } from '@/shared/i18n/types';
import type { Report, ReportFormat, ReportStatus, ReportType, ScheduleCadence } from './types';

/*
 * Localized labels for report enums, typed against the generated unions so
 * a value added to the contract fails compilation until it has a label.
 */

export const REPORT_TYPES = [
  'monthly_summary',
  'yearly_summary',
  'cash_flow',
  'income',
  'expense',
  'category',
  'merchant',
  'transactions',
  'account',
  'budget',
  'subscription',
  'recurring',
  'goal',
] as const satisfies readonly ReportType[];

type MissingTypes = Exclude<ReportType, (typeof REPORT_TYPES)[number]>;
/** Compile-time check: every contract report type is listed above. */
export const reportTypesAreListed: [MissingTypes] extends [never] ? true : MissingTypes = true;

export function isReportType(value: string): value is ReportType {
  return (REPORT_TYPES as readonly string[]).includes(value);
}

/** Groups for the type picker. */
export const REPORT_TYPE_GROUPS: readonly { label: MessageKey; types: readonly ReportType[] }[] = [
  { label: 'reports.typeGroup.summaries', types: ['monthly_summary', 'yearly_summary'] },
  {
    label: 'reports.typeGroup.money',
    types: ['cash_flow', 'income', 'expense', 'category', 'merchant', 'transactions'],
  },
  {
    label: 'reports.typeGroup.current',
    types: ['account', 'budget', 'subscription', 'recurring', 'goal'],
  },
];

export const reportTypeLabel: Readonly<Record<ReportType, MessageKey>> = {
  monthly_summary: 'reports.type.monthly_summary',
  yearly_summary: 'reports.type.yearly_summary',
  cash_flow: 'reports.type.cash_flow',
  income: 'reports.type.income',
  expense: 'reports.type.expense',
  category: 'reports.type.category',
  merchant: 'reports.type.merchant',
  transactions: 'reports.type.transactions',
  account: 'reports.type.account',
  budget: 'reports.type.budget',
  subscription: 'reports.type.subscription',
  recurring: 'reports.type.recurring',
  goal: 'reports.type.goal',
};

export const reportTypeHelp: Readonly<Record<ReportType, MessageKey>> = {
  monthly_summary: 'reports.typeHelp.monthly_summary',
  yearly_summary: 'reports.typeHelp.yearly_summary',
  cash_flow: 'reports.typeHelp.cash_flow',
  income: 'reports.typeHelp.income',
  expense: 'reports.typeHelp.expense',
  category: 'reports.typeHelp.category',
  merchant: 'reports.typeHelp.merchant',
  transactions: 'reports.typeHelp.transactions',
  account: 'reports.typeHelp.account',
  budget: 'reports.typeHelp.budget',
  subscription: 'reports.typeHelp.subscription',
  recurring: 'reports.typeHelp.recurring',
  goal: 'reports.typeHelp.goal',
};

/** Types built from a period and the transaction filters (the others show today's figures). */
export const PERIOD_TYPES: ReadonlySet<ReportType> = new Set([
  'monthly_summary',
  'yearly_summary',
  'cash_flow',
  'income',
  'expense',
  'category',
  'merchant',
  'transactions',
]);

/** Types whose cash-flow section can add converted totals with disclosed rates. */
export const CONVERTIBLE_TYPES: ReadonlySet<ReportType> = new Set([
  'monthly_summary',
  'yearly_summary',
  'cash_flow',
  'income',
  'expense',
]);

/**
 * Transaction types each report counts. The analytics endpoints apply these
 * for income and spending; the report request carries them explicitly.
 */
export const REPORT_TRANSACTION_TYPES: Readonly<Partial<Record<ReportType, readonly string[]>>> = {
  income: ['income'],
  expense: ['expense', 'group_expense', 'refund', 'reimbursement'],
};

export function isPeriodType(value: string): boolean {
  return isReportType(value) && PERIOD_TYPES.has(value);
}

export const REPORT_FORMATS = [
  'csv',
  'xlsx',
  'pdf',
  'json',
] as const satisfies readonly ReportFormat[];

export const formatLabel: Readonly<Record<ReportFormat, MessageKey>> = {
  csv: 'reports.format.csv',
  xlsx: 'reports.format.xlsx',
  pdf: 'reports.format.pdf',
  json: 'reports.format.json',
};

export function isReportFormat(value: string): value is ReportFormat {
  return (REPORT_FORMATS as readonly string[]).includes(value);
}

interface StatusDisplay {
  label: MessageKey;
  icon: IconName;
  tone: Tone;
}

/** Report states, always icon + words. */
export const statusDisplay: Readonly<Record<ReportStatus, StatusDisplay>> = {
  queued: { label: 'reports.status.queued', icon: 'clock', tone: 'neutral' },
  running: { label: 'reports.status.running', icon: 'refresh', tone: 'info' },
  completed: { label: 'reports.status.completed', icon: 'check-circle', tone: 'success' },
  failed: { label: 'reports.status.failed', icon: 'alert-circle', tone: 'danger' },
  expired: { label: 'reports.status.expired', icon: 'history', tone: 'neutral' },
};

/** Why a report could not be created (`error_code`), in plain words. */
const failureMessages: Readonly<Record<NonNullable<Report['error_code']>, MessageKey>> = {
  too_many_rows: 'reports.failure.too_many_rows',
  pdf_too_large: 'reports.failure.pdf_too_large',
  report_invalid: 'reports.failure.report_invalid',
  reports_unavailable: 'reports.failure.reports_unavailable',
  storage_unavailable: 'reports.failure.storage_unavailable',
  generation_failed: 'reports.failure.generation_failed',
};

export function failureMessage(code: string | undefined): MessageKey {
  if (!code || !Object.hasOwn(failureMessages, code)) return 'reports.failure.other';
  return failureMessages[code as keyof typeof failureMessages];
}

export const CADENCES = ['weekly', 'monthly'] as const satisfies readonly ScheduleCadence[];

export const cadenceLabel: Readonly<Record<ScheduleCadence, MessageKey>> = {
  weekly: 'reports.cadence.weekly',
  monthly: 'reports.cadence.monthly',
};
