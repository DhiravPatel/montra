import type { components } from '@/shared/api/schema';

/** Report types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

export type Report = Schemas['ReportDTO'];
export type ReportStatus = Report['status'];
export type ReportInput = Schemas['ReportInput'];
export type ReportType = ReportInput['report_type'];
export type ReportFormat = ReportInput['format'];
export type ReportFilters = Schemas['Filters'];
export type ReportSchedule = Schemas['ScheduleDTO'];
export type ScheduleInput = Schemas['ScheduleInput'];
/** Partial edit of a schedule (only the fields sent change; `enabled` pauses or resumes). */
export type SchedulePatch = Schemas['SchedulePatch'];
/** The dates a report covers, resolved when it was requested. */
export type ReportWindow = Schemas['Window'];
export type ScheduleCadence = ScheduleInput['cadence'];
/** A short-lived signed link to a ready report file. */
export type FileAccess = Schemas['Access'];
export type Limits = Schemas['Limits'];

/** GET /reports with the server's clock (for "how long has this been running"). */
export interface ReportList {
  reports: Report[];
  /** When the API answered (RFC 3339); compared with `requested_at`, never with the device clock. */
  serverTime: string;
}
