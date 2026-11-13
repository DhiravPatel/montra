import type { NamespaceTranslation } from '../../types';
import type en from '../en/paymentMethods';

/** Hindi `paymentMethods` messages; missing keys fall back to English. */
const messages = {
  // Payment methods
  'paymentMethods.title': 'भुगतान के तरीके',
  'paymentMethods.description':
    'आप कैसे भुगतान करते हैं: नकद, UPI, कार्ड और बहुत कुछ। खर्च दर्ज करते समय इनमें से एक चुनें।',
  'paymentMethods.add': 'भुगतान का तरीका जोड़ें',
  'paymentMethods.list.title': 'आपके भुगतान के तरीके',
  'paymentMethods.loading': 'भुगतान के तरीके लोड हो रहे हैं…',
  'paymentMethods.error': 'हम आपके भुगतान के तरीके लोड नहीं कर सके',
  'paymentMethods.empty.title': 'अभी कोई भुगतान का तरीका नहीं',
  'paymentMethods.empty.body':
    'आप कैसे भुगतान करते हैं, जैसे नकद, UPI या कार्ड, उसे जोड़ें ताकि पता चले कि आप कैसे खर्च करते हैं।',
  'paymentMethods.showArchived': 'संग्रहित दिखाएँ',
  'paymentMethods.default': 'डिफ़ॉल्ट',
  'paymentMethods.archived': 'संग्रहित',
  'paymentMethods.linkedTo': '{account} से जुड़ा',
  'paymentMethods.notFound': 'वह भुगतान का तरीका अब मौजूद नहीं है।',
  'paymentMethods.create.title': 'भुगतान का तरीका जोड़ें',
  'paymentMethods.create.submit': 'भुगतान का तरीका जोड़ें',
  'paymentMethods.create.done': 'भुगतान का तरीका जोड़ दिया गया',
  'paymentMethods.edit.title': 'भुगतान का तरीका बदलें',
  'paymentMethods.edit.done': 'भुगतान का तरीका अपडेट हो गया',
  'paymentMethods.form.safety':
    'केवल नाम और, चाहें तो, आखिरी 4 अंक रखें। पूरा कार्ड नंबर, CVV, PIN या OTP कभी न डालें।',
  'paymentMethods.form.kind': 'प्रकार',
  'paymentMethods.form.kindPlaceholder': 'प्रकार चुनें',
  'paymentMethods.form.kindRequired': 'प्रकार चुनें।',
  'paymentMethods.form.label': 'नाम',
  'paymentMethods.form.labelHelp': 'उदाहरण: “HDFC डेबिट कार्ड” या “GPay”।',
  'paymentMethods.form.labelRequired': 'नाम दर्ज करें।',
  'paymentMethods.form.network': 'कार्ड नेटवर्क',
  'paymentMethods.form.hint': 'संकेत',
  'paymentMethods.form.hintHelp': 'उदाहरण: “•••• 4821” या छिपा हुआ UPI हैंडल।',
  'paymentMethods.form.hintUnsafe':
    'ज़्यादा से ज़्यादा आखिरी 4 अंक इस्तेमाल करें। पूरा नंबर कभी न डालें।',
  'paymentMethods.form.account': 'जुड़ा हुआ खाता',
  'paymentMethods.form.accountHelp': 'वह खाता जिससे यह तरीका आमतौर पर भुगतान करता है।',
  'paymentMethods.form.default': 'इसे मेरा डिफ़ॉल्ट बनाएँ',
  'paymentMethods.form.defaultHelp': 'खर्च जोड़ते समय यह सबसे पहले सुझाया जाएगा।',
  'paymentMethods.remove.action': 'हटाएँ',
  'paymentMethods.remove.title': 'यह भुगतान का तरीका हटाएँ?',
  'paymentMethods.remove.body':
    '{label} नए लेन-देन के लिए नहीं दिखेगा। अगर पिछले लेन-देन में इसका इस्तेमाल हुआ है, तो इसे संग्रहित किया जाएगा ताकि उनका इतिहास बना रहे।',
  'paymentMethods.remove.confirm': 'हटाएँ',
  'paymentMethods.remove.done': 'भुगतान का तरीका हटा दिया गया',
  'paymentMethods.remove.archived':
    'भुगतान का तरीका संग्रहित किया गया, क्योंकि पिछले लेन-देन इसका इस्तेमाल करते हैं',
  'paymentMethods.restore.action': 'वापस लाएँ',
  'paymentMethods.restore.done': 'भुगतान का तरीका वापस आ गया',
  'paymentMethods.restore.failed': 'हम भुगतान का तरीका वापस नहीं ला सके',
  'paymentMethods.conflict':
    'इसे कहीं और बदला गया था। हमने नया संस्करण लोड कर दिया है; उसे देखें और फिर से सहेजें।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
