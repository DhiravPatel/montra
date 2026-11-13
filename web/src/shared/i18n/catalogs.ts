import { readPreference } from '@/shared/utils/preferences';
import {
  browserLocales,
  detectLanguage,
  isSupportedLanguage,
  type Language,
  supportedLanguages,
} from './languages';
import coreMessages from './locales/en/core';
import { catalogLoaders, type LazyNamespace, type Namespace, namespaces } from './namespaces.gen';
import type { Message } from './types';

/**
 * Message catalogs, loaded per namespace (one per top-level key prefix).
 *
 * English `core` (what the first screen needs) ships with the app; every
 * other namespace, and every Hindi catalog, is its own chunk that loads with
 * the routes that use it (app/router/routeMessages.gen.ts). English is always
 * loaded next to another language, because missing translations fall back
 * to it. This module is the single source of the interface language outside
 * React (route loaders run before anything renders).
 */

type Catalog = Readonly<Record<string, Message>>;

const lazyNamespaces: ReadonlySet<string> = new Set(namespaces.filter((ns) => ns !== 'core'));

const loaded: Record<Language, Map<Namespace, Catalog>> = {
  en: new Map<Namespace, Catalog>([['core', coreMessages]]),
  hi: new Map<Namespace, Catalog>(),
};
const inFlight = new Map<string, Promise<void>>();
const listeners = new Set<() => void>();
let version = 0;

function initialLanguage(): Language {
  const saved = readPreference('lang');
  return isSupportedLanguage(saved) ? saved : detectLanguage(browserLocales());
}

let currentLanguage: Language = initialLanguage();

/** The namespace a key belongs to (its prefix, unless the prefix is part of core). */
export function namespaceOf(key: string): Namespace {
  const prefix = key.slice(0, key.indexOf('.'));
  return lazyNamespaces.has(prefix) ? (prefix as LazyNamespace) : 'core';
}

function notify() {
  version += 1;
  for (const listener of listeners) listener();
}

function loadOne(lang: Language, ns: Namespace): Promise<void> {
  if (loaded[lang].has(ns)) return Promise.resolve();
  const id = `${lang}/${ns}`;
  const running = inFlight.get(id);
  if (running) return running;
  const loaders: Partial<Record<Namespace, () => Promise<{ default: Catalog }>>> =
    catalogLoaders[lang];
  const loader = loaders[ns];
  if (!loader) return Promise.resolve();
  const promise = loader()
    .then((module) => {
      loaded[lang].set(ns, module.default);
      notify();
    })
    .finally(() => {
      inFlight.delete(id);
    });
  inFlight.set(id, promise);
  return promise;
}

/** Whether these namespaces (and core) are ready to render in `lang`. */
export function hasNamespaces(lang: Language, list: readonly Namespace[]): boolean {
  const needed: readonly Namespace[] = ['core', ...list];
  return needed.every((ns) => loaded.en.has(ns) && (lang === 'en' || loaded[lang].has(ns)));
}

/** Loads core and `list` for `lang` (and English, the fallback). */
export function loadNamespaces(lang: Language, list: readonly Namespace[] = []): Promise<void> {
  if (hasNamespaces(lang, list)) return Promise.resolve();
  const needed: readonly Namespace[] = ['core', ...list];
  const work = needed.flatMap((ns) =>
    lang === 'en' ? [loadOne('en', ns)] : [loadOne('en', ns), loadOne(lang, ns)],
  );
  return Promise.all(work).then(() => undefined);
}

/** Loads what a route needs in the current interface language. */
export function loadRouteNamespaces(list: readonly Namespace[]): Promise<void> {
  return loadNamespaces(currentLanguage, list);
}

/** Every namespace loaded so far (in English, which is always loaded first). */
export function loadedNamespaces(): Namespace[] {
  return [...loaded.en.keys()];
}

/** Looks a key up in `lang`, falling back to English; undefined when its namespace isn't loaded. */
export function lookupMessage(lang: Language, key: string): Message | undefined {
  const ns = namespaceOf(key);
  return loaded[lang].get(ns)?.[key] ?? loaded.en.get(ns)?.[key];
}

const warned = new Set<string>();

/**
 * A key was used before its namespace loaded (a route's namespaces come from
 * a static scan, so this means a key the scan cannot see). Load it now; the
 * provider re-renders when it arrives.
 */
export function requestMissing(lang: Language, key: string): void {
  const ns = namespaceOf(key);
  if (import.meta.env.DEV && !warned.has(ns)) {
    warned.add(ns);
    // eslint-disable-next-line no-console -- development-only diagnostic for a missed namespace
    console.warn(`[i18n] "${key}" was used before the "${ns}" messages loaded.`);
  }
  void loadNamespaces(lang, [ns]).catch(() => undefined);
}

export function getCurrentLanguage(): Language {
  return currentLanguage;
}

export function setCurrentLanguage(lang: Language): void {
  currentLanguage = lang;
}

export function subscribeCatalogs(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function catalogVersion(): number {
  return version;
}

/** Loads every catalog in every language (tests; never used by the app). */
export async function loadAllCatalogs(): Promise<void> {
  await Promise.all(supportedLanguages.map((lang) => loadNamespaces(lang, [...namespaces])));
}
