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

/** Whether the page is visible (polling pauses while the tab is hidden). */
export function usePageVisible(): boolean {
  return useSyncExternalStore(subscribe, isVisible, () => true);
}
