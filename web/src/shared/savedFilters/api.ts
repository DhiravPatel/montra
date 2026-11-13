import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { hasErrorCode } from '@/shared/api/errors';
import { apiData } from '@/shared/api/request';
import type { components } from '@/shared/api/schema';

/** A named filter kept on the account (GET/POST/DELETE /saved-filters). */
export type SavedFilter = components['schemas']['SavedFilterDTO'];
export type SavedFilterScope = SavedFilter['scope'];

/**
 * The filter object as the API stores it: exactly the query parameters of
 * the screen's list endpoint (GET /transactions, GET /search), so a filter
 * saved by one client applies in the other.
 */
export type SavedFilterQuery = Readonly<Record<string, unknown>>;

/** Name limits from the contract (`Saved-filters-createRequest.name`). */
export const SAVED_FILTER_NAME_MAX = 80;

export const savedFilterKeys = {
  all: () => ['saved-filters'] as const,
  list: (scope: SavedFilterScope) => ['saved-filters', scope] as const,
};

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/**
 * Saved filters. The contract has no update or read-one operation, takes no
 * Idempotency-Key on create (a repeated create answers CONFLICT for the
 * same name) and sets no fair-use cap on how many a person keeps.
 */
export const savedFiltersApi = {
  list: (scope: SavedFilterScope, signal?: AbortSignal): Promise<SavedFilter[]> =>
    apiData(api.GET('/saved-filters', { params: { query: { scope } }, ...signalOption(signal) })),
  create: (scope: SavedFilterScope, name: string, filter: SavedFilterQuery): Promise<SavedFilter> =>
    apiData(api.POST('/saved-filters', { body: { scope, name, filter } })),
  remove: (id: string) => apiData(api.DELETE('/saved-filters/{id}', { params: { path: { id } } })),
};

export function useSavedFilters(scope: SavedFilterScope) {
  return useQuery({
    queryKey: savedFilterKeys.list(scope),
    queryFn: ({ signal }) => savedFiltersApi.list(scope, signal),
  });
}

export function useCreateSavedFilter(scope: SavedFilterScope) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ name, filter }: { name: string; filter: SavedFilterQuery }) =>
      savedFiltersApi.create(scope, name, filter),
    onSuccess: (created) => {
      queryClient.setQueryData<SavedFilter[]>(savedFilterKeys.list(scope), (list) =>
        list
          ? [...list.filter((item) => item.id !== created.id), created].sort((a, b) =>
              a.name.localeCompare(b.name),
            )
          : list,
      );
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: savedFilterKeys.list(scope) }),
  });
}

export function useDeleteSavedFilter(scope: SavedFilterScope) {
  const queryClient = useQueryClient();
  return useMutation({
    // Already gone (deleted elsewhere): the outcome the person asked for.
    mutationFn: async (id: string) => {
      try {
        await savedFiltersApi.remove(id);
      } catch (error) {
        if (!hasErrorCode(error, 'NOT_FOUND')) throw error;
      }
      return id;
    },
    onSuccess: (id) => {
      queryClient.setQueryData<SavedFilter[]>(savedFilterKeys.list(scope), (list) =>
        list?.filter((item) => item.id !== id),
      );
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: savedFilterKeys.list(scope) }),
  });
}

/** A saved filter's object form, or null when it isn't a JSON object (other clients may save anything). */
export function filterObject(value: unknown): SavedFilterQuery | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as SavedFilterQuery)
    : null;
}
