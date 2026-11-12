import { useEffect, useRef } from 'react';
import { usePreferences } from '@/shared/finance/reference';
import {
  applyDisplayPreferences,
  clearDisplayPreferences,
} from '@/shared/theme/displayPreferences';
import { useTheme } from '@/shared/theme/ThemeContext';

/**
 * Applies the signed-in account's display preferences everywhere: reduced
 * motion, high contrast and text size on <html>, and the account's theme
 * (when it loads or changes). Rendered once inside the signed-in routes;
 * signing out puts the device defaults back.
 */
export function AccountDisplayPreferences() {
  const preferences = usePreferences();
  const { setPreference } = useTheme();
  const data = preferences.data;
  const reducedMotion = data?.reduced_motion;
  const highContrast = data?.high_contrast;
  const textScale = data?.text_scale_percent;
  const theme = data?.theme;

  useEffect(() => {
    if (reducedMotion === undefined || highContrast === undefined || textScale === undefined) {
      return;
    }
    applyDisplayPreferences(document.documentElement, {
      reducedMotion,
      highContrast,
      textScalePercent: textScale,
    });
  }, [reducedMotion, highContrast, textScale]);

  useEffect(
    () => () => {
      clearDisplayPreferences(document.documentElement);
    },
    [],
  );

  // Follow the account's theme when it is first read and whenever it changes
  // (e.g. saved on another device); a choice made here is saved to the account.
  const appliedTheme = useRef<string | null>(null);
  useEffect(() => {
    if (!theme || appliedTheme.current === theme) return;
    appliedTheme.current = theme;
    setPreference(theme);
  }, [theme, setPreference]);

  return null;
}
