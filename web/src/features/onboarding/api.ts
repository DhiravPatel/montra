import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import type { OnboardingInput, Preferences, PreferencesPatch } from '@/shared/finance/types';

/** Onboarding and preference endpoints (spec §4.1, §20B.2). */
export const onboardingApi = {
  /** Saved progress, so setup resumes where the person left it. */
  get: (signal?: AbortSignal) => apiData(api.GET('/me/onboarding', signal ? { signal } : {})),
  /** Steps merge with what is stored (a completed step wins over a skipped one). */
  record: (body: OnboardingInput) => apiData(api.POST('/me/onboarding', { body })),
  updatePreferences: (body: PreferencesPatch): Promise<Preferences> =>
    apiData(api.PATCH('/me/preferences', { body })),
  archiveCategory: (id: string) =>
    apiData(api.POST('/categories/{id}/archive', { params: { path: { id } } })),
};
