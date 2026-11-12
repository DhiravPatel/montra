import type { components } from '@/shared/api/schema';

/** Support types generated from the OpenAPI contract (never hand-written). */
type Schemas = components['schemas'];

/** A request as its author sees it (GET /support/requests). */
export type SupportRequest = Schemas['RequestDTO'];
/** A request as support staff see it (GET /support/queue). */
export type StaffRequest = Schemas['StaffRequestDTO'];
export type SupportRequestInput = Schemas['RequestInput'];
/** The signed-out contact form (POST /support/contact). */
export type ContactInput = Schemas['ContactInput'];
export type ContactResult = Schemas['ContactResult'];
/** One message in a request's thread (the requester and Montra staff). */
export type SupportMessage = Schemas['MessageDTO'];
export type SupportMessageInput = Schemas['MessageInput'];

export type RequestKind = SupportRequest['kind'];
export type RequestStatus = SupportRequest['status'];
/** The contact form offers every kind except feedback. */
export type ContactKind = ContactInput['kind'];
/** Statuses staff can move a request to (never back to open). */
export type StaffStatus = Schemas['StatusInput']['status'];

/** Server-side queue filters; omitted means "all". */
export interface QueueFilters {
  status?: RequestStatus;
  kind?: RequestKind;
}
