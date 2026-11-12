/** Human-readable language/region name, e.g. "English (India)"; falls back to the tag. */
export function localeDisplayName(locale: string, displayLocale: string): string {
  try {
    return new Intl.DisplayNames([displayLocale], { type: 'language' }).of(locale) ?? locale;
  } catch {
    return locale;
  }
}
