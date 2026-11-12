import { Fragment, type ReactNode, useCallback, useEffect, useMemo, useState } from 'react';
import { readPreference, writePreference } from '@/shared/utils/preferences';
import { I18nContext, type I18nContextValue, type RichTags } from './I18nContext';
import {
  browserLocales,
  detectLanguage,
  isSupportedLanguage,
  type Language,
  resolveFormatLocale,
  textDirection,
} from './languages';
import { createTranslator, splitRichText } from './translate';
import type { MessageKey, TranslateParams } from './types';

function initialLanguage(): Language {
  const saved = readPreference('lang');
  return isSupportedLanguage(saved) ? saved : detectLanguage(browserLocales());
}

interface I18nProviderProps {
  children: ReactNode;
  /** Forces a language (tests, previews); otherwise saved preference or browser language. */
  language?: Language;
}

export function I18nProvider({ children, language }: I18nProviderProps) {
  const [lang, setLang] = useState<Language>(() => language ?? initialLanguage());
  const formatLocale = useMemo(() => resolveFormatLocale(lang, browserLocales()), [lang]);
  const dir = textDirection(lang);
  const t = useMemo(() => createTranslator(lang, formatLocale), [lang, formatLocale]);

  const rich = useCallback(
    (key: MessageKey, tags: RichTags, params?: TranslateParams): ReactNode[] =>
      splitRichText(t(key, params)).map((segment, index) => {
        const render = segment.tag ? tags[segment.tag] : undefined;
        return <Fragment key={index}>{render ? render(segment.text) : segment.text}</Fragment>;
      }),
    [t],
  );

  const setLanguage = useCallback((next: Language) => {
    setLang(next);
    writePreference('lang', next);
  }, []);

  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = dir;
  }, [lang, dir]);

  const value = useMemo<I18nContextValue>(
    () => ({ lang, formatLocale, dir, t, rich, setLanguage }),
    [lang, formatLocale, dir, t, rich, setLanguage],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}
