import type { ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';
import { Icon, type IconName } from './Icon';
import { type Tone, toneIcon, toneSurface, toneText } from './tones';

interface StatusBadgeProps {
  tone?: Tone;
  icon?: IconName;
  children: ReactNode;
}

/** Small status label: always icon + text. */
export function StatusBadge({ tone = 'neutral', icon, children }: StatusBadgeProps) {
  return (
    <span
      className={cx(
        'inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium text-fg',
        toneSurface[tone],
      )}
    >
      <Icon name={icon ?? toneIcon[tone]} className={cx('size-3.5', toneText[tone])} />
      {children}
    </span>
  );
}
