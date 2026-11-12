import type { ReactNode } from 'react';
import { useI18n } from '@/shared/i18n/I18nContext';
import { initials } from '../people';
import type { PersonRef } from '../types';

/**
 * Someone's minimal profile exactly as the API returns it: display name and
 * @username. The circle shows initials (decorative); photos are not loaded.
 */
export function PersonSummary({
  person,
  children,
}: {
  person: PersonRef;
  /** Extra lines under the name (dates, status). */
  children?: ReactNode;
}) {
  const { formatLocale } = useI18n();
  return (
    <div className="flex min-w-0 items-start gap-3">
      <span
        aria-hidden="true"
        className="inline-flex size-10 shrink-0 items-center justify-center rounded-full bg-accent-soft text-sm font-semibold text-fg"
      >
        {initials(person.display_name, formatLocale)}
      </span>
      <div className="min-w-0 space-y-0.5">
        <p className="font-medium break-words text-fg">{person.display_name}</p>
        {person.username ? (
          <p className="text-sm break-all text-fg-muted">@{person.username}</p>
        ) : null}
        {children}
      </div>
    </div>
  );
}
