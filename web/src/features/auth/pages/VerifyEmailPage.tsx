import { useMutation } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { useAuth } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { ButtonLink } from '@/shared/components/Button';
import { ErrorState, LoadingState } from '@/shared/components/states';
import { defaultSignedInPath, paths } from '@/shared/config/paths';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useT } from '@/shared/i18n/I18nContext';
import { authApi } from '../api';
import { AuthCard } from '../components/AuthCard';
import { EmailRequestForm } from '../components/EmailRequestForm';
import { useFragmentToken } from '../hooks/useFragmentToken';

/** Lets the user ask for a fresh link when theirs is missing, expired or used. */
function RequestNewLink() {
  const t = useT();
  const [sentTo, setSentTo] = useState<string | null>(null);
  if (sentTo) {
    return (
      <Alert tone="info" live="polite">
        {t('auth.verify.newLinkSent', { email: sentTo })}
      </Alert>
    );
  }
  return (
    <div className="space-y-3">
      <p className="text-sm text-fg-muted">{t('auth.verify.requestNew')}</p>
      <EmailRequestForm
        submitLabel={t('auth.verify.sendNew')}
        onRequest={authApi.resendVerification}
        onAccepted={setSentTo}
      />
    </div>
  );
}

export function VerifyEmailPage() {
  const t = useT();
  const { status, refreshUser } = useAuth();
  const token = useFragmentToken();
  const started = useRef(false);
  const mutation = useMutation({ ...sensitiveMutation, mutationFn: authApi.verifyEmail });
  const { mutate } = mutation;

  useDocumentTitle(t('auth.verify.title'));

  useEffect(() => {
    // Tokens are single use: post exactly once, even under StrictMode re-runs.
    if (!token || started.current) return;
    started.current = true;
    mutate(token, {
      onSuccess: () => {
        if (status === 'authenticated') void refreshUser();
      },
    });
  }, [token, mutate, status, refreshUser]);

  const continuePath = status === 'authenticated' ? defaultSignedInPath : paths.signIn;
  const continueLabel = status === 'authenticated' ? t('nav.goToAccount') : t('auth.verify.signIn');

  let body;
  if (!token) {
    body = (
      <div className="space-y-5">
        <Alert tone="warning" title={t('auth.verify.missing.title')}>
          {t('auth.verify.missing.body')}
        </Alert>
        <RequestNewLink />
      </div>
    );
  } else if (mutation.isSuccess) {
    body = (
      <div className="space-y-5">
        <Alert tone="success" live="polite" title={t('auth.verify.success.title')}>
          {t('auth.verify.success.body')}
        </Alert>
        <ButtonLink to={continuePath} className="w-full">
          {continueLabel}
        </ButtonLink>
      </div>
    );
  } else if (mutation.isError && hasErrorCode(mutation.error, 'GONE')) {
    body = (
      <div className="space-y-5">
        <Alert tone="warning" live="assertive" title={t('auth.verify.expired.title')}>
          {t('auth.verify.expired.body')}
        </Alert>
        <RequestNewLink />
        <ButtonLink to={paths.signIn} variant="secondary" className="w-full">
          {t('auth.verify.signIn')}
        </ButtonLink>
      </div>
    );
  } else if (mutation.isError) {
    body = (
      <ErrorState
        titleAs="h2"
        title={t('auth.verify.failed')}
        error={mutation.error}
        onRetry={() => {
          mutate(token);
        }}
      />
    );
  } else {
    body = <LoadingState label={t('auth.verify.pending')} />;
  }

  return <AuthCard title={t('auth.verify.title')}>{body}</AuthCard>;
}
