import type { NamespaceTranslation } from '../../types';
import type en from '../en/helpGuides';

/** Help guides: topics, titles, summaries and the guide screens’ own strings (Hindi). */
const messages = {
  // Help guides: topics, titles and summaries (the guide text is in helpContent)
  'helpGuides.topic.start': 'शुरुआत',
  'helpGuides.topic.calculations': 'Montra हिसाब कैसे लगाता है',
  'helpGuides.topic.statements': 'स्टेटमेंट और मिलान',
  'helpGuides.topic.account': 'गोपनीयता, सुरक्षा और सीमाएँ',
  'helpGuides.topic.troubleshooting': 'समस्या का समाधान',
  'helpGuides.ui.title': 'गाइड',
  'helpGuides.ui.description': 'चरण-दर-चरण गाइड और Montra आपकी संख्याएँ कैसे निकालता है।',
  'helpGuides.ui.search': 'गाइड में खोजें',
  'helpGuides.ui.searchHelp': 'मौजूदा भाषा में शीर्षक और लिखाई में खोजता है।',
  'helpGuides.ui.noResults':
    '“{query}” से कोई गाइड मेल नहीं खाती। कोई दूसरा शब्द आज़माएँ, या नीचे हमें अनुरोध भेजें।',
  'helpGuides.ui.resultCount': {
    one: '{count} गाइड मिली',
    other: '{count} गाइड मिलीं',
  },
  'helpGuides.ui.open': 'गाइड पढ़ें',
  'helpGuides.ui.back': 'सभी गाइड',
  'helpGuides.ui.onThisPage': 'इस पेज पर',
  'helpGuides.ui.related': 'यह कहाँ करें',
  'helpGuides.ui.notFound': 'यह गाइड मौजूद नहीं है। हो सकता है यह कहीं और चली गई हो।',
  'helpGuides.ui.contact': 'जवाब नहीं मिला? सहायता अनुरोध भेजें।',
  'helpGuides.ui.status': 'सेवा की स्थिति',
  'helpGuides.ui.statusHelp': 'देखें कि क्या Montra में अभी कोई समस्या है।',
  'helpGuides.ui.affordance': 'यह कैसे काम करता है',
  'helpGuides.ui.affordanceFor': 'यह कैसे काम करता है: {guide}',
  'helpGuides.ui.topicGuides': '{topic} की गाइड',
  'helpGuides.ui.browseTitle': 'गाइड और तरीके',
  'helpGuides.ui.searchAll': 'सभी गाइड में खोजें',
  'helpGuides.gettingStarted.title': 'बैंक जोड़े बिना शुरुआत करें',
  'helpGuides.gettingStarted.summary':
    'खाते बनाएँ, लेन-देन दर्ज या आयात करें और आगे की योजना बनाएँ। Montra को कभी आपके बैंक लॉगिन की ज़रूरत नहीं होती।',
  'helpGuides.gettingStarted.link': 'खाता जोड़ें',
  'helpGuides.noBank.title': 'मुझे अपना बैंक क्यों नहीं दिखता?',
  'helpGuides.noBank.summary':
    'Montra अभी किसी बैंक से नहीं जुड़ सकता। जानिए क्यों, और इसके बदले क्या इस्तेमाल करें।',
  'helpGuides.noBank.link': 'जुड़ी सेवाएँ देखें',
  'helpGuides.balances.title': 'बैलेंस का हिसाब कैसे होता है',
  'helpGuides.balances.summary':
    'शुरुआती बैलेंस और हर गिना गया लेन-देन, जिसमें ट्रांसफ़र और समायोजन खर्च से अलग रहते हैं।',
  'helpGuides.balances.link': 'खातों पर जाएँ',
  'helpGuides.budgets.title': 'बजट का हिसाब कैसे होता है',
  'helpGuides.budgets.summary':
    'खर्च में क्या गिना जाता है, रफ़्तार और अनुमान कैसे काम करते हैं, और रिफ़ंड और रोलओवर बजट को कैसे बदलते हैं।',
  'helpGuides.budgets.link': 'बजट पर जाएँ',
  'helpGuides.recurring.title': 'आवर्ती, बिल और सब्सक्रिप्शन',
  'helpGuides.recurring.summary':
    'बार-बार होने वाले लेन-देन कैसे तय और दर्ज होते हैं, बिल की स्थिति कैसे तय होती है, और सब्सक्रिप्शन का कुल और पहचान कैसे होती है।',
  'helpGuides.recurring.link': 'बिल और आवर्ती पर जाएँ',
  'helpGuides.goals.title': 'लक्ष्यों का हिसाब कैसे होता है',
  'helpGuides.goals.summary':
    'बचत में क्या गिना जाता है, पड़ाव कैसे पूरे होते हैं और अनुमान किन बातों पर आधारित है।',
  'helpGuides.goals.link': 'लक्ष्यों पर जाएँ',
  'helpGuides.groupBalances.title': 'समूह के बकाये का हिसाब कैसे होता है',
  'helpGuides.groupBalances.summary':
    'किसका किस पर कितना बकाया है: हर व्यक्ति ने कितना दिया, उसका हिस्सा, और पुष्टि हुए निपटान।',
  'helpGuides.groupBalances.link': 'समूहों पर जाएँ',
  'helpGuides.imports.title': 'स्टेटमेंट आयात करना और असफल आयात ठीक करना',
  'helpGuides.imports.summary':
    'स्टेटमेंट फ़ाइल अपलोड करें, कॉलम जाँचें, पंक्तियाँ और डुप्लिकेट देखें, और कुछ गलत होने पर उसे ठीक करें।',
  'helpGuides.imports.link': 'आयात पर जाएँ',
  'helpGuides.reconciliation.title': 'खाते का मिलान करना',
  'helpGuides.reconciliation.summary':
    'स्टेटमेंट की पंक्तियों को अपने लेन-देन से मिलाएँ और बैलेंस की तुलना स्टेटमेंट से करें।',
  'helpGuides.reconciliation.link': 'खातों पर जाएँ',
  'helpGuides.privacy.title': 'गोपनीयता, एक्सपोर्ट और खाता हटाना',
  'helpGuides.privacy.summary':
    'वैकल्पिक सहमतियाँ चुनें, अपने डेटा की कॉपी डाउनलोड करें, खाता रोकें या हटाएँ।',
  'helpGuides.privacy.link': 'गोपनीयता और डेटा पर जाएँ',
  'helpGuides.twoStep.title': 'दो-चरणीय सत्यापन और रिकवरी',
  'helpGuides.twoStep.summary':
    'ऑथेंटिकेटर ऐप से साइन-इन सुरक्षित करें, और फ़ोन न होने की स्थिति के लिए रिकवरी कोड रखें।',
  'helpGuides.twoStep.link': 'सुरक्षा सेटिंग पर जाएँ',
  'helpGuides.fairUse.title': 'उचित उपयोग की सीमाएँ',
  'helpGuides.fairUse.summary':
    'सभी पर एक जैसी सीमाएँ लागू होती हैं। ये Montra को तेज़ रखती हैं; ये कभी सशुल्क स्तर नहीं हैं।',
  'helpGuides.fairUse.link': 'सीमाएँ और अपना उपयोग देखें',
  'helpGuides.troubleshooting.title': 'साइन-इन, सिंक और सूचनाओं की समस्याएँ',
  'helpGuides.troubleshooting.summary':
    'जब साइन इन न हो पाए, डेटा पुराना लगे, या सूचनाएँ न आएँ, तो क्या जाँचें।',
  'helpGuides.troubleshooting.link': 'सूचना सेटिंग पर जाएँ',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
