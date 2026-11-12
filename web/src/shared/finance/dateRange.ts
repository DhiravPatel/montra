import { isDateRangePreset } from './labels';
import type { DateRangePreset } from './types';

export type RangeChoice = DateRangePreset | 'custom' | 'all';

export interface DateRangeValue {
  range: RangeChoice;
  from: string;
  to: string;
}

export function parseRangeChoice(value: string, allowAll: boolean): RangeChoice | null {
  if (value === 'custom') return 'custom';
  if (allowAll && value === 'all') return 'all';
  return isDateRangePreset(value) ? value : null;
}
