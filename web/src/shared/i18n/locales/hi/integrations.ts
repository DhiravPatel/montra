import type { NamespaceTranslation } from '../../types';
import type en from '../en/integrations';

/** Hindi `integrations` messages; missing keys fall back to English. */
const messages = {
  // Integrations: connected services, consent, sync and OAuth return
  'integrations.title': 'जुड़ी सेवाएँ',
  'integrations.description':
    'किसी बैंक या सेवा को जोड़ें ताकि Montra किसी खाते को अपडेट रख सके। यह वैकल्पिक है।',
  'integrations.loading': 'जुड़ी सेवाएँ लोड हो रही हैं…',
  'integrations.error': 'हम जुड़ी सेवाएँ लोड नहीं कर सके',
  'integrations.manualFirst.title': 'Montra बिना किसी जुड़ाव के पूरी तरह काम करता है',
  'integrations.manualFirst.body':
    'जब चाहें, लेन-देन खुद जोड़ें या स्टेटमेंट आयात करें। जुड़ाव वैकल्पिक हैं।',
  'integrations.manualFirst.never':
    'Montra कभी आपका बैंक पासवर्ड, UPI PIN, OTP या कार्ड CVV नहीं माँगता। अगर आप कोई सेवा जोड़ते हैं, तो आप उसी सेवा की अपनी साइट पर अनुमति देते हैं।',
  'integrations.importInstead': 'स्टेटमेंट आयात करें',
  'integrations.connections.title': 'आपके जुड़ाव',
  'integrations.connections.empty': 'कोई जुड़ाव नहीं',
  'integrations.connections.emptyBody':
    'आपने कुछ भी नहीं जोड़ा है। Montra में सब कुछ बिना जुड़ाव के काम करता है।',
  'integrations.connection.pending': 'अनुमति का इंतज़ार',
  'integrations.connection.connected': 'जुड़ा हुआ',
  'integrations.connection.syncing': 'सिंक हो रहा है',
  'integrations.connection.partial': 'आंशिक रूप से सिंक हुआ',
  'integrations.connection.failed': 'ध्यान देने की ज़रूरत',
  'integrations.connection.consent_expired': 'सहमति की अवधि खत्म',
  'integrations.connection.disconnected': 'अलग किया गया',
  'integrations.connection.revoked': 'अलग किया गया',
  'integrations.connection.unknownProvider': 'एक सेवा जो अब सूची में नहीं है',
  'integrations.connection.account': 'खाता:',
  'integrations.connection.consentUntil': 'सहमति इस तक:',
  'integrations.connection.consentEnded': 'सहमति खत्म हुई:',
  'integrations.connection.lastSync': 'पिछला सिंक:',
  'integrations.connection.never': 'अभी नहीं',
  'integrations.connection.expiredHelp':
    'आपकी सहमति खत्म हो गई, इसलिए सिंक रुक गया। फिर से सहमति देने के लिए दोबारा जोड़ें।',
  'integrations.connection.providerGone': 'यह सेवा अब उपलब्ध नहीं है, इसलिए यह सिंक नहीं हो सकती।',
  'integrations.connection.reconnect': 'दोबारा जोड़ें',
  'integrations.connection.startAgain': 'फिर से शुरू करें',
  'integrations.providers.title': 'सेवाएँ',
  'integrations.providers.description':
    'वे सेवाएँ जिन्हें आप जोड़ सकते हैं। हर सेवा बताती है कि वह क्या पढ़ेगी।',
  'integrations.providers.noneAvailable':
    'इनमें से कोई भी सेवा अभी जोड़ी नहीं जा सकती। हर सेवा इसकी वजह बताती है।',
  'integrations.providers.empty': 'कोई सेवा सूची में नहीं है',
  'integrations.provider.available': 'उपलब्ध',
  'integrations.provider.not_configured': 'सेट नहीं है',
  'integrations.provider.unavailable': 'उपलब्ध नहीं',
  'integrations.provider.notConfiguredHelp':
    'यह सेवा इस Montra सर्वर पर सेट नहीं है, इसलिए इसे जोड़ा नहीं जा सकता।',
  'integrations.provider.unavailableHelp': 'आप इस सेवा को अभी नहीं जोड़ सकते।',
  'integrations.provider.reads': 'पढ़ेगी: {data}',
  'integrations.provider.connect': 'जोड़ें',
  'integrations.kind.bank_data': 'बैंक डेटा',
  'integrations.kind.account_aggregator': 'अकाउंट एग्रीगेटर',
  'integrations.kind.card': 'कार्ड',
  'integrations.kind.payments': 'भुगतान',
  'integrations.data.transactions': 'लेन-देन',
  'integrations.data.balances': 'खाते की शेष राशि',
  'integrations.data.webhooks': 'तुरंत अपडेट की सूचनाएँ',
  'integrations.connect.title': '{provider} जोड़ें',
  'integrations.connect.description':
    'पढ़ें कि आप किस बात पर सहमति दे रहे हैं। आप {provider} की अपनी साइट पर अनुमति देंगे।',
  'integrations.connect.consentHeading': 'आप किस बात पर सहमति दे रहे हैं',
  'integrations.connect.purpose': 'क्यों',
  'integrations.connect.shared': 'Montra क्या पढ़ेगा',
  'integrations.connect.duration': 'कितने समय तक',
  'integrations.connect.days': {
    one: '{count} दिन, जब तक आप पहले अलग न करें',
    other: '{count} दिन, जब तक आप पहले अलग न करें',
  },
  'integrations.connect.neverTitle': 'Montra क्या कभी नहीं करता',
  'integrations.connect.neverCredentials':
    'Montra कभी आपका बैंक पासवर्ड, UPI PIN, OTP या कार्ड CVV नहीं माँगता। आप {provider} की अपनी साइट पर साइन इन करते हैं।',
  'integrations.connect.neverPayments':
    'Montra सिर्फ़ पढ़ सकता है। यह पैसे नहीं भेज सकता और न ही भुगतान कर सकता है।',
  'integrations.connect.disconnectAnyTime':
    'आप कभी भी अलग कर सकते हैं और चुन सकते हैं कि आयात की गई चीज़ें हटानी हैं या नहीं।',
  'integrations.connect.loadingAccounts': 'आपके खाते लोड हो रहे हैं…',
  'integrations.connect.noAccount.title': 'पहले एक खाता जोड़ें',
  'integrations.connect.noAccount.body':
    'आयात किए गए लेन-देन रखने के लिए Montra को एक सक्रिय खाते की ज़रूरत है।',
  'integrations.connect.noAccount.action': 'खाता जोड़ें',
  'integrations.connect.account': 'भरने के लिए Montra खाता',
  'integrations.connect.accountHelp': '{provider} से आए लेन-देन इस खाते में जोड़े जाते हैं।',
  'integrations.connect.accountPlaceholder': 'खाता चुनें',
  'integrations.connect.accountRequired': 'भरने के लिए खाता चुनें।',
  'integrations.connect.agree': {
    one: 'मैं सहमत हूँ कि Montra ऊपर बताई गई वजह से {count} दिन तक {provider} से मेरे {data} पढ़ सकता है।',
    other:
      'मैं सहमत हूँ कि Montra ऊपर बताई गई वजह से {count} दिन तक {provider} से मेरे {data} पढ़ सकता है।',
  },
  'integrations.connect.consentRequired': 'आगे बढ़ने के लिए सहमति दें।',
  'integrations.connect.continue': '{provider} पर आगे बढ़ें',
  'integrations.connect.redirecting': '{provider} खुल रहा है…',
  'integrations.connect.badRedirect':
    'सेवा के अनुमति पेज का पता सही नहीं लग रहा, इसलिए Montra ने उसे नहीं खोला। बाद में फिर से कोशिश करें।',
  'integrations.sync.action': 'अभी सिंक करें',
  'integrations.sync.started': 'सिंक शुरू हुआ',
  'integrations.sync.startedBody': 'पूरा होने पर नए लेन-देन दिखेंगे।',
  'integrations.sync.failed': 'सिंक शुरू नहीं हुआ',
  'integrations.history.title': 'सिंक का इतिहास',
  'integrations.history.show': 'सिंक का इतिहास दिखाएँ',
  'integrations.history.hide': 'सिंक का इतिहास छिपाएँ',
  'integrations.history.label': 'हाल के सिंक',
  'integrations.history.loading': 'सिंक का इतिहास लोड हो रहा है…',
  'integrations.history.error': 'हम सिंक का इतिहास लोड नहीं कर सके',
  'integrations.history.empty': 'अभी कोई सिंक नहीं।',
  'integrations.history.counts':
    'पढ़े {fetched} · जोड़े {created} · अपडेट किए {updated} · छोड़े {skipped}',
  'integrations.run.queued': 'इंतज़ार में',
  'integrations.run.running': 'चल रहा है',
  'integrations.run.succeeded': 'पूरा हुआ',
  'integrations.run.partial': 'आंशिक रूप से पूरा',
  'integrations.run.failed': 'विफल',
  'integrations.trigger.manual': 'आपने शुरू किया',
  'integrations.trigger.scheduled': 'तय समय पर',
  'integrations.trigger.webhook': 'सेवा से अपडेट',
  'integrations.trigger.backfill': 'पहला आयात',
  'integrations.errorCode.token_exchange_failed':
    'सेवा ने जुड़ना पूरा नहीं किया। फिर से जोड़ने की कोशिश करें।',
  'integrations.errorCode.consent_expired': 'आपकी सहमति की अवधि खत्म हो गई।',
  'integrations.errorCode.provider_unavailable':
    'सेवा उपलब्ध नहीं थी। Montra बाद में फिर से कोशिश करेगा।',
  'integrations.errorCode.provider_error':
    'सेवा ने एक गड़बड़ी भेजी। Montra बाद में फिर से कोशिश करेगा।',
  'integrations.errorCode.token_unreadable':
    'Montra सहेजी गई अनुमति का इस्तेमाल नहीं कर सका। इसे ठीक करने के लिए दोबारा जोड़ें।',
  'integrations.errorCode.timed_out': 'सिंक में बहुत समय लगा, इसलिए उसे रोक दिया गया।',
  'integrations.errorCode.other': 'पिछला सिंक पूरा नहीं हुआ।',
  'integrations.disconnect.action': 'अलग करें',
  'integrations.disconnect.title': '{provider} को अलग करें?',
  'integrations.disconnect.body':
    'Montra सिंक रोक देगा, सहेजी गई अनुमति हटा देगा और {provider} से उसे रद्द करने को कहेगा। आपकी सहमति अभी खत्म हो जाएगी।',
  'integrations.disconnect.deleteData': 'इस जुड़ाव से आयात किए गए लेन-देन भी हटाएँ',
  'integrations.disconnect.deleteDataHelp':
    'वे आपके खाते और उसकी शेष राशि से हटा दिए जाते हैं। आपके खुद जोड़े गए लेन-देन बने रहते हैं।',
  'integrations.disconnect.confirm': 'अलग करें',
  'integrations.disconnect.done': '{provider} से अलग किया गया',
  'integrations.disconnect.kept': 'पहले से आयात किए गए लेन-देन आपके खाते में बने रहते हैं।',
  'integrations.disconnect.deletedCount': {
    one: '{count} आयात किया गया लेन-देन हटाया गया।',
    other: '{count} आयात किए गए लेन-देन हटाए गए।',
  },
  'integrations.disconnect.dataAction': 'आयात किए गए लेन-देन हटाएँ',
  'integrations.disconnect.dataTitle': 'आयात किए गए लेन-देन हटाएँ?',
  'integrations.disconnect.dataBody':
    'इससे वे लेन-देन हट जाएँगे जो इस जुड़ाव ने {provider} से आयात किए थे।',
  'integrations.disconnect.dataConfirm': 'लेन-देन हटाएँ',
  'integrations.disconnect.dataDeleted': 'आयात किए गए लेन-देन हटा दिए गए',
  'integrations.error.consentExpired':
    'इस जुड़ाव के लिए आपकी सहमति की अवधि खत्म हो गई। इसे नया करने के लिए दोबारा जोड़ें।',
  'integrations.error.reconnect': 'सिंक करने से पहले फिर से जोड़ें।',
  'integrations.error.accountInactive':
    'कोई सक्रिय खाता चुनें। संग्रहित और बंद खाते भरे नहीं जा सकते।',
  'integrations.error.notAvailable':
    'यह सेवा उपलब्ध नहीं है। इसकी जगह लेन-देन खुद जोड़ें या स्टेटमेंट आयात करें।',
  'integrations.error.noLongerAvailable': 'यह सेवा अब उपलब्ध नहीं है।',
  'integrations.error.providerFailed':
    'सेवा ने जुड़ाव पूरा नहीं किया, इसलिए कुछ भी सहेजा नहीं गया। जुड़ी सेवाओं से फिर से कोशिश करें।',
  'integrations.error.requestExpired':
    'इस जुड़ाव अनुरोध की समय-सीमा खत्म हो गई या इसका पहले ही इस्तेमाल हो चुका है। जुड़ी सेवाओं से फिर से शुरू करें।',
  'integrations.error.syncRunning': 'एक सिंक पहले से चल रहा है। उसके पूरा होने का इंतज़ार करें।',
  'integrations.error.connectionGone': 'यह जुड़ाव अब मौजूद नहीं है।',
  'integrations.error.chooseAccount': 'अपना कोई एक खाता चुनें।',
  'integrations.error.consentNeeded': 'जोड़ने के लिए सहमति पढ़ें और स्वीकार करें।',
  'integrations.callback.title': 'आपका जुड़ाव पूरा हो रहा है',
  'integrations.callback.theProvider': 'सेवा',
  'integrations.callback.pending': '{provider} के साथ जुड़ाव पूरा हो रहा है…',
  'integrations.callback.back': 'जुड़ी सेवाओं पर वापस जाएँ',
  'integrations.callback.success.title': '{provider} से जुड़ गया',
  'integrations.callback.success.body':
    'Montra अभी आपके लेन-देन आयात कर रहा है। इसमें कुछ मिनट लग सकते हैं, और आप इसे सिंक के इतिहास में देख सकते हैं।',
  'integrations.callback.declined.title': 'आपने जुड़ाव की अनुमति नहीं दी',
  'integrations.callback.declined.body':
    '{provider} से Montra के साथ कुछ भी साझा नहीं किया गया। आप जुड़ी सेवाओं से फिर से कोशिश कर सकते हैं।',
  'integrations.callback.missing.title': 'इस पेज पर सेवा का जवाब नहीं है',
  'integrations.callback.missing.body': 'जुड़ी सेवाओं से फिर से जोड़ना शुरू करें।',
  'integrations.callback.expired.title':
    'इस जुड़ाव अनुरोध की समय-सीमा खत्म हो गई या इसका पहले ही इस्तेमाल हो चुका है',
  'integrations.callback.expired.body':
    'एक जुड़ाव अनुरोध 30 मिनट तक, एक ही बार काम करता है। जुड़ी सेवाओं से फिर से शुरू करें।',
  'integrations.callback.failed.title': 'जुड़ाव पूरा नहीं हुआ',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
