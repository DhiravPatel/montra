import type { StaffRequest, SupportMessage, SupportRequest } from '@/features/support/types';

/** Support requests shaped like the API's (references are the ID's first 8 characters, upper case). */
export const REQUEST_ID = '6b1f2e3d-4c5b-4a69-8877-665544332211';
export const REQUEST_ID_2 = '9c8d7e6f-5a4b-4c3d-8e2f-1a0b9c8d7e6f';
export const SECURITY_REQUEST_ID = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';

export function referenceOf(id: string): string {
  return id.slice(0, 8).toUpperCase();
}

export function makeSupportRequest(overrides: Partial<SupportRequest> = {}): SupportRequest {
  const id = overrides.id ?? REQUEST_ID;
  return {
    id,
    reference: referenceOf(id),
    kind: 'bug',
    subject: 'Export button spins',
    body: 'The CSV export spins forever.\nIt never finishes.',
    status: 'open',
    message_count: 0,
    created_at: '2026-11-04T09:00:00Z',
    updated_at: '2026-11-04T09:00:00Z',
    ...overrides,
  };
}

export function makeStaffRequest(overrides: Partial<StaffRequest> = {}): StaffRequest {
  const base = makeSupportRequest(overrides);
  return {
    ...base,
    contact_email: 'asha@example.com',
    signed_in: true,
    client_kind: 'web',
    app_version: '0.1.0',
    ...overrides,
  };
}

export const MESSAGE_ID = '0d1e2f3a-4b5c-4d6e-8f70-819203a4b5c6';
export const STAFF_MESSAGE_ID = '1e2f3a4b-5c6d-4e7f-8091-a2b3c4d5e6f7';

/** A thread message as GET /support/requests/{id}/messages returns it (live shape). */
export function makeSupportMessage(overrides: Partial<SupportMessage> = {}): SupportMessage {
  return {
    id: MESSAGE_ID,
    request_id: REQUEST_ID,
    author_role: 'requester',
    mine: true,
    body: 'It happens with CSV only.',
    created_at: '2026-11-04T09:30:00Z',
    ...overrides,
  };
}

/** A reply from Montra support, as the requester sees it. */
export function makeStaffReply(overrides: Partial<SupportMessage> = {}): SupportMessage {
  return makeSupportMessage({
    id: STAFF_MESSAGE_ID,
    author_role: 'staff',
    mine: false,
    body: 'Thanks. We found the problem and fixed it.',
    created_at: '2026-11-04T11:00:00Z',
    ...overrides,
  });
}

/** The daily cap answer of POST /support/requests and …/messages (live shape). */
export function dailyCapDetail(kind: 'support requests' | 'support messages') {
  return {
    message: `You can send up to 10 ${kind} a day. Please try again later.`,
    code: 'daily_cap',
    params: { kind, limit: '10', window_hours: '24' },
  };
}
