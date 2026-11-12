import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { Button } from '@/shared/components/Button';
import { useCountdown } from '@/shared/hooks/useCountdown';
import { describeError } from '@/shared/i18n/describeError';
import { formatWait } from '@/shared/i18n/formatWait';
import { useT } from '@/shared/i18n/I18nContext';
import { authApi } from '../api';

const COOLDOWN_MS = 60_000;

/** Resends the verification email for a known address (generic, non-enumerating result). */
export function ResendVerification({ email }: { email: string }) {
  const t = useT();
  const [sentAt, setSentAt] = useState<number | null>(null);
  const remaining = useCountdown(sentAt === null ? null : sentAt + COOLDOWN_MS);
  const mutation = useMutation({
    mutationFn: () => authApi.resendVerification(email),
    onSuccess: () => {
      setSentAt(Date.now());
    },
  });
  const waiting = remaining > 0;

  return (
    <div className="space-y-2">
      <Button
        variant="secondary"
        loading={mutation.isPending}
        aria-disabled={waiting || undefined}
        onClick={() => {
          if (waiting || mutation.isPending) return;
          mutation.mutate();
        }}
      >
        {waiting
          ? t('auth.resend.wait', { wait: formatWait(t, remaining) })
          : t('auth.resend.action')}
      </Button>
      {mutation.isSuccess ? (
        <p role="status" className="text-sm text-fg-muted">
          {t('auth.resend.sent')}
        </p>
      ) : null}
      {mutation.isError ? (
        <p role="alert" className="text-sm text-danger">
          {describeError(mutation.error, t)}
        </p>
      ) : null}
    </div>
  );
}
