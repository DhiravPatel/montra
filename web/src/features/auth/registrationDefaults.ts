/**
 * Locale and time zone sent at registration, detected from the browser and
 * normalized to what the API accepts (backend validLocale: `ll` or `ll-RR`).
 */
export function toApiLocale(locale: string): string | null {
  try {
    const parsed = new Intl.Locale(locale);
    const language = parsed.language.toLowerCase();
    if (!/^[a-z]{2,3}$/.test(language)) return null;
    const region = parsed.region;
    return region && /^[A-Z]{2}$/.test(region) ? `${language}-${region}` : language;
  } catch {
    return null;
  }
}

export function browserTimeZone(): string | null {
  try {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    return zone && zone.length <= 64 ? zone : null;
  } catch {
    return null;
  }
}
