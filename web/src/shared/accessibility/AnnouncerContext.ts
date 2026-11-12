import { createContext, useContext } from 'react';

export type Announce = (message: string, politeness?: 'polite' | 'assertive') => void;

export const AnnouncerContext = createContext<Announce | null>(null);

/** Announces a message to screen readers without showing it. */
export function useAnnounce(): Announce {
  const announce = useContext(AnnouncerContext);
  if (!announce) throw new Error('useAnnounce must be used inside <AnnouncerProvider>');
  return announce;
}
