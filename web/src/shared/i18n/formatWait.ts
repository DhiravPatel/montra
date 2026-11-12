import type { Translate } from './types';

/**
 * Human wait time for Retry-After values: "45 seconds", "15 minutes",
 * "2 hours" (rounded up, localized and pluralized through the catalog).
 */
export function formatWait(t: Translate, seconds: number): string {
  const whole = Math.max(1, Math.ceil(seconds));
  if (whole < 60) return t('time.seconds', { count: whole });
  if (whole < 90 * 60) return t('time.minutes', { count: Math.ceil(whole / 60) });
  return t('time.hours', { count: Math.ceil(whole / 3600) });
}
