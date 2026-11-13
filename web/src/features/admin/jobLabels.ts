import type { Tone } from '@/shared/components/tones';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import type { JobAttempt, JobStatus } from './types';

/** Job statuses in filter order; typed against the contract, so a new status needs a label. */
export const JOB_STATUSES = [
  'queued',
  'running',
  'succeeded',
  'failed',
  'dead',
  'cancelled',
] as const satisfies readonly JobStatus[];

type MissingStatuses = Exclude<JobStatus, (typeof JOB_STATUSES)[number]>;
/** Compile-time check: every status in the contract is listed above. */
export const jobStatusesAreListed: [MissingStatuses] extends [never] ? true : MissingStatuses =
  true;

export function isJobStatus(value: unknown): value is JobStatus {
  return typeof value === 'string' && (JOB_STATUSES as readonly string[]).includes(value);
}

export const jobStatusLabel: Readonly<Record<JobStatus, MessageKey>> = {
  queued: 'adminJobs.status.queued',
  running: 'adminJobs.status.running',
  succeeded: 'adminJobs.status.succeeded',
  failed: 'adminJobs.status.failed',
  dead: 'adminJobs.status.dead',
  cancelled: 'adminJobs.status.cancelled',
};

export const jobStatusTone: Readonly<Record<JobStatus, Tone>> = {
  queued: 'neutral',
  running: 'info',
  succeeded: 'success',
  failed: 'warning',
  dead: 'danger',
  cancelled: 'neutral',
};

type Outcome = NonNullable<JobAttempt['outcome']> | 'running';

export const attemptOutcomeLabel: Readonly<Record<Outcome, MessageKey>> = {
  running: 'adminJobs.outcome.running',
  succeeded: 'adminJobs.outcome.succeeded',
  retry: 'adminJobs.outcome.retry',
  failed: 'adminJobs.outcome.failed',
  dead: 'adminJobs.outcome.dead',
  cancelled: 'adminJobs.outcome.cancelled',
  lease_expired: 'adminJobs.outcome.lease_expired',
};

const knownErrorCodes: Readonly<Record<string, MessageKey>> = {
  provider_circuit_open: 'adminJobs.errorCode.provider_circuit_open',
  timeout: 'adminJobs.errorCode.timeout',
  email_send_failed: 'adminJobs.errorCode.email_send_failed',
};

/** A failure code in words when this client knows it; null otherwise (the code alone is shown). */
export function jobErrorText(code: string | undefined, t: Translate): string | null {
  if (!code) return null;
  const key = knownErrorCodes[code];
  return key ? t(key) : null;
}
