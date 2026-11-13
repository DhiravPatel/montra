import type { NamespaceTranslation } from '../../types';
import type en from '../en/privacy';

/** Hindi `privacy` messages; missing keys fall back to English. */
const messages = {
  'privacy.collect.finance':
    'आपके जोड़े गए पैसे के रिकॉर्ड: खाते (एक नाम और, अगर आप चाहें, आखिरी 2–4 अंक), भुगतान के तरीके, लेन-देन, श्रेणियाँ, टैग और दुकानें, साथ ही उनमें किए गए बदलावों का इतिहास। Montra कभी पूरा कार्ड या खाता नंबर, PIN या बैंक पासवर्ड नहीं माँगता।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
