import type { NamespaceTranslation } from '../../types';
import type en from '../en/savedFilters';

/** Hindi `savedFilters` messages; missing keys fall back to English. */
const messages = {
  'savedFilters.open': {
    one: 'सहेजे गए फ़िल्टर ({count})',
    other: 'सहेजे गए फ़िल्टर ({count})',
  },
  'savedFilters.openEmpty': 'सहेजे गए फ़िल्टर',
  'savedFilters.title.transactions': 'सहेजे गए फ़िल्टर',
  'savedFilters.title.search': 'सहेजी गई खोजें',
  'savedFilters.description':
    'ये आपके खाते के साथ सहेजे जाते हैं, इसलिए Montra ऐप में भी काम करते हैं। खोज का शब्द और रकम भी सहेजी जाती है, पर कभी लिंक में नहीं दिखती।',
  'savedFilters.save.title.transactions': 'मौजूदा फ़िल्टर सहेजें',
  'savedFilters.save.title.search': 'यह खोज सहेजें',
  'savedFilters.save.name': 'नाम',
  'savedFilters.save.nameHelp': 'ज़्यादा से ज़्यादा 80 अक्षर, आपके दूसरे सहेजे फ़िल्टर से अलग।',
  'savedFilters.save.submit': 'सहेजें',
  'savedFilters.save.nothing.transactions':
    'पहले कोई फ़िल्टर, अवधि, क्रम या खोज चुनें, फिर उसे यहाँ सहेजें।',
  'savedFilters.save.nothing.search': 'खोजने के लिए कम से कम 2 अक्षर लिखें, फिर उसे यहाँ सहेजें।',
  'savedFilters.save.done': '“{name}” सहेजा गया',
  'savedFilters.errors.nameRequired': 'नाम दर्ज करें।',
  'savedFilters.errors.nameTooLong': 'ज़्यादा से ज़्यादा 80 अक्षर इस्तेमाल करें।',
  'savedFilters.errors.duplicate': '“{name}” नाम का सहेजा फ़िल्टर पहले से है। कोई दूसरा नाम चुनें।',
  'savedFilters.errors.nameInvalid': 'यह नाम इस्तेमाल नहीं हो सकता। कोई दूसरा आज़माएँ।',
  'savedFilters.errors.filterRejected':
    'ये फ़िल्टर सहेजे नहीं जा सके। इनमें से कुछ हटाकर फिर से प्रयास करें।',
  'savedFilters.list.title.transactions': 'आपके सहेजे फ़िल्टर',
  'savedFilters.list.title.search': 'आपकी सहेजी खोजें',
  'savedFilters.list.loading': 'सहेजे गए फ़िल्टर लोड हो रहे हैं…',
  'savedFilters.list.error': 'सहेजे गए फ़िल्टर लोड नहीं हो सके',
  'savedFilters.list.empty': 'अभी कुछ भी सहेजा नहीं गया है।',
  'savedFilters.list.unusable': 'Montra के इस संस्करण में इस्तेमाल नहीं हो सकता।',
  'savedFilters.list.savedOn': '{date} को सहेजा गया',
  'savedFilters.apply': 'लागू करें',
  'savedFilters.applyNamed': '{name} लागू करें',
  'savedFilters.applied': '“{name}” लागू किया गया',
  'savedFilters.appliedPartly': 'इसके कुछ फ़िल्टर यहाँ उपलब्ध नहीं हैं, इसलिए छोड़ दिए गए।',
  'savedFilters.delete': 'हटाएँ',
  'savedFilters.deleteNamed': '{name} हटाएँ',
  'savedFilters.delete.title': '“{name}” हटाएँ?',
  'savedFilters.delete.body': 'केवल सहेजा गया फ़िल्टर हटेगा। और कुछ नहीं बदलेगा।',
  'savedFilters.delete.confirm': 'सहेजा फ़िल्टर हटाएँ',
  'savedFilters.deleted': '“{name}” हटाया गया',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
