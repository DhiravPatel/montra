import type { PlatformActionFilters, QueueStatus } from './types';

/** Query keys of the moderation screens (no finance data). */
export const moderationKeys = {
  all: ['moderation'] as const,
  /** Actions that affected you (GET /me/moderation). */
  mine: () => ['moderation', 'me'] as const,
  /** Appeals you made (GET /me/moderation/appeals). */
  myAppeals: () => ['moderation', 'me', 'appeals'] as const,
  /** Reports you filed (GET /content-reports). */
  myReports: () => ['moderation', 'my-reports'] as const,
  /** Every staff list (prefix). */
  staff: () => ['moderation', 'staff'] as const,
  staffReportLists: () => ['moderation', 'staff', 'reports'] as const,
  staffReports: (status: QueueStatus) => ['moderation', 'staff', 'reports', status] as const,
  staffAppeals: () => ['moderation', 'staff', 'appeals'] as const,
  /** Platform actions (prefix of every filter). */
  staffActionLists: () => ['moderation', 'staff', 'actions'] as const,
  staffActions: (filters: PlatformActionFilters) =>
    ['moderation', 'staff', 'actions', filters] as const,
};
