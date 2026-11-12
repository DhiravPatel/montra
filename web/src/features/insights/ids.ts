/** DOM ids used to move focus after an action (insight IDs are opaque UUIDs). */
export function insightTitleId(id: string): string {
  return `insight-${id}-title`;
}

export function insightThanksId(id: string): string {
  return `insight-${id}-thanks`;
}

export const INSIGHTS_LIST_HEADING_ID = 'insights-list-heading';
export const MUTED_TYPES_HEADING_ID = 'insights-muted-heading';
