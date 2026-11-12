import { type ReactNode, useCallback, useEffect, useMemo, useState } from 'react';
import { readPreference, writePreference } from '@/shared/utils/preferences';
import { ThemeContext, type ThemeContextValue, type ThemePreference } from './ThemeContext';

function savedPreference(): ThemePreference {
  const saved = readPreference('theme');
  return saved === 'light' || saved === 'dark' ? saved : 'system';
}

/**
 * Applies the theme as `data-theme` on <html>. With `system`, the attribute
 * is removed and CSS follows prefers-color-scheme. public/theme-init.js
 * applies the saved choice before first paint.
 */
export function ThemeProvider({ children }: { children: ReactNode }) {
  const [preference, setPreferenceState] = useState<ThemePreference>(savedPreference);

  useEffect(() => {
    const root = document.documentElement;
    if (preference === 'system') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', preference);
  }, [preference]);

  const setPreference = useCallback((next: ThemePreference) => {
    setPreferenceState(next);
    writePreference('theme', next === 'system' ? null : next);
  }, []);

  const value = useMemo<ThemeContextValue>(
    () => ({ preference, setPreference }),
    [preference, setPreference],
  );
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}
