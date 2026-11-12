import type {
  Consent,
  Deletion,
  ExportJob,
  FileAccess,
  Legal,
  Limits,
} from '@/features/privacy/types';

/** Privacy fixtures shaped like the live API's answers (checked against the dev API). */
export const EXPORT_ID = '79d28bfa-fa2a-4ba3-8c3d-c47df36612c6';
export const EXPORT_FILE_ID = '676b925a-4a6f-4dc9-a930-3aa262dd4d36';
export const DELETION_ID = '15626cab-f04d-4d03-b1c8-ddc01638ce40';

export function makeConsent(overrides: Partial<Consent> = {}): Consent {
  return {
    id: 'c5aba789-4ee9-46fa-84e3-d861de0eb78a',
    consent_type: 'location',
    version: '2026-11-01',
    granted_at: '2026-11-02T08:00:00Z',
    ...overrides,
  };
}

/** Terms and privacy notice, accepted at sign-up. */
export function requiredConsents(): Consent[] {
  return [
    makeConsent({
      id: 'bf38d1cd-21de-44c8-9b49-398977ee2c86',
      consent_type: 'privacy_policy',
      granted_at: '2026-10-01T08:30:00Z',
    }),
    makeConsent({
      id: 'c0ffee00-21de-44c8-9b49-398977ee2c86',
      consent_type: 'terms',
      granted_at: '2026-10-01T08:30:00Z',
    }),
  ];
}

export function makeExportJob(overrides: Partial<ExportJob> = {}): ExportJob {
  return {
    id: EXPORT_ID,
    status: 'queued',
    format: 'json_zip',
    requested_at: '2026-11-05T05:58:00Z',
    ...overrides,
  };
}

export function completedExport(overrides: Partial<ExportJob> = {}): ExportJob {
  return makeExportJob({
    status: 'completed',
    file_id: EXPORT_FILE_ID,
    completed_at: '2026-11-05T05:59:00Z',
    expires_at: '2026-11-12T05:59:00Z',
    ...overrides,
  });
}

export function makeExportAccess(overrides: Partial<FileAccess> = {}): FileAccess {
  return {
    url: `http://localhost:8080/api/v1/files/${EXPORT_FILE_ID}/content?exp=1793872344&sig=AK8OhgDQxKCHKmA3JP6Thp-EMtFJjUdRtnbOfEgYLxI&sub=7c9e6679-7425-40de-944b-e07fc1f90ae7`,
    expires_at: '2026-11-05T06:05:00Z',
    content_type: 'application/zip',
    filename: 'montra-export-20261105.zip',
    ...overrides,
  };
}

/** The API's disclosure text (English only), as GET /me/deletion-request returns it. */
export const CONSEQUENCES = [
  'You will be signed out of every device and all active integrations will be revoked.',
  'Your accounts, transactions, budgets, goals, subscriptions, receipts, imports, reports and AI history will be permanently deleted.',
  'Uploaded documents will be removed from storage.',
  'Your profile will be removed; community posts and comments will be anonymized.',
  'This cannot be undone after the scheduled date.',
];

export const RETAINED = [
  'Shared group expense shares and settlements remain so other members\' balances stay correct; your name is replaced with "Deleted member".',
  'Security and audit records are kept in anonymized form for the documented retention period to meet legal and fraud-prevention obligations.',
];

export const CONSEQUENCE_CODES = [
  'signed_out_and_integrations_revoked',
  'personal_records_deleted',
  'documents_removed',
  'profile_removed_posts_anonymized',
  'irreversible_after_date',
];

export const RETAINED_CODES = [
  'shared_group_records_anonymized',
  'security_audit_records_retained',
];

export const GROUP_IMPACT_TEXT =
  'Ownership of "Flat 4B" will transfer to its longest-standing admin or member.';

export function makeDeletion(overrides: Partial<Deletion> = {}): Deletion {
  return {
    status: 'none',
    consequences: CONSEQUENCES,
    consequence_codes: CONSEQUENCE_CODES,
    retained: RETAINED,
    retained_codes: RETAINED_CODES,
    group_impact: [GROUP_IMPACT_TEXT],
    group_impact_details: [
      {
        code: 'ownership_transfer',
        params: {
          group_id: '520cd8ca-92b7-432e-9096-f9542af0ce8c',
          group_name: 'Flat 4B',
          outcome: 'ownership_transfer',
        },
        text: GROUP_IMPACT_TEXT,
      },
    ],
    ...overrides,
  };
}

export function scheduledDeletion(overrides: Partial<Deletion> = {}): Deletion {
  return makeDeletion({
    id: DELETION_ID,
    status: 'scheduled',
    requested_at: '2026-11-05T06:00:00Z',
    scheduled_for: '2026-11-12T06:00:00Z',
    ...overrides,
  });
}

export function makeLimits(overrides: Partial<Limits> = {}): Limits {
  return {
    storage_quota_bytes: 2_147_483_648,
    storage_used_bytes: 536_870_912,
    max_upload_bytes: 20_971_520,
    import_max_rows: 20_000,
    max_open_recurring_rules: 500,
    max_open_bills: 200,
    max_open_subscriptions: 500,
    max_open_goals: 200,
    support_requests_per_day: 10,
    rate_limits: [
      { policy: 'default', per_minute: 600, burst: 60 },
      { policy: 'write', per_minute: 240, burst: 40 },
      { policy: 'upload', per_minute: 20, burst: 10 },
      { policy: 'export', per_minute: 2, burst: 5 },
      { policy: 'social', per_minute: 30, burst: 15 },
      { policy: 'auth', per_minute: 10, burst: 10 },
    ],
    deletion_grace_days: 7,
    export_download_days: 7,
    ai_requests_per_day: 0,
    note_code: 'fair_use_same_for_everyone',
    note: 'Every feature is free for everyone. These limits keep Montra fast and affordable to run; they are the same for all users.',
    ...overrides,
  };
}

/** GET /legal as the live API answers it (every consent type at 2026-11-01). */
export function makeLegal(overrides: Partial<Legal> = {}): Legal {
  const types = [
    'terms',
    'privacy_policy',
    'ai_processing',
    'ai_receipt_processing',
    'marketing_email',
    'product_analytics',
    'location',
    'contacts_discovery',
    'push_notifications',
  ] as const;
  return {
    terms_version: '2026-11-01',
    privacy_version: '2026-11-01',
    consents: types.map((type) => ({
      type,
      version: '2026-11-01',
      required: type === 'terms' || type === 'privacy_policy',
    })),
    ...overrides,
  };
}
