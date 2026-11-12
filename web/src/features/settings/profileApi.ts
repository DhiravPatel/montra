import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import { useAuth } from '@/shared/auth/AuthContext';
import { financeKeys, preferencesQueryKey } from '@/shared/finance/keys';
import type { Preferences, PreferencesPatch } from '@/shared/finance/types';
import { loadFilePreview } from '@/shared/files/preview';
import { socialApi } from '@/features/social/api';
import { socialKeys } from '@/features/social/keys';
import type { OwnProfile, OwnProfilePatch } from '@/features/social/types';

/**
 * Profile (PATCH /me) and preferences (PATCH /me/preferences). Neither is
 * versioned: each save sends only the fields that changed. The signed-in
 * user carries the display name, username, avatar, currency, time zone and
 * locale too, so it is reloaded after a save.
 */
export function useSaveProfile() {
  const queryClient = useQueryClient();
  const { refreshUser } = useAuth();
  return useMutation({
    mutationFn: (patch: OwnProfilePatch): Promise<OwnProfile> => socialApi.updateProfile(patch),
    onSuccess: async (profile) => {
      queryClient.setQueryData(socialKeys.profile(), profile);
      await refreshUser();
    },
  });
}

export function useSavePreferences() {
  const queryClient = useQueryClient();
  const { refreshUser } = useAuth();
  return useMutation({
    mutationFn: (patch: PreferencesPatch): Promise<Preferences> =>
      apiData(api.PATCH('/me/preferences', { body: patch })),
    onSuccess: async (preferences, patch) => {
      queryClient.setQueryData(preferencesQueryKey, preferences);
      // Totals that depend on the time zone or the month start are computed again.
      if (patch.timezone || patch.month_start_day || patch.week_start) {
        void queryClient.invalidateQueries({ queryKey: financeKeys.all });
      }
      await refreshUser();
    },
  });
}

/** Your avatar image as a `data:` URL (downloaded through its short-lived signed link). */
export function useAvatarPreview(fileId: string | undefined) {
  return useQuery({
    queryKey: ['me', 'avatar', fileId ?? ''] as const,
    queryFn: ({ signal }) => loadFilePreview(fileId ?? '', signal),
    enabled: Boolean(fileId),
    staleTime: Number.POSITIVE_INFINITY,
    refetchOnWindowFocus: false,
  });
}
