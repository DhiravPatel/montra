import { type HelpGuideId, helpGuideIds } from '@/shared/help/guides';
import type { Translate } from '@/shared/i18n/types';
import { guideSections } from './content';

/** Everything a guide says, in the interface language, for searching. */
export function guideText(id: HelpGuideId, t: Translate): string {
  const parts = [t(`helpGuides.${id}.title`), t(`helpGuides.${id}.summary`)];
  for (const section of guideSections[id]) {
    parts.push(t(section.title));
    for (const block of section.blocks) parts.push(t(block.key));
  }
  return parts.join(' ');
}

function fold(text: string, locale: string): string {
  return text.normalize('NFC').toLocaleLowerCase(locale);
}

/** Search words: whitespace-separated, at most 10 (longer queries add nothing). */
export function searchWords(query: string, locale: string): string[] {
  return fold(query, locale).split(/\s+/u).filter(Boolean).slice(0, 10);
}

/**
 * Guides containing every word of the query (in any order), in the guides'
 * usual order. An empty query matches every guide.
 */
export function searchGuides(query: string, t: Translate, locale: string): HelpGuideId[] {
  const words = searchWords(query, locale);
  if (words.length === 0) return [...helpGuideIds];
  return helpGuideIds.filter((id) => {
    const text = fold(guideText(id, t), locale);
    return words.every((word) => text.includes(word));
  });
}
