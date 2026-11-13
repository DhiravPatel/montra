import type { NamespaceTranslation } from '../../types';
import type en from '../en/onboarding';

/** Hindi `onboarding` messages; missing keys fall back to English. */
const messages = {
  // Onboarding
  'onboarding.title': 'Montra सेट अप करें',
  'onboarding.description':
    'कुछ वैकल्पिक कदम। आप इनमें से कोई भी छोड़ सकते हैं और बाद में सब बदल सकते हैं।',
  'onboarding.loading': 'आपकी पसंद लोड हो रही है…',
  'onboarding.loadFailed': 'हम आपकी पसंद लोड नहीं कर सके',
  'onboarding.progressLabel': 'सेटअप की प्रगति',
  'onboarding.stepOf': '{total} में से कदम {current}',
  'onboarding.stepDone': 'पूरा',
  'onboarding.skipStep': 'यह कदम छोड़ें',
  'onboarding.skipAll': 'सेटअप छोड़ें',
  'onboarding.skipped': 'सेटअप छोड़ दिया गया। आप कभी भी अपनी पसंद बदल सकते हैं।',
  'onboarding.finish': 'पूरा करें',
  'onboarding.progressNotSaved': 'हम आपकी प्रगति सहेज नहीं सके, पर आपकी पसंद रखी गई है।',
  'onboarding.welcome.title': 'Montra में आपका स्वागत है',
  'onboarding.welcome.body':
    'Montra आपको दिखाता है कि आपका पैसा कहाँ जाता है। आइए कुछ बुनियादी बातें तय करें ताकि आँकड़े आपके लिए सही हों।',
  'onboarding.welcome.free': 'सभी के लिए मुफ़्त',
  'onboarding.welcome.freeBody': 'हर सुविधा मुफ़्त है। कोई पेड प्लान नहीं।',
  'onboarding.welcome.private': 'शुरू से निजी',
  'onboarding.welcome.privateBody': 'आपका डेटा आपका है। हम इसे नहीं बेचते।',
  'onboarding.welcome.manual': 'नियंत्रण आपके हाथ में',
  'onboarding.welcome.manualBody': 'खुद दर्ज करें। बैंक जोड़ने की ज़रूरत नहीं।',
  'onboarding.welcome.optional': 'हर कदम वैकल्पिक है और लगभग एक मिनट लेता है।',
  'onboarding.welcome.start': 'शुरू करें',
  'onboarding.privacy.title': 'आपकी गोपनीयता',
  'onboarding.privacy.factPrivate':
    'आपकी वित्तीय जानकारी निजी है और कभी सार्वजनिक नहीं दिखाई जाती।',
  'onboarding.privacy.factNoSelling':
    'हम आपका डेटा नहीं बेचते और विज्ञापन के लिए इस्तेमाल नहीं करते।',
  'onboarding.privacy.factNoBank':
    'आपको कभी बैंक जोड़ने की ज़रूरत नहीं, और Montra कभी बैंक पासवर्ड नहीं माँगता।',
  'onboarding.privacy.factAi':
    'AI सुविधाएँ तब तक बंद रहती हैं जब तक आप उन्हें चालू करके सहमति न दें।',
  'onboarding.privacy.factControl': 'आप कभी भी अपना डेटा निर्यात कर सकते हैं या हटा सकते हैं।',
  'onboarding.privacy.analytics': 'उपयोग के गुमनाम आँकड़े साझा करें',
  'onboarding.privacy.analyticsHelp':
    'वैकल्पिक। यह केवल आपकी पसंद दर्ज करता है: Montra अभी उपयोग के कोई आँकड़े इकट्ठा नहीं करता। अगर कभी करेगा, तो उनमें राशि, दुकान या कोई वित्तीय जानकारी कभी नहीं होगी।',
  'onboarding.region.title': 'आप कहाँ हैं',
  'onboarding.region.country': 'देश',
  'onboarding.region.countryPlaceholder': 'अपना देश चुनें',
  'onboarding.region.countryHelp': 'मुद्रा और स्थानीय फ़ॉर्मैट सुझाने के लिए।',
  'onboarding.region.currencyHelp':
    'कुल इसी मुद्रा में दिखाए जाते हैं। इसे बदलने से पहले दर्ज की गई राशि नहीं बदलती।',
  'onboarding.region.timezone': 'समय क्षेत्र',
  'onboarding.region.timezoneHelp': 'तय करता है कि कोई लेन-देन किस दिन का है।',
  'onboarding.region.timezoneRequired': 'समय क्षेत्र चुनें।',
  'onboarding.region.locale': 'फ़ॉर्मैट',
  'onboarding.region.localeHelp': 'ईमेल और निर्यात के लिए।',
  'onboarding.region.localeRequired': 'फ़ॉर्मैट चुनें।',
  'onboarding.region.weekStart': 'हफ़्ता शुरू होता है',
  'onboarding.region.monthStart': 'महीना इस दिन शुरू होता है',
  'onboarding.region.monthStartHelp': 'उदाहरण के लिए, जिस दिन आपका वेतन आता है।',
  'onboarding.income.title': 'आपकी आय (वैकल्पिक)',
  'onboarding.income.why':
    'मोटा मासिक अनुमान Montra को समझदारी से सुझाव देने में मदद करता है। यह कभी किसी के साथ साझा नहीं होता, और “नहीं बताना चाहते” भी ठीक है।',
  'onboarding.income.legend': 'अनुमानित मासिक आय (भारतीय रुपये में)',
  'onboarding.income.prefer_not_to_say': 'नहीं बताना चाहते',
  'onboarding.income.under_25k': '₹25,000 से कम',
  'onboarding.income.25k_50k': '₹25,000 से ₹50,000',
  'onboarding.income.50k_1l': '₹50,000 से ₹1 लाख',
  'onboarding.income.1l_2l': '₹1 लाख से ₹2 लाख',
  'onboarding.income.2l_5l': '₹2 लाख से ₹5 लाख',
  'onboarding.income.above_5l': '₹5 लाख से ज़्यादा',
  'onboarding.goals.title': 'पहला लक्ष्य (वैकल्पिक)',
  'onboarding.goals.body':
    'किसी चीज़ के लिए बचत कर रहे हैं? उसे यहाँ जोड़ें और होम पर अपनी प्रगति देखें। बचत की योजना, पड़ाव और योगदान आप बाद में जोड़ सकते हैं।',
  'onboarding.goals.currencyHelp': '{currency} में, आपकी मुख्य मुद्रा।',
  'onboarding.goals.datePast': 'आज की या उसके बाद की तारीख चुनें।',
  'onboarding.goals.submit': 'लक्ष्य जोड़ें और आगे बढ़ें',
  'onboarding.goals.created': 'लक्ष्य “{name}” जोड़ा गया',
  'onboarding.accounts.title': 'आपका पहला खाता',
  'onboarding.accounts.body':
    'बताएँ कि आपका पैसा कहाँ है, जैसे नकद बटुआ, बैंक खाता या कार्ड। आप बाद में और जोड़ सकते हैं।',
  'onboarding.accounts.noBank':
    'Montra कभी आपके बैंक से नहीं जुड़ता। बैलेंस आपकी दर्ज की गई जानकारी से आते हैं।',
  'onboarding.accounts.added': 'अब तक जोड़े गए',
  'onboarding.accounts.addFirst': 'खाता जोड़ें',
  'onboarding.accounts.addAnother': 'एक और खाता जोड़ें',
  'onboarding.accounts.created': '{name} जोड़ा गया',
  'onboarding.categories.title': 'श्रेणियाँ',
  'onboarding.categories.body':
    'Montra ने आपके लिए ये श्रेणियाँ बनाई हैं। जो इस्तेमाल नहीं करेंगे उनका निशान हटा दें; आप बाद में अपनी श्रेणियाँ जोड़ सकते हैं।',
  'onboarding.categories.loading': 'श्रेणियाँ लोड हो रही हैं…',
  'onboarding.categories.error': 'हम आपकी श्रेणियाँ लोड नहीं कर सके',
  'onboarding.categories.none': 'देखने के लिए कोई शुरुआती श्रेणी नहीं है।',
  'onboarding.categories.later':
    'जिन श्रेणियों का निशान हटाया गया है उन्हें संग्रहित किया जाता है, हटाया नहीं जाता, ताकि आप उन्हें वापस ला सकें।',
  'onboarding.notifications.title': 'ईमेल सारांश',
  'onboarding.notifications.legend': 'मुझे मेरे पैसे का सारांश भेजें',
  'onboarding.notifications.off': 'कोई सारांश नहीं',
  'onboarding.notifications.offHelp': 'आप फिर भी जब चाहें Montra देख सकते हैं।',
  'onboarding.notifications.daily': 'रोज़',
  'onboarding.notifications.dailyHelp': 'हर सुबह एक ईमेल।',
  'onboarding.notifications.weekly': 'हर हफ़्ते',
  'onboarding.notifications.weeklyHelp': 'हर हफ़्ते एक ईमेल।',
  'onboarding.notifications.security':
    'सुरक्षा और खाते से जुड़े ईमेल, जैसे साइन-इन अलर्ट, हमेशा भेजे जाते हैं।',
  'onboarding.done.title': 'सब तैयार है',
  'onboarding.done.body': 'कोई लेन-देन दर्ज करके शुरू करें। आपका डैशबोर्ड अपने आप भरता जाएगा।',
  'onboarding.done.dashboard': 'होम पर जाएँ',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
