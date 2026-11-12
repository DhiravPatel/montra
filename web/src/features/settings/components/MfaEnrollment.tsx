import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation } from '@tanstack/react-query';
import { QRCodeSVG } from 'qrcode.react';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { sensitiveMutation } from '@/shared/api/mutationOptions';
import type { MfaSetup } from '@/shared/api/types';
import { Button } from '@/shared/components/Button';
import { CopyButton } from '@/shared/components/CopyButton';
import { TextField } from '@/shared/components/TextField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { totpCodeSchema } from '@/shared/validation/schemas';
import { securityApi } from '../api';

interface MfaEnrollmentProps {
  /** Secret material: kept in component state only, never logged or cached. */
  setup: MfaSetup;
  onActivated: (recoveryCodes: string[]) => void;
  onCancel: () => void;
}

function groupSecret(secret: string): string {
  return secret.replace(/(.{4})/g, '$1 ').trim();
}

export function MfaEnrollment({ setup, onActivated, onCancel }: MfaEnrollmentProps) {
  const t = useT();
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(() => z.object({ code: totpCodeSchema(t) }), [t]);
  const form = useForm<{ code: string }, unknown, { code: string }>({
    resolver: zodResolver(schema),
    defaultValues: { code: '' },
  });
  const mutation = useMutation({ ...sensitiveMutation, mutationFn: securityApi.activateTotp });

  const onSubmit = form.handleSubmit(async ({ code }) => {
    if (mutation.isPending) return;
    setFormError(null);
    try {
      const result = await mutation.mutateAsync(code);
      mutation.reset();
      onActivated(result.recovery_codes);
    } catch (error) {
      if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        form.setError(
          'code',
          { type: 'server', message: t('settings.mfa.activate.invalid') },
          { shouldFocus: true },
        );
      } else if (hasErrorCode(error, 'CONFLICT')) {
        setFormError(t('settings.mfa.activate.conflict'));
      } else {
        setFormError(describeError(error, t));
      }
    }
  });

  return (
    <div className="space-y-6">
      <ol className="space-y-6">
        <li className="space-y-3">
          <h3 className="font-semibold text-fg">{t('settings.mfa.enroll.step1')}</h3>
          <p className="text-sm text-fg-muted">{t('settings.mfa.enroll.step1Body')}</p>
          {/* QR codes need dark-on-light contrast in every theme. */}
          <div className="inline-block rounded-lg border border-line bg-qr-light p-3">
            <QRCodeSVG
              value={setup.otpauth_uri}
              size={176}
              level="M"
              marginSize={1}
              bgColor="#ffffff"
              fgColor="#000000"
              role="img"
              aria-label={t('settings.mfa.enroll.qrLabel')}
            />
          </div>
          <div className="space-y-2">
            <p className="text-sm text-fg-muted">{t('settings.mfa.enroll.manual')}</p>
            <div className="flex flex-wrap items-center gap-3">
              <code className="rounded-md bg-surface-muted px-3 py-2 font-mono text-sm tracking-wider text-fg select-all">
                {groupSecret(setup.secret)}
              </code>
              <CopyButton value={setup.secret} label={t('settings.mfa.enroll.copyKey')} />
            </div>
          </div>
        </li>
        <li className="space-y-3">
          <h3 className="font-semibold text-fg">{t('settings.mfa.enroll.step2')}</h3>
          <form onSubmit={onSubmit} noValidate className="max-w-xs space-y-4">
            <FormAlert message={formError} />
            <TextField
              label={t('settings.mfa.enroll.codeLabel')}
              help={t('settings.mfa.enroll.codeHelp')}
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={7}
              error={form.formState.errors.code?.message}
              {...form.register('code')}
            />
            <div className="flex flex-wrap gap-3">
              <Button type="submit" loading={mutation.isPending}>
                {t('settings.mfa.enroll.activate')}
              </Button>
              <Button variant="ghost" disabled={mutation.isPending} onClick={onCancel}>
                {t('common.cancel')}
              </Button>
            </div>
          </form>
        </li>
      </ol>
    </div>
  );
}
