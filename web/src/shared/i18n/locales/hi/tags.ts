import type { NamespaceTranslation } from '../../types';
import type en from '../en/tags';

/** Hindi `tags` messages; missing keys fall back to English. */
const messages = {
  'tags.title': 'टैग',
  'tags.description':
    'टैग ऐसे लेबल हैं जिन्हें आप किसी भी लेन-देन पर लगा सकते हैं, जैसे “ऑफ़िस ट्रिप” या “शादी”।',
  'tags.add': 'टैग जोड़ें',
  'tags.list.title': 'आपके टैग',
  'tags.loading': 'टैग लोड हो रहे हैं…',
  'tags.error': 'हम आपके टैग लोड नहीं कर सके',
  'tags.empty.title': 'अभी कोई टैग नहीं',
  'tags.empty.body': 'यहाँ टैग जोड़ें, या लेन-देन जोड़ते समय टैग लिखें।',
  'tags.allArchived': 'आपके सभी टैग संग्रहित हैं। उन्हें देखने के लिए “संग्रहित दिखाएँ” चालू करें।',
  'tags.usage': { one: '{count} लेन-देन पर लगा है', other: '{count} लेन-देन पर लगा है' },
  'tags.unused': 'अभी इस्तेमाल नहीं हुआ',
  'tags.create.title': 'टैग जोड़ें',
  'tags.create.submit': 'टैग जोड़ें',
  'tags.create.done': 'टैग जोड़ दिया गया',
  'tags.edit.title': 'टैग बदलें',
  'tags.edit.done': 'टैग अपडेट हो गया',
  'tags.form.name': 'नाम',
  'tags.form.nameRequired': 'नाम दर्ज करें।',
  'tags.form.duplicate': 'इस नाम का टैग पहले से है।',
  'tags.archive.action': 'संग्रहित करें',
  'tags.archive.done': 'टैग संग्रहित किया गया। यह पिछले लेन-देन पर बना रहेगा।',
  'tags.unarchive.action': 'संग्रह से निकालें',
  'tags.unarchive.done': 'टैग फिर से सक्रिय है',
  'tags.status.failed': 'हम टैग अपडेट नहीं कर सके',
  'tags.delete.action': 'हटाएँ',
  'tags.delete.title': 'यह टैग हटाएँ?',
  'tags.delete.body': {
    one: '“{name}” {count} लेन-देन से हटा दिया जाएगा। लेन-देन वैसा ही रहेगा।',
    other: '“{name}” {count} लेन-देन से हटा दिया जाएगा। लेन-देन वैसे ही रहेंगे।',
  },
  'tags.delete.bodyUnused': '“{name}” किसी लेन-देन पर नहीं लगा है।',
  'tags.delete.confirm': 'टैग हटाएँ',
  'tags.delete.done': 'टैग हटा दिया गया',
  'tags.notFound': 'वह टैग अब मौजूद नहीं है।',
  'tags.status.reloaded':
    'यह टैग कहीं और बदला गया था। हमने नया संस्करण लोड कर दिया है, उसे देखें और फिर से कोशिश करें।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
