/** Transport-level events the auth layer reacts to. */
export type ApiEvent = 'session-expired';

type Listener = () => void;

const listeners = new Map<ApiEvent, Set<Listener>>();

export const apiEvents = {
  /** Subscribes and returns an unsubscribe function. */
  on(event: ApiEvent, listener: Listener): () => void {
    let set = listeners.get(event);
    if (!set) {
      set = new Set();
      listeners.set(event, set);
    }
    set.add(listener);
    return () => {
      set.delete(listener);
    };
  },
  emit(event: ApiEvent): void {
    for (const listener of [...(listeners.get(event) ?? [])]) listener();
  },
};
