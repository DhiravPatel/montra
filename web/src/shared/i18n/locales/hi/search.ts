import type { NamespaceTranslation } from '../../types';
import type en from '../en/search';

/** Hindi `search` messages; missing keys fall back to English. */
const messages = {
  // Global search (round 5)
  'search.header.label': 'Montra में खोजें',
  'search.header.placeholder': 'Montra में खोजें',
  'search.header.open': 'खोज खोलें',
  'search.title': 'खोजें',
  'search.description':
    'अपने लेन-देन, खाते, व्यापारी, श्रेणियाँ, बजट, बिल, सब्सक्रिप्शन, आवर्ती चीज़ें, लक्ष्य और समूह खोजें, साथ ही समुदाय की पोस्ट और वे लोग जिनसे आप जुड़ सकते हैं।',
  'search.form.label': 'Montra में खोजें',
  'search.field.label': 'क्या खोजना है',
  'search.field.placeholder': 'व्यापारी, विवरण, खाता या लक्ष्य',
  'search.field.help':
    'कम से कम 2 अक्षर लिखें। लिखते ही नतीजे बदलते हैं। किसी खोज को हाल की खोजों में रखने के लिए Enter दबाएँ।',
  'search.tooShort': 'खोजने के लिए कम से कम 2 अक्षर लिखें।',
  'search.scope.label': 'कहाँ खोजें',
  'search.scope.all': 'सब कुछ',
  'search.sort.label': 'क्रम',
  'search.sort.relevance': 'सबसे मिलता-जुलता',
  'search.sort.name': 'नाम से',
  'search.sort.recent': 'सबसे नया पहले',
  'search.submit': 'खोजें',
  'search.loading': 'खोज रहे हैं…',
  'search.updating': 'नतीजे अपडेट हो रहे हैं…',
  'search.error': 'हम अभी खोज नहीं सके',
  'search.results.summary': {
    one: '“{query}” के लिए {count} नतीजा',
    other: '“{query}” के लिए {count} नतीजे',
  },
  'search.results.announce': { one: '{count} नतीजा मिला', other: '{count} नतीजे मिले' },
  'search.results.count': { one: '{count} नतीजा', other: '{count} नतीजे' },
  'search.results.sortedBy': 'क्रम: {order}',
  'search.empty.title': '“{query}” के लिए कोई नतीजा नहीं',
  'search.empty.body':
    'वर्तनी जाँचें या कम शब्द आज़माएँ। खोज लेन-देन के विवरण, नोट्स और व्यापारियों में; खातों, व्यापारियों, श्रेणियों, बजट, बिलों, सब्सक्रिप्शन, आवर्ती चीज़ों, लक्ष्यों और समूहों के नामों में; आपके पढ़ने लायक समुदाय की पोस्ट में; और उन लोगों में देखती है जिन्होंने अपने सटीक यूज़रनेम से खोजे जाने का विकल्प चुना है।',
  'search.empty.announce': 'कोई नतीजा नहीं मिला',
  'search.empty.searchEverything': 'सब कुछ खोजें',
  'search.section.transactions': 'लेन-देन',
  'search.section.accounts': 'खाते',
  'search.section.merchants': 'व्यापारी',
  'search.section.categories': 'श्रेणियाँ',
  'search.section.budgets': 'बजट',
  'search.section.bills': 'बिल',
  'search.section.subscriptions': 'सब्सक्रिप्शन',
  'search.section.recurring_rules': 'आवर्ती चीज़ें',
  'search.section.goals': 'लक्ष्य',
  'search.section.groups': 'समूह',
  'search.section.posts': 'समुदाय की पोस्ट',
  'search.section.users': 'लोग',
  'search.section.more': '{section} में और दिखाएँ',
  'search.section.limitReached': {
    one: 'पहला {count} नतीजा दिखाया जा रहा है। खोज को छोटा करने के लिए और शब्द जोड़ें।',
    other: 'पहले {count} नतीजे दिखाए जा रहे हैं। खोज को छोटा करने के लिए और शब्द जोड़ें।',
  },
  'search.kind.bill.active': 'सक्रिय बिल',
  'search.kind.bill.paused': 'रोका गया बिल',
  'search.kind.bill.archived': 'संग्रहित बिल',
  'search.tx.untitled': 'लेन-देन',
  'search.tx.shared': 'आपके साथ साझा',
  'search.user.username': '@{username}',
  'search.users.connectHint': 'किसी से जुड़ने के लिए, दोस्त पेज पर उनका सटीक यूज़रनेम खोजें।',
  'search.users.findLink': 'लोगों को खोजें',
  'search.recent.title': 'हाल की खोजें',
  'search.recent.description':
    'आपकी सबमिट की गई खोजें आपके खाते में रखी जाती हैं, सबसे नई पहले (20 तक)। इन्हें सिर्फ़ आप देख सकते हैं।',
  'search.recent.loading': 'हाल की खोजें लोड हो रही हैं…',
  'search.recent.error': 'हम आपकी हाल की खोजें लोड नहीं कर सके',
  'search.recent.empty': 'अभी कोई हाल की खोज नहीं।',
  'search.recent.inScope': '{section} में',
  'search.recent.clear': 'इतिहास मिटाएँ',
  'search.recent.clearTitle': 'अपना खोज इतिहास मिटाएँ?',
  'search.recent.clearBody':
    'इससे आपके खाते से सभी हाल की खोजें हट जाएँगी। आपके रिकॉर्ड नहीं बदलेंगे।',
  'search.recent.clearConfirm': 'इतिहास मिटाएँ',
  'search.recent.cleared': 'खोज इतिहास मिटा दिया गया',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
