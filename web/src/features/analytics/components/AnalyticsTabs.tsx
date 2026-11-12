import { Link } from 'react-router';
import { Icon } from '@/shared/components/Icon';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { ANALYTICS_VIEWS, type AnalyticsFilters, writeAnalyticsFilters } from '../filters';
import { viewIcon, viewLabel } from '../labels';

const tabClasses =
  'inline-flex min-h-11 items-center gap-2 border-b-4 border-transparent px-1 text-sm font-medium whitespace-nowrap text-fg-muted ' +
  'hover:text-fg aria-[current=page]:border-accent aria-[current=page]:font-semibold aria-[current=page]:text-fg';

/**
 * The analytics sections as links (the section is part of the address, so it
 * can be bookmarked and Back works). The open one is marked with
 * aria-current, a bar and bold text; the period and filters are kept.
 */
export function AnalyticsTabs({ filters }: { filters: AnalyticsFilters }) {
  const t = useT();
  return (
    <nav aria-label={t('analytics.sections')} className="mb-6 overflow-x-auto border-b border-line">
      <ul className="flex gap-6">
        {ANALYTICS_VIEWS.map((view) => (
          <li key={view}>
            <Link
              to={{
                pathname: paths.analytics,
                search: `?${writeAnalyticsFilters({ ...filters, view }).toString()}`,
              }}
              aria-current={view === filters.view ? 'page' : undefined}
              className={tabClasses}
            >
              <Icon name={viewIcon[view]} className="size-4" />
              {t(viewLabel[view])}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
