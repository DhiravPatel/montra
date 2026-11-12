import type { DateRangePreset } from '@/shared/finance/types';
import { CONVERTIBLE_TYPES, PERIOD_TYPES, REPORT_TRANSACTION_TYPES } from './labels';
import type {
  Report,
  ReportFilters,
  ReportFormat,
  ReportInput,
  ReportSchedule,
  ReportType,
  ScheduleCadence,
  ScheduleInput,
  SchedulePatch,
} from './types';

/** The filters a report or schedule can carry (beyond its period). */
export interface ReportOptionValues {
  accountId: string;
  categoryId: string;
  /** Only transactions in this currency; '' for every currency. */
  currency: string;
  includePending: boolean;
  /** Adds totals converted into this currency (with disclosed rates); '' for none. */
  display: string;
}

export interface ReportFormValues extends ReportOptionValues {
  type: ReportType | '';
  format: ReportFormat;
  range: DateRangePreset | 'custom';
  from: string;
  to: string;
  title: string;
}

export interface ScheduleFormValues extends ReportOptionValues {
  type: ReportType | '';
  format: ReportFormat;
  cadence: ScheduleCadence;
  title: string;
}

export const emptyOptions: ReportOptionValues = {
  accountId: '',
  categoryId: '',
  currency: '',
  includePending: false,
  display: '',
};

/** A schedule's stored filters as form values (to edit it). */
export function scheduleOptionValues(schedule: ReportSchedule): ReportOptionValues {
  const filters = schedule.filters;
  return {
    accountId: filters.account_ids?.[0] ?? '',
    categoryId: filters.category_ids?.[0] ?? '',
    currency: filters.currency ?? '',
    includePending: filters.include_pending ?? false,
    display: filters.display_currency ?? '',
  };
}

/** The API's own default period for a report type. */
export function defaultRange(type: ReportType | ''): DateRangePreset {
  return type === 'yearly_summary' ? 'this_year' : 'this_month';
}

/** Filters that apply to the report type (others are left out so nothing misleading is stored). */
function optionFilters(type: ReportType, values: ReportOptionValues): ReportFilters {
  const filters: ReportFilters = {};
  if (!PERIOD_TYPES.has(type)) return filters;
  if (values.accountId) filters.account_ids = [values.accountId];
  if (values.categoryId) filters.category_ids = [values.categoryId];
  if (values.currency) filters.currency = values.currency;
  if (values.includePending) filters.include_pending = true;
  const types = REPORT_TRANSACTION_TYPES[type];
  if (types) filters.types = [...types];
  if (values.display && CONVERTIBLE_TYPES.has(type)) filters.display_currency = values.display;
  return filters;
}

export function toReportInput(values: ReportFormValues & { type: ReportType }): ReportInput {
  const filters = optionFilters(values.type, values);
  if (PERIOD_TYPES.has(values.type)) {
    if (values.range === 'custom') {
      filters.from = values.from;
      filters.to = values.to;
    } else {
      filters.range = values.range;
    }
  }
  const title = values.title.trim();
  return {
    report_type: values.type,
    format: values.format,
    ...(title ? { title } : {}),
    filters,
  };
}

export function toScheduleInput(values: ScheduleFormValues & { type: ReportType }): ScheduleInput {
  const title = values.title.trim();
  return {
    report_type: values.type,
    format: values.format,
    cadence: values.cadence,
    ...(title ? { title } : {}),
    filters: optionFilters(values.type, values),
  };
}

/**
 * The changes to a schedule, with the version read: the title as typed (an
 * empty one restores the default), format, cadence and the filters as a
 * whole (the cadence sets the dates).
 */
export function toSchedulePatch(
  values: ScheduleFormValues & { type: ReportType },
  schedule: ReportSchedule,
): SchedulePatch {
  return {
    title: values.title.trim(),
    format: values.format,
    cadence: values.cadence,
    filters: optionFilters(values.type, values),
    version: schedule.version,
  };
}

/** The same report again (a failed or expired one): same type, format, title and filters. */
export function repeatInput(report: Report, type: ReportType): ReportInput {
  return { report_type: type, format: report.format, title: report.title, filters: report.filters };
}
