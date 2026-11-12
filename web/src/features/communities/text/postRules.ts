import type { Translate } from '@/shared/i18n/types';
import { countLinks, looksSecret, safeHref } from './userText';

/** Limits the API applies to posts (spec §20B.17 spam controls). */
export const TITLE_MAX = 200;
export const BODY_MAX = 10_000;
export const LINK_MAX = 500;
export const MAX_LINKS = 3;

export type PostTextField = 'title' | 'body';

function chars(text: string): number {
  return Array.from(text).length;
}

/** Checks a title and body the way the API does, so problems show before sending. */
export function validatePostText(
  title: string,
  body: string,
  t: Translate,
): Partial<Record<PostTextField, string>> {
  const errors: Partial<Record<PostTextField, string>> = {};
  const titleText = title.trim();
  if (chars(titleText) < 3) errors.title = t('communities.composer.titleRequired');
  else if (chars(titleText) > TITLE_MAX) {
    errors.title = t('validation.maxLength', { max: TITLE_MAX });
  } else if (looksSecret(titleText)) errors.title = t('communities.field.secret');
  const bodyText = body.trim();
  if (chars(bodyText) > BODY_MAX) errors.body = t('validation.maxLength', { max: BODY_MAX });
  else if (countLinks(bodyText) > MAX_LINKS) errors.body = t('communities.field.links');
  else if (looksSecret(bodyText)) errors.body = t('communities.field.secret');
  return errors;
}

/** A public https address, as the API requires for resource links; null when fine. */
export function validateResourceLink(link: string, t: Translate): string | null {
  const text = link.trim();
  if (!text) return t('communities.field.linkRequired');
  if (text.length > LINK_MAX || !text.toLowerCase().startsWith('https://') || !safeHref(text)) {
    return t('communities.field.httpsLink');
  }
  return null;
}
