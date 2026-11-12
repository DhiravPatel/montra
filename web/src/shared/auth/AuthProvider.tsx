import { useQuery, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { api } from '@/shared/api/client';
import { forgetCsrfToken } from '@/shared/api/csrf';
import { ApiError, isApiError, isTransientError } from '@/shared/api/errors';
import { apiEvents } from '@/shared/api/events';
import { apiData } from '@/shared/api/request';
import {
  AuthContext,
  type AuthContextValue,
  type AuthStatus,
  type SignOutNotice,
} from './AuthContext';
import { type AuthChannel, openAuthChannel } from './broadcast';
import { type AuthSession, fetchSession, sessionQueryKey } from './session';

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const [notice, setNotice] = useState<SignOutNotice | null>(null);
  const [signedInAt, setSignedInAt] = useState<number | null>(null);
  const channelRef = useRef<AuthChannel | null>(null);

  const sessionQuery = useQuery<AuthSession | null, ApiError>({
    queryKey: sessionQueryKey,
    queryFn: ({ signal }) => fetchSession(signal),
    staleTime: 60_000,
    refetchOnWindowFocus: true,
    retry: (failureCount, error) => isTransientError(error) && failureCount < 2,
  });

  /** Drops every cached query except the session itself, then marks the user signed out. */
  const clearSignedInState = useCallback(
    (reason: SignOutNotice | null) => {
      forgetCsrfToken();
      queryClient.removeQueries({ predicate: (query) => query.queryKey[0] !== sessionQueryKey[0] });
      queryClient.setQueryData<AuthSession | null>(sessionQueryKey, null);
      setNotice(reason);
      setSignedInAt(null);
    },
    [queryClient],
  );

  // The API client reports sessions that could not be renewed.
  useEffect(
    () =>
      apiEvents.on('session-expired', () => {
        const current = queryClient.getQueryData<AuthSession | null>(sessionQueryKey);
        if (current) clearSignedInState('expired');
      }),
    [queryClient, clearSignedInState],
  );

  // Keep other tabs in sync.
  useEffect(() => {
    const channel = openAuthChannel((message) => {
      if (message.type === 'signed-out') {
        if (queryClient.getQueryData<AuthSession | null>(sessionQueryKey))
          clearSignedInState('signed-out');
      } else {
        void queryClient.invalidateQueries({ queryKey: sessionQueryKey });
      }
    });
    channelRef.current = channel;
    return () => {
      channel.close();
      channelRef.current = null;
    };
  }, [queryClient, clearSignedInState]);

  const completeSignIn = useCallback(async () => {
    const session = await queryClient.query({
      queryKey: sessionQueryKey,
      queryFn: ({ signal }) => fetchSession(signal),
      staleTime: 0,
    });
    if (!session) {
      // Login succeeded but the browser did not send the session cookie back.
      throw new ApiError({
        status: 0,
        code: 'COOKIES_BLOCKED',
        message: 'Session cookies were not stored.',
      });
    }
    setNotice(null);
    setSignedInAt(Date.now());
    channelRef.current?.post({ type: 'signed-in' });
  }, [queryClient]);

  const signOut = useCallback(
    async (scope: 'current' | 'everywhere' = 'current') => {
      try {
        await apiData(
          scope === 'current' ? api.POST('/auth/logout') : api.POST('/auth/logout-all'),
        );
      } catch (error) {
        // 401: the session had already ended server-side, which is the goal.
        if (!(isApiError(error) && error.status === 401)) throw error;
      }
      channelRef.current?.post({ type: 'signed-out' });
      clearSignedInState(scope === 'current' ? 'signed-out' : 'signed-out-everywhere');
    },
    [clearSignedInState],
  );

  const refreshUser = useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: sessionQueryKey });
  }, [queryClient]);

  const clearNotice = useCallback(() => {
    setNotice(null);
  }, []);

  const { data, error, refetch } = sessionQuery;
  const retry = useCallback(() => {
    void refetch();
  }, [refetch]);

  const value = useMemo<AuthContextValue>(() => {
    let status: AuthStatus;
    if (data) status = 'authenticated';
    else if (data === null) status = 'anonymous';
    else if (error) status = 'error';
    else status = 'loading';
    return {
      status,
      user: data?.user ?? null,
      session: data?.session ?? null,
      error: data === undefined ? error : null,
      notice,
      clearNotice,
      signedInAt,
      retry,
      completeSignIn,
      signOut,
      refreshUser,
    };
  }, [data, error, notice, clearNotice, signedInAt, retry, completeSignIn, signOut, refreshUser]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
