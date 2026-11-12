import type { IconName } from './Icon';

export type Tone = 'info' | 'success' | 'warning' | 'danger' | 'neutral';

export const toneIcon: Readonly<Record<Tone, IconName>> = {
  info: 'info',
  success: 'check-circle',
  warning: 'alert-triangle',
  danger: 'alert-circle',
  neutral: 'info',
};

export const toneSurface: Readonly<Record<Tone, string>> = {
  info: 'border-info/40 bg-info-soft',
  success: 'border-success/40 bg-success-soft',
  warning: 'border-warning/40 bg-warning-soft',
  danger: 'border-danger/40 bg-danger-soft',
  neutral: 'border-line bg-surface-muted',
};

export const toneText: Readonly<Record<Tone, string>> = {
  info: 'text-info',
  success: 'text-success',
  warning: 'text-warning',
  danger: 'text-danger',
  neutral: 'text-fg-muted',
};
