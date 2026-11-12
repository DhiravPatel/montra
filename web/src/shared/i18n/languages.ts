/** Interface languages with a catalog. Add a language by adding a catalog. */
export const supportedLanguages = ['en', 'hi'] as const;

export type Language = (typeof supportedLanguages)[number];

/** Language names in their own language (endonyms) for the language picker. */
export const languageEndonyms: Readonly<Record<Language, string>> = {
  en: 'English',
  hi: 'हिन्दी',
};

/** Default formatting locale when the browser offers no regional variant. */
const defaultFormatLocale: Readonly<Record<Language, string>> = {
  en: 'en',
  hi: 'hi-IN',
};

const rtlLanguages = new Set([
  'ar',
  'arc',
  'ckb',
  'dv',
  'fa',
  'he',
  'ks',
  'ps',
  'sd',
  'ug',
  'ur',
  'yi',
]);

export function isSupportedLanguage(value: unknown): value is Language {
  return typeof value === 'string' && (supportedLanguages as readonly string[]).includes(value);
}

function primarySubtag(locale: string): string {
  return locale.split('-')[0]?.toLowerCase() ?? '';
}

/** Picks the first browser language Montra supports, or English. */
export function detectLanguage(browserLocales: readonly string[]): Language {
  for (const locale of browserLocales) {
    const lang = primarySubtag(locale);
    if (isSupportedLanguage(lang)) return lang;
  }
  return 'en';
}

/**
 * Locale used for numbers, dates and currency. Keeps the browser's regional
 * conventions when they match the interface language (e.g. `en-IN` lakh
 * grouping), otherwise uses the language default.
 */
export function resolveFormatLocale(lang: Language, browserLocales: readonly string[]): string {
  for (const locale of browserLocales) {
    if (primarySubtag(locale) !== lang) continue;
    try {
      const [canonical] = Intl.getCanonicalLocales(locale);
      if (canonical) return canonical;
    } catch {
      // ignore malformed browser locale tags
    }
  }
  return defaultFormatLocale[lang];
}

export function textDirection(locale: string): 'ltr' | 'rtl' {
  return rtlLanguages.has(primarySubtag(locale)) ? 'rtl' : 'ltr';
}

export function browserLocales(): readonly string[] {
  if (typeof navigator === 'undefined') return [];
  return navigator.languages.length > 0 ? navigator.languages : [navigator.language];
}
