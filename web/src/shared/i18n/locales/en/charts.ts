import type { Message } from '../../types';

/** English `charts` messages (source of truth for their keys). */
const messages = {
  // Charts
  'charts.showTable': 'Show as table',
  'charts.showChart': 'Show as chart',
  'charts.pointTitle': '{series}, {label}: {value}',
  'charts.date': 'Date',
  'charts.period': 'Period',
  'charts.seriesValue': '{series}: {value}',
} as const satisfies Record<string, Message>;

export default messages;
