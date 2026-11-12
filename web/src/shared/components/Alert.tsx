import type { ReactNode } from 'react';
import { cx } from '@/shared/utils/cx';
import { Icon } from './Icon';
import { type Tone, toneIcon, toneSurface, toneText } from './tones';

interface AlertProps {
  tone?: Tone;
  title?: string;
  children?: ReactNode;
  /**
   * `assertive` renders role="alert" (errors after an action), `polite`
   * renders role="status"; omit for static content.
   */
  live?: 'polite' | 'assertive';
  className?: string;
}

/** Inline message. Tone is conveyed by icon and wording, not color alone. */
export function Alert({ tone = 'info', title, children, live, className }: AlertProps) {
  const role = live === 'assertive' ? 'alert' : live === 'polite' ? 'status' : undefined;
  return (
    <div
      role={role}
      className={cx(
        'flex gap-3 rounded-lg border p-4 text-sm text-fg',
        toneSurface[tone],
        className,
      )}
    >
      <Icon name={toneIcon[tone]} className={cx('mt-0.5', toneText[tone])} />
      <div className="min-w-0 space-y-1">
        {title ? <p className="font-semibold">{title}</p> : null}
        {children ? <div className="space-y-2">{children}</div> : null}
      </div>
    </div>
  );
}
