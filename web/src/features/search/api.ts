import { skipToken, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { searchKeys } from './keys';
import type { RecentSearch, SearchRequest, SearchResults } from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/**
 * Global search (spec §4.20): the API returns only records the caller may
 * see. The query text is personal, so it is sent to the API only (never put
 * in page URLs, titles, logs or browser storage).
 */
export const searchApi = {
  /**
   * One search. `save` is sent only when the person submitted the search
   * (the API's default is not to remember it), never while typing.
   */
  search: (request: SearchRequest, signal?: AbortSignal): Promise<SearchResults> =>
    apiData(
      api.GET('/search', {
        params: {
          query: {
            q: request.q,
            scope: request.scope,
            limit: request.limit,
            sort: request.sort,
            ...(request.save ? { save: true } : {}),
          },
        },
        ...signalOption(signal),
      }),
    ),
  /** Your last 20 submitted searches, newest first. */
  recent: (signal?: AbortSignal): Promise<RecentSearch[]> =>
    apiData(api.GET('/search/recent', signalOption(signal))),
  /** Deletes your whole search history; resolves with how many were removed. */
  clearRecent: () => apiData(api.DELETE('/search/recent')),
};

const IDLE: SearchRequest = { q: '', scope: 'all', limit: 0, sort: 'relevance', save: false };

/**
 * Results for one request (`null` while there is nothing to search). The
 * previous results stay on screen while the next ones load, and a request
 * that is no longer wanted (the text changed) is aborted through the
 * query's AbortSignal.
 */
export function useSearchResults(request: SearchRequest | null) {
  const queryClient = useQueryClient();
  return useQuery({
    queryKey: searchKeys.results(request ?? IDLE),
    queryFn: request
      ? async ({ signal }) => {
          const results = await searchApi.search(request, signal);
          if (request.save) void queryClient.invalidateQueries({ queryKey: searchKeys.recent() });
          return results;
        }
      : skipToken,
    // Keep the previous results on screen while the next ones load. Coming back
    // (Back button) to a search that was submitted, show its cached results
    // right away: the same search with `save` flipped returns the same records.
    placeholderData: (previous) =>
      previous ??
      (request
        ? queryClient.getQueryData<SearchResults>(
            searchKeys.results({ ...request, save: !request.save }),
          )
        : undefined),
    // A submitted search is remembered by the request itself; never repeat it on focus.
    refetchOnWindowFocus: false,
  });
}

export function useRecentSearches() {
  return useQuery({
    queryKey: searchKeys.recent(),
    queryFn: ({ signal }) => searchApi.recent(signal),
  });
}
