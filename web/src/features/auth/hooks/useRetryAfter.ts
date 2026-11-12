import { useCallback, useState } from 'react';
import { isApiError } from '@/shared/api/errors';
import { useCountdown } from '@/shared/hooks/useCountdown';

/** Tracks a Retry-After deadline from rate-limited responses. */
export function useRetryAfter() {
  const [deadline, setDeadline] = useState<number | null>(null);
  const remaining = useCountdown(deadline);
  const capture = useCallback((error: unknown) => {
    if (isApiError(error) && error.retryAfterSeconds) {
      setDeadline(Date.now() + error.retryAfterSeconds * 1000);
    }
  }, []);
  return { remaining, blocked: remaining > 0, capture };
}
