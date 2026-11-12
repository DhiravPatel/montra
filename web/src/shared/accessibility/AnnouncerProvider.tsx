import { type ReactNode, useCallback, useEffect, useRef, useState } from 'react';
import { type Announce, AnnouncerContext } from './AnnouncerContext';

/**
 * Visually hidden live regions that exist from first render (regions added
 * later are not reliably announced). Messages are cleared first so repeating
 * the same text is announced again.
 */
export function AnnouncerProvider({ children }: { children: ReactNode }) {
  const [polite, setPolite] = useState('');
  const [assertive, setAssertive] = useState('');
  const timer = useRef<number | undefined>(undefined);

  const announce = useCallback<Announce>((message, politeness = 'polite') => {
    const set = politeness === 'assertive' ? setAssertive : setPolite;
    set('');
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      set(message);
    }, 50);
  }, []);

  useEffect(
    () => () => {
      window.clearTimeout(timer.current);
    },
    [],
  );

  return (
    <AnnouncerContext.Provider value={announce}>
      {children}
      <div className="sr-only" aria-live="polite" aria-atomic="true" data-testid="announcer-polite">
        {polite}
      </div>
      <div className="sr-only" aria-live="assertive" aria-atomic="true">
        {assertive}
      </div>
    </AnnouncerContext.Provider>
  );
}
