import type { NamespaceTranslation } from '../../types';
import type en from '../en/social';

/** Hindi `social` messages; missing keys fall back to English. */
const messages = {
  // Round 4: friends (social graph, privacy by default)
  'social.title': 'दोस्त',
  'social.description':
    'जिन लोगों पर आप भरोसा करते हैं, उनसे जुड़ें और बजट, लक्ष्य और समूह साझा करें। दोस्त कभी आपके लेन-देन या बैलेंस नहीं देखते।',
  'social.tabs.label': 'दोस्तों के हिस्से',
  'social.tabs.friends': 'दोस्त',
  'social.tabs.requests': 'अनुरोध',
  'social.tabs.waiting': { one: '{count} इंतज़ार में', other: '{count} इंतज़ार में' },
  'social.tabs.find': 'लोग खोजें',
  'social.tabs.blocked': 'ब्लॉक और म्यूट',
  'social.tabs.privacy': 'गोपनीयता',
  'social.actionsFor': '{name} के लिए और विकल्प',
  'social.username.calloutTitle': 'अभी आपका कोई यूज़रनेम नहीं है',
  'social.username.calloutBody':
    'Montra पर दोस्त एक-दूसरे को सही यूज़रनेम से ढूँढते हैं। एक यूज़रनेम चुनें, ताकि आपके जान-पहचान वाले आपको अनुरोध भेज सकें।',
  'social.username.calloutAction': 'यूज़रनेम चुनें',
  'social.username.profileLink': 'अपनी प्रोफ़ाइल देखें',
  'social.username.title': 'आपका यूज़रनेम',
  'social.username.description':
    'Montra पर दोस्त आपको आपके यूज़रनेम से ढूँढते हैं। जिनसे आप जुड़ते हैं, उन्हें यह आपके नाम के साथ दिखता है।',
  'social.username.current': 'आपका यूज़रनेम @{username} है।',
  'social.username.none': 'अभी आपका कोई यूज़रनेम नहीं है, इसलिए दोस्त आपको ढूँढ नहीं सकते।',
  'social.username.label': 'यूज़रनेम',
  'social.username.help': '3 से 30 अक्षर: छोटे अंग्रेज़ी अक्षर, अंक, बिंदु (.) और अंडरस्कोर (_)।',
  'social.username.required': 'यूज़रनेम दर्ज करें।',
  'social.username.invalid':
    '3 से 30 अक्षर इस्तेमाल करें: छोटे अंग्रेज़ी अक्षर, अंक, बिंदु (.) और अंडरस्कोर (_)।',
  'social.username.taken': 'यह यूज़रनेम पहले से लिया जा चुका है। कोई दूसरा आज़माएँ।',
  'social.username.reserved': 'यह यूज़रनेम Montra के लिए आरक्षित है। कोई दूसरा चुनें।',
  'social.username.unavailable': 'यह यूज़रनेम उपलब्ध नहीं है। कोई दूसरा आज़माएँ।',
  'social.username.unchanged': '@{username} पहले से आपका यूज़रनेम है',
  'social.username.saved': 'अब आपका यूज़रनेम @{username} है',
  'social.username.savedFindable': 'दोस्त आपको इससे ढूँढ सकते हैं।',
  'social.username.savedHidden':
    'अभी आप खोज में नहीं दिखते। आप इसे “आपको कौन ढूँढ सकता है” में बदल सकते हैं।',
  'social.username.change': 'यूज़रनेम बदलें',
  'social.username.save': 'यूज़रनेम सहेजें',
  'social.friends.title': 'आपके दोस्त',
  'social.friends.description':
    'आप दोस्तों को साझा बजट, लक्ष्य और समूहों में जोड़ सकते हैं। वे कभी आपके निजी लेन-देन या बैलेंस नहीं देखते।',
  'social.friends.loading': 'आपके दोस्त लोड हो रहे हैं…',
  'social.friends.error': 'हम आपके दोस्त लोड नहीं कर सके',
  'social.friends.empty.title': 'अभी कोई दोस्त नहीं',
  'social.friends.empty.body':
    'लोगों को उनके यूज़रनेम से ढूँढें और उन्हें अनुरोध भेजें। फिर आप उनके साथ बजट, लक्ष्य और समूह साझा कर सकते हैं।',
  'social.friends.empty.action': 'लोग खोजें',
  'social.friends.count': { one: '{count} दोस्त', other: '{count} दोस्त' },
  'social.remove.action': 'हटाएँ',
  'social.remove.actionFor': '{name} को दोस्तों से हटाएँ',
  'social.remove.title': '{name} को अपने दोस्तों से हटाएँ?',
  'social.remove.body':
    'आप दोस्त नहीं रहेंगे, इसलिए एक-दूसरे को नए साझा बजट या लक्ष्यों में नहीं जोड़ पाएँगे। जो आप पहले से साझा करते हैं और जिन समूहों में आप दोनों हैं, वे वैसे ही रहेंगे। Montra उन्हें नहीं बताता, और आप बाद में फिर से अनुरोध भेज सकते हैं।',
  'social.remove.confirm': 'दोस्त हटाएँ',
  'social.remove.done': '{name} को आपके दोस्तों से हटा दिया गया',
  'social.remove.alreadyDone': 'अब आप {name} के दोस्त नहीं हैं',
  'social.block.action': 'ब्लॉक करें',
  'social.block.title': '{name} को ब्लॉक करें?',
  'social.block.effectFriends':
    'आप दोस्त नहीं रहेंगे, और आपके बीच के सभी दोस्ती अनुरोध रद्द हो जाएँगे।',
  'social.block.effectHidden':
    'आप एक-दूसरे को दोस्तों, अनुरोधों या खोज में नहीं देखेंगे, और वे आपको न ढूँढ पाएँगे, न अनुरोध भेज पाएँगे।',
  'social.block.effectPrivate':
    'Montra उन्हें नहीं बताता। जिन समूहों में आप दोनों हैं, उनका साझा इतिहास बना रहता है।',
  'social.block.confirm': 'ब्लॉक करें',
  'social.block.done': '{name} ब्लॉक हो गए',
  'social.block.notFound': 'हम इस व्यक्ति को नहीं ढूँढ सके। हो सकता है उनका खाता बंद हो गया हो।',
  'social.unblock.action': 'अनब्लॉक करें',
  'social.unblock.actionFor': '{name} को अनब्लॉक करें',
  'social.unblock.title': '{name} को अनब्लॉक करें?',
  'social.unblock.body':
    'अगर आपकी गोपनीयता सेटिंग अनुमति देती है, तो वे आपको यूज़रनेम से फिर ढूँढ सकेंगे और दोस्ती का अनुरोध भेज सकेंगे। जब तक आप दोनों सहमत न हों, आप फिर से दोस्त नहीं बनेंगे।',
  'social.unblock.confirm': 'अनब्लॉक करें',
  'social.unblock.done': '{name} अनब्लॉक हो गए',
  'social.unblock.alreadyDone': '{name} ब्लॉक नहीं हैं',
  'social.mute.action': 'सूचनाएँ म्यूट करें',
  'social.unmute.action': 'सूचनाएँ फिर से चालू करें',
  'social.unmute.actionFor': '{name} की सूचनाएँ फिर से चालू करें',
  'social.mute.done': '{name} को म्यूट किया गया',
  'social.mute.doneBody': 'आपको उनकी सूचनाएँ नहीं मिलेंगी। उन्हें यह नहीं बताया जाता।',
  'social.unmute.done': '{name} की सूचनाएँ फिर से चालू हैं',
  'social.mute.failed': 'हम उन्हें म्यूट नहीं कर सके',
  'social.unmute.failed': 'हम उनकी सूचनाएँ फिर से चालू नहीं कर सके',
  'social.muted.badge': 'म्यूट',
  'social.requests.title': 'दोस्ती के अनुरोध',
  'social.requests.loading': 'दोस्ती के अनुरोध लोड हो रहे हैं…',
  'social.requests.error': 'हम आपके दोस्ती के अनुरोध लोड नहीं कर सके',
  'social.requests.incomingTitle': 'आपके लिए अनुरोध',
  'social.requests.incomingDescription':
    'दोस्त बनने के लिए स्वीकार करें। अगर आप मना करते हैं, तो Montra उन्हें सूचना नहीं भेजता।',
  'social.requests.incomingEmpty': 'कोई अनुरोध इंतज़ार में नहीं',
  'social.requests.incomingEmptyBody': 'जब कोई आपको दोस्ती का अनुरोध भेजेगा, तो वह यहाँ दिखेगा।',
  'social.requests.outgoingTitle': 'आपके भेजे अनुरोध',
  'social.requests.outgoingDescription':
    'जवाब का इंतज़ार है। आप किसी भी समय अनुरोध रद्द कर सकते हैं।',
  'social.requests.outgoingEmpty': 'आपने कोई अनुरोध नहीं भेजा है',
  'social.requests.sentOn': '{date} को भेजा गया',
  'social.requests.note': 'संदेश:',
  'social.requests.accept': 'स्वीकार करें',
  'social.requests.acceptFrom': '{name} का अनुरोध स्वीकार करें',
  'social.requests.decline': 'मना करें',
  'social.requests.declineFrom': '{name} के अनुरोध को मना करें',
  'social.requests.cancel': 'अनुरोध रद्द करें',
  'social.requests.cancelTo': '{name} को भेजा अनुरोध रद्द करें',
  'social.requests.accepted': 'अब आप {name} के दोस्त हैं',
  'social.requests.declined': '{name} के अनुरोध को मना किया गया',
  'social.requests.cancelled': '{name} को भेजा आपका अनुरोध रद्द किया गया',
  'social.requests.acceptFailed': 'हम अनुरोध स्वीकार नहीं कर सके',
  'social.requests.declineFailed': 'हम अनुरोध को मना नहीं कर सके',
  'social.requests.cancelFailed': 'हम अनुरोध रद्द नहीं कर सके',
  'social.requests.gone':
    'यह अनुरोध अब इंतज़ार में नहीं है। हो सकता है इसका जवाब दिया जा चुका हो या इसे रद्द कर दिया गया हो।',
  'social.find.title': 'यूज़रनेम से लोग खोजें',
  'social.find.description':
    'लोग सिर्फ़ उनके सही यूज़रनेम से मिलते हैं: अधूरा यूज़रनेम किसी को नहीं ढूँढता। Montra सिर्फ़ उन्हीं लोगों को दिखाता है जिन्होंने खोजे जाने की अनुमति दी है, और कभी किसी का पैसा नहीं दिखाता।',
  'social.find.label': 'यूज़रनेम',
  'social.find.help':
    'उनका सही यूज़रनेम दर्ज करें, जैसे @asha_rao। अधूरे यूज़रनेम से कोई नहीं मिलता।',
  'social.find.submit': 'खोजें',
  'social.find.required': 'यूज़रनेम दर्ज करें।',
  'social.find.tooShort': {
    one: 'पूरा यूज़रनेम दर्ज करें (कम से कम {count} अक्षर)।',
    other: 'पूरा यूज़रनेम दर्ज करें (कम से कम {count} अक्षर)।',
  },
  'social.find.invalid':
    'यूज़रनेम में 3 से 30 अक्षर होते हैं: छोटे अंग्रेज़ी अक्षर, अंक, बिंदु (.) और अंडरस्कोर (_)।',
  'social.find.searching': 'खोज रहे हैं…',
  'social.find.error': 'अभी हम खोज नहीं सके',
  'social.find.foundAnnouncement': '{name}, @{username} मिल गए।',
  'social.find.notFoundTitle': '@{username} यूज़रनेम वाला कोई नहीं मिला',
  'social.find.notFoundBody':
    'सिर्फ़ सही यूज़रनेम से ही कोई मिलता है, इसलिए वर्तनी जाँचें। कुछ लोग खोज में न दिखना चुनते हैं, और नए खाते तब तक छिपे रहते हैं जब तक वे इसे चालू न करें।',
  'social.find.shareYours':
    'आप अपना यूज़रनेम, @{username}, भी साझा कर सकते हैं, ताकि वे आपको ढूँढ सकें।',
  'social.find.self': 'यह आपका अपना यूज़रनेम है',
  'social.find.selfBody':
    'इसे अपने जान-पहचान वालों के साथ साझा करें, ताकि वे आपको ढूँढकर अनुरोध भेज सकें।',
  'social.find.resultLabel': 'खोज का नतीजा: {name}',
  'social.find.blockedNow': 'आपने @{username} को ब्लॉक किया है',
  'social.find.blockedNowBody':
    'वे अब आपकी खोज में नहीं दिखेंगे। आप उन्हें “ब्लॉक और म्यूट” में अनब्लॉक कर सकते हैं।',
  'social.find.status.friend': 'दोस्त',
  'social.find.status.sent': 'अनुरोध भेजा गया',
  'social.find.status.received': 'आपको अनुरोध भेजा है',
  'social.find.status.self': 'आप',
  'social.find.alreadyFriends': 'आप और {name} पहले से दोस्त हैं।',
  'social.find.viewRequests': 'अनुरोध देखें',
  'social.send.note': 'एक संदेश जोड़ें',
  'social.send.noteHelp': 'वे इसे आपके अनुरोध के साथ देखेंगे। ज़्यादा से ज़्यादा {max} अक्षर।',
  'social.send.action': 'दोस्ती का अनुरोध भेजें',
  'social.send.actionTo': '{name} को दोस्ती का अनुरोध भेजें',
  'social.send.done': '{name} को दोस्ती का अनुरोध भेजा गया',
  'social.send.doneBody': 'जब वे स्वीकार करेंगे, तब आप दोस्त बन जाएँगे।',
  'social.send.closed': '{name} अभी दोस्ती के अनुरोध नहीं ले रहे हैं।',
  'social.send.notFound':
    'हम {name} को अनुरोध नहीं भेज सके। हो सकता है उन्होंने अपना यूज़रनेम बदल दिया हो या खोजे जाने की अनुमति बंद कर दी हो।',
  'social.send.conflict':
    'आप पहले से {name} के दोस्त हैं, या आपके बीच एक अनुरोध पहले से इंतज़ार में है।',
  'social.send.alreadyFriends': 'आप और {name} पहले से दोस्त हैं।',
  'social.send.pending':
    'आपने {name} को पहले ही अनुरोध भेजा है। जब वे स्वीकार करेंगे, तब आप दोस्त बन जाएँगे।',
  'social.blocked.title': 'ब्लॉक किए गए लोग',
  'social.blocked.description':
    'जिन्हें आपने ब्लॉक किया है, वे आपके दोस्तों, अनुरोधों और खोज से गायब हो जाते हैं, और वे आपको न ढूँढ सकते हैं, न अनुरोध भेज सकते हैं। उन्हें यह नहीं बताया जाता।',
  'social.blocked.empty': 'आपने किसी को ब्लॉक नहीं किया है',
  'social.blocked.emptyBody':
    'किसी को ब्लॉक करने के लिए, उनके नाम के पास का मेन्यू खोलें और “ब्लॉक करें” चुनें।',
  'social.blocked.loading': 'ब्लॉक किए गए लोग लोड हो रहे हैं…',
  'social.blocked.error': 'हम ब्लॉक किए गए लोग लोड नहीं कर सके',
  'social.blocked.since': '{date} को ब्लॉक किया',
  'social.blocked.loadMore': 'और ब्लॉक किए गए लोग दिखाएँ',
  'social.loadMoreFailed': 'हम और लोड नहीं कर सके। फिर से कोशिश करें।',
  'social.muted.title': 'म्यूट किए गए लोग',
  'social.muted.description':
    'म्यूट करने से किसी की सूचनाएँ, जैसे दोस्ती के अनुरोध, आनी बंद हो जाती हैं। उन्हें यह नहीं बताया जाता, और बाकी कुछ नहीं बदलता।',
  'social.muted.empty': 'आपने किसी को म्यूट नहीं किया है',
  'social.muted.emptyBody':
    'किसी को म्यूट करने के लिए, उनके नाम के पास का मेन्यू खोलें और “सूचनाएँ म्यूट करें” चुनें।',
  'social.muted.loading': 'म्यूट किए गए लोग लोड हो रहे हैं…',
  'social.muted.error': 'हम म्यूट किए गए लोग लोड नहीं कर सके',
  'social.muted.since': '{date} को म्यूट किया',
  'social.muted.loadMore': 'और म्यूट किए गए लोग दिखाएँ',
  'social.privacy.title': 'आपको कौन ढूँढ सकता है',
  'social.privacy.description':
    'चुनें कि आपको कौन ढूँढ सकता है और कौन आपसे दोस्ती का अनुरोध कर सकता है। सहेजते ही बदलाव लागू हो जाते हैं।',
  'social.privacy.loading': 'आपकी गोपनीयता सेटिंग लोड हो रही है…',
  'social.privacy.error': 'हम आपकी गोपनीयता सेटिंग लोड नहीं कर सके',
  'social.privacy.discoverable': 'लोगों को मेरे यूज़रनेम से मुझे ढूँढने दें',
  'social.privacy.discoverableHelp':
    'चालू होने पर, लोग आपका यूज़रनेम, @{username}, खोजकर आपको ढूँढ सकते हैं। बंद होने पर, आप खोज में नहीं दिखते, लेकिन आपके दोस्त और आपके समूहों के लोग अब भी आपको जोड़ सकते हैं।',
  'social.privacy.discoverableNoUsername':
    'अभी आपका कोई यूज़रनेम नहीं है, इसलिए कोई आपको खोज से नहीं ढूँढ सकता।',
  'social.privacy.hiddenByDefault':
    'नए खाते छिपे हुए शुरू होते हैं: जब तक आप इसे चालू न करें, कोई आपको यूज़रनेम से नहीं ढूँढ सकता, भले ही वह उसे जानता हो।',
  'social.privacy.requests.legend': 'आपको दोस्ती का अनुरोध कौन भेज सकता है',
  'social.privacy.requests.help': 'जिन्हें आप ब्लॉक करते हैं, वे आपको कभी अनुरोध नहीं भेज सकते।',
  'social.privacy.requests.everyone': 'सभी',
  'social.privacy.requests.everyoneHelp': 'जो भी आपको ढूँढे, वह आपको अनुरोध भेज सकता है।',
  'social.privacy.requests.friendsOfFriends': 'दोस्तों के दोस्त',
  'social.privacy.requests.friendsOfFriendsHelp': 'सिर्फ़ वे लोग जिनका आपके साथ कोई साझा दोस्त है।',
  'social.privacy.requests.nobody': 'कोई नहीं',
  'social.privacy.requests.nobodyHelp':
    'कोई आपको अनुरोध नहीं भेज सकता। आप ख़ुद अब भी अनुरोध भेज सकते हैं।',
  'social.privacy.moneyNote':
    'आप जो भी चुनें, दोस्त कभी आपके लेन-देन या बैलेंस नहीं देखते। बजट और लक्ष्य तभी साझा होते हैं, जब आप उन्हें साझा करते हैं।',
  'social.privacy.save': 'गोपनीयता सेटिंग सहेजें',
  'social.privacy.saved': 'गोपनीयता सेटिंग सहेजी गई',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
