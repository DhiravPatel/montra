import { createContext, useContext } from 'react';
import type { ApiError } from '@/shared/api/errors';
import type { Session, User } from '@/shared/api/types';

export type AuthStatus = 'loading' | 'authenticated' | 'anonymous' | 'error';

/** Why the user was last signed out; shown once on the sign-in page. */
export type SignOutNotice = 'signed-out' | 'signed-out-everywhere' | 'expired';

export interface AuthContextValue {
  status: AuthStatus;
  user: User | null;
  session: Session | null;
  /** Set when the session could not be checked (offline, server error). */
  error: ApiError | null;
  notice: SignOutNotice | null;
  clearNotice: () => void;
  /**
   * When this tab completed a sign-in (epoch ms), or null. The API treats a
   * new sign-in as a recent re-authentication (last_reauth_at = now()).
   */
  signedInAt: number | null;
  /** Re-checks the session (after a bootstrap error). */
  retry: () => void;
  /**
   * Call after a successful login or MFA verification: confirms the session
   * cookies work by loading `GET /auth/session` and updates every tab.
   */
  completeSignIn: () => Promise<void>;
  /** Signs out this session or every session, then clears client state. */
  signOut: (scope?: 'current' | 'everywhere') => Promise<void>;
  /** Reloads the signed-in user (e.g. after enabling two-step verification). */
  refreshUser: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | null>(null);

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside <AuthProvider>');
  return value;
}

/** The signed-in user. Only use inside routes protected by <RequireAuth>. */
export function useCurrentUser(): User {
  const { user } = useAuth();
  if (!user) throw new Error('useCurrentUser requires an authenticated session');
  return user;
}
