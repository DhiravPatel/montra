"""Generates mobile ARB entries and Dart registries for help guides and
saved-filter strings. Run: python3 gen_mobile.py <mobile dir>."""
import json
import os
import re
import sys
from collections import OrderedDict

sys.path.insert(0, os.path.dirname(__file__))
import content  # noqa: E402

MOBILE = sys.argv[1]
EN = os.path.join(MOBILE, 'lib/app/l10n/arb/app_en.arb')
HI = os.path.join(MOBILE, 'lib/app/l10n/arb/app_hi.arb')


def cap(s):
    return s[0].upper() + s[1:]


def slug(i):
    return re.sub(r'([A-Z])', lambda m: '-' + m.group(1).lower(), i)


en = OrderedDict()
hi = OrderedDict()
meta = {}

# Saved filters (mobile UI strings).
SAVED = [
    ('savedFiltersOpen', 'Saved filters', 'सहेजे गए फ़िल्टर'),
    ('savedSearchesOpen', 'Saved searches', 'सहेजी गई खोजें'),
    ('savedFiltersTitle', 'Saved filters', 'सहेजे गए फ़िल्टर'),
    ('savedSearchesTitle', 'Saved searches', 'सहेजी गई खोजें'),
    ('savedFiltersSaveCurrent', 'Save current filters', 'मौजूदा फ़िल्टर सहेजें'),
    ('savedSearchesSaveCurrent', 'Save this search', 'यह खोज सहेजें'),
    ('savedFiltersNothingToSave', 'Search or choose filters first, then save them here.', 'पहले खोजें या फ़िल्टर चुनें, फिर उन्हें यहाँ सहेजें।'),
    ('savedSearchesNothingToSave', 'Type at least 2 characters to save a search.', 'खोज सहेजने के लिए कम से कम 2 अक्षर लिखें।'),
    ('savedFiltersEmpty', 'Nothing saved yet. What you save is kept with your account, so it’s on the web too.', 'अभी कुछ सहेजा नहीं गया है। आप जो सहेजते हैं वह आपके खाते के साथ रहता है, इसलिए वेब पर भी दिखता है।'),
    ('savedFiltersSaveTitle', 'Save filters', 'फ़िल्टर सहेजें'),
    ('savedSearchesSaveTitle', 'Save search', 'खोज सहेजें'),
    ('savedFiltersNameLabel', 'Name', 'नाम'),
    ('savedFiltersNameHelp', 'For example “Groceries this month”. Up to 80 characters.', 'जैसे “इस महीने का किराना”। 80 अक्षरों तक।'),
    ('savedFiltersNameRequired', 'Enter a name.', 'कोई नाम लिखें।'),
    ('savedFiltersNameTooLong', 'Use 80 characters or fewer.', '80 या उससे कम अक्षर इस्तेमाल करें।'),
    ('savedFiltersNameTaken', 'You already saved one with this name. Choose another name.', 'इस नाम से आप पहले ही कुछ सहेज चुके हैं। कोई दूसरा नाम चुनें।'),
    ('savedFiltersFilterInvalid', 'These filters can’t be saved. Change them and try again.', 'ये फ़िल्टर सहेजे नहीं जा सकते। इन्हें बदलकर फिर से कोशिश करें।'),
    ('savedFiltersSaveAction', 'Save', 'सहेजें'),
    ('savedFiltersSaved', 'Saved “{name}”.', '“{name}” सहेजा गया।'),
    ('savedFiltersApplied', 'Showing “{name}”.', '“{name}” दिखाया जा रहा है।'),
    ('savedFiltersDeleteTooltip', 'Delete “{name}”', '“{name}” हटाएँ'),
    ('savedFiltersDeleteTitle', 'Delete “{name}”?', '“{name}” हटाएँ?'),
    ('savedFiltersDeleteBody', 'It’s removed from your account on every device. Your records don’t change.', 'यह हर डिवाइस पर आपके खाते से हट जाएगा। आपके रिकॉर्ड नहीं बदलते।'),
    ('savedFiltersDeleted', 'Deleted “{name}”.', '“{name}” हटाया गया।'),
    ('savedFiltersAlreadyGone', '“{name}” was already deleted.', '“{name}” पहले ही हटाया जा चुका था।'),
    ('savedFiltersUnusable', 'Can’t be used in this version of the app.', 'ऐप के इस वर्शन में इस्तेमाल नहीं हो सकता।'),
    ('savedFiltersSearchFor', 'Search: “{query}”', 'खोज: “{query}”'),
]
for key, e, h in SAVED:
    en[key] = e
    hi[key] = h
    ph = re.findall(r'\{(\w+)\}', e)
    if ph:
        meta[key] = {'placeholders': {p: {'type': 'String'} for p in ph}}
en['savedFiltersCount'] = '{count, plural, =0{No filters} =1{1 filter} other{{count} filters}}'
hi['savedFiltersCount'] = '{count, plural, =0{कोई फ़िल्टर नहीं} =1{1 फ़िल्टर} other{{count} फ़िल्टर}}'
meta['savedFiltersCount'] = {'placeholders': {'count': {'type': 'int'}}}

# Help guides.
for tid, e, h in content.TOPICS:
    en['helpGuideTopic' + cap(tid)] = e
    hi['helpGuideTopic' + cap(tid)] = h
for k, e, h in content.UI:
    key = 'helpGuides' + cap(k)
    if k == 'resultCount':
        en[key] = '{count, plural, =1{1 guide found} other{{count} guides found}}'
        hi[key] = '{count, plural, =1{1 गाइड मिली} other{{count} गाइड मिलीं}}'
        meta[key] = {'placeholders': {'count': {'type': 'int'}}}
        continue
    en[key] = e
    hi[key] = h
    ph = re.findall(r'\{(\w+)\}', e)
    if ph:
        meta[key] = {'placeholders': {p: {'type': 'String'} for p in ph}}
en['helpGuidesAffordanceFor'] = 'How this works: {guide}'
hi['helpGuidesAffordanceFor'] = 'यह कैसे काम करता है: {guide}'
meta['helpGuidesAffordanceFor'] = {'placeholders': {'guide': {'type': 'String'}}}

dart_guides = []
for g in content.GUIDES:
    gid = g['id']
    base = 'helpGuide' + cap(gid)
    for part in ('title', 'summary', 'link'):
        en[base + cap(part)] = g[part][0]
        hi[base + cap(part)] = g[part][1]
    secs = []
    for sid, (te, th), blocks in g['sections']:
        sk = base + cap(sid)
        en[sk + 'Title'] = te
        hi[sk + 'Title'] = th
        bl = []
        for n, (kind, be, bh) in enumerate(blocks, 1):
            bk = '%sB%d' % (sk, n)
            en[bk] = be
            hi[bk] = bh
            bl.append((kind, bk))
        secs.append((sid, sk + 'Title', bl))
    dart_guides.append((gid, g['topic'], base, secs))

for d in (en, hi):
    for k, v in d.items():
        assert '{' not in v or k in meta, k


def merge(path, entries, with_meta):
    with open(path, encoding='utf-8') as f:
        data = json.load(f, object_pairs_hook=OrderedDict)
    # Drop earlier generated keys so the script can be re-run.
    for k in list(data):
        bare = k.lstrip('@')
        if bare.startswith('helpGuide') or bare.startswith('savedFilters') or bare.startswith('savedSearches'):
            del data[k]
    for k, v in entries.items():
        data[k] = v
        if with_meta and k in meta:
            data['@' + k] = meta[k]
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


merge(EN, en, True)
merge(HI, hi, False)

# Dart: guide ids (core) and content (support feature).
ids = [g[0] for g in dart_guides]
core = ['// Help guide identifiers and titles (HELP-001). The guide text is in the',
        '// ARB files (`helpGuide*` keys); the structure is in',
        '// features/support/domain/help_guide_content.dart.',
        '',
        "import 'package:montra_mobile/app/l10n/l10n.dart';",
        '',
        '/// One in-app help guide. Screens link to their guide with',
        '/// `HelpGuideButton`; the path matches the web (`/help/guides/<slug>`).',
        'enum HelpGuide {']
for i in ids:
    doc = dict((g['id'], g['title'][0]) for g in content.GUIDES)[i]
    core.append('  /// %s' % doc)
    core.append("  %s('%s')%s" % (i, slug(i), ',' if i != ids[-1] else ';'))
    core.append('')
core[-1:] = ['',
             '  const HelpGuide(this.slug);',
             '',
             '  /// URL segment.',
             '  final String slug;',
             '',
             '  /// The guides list.',
             "  static const String listPath = '/help/guides';",
             '',
             '  /// This guide\'s screen.',
             "  String get path => '$listPath/$slug';",
             '',
             '  /// The guide for a URL [slug], or null.',
             '  static HelpGuide? fromSlug(String slug) {',
             '    for (final HelpGuide guide in values) {',
             '      if (guide.slug == slug) {',
             '        return guide;',
             '      }',
             '    }',
             '    return null;',
             '  }',
             '',
             '  /// The guide\'s title in the current language.',
             '  String title(AppLocalizations l10n) => switch (this) {']
for i in ids:
    core.append('    HelpGuide.%s => l10n.helpGuide%sTitle,' % (i, cap(i)))
core += ['  };', '}', '']
with open(os.path.join(MOBILE, 'lib/core/help/help_guide.dart'), 'w') as f:
    f.write('\n'.join(core))

out = ['// Structure of the help guides (HELP-001): topics, sections and',
       '// paragraphs. The text is in the ARB files (`helpGuide*` keys), in',
       '// English and Hindi, and matches the web guides.',
       '',
       "import 'package:flutter/foundation.dart';",
       "import 'package:montra_mobile/app/l10n/l10n.dart';",
       "import 'package:montra_mobile/core/help/help_guide.dart';",
       '',
       '/// Reads one string from the localizations.',
       'typedef L10nText = String Function(AppLocalizations l10n);',
       '',
       '/// Groups of guides, in display order.',
       'enum HelpGuideTopic {']
for tid, e, _ in content.TOPICS:
    out.append('  /// %s' % e)
    out.append('  %s(_topic%s),' % (tid, cap(tid)))
    out.append('')
out[-2] = out[-2][:-1] + ';' if False else out[-2]
out[-1:] = []
# fix last comma
out[-1] = out[-1][:-1] + ';'
out += ['',
        '  const HelpGuideTopic(this.title);',
        '',
        '  /// Heading.',
        '  final L10nText title;',
        '}',
        '']
for tid, _, _ in content.TOPICS:
    out.append('String _topic%s(AppLocalizations l) => l.helpGuideTopic%s;' % (cap(tid), cap(tid)))
out += ['',
        '/// One paragraph or bullet.',
        '@immutable',
        'class HelpGuideBlock {',
        '  /// Creates the block.',
        '  const HelpGuideBlock(this.text, {this.bullet = false});',
        '',
        '  /// The text.',
        '  final L10nText text;',
        '',
        '  /// Whether it is a list item.',
        '  final bool bullet;',
        '}',
        '',
        '/// A titled part of a guide.',
        '@immutable',
        'class HelpGuideSection {',
        '  /// Creates the section.',
        '  const HelpGuideSection(this.id, this.title, this.blocks);',
        '',
        '  /// Stable id (for anchors).',
        '  final String id;',
        '',
        '  /// Heading.',
        '  final L10nText title;',
        '',
        '  /// Paragraphs and bullets in order.',
        '  final List<HelpGuideBlock> blocks;',
        '}',
        '',
        '/// One guide\'s content.',
        '@immutable',
        'class HelpGuideContent {',
        '  /// Creates the content.',
        '  const HelpGuideContent({',
        '    required this.guide,',
        '    required this.topic,',
        '    required this.summary,',
        '    required this.linkLabel,',
        '    required this.sections,',
        '  });',
        '',
        '  /// Which guide.',
        '  final HelpGuide guide;',
        '',
        '  /// Its topic.',
        '  final HelpGuideTopic topic;',
        '',
        '  /// One-line summary.',
        '  final L10nText summary;',
        '',
        '  /// Label of the link to the screen the guide is about.',
        '  final L10nText linkLabel;',
        '',
        '  /// Sections in order.',
        '  final List<HelpGuideSection> sections;',
        '',
        '  /// Every string of the guide, for searching.',
        '  Iterable<String> texts(AppLocalizations l10n) sync* {',
        '    yield guide.title(l10n);',
        '    yield summary(l10n);',
        '    for (final HelpGuideSection section in sections) {',
        '      yield section.title(l10n);',
        '      for (final HelpGuideBlock block in section.blocks) {',
        '        yield block.text(l10n);',
        '      }',
        '    }',
        '  }',
        '}',
        '',
        '/// Every guide, in display order within its topic.',
        'const List<HelpGuideContent> helpGuides = <HelpGuideContent>[']
for gid, topic, base, secs in dart_guides:
    out += ['  HelpGuideContent(',
            '    guide: HelpGuide.%s,' % gid,
            '    topic: HelpGuideTopic.%s,' % topic,
            '    summary: _%sSummary,' % gid,
            '    linkLabel: _%sLink,' % gid,
            '    sections: <HelpGuideSection>[']
    for sid, tkey, bl in secs:
        out.append("      HelpGuideSection('%s', _%s, <HelpGuideBlock>[" % (sid, tkey))
        for kind, bk in bl:
            out.append('        HelpGuideBlock(_%s%s),' % (bk, ', bullet: true' if kind == 'li' else ''))
        out.append('      ]),')
    out += ['    ],', '  ),']
out += ['];', '', '/// The content of [guide].',
        'HelpGuideContent helpGuideContent(HelpGuide guide) =>',
        '    helpGuides.firstWhere((HelpGuideContent c) => c.guide == guide);', '']
keys = []
for gid, topic, base, secs in dart_guides:
    keys.append(('_%sSummary' % gid, base + 'Summary'))
    keys.append(('_%sLink' % gid, base + 'Link'))
    for sid, tkey, bl in secs:
        keys.append(('_' + tkey, tkey))
        for kind, bk in bl:
            keys.append(('_' + bk, bk))
for fn, key in keys:
    out.append('String %s(AppLocalizations l) => l.%s;' % (fn, key))
out.append('')
with open(os.path.join(MOBILE, 'lib/features/support/domain/help_guide_content.dart'), 'w') as f:
    f.write('\n'.join(out))
print('guides', len(dart_guides), 'en keys', len(en))
