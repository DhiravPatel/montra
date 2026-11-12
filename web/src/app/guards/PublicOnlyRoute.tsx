import { Navigate, Outlet, useLocation } from 'react-router';
import type { User } from '@/shared/api/types';
import { useAuth } from '@/shared/auth/AuthContext';
import { defaultSignedInPath, isSafeInternalPath, paths } from '@/shared/config/paths';

function returnPath(state: unknown, user: User | null): string {
  if (
    typeof state === 'object' &&
    state !== null &&
    'from' in state &&
    isSafeInternalPath(state.from)
  ) {
    return state.from;
  }
  // New accounts start with the optional setup; everyone else lands on Home.
  return user && !user.onboarding_completed ? paths.onboarding : defaultSignedInPath;
}

/** Sign-in and sign-up: a signed-in user is sent on to the app (or where they were headed). */
export function PublicOnlyRoute() {
  const { status, user } = useAuth();
  const location = useLocation();
  const state: unknown = location.state;
  if (status === 'authenticated') return <Navigate to={returnPath(state, user)} replace />;
  return <Outlet />;
}
