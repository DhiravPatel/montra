import { type ReactNode, useId, useState } from 'react';
import { cx } from '@/shared/utils/cx';
import { Icon } from './Icon';

interface DisclosureProps {
  summary: string;
  children: ReactNode;
  defaultOpen?: boolean;
  className?: string;
}

/** A button that shows or hides a section (aria-expanded + aria-controls). */
export function Disclosure({ summary, children, defaultOpen = false, className }: DisclosureProps) {
  const [open, setOpen] = useState(defaultOpen);
  const id = useId();
  return (
    <div className={className}>
      <button
        type="button"
        aria-expanded={open}
        aria-controls={id}
        onClick={() => {
          setOpen((value) => !value);
        }}
        className="inline-flex min-h-11 items-center gap-2 rounded-md text-sm font-medium text-accent underline decoration-1 underline-offset-4 hover:text-accent-hover"
      >
        <Icon
          name="chevron-down"
          className={cx(
            'size-4 transition-transform motion-reduce:transition-none',
            open && 'rotate-180',
          )}
        />
        {summary}
      </button>
      <div id={id} hidden={!open} className="mt-3">
        {children}
      </div>
    </div>
  );
}
