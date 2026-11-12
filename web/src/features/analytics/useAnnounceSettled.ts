import { useEffect, useRef } from 'react';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';

/**
 * Tells screen-reader users that new figures are on screen after they change
 * the period or a filter (the first load is announced by the page itself).
 * `settledKey` identifies the request whose fresh result is shown, or null
 * while loading or showing the previous figures.
 */
export function useAnnounceSettled(settledKey: string | null, message: string) {
  const announce = useAnnounce();
  const last = useRef<string | null>(null);
  useEffect(() => {
    if (settledKey === null) return;
    if (last.current !== null && last.current !== settledKey) announce(message);
    last.current = settledKey;
  }, [settledKey, message, announce]);
}
