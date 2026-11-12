import { useCallback, useState } from 'react';

/**
 * Idempotency keys for financial creates (docs/API.md "Idempotency and
 * concurrency"). A form keeps one key while the same draft is retried, so a
 * retry after a lost response replays the original result instead of
 * recording the money twice. A new key is taken only after a success.
 */
export function newIdempotencyKey(): string {
  return `web-${crypto.randomUUID()}`;
}

export interface IdempotencyKey {
  key: string;
  /** Call after a successful write so the next draft gets its own key. */
  renew: () => void;
}

export function useIdempotencyKey(): IdempotencyKey {
  const [key, setKey] = useState(newIdempotencyKey);
  const renew = useCallback(() => {
    setKey(newIdempotencyKey());
  }, []);
  return { key, renew };
}
