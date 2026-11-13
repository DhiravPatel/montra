import type { NamespaceTranslation } from '../../types';
import type en from '../en/fx';

/** Hindi `fx` messages; missing keys fall back to English. */
const messages = {
  // Exchange rates
  'fx.title': 'विनिमय दरें',
  'fx.description': 'मुद्राओं के बीच राशियाँ दिखाने और बदलने के लिए दरें।',
  'fx.explain.title': 'दरें आपके रिकॉर्ड कभी नहीं बदलतीं',
  'fx.explain.body':
    'विनिमय दरें सिर्फ़ बदले हुए कुल दिखाने और यहाँ राशियाँ बदलने के लिए इस्तेमाल होती हैं। हर लेन-देन उसी मुद्रा और राशि में रहता है जो आपने दर्ज की थी, और दर जोड़ने या हटाने से वह कभी नहीं बदलता।',
  'fx.explain.history':
    'दरें इतिहास के रूप में रखी जाती हैं: नई दर अपनी तारीख से लागू होती है, और प्रदाता की दरों से पहले आपकी अपनी दरें इस्तेमाल होती हैं।',
  'fx.rate.equation': '1 {base} = {rate} {quote}',
  'fx.rate.asOf': '{date} से',
  'fx.rate.inverted': '{base} → {quote} दर से निकाला गया।',
  'fx.source.manual': 'खुद डाली गई दर',
  'fx.source.mine': 'आपकी दर',
  'fx.source.ecb': 'यूरोपियन सेंट्रल बैंक',
  'fx.source.provider': 'दर प्रदाता',
  'fx.currencies.loading': 'मुद्राएँ लोड हो रही हैं…',
  'fx.currencies.error': 'हम मुद्राओं की सूची लोड नहीं कर सके',
  'fx.form.chooseCurrency': 'मुद्रा चुनें',
  'fx.form.currencyRequired': 'मुद्रा चुनें।',
  'fx.form.sameCurrency': 'पहली मुद्रा से अलग मुद्रा चुनें।',
  'fx.form.pairInvalid': 'दो अलग-अलग समर्थित मुद्राएँ चुनें।',
  'fx.form.rateRequired': 'दर दर्ज करें।',
  'fx.form.rateZero': 'शून्य से बड़ी दर दर्ज करें।',
  'fx.form.rateDecimalMark':
    'दशमलव के लिए कॉमा इस्तेमाल करें और कोई दूसरा चिह्न नहीं, जैसे {example}।',
  'fx.form.dateFuture': 'आज की या उससे पहले की तारीख चुनें।',
  'fx.convert.title': 'राशि बदलें',
  'fx.convert.description':
    'किसी राशि को दूसरी मुद्रा में देखें, इस्तेमाल हुई दर के साथ। कुछ भी सहेजा नहीं जाता।',
  'fx.convert.from': 'से',
  'fx.convert.to': 'में',
  'fx.convert.amount': 'राशि',
  'fx.convert.policy': 'कौन सी दर इस्तेमाल करें',
  'fx.convert.policyCurrent': 'सबसे नई दर',
  'fx.convert.policyHistorical': 'किसी तारीख की दर',
  'fx.convert.date': 'तारीख',
  'fx.convert.submit': 'बदलें',
  'fx.convert.resultTitle': 'बदली हुई राशि',
  'fx.convert.usedCurrent': 'सबसे नई उपलब्ध दर इस्तेमाल हुई।',
  'fx.convert.usedHistorical': '{date} या उससे पहले की सबसे नई दर इस्तेमाल हुई।',
  'fx.convert.rounded': 'नतीजा मुद्रा की सबसे छोटी इकाई तक पूरा किया गया है।',
  'fx.convert.noRate':
    '{from} → {to} के लिए कोई विनिमय दर नहीं है। इन्हें बदलने के लिए नीचे एक दर जोड़ें।',
  'fx.convert.amountInvalid': 'राशि {currency} की सटीकता में दर्ज करें।',
  'fx.add.title': 'अपनी दर जोड़ें',
  'fx.add.description':
    'अपनी दर इस्तेमाल करें, जैसे वह दर जो आपके बैंक या कार्ड ने दी। यह प्रदाता की दरों से पहले इस्तेमाल होती है।',
  'fx.add.base': 'किस मुद्रा से',
  'fx.add.quote': 'किस मुद्रा में',
  'fx.add.rate': 'दर',
  'fx.add.rateHelp':
    'पहली मुद्रा की एक इकाई दूसरी मुद्रा में कितनी है, दशमलव के बाद {count} अंकों तक।',
  'fx.add.date': 'कब से लागू',
  'fx.add.dateHelp': 'उसी जोड़ी और तारीख की दर उस दिन की दर की जगह ले लेती है।',
  'fx.add.submit': 'दर सहेजें',
  'fx.add.done': 'दर सहेजी गई',
  'fx.list.title': 'दरें',
  'fx.list.description': 'हर मुद्रा जोड़ी की सबसे नई दर। पुरानी दरें इतिहास के लिए रखी जाती हैं।',
  'fx.list.filters': 'दरें छाँटें',
  'fx.list.base': 'किस मुद्रा से',
  'fx.list.quote': 'किस मुद्रा में',
  'fx.list.anyCurrency': 'कोई भी मुद्रा',
  'fx.list.loading': 'विनिमय दरें लोड हो रही हैं…',
  'fx.list.error': 'हम विनिमय दरें लोड नहीं कर सके',
  'fx.list.empty': 'अभी कोई विनिमय दर नहीं',
  'fx.list.noMatches': 'इन मुद्राओं के लिए कोई दर नहीं',
  'fx.list.emptyBody':
    'दो मुद्राओं के बीच बदलने के लिए अपनी दर जोड़ें। प्रदाता सेट होने पर उसकी दरें यहाँ दिखती हैं।',
  'fx.list.mine': 'आपकी दरें',
  'fx.list.provider': 'प्रदाता की दरें',
  'fx.stale.list': 'विनिमय दरें रीफ़्रेश नहीं हो सकीं, इसलिए यह सूची पुरानी हो सकती है।',
  'fx.delete.action': 'दर {pair} हटाएँ',
  'fx.delete.title': 'यह दर हटाएँ?',
  'fx.delete.body':
    'बदलने के लिए इस जोड़ी की आपकी पिछली दर, या कोई प्रदाता दर हो तो वह, इस्तेमाल होगी। आपके लेन-देन नहीं बदलते।',
  'fx.delete.confirm': 'दर हटाएँ',
  'fx.delete.done': 'दर हटा दी गई',
  'fx.delete.gone': 'यह दर पहले ही हटा दी गई थी',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
