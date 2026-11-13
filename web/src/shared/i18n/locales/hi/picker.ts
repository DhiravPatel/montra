import type { NamespaceTranslation } from '../../types';
import type en from '../en/picker';

/** Hindi `picker` messages; missing keys fall back to English. */
const messages = {
  'picker.legend': 'एक लेन-देन चुनें',
  'picker.suggested': 'सुझाए गए मिलान',
  'picker.suggestionsLoading': 'मिलते-जुलते लेन-देन ढूँढ रहे हैं…',
  'picker.searchHeading': 'आपके लेन-देन',
  'picker.search': 'विवरण, नोट या व्यापारी खोजें',
  'picker.loading': 'लेन-देन लोड हो रहे हैं…',
  'picker.error': 'हम आपके लेन-देन लोड नहीं कर सके',
  'picker.noMatches': 'आपकी खोज से कोई लेन-देन मेल नहीं खाता।',
  'picker.empty': 'इस अवधि के लिए दिखाने को कोई लेन-देन नहीं।',
  'picker.resultCount': { one: '{count} लेन-देन मिला', other: '{count} लेन-देन मिले' },
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
