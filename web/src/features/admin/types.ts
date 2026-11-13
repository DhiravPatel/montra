import type { components } from '@/shared/api/schema';

/** Admin dashboard types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

/** Aggregate platform usage for a window: counts only, never people or records. */
export type Usage = Schemas['Usage'];
export type DailyUsage = Schemas['DailyUsage'];

/** Background jobs as operators see them: status and codes, never payloads or people. */
export type Job = Schemas['JobDTO'];
export type JobStatus = Job['status'];
export type JobAttempt = Schemas['JobAttemptDTO'];
export type JobDetail = Schemas['JobDetail'];

/** GET /admin/jobs filters (UTC creation dates, inclusive). */
export interface JobFilters {
  status: JobStatus | '';
  type: string;
  from: string;
  to: string;
}
