import type { NamespaceTranslation } from '../../types';
import type en from '../en/profileSettings';

/** Hindi `profileSettings` messages; missing keys fall back to English. */
const messages = {
  'profileSettings.title': 'प्रोफ़ाइल और प्राथमिकताएँ',
  'profileSettings.description':
    'दोस्तों और समूहों को आप कैसे दिखते हैं, Montra तारीखें और पैसे कैसे दिखाता है, और ऐप कैसा दिखता है। बदलाव आपके सभी डिवाइस पर लागू होते हैं।',
  'profileSettings.nothingChanged': 'सहेजने को कुछ नहीं: आपने कुछ नहीं बदला',
  'profileSettings.avatar.title': 'प्रोफ़ाइल फ़ोटो',
  'profileSettings.avatar.description':
    'उन लोगों को आपके नाम के साथ दिखती है जो आपकी प्रोफ़ाइल देख सकते हैं (नीचे “आपकी प्रोफ़ाइल कौन देख सकता है” देखें)।',
  'profileSettings.avatar.help': '5 MB तक की JPG, PNG या WebP तस्वीर।',
  'profileSettings.avatar.upload': 'फ़ोटो अपलोड करें',
  'profileSettings.avatar.change': 'फ़ोटो बदलें',
  'profileSettings.avatar.choose': 'प्रोफ़ाइल फ़ोटो चुनें',
  'profileSettings.avatar.remove': 'फ़ोटो हटाएँ',
  'profileSettings.avatar.uploading': 'आपकी फ़ोटो अपलोड हो रही है…',
  'profileSettings.avatar.saving': 'आपकी फ़ोटो सहेजी जा रही है…',
  'profileSettings.avatar.saved': 'प्रोफ़ाइल फ़ोटो अपडेट हो गई',
  'profileSettings.avatar.removed': 'प्रोफ़ाइल फ़ोटो हटा दी गई',
  'profileSettings.avatar.loading': 'आपकी फ़ोटो लोड हो रही है…',
  'profileSettings.avatar.alt': 'आपकी प्रोफ़ाइल फ़ोटो',
  'profileSettings.avatar.unavailable': 'फ़ोटो उपलब्ध नहीं',
  'profileSettings.avatar.previewFailed': 'आपकी फ़ोटो अभी दिखाई नहीं जा सकी। वह सहेजी हुई है।',
  'profileSettings.avatar.type': 'JPG, PNG या WebP तस्वीर चुनें।',
  'profileSettings.avatar.invalid':
    'यह तस्वीर आपकी फ़ोटो के रूप में इस्तेमाल नहीं हो सकती। इसे फिर से अपलोड करें और अपलोड पूरा होने दें।',
  'profileSettings.avatar.removeTitle': 'अपनी प्रोफ़ाइल फ़ोटो हटाएँ?',
  'profileSettings.avatar.removeBody':
    'उसकी जगह आपके नाम के पहले अक्षर दिखेंगे। तस्वीर आपकी फ़ाइलों में तब तक रहेगी जब तक आप उसे न हटाएँ।',
  'profileSettings.avatar.removeConfirm': 'फ़ोटो हटाएँ',
  'profileSettings.profile.title': 'आपकी प्रोफ़ाइल',
  'profileSettings.profile.description':
    'दोस्त और समूह आपका नाम और यूज़रनेम देखते हैं। बाकी सब वैकल्पिक है।',
  'profileSettings.profile.loading': 'आपकी प्रोफ़ाइल लोड हो रही है…',
  'profileSettings.profile.error': 'हम आपकी प्रोफ़ाइल लोड नहीं कर सके',
  'profileSettings.profile.displayName': 'दिखने वाला नाम',
  'profileSettings.profile.displayNameHelp': '80 अक्षरों तक।',
  'profileSettings.profile.displayNameRequired': 'दिखने वाला नाम लिखें।',
  'profileSettings.profile.displayNameTooLong': '80 या उससे कम अक्षर इस्तेमाल करें।',
  'profileSettings.profile.usernameHelp':
    '3 से 30 अक्षर: छोटे अंग्रेज़ी अक्षर, अंक, बिंदु और अंडरस्कोर। हटाने के लिए खाली छोड़ दें।',
  'profileSettings.profile.bio': 'परिचय',
  'profileSettings.profile.bioHelp': 'आपके बारे में एक-दो पंक्तियाँ, 280 अक्षरों तक।',
  'profileSettings.profile.bioTooLong': '280 या उससे कम अक्षर इस्तेमाल करें।',
  'profileSettings.profile.interests': 'रुचियाँ',
  'profileSettings.profile.interestsHelp': {
    one: 'इन्हें कॉमा से अलग करें। {count} रुचि तक।',
    other: 'इन्हें कॉमा से अलग करें। {count} रुचियों तक।',
  },
  'profileSettings.profile.interestsInvalid': {
    one: '{count} रुचि तक लिखें, हर एक {length} अक्षरों तक।',
    other: '{count} रुचियों तक लिखें, हर एक {length} अक्षरों तक।',
  },
  'profileSettings.profile.location': 'जगह',
  'profileSettings.profile.locationHelp': 'सिर्फ़ शहर या क्षेत्र, कभी अपना पता नहीं।',
  'profileSettings.profile.locationTooLong': '80 या उससे कम अक्षर इस्तेमाल करें।',
  'profileSettings.profile.save': 'प्रोफ़ाइल सहेजें',
  'profileSettings.profile.saved': 'प्रोफ़ाइल सहेज ली गई',
  'profileSettings.visibility.legend': 'आपकी प्रोफ़ाइल कौन देख सकता है',
  'profileSettings.visibility.help':
    'आपकी प्रोफ़ाइल में आपकी फ़ोटो, परिचय, रुचियाँ और जगह होती हैं। आपके बैलेंस और लेन-देन कभी इसका हिस्सा नहीं होते। जिन्हें आप ब्लॉक करते हैं या जो आपको ब्लॉक करते हैं, वे इसे कभी नहीं देखते।',
  'profileSettings.visibility.private': 'निजी',
  'profileSettings.visibility.privateHelp':
    'सिर्फ़ आप, आपके साथ किसी सक्रिय समूह में शामिल लोग, और वे लोग जिनके साथ आपका दोस्ती का अनुरोध लंबित है।',
  'profileSettings.visibility.connections': 'दोस्त',
  'profileSettings.visibility.connectionsHelp':
    'आपके दोस्त, और वे सभी जिन्हें निजी प्रोफ़ाइल दिखती है: आपके साथ किसी सक्रिय समूह में शामिल लोग और वे लोग जिनके साथ आपका दोस्ती का अनुरोध लंबित है।',
  'profileSettings.visibility.public': 'Montra पर कोई भी',
  'profileSettings.visibility.publicHelp': 'Montra में साइन इन किया हुआ कोई भी व्यक्ति।',
  'profileSettings.discoverableHelp':
    'जो लोग आपका पूरा यूज़रनेम लिखते हैं, वे आपको ढूँढ सकते हैं और दोस्ती का अनुरोध भेज सकते हैं।',
  'profileSettings.region.title': 'क्षेत्र, पैसे और डिस्प्ले',
  'profileSettings.region.description':
    'आपकी मुद्राएँ, समय क्षेत्र, फ़ॉर्मैट और डिफ़ॉल्ट। सिर्फ़ जो आप बदलते हैं वही सहेजा जाता है।',
  'profileSettings.region.loading': 'आपकी प्राथमिकताएँ लोड हो रही हैं…',
  'profileSettings.region.error': 'हम आपकी प्राथमिकताएँ लोड नहीं कर सके',
  'profileSettings.region.currenciesFailed':
    'मुद्राओं की सूची लोड नहीं हो सकी, इसलिए सिर्फ़ आपकी मौजूदा मुद्राएँ दिख रही हैं।',
  'profileSettings.region.accountsFailed':
    'आपके खाते अभी लोड नहीं हो सके; आप फिर भी डिफ़ॉल्ट हटा सकते हैं।',
  'profileSettings.region.money': 'पैसे',
  'profileSettings.region.baseCurrencyHelp':
    'जब आप मुद्रा नहीं चुनते, तो नए बजट, लक्ष्य, सब्सक्रिप्शन और नियमित चीज़ों के लिए, और रकम वाले फ़िल्टर के लिए इस्तेमाल होती है। हर खाता अपनी मुद्रा रखता है।',
  'profileSettings.region.baseChangeTitle': 'मुख्य मुद्रा बदलने से क्या होता है',
  'profileSettings.region.baseChangeBody':
    'नए रिकॉर्ड {from} की जगह {to} में शुरू होंगे। पहले से दर्ज रकम, आपके खाते और उनके बैलेंस अपनी मुद्रा में रहते हैं और बदले नहीं जाते, और अलग-अलग मुद्राओं के कुल अब भी अलग दिखते हैं।',
  'profileSettings.region.displayCurrency': 'डिस्प्ले मुद्रा',
  'profileSettings.region.displayCurrencyNone': 'कोई नहीं',
  'profileSettings.region.displayCurrencyHelp':
    'वैकल्पिक। विश्लेषण और रिपोर्ट इस मुद्रा में बदले हुए कुल, इस्तेमाल हुई दरों के साथ, जोड़ सकते हैं। आपके रिकॉर्ड कभी नहीं बदले जाते।',
  'profileSettings.region.place': 'जगह और समय',
  'profileSettings.region.countryNone': 'तय नहीं',
  'profileSettings.region.formats': 'फ़ॉर्मैट',
  'profileSettings.region.formatsHelp':
    'ईमेल, एक्सपोर्ट और रिपोर्ट में इस्तेमाल होते हैं। ऐप खुद आपकी इंटरफ़ेस भाषा के हिसाब से चलता है।',
  'profileSettings.region.dateFormat': 'तारीख का फ़ॉर्मैट',
  'profileSettings.region.dateFormat.locale': 'भाषा और क्षेत्र के अनुसार',
  'profileSettings.region.dateFormat.dmy': 'दिन, महीना, साल (31/12/2026)',
  'profileSettings.region.dateFormat.mdy': 'महीना, दिन, साल (12/31/2026)',
  'profileSettings.region.dateFormat.ymd': 'साल, महीना, दिन (2026-12-31)',
  'profileSettings.region.numberFormat': 'संख्या का फ़ॉर्मैट',
  'profileSettings.region.numberFormat.locale': 'भाषा और क्षेत्र के अनुसार',
  'profileSettings.region.numberFormat.indian': 'भारतीय (1,00,000.00)',
  'profileSettings.region.numberFormat.international': 'अंतरराष्ट्रीय (100,000.00)',
  'profileSettings.region.periods': 'हफ़्ते और महीने',
  'profileSettings.region.monthStartHelp': 'मासिक बजट और रिपोर्ट इसी दिन से शुरू होते हैं।',
  'profileSettings.region.defaultRange': 'डिफ़ॉल्ट अवधि',
  'profileSettings.region.defaultRangeHelp': 'होम खोलने पर क्या दिखे।',
  'profileSettings.region.defaults': 'डिफ़ॉल्ट और थीम',
  'profileSettings.region.defaultAccount': 'डिफ़ॉल्ट खाता',
  'profileSettings.region.defaultAccountNone': 'कोई डिफ़ॉल्ट खाता नहीं',
  'profileSettings.region.defaultAccountUnavailable': 'एक खाता जो अब सक्रिय नहीं है',
  'profileSettings.region.defaultAccountHelp': 'लेन-देन जोड़ते समय सबसे पहले चुना जाता है।',
  'profileSettings.region.themeHelp': 'आपके सभी डिवाइस पर लागू होती है।',
  'profileSettings.region.save': 'प्राथमिकताएँ सहेजें',
  'profileSettings.region.saved': 'प्राथमिकताएँ सहेज ली गईं',
  'profileSettings.accessibility.title': 'सुलभता',
  'profileSettings.accessibility.description':
    'सहेजते ही ये पूरे Montra में, आपके सभी डिवाइस पर लागू होती हैं।',
  'profileSettings.accessibility.reducedMotion': 'हलचल कम करें',
  'profileSettings.accessibility.reducedMotionHelp':
    'एनिमेशन और ट्रांज़िशन बंद करता है। Montra आपके डिवाइस की सेटिंग भी मानता है।',
  'profileSettings.accessibility.highContrast': 'हाई कंट्रास्ट',
  'profileSettings.accessibility.highContrastHelp':
    'हल्की और गहरी दोनों थीम में ज़्यादा गहरा टेक्स्ट, मज़बूत किनारे और साफ़ स्थिति रंग।',
  'profileSettings.accessibility.textScale': 'टेक्स्ट का आकार',
  'profileSettings.accessibility.textScaleHelp':
    'सारे टेक्स्ट और खाली जगह को बड़ा या छोटा करता है।',
  'profileSettings.accessibility.textScaleDefault': '{size} (डिफ़ॉल्ट)',
  'profileSettings.accessibility.save': 'सुलभता सेटिंग सहेजें',
  'profileSettings.accessibility.saved': 'सुलभता सेटिंग सहेज ली गईं',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
