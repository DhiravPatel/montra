import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode, isApiError } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { useCurrentUser } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { PasswordField } from '@/shared/components/PasswordField';
import { useToast } from '@/shared/components/toast/ToastContext';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { currentPasswordSchema, newPasswordSchema } from '@/shared/validation/schemas';
import { PasswordRequirements } from '@/shared/forms/PasswordRequirements';
import { securityApi, sessionsQueryKey } from '../api';

interface ChangePasswordValues {
  currentPassword: string;
  newPassword: string;
  confirmPassword: string;
}

export function ChangePasswordCard() {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const user = useCurrentUser();
  const [formError, setFormError] = useState<string | null>(null);

  const schema = useMemo(
    () =>
      z
        .object({
          currentPassword: currentPasswordSchema(t),
          newPassword: newPasswordSchema(t, () => user.email),
          confirmPassword: z.string(),
        })
        .refine((values) => values.newPassword === values.confirmPassword, {
          path: ['confirmPassword'],
          error: t('validation.passwordMismatch'),
        }),
    [t, user.email],
  );
  const form = useForm<ChangePasswordValues, unknown, ChangePasswordValues>({
    resolver: zodResolver(schema),
    defaultValues: { currentPassword: '', newPassword: '', confirmPassword: '' },
  });
  const newPassword = useWatch({ control: form.control, name: 'newPassword' });

  const mutation = useMutation({
    ...sensitiveMutation,
    mutationFn: (values: ChangePasswordValues) =>
      securityApi.changePassword(values.currentPassword, values.newPassword),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    try {
      await mutation.mutateAsync(values);
      form.reset();
      toast.show({
        tone: 'success',
        title: t('settings.password.changed'),
        description: t('settings.password.changedBody'),
      });
      await queryClient.invalidateQueries({ queryKey: sessionsQueryKey });
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
          current_password: 'currentPassword',
          password: 'newPassword',
          new_password: 'newPassword',
        });
        if (rest.length > 0) setFormError(rest.join(' '));
      } else {
        setFormError(describeError(error, t));
      }
      if (
        isApiError(error) &&
        error.details.some((detail) => detail.field === 'body.current_password')
      ) {
        form.resetField('currentPassword', { keepError: true });
      }
    }
  });

  const { errors } = form.formState;

  return (
    <Card title={t('settings.password.title')} description={t('settings.password.description')}>
      <form onSubmit={onSubmit} noValidate className="max-w-md space-y-5">
        <FormAlert message={formError} />
        {/* Lets password managers update the right saved credential. */}
        <input
          type="email"
          name="username"
          autoComplete="username"
          value={user.email}
          readOnly
          hidden
        />
        <PasswordField
          label={t('settings.password.current')}
          autoComplete="current-password"
          error={errors.currentPassword?.message}
          {...form.register('currentPassword')}
        />
        <PasswordField
          label={t('auth.fields.newPassword')}
          autoComplete="new-password"
          help={<PasswordRequirements password={newPassword} email={user.email} />}
          error={errors.newPassword?.message}
          {...form.register('newPassword')}
        />
        <PasswordField
          label={t('auth.fields.confirmPassword')}
          autoComplete="new-password"
          error={errors.confirmPassword?.message}
          {...form.register('confirmPassword')}
        />
        <Button type="submit" loading={mutation.isPending}>
          {t('settings.password.submit')}
        </Button>
      </form>
    </Card>
  );
}
