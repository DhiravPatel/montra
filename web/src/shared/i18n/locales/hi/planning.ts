import type { NamespaceTranslation } from '../../types';
import type en from '../en/planning';

/** Hindi `planning` messages; missing keys fall back to English. */
const messages = {
  // Round 2: planning (calendar, bills, recurring items, schedules)
  'planning.subnav.label': 'योजना के भाग',
  'planning.subnav.upcoming': 'आने वाले',
  'planning.subnav.bills': 'बिल',
  'planning.subnav.recurring': 'आवर्ती',
  'planning.rule.bill_inactive': 'यह बिल संग्रहित है। भुगतान दर्ज करने से पहले इसे वापस लाएँ।',
  'planning.rule.transfer_needs_two_accounts': 'आवर्ती ट्रांसफ़र के लिए दो अलग-अलग खाते चाहिए।',
  'planning.rule.cross_currency_transfer_not_auto_posted':
    'अलग-अलग मुद्राओं के बीच ट्रांसफ़र में हर बार मिली राशि चाहिए, इसलिए ये अपने-आप दर्ज नहीं हो सकते।',
  'planning.rule.bills_not_auto_posted':
    'बिल असली भुगतान जोड़कर या दर्ज करके पक्के होते हैं, अपने-आप नहीं।',
  'planning.rule.auto_post_needs_amount_and_account':
    'अपने-आप दर्ज करने के लिए तय राशि और एक खाता चाहिए।',
  'planning.rule.use_bill_screen': 'यह शेड्यूल एक बिल का है। इसे बिल के पेज से बदलें।',
  'planning.rule.postpone_needs_later_open_occurrence':
    'बाद की तारीख चुनें। केवल आने वाले या बकाया आइटम आगे बढ़ाए जा सकते हैं।',
  'planning.rule.transaction_voided': 'वह लेन-देन हटा दिया गया था, इसलिए उसे जोड़ा नहीं जा सकता।',
  'planning.rule.transfer_missing_destination':
    'इस ट्रांसफ़र का कोई पाने वाला खाता नहीं है। पहले शेड्यूल बदलें।',
  'planning.errors.alreadyHandled':
    'यह पहले ही निपटाया या बदला जा चुका है। हमने इसे रीफ़्रेश कर दिया है, देखें और ज़रूरत हो तो फिर से कोशिश करें।',
  'planning.errors.alreadyLinked':
    'वह लेन-देन पहले से किसी दूसरे भुगतान से जुड़ा है। कोई दूसरा चुनें।',
  'planning.errors.changedElsewhere':
    'इसे कहीं और बदला गया। हमने नया संस्करण लोड कर दिया है; फिर से कोशिश करें।',
  'planning.conflict.schedule_ended':
    'यह शेड्यूल खत्म हो चुका है। फिर से शुरू करने से पहले इसे बदलकर नई तारीखें तय करें।',
  'planning.conflict.rule_in_use':
    'यह आइटम इस्तेमाल में है, इसलिए हटाया नहीं जा सकता। इसके बजाय इसे बंद करें; इसका इतिहास बना रहेगा।',
  'planning.conflict.no_open_occurrence':
    'अभी यहाँ कुछ भी बकाया या आने वाला नहीं है। हमने इसे रीफ़्रेश कर दिया है।',
  'planning.conflict.occurrence_not_open':
    'इस भुगतान को पहले ही चुकाया या छोड़ा जा चुका है। हमने इसे रीफ़्रेश कर दिया है, फिर से कोशिश करने से पहले देख लें।',
  'planning.conflict.occurrence_not_skipped':
    'केवल छोड़े गए आइटम फिर से देय किए जा सकते हैं। हमने इसे रीफ़्रेश कर दिया है।',
  'planning.conflict.occurrence_already_handled':
    'यह पहले ही दर्ज, जोड़ा या छोड़ा जा चुका है। हमने इसे रीफ़्रेश कर दिया है, फिर से कोशिश करने से पहले देख लें।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
