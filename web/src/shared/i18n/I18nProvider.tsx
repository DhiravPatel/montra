import {
  Fragment,
  type ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
} from 'react';
import { writePreference } from '@/shared/utils/preferences';
import {
  catalogVersion,
  getCurrentLanguage,
  hasNamespaces,
  loadedNamespaces,
  loadNamespaces,
  setCurrentLanguage,
  subscribeCatalogs,
} from './catalogs';
import { I18nContext, type I18nContextValue, type RichTags } from './I18nContext';
import { browserLocales, type Language, resolveFormatLocale, textDirection } from './languages';
import { createTranslator, splitRichText } from './translate';
import type { MessageKey, TranslateParams } from './types';

interface I18nProviderProps {
  children: ReactNode;
  /** Forces a language (tests, previews); otherwise saved preference or browser language. */
  language?: Language;
}

export function I18nProvider({ children, language }: I18nProviderProps) {
  const [lang, setLang] = useState<Language>(() => language ?? getCurrentLanguage());
  // A namespace arriving re-creates `t`, so text waiting for it re-renders.
  const version = useSyncExternalStore(subscribeCatalogs, catalogVersion, catalogVersion);
  const formatLocale = useMemo(() => resolveFormatLocale(lang, browserLocales()), [lang]);
  const dir = textDirection(lang);
  // A new catalog version must give a new translator, so text that was waiting re-renders.
  // eslint-disable-next-line react-hooks/exhaustive-deps -- `version` is that deliberate extra dependency
  const t = useMemo(() => createTranslator(lang, formatLocale), [lang, formatLocale, version]);
  const requested = useRef<Language>(lang);

  const rich = useCallback(
    (key: MessageKey, tags: RichTags, params?: TranslateParams): ReactNode[] =>
      splitRichText(t(key, params)).map((segment, index) => {
        const render = segment.tag ? tags[segment.tag] : undefined;
        return <Fragment key={index}>{render ? render(segment.text) : segment.text}</Fragment>;
      }),
    [t],
  );

  /**
   * Switches once the new language's catalogs for everything loaded so far
   * have arrived, so the page never shows a half-translated mix. A failed
   * download keeps the current language.
   */
  const setLanguage = useCallback((next: Language) => {
    requested.current = next;
    writePreference('lang', next);
    const apply = () => {
      if (requested.current !== next) return;
      setCurrentLanguage(next);
      setLang(next);
    };
    const needed = loadedNamespaces();
    if (hasNamespaces(next, needed)) {
      apply();
      return;
    }
    loadNamespaces(next, needed).then(apply, () => {
      if (requested.current === next) requested.current = getCurrentLanguage();
    });
  }, []);

  useEffect(() => {
    setCurrentLanguage(lang);
    document.documentElement.lang = lang;
    document.documentElement.dir = dir;
  }, [lang, dir]);

  const value = useMemo<I18nContextValue>(
    () => ({ lang, formatLocale, dir, t, rich, setLanguage }),
    [lang, formatLocale, dir, t, rich, setLanguage],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}
