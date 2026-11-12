import { createContext, useContext } from 'react';

/** `system` follows the OS setting (prefers-color-scheme). */
export type ThemePreference = 'system' | 'light' | 'dark';

export interface ThemeContextValue {
  preference: ThemePreference;
  setPreference: (preference: ThemePreference) => void;
}

export const ThemeContext = createContext<ThemeContextValue | null>(null);

export function useTheme(): ThemeContextValue {
  const value = useContext(ThemeContext);
  if (!value) throw new Error('useTheme must be used inside <ThemeProvider>');
  return value;
}

export function isThemePreference(value: unknown): value is ThemePreference {
  return value === 'system' || value === 'light' || value === 'dark';
}
