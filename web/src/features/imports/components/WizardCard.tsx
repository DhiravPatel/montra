import type { ReactNode } from 'react';

/** The current step's heading; the wizard moves focus here when the step changes. */
export const STEP_HEADING_ID = 'import-step-heading';

/** The card of the current wizard step (only one is shown at a time). */
export function WizardCard({
  title,
  description,
  children,
}: {
  title: string;
  description?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section
      aria-labelledby={STEP_HEADING_ID}
      className="rounded-xl border border-line bg-surface p-5 shadow-card sm:p-6"
    >
      <div className="mb-5 space-y-1">
        <h2
          id={STEP_HEADING_ID}
          tabIndex={-1}
          className="text-lg font-semibold text-fg outline-none"
        >
          {title}
        </h2>
        {description ? <div className="text-sm text-fg-muted">{description}</div> : null}
      </div>
      {children}
    </section>
  );
}
