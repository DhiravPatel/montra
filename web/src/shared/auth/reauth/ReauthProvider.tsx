import { type ReactNode, useCallback, useMemo, useRef, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Dialog } from '@/shared/components/Dialog';
import { useT } from '@/shared/i18n/I18nContext';
import { useAuth, useCurrentUser } from '../AuthContext';
import { ReauthCancelledError, ReauthContext, type ReauthContextValue } from './ReauthContext';
import { ReauthForm } from './ReauthForm';

/** The API's re-authentication window is 10 minutes (AUTH_REAUTH_WINDOW); stay inside it. */
const FRESH_FOR_MS = 9 * 60_000;

interface Prompt {
  resolve: () => void;
  reject: (error: Error) => void;
}

/** Provides re-authentication for sensitive actions. Mount inside authenticated routes. */
export function ReauthProvider({ children }: { children: ReactNode }) {
  const t = useT();
  const user = useCurrentUser();
  const { signedInAt } = useAuth();
  const [prompt, setPrompt] = useState<Prompt | null>(null);
  const [busy, setBusy] = useState(false);
  const promptPromise = useRef<Promise<void> | null>(null);
  const lastConfirmedAt = useRef<number | null>(null);

  const requestReauth = useCallback((): Promise<void> => {
    // Concurrent callers share one dialog.
    promptPromise.current ??= new Promise<void>((resolve, reject) => {
      setPrompt({ resolve, reject });
    }).finally(() => {
      promptPromise.current = null;
    });
    return promptPromise.current;
  }, []);

  const withReauth = useCallback(
    async <T,>(action: () => Promise<T>): Promise<T> => {
      try {
        return await action();
      } catch (error) {
        if (!hasErrorCode(error, 'REAUTH_REQUIRED')) throw error;
        lastConfirmedAt.current = null;
        await requestReauth();
        return action();
      }
    },
    [requestReauth],
  );

  const ensureRecentReauth = useCallback(async () => {
    // A sign-in in this tab counts too: the API records it as a re-authentication.
    const last = Math.max(lastConfirmedAt.current ?? 0, signedInAt ?? 0);
    if (last > 0 && Date.now() - last < FRESH_FOR_MS) return;
    await requestReauth();
  }, [requestReauth, signedInAt]);

  const close = (outcome: 'confirmed' | 'cancelled') => {
    if (!prompt) return;
    if (outcome === 'confirmed') {
      lastConfirmedAt.current = Date.now();
      prompt.resolve();
    } else {
      prompt.reject(new ReauthCancelledError());
    }
    setPrompt(null);
  };

  const value = useMemo<ReauthContextValue>(
    () => ({ withReauth, ensureRecentReauth }),
    [withReauth, ensureRecentReauth],
  );

  return (
    <ReauthContext.Provider value={value}>
      {children}
      <Dialog
        open={prompt !== null}
        onOpenChange={(open) => {
          if (!open) close('cancelled');
        }}
        busy={busy}
        title={t('reauth.title')}
        description={user.mfa_enabled ? t('reauth.descriptionWithCode') : t('reauth.description')}
      >
        <ReauthForm
          email={user.email}
          mfaEnabled={user.mfa_enabled}
          onPendingChange={setBusy}
          onConfirmed={() => {
            close('confirmed');
          }}
          onCancel={() => {
            close('cancelled');
          }}
        />
      </Dialog>
    </ReauthContext.Provider>
  );
}
