import type { NamespaceTranslation } from '../../types';
import type en from '../en/reauth';

/** Hindi `reauth` messages; missing keys fall back to English. */
const messages = {
  'reauth.title': 'पुष्टि करें कि यह आप ही हैं',
  'reauth.description': 'आपकी सुरक्षा के लिए, जारी रखने हेतु अपना पासवर्ड दर्ज करें।',
  'reauth.descriptionWithCode':
    'आपकी सुरक्षा के लिए, जारी रखने हेतु अपना पासवर्ड और ऑथेंटिकेटर ऐप का कोड (या कोई रिकवरी कोड) दर्ज करें।',
  'reauth.password': 'पासवर्ड',
  'reauth.code': 'ऑथेंटिकेटर कोड',
  'reauth.codeHelp': 'आपके ऑथेंटिकेटर ऐप का 6 अंकों का कोड।',
  'reauth.confirm': 'पुष्टि करें',
  'reauth.wrongPassword': 'यह पासवर्ड गलत है।',
  'reauth.wrongCode': 'यह कोड काम नहीं किया। नए कोड का इंतज़ार करें और फिर से प्रयास करें।',
  'reauth.recoveryHelp':
    'हर रिकवरी कोड एक ही बार काम करता है, इसलिए यहाँ इस्तेमाल करने पर वह खत्म हो जाएगा।',
  'reauth.wrongRecovery': 'यह रिकवरी कोड काम नहीं किया या पहले ही इस्तेमाल हो चुका है।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
