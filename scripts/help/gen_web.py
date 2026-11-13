"""Emits the web help-guide catalogs and registry from content.py."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import content as c  # noqa: E402

WEB = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'web', 'src')
L = f'{WEB}/shared/i18n/locales'


def q(text):
    return "'" + text.replace('\\', '\\\\').replace("'", "\\'") + "'"


def kebab(name):
    return re.sub(r'([A-Z])', lambda m: '-' + m.group(1).lower(), name)


EXTRA_UI = [
    ('affordanceFor', 'How this works: {guide}', 'यह कैसे काम करता है: {guide}'),
    ('topicGuides', 'Guides about {topic}', '{topic} की गाइड'),
    ('browseTitle', 'Guides and how-tos', 'गाइड और तरीके'),
    ('searchAll', 'Search all guides', 'सभी गाइड में खोजें'),
]


def guides_catalog(lang):
    i = 0 if lang == 'en' else 1
    lines = []
    lines.append('  // Help guides: topics, titles and summaries (the guide text is in helpContent)')
    for tid, en, hi in c.TOPICS:
        lines.append(f"  'helpGuides.topic.{tid}': {q(en if lang == 'en' else hi)},")
    for key, en, hi in c.UI + EXTRA_UI:
        if key == 'resultCount':
            if lang == 'en':
                lines.append("  'helpGuides.ui.resultCount': {")
                lines.append("    one: '{count} guide found',")
                lines.append("    other: '{count} guides found',")
                lines.append('  },')
            else:
                lines.append("  'helpGuides.ui.resultCount': {")
                lines.append("    one: '{count} गाइड मिली',")
                lines.append("    other: '{count} गाइड मिलीं',")
                lines.append('  },')
            continue
        lines.append(f"  'helpGuides.ui.{key}': {q(en if lang == 'en' else hi)},")
    for g in c.GUIDES:
        gid = g['id']
        lines.append(f"  'helpGuides.{gid}.title': {q(g['title'][i])},")
        lines.append(f"  'helpGuides.{gid}.summary': {q(g['summary'][i])},")
        lines.append(f"  'helpGuides.{gid}.link': {q(g['link'][i])},")
    return lines


def content_catalog(lang):
    i = 0 if lang == 'en' else 1
    lines = ['  // Help guide text, one key per section title and paragraph or list item']
    for g in c.GUIDES:
        gid = g['id']
        for sid, title, blocks in g['sections']:
            lines.append(f"  'helpContent.{gid}.{sid}.title': {q(title[i])},")
            for n, (kind, en, hi) in enumerate(blocks, 1):
                lines.append(f"  'helpContent.{gid}.{sid}.{n}': {q(en if lang == 'en' else hi)},")
    return lines


def write_catalog(ns, lang, lines, doc):
    path = f'{L}/{lang}/{ns}.ts'
    if lang == 'en':
        head = ("import type { Message } from '../../types';\n\n"
                f'/** {doc} */\nconst messages = {{\n')
        tail = '\n} as const satisfies Record<string, Message>;\n\nexport default messages;\n'
    else:
        head = ("import type { NamespaceTranslation } from '../../types';\n"
                f"import type en from '../en/{ns}';\n\n"
                f'/** {doc} (Hindi). */\nconst messages = {{\n')
        tail = '\n} as const satisfies NamespaceTranslation<typeof en>;\n\nexport default messages;\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(head + '\n'.join(lines) + tail)


for lang in ('en', 'hi'):
    write_catalog('helpGuides', lang, guides_catalog(lang),
                  'Help guides: topics, titles, summaries and the guide screens’ own strings')
    write_catalog('helpContent', lang, content_catalog(lang),
                  'Help guide text (HELP-001), generated from one source shared with mobile')

# Shared ids, topics and paths (other features link to guides through these).
ids = [g['id'] for g in c.GUIDES]
with open(f'{WEB}/shared/help/guides.ts', 'w', encoding='utf-8') as f:
    f.write("""/**
 * In-app help guides (HELP-001): their IDs, topics and addresses. Screens
 * link to the guide about them through `helpGuidePath()` (or
 * <HelpGuideLink>); the guide pages live in features/support. Slugs match
 * the mobile app's routes (`/help/guides/<slug>`).
 */
export const helpGuideIds = [
""")
    for gid in ids:
        f.write(f"  '{gid}',\n")
    f.write("""] as const;

export type HelpGuideId = (typeof helpGuideIds)[number];

/** Topics in display order, each with its guides in order. */
export const helpTopics = [
""")
    for tid, _, _ in c.TOPICS:
        members = ', '.join(f"'{g['id']}'" for g in c.GUIDES if g['topic'] == tid)
        f.write(f"  {{ id: '{tid}', guides: [{members}] }},\n")
    f.write("""] as const satisfies readonly { id: string; guides: readonly HelpGuideId[] }[];

export type HelpTopicId = (typeof helpTopics)[number]['id'];

export const helpGuidesPath = '/help/guides';

/** `budgets` → `budgets`, `twoStep` → `two-step`. */
export function helpGuideSlug(id: HelpGuideId): string {
  return id.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
}

export function helpGuidePath(id: HelpGuideId, section?: string): string {
  return `${helpGuidesPath}/${helpGuideSlug(id)}${section ? `#${section}` : ''}`;
}

export function guideIdFromSlug(slug: string | undefined): HelpGuideId | null {
  return helpGuideIds.find((id) => helpGuideSlug(id) === slug) ?? null;
}
""")

# Guide structure for the support feature.
os.makedirs(f'{WEB}/features/support/guides', exist_ok=True)
with open(f'{WEB}/features/support/guides/content.ts', 'w', encoding='utf-8') as f:
    f.write("""import type { HelpGuideId } from '@/shared/help/guides';
import type { MessageKey } from '@/shared/i18n/types';

/**
 * The structure of each help guide: sections of paragraphs and list items,
 * by message key (helpContent.*). The text itself is in the catalogs, in
 * English and Hindi, from the same source as the mobile app's guides.
 */
export interface GuideBlock {
  kind: 'p' | 'li';
  key: MessageKey;
}

export interface GuideSection {
  /** Anchor on the guide page (`#pace`). */
  id: string;
  title: MessageKey;
  blocks: readonly GuideBlock[];
}

export const guideSections: Readonly<Record<HelpGuideId, readonly GuideSection[]>> = {
""")
    for g in c.GUIDES:
        gid = g['id']
        f.write(f'  {gid}: [\n')
        for sid, _, blocks in g['sections']:
            f.write('    {\n')
            f.write(f"      id: '{kebab(sid)}',\n")
            f.write(f"      title: 'helpContent.{gid}.{sid}.title',\n")
            f.write('      blocks: [\n')
            for n, (kind, _, _) in enumerate(blocks, 1):
                f.write(f"        {{ kind: '{kind}', key: 'helpContent.{gid}.{sid}.{n}' }},\n")
            f.write('      ],\n    },\n')
        f.write('  ],\n')
    f.write('};\n')

print('ok', len(ids), 'guides')
