import { createContext, type ReactNode, useContext } from 'react';
import type { Language } from './languages';
import type { MessageKey, Translate, TranslateParams } from './types';

export type RichTags = Readonly<Record<string, (text: string) => ReactNode>>;

export interface I18nContextValue {
  /** Interface language. */
  lang: Language;
  /** BCP 47 locale for numbers, dates and currency. */
  formatLocale: string;
  dir: 'ltr' | 'rtl';
  t: Translate;
  /** Translates a message containing `<tag>text</tag>` markup into React nodes. */
  rich: (key: MessageKey, tags: RichTags, params?: TranslateParams) => ReactNode[];
  setLanguage: (lang: Language) => void;
}

export const I18nContext = createContext<I18nContextValue | null>(null);

export function useI18n(): I18nContextValue {
  const value = useContext(I18nContext);
  if (!value) throw new Error('useI18n must be used inside <I18nProvider>');
  return value;
}

/** Shorthand for the translate function. */
export function useT(): Translate {
  return useI18n().t;
}
