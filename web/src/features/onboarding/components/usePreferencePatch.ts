import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuth } from '@/shared/auth/AuthContext';
import { preferencesQueryKey } from '@/shared/finance/keys';
import type { PreferencesPatch } from '@/shared/finance/types';
import { onboardingApi } from '../api';

/** Saves preferences, then reloads the signed-in user (currency, time zone and locale live there too). */
export function usePreferencePatch() {
  const queryClient = useQueryClient();
  const { refreshUser } = useAuth();
  return useMutation({
    mutationFn: (patch: PreferencesPatch) => onboardingApi.updatePreferences(patch),
    onSuccess: async (preferences) => {
      queryClient.setQueryData(preferencesQueryKey, preferences);
      await refreshUser();
    },
  });
}
