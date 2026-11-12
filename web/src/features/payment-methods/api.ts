import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import type { components } from '@/shared/api/schema';
import type { PaymentMethod, PaymentMethodInput } from '@/shared/finance/types';

export type PaymentMethodPatch = components['schemas']['PaymentMethodPatch'];

/**
 * Payment methods (masked metadata only; never full card or account
 * numbers, CVVs, PINs or OTPs). Updates change only the fields sent and
 * carry the `version` that was edited.
 */
export const paymentMethodsApi = {
  get: (id: string): Promise<PaymentMethod> =>
    apiData(api.GET('/payment-methods/{id}', { params: { path: { id } } })),
  create: (body: PaymentMethodInput): Promise<PaymentMethod> =>
    apiData(api.POST('/payment-methods', { body })),
  update: (id: string, body: PaymentMethodPatch): Promise<PaymentMethod> =>
    apiData(api.PATCH('/payment-methods/{id}', { params: { path: { id } }, body })),
  /** Deletes an unused method; one used by transactions is archived instead (`{deleted, archived}`). */
  remove: (id: string) =>
    apiData(api.DELETE('/payment-methods/{id}', { params: { path: { id } } })),
  restore: (id: string): Promise<PaymentMethod> =>
    apiData(api.POST('/payment-methods/{id}/restore', { params: { path: { id } } })),
};

/** At most four digits anywhere in the hint (mirrors the API's guard). */
export function maskedHintIsSafe(value: string): boolean {
  return (value.match(/\d/g) ?? []).length <= 4;
}
