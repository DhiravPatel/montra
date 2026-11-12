import { type ReactNode, useId } from 'react';
import { cx } from '@/shared/utils/cx';

interface CardProps {
  title?: string;
  description?: ReactNode;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
}

/** A titled section of a page (renders a <section> labelled by its h2). */
export function Card({ title, description, actions, children, className }: CardProps) {
  const headingId = useId();
  return (
    <section
      aria-labelledby={title ? headingId : undefined}
      className={cx('rounded-xl border border-line bg-surface p-5 shadow-card sm:p-6', className)}
    >
      {title ? (
        <div className="mb-5 flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0 space-y-1">
            <h2 id={headingId} className="text-lg font-semibold text-fg">
              {title}
            </h2>
            {description ? <div className="text-sm text-fg-muted">{description}</div> : null}
          </div>
          {actions ? <div className="flex shrink-0 flex-wrap gap-2">{actions}</div> : null}
        </div>
      ) : null}
      {children}
    </section>
  );
}
