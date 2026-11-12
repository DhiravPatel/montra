import type { SearchSection } from './types';

/** The search page's field (the header's search link focuses it when already on the page). */
export const SEARCH_PAGE_INPUT_ID = 'search-page-query';

/** Heading of a result section; focus moves here after "Show more". */
export function sectionHeadingId(section: SearchSection): string {
  return `search-section-${section}`;
}
