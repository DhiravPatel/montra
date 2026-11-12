import type { ReactNode, Ref } from 'react';

interface AuthCardProps {
  title: string;
  description?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  headingRef?: Ref<HTMLHeadingElement>;
}

/** Centered single-task card used by sign-in, sign-up and recovery pages. */
export function AuthCard({ title, description, children, footer, headingRef }: AuthCardProps) {
  return (
    <div className="mx-auto w-full max-w-md px-4 py-10 sm:py-16">
      <div className="rounded-xl border border-line bg-surface p-6 shadow-card sm:p-8">
        <h1
          ref={headingRef}
          tabIndex={-1}
          data-page-heading=""
          className="text-2xl font-semibold tracking-tight text-fg outline-none"
        >
          {title}
        </h1>
        {description ? <div className="mt-2 text-sm text-fg-muted">{description}</div> : null}
        <div className="mt-6">{children}</div>
      </div>
      {footer ? (
        <div className="mt-6 space-y-2 text-center text-sm text-fg-muted">{footer}</div>
      ) : null}
    </div>
  );
}
