import type { NamespaceTranslation } from '../../types';
import type en from '../en/notifications';

/** Hindi `notifications` messages; missing keys fall back to English. */
const messages = {
  // Notifications: center, bell, settings, browser notifications and unsubscribe
  'notifications.bell.label': 'सूचनाएँ',
  'notifications.bell.labelNone': 'सूचनाएँ, कोई बिना पढ़ी नहीं',
  'notifications.bell.labelCount': {
    one: 'सूचनाएँ, {count} बिना पढ़ी',
    other: 'सूचनाएँ, {count} बिना पढ़ी',
  },
  'notifications.center.title': 'सूचनाएँ',
  'notifications.center.description':
    'आपके पैसे, समूहों और खाते के बारे में अपडेट। किसी को खोलने पर वह पढ़ी हुई मानी जाती है।',
  'notifications.center.loading': 'सूचनाएँ लोड हो रही हैं…',
  'notifications.center.error': 'हम आपकी सूचनाएँ लोड नहीं कर सके',
  'notifications.center.empty.inbox': 'आपने सब कुछ देख लिया है',
  'notifications.center.empty.inboxBody':
    'आपके पैसे, समूहों और खाते के बारे में नई सूचनाएँ यहाँ दिखेंगी।',
  'notifications.center.empty.unread': 'कोई बिना पढ़ी सूचना नहीं',
  'notifications.center.empty.archived': 'कुछ भी संग्रहित नहीं',
  'notifications.center.empty.archivedBody':
    'जिन सूचनाओं को आप संग्रहित करते हैं, और जिन श्रेणियों को आपने Montra में बंद किया है उनकी सूचनाएँ, यहाँ रखी जाती हैं।',
  'notifications.center.empty.category': 'यहाँ {category} के बारे में कुछ नहीं है।',
  'notifications.center.showing': {
    one: '{count} सूचना दिखाई जा रही है',
    other: '{count} सूचनाएँ दिखाई जा रही हैं',
  },
  'notifications.center.markAllRead': 'सभी को पढ़ा हुआ मानें',
  'notifications.center.allRead': {
    one: '{count} सूचना पढ़ी हुई मानी गई',
    other: '{count} सूचनाएँ पढ़ी हुई मानी गईं',
  },
  'notifications.center.nothingToMark': 'सब कुछ पहले से पढ़ा हुआ था',
  'notifications.center.allReadFailed': 'हम आपकी सूचनाओं को पढ़ा हुआ नहीं मान सके',
  'notifications.center.settings': 'सूचना सेटिंग',
  'notifications.center.view': 'दिखाएँ',
  'notifications.center.view.inbox': 'इनबॉक्स',
  'notifications.center.view.unread': 'बिना पढ़ी',
  'notifications.center.view.archived': 'संग्रहित',
  'notifications.center.category': 'श्रेणी',
  'notifications.center.allCategories': 'सभी श्रेणियाँ',
  'notifications.item.new': 'नई',
  'notifications.item.markRead': 'पढ़ा हुआ मानें',
  'notifications.item.markUnread': 'बिना पढ़ा मानें',
  'notifications.item.archive': 'संग्रहित करें',
  'notifications.item.unarchive': 'इनबॉक्स में ले जाएँ',
  'notifications.item.archived': 'सूचना संग्रहित की गई',
  'notifications.item.unarchived': 'सूचना आपके इनबॉक्स में ले जाई गई',
  'notifications.item.gone': 'वह सूचना अब मौजूद नहीं है।',
  'notifications.item.updateFailed': 'हम उस सूचना को अपडेट नहीं कर सके',
  'notifications.category.budget': 'बजट',
  'notifications.category.bill': 'बिल',
  'notifications.category.subscription': 'सब्सक्रिप्शन',
  'notifications.category.recurring': 'आवर्ती भुगतान',
  'notifications.category.goal': 'लक्ष्य',
  'notifications.category.import': 'स्टेटमेंट आयात',
  'notifications.category.receipt': 'रसीदें',
  'notifications.category.insight': 'सुझाव',
  'notifications.category.group': 'समूह',
  'notifications.category.settlement': 'हिसाब बराबर करना',
  'notifications.category.trip': 'यात्राएँ',
  'notifications.category.social': 'दोस्त',
  'notifications.category.community': 'समुदाय',
  'notifications.category.challenge': 'चुनौतियाँ',
  'notifications.category.security': 'सुरक्षा',
  'notifications.category.account': 'आपका Montra खाता',
  'notifications.category.export': 'एक्सपोर्ट और रिपोर्ट',
  'notifications.category.system': 'Montra के अपडेट',
  'notifications.category.other': 'अन्य',
  'notifications.categoryHelp.budget': 'जब आप किसी बजट के करीब पहुँचें या उससे आगे निकल जाएँ।',
  'notifications.categoryHelp.bill': 'जल्द देय या बकाया बिल।',
  'notifications.categoryHelp.subscription': 'खत्म होते ट्रायल और आने वाले रिन्यूअल।',
  'notifications.categoryHelp.recurring': 'तय भुगतान जो देय हैं या दर्ज नहीं हो सके।',
  'notifications.categoryHelp.goal': 'लक्ष्य की प्रगति, साझा लक्ष्य और योगदान की याद।',
  'notifications.categoryHelp.import': 'जब कोई स्टेटमेंट आयात पूरा हो जाए या उसे देखना ज़रूरी हो।',
  'notifications.categoryHelp.receipt': 'जब कोई रसीद जाँचने के लिए तैयार हो।',
  'notifications.categoryHelp.insight': 'आपके खर्च में Montra को दिखे पैटर्न।',
  'notifications.categoryHelp.group': 'आपके समूहों की गतिविधि, जैसे नए खर्च और सदस्य।',
  'notifications.categoryHelp.settlement': 'आपके समूहों में हिसाब बराबर करना।',
  'notifications.categoryHelp.trip':
    'शुरू होती यात्राएँ, और वे यात्राएँ जो बकाया हिसाब के साथ खत्म हुईं।',
  'notifications.categoryHelp.social': 'दोस्ती के अनुरोध।',
  'notifications.categoryHelp.community': 'समुदायों में ज़िक्र, जवाब और सदस्यता।',
  'notifications.categoryHelp.challenge': 'आपकी चुनौतियों में अहम पड़ाव।',
  'notifications.categoryHelp.security': 'साइन-इन अलर्ट और पासवर्ड या दो-चरण सत्यापन में बदलाव।',
  'notifications.categoryHelp.account': 'आपके Montra खाते के बारे में ज़रूरी सूचनाएँ।',
  'notifications.categoryHelp.export': 'जब आपका डेटा एक्सपोर्ट या कोई रिपोर्ट तैयार हो।',
  'notifications.categoryHelp.system': 'Montra के बारे में कभी-कभार की सूचनाएँ।',
  'notifications.section.money': 'आपका पैसा',
  'notifications.section.people': 'लोग और समूह',
  'notifications.section.account': 'खाता और सुरक्षा',
  'notifications.section.other': 'अन्य',
  'notifications.channel.in_app': 'Montra में',
  'notifications.channel.email': 'ईमेल',
  'notifications.channel.web_push': 'ब्राउज़र',
  'notifications.channel.push': 'फ़ोन ऐप',
  'notifications.timing.immediate': 'तुरंत',
  'notifications.timing.followDaily': 'आपके खाते की सेटिंग के साथ (रोज़ का सारांश)',
  'notifications.timing.followWeekly': 'आपके खाते की सेटिंग के साथ (हफ़्ते का सारांश)',
  'notifications.timing.daily': 'रोज़ के सारांश में',
  'notifications.timing.weekly': 'हफ़्ते के सारांश में',
  'notifications.settings.title': 'सूचना सेटिंग',
  'notifications.settings.description': 'चुनें कि Montra आपको किन बातों के बारे में और कैसे बताए।',
  'notifications.settings.center': 'सूचनाएँ खोलें',
  'notifications.settings.accountError': 'हम आपकी ईमेल और शांत समय की सेटिंग लोड नहीं कर सके',
  'notifications.prefs.title': 'आपको किन बातों की सूचना मिलती है',
  'notifications.prefs.description': 'चुनें कि हर तरह की सूचना आप तक कहाँ पहुँचे।',
  'notifications.prefs.loading': 'आपकी पसंद लोड हो रही है…',
  'notifications.prefs.error': 'हम आपकी सूचना पसंद लोड नहीं कर सके',
  'notifications.prefs.alwaysOn.title': 'सुरक्षा और खाते की सूचनाएँ हमेशा चालू रहती हैं',
  'notifications.prefs.alwaysOn.body':
    'साइन-इन अलर्ट, पासवर्ड और दो-चरण सत्यापन में बदलाव, और आपके खाते की दूसरी सूचनाएँ हमेशा Montra में दिखती हैं और हमेशा ईमेल की जाती हैं, क्योंकि ये आपके खाते की सुरक्षा करती हैं। बाकी सब आप चुनते हैं।',
  'notifications.prefs.alwaysOnShort': 'Montra में और ईमेल से हमेशा चालू',
  'notifications.prefs.lockedChannel': 'हमेशा चालू',
  'notifications.prefs.inAppHelp':
    'किसी श्रेणी के लिए “Montra में” बंद करने पर उसकी नई सूचनाएँ सीधे संग्रहित में चली जाती हैं, ताकि कुछ भी खोए नहीं।',
  'notifications.prefs.deviceHelp':
    'ब्राउज़र और फ़ोन की सूचनाएँ सिर्फ़ वहीं आती हैं जहाँ आपने उन्हें चालू किया है।',
  'notifications.prefs.digestOff':
    'हर श्रेणी के लिए ईमेल का समय: “तुरंत” हर वैकल्पिक ईमेल अलग से भेजता है; रोज़ या हफ़्ते का सारांश उस श्रेणी के ईमेल सारांश के लिए रोक लेता है। ज़रूरी ईमेल हमेशा तुरंत भेजे जाते हैं।',
  'notifications.prefs.digestDaily':
    'आपके खाते की सेटिंग रोज़ का सारांश है, इसलिए “आपके खाते की सेटिंग के साथ” वाली श्रेणियाँ उसका इंतज़ार करती हैं। किसी श्रेणी के ईमेल ज़्यादा देर रोकने के लिए हफ़्ते का सारांश चुनें, या रोज़ के सारांश में रखने के लिए रोज़ का। ज़रूरी ईमेल हमेशा तुरंत भेजे जाते हैं।',
  'notifications.prefs.digestWeekly':
    'आपके खाते की सेटिंग हफ़्ते का सारांश है, इसलिए “आपके खाते की सेटिंग के साथ” वाली श्रेणियाँ उसका इंतज़ार करती हैं। किसी श्रेणी के ईमेल जल्दी पाने के लिए रोज़ का सारांश चुनें। ज़रूरी ईमेल हमेशा तुरंत भेजे जाते हैं।',
  'notifications.prefs.groupRows':
    'कुछ समूहों की अपनी सूचना सेटिंग हैं, जो उन समूहों पर इनकी जगह लागू होती हैं।',
  'notifications.prefs.emailTiming': 'ईमेल का समय',
  'notifications.prefs.save': 'पसंद सहेजें',
  'notifications.prefs.discard': 'बदलाव वापस लें',
  'notifications.prefs.unsaved': {
    one: '{count} बदलाव सहेजा नहीं गया',
    other: '{count} बदलाव सहेजे नहीं गए',
  },
  'notifications.prefs.saved': 'सूचना पसंद सहेज ली गई',
  'notifications.digest.title': 'ईमेल सारांश',
  'notifications.digest.description': 'वैकल्पिक ईमेल एक-एक करके पाएँ, या एक सारांश में एक साथ।',
  'notifications.digest.legend': 'वैकल्पिक ईमेल',
  'notifications.digest.off': 'जैसे-जैसे हों, भेजें',
  'notifications.digest.offHelp': 'हर वैकल्पिक ईमेल अलग से आता है।',
  'notifications.digest.daily': 'रोज़ का सारांश',
  'notifications.digest.dailyHelp':
    'हर सुबह करीब 8:00 बजे एक ईमेल, जिसमें बताया जाता है कि क्या हुआ।',
  'notifications.digest.weekly': 'हफ़्ते का सारांश',
  'notifications.digest.weeklyHelp': 'हर सोमवार सुबह एक ईमेल, जिसमें बताया जाता है कि क्या हुआ।',
  'notifications.digest.always':
    'सुरक्षा और खाते के ईमेल, और ज़रूरी ईमेल, हमेशा तुरंत भेजे जाते हैं।',
  'notifications.digest.save': 'ईमेल सेटिंग सहेजें',
  'notifications.digest.saved': 'ईमेल सारांश की सेटिंग सहेज ली गई',
  'notifications.quiet.title': 'शांत समय',
  'notifications.quiet.description':
    'शांत समय खत्म होने तक ब्राउज़र, फ़ोन और ईमेल की सूचनाएँ रुकी रहती हैं। वे Montra में फिर भी दिखती हैं, और सुरक्षा अलर्ट और ज़रूरी सूचनाएँ हमेशा आती हैं।',
  'notifications.quiet.enable': 'शांत समय में सूचनाएँ रोकें',
  'notifications.quiet.enableHelp': 'समय आपके टाइम ज़ोन ({timeZone}) में है।',
  'notifications.quiet.start': 'से',
  'notifications.quiet.end': 'तक',
  'notifications.quiet.timeInvalid': '22:00 जैसा समय दर्ज करें।',
  'notifications.quiet.sameTime': 'शुरू के समय से अलग खत्म होने का समय चुनें।',
  'notifications.quiet.save': 'शांत समय सहेजें',
  'notifications.quiet.saved': 'शांत समय सहेज लिया गया',
  'notifications.push.title': 'ब्राउज़र सूचनाएँ',
  'notifications.push.description':
    'Montra खुला न होने पर भी इस ब्राउज़र में सूचना पाएँ। सूचनाओं में छोटा सारांश होता है, कभी कोई राशि नहीं।',
  'notifications.push.checking': 'इस ब्राउज़र की जाँच हो रही है…',
  'notifications.push.on': 'इस ब्राउज़र के लिए चालू',
  'notifications.push.onHelp':
    'जब किसी चीज़ पर आपका ध्यान चाहिए होगा, तो आपको यहाँ एक छोटी सूचना मिलेगी।',
  'notifications.push.off': 'इस ब्राउज़र के लिए बंद',
  'notifications.push.offHelp': 'आपका ब्राउज़र पहले आपकी अनुमति माँगेगा।',
  'notifications.push.turnOn': 'ब्राउज़र सूचनाएँ चालू करें',
  'notifications.push.turnOff': 'इस ब्राउज़र के लिए बंद करें',
  'notifications.push.turnedOn': 'इस ब्राउज़र के लिए ब्राउज़र सूचनाएँ चालू हैं',
  'notifications.push.turnedOff': 'इस ब्राउज़र के लिए ब्राउज़र सूचनाएँ बंद हैं',
  'notifications.push.unsupported.title': 'यह ब्राउज़र सूचनाएँ नहीं दिखा सकता',
  'notifications.push.unsupported.body':
    'यह वेबसाइटों की सूचनाओं का समर्थन नहीं करता, या वे बंद हैं। आपको सब कुछ फिर भी Montra की सूचनाओं में मिलेगा।',
  'notifications.push.notConfigured.title': 'इस सर्वर पर ब्राउज़र सूचनाएँ उपलब्ध नहीं हैं',
  'notifications.push.notConfigured.body':
    'यह Montra सर्वर इन्हें भेजने के लिए सेट नहीं है। आपको सब कुछ Montra की सूचनाओं में, और चाहें तो ईमेल से भी, मिलता रहेगा।',
  'notifications.push.blocked.title': 'इस ब्राउज़र में सूचनाएँ ब्लॉक हैं',
  'notifications.push.blocked.body':
    'इन्हें अनुमति देने के लिए अपने ब्राउज़र में इस साइट की सूचना सेटिंग बदलें, फिर यह पेज दोबारा लोड करें।',
  'notifications.push.blockedNow':
    'आपके ब्राउज़र ने Montra की सूचनाएँ ब्लॉक कर दीं। इन्हें अनुमति देने के लिए अपने ब्राउज़र में इस साइट की सूचना सेटिंग बदलें, फिर यह पेज दोबारा लोड करें।',
  'notifications.push.dismissed':
    'आपने सूचनाओं की अनुमति नहीं दी, इसलिए कुछ नहीं बदला। आप कभी भी फिर से कोशिश कर सकते हैं।',
  'notifications.push.serviceUnsupported':
    'Montra अभी इस ब्राउज़र की पुश सेवा से सूचनाएँ नहीं भेज सकता। कोई दूसरा ब्राउज़र आज़माएँ।',
  'notifications.push.workerFailed':
    'Montra इस ब्राउज़र में सूचनाएँ शुरू नहीं कर सका। पेज दोबारा लोड करें और फिर से कोशिश करें।',
  'notifications.push.browserFailed':
    'यह ब्राउज़र सूचनाएँ सेट नहीं कर सका। बाद में फिर से कोशिश करें।',
  'notifications.push.configError': 'हम जाँच नहीं सके कि ब्राउज़र सूचनाएँ उपलब्ध हैं या नहीं',
  'notifications.push.reregister.title': 'इस ब्राउज़र को फिर से रजिस्टर करना होगा',
  'notifications.push.reregister.body':
    'ब्राउज़र सूचनाएँ हर साइन-इन के साथ खत्म हो जाती हैं, ताकि साझा ब्राउज़र पर साइन आउट के बाद वे आती न रहें। यहाँ सूचनाएँ पाते रहने के लिए इस ब्राउज़र को फिर से रजिस्टर करें।',
  'notifications.push.reregister.stoppedBody':
    'पुश सेवा ने इस ब्राउज़र पर सूचनाएँ पहुँचाना बंद कर दिया। यहाँ सूचनाएँ फिर से पाने के लिए इसे दोबारा रजिस्टर करें।',
  'notifications.push.reregister.action': 'इस ब्राउज़र को फिर से रजिस्टर करें',
  'notifications.push.sessionNote':
    'ब्राउज़र तब तक रजिस्टर रहता है जब तक आप उससे साइन आउट नहीं करते। दोबारा साइन इन करने के बाद इसी पेज से उसे फिर रजिस्टर करें।',
  'notifications.devices.title': 'सूचनाएँ पाने वाले ब्राउज़र और डिवाइस',
  'notifications.devices.description':
    'आपके खाते पर रजिस्टर सब कुछ। Montra उनके पते या कुंजियाँ कभी नहीं दिखाता।',
  'notifications.devices.loading': 'ब्राउज़र और डिवाइस लोड हो रहे हैं…',
  'notifications.devices.error': 'हम आपके ब्राउज़र और डिवाइस लोड नहीं कर सके',
  'notifications.devices.empty': 'सूचनाओं के लिए कोई ब्राउज़र या डिवाइस रजिस्टर नहीं है।',
  'notifications.devices.kind.webpush': 'ब्राउज़र',
  'notifications.devices.kind.fcm': 'फ़ोन ऐप',
  'notifications.devices.thisBrowser': 'यह ब्राउज़र',
  'notifications.devices.stopped': 'रुका हुआ',
  'notifications.devices.stoppedHelp':
    'पुश सेवा ने इस पर सूचनाएँ पहुँचाना बंद कर दिया। फिर से शुरू करने के लिए उसी ब्राउज़र या डिवाइस से इसे दोबारा रजिस्टर करें।',
  'notifications.devices.added': '{date} को जोड़ा गया',
  'notifications.devices.lastUsed': 'आख़िरी सूचना {date}',
  'notifications.devices.neverUsed': 'अभी तक कोई सूचना नहीं भेजी गई',
  'notifications.devices.remove': 'हटाएँ',
  'notifications.devices.removeFor': '{device} हटाएँ',
  'notifications.devices.removeTitle': 'यह ब्राउज़र या डिवाइस हटाएँ?',
  'notifications.devices.removeBody':
    '{device} को दोबारा रजिस्टर होने तक सूचनाएँ नहीं मिलेंगी। और कुछ नहीं बदलता।',
  'notifications.devices.removeConfirm': 'हटाएँ',
  'notifications.devices.removed': 'हटा दिया गया। अब इसे सूचनाएँ नहीं मिलेंगी।',
  'notifications.unsubscribe.title': 'ईमेल की सदस्यता छोड़ें',
  'notifications.unsubscribe.confirm.category': 'क्या {category} के बारे में ईमेल पाना बंद करें?',
  'notifications.unsubscribe.confirm.generic': 'क्या इस तरह के ईमेल पाना बंद करें?',
  'notifications.unsubscribe.confirm.action': 'सदस्यता छोड़ें',
  'notifications.unsubscribe.stillSent':
    'सुरक्षा और खाते के ईमेल, जैसे साइन-इन अलर्ट, फिर भी भेजे जाते हैं क्योंकि ये आपके खाते की सुरक्षा करते हैं।',
  'notifications.unsubscribe.manage': 'सूचना सेटिंग बदलें',
  'notifications.unsubscribe.done.title': 'आपने सदस्यता छोड़ दी है',
  'notifications.unsubscribe.done.body':
    'अब आपको {category} के बारे में ईमेल नहीं मिलेंगे। आप इन्हें अपनी सूचना सेटिंग में फिर से चालू कर सकते हैं।',
  'notifications.unsubscribe.missing.title': 'यह लिंक अधूरा है',
  'notifications.unsubscribe.missing.body':
    'अपने ईमेल से सदस्यता छोड़ने वाला लिंक फिर से खोलें, या Montra में अपनी ईमेल सेटिंग बदलें।',
  'notifications.unsubscribe.invalid.title':
    'इस लिंक की समय-सीमा खत्म हो गई है या यह मान्य नहीं है',
  'notifications.unsubscribe.invalid.body':
    'सदस्यता छोड़ने वाले लिंक 60 दिन तक काम करते हैं। आप फिर भी Montra में अपनी ईमेल सेटिंग बदल सकते हैं।',
  'notifications.unsubscribe.alwaysOn.title': 'ये ईमेल बंद नहीं किए जा सकते',
  'notifications.unsubscribe.alwaysOn.body':
    'सुरक्षा और खाते के ईमेल, जैसे साइन-इन अलर्ट, आपके खाते की सुरक्षा करते हैं, इसलिए Montra इन्हें हमेशा भेजता है।',
  'notifications.unsubscribe.failed': 'हम आपकी सदस्यता नहीं हटा सके',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
