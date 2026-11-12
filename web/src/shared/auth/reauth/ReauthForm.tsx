import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { api } from '@/shared/api/client';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { apiData } from '@/shared/api/request';
import { Button } from '@/shared/components/Button';
import { PasswordField } from '@/shared/components/PasswordField';
import { TextField } from '@/shared/components/TextField';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import {
  currentPasswordSchema,
  recoveryCodeSchema,
  totpCodeSchema,
} from '@/shared/validation/schemas';

interface ReauthFormProps {
  email: string;
  mfaEnabled: boolean;
  onConfirmed: () => void;
  onCancel: () => void;
  onPendingChange: (pending: boolean) => void;
}

interface ReauthValues {
  password: string;
  code: string;
  recoveryCode: string;
}

type SecondFactor = 'none' | 'code' | 'recovery';

/**
 * Password plus, when two-step verification is on, an authenticator code or
 * a single-use recovery code (POST /auth/reauthenticate).
 */
export function ReauthForm({
  email,
  mfaEnabled,
  onConfirmed,
  onCancel,
  onPendingChange,
}: ReauthFormProps) {
  const t = useT();
  const [factor, setFactor] = useState<SecondFactor>(mfaEnabled ? 'code' : 'none');
  const [formError, setFormError] = useState<string | null>(null);
  const switched = useRef(false);

  const schema = useMemo(
    () =>
      z.object({
        password: currentPasswordSchema(t),
        code: factor === 'code' ? totpCodeSchema(t) : z.string(),
        recoveryCode: factor === 'recovery' ? recoveryCodeSchema(t) : z.string(),
      }),
    [t, factor],
  );

  const form = useForm<ReauthValues, unknown, ReauthValues>({
    resolver: zodResolver(schema),
    defaultValues: { password: '', code: '', recoveryCode: '' },
  });
  const { setFocus, clearErrors } = form;

  useEffect(() => {
    if (!switched.current) return;
    if (factor === 'code') setFocus('code');
    if (factor === 'recovery') setFocus('recoveryCode');
  }, [factor, setFocus]);

  const mutation = useMutation({
    ...sensitiveMutation,
    mutationFn: (values: ReauthValues) =>
      apiData(
        api.POST('/auth/reauthenticate', {
          body: {
            password: values.password,
            ...(factor === 'code' ? { code: values.code } : {}),
            ...(factor === 'recovery' ? { recovery_code: values.recoveryCode } : {}),
          },
        }),
      ),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    onPendingChange(true);
    try {
      await mutation.mutateAsync(values);
      onConfirmed();
    } catch (error) {
      if (hasErrorCode(error, 'REAUTH_REQUIRED')) {
        form.setError(
          'password',
          { type: 'server', message: t('reauth.wrongPassword') },
          { shouldFocus: true },
        );
      } else if (hasErrorCode(error, 'MFA_REQUIRED')) {
        if (factor === 'recovery') {
          form.setError(
            'recoveryCode',
            { type: 'server', message: t('reauth.wrongRecovery') },
            { shouldFocus: true },
          );
        } else {
          // Also covers a stale "MFA off" view: reveal the code field.
          setFactor('code');
          form.setError(
            'code',
            { type: 'server', message: t('reauth.wrongCode') },
            { shouldFocus: true },
          );
        }
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          password: 'password',
          code: 'code',
          recovery_code: 'recoveryCode',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(describeError(error, t));
      }
    } finally {
      onPendingChange(false);
    }
  });

  const switchFactor = () => {
    switched.current = true;
    clearErrors(['code', 'recoveryCode']);
    setFactor((current) => (current === 'code' ? 'recovery' : 'code'));
  };

  const { errors } = form.formState;

  return (
    <form onSubmit={onSubmit} noValidate className="space-y-4">
      <FormAlert message={formError} />
      {/* Lets password managers match the saved credential. */}
      <input type="email" name="username" autoComplete="username" value={email} readOnly hidden />
      <PasswordField
        label={t('reauth.password')}
        autoComplete="current-password"
        error={errors.password?.message}
        {...form.register('password')}
      />
      {factor === 'code' ? (
        <TextField
          label={t('reauth.code')}
          help={t('reauth.codeHelp')}
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={7}
          error={errors.code?.message}
          {...form.register('code')}
        />
      ) : null}
      {factor === 'recovery' ? (
        <TextField
          label={t('auth.mfa.recoveryLabel')}
          help={t('reauth.recoveryHelp')}
          autoComplete="off"
          autoCapitalize="off"
          spellCheck={false}
          maxLength={20}
          error={errors.recoveryCode?.message}
          {...form.register('recoveryCode')}
        />
      ) : null}
      {factor !== 'none' ? (
        <Button variant="ghost" size="sm" onClick={switchFactor}>
          {factor === 'code' ? t('auth.mfa.useRecovery') : t('auth.mfa.useCode')}
        </Button>
      ) : null}
      <div className="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={mutation.isPending}>
          {t('reauth.confirm')}
        </Button>
      </div>
    </form>
  );
}
