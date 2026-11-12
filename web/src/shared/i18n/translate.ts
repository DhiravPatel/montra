import { en } from './locales/en';
import { hi } from './locales/hi';
import type { Language } from './languages';
import type { Message, MessageKey, PartialCatalog, Translate, TranslateParams } from './types';

const catalogs: Readonly<Record<Language, PartialCatalog>> = { en, hi };

const PLACEHOLDER = /\{(\w+)\}/g;

function selectForm(message: Message, count: number | undefined, rules: Intl.PluralRules): string {
  if (typeof message === 'string') return message;
  const category = rules.select(count ?? 0);
  return message[category] ?? message.other;
}

/**
 * Creates a translator for one language. Missing keys fall back to English;
 * `{name}` placeholders are replaced from params (numbers are formatted for
 * the locale) and `count` selects plural forms via Intl.PluralRules.
 */
export function createTranslator(lang: Language, formatLocale: string): Translate {
  const rules = new Intl.PluralRules(formatLocale);
  const numbers = new Intl.NumberFormat(formatLocale);
  const catalog = catalogs[lang];

  return (key: MessageKey, params?: TranslateParams): string => {
    const message = catalog[key] ?? en[key];
    const count = typeof params?.count === 'number' ? params.count : undefined;
    const template = selectForm(message, count, rules);
    if (!params) return template;
    return template.replace(PLACEHOLDER, (match, name: string) => {
      const value = params[name];
      if (value === undefined) return match;
      return typeof value === 'number' ? numbers.format(value) : value;
    });
  };
}

export interface RichSegment {
  /** Tag name for marked-up text (e.g. `link` in `<link>Terms</link>`), or null for plain text. */
  tag: string | null;
  text: string;
}

const TAG = /<(\w+)>(.*?)<\/\1>/g;

/** Splits a translated string containing simple non-nested `<tag>text</tag>` markup. */
export function splitRichText(message: string): RichSegment[] {
  const segments: RichSegment[] = [];
  let lastIndex = 0;
  for (const match of message.matchAll(TAG)) {
    const [whole, tag, text] = match;
    if (match.index > lastIndex)
      segments.push({ tag: null, text: message.slice(lastIndex, match.index) });
    segments.push({ tag: tag ?? null, text: text ?? '' });
    lastIndex = match.index + whole.length;
  }
  if (lastIndex < message.length) segments.push({ tag: null, text: message.slice(lastIndex) });
  return segments;
}
