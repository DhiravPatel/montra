import { createContext, useContext } from 'react';
import type { FriendRequest, PersonRef } from '../types';

export type RequestAction = 'accept' | 'decline' | 'cancel';

/**
 * Actions on people and requests, shared by every tab of the Friends page.
 * Destructive ones (remove, block, unblock) open a confirmation first;
 * repeated clicks while an action runs are ignored.
 */
export interface SocialActions {
  /** Accept or decline a request you received, or cancel one you sent. */
  respond: (request: FriendRequest, action: RequestAction) => void;
  /** The action running for this request, if any. */
  respondingTo: (requestId: string) => RequestAction | null;
  /** Mute or unmute someone's notifications (they are not told). */
  setMuted: (person: PersonRef, muted: boolean) => void;
  /** True while a mute change for this person is running. */
  isMuting: (userId: string) => boolean;
  confirmRemove: (person: PersonRef) => void;
  confirmBlock: (person: PersonRef) => void;
  confirmUnblock: (person: PersonRef) => void;
}

export const SocialActionsContext = createContext<SocialActions | null>(null);

export function useSocialActions(): SocialActions {
  const actions = useContext(SocialActionsContext);
  if (!actions) throw new Error('useSocialActions must be used inside <SocialActionsProvider>');
  return actions;
}
