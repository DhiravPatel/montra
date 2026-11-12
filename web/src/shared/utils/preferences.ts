/**
 * Per-device UI preferences (theme, interface language) persisted in
 * localStorage. This is the only module allowed to touch browser storage.
 *
 * Never store tokens, personal details, or financial data here: the key
 * union below is deliberately closed.
 */
type PreferenceKey = 'theme' | 'lang';

const PREFIX = 'montra.';

export function readPreference(key: PreferenceKey): string | null {
  try {
    // eslint-disable-next-line no-restricted-globals -- audited preference store
    return localStorage.getItem(PREFIX + key);
  } catch {
    return null; // storage blocked or unavailable
  }
}

export function writePreference(key: PreferenceKey, value: string | null): void {
  try {
    if (value === null) {
      // eslint-disable-next-line no-restricted-globals -- audited preference store
      localStorage.removeItem(PREFIX + key);
    } else {
      // eslint-disable-next-line no-restricted-globals -- audited preference store
      localStorage.setItem(PREFIX + key, value);
    }
  } catch {
    // Preference simply won't persist; the app keeps working.
  }
}
