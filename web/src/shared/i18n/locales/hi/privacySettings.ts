import type { NamespaceTranslation } from '../../types';
import type en from '../en/privacySettings';

/** Hindi `privacySettings` messages; missing keys fall back to English. */
const messages = {
  // Privacy & data settings and fair-use limits (round 5; privacy.* belongs to the public notice)
  'privacySettings.title': 'गोपनीयता और डेटा',
  'privacySettings.description':
    'चुनें कि Montra कौन-सी वैकल्पिक प्रोसेसिंग कर सकता है, अपने डेटा की कॉपी पाएँ, या अपना खाता बंद करें।',
  'privacySettings.readNotice': 'गोपनीयता सूचना पढ़ें',
  'privacySettings.limitsLink': 'उचित-उपयोग सीमाएँ',
  'privacySettings.consents.title': 'आपकी पसंद',
  'privacySettings.consents.description':
    'वैकल्पिक प्रोसेसिंग तब तक बंद रहती है जब तक आप अनुमति न दें, और आप कभी भी सहमति वापस ले सकते हैं।',
  'privacySettings.consents.loading': 'आपकी पसंद लोड हो रही है…',
  'privacySettings.consents.error': 'हम आपकी पसंद लोड नहीं कर सके',
  'privacySettings.consents.on': 'चालू',
  'privacySettings.consents.off': 'बंद',
  'privacySettings.consents.give': 'अनुमति दें',
  'privacySettings.consents.withdraw': 'वापस लें',
  'privacySettings.consents.givenOn': '{date} को अनुमति दी · शब्दों का संस्करण {version}',
  'privacySettings.consents.otherApp':
    'आपने इसकी अनुमति Montra के किसी दूसरे ऐप में दी थी। वेब पोर्टल में AI सुविधाएँ नहीं हैं, लेकिन आप इसे यहाँ वापस ले सकते हैं।',
  'privacySettings.consents.given': '{name}: अनुमति दी गई',
  'privacySettings.consents.withdrawn': '{name}: सहमति वापस ली गई',
  'privacySettings.consents.alreadyOff': '{name} पहले से बंद था',
  'privacySettings.consents.failed': '{name} नहीं बदला',
  'privacySettings.consents.versionChanged':
    'Montra ने अभी इस सहमति के शब्द बदले हैं। नए संस्करण पर सहमति देने के लिए फिर से कोशिश करें।',
  'privacySettings.consents.requiredTitle': 'Montra इस्तेमाल करने के लिए ज़रूरी',
  'privacySettings.consents.accepted': '{date} को स्वीकार किया · संस्करण {version}',
  'privacySettings.consents.notRecorded': 'दर्ज नहीं',
  'privacySettings.consents.requiredBody':
    'साइन अप करते समय आपने इन्हें स्वीकार किया था। इन्हें वापस लेने के लिए नीचे अपना खाता हटाएँ।',
  'privacySettings.consents.showHistory': 'सहमति का इतिहास दिखाएँ',
  'privacySettings.consents.hideHistory': 'सहमति का इतिहास छिपाएँ',
  'privacySettings.consents.historyTitle': 'सहमति का इतिहास',
  'privacySettings.consents.historyLoading': 'सहमति का इतिहास लोड हो रहा है…',
  'privacySettings.consents.historyError': 'हम आपकी सहमति का इतिहास लोड नहीं कर सके',
  'privacySettings.consents.historyConsent': 'सहमति',
  'privacySettings.consents.historyGiven': 'दी गई',
  'privacySettings.consents.historyWithdrawn': 'वापस ली गई',
  'privacySettings.consents.historyVersion': 'संस्करण',
  'privacySettings.consents.stillOn': 'अभी भी चालू',
  'privacySettings.consent.location.title': 'लेन-देन पर जगह',
  'privacySettings.consent.location.body':
    'इससे आप लेन-देन के साथ किसी जगह का नाम सहेज सकते हैं, जैसे वह दुकान जहाँ आपने भुगतान किया।',
  'privacySettings.consent.location.off': 'बंद होने पर आप लेन-देन में जगह नहीं जोड़ सकते।',
  'privacySettings.consent.push_notifications.title': 'पुश सूचनाएँ',
  'privacySettings.consent.push_notifications.body':
    'इससे Montra उन ब्राउज़र और फ़ोन पर अलर्ट भेज सकता है जहाँ आपने पुश सूचनाएँ भी चालू की हैं।',
  'privacySettings.consent.push_notifications.off':
    'इससे आपकी पसंद दर्ज होती है। किसी डिवाइस पर अलर्ट तब रुकते हैं जब आप सूचना सेटिंग्स में उसके लिए पुश बंद करते हैं।',
  'privacySettings.consent.push_notifications.link': 'सूचना सेटिंग्स',
  'privacySettings.consent.marketing_email.title': 'ईमेल से उत्पाद समाचार',
  'privacySettings.consent.marketing_email.body':
    'Montra की नई सुविधाओं के बारे में कभी-कभार ईमेल।',
  'privacySettings.consent.marketing_email.off':
    'Montra अभी उत्पाद समाचार नहीं भेजता; अगर यह बदले, तो इसके लिए आपकी पसंद दर्ज रहती है। खाते और सुरक्षा से जुड़े ईमेल हमेशा भेजे जाते हैं।',
  'privacySettings.consent.product_analytics.title': 'उत्पाद विश्लेषण',
  'privacySettings.consent.product_analytics.body':
    'Montra की सुविधाओं के इस्तेमाल के बारे में कुल आँकड़ों की अनुमति देता है।',
  'privacySettings.consent.product_analytics.off':
    'Montra अभी कोई उत्पाद विश्लेषण नहीं जुटाता; अगर यह बदले, तो इसके लिए आपकी पसंद दर्ज रहती है।',
  'privacySettings.consent.contacts_discovery.title': 'आपके संपर्क आपको ढूँढ सकें',
  'privacySettings.consent.contacts_discovery.body':
    'जिन लोगों के पास पहले से आपकी संपर्क जानकारी है, वे आपको Montra पर ढूँढ सकें।',
  'privacySettings.consent.contacts_discovery.off':
    'Montra में अभी संपर्क मिलाने की सुविधा नहीं है; अगर यह बदले, तो इसके लिए आपकी पसंद दर्ज रहती है। यूज़रनेम से ढूँढा जाना एक अलग सेटिंग है।',
  'privacySettings.consent.contacts_discovery.link': 'यूज़रनेम से आपको कौन ढूँढ सकता है',
  'privacySettings.consent.ai_processing.title': 'AI सुविधाएँ',
  'privacySettings.consent.ai_processing.body':
    'इससे Montra की वैकल्पिक AI सुविधाएँ आपको जवाब देने के लिए आपके डेटा का इस्तेमाल कर सकती हैं।',
  'privacySettings.consent.ai_processing.off':
    'वापस लेने पर हर Montra ऐप में AI सुविधाएँ बंद हो जाती हैं।',
  'privacySettings.consent.ai_receipt_processing.title': 'AI से रसीदें पढ़ना',
  'privacySettings.consent.ai_receipt_processing.body':
    'इससे Montra का वैकल्पिक AI जानकारी भरने के लिए रसीदों की तस्वीरें पढ़ सकता है।',
  'privacySettings.consent.ai_receipt_processing.off':
    'वापस लेने पर रसीदों की जानकारी आप खुद भरेंगे।',
  'privacySettings.consent.terms.title': 'उपयोग की शर्तें',
  'privacySettings.consent.privacy_policy.title': 'गोपनीयता सूचना',
  'privacySettings.consent.integration.title': 'जुड़ी हुई सेवा',
  'privacySettings.consent.other.title': 'अन्य सहमति',
  'privacySettings.export.title': 'अपना डेटा डाउनलोड करें',
  'privacySettings.export.description':
    'Montra आपके बारे में जो कुछ भी रखता है, उसकी एक कॉपी पाएँ।',
  'privacySettings.export.contents':
    'आपकी प्रोफ़ाइल, सेटिंग्स, रिकॉर्ड, समूह, सूचनाएँ और बहुत कुछ, एक ZIP फ़ाइल में JSON फ़ाइलों के रूप में।',
  'privacySettings.export.secrets': 'पासवर्ड, सुरक्षा कोड और साइन-इन टोकन कभी शामिल नहीं होते।',
  'privacySettings.export.window': {
    one: 'तैयार होने के बाद डाउनलोड {count} दिन तक उपलब्ध रहता है।',
    other: 'तैयार होने के बाद डाउनलोड {count} दिन तक उपलब्ध रहता है।',
  },
  'privacySettings.export.windowUnknown': 'तैयार होने के बाद डाउनलोड कुछ समय तक ही उपलब्ध रहता है।',
  'privacySettings.export.reauth': 'आपकी सुरक्षा के लिए, Montra पहले आपका पासवर्ड माँग सकता है।',
  'privacySettings.export.request': 'मेरा डेटा माँगें',
  'privacySettings.export.requested': 'एक्सपोर्ट का अनुरोध भेज दिया गया',
  'privacySettings.export.checking': 'आपका एक्सपोर्ट जाँचा जा रहा है…',
  'privacySettings.export.notFound': 'हमें वह एक्सपोर्ट नहीं मिला। नीचे से नया माँगें।',
  'privacySettings.export.checkFailed': 'हम आपका एक्सपोर्ट नहीं जाँच सके',
  'privacySettings.export.queued': 'आपका एक्सपोर्ट शुरू होने का इंतज़ार कर रहा है',
  'privacySettings.export.running': 'आपका एक्सपोर्ट तैयार हो रहा है',
  'privacySettings.export.wait':
    'इसमें आमतौर पर कुछ मिनट लगते हैं। आप यह पेज छोड़ सकते हैं: तैयार होने पर Montra आपको सूचना देगा।',
  'privacySettings.export.stalled':
    'इसमें सामान्य से ज़्यादा समय लग रहा है। थोड़ी देर बाद फिर से जाँचें।',
  'privacySettings.export.checkAgain': 'फिर से जाँचें',
  'privacySettings.export.ready': 'आपका एक्सपोर्ट तैयार है',
  'privacySettings.export.availableUntil': 'आप इसे {date} तक डाउनलोड कर सकते हैं।',
  'privacySettings.export.download': 'ZIP डाउनलोड करें',
  'privacySettings.export.requestNew': 'नया एक्सपोर्ट माँगें',
  'privacySettings.export.downloadStarted': 'डाउनलोड शुरू हो गया',
  'privacySettings.export.downloadFailed': 'डाउनलोड शुरू नहीं हुआ',
  'privacySettings.export.downloadGone': 'यह डाउनलोड अब उपलब्ध नहीं है। नया एक्सपोर्ट माँगें।',
  'privacySettings.export.failed': 'हम आपका एक्सपोर्ट तैयार नहीं कर सके',
  'privacySettings.export.failedBody':
    'कुछ भी खोया नहीं है। फिर से कोशिश करें, और अगर ऐसा बार-बार हो तो सहायता से संपर्क करें।',
  'privacySettings.export.tryAgain': 'फिर से कोशिश करें',
  'privacySettings.export.expired': 'इस एक्सपोर्ट की अवधि खत्म हो गई है',
  'privacySettings.export.expiredBody':
    'आपके डेटा की सुरक्षा के लिए डाउनलोड कुछ समय बाद हटा दिए जाते हैं। ज़रूरत हो तो नया एक्सपोर्ट माँगें।',
  'privacySettings.deactivate.title': 'थोड़ा विराम लें',
  'privacySettings.deactivate.description':
    'अगर आप कुछ समय के लिए Montra इस्तेमाल नहीं करना चाहते, तो अपना खाता निष्क्रिय करें।',
  'privacySettings.deactivate.signOut':
    'आप हर डिवाइस से साइन आउट हो जाएँगे, इसमें यह डिवाइस भी शामिल है।',
  'privacySettings.deactivate.kept': 'कुछ भी हटाया नहीं जाता: आपके रिकॉर्ड वैसे ही रहते हैं।',
  'privacySettings.deactivate.return': 'अपना खाता फिर से चालू करने के लिए कभी भी साइन इन करें।',
  'privacySettings.deactivate.action': 'खाता निष्क्रिय करें',
  'privacySettings.deactivate.confirm.title': 'अपना खाता निष्क्रिय करें?',
  'privacySettings.deactivate.confirm.body':
    'आप हर डिवाइस से साइन आउट हो जाएँगे। कुछ भी हटाया नहीं जाएगा, और फिर से साइन इन करने पर आपका खाता चालू हो जाएगा।',
  'privacySettings.deactivate.confirm.action': 'निष्क्रिय करें',
  'privacySettings.deactivate.done': 'आपका खाता निष्क्रिय हो गया है',
  'privacySettings.deactivate.doneBody': 'इसे फिर से चालू करने के लिए कभी भी साइन इन करें।',
  'privacySettings.deletion.title': 'अपना खाता हटाएँ',
  'privacySettings.deletion.description':
    'छूट की अवधि के बाद आपका खाता और निजी डेटा हमेशा के लिए हटा दिया जाता है। तब तक आप इसे रद्द कर सकते हैं।',
  'privacySettings.deletion.loading': 'खाता हटाने की स्थिति जाँची जा रही है…',
  'privacySettings.deletion.error': 'हम आपके खाता हटाने की स्थिति नहीं जाँच सके',
  'privacySettings.deletion.grace': {
    one: 'पुष्टि करने के {count} दिन बाद आपका खाता हटाया जाता है। उससे पहले आप कभी भी रद्द कर सकते हैं, और सब कुछ वैसा ही रहेगा।',
    other:
      'पुष्टि करने के {count} दिन बाद आपका खाता हटाया जाता है। उससे पहले आप कभी भी रद्द कर सकते हैं, और सब कुछ वैसा ही रहेगा।',
  },
  'privacySettings.deletion.graceUnknown':
    'छूट की अवधि के बाद आपका खाता हटाया जाता है। उससे पहले आप कभी भी रद्द कर सकते हैं, और सब कुछ वैसा ही रहेगा।',
  'privacySettings.deletion.consequences': 'क्या होगा',
  'privacySettings.deletion.groupImpact': 'आपके समूह',
  'privacySettings.deletion.retained': 'क्या रखा जाता है, और क्यों',
  'privacySettings.deletion.englishOnly':
    'इनमें से कुछ जानकारी Montra के सर्वर से आती है और अंग्रेज़ी में दिखाई जाती है।',
  'privacySettings.deletion.start': 'मेरा खाता हटाएँ…',
  'privacySettings.deletion.dialogTitle': 'अपना खाता हटाएँ?',
  'privacySettings.deletion.dialogBody':
    'इससे आपका खाता हटाना तय हो जाएगा। यह पक्का करने के लिए कि यह आप ही हैं, Montra आपका पासवर्ड माँग सकता है।',
  'privacySettings.deletion.dialogGrace': {
    one: 'अगर आप रद्द नहीं करते, तो यह आज से {count} दिन बाद हटा दिया जाएगा।',
    other: 'अगर आप रद्द नहीं करते, तो यह आज से {count} दिन बाद हटा दिया जाएगा।',
  },
  'privacySettings.deletion.dialogGraceUnknown':
    'अगर आप रद्द नहीं करते, तो छूट की अवधि खत्म होने पर यह हटा दिया जाएगा।',
  'privacySettings.deletion.confirmLabel': 'पुष्टि के लिए {word} लिखें',
  'privacySettings.deletion.confirmHelp': 'इससे गलती से खाता हटने से बचाव होता है।',
  'privacySettings.deletion.confirmMismatch': '{word} ठीक वैसे ही लिखें जैसा दिखाया गया है।',
  'privacySettings.deletion.reason': 'आप क्यों जा रहे हैं?',
  'privacySettings.deletion.reasonHelp': 'खाता हटने पर यह भी हटा दिया जाता है।',
  'privacySettings.deletion.keepAccount': 'मेरा खाता रखें',
  'privacySettings.deletion.schedule': 'हटाना तय करें',
  'privacySettings.deletion.alreadyScheduled':
    'खाता हटाना पहले से तय है। पेज पर अब वही दिख रहा है।',
  'privacySettings.deletion.scheduledToast': 'खाता हटाना तय हो गया',
  'privacySettings.deletion.scheduledFor':
    'आपका खाता {date} को हटा दिया जाएगा। तब तक आप इसे रद्द कर सकते हैं।',
  'privacySettings.deletion.scheduledTitle': 'आपका खाता हटाना तय है',
  'privacySettings.deletion.scheduledBody':
    'यह {date} को हटा दिया जाएगा। तब तक आप रद्द कर सकते हैं, और सब कुछ वैसा ही रहेगा।',
  'privacySettings.deletion.scheduledBodyNoDate':
    'छूट की अवधि खत्म होने पर यह हटा दिया जाएगा। तब तक आप रद्द कर सकते हैं, और सब कुछ वैसा ही रहेगा।',
  'privacySettings.deletion.exportFirst':
    'अगर आपको अपने डेटा की कॉपी चाहिए, तो उससे पहले एक्सपोर्ट डाउनलोड कर लें।',
  'privacySettings.deletion.cancel': 'हटाना रद्द करें',
  'privacySettings.deletion.cancelled': 'हटाना रद्द हो गया',
  'privacySettings.deletion.cancelledBody': 'आपका खाता वैसा ही रहेगा।',
  'privacySettings.deletion.nothingToCancel': 'रद्द करने के लिए कोई तय हटाना नहीं है।',
  'privacySettings.deletion.processingTitle': 'आपका खाता हटाया जा रहा है',
  'privacySettings.deletion.processingBody':
    'छूट की अवधि खत्म हो गई है और खाता हटाना शुरू हो गया है। अब इसे रोका नहीं जा सकता।',
  'privacySettings.deletion.failedTitle': 'पिछली बार खाता हटाना पूरा नहीं हुआ',
  'privacySettings.deletion.failedBody':
    'आपका खाता हटाते समय कुछ गड़बड़ हो गई। सहायता से संपर्क करें ताकि टीम मदद कर सके।',
  'privacySettings.deletion.contactSupport': 'सहायता से संपर्क करें',
  'privacySettings.limits.title': 'उचित-उपयोग सीमाएँ',
  'privacySettings.limits.description':
    'वे सीमाएँ जो Montra को सबके लिए तेज़ रखती हैं, और आप अपनी स्टोरेज का कितना हिस्सा इस्तेमाल करते हैं।',
  'privacySettings.limits.free.title': 'सब कुछ मुफ़्त है, सबके लिए',
  'privacySettings.limits.free.body':
    'कोई पेड प्लान या अपग्रेड नहीं है। ये सीमाएँ हर खाते के लिए एक जैसी हैं; ये Montra को तेज़ और चलाने में किफ़ायती रखती हैं।',
  'privacySettings.limits.loading': 'सीमाएँ लोड हो रही हैं…',
  'privacySettings.limits.error': 'हम सीमाएँ लोड नहीं कर सके',
  'privacySettings.limits.storage.title': 'आपकी स्टोरेज',
  'privacySettings.limits.storage.description':
    'आपकी अपलोड की गई रसीदें, स्टेटमेंट और अटैचमेंट इसमें गिने जाते हैं।',
  'privacySettings.limits.storage.used': '{quota} में से {used} इस्तेमाल हुआ ({percent})',
  'privacySettings.limits.storage.noCap':
    'आप {used} इस्तेमाल करते हैं। अभी स्टोरेज की कोई सीमा नहीं है।',
  'privacySettings.limits.storage.meter': 'इस्तेमाल हुई स्टोरेज',
  'privacySettings.limits.storage.full': 'भर गई',
  'privacySettings.limits.storage.nearlyFull': 'लगभग भर गई',
  'privacySettings.limits.storage.freeUp':
    'जगह बनाने के लिए वे फ़ाइलें हटाएँ जिनकी अब ज़रूरत नहीं है, जैसे पुरानी रसीदें या स्टेटमेंट फ़ाइलें।',
  'privacySettings.limits.records.title': 'फ़ाइलों और रिकॉर्ड की सीमाएँ',
  'privacySettings.limits.records.description': 'ज़्यादातर लोग इनके आस-पास भी नहीं पहुँचते।',
  'privacySettings.limits.maxUpload': 'सबसे बड़ी फ़ाइल',
  'privacySettings.limits.maxUploadHelp':
    'एक बार में अपलोड हो सकने वाली सबसे बड़ी फ़ाइल। कुछ तरह की फ़ाइलों की सीमा इससे छोटी है।',
  'privacySettings.limits.importRows': 'स्टेटमेंट आयात',
  'privacySettings.limits.rows': { one: '{count} पंक्ति', other: '{count} पंक्तियाँ' },
  'privacySettings.limits.importRowsHelp':
    'एक आयात में ज़्यादा से ज़्यादा इतनी पंक्तियाँ पढ़ी जा सकती हैं। बड़े स्टेटमेंट को छोटी फ़ाइलों में बाँटें।',
  'privacySettings.limits.openRecurring': 'आवर्ती नियम',
  'privacySettings.limits.openRecurringHelp':
    'वे आवर्ती नियम जो खत्म नहीं हुए हैं। बिलों के शेड्यूल भी गिने जाते हैं।',
  'privacySettings.limits.openBills': 'बिल',
  'privacySettings.limits.openBillsHelp': 'वे बिल जो संग्रहित नहीं हैं।',
  'privacySettings.limits.openSubscriptions': 'सब्सक्रिप्शन',
  'privacySettings.limits.openSubscriptionsHelp': 'वे सब्सक्रिप्शन जो रद्द नहीं हुए हैं।',
  'privacySettings.limits.openGoals': 'लक्ष्य',
  'privacySettings.limits.openGoalsHelp': 'वे लक्ष्य जो संग्रहित नहीं हैं।',
  'privacySettings.limits.supportRequests': 'सहायता अनुरोध',
  'privacySettings.limits.perDay': { one: 'रोज़ {count}', other: 'रोज़ {count}' },
  'privacySettings.limits.supportRequestsHelp':
    '24 घंटे में आप सहायता को इतने अनुरोध भेज सकते हैं।',
  'privacySettings.limits.downloadWindow': 'डाउनलोड की अवधि',
  'privacySettings.limits.downloadWindowHelp':
    'डेटा एक्सपोर्ट और रिपोर्ट डाउनलोड कितने समय तक उपलब्ध रहते हैं।',
  'privacySettings.limits.deletionGrace': 'खाता हटाने की छूट अवधि',
  'privacySettings.limits.deletionGraceHelp':
    'खाता हटाने का अनुरोध करने के बाद आप कितने समय तक उसे रद्द कर सकते हैं।',
  'privacySettings.limits.days': { one: '{count} दिन', other: '{count} दिन' },
  'privacySettings.limits.ai': 'AI अनुरोध',
  'privacySettings.limits.aiOff': 'बंद',
  'privacySettings.limits.aiHelp':
    'Montra की वैकल्पिक AI सुविधाओं के अनुरोध, जो सिर्फ़ तब इस्तेमाल होते हैं जब आप उन्हें चालू करें।',
  'privacySettings.limits.aiOffHelp': 'Montra की वैकल्पिक AI सुविधाएँ चालू नहीं हैं।',
  'privacySettings.limits.rates.title': 'अनुरोधों की दर',
  'privacySettings.limits.rates.description':
    'हर मिनट ऐप्स आपके लिए कितने अनुरोध भेज सकते हैं, प्रकार के अनुसार।',
  'privacySettings.limits.rates.kind': 'अनुरोध का प्रकार',
  'privacySettings.limits.rates.perMinute': 'प्रति मिनट',
  'privacySettings.limits.rates.burst': 'एक साथ अतिरिक्त छूट',
  'privacySettings.limits.rates.none': 'अभी अनुरोधों की कोई दर प्रकाशित नहीं है।',
  'privacySettings.limits.rates.over':
    'अगर आप कोई दर पार कर लेते हैं, तो Montra आपसे थोड़ा रुकने को कहता है। कुछ भी खोता नहीं है।',
  'privacySettings.limits.policy.default': 'रोज़ का इस्तेमाल',
  'privacySettings.limits.policyHelp.default': 'पेज खोलना और अपना डेटा देखना।',
  'privacySettings.limits.policy.write': 'बदलाव सहेजना',
  'privacySettings.limits.policyHelp.write': 'रिकॉर्ड जोड़ना, बदलना या हटाना।',
  'privacySettings.limits.policy.upload': 'अपलोड',
  'privacySettings.limits.policyHelp.upload': 'रसीदें, स्टेटमेंट और अटैचमेंट।',
  'privacySettings.limits.policy.export': 'एक्सपोर्ट और रिपोर्ट',
  'privacySettings.limits.policyHelp.export': 'डेटा एक्सपोर्ट और रिपोर्ट फ़ाइलें।',
  'privacySettings.limits.policy.social': 'दोस्त, समूह और समुदाय',
  'privacySettings.limits.policyHelp.social': 'दोस्ती के अनुरोध, निमंत्रण और पोस्ट।',
  'privacySettings.limits.policy.auth': 'साइन-इन और सुरक्षा',
  'privacySettings.limits.policyHelp.auth': 'साइन-इन की कोशिशें, पासवर्ड रीसेट और संपर्क फ़ॉर्म।',
  'privacySettings.limits.policy.ai': 'AI अनुरोध',
  'privacySettings.limits.policyHelp.ai': 'वैकल्पिक AI सुविधाएँ।',
  'privacySettings.limits.backToPrivacy': 'गोपनीयता और डेटा पर वापस जाएँ',
  'privacySettings.consents.versionUnknown':
    'यह सहमति अभी नहीं दी जा सकती। पेज फिर से लोड करें और बाद में कोशिश करें।',
  'privacySettings.export.status.queued': 'शुरू होने का इंतज़ार',
  'privacySettings.export.status.running': 'तैयार हो रहा है',
  'privacySettings.export.status.completed': 'डाउनलोड के लिए तैयार',
  'privacySettings.export.status.failed': 'पूरा नहीं हुआ',
  'privacySettings.export.status.expired': 'अब उपलब्ध नहीं',
  'privacySettings.export.historyTitle': 'पिछले एक्सपोर्ट',
  'privacySettings.export.requestedOn': '{date} को माँगा गया',
  'privacySettings.export.downloadFrom': '{date} को माँगा गया एक्सपोर्ट डाउनलोड करें',
  'privacySettings.export.listError': 'हम आपके एक्सपोर्ट लोड नहीं कर सके',
  'privacySettings.deletion.code.signed_out_and_integrations_revoked':
    'आप हर डिवाइस से साइन आउट हो जाएँगे, और हर जुड़ी हुई सेवा का कनेक्शन हटा दिया जाएगा।',
  'privacySettings.deletion.code.personal_records_deleted':
    'आपके खाते, लेन-देन, बजट, लक्ष्य, सदस्यताएँ, रसीदें, इम्पोर्ट और रिपोर्ट हमेशा के लिए मिटा दिए जाएँगे।',
  'privacySettings.deletion.code.documents_removed':
    'आपकी अपलोड की गई फ़ाइलें स्टोरेज से हटा दी जाएँगी।',
  'privacySettings.deletion.code.profile_removed_posts_anonymized':
    'आपकी प्रोफ़ाइल हटा दी जाएगी; आपकी कम्युनिटी पोस्ट और टिप्पणियों पर अब आपका नाम नहीं दिखेगा।',
  'privacySettings.deletion.code.irreversible_after_date':
    'तय तारीख के बाद इसे वापस नहीं लिया जा सकता।',
  'privacySettings.deletion.code.shared_group_records_anonymized':
    'समूह के खर्चों और भुगतानों में आपका हिस्सा बना रहता है, ताकि बाकी सदस्यों के बैलेंस सही रहें; आपके नाम की जगह “हटाया गया सदस्य” दिखेगा।',
  'privacySettings.deletion.code.security_audit_records_retained':
    'सुरक्षा और ऑडिट रिकॉर्ड, कानूनी और धोखाधड़ी-रोकथाम ज़िम्मेदारियों के लिए, तय अवधि तक आपके नाम के बिना रखे जाते हैं।',
  'privacySettings.deletion.code.ownership_transfer':
    '“{name}” का मालिकाना हक़ उसके सबसे पुराने एडमिन या सदस्य को मिल जाएगा।',
  'privacySettings.deletion.code.group_deleted':
    '“{name}” में कोई और सदस्य नहीं है, इसलिए उसे मिटा दिया जाएगा।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
