import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import { isReauthCancelled, useReauth } from '@/shared/auth/reauth/ReauthContext';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextField } from '@/shared/components/TextField';
import { applyServerErrors } from '@/shared/forms/applyServerErrors';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { recoveryCodeSchema, totpCodeSchema } from '@/shared/validation/schemas';
import { securityApi } from '../api';

interface DisableValues {
  code: string;
  recoveryCode: string;
}

function DisableForm({
  onDisabled,
  onCancel,
  onPendingChange,
}: {
  onDisabled: () => void;
  onCancel: () => void;
  onPendingChange: (pending: boolean) => void;
}) {
  const t = useT();
  const { withReauth } = useReauth();
  const [mode, setMode] = useState<'code' | 'recovery'>('code');
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () =>
      mode === 'code'
        ? z.object({ code: totpCodeSchema(t), recoveryCode: z.string() })
        : z.object({ code: z.string(), recoveryCode: recoveryCodeSchema(t) }),
    [t, mode],
  );
  const form = useForm<DisableValues, unknown, DisableValues>({
    resolver: zodResolver(schema),
    defaultValues: { code: '', recoveryCode: '' },
  });
  const mutation = useMutation({
    ...sensitiveMutation,
    mutationFn: (values: DisableValues) =>
      withReauth(() =>
        securityApi.disableTotp(
          mode === 'code' ? { code: values.code } : { recovery_code: values.recoveryCode },
        ),
      ),
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    onPendingChange(true);
    try {
      await mutation.mutateAsync(values);
      onDisabled();
    } catch (error) {
      if (isReauthCancelled(error)) return;
      const field = mode === 'code' ? 'code' : 'recoveryCode';
      if (hasErrorCode(error, 'MFA_REQUIRED')) {
        form.setError(
          field,
          { type: 'server', message: t('settings.mfa.disable.invalid') },
          { shouldFocus: true },
        );
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const rest = applyServerErrors(error, form.setError, {
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

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-4">
      <FormAlert message={formError} />
      {mode === 'code' ? (
        <TextField
          label={t('settings.mfa.disable.codeLabel')}
          help={t('settings.mfa.disable.codeHelp')}
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={7}
          error={errors.code?.message}
          {...form.register('code')}
        />
      ) : (
        <TextField
          label={t('auth.mfa.recoveryLabel')}
          autoComplete="off"
          autoCapitalize="off"
          spellCheck={false}
          maxLength={20}
          error={errors.recoveryCode?.message}
          {...form.register('recoveryCode')}
        />
      )}
      <Button
        variant="ghost"
        size="sm"
        onClick={() => {
          form.clearErrors();
          setMode((current) => (current === 'code' ? 'recovery' : 'code'));
        }}
      >
        {mode === 'code' ? t('auth.mfa.useRecovery') : t('auth.mfa.useCode')}
      </Button>
      <div className="flex flex-col-reverse gap-3 pt-2 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button type="submit" variant="danger" loading={mutation.isPending}>
          {t('settings.mfa.disable.confirm')}
        </Button>
      </div>
    </form>
  );
}

interface DisableMfaDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onDisabled: () => void;
}

/** Turning off two-step verification needs a fresh code (codes are single-use). */
export function DisableMfaDialog({ open, onOpenChange, onDisabled }: DisableMfaDialogProps) {
  const t = useT();
  const [busy, setBusy] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      busy={busy}
      title={t('settings.mfa.disable.title')}
      description={t('settings.mfa.disable.body')}
    >
      <DisableForm
        onPendingChange={setBusy}
        onDisabled={onDisabled}
        onCancel={() => {
          onOpenChange(false);
        }}
      />
    </Dialog>
  );
}
