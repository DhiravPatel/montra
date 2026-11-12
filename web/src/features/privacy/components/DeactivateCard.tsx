import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { useAuth } from '@/shared/auth/AuthContext';
import { isReauthCancelled, useReauth } from '@/shared/auth/reauth/ReauthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { Icon } from '@/shared/components/Icon';
import { useToast } from '@/shared/components/toast/ToastContext';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { privacyApi } from '../api';

/**
 * Deactivation: reversible (signing in again reactivates the account), signs
 * out every session including this one. Needs a recent re-authentication.
 */
export function DeactivateCard() {
  const t = useT();
  const toast = useToast();
  const { signOut } = useAuth();
  const { withReauth } = useReauth();
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const mutation = useMutation({ mutationFn: () => withReauth(privacyApi.deactivate) });

  const confirm = () => {
    if (mutation.isPending) return;
    setError(null);
    mutation.mutate(undefined, {
      onSuccess: () => {
        setOpen(false);
        toast.show({
          tone: 'info',
          title: t('privacySettings.deactivate.done'),
          description: t('privacySettings.deactivate.doneBody'),
        });
        // The API already ended every session; this clears this tab's state.
        void signOut('current').catch(() => undefined);
      },
      onError: (failure) => {
        if (isReauthCancelled(failure)) return;
        setError(describeError(failure, t));
      },
    });
  };

  return (
    <Card
      title={t('privacySettings.deactivate.title')}
      description={t('privacySettings.deactivate.description')}
    >
      <ul className="mb-5 list-disc space-y-1 ps-5 text-sm text-fg-muted">
        <li>{t('privacySettings.deactivate.signOut')}</li>
        <li>{t('privacySettings.deactivate.kept')}</li>
        <li>{t('privacySettings.deactivate.return')}</li>
      </ul>
      <Button
        variant="secondary"
        onClick={() => {
          setError(null);
          setOpen(true);
        }}
      >
        <Icon name="pause" className="size-4" />
        {t('privacySettings.deactivate.action')}
      </Button>
      <ConfirmDialog
        open={open}
        onOpenChange={(next) => {
          if (!mutation.isPending) setOpen(next);
        }}
        title={t('privacySettings.deactivate.confirm.title')}
        description={t('privacySettings.deactivate.confirm.body')}
        confirmLabel={t('privacySettings.deactivate.confirm.action')}
        onConfirm={confirm}
        pending={mutation.isPending}
        error={error}
      />
    </Card>
  );
}
