import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import type {
  ContactInput,
  ContactResult,
  QueueFilters,
  StaffRequest,
  StaffStatus,
  SupportMessage,
  SupportMessageInput,
  SupportRequest,
  SupportRequestInput,
} from './types';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/**
 * Help requests, bug reports, security and privacy reports and feedback
 * (spec §4.21). Text containing card numbers, PINs, OTPs or passwords is
 * refused by the API; the forms check for it before sending as well.
 */
export const supportApi = {
  /** The caller's requests, newest first (at most 100). */
  list: (signal?: AbortSignal): Promise<SupportRequest[]> =>
    apiData(api.GET('/support/requests', signalOption(signal))),
  get: (id: string, signal?: AbortSignal): Promise<SupportRequest> =>
    apiData(
      api.GET('/support/requests/{id}', { params: { path: { id } }, ...signalOption(signal) }),
    ),
  create: (body: SupportRequestInput): Promise<SupportRequest> =>
    apiData(api.POST('/support/requests', { body })),
  /** The request's thread, oldest first (the requester and Montra staff can read it). */
  messages: (id: string, signal?: AbortSignal): Promise<SupportMessage[]> =>
    apiData(
      api.GET('/support/requests/{id}/messages', {
        params: { path: { id } },
        ...signalOption(signal),
      }),
    ),
  /** Adds a message (staff replies notify the requester; a closed request answers 422). */
  postMessage: (id: string, body: SupportMessageInput): Promise<SupportMessage> =>
    apiData(api.POST('/support/requests/{id}/messages', { params: { path: { id } }, body })),
  /** Signed-out contact form; replies go to `contact_email`. */
  contact: (body: ContactInput): Promise<ContactResult> =>
    apiData(api.POST('/support/contact', { body })),
  /** Staff queue: security and privacy first, as the API orders it (at most 200). */
  queue: (filters: QueueFilters, signal?: AbortSignal): Promise<StaffRequest[]> =>
    apiData(
      api.GET('/support/queue', {
        params: {
          query: {
            ...(filters.status ? { status: filters.status } : {}),
            ...(filters.kind ? { kind: filters.kind } : {}),
          },
        },
        ...signalOption(signal),
      }),
    ),
  /** Staff status change (audited by the API). */
  setStatus: (id: string, status: StaffStatus): Promise<StaffRequest> =>
    apiData(api.PATCH('/support/queue/{id}', { params: { path: { id } }, body: { status } })),
};
