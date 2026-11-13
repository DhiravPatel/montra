import type { NamespaceTranslation } from '../../types';
import type en from '../en/calendar';

/** Hindi `calendar` messages; missing keys fall back to English. */
const messages = {
  'calendar.title': 'आने वाले',
  'calendar.description':
    'बिल, आवर्ती पैसा, सब्सक्रिप्शन का नवीनीकरण और लक्ष्य की तारीखें एक ही जगह।',
  'calendar.loading': 'आने वाली चीज़ें लोड हो रही हैं…',
  'calendar.error': 'हम आपका कैलेंडर लोड नहीं कर सके',
  'calendar.empty.title': '{month} के लिए कुछ तय नहीं है',
  'calendar.empty.body':
    'अपने बिल और नियमित आय या खर्च जोड़ें, ताकि देय होने से पहले वे यहाँ दिखें।',
  'calendar.previous': 'पिछला महीना',
  'calendar.next': 'अगला महीना',
  'calendar.thisMonth': 'यह महीना',
  'calendar.showing': '{month} दिखाया जा रहा है',
  'calendar.today': 'आज',
  'calendar.projectedNote': 'अनुमानित आइटम शेड्यूल से निकाले गए हैं और अभी बने नहीं हैं।',
  'calendar.kind.recurring': 'आवर्ती',
  'calendar.kind.bill': 'बिल',
  'calendar.kind.group_expense': 'साझा खर्च',
  'calendar.kind.subscription_renewal': 'सब्सक्रिप्शन नवीनीकरण',
  'calendar.kind.trial_end': 'फ़्री ट्रायल खत्म',
  'calendar.kind.goal_target': 'लक्ष्य की तारीख',
  'calendar.status.projected': 'अनुमानित',
  'calendar.status.expected': 'अपेक्षित',
  'calendar.status.target': 'लक्ष्य',
  'calendar.movedFrom': '{date} से आगे बढ़ाया गया',
  'calendar.commitments.title': 'नियमित प्रतिबद्धताएँ',
  'calendar.commitments.description':
    'आपके चालू शेड्यूल हर महीने कितने होते हैं, हर मुद्रा के हिसाब से।',
  'calendar.commitments.loading': 'प्रतिबद्धताएँ लोड हो रही हैं…',
  'calendar.commitments.error': 'हम आपकी नियमित प्रतिबद्धताएँ लोड नहीं कर सके',
  'calendar.commitments.empty': 'अभी कोई नियमित प्रतिबद्धता नहीं।',
  'calendar.commitments.kind.expense': 'आवर्ती खर्च',
  'calendar.commitments.kind.income': 'आवर्ती आय',
  'calendar.commitments.kind.transfer': 'आवर्ती ट्रांसफ़र',
  'calendar.commitments.kind.bill': 'बिल',
  'calendar.commitments.kind.subscription': 'सब्सक्रिप्शन',
  'calendar.commitments.kind.group_expense': 'साझा खर्च',
  'calendar.commitments.count': { one: '{count} शेड्यूल', other: '{count} शेड्यूल' },
  'calendar.commitments.monthly': 'हर महीने',
  'calendar.commitments.next30': 'अगले 30 दिन',
  'calendar.commitments.variable': {
    one: '{count} शेड्यूल की राशि बदलती है, इसलिए वह शामिल नहीं है।',
    other: '{count} शेड्यूल की राशि बदलती है, इसलिए वे शामिल नहीं हैं।',
  },
  'calendar.commitments.note.fixed_amounts_expectations':
    'केवल तय राशियाँ गिनी गई हैं। बिल और आय अनुमान हैं, अभी दर्ज पैसा नहीं।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
