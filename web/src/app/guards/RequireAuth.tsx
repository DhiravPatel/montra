import { Navigate, Outlet, useLocation } from 'react-router';
import { useAuth } from '@/shared/auth/AuthContext';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { paths } from '@/shared/config/paths';
import { useT } from '@/shared/i18n/I18nContext';
import { AccountDisplayPreferences } from '../providers/AccountDisplayPreferences';

/** Signed-in pages whose links carry a one-time token in the URL fragment. */
const FRAGMENT_TOKEN_PATHS: ReadonlySet<string> = new Set([paths.groupJoin, paths.communityJoin]);

/** Renders child routes only for a signed-in user; otherwise routes to sign-in. */
export function RequireAuth() {
  const auth = useAuth();
  const location = useLocation();
  const t = useT();

  if (auth.status === 'loading') {
    return (
      <main
        id="main"
        tabIndex={-1}
        className="flex min-h-dvh items-center justify-center outline-none"
      >
        <LoadingState label={t('session.checking')} />
      </main>
    );
  }

  if (auth.status === 'error') {
    // Offline or server trouble: do not sign the user out, offer a retry.
    return (
      <main
        id="main"
        tabIndex={-1}
        className="mx-auto flex min-h-dvh max-w-xl items-center px-4 outline-none"
      >
        <ErrorState
          titleAs="h2"
          title={t('session.checkFailed')}
          error={auth.error}
          onRetry={auth.retry}
        />
      </main>
    );
  }

  if (auth.status === 'anonymous') {
    // After an explicit sign-out, do not offer to return to the old page.
    const explicit = auth.notice === 'signed-out' || auth.notice === 'signed-out-everywhere';
    // Invitation pages carry their one-time token in the fragment; keep it
    // (in history state only, never sent anywhere) so the link still works
    // after signing in.
    const keepHash = FRAGMENT_TOKEN_PATHS.has(location.pathname) ? location.hash : '';
    return (
      <Navigate
        to={paths.signIn}
        replace
        state={explicit ? undefined : { from: location.pathname + location.search + keepHash }}
      />
    );
  }

  return (
    <>
      <AccountDisplayPreferences />
      <Outlet />
    </>
  );
}
