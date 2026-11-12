import { createContext, useContext } from 'react';

export class ReauthCancelledError extends Error {
  constructor() {
    super('Re-authentication was cancelled.');
    this.name = 'ReauthCancelledError';
  }
}

export function isReauthCancelled(error: unknown): error is ReauthCancelledError {
  return error instanceof ReauthCancelledError;
}

export interface ReauthContextValue {
  /**
   * Runs `action`; if the API answers REAUTH_REQUIRED, asks the user to
   * confirm their password (and authenticator code), then retries once.
   * Rejects with ReauthCancelledError if the user cancels.
   */
  withReauth: <T>(action: () => Promise<T>) => Promise<T>;
  /**
   * Asks for re-authentication now unless this tab re-authenticated within
   * the server's window. Use before actions that also consume a TOTP code,
   * so the same code is not needed twice (codes are single-use).
   */
  ensureRecentReauth: () => Promise<void>;
}

export const ReauthContext = createContext<ReauthContextValue | null>(null);

export function useReauth(): ReauthContextValue {
  const value = useContext(ReauthContext);
  if (!value) throw new Error('useReauth must be used inside <ReauthProvider>');
  return value;
}
