import type { ReactNode } from 'react';

interface PageHeaderProps {
  title: string;
  description?: ReactNode;
  actions?: ReactNode;
}

/** Page title (the page's single h1). Focused on navigation by the route announcer. */
export function PageHeader({ title, description, actions }: PageHeaderProps) {
  return (
    <header className="mb-6 flex flex-wrap items-end justify-between gap-4 sm:mb-8">
      <div className="min-w-0 space-y-1">
        <h1
          tabIndex={-1}
          data-page-heading=""
          className="text-2xl font-semibold tracking-tight text-fg outline-none sm:text-3xl"
        >
          {title}
        </h1>
        {description ? <div className="text-fg-muted">{description}</div> : null}
      </div>
      {actions ? <div className="flex flex-wrap gap-2">{actions}</div> : null}
    </header>
  );
}
