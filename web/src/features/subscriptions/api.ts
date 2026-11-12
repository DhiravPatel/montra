import { useQuery } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { financeKeys } from '@/shared/finance/keys';
import type {
  ChecklistItemPatch,
  DetectionCandidate,
  DetectionConfirmInput,
  Subscription,
  SubscriptionActionInput,
  SubscriptionDetail,
  SubscriptionInput,
  SubscriptionPatch,
  SubscriptionPaymentCandidate,
  SubscriptionPaymentInput,
  SubscriptionStatus,
  SubscriptionSummary,
  Transaction,
} from '@/shared/finance/types';

/** `''` = everything except cancelled (the API default); `all` includes cancelled. */
export type SubscriptionListStatus = SubscriptionStatus | 'all' | '';
export type DetectionStatus = DetectionCandidate['status'];

/** Lifecycle endpoints (`POST /subscriptions/{id}/<action>`). */
export type SubscriptionAction =
  'verify' | 'pause' | 'resume' | 'cancellation-started' | 'cancelled' | 'reactivate';

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/** Subscriptions and detection review (spec: subscriptions). Never cancels anything itself. */
export const subscriptionsApi = {
  list: (status: SubscriptionListStatus, signal?: AbortSignal): Promise<Subscription[]> =>
    apiData(
      api.GET('/subscriptions', {
        params: { query: status ? { status } : {} },
        ...signalOption(signal),
      }),
    ),
  summary: (signal?: AbortSignal): Promise<SubscriptionSummary> =>
    apiData(api.GET('/subscriptions/summary', signalOption(signal))),
  get: (id: string, signal?: AbortSignal): Promise<SubscriptionDetail> =>
    apiData(api.GET('/subscriptions/{id}', { params: { path: { id } }, ...signalOption(signal) })),
  /** A retry with the same key replays the first result instead of adding it twice. */
  create: (body: SubscriptionInput, key: string): Promise<SubscriptionDetail> =>
    apiData(api.POST('/subscriptions', { params: { header: { 'Idempotency-Key': key } }, body })),
  /** Only the fields sent change (`clear` removes links); price changes stay in the history. */
  update: (id: string, body: SubscriptionPatch): Promise<SubscriptionDetail> =>
    apiData(api.PATCH('/subscriptions/{id}', { params: { path: { id } }, body })),
  /** `version` is the one on screen: a concurrent change answers 409 VERSION_CONFLICT. */
  act: (
    id: string,
    action: SubscriptionAction,
    version: number,
    body: SubscriptionActionInput = {},
  ): Promise<SubscriptionDetail> => {
    const options = { params: { path: { id }, query: { version } }, body };
    switch (action) {
      case 'verify':
        return apiData(api.POST('/subscriptions/{id}/verify', options));
      case 'pause':
        return apiData(api.POST('/subscriptions/{id}/pause', options));
      case 'resume':
        return apiData(api.POST('/subscriptions/{id}/resume', options));
      case 'cancellation-started':
        return apiData(api.POST('/subscriptions/{id}/cancellation-started', options));
      case 'cancelled':
        return apiData(api.POST('/subscriptions/{id}/cancelled', options));
      case 'reactivate':
        return apiData(api.POST('/subscriptions/{id}/reactivate', options));
    }
  },
  /** Ticks or unticks one cancellation step (`index` from 0). */
  updateChecklistItem: (
    id: string,
    index: number,
    body: ChecklistItemPatch,
  ): Promise<SubscriptionDetail> =>
    apiData(
      api.PATCH('/subscriptions/{id}/cancellation-checklist/{index}', {
        params: { path: { id, index } },
        body,
      }),
    ),
  /** Links a recorded expense as a payment (idempotent; the ledger is not changed). */
  recordPayment: (
    id: string,
    body: SubscriptionPaymentInput,
    key: string,
  ): Promise<SubscriptionDetail> =>
    apiData(
      api.POST('/subscriptions/{id}/payments', {
        params: { path: { id }, header: { 'Idempotency-Key': key } },
        body,
      }),
    ),
  /** Removes a payment link; the transaction itself is not changed and can be linked again. */
  unlinkPayment: (id: string, transactionId: string): Promise<SubscriptionDetail> =>
    apiData(
      api.DELETE('/subscriptions/{id}/payments/{transactionId}', {
        params: { path: { id, transactionId } },
      }),
    ),
  /** Unlinked expenses that may be this subscription's payments, best match first. */
  paymentCandidates: (id: string, signal?: AbortSignal): Promise<SubscriptionPaymentCandidate[]> =>
    apiData(
      api.GET('/subscriptions/{id}/payment-candidates', {
        params: { path: { id } },
        ...signalOption(signal),
      }),
    ),
  detections: (status: DetectionStatus, signal?: AbortSignal): Promise<DetectionCandidate[]> =>
    apiData(
      api.GET('/subscriptions/detections', {
        params: { query: { status } },
        ...signalOption(signal),
      }),
    ),
  confirmDetection: (id: string, body: DetectionConfirmInput): Promise<SubscriptionDetail> =>
    apiData(api.POST('/subscriptions/detections/{id}/confirm', { params: { path: { id } }, body })),
  dismissDetection: (id: string): Promise<{ ok: boolean }> =>
    apiData(api.POST('/subscriptions/detections/{id}/dismiss', { params: { path: { id } } })),
  /** A transaction (to compare a chosen payment with the subscription's price). */
  transaction: (id: string): Promise<Transaction> =>
    apiData(api.GET('/transactions/{id}', { params: { path: { id } } })),
  /** Queues a background run that looks for repeating charges (202). */
  refreshDetections: (): Promise<{ ok: boolean }> =>
    apiData(api.POST('/subscriptions/detections/refresh')),
};

export function useSubscriptions(status: SubscriptionListStatus) {
  return useQuery({
    queryKey: financeKeys.subscriptions(status),
    queryFn: ({ signal }) => subscriptionsApi.list(status, signal),
  });
}

export function useSubscriptionSummary() {
  return useQuery({
    queryKey: financeKeys.subscriptionSummary(),
    queryFn: ({ signal }) => subscriptionsApi.summary(signal),
  });
}

export function useSubscription(id: string) {
  return useQuery({
    queryKey: financeKeys.subscription(id),
    queryFn: ({ signal }) => subscriptionsApi.get(id, signal),
    enabled: Boolean(id),
  });
}

/** Suggested payments for the link dialog (fresh every time it opens). */
export function useSubscriptionPaymentCandidates(id: string, enabled: boolean) {
  return useQuery({
    queryKey: financeKeys.subscriptionPaymentCandidates(id),
    queryFn: ({ signal }) => subscriptionsApi.paymentCandidates(id, signal),
    enabled,
    staleTime: 0,
  });
}

export function useDetections(status: DetectionStatus) {
  return useQuery({
    queryKey: financeKeys.detections(status),
    queryFn: ({ signal }) => subscriptionsApi.detections(status, signal),
  });
}
