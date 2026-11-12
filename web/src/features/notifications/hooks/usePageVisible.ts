import { useSyncExternalStore } from 'react';

function subscribe(onChange: () => void) {
  document.addEventListener('visibilitychange', onChange);
  return () => {
    document.removeEventListener('visibilitychange', onChange);
  };
}

function isVisible() {
  return document.visibilityState !== 'hidden';
}

/** Whether the tab is visible: polling stops while it is hidden. */
export function usePageVisible(): boolean {
  return useSyncExternalStore(subscribe, isVisible, () => true);
}
