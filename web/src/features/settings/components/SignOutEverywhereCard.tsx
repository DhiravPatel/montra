import { useState } from 'react';
import { useAuth } from '@/shared/auth/AuthContext';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';

export function SignOutEverywhereCard() {
  const t = useT();
  const { signOut } = useAuth();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const confirm = () => {
    if (pending) return;
    setPending(true);
    setError(null);
    signOut('everywhere')
      .catch((failure: unknown) => {
        setError(describeError(failure, t));
      })
      .finally(() => {
        setPending(false);
      });
  };

  return (
    <Card title={t('settings.signOutAll.title')} description={t('settings.signOutAll.description')}>
      <Button
        variant="danger"
        onClick={() => {
          setError(null);
          setOpen(true);
        }}
      >
        {t('settings.signOutAll.action')}
      </Button>
      <ConfirmDialog
        open={open}
        onOpenChange={setOpen}
        title={t('settings.signOutAll.confirm.title')}
        description={t('settings.signOutAll.confirm.body')}
        confirmLabel={t('settings.signOutAll.action')}
        onConfirm={confirm}
        pending={pending}
        error={error}
      />
    </Card>
  );
}
