import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { useAuth } from '@/shared/auth/AuthContext';
import { Alert } from '@/shared/components/Alert';
import { Button, ButtonLink } from '@/shared/components/Button';
import { PasswordField } from '@/shared/components/PasswordField';
import { paths } from '@/shared/config/paths';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { useDocumentTitle } from '@/shared/hooks/useDocumentTitle';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { newPasswordSchema } from '@/shared/validation/schemas';
import { authApi } from '../api';
import { AuthCard } from '../components/AuthCard';
import { PasswordRequirements } from '@/shared/forms/PasswordRequirements';
import { RetryAfterNotice } from '../components/RetryAfterNotice';
import { useFragmentToken } from '../hooks/useFragmentToken';
import { useRetryAfter } from '../hooks/useRetryAfter';

interface ResetValues {
  newPassword: string;
  confirmPassword: string;
}

function InvalidLink({ expired }: { expired: boolean }) {
  const t = useT();
  return (
    <div className="space-y-5">
      <Alert
        tone="warning"
        live={expired ? 'assertive' : undefined}
        title={expired ? t('auth.reset.expired.title') : t('auth.reset.missing.title')}
      >
        {expired ? t('auth.reset.expired.body') : t('auth.reset.missing.body')}
      </Alert>
      <ButtonLink to={paths.forgotPassword} className="w-full">
        {t('auth.reset.requestNew')}
      </ButtonLink>
    </div>
  );
}

function ResetForm({ token, onExpired }: { token: string; onExpired: () => void }) {
  const t = useT();
  const { status, refreshUser } = useAuth();
  const [formError, setFormError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const retry = useRetryAfter();

  const schema = useMemo(
    () =>
      z
        .object({ newPassword: newPasswordSchema(t), confirmPassword: z.string() })
        .refine((values) => values.newPassword === values.confirmPassword, {
          path: ['confirmPassword'],
          error: t('validation.passwordMismatch'),
        }),
    [t],
  );
  const form = useForm<ResetValues, unknown, ResetValues>({
    resolver: zodResolver(schema),
    defaultValues: { newPassword: '', confirmPassword: '' },
  });
  const newPassword = useWatch({ control: form.control, name: 'newPassword' });
  const mutation = useMutation({
    ...sensitiveMutation,
    mutationFn: (values: ResetValues) => authApi.resetPassword(token, values.newPassword),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending || retry.blocked) return;
    setFormError(null);
    try {
      await mutation.mutateAsync(values);
      form.reset();
      setDone(true);
      // The API signed out every session; drop this tab's session too.
      if (status === 'authenticated') void refreshUser();
    } catch (error) {
      retry.capture(error);
      if (hasErrorCode(error, 'GONE')) {
        onExpired();
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        // The API reports password policy failures as body.password.
        const rest = applyServerErrors(error, form.setError, {
          password: 'newPassword',
          new_password: 'newPassword',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  if (done) {
    return (
      <div className="space-y-5">
        <Alert tone="success" live="polite" title={t('auth.reset.success.title')}>
          {t('auth.reset.success.body')}
        </Alert>
        <ButtonLink to={paths.signIn} className="w-full">
          {t('auth.verify.signIn')}
        </ButtonLink>
      </div>
    );
  }

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <PasswordField
        label={t('auth.fields.newPassword')}
        autoComplete="new-password"
        help={<PasswordRequirements password={newPassword} />}
        error={errors.newPassword?.message}
        {...form.register('newPassword')}
      />
      <PasswordField
        label={t('auth.fields.confirmPassword')}
        autoComplete="new-password"
        error={errors.confirmPassword?.message}
        {...form.register('confirmPassword')}
      />
      <Button type="submit" className="w-full" loading={mutation.isPending}>
        {t('auth.reset.submit')}
      </Button>
      <RetryAfterNotice seconds={retry.remaining} />
    </form>
  );
}

export function ResetPasswordPage() {
  const t = useT();
  const token = useFragmentToken();
  const [expired, setExpired] = useState(false);
  useDocumentTitle(t('auth.reset.title'));

  return (
    <AuthCard
      title={t('auth.reset.title')}
      description={token && !expired ? t('auth.reset.description') : undefined}
    >
      {!token || expired ? (
        <InvalidLink expired={expired} />
      ) : (
        <ResetForm
          token={token}
          onExpired={() => {
            setExpired(true);
          }}
        />
      )}
    </AuthCard>
  );
}
