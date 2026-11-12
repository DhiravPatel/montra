import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { type SignOutNotice, useAuth } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { PasswordField } from '@/shared/components/PasswordField';
import { ExternalLink, TextLink } from '@/shared/components/TextLink';
import { TextField } from '@/shared/components/TextField';
import { appConfig } from '@/shared/config/env';
import { paths } from '@/shared/config/paths';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { useAnnounce } from '@/shared/accessibility/AnnouncerContext';
import { describeError } from '@/shared/i18n/describeError';
import { formatWait } from '@/shared/i18n/formatWait';
import { useT } from '@/shared/i18n/I18nContext';
import type { MessageKey } from '@/shared/i18n/types';
import { currentPasswordSchema, emailSchema } from '@/shared/validation/schemas';
import { authApi } from '../api';
import { AuthCard } from '../components/AuthCard';
import { MfaChallengeForm } from '../components/MfaChallengeForm';
import { ResendVerification } from '../components/ResendVerification';
import { RetryAfterNotice } from '../components/RetryAfterNotice';
import { useRetryAfter } from '../hooks/useRetryAfter';

interface SignInValues {
  email: string;
  password: string;
}

type Problem =
  | { kind: 'message'; text: string }
  | { kind: 'unverified'; email: string }
  | { kind: 'locked' }
  | { kind: 'throttled'; retryAfterSeconds: number | null };

const noticeText: Record<SignOutNotice, { key: MessageKey; tone: 'info' | 'warning' }> = {
  'signed-out': { key: 'auth.notice.signedOut', tone: 'info' },
  'signed-out-everywhere': { key: 'auth.notice.signedOutEverywhere', tone: 'info' },
  expired: { key: 'auth.notice.expired', tone: 'warning' },
};

function ProblemAlert({ problem }: { problem: Problem }) {
  const t = useT();
  switch (problem.kind) {
    case 'unverified':
      return (
        <Alert tone="warning" live="assertive" title={t('auth.signIn.unverified.title')}>
          <p>{t('auth.signIn.unverified.body', { email: problem.email })}</p>
          <ResendVerification email={problem.email} />
        </Alert>
      );
    case 'locked':
      return (
        <Alert tone="danger" live="assertive" title={t('auth.signIn.locked.title')}>
          <p>
            {t('auth.signIn.locked.body')}{' '}
            <ExternalLink href={`mailto:${appConfig.supportEmail}`}>
              {appConfig.supportEmail}
            </ExternalLink>
          </p>
          <TextLink to={paths.forgotPassword}>{t('auth.signIn.forgot')}</TextLink>
        </Alert>
      );
    case 'throttled':
      return (
        <Alert tone="danger" live="assertive" title={t('auth.signIn.throttled.title')}>
          <p>
            {problem.retryAfterSeconds
              ? t('auth.signIn.throttled.body', { wait: formatWait(t, problem.retryAfterSeconds) })
              : t('auth.signIn.throttled.bodyLater')}
          </p>
          <TextLink to={paths.forgotPassword}>{t('auth.signIn.forgot')}</TextLink>
        </Alert>
      );
    case 'message':
      return (
        <Alert tone="danger" live="assertive">
          {problem.text}
        </Alert>
      );
  }
}

function SignInForm({ onMfaRequired }: { onMfaRequired: (token: string) => void }) {
  const t = useT();
  const { completeSignIn, clearNotice } = useAuth();
  const announce = useAnnounce();
  const [problem, setProblem] = useState<Problem | null>(null);
  const retry = useRetryAfter();

  const schema = useMemo(
    () => z.object({ email: emailSchema(t), password: currentPasswordSchema(t) }),
    [t],
  );
  const form = useForm<SignInValues, unknown, SignInValues>({
    resolver: zodResolver(schema),
    defaultValues: { email: '', password: '' },
  });

  const mutation = useMutation({ ...sensitiveMutation, mutationFn: authApi.login });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    if (retry.blocked) {
      // Hold the attempt back on the client; the visible alert already explains why.
      announce(t('auth.retryIn', { wait: formatWait(t, retry.remaining) }), 'assertive');
      return;
    }
    setProblem(null);
    clearNotice();
    try {
      const result = await mutation.mutateAsync({ email: values.email, password: values.password });
      if (result.status === 'mfa_required' && result.mfa_token) {
        onMfaRequired(result.mfa_token);
        return;
      }
      await completeSignIn(); // the public-only route then redirects
    } catch (error) {
      retry.capture(error);
      form.resetField('password', { keepError: false });
      if (hasErrorCode(error, 'UNAUTHENTICATED')) {
        // Generic on purpose: never reveal whether the email has an account.
        setProblem({ kind: 'message', text: t('auth.signIn.invalid') });
      } else if (hasErrorCode(error, 'EMAIL_NOT_VERIFIED')) {
        setProblem({ kind: 'unverified', email: values.email });
      } else if (hasErrorCode(error, 'ACCOUNT_LOCKED')) {
        setProblem({ kind: 'locked' });
      } else if (hasErrorCode(error, 'LOGIN_THROTTLED')) {
        setProblem({ kind: 'throttled', retryAfterSeconds: error.retryAfterSeconds });
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          email: 'email',
          password: 'password',
        });
        if (rest.length > 0) setProblem({ kind: 'message', text: rest.join(' ') });
      } else {
        setProblem({ kind: 'message', text: describeError(error, t) });
      }
    }
  });

  const { errors } = form.formState;

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      {problem ? <ProblemAlert problem={problem} /> : null}
      <TextField
        label={t('auth.fields.email')}
        type="email"
        autoComplete="email"
        inputMode="email"
        spellCheck={false}
        error={errors.email?.message}
        {...form.register('email')}
      />
      <div className="space-y-2">
        <PasswordField
          label={t('auth.fields.password')}
          autoComplete="current-password"
          error={errors.password?.message}
          {...form.register('password')}
        />
        <p className="text-sm">
          <TextLink to={paths.forgotPassword}>{t('auth.signIn.forgot')}</TextLink>
        </p>
      </div>
      <Button type="submit" className="w-full" loading={mutation.isPending}>
        {t('auth.signIn.submit')}
      </Button>
      <RetryAfterNotice seconds={retry.remaining} />
    </form>
  );
}

export function SignInPage() {
  const t = useT();
  const { notice } = useAuth();
  const [mfaToken, setMfaToken] = useState<string | null>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const stepChanged = useRef(false);
  const onMfaStep = mfaToken !== null;

  useDocumentTitle(onMfaStep ? t('auth.mfa.title') : t('auth.signIn.title'));

  // Move focus to the new heading when the step changes (not on first render).
  useEffect(() => {
    if (!stepChanged.current) return;
    headingRef.current?.focus();
  }, [onMfaStep]);

  const showNotice = notice && !onMfaStep ? noticeText[notice] : null;

  return (
    <AuthCard
      headingRef={headingRef}
      title={onMfaStep ? t('auth.mfa.title') : t('auth.signIn.title')}
      description={onMfaStep ? t('auth.mfa.description') : t('auth.signIn.description')}
      footer={
        onMfaStep ? null : (
          <p>
            {t('auth.signIn.noAccount')}{' '}
            <TextLink to={paths.signUp}>{t('auth.signIn.createAccount')}</TextLink>
          </p>
        )
      }
    >
      {showNotice ? (
        <Alert tone={showNotice.tone} live="polite" className="mb-5">
          {t(showNotice.key)}
        </Alert>
      ) : null}
      {mfaToken ? (
        <MfaChallengeForm
          mfaToken={mfaToken}
          onRestart={() => {
            stepChanged.current = true;
            setMfaToken(null);
          }}
        />
      ) : (
        <SignInForm
          onMfaRequired={(token) => {
            stepChanged.current = true;
            setMfaToken(token);
          }}
        />
      )}
    </AuthCard>
  );
}
