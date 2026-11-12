import { QueryClient } from '@tanstack/react-query';
import { isTransientError } from '@/shared/api/errors';

export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30_000,
        // Retry only reads that failed for transient reasons; 4xx answers are final.
        retry: (failureCount, error) => isTransientError(error) && failureCount < 2,
        refetchOnWindowFocus: true,
      },
      mutations: {
        // Writes are never retried automatically (no duplicate submissions).
        retry: false,
      },
    },
  });
}
