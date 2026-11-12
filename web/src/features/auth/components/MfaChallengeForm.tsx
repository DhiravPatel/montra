import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { useAuth } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { TextField } from '@/shared/components/TextField';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { recoveryCodeSchema, totpCodeSchema } from '@/shared/validation/schemas';
import { authApi } from '../api';
import { useRetryAfter } from '../hooks/useRetryAfter';
import { RetryAfterNotice } from './RetryAfterNotice';

interface MfaValues {
  code: string;
  recoveryCode: string;
}

interface MfaChallengeFormProps {
  /** Short-lived challenge token from the login response (kept in memory only). */
  mfaToken: string;
  onRestart: () => void;
}

/**
 * Second sign-in step: authenticator code, or a single-use recovery code.
 * MFA_CODE_INVALID keeps the challenge (retry with the same token);
 * MFA_CHALLENGE_EXPIRED ends it, so the only way forward is to sign in again.
 */
export function MfaChallengeForm({ mfaToken, onRestart }: MfaChallengeFormProps) {
  const t = useT();
  const { completeSignIn } = useAuth();
  const [mode, setMode] = useState<'code' | 'recovery'>('code');
  const [expired, setExpired] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const retry = useRetryAfter();
  const switched = useRef(false);
  const restartRef = useRef<HTMLButtonElement>(null);

  const schema = useMemo(
    () =>
      mode === 'code'
        ? z.object({ code: totpCodeSchema(t), recoveryCode: z.string() })
        : z.object({ code: z.string(), recoveryCode: recoveryCodeSchema(t) }),
    [t, mode],
  );
  const form = useForm<MfaValues, unknown, MfaValues>({
    resolver: zodResolver(schema),
    defaultValues: { code: '', recoveryCode: '' },
  });
  const { setFocus, clearErrors } = form;

  useEffect(() => {
    if (!switched.current) return;
    setFocus(mode === 'code' ? 'code' : 'recoveryCode');
  }, [mode, setFocus]);

  useEffect(() => {
    if (expired) restartRef.current?.focus();
  }, [expired]);

  const mutation = useMutation({
    ...sensitiveMutation,
    mutationFn: (values: MfaValues) =>
      authApi.verifyMfa(
        mode === 'code'
          ? { mfa_token: mfaToken, code: values.code }
          : { mfa_token: mfaToken, recovery_code: values.recoveryCode },
      ),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || retry.blocked || expired) return;
    setFormError(null);
    try {
      const result = await mutation.mutateAsync(values);
      if (result.status !== 'authenticated') {
        setFormError(t('errors.UNKNOWN_ERROR'));
        return;
      }
      await completeSignIn();
    } catch (error) {
      retry.capture(error);
      const field = mode === 'code' ? 'code' : 'recoveryCode';
      if (hasErrorCode(error, 'MFA_CODE_INVALID')) {
        const message = mode === 'code' ? t('auth.mfa.codeInvalid') : t('auth.mfa.recoveryInvalid');
        form.setError(field, { type: 'server', message }, { shouldFocus: true });
      } else if (
        hasErrorCode(error, 'MFA_CHALLENGE_EXPIRED') ||
        hasErrorCode(error, 'UNAUTHENTICATED')
      ) {
        // UNAUTHENTICATED: older API builds used it for an expired challenge.
        setExpired(true);
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          code: 'code',
          recovery_code: 'recoveryCode',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  if (expired) {
    return (
      <div className="space-y-5">
        <Alert tone="warning" live="assertive" title={t('auth.mfa.expired.title')}>
          {t('auth.mfa.expired.body')}
        </Alert>
        <Button ref={restartRef} className="w-full" onClick={onRestart}>
          {t('auth.mfa.expired.action')}
        </Button>
      </div>
    );
  }

  const switchMode = () => {
    switched.current = true;
    clearErrors();
    setFormError(null);
    setMode((current) => (current === 'code' ? 'recovery' : 'code'));
  };

  const { errors } = form.formState;

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      {mode === 'code' ? (
        <TextField
          label={t('auth.mfa.codeLabel')}
          help={t('auth.mfa.codeHelp')}
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={7}
          error={errors.code?.message}
          {...form.register('code')}
        />
      ) : (
        <TextField
          label={t('auth.mfa.recoveryLabel')}
          help={t('auth.mfa.recoveryHelp')}
          autoComplete="off"
          autoCapitalize="off"
          spellCheck={false}
          maxLength={20}
          error={errors.recoveryCode?.message}
          {...form.register('recoveryCode')}
        />
      )}
      <Button type="submit" className="w-full" loading={mutation.isPending}>
        {t('auth.mfa.submit')}
      </Button>
      <RetryAfterNotice seconds={retry.remaining} />
      <div className="flex flex-col items-start gap-2 text-sm">
        <Button variant="ghost" size="sm" onClick={switchMode}>
          {mode === 'code' ? t('auth.mfa.useRecovery') : t('auth.mfa.useCode')}
        </Button>
        <Button variant="ghost" size="sm" onClick={onRestart}>
          {t('auth.mfa.restart')}
        </Button>
      </div>
    </form>
  );
}
