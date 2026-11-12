import { writePreference } from '@/shared/utils/preferences';

/**
 * Account display preferences (PATCH /me/preferences) applied to <html>:
 * - `data-motion="reduce"` turns transitions and animations off,
 * - `data-contrast="high"` switches to the stronger token set,
 * - the root font size scales every rem-based size (text_scale_percent).
 * See src/styles/index.css. public/theme-init.js applies the saved copy
 * before first paint, so a reload does not flash the default look.
 */
export interface DisplayPreferences {
  reducedMotion: boolean;
  highContrast: boolean;
  /** 80-200 (percent of the browser's default font size). */
  textScalePercent: number;
}

const MIN_SCALE = 80;
const MAX_SCALE = 200;

function clampScale(value: number): number {
  if (!Number.isFinite(value)) return 100;
  return Math.min(Math.max(Math.round(value), MIN_SCALE), MAX_SCALE);
}

/** "motion=reduce;contrast=high;scale=125": no personal data, only how the app looks. */
export function serializeDisplay(display: DisplayPreferences): string | null {
  const parts: string[] = [];
  if (display.reducedMotion) parts.push('motion=reduce');
  if (display.highContrast) parts.push('contrast=high');
  const scale = clampScale(display.textScalePercent);
  if (scale !== 100) parts.push(`scale=${String(scale)}`);
  return parts.length > 0 ? parts.join(';') : null;
}

export function applyDisplayPreferences(root: HTMLElement, display: DisplayPreferences): void {
  if (display.reducedMotion) root.setAttribute('data-motion', 'reduce');
  else root.removeAttribute('data-motion');
  if (display.highContrast) root.setAttribute('data-contrast', 'high');
  else root.removeAttribute('data-contrast');
  const scale = clampScale(display.textScalePercent);
  root.style.fontSize = scale === 100 ? '' : `${String(scale)}%`;
  writePreference('display', serializeDisplay(display));
}

/** Back to the device defaults (after sign-out, so the next person starts fresh). */
export function clearDisplayPreferences(root: HTMLElement): void {
  root.removeAttribute('data-motion');
  root.removeAttribute('data-contrast');
  root.style.fontSize = '';
  writePreference('display', null);
}
