import type { en } from './locales/en';

/** A message with CLDR plural forms, selected with the `count` parameter. */
export type PluralMessage = Readonly<
  Partial<Record<Intl.LDMLPluralRule, string>> & { other: string }
>;

export type Message = string | PluralMessage;

/** Every translation key. The English catalog is the source of truth. */
export type MessageKey = keyof typeof en;

/** Non-English catalogs may be partial; missing keys fall back to English. */
export type PartialCatalog = Readonly<Partial<Record<MessageKey, Message>>>;

export type TranslateParams = Readonly<Record<string, string | number>>;

export type Translate = (key: MessageKey, params?: TranslateParams) => string;
