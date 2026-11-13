import type { NamespaceTranslation } from '../../types';
import type en from '../en/charts';

/** Hindi `charts` messages; missing keys fall back to English. */
const messages = {
  // Charts
  'charts.showTable': 'तालिका के रूप में दिखाएँ',
  'charts.showChart': 'चार्ट के रूप में दिखाएँ',
  'charts.pointTitle': '{series}, {label}: {value}',
  'charts.date': 'तारीख',
  'charts.period': 'अवधि',
  'charts.seriesValue': '{series}: {value}',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;
