import { useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import type { MfaSetup } from '@/shared/api/types';
import { useAuth, useCurrentUser } from '@/shared/auth/AuthContext';
import { isReauthCancelled, useReauth } from '@/shared/auth/reauth/ReauthContext';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Card } from '@/shared/components/Card';
import { ConfirmDialog } from '@/shared/components/ConfirmDialog';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { useToast } from '@/shared/components/toast/ToastContext';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { securityApi } from '../api';
import { DisableMfaDialog } from './DisableMfaDialog';
import { MfaEnrollment } from './MfaEnrollment';
import { RecoveryCodesPanel } from './RecoveryCodesPanel';

type Flow =
  | { step: 'idle' }
  | { step: 'enrolling'; setup: MfaSetup }
  | { step: 'codes'; codes: readonly string[]; context: 'enabled' | 'regenerated' };

/** Two-step verification (TOTP) setup, recovery codes and turning it off. */
export function TwoStepCard() {
  const t = useT();
  const toast = useToast();
  const user = useCurrentUser();
  const { refreshUser } = useAuth();
  const { withReauth, ensureRecentReauth } = useReauth();
  const [flow, setFlow] = useState<Flow>({ step: 'idle' });
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [regenOpen, setRegenOpen] = useState(false);
  const [regenPending, setRegenPending] = useState(false);
  const [regenError, setRegenError] = useState<string | null>(null);
  const [disableOpen, setDisableOpen] = useState(false);

  const startSetup = async () => {
    if (starting) return;
    setStarting(true);
    setError(null);
    try {
      const setup = await withReauth(securityApi.startTotpSetup);
      setFlow({ step: 'enrolling', setup });
    } catch (failure) {
      if (isReauthCancelled(failure)) return;
      if (hasErrorCode(failure, 'CONFLICT')) {
        await refreshUser(); // already enabled elsewhere
        return;
      }
      setError(describeError(failure, t));
    } finally {
      setStarting(false);
    }
  };

  const regenerate = async () => {
    if (regenPending) return;
    setRegenPending(true);
    setRegenError(null);
    try {
      const result = await withReauth(securityApi.regenerateRecoveryCodes);
      setRegenOpen(false);
      setFlow({ step: 'codes', codes: result.recovery_codes, context: 'regenerated' });
    } catch (failure) {
      if (!isReauthCancelled(failure)) setRegenError(describeError(failure, t));
    } finally {
      setRegenPending(false);
    }
  };

  const openDisable = async () => {
    setError(null);
    try {
      // Confirm identity first so the dialog can ask for a fresh, unused code.
      await ensureRecentReauth();
      setDisableOpen(true);
    } catch (failure) {
      if (!isReauthCancelled(failure)) setError(describeError(failure, t));
    }
  };

  const status = user.mfa_enabled ? (
    <StatusBadge tone="success" icon="shield-check">
      {t('settings.mfa.statusOn')}
    </StatusBadge>
  ) : (
    <StatusBadge tone="warning" icon="shield">
      {t('settings.mfa.statusOff')}
    </StatusBadge>
  );

  let body;
  if (flow.step === 'enrolling') {
    body = (
      <MfaEnrollment
        setup={flow.setup}
        onCancel={() => {
          setFlow({ step: 'idle' });
        }}
        onActivated={(codes) => {
          setFlow({ step: 'codes', codes, context: 'enabled' });
          void refreshUser();
        }}
      />
    );
  } else if (flow.step === 'codes') {
    body = (
      <RecoveryCodesPanel
        codes={flow.codes}
        context={flow.context}
        onDone={() => {
          setFlow({ step: 'idle' });
        }}
      />
    );
  } else if (user.mfa_enabled) {
    body = (
      <div className="space-y-4">
        <p className="text-sm text-fg-muted">{t('settings.mfa.onBody')}</p>
        <div className="flex flex-wrap gap-3">
          <Button
            variant="secondary"
            onClick={() => {
              setRegenError(null);
              setRegenOpen(true);
            }}
          >
            {t('settings.mfa.regenerate.action')}
          </Button>
          <Button variant="danger" onClick={() => void openDisable()}>
            {t('settings.mfa.disable.action')}
          </Button>
        </div>
      </div>
    );
  } else {
    body = (
      <div className="space-y-4">
        <p className="text-sm text-fg-muted">{t('settings.mfa.offBody')}</p>
        <Button loading={starting} onClick={() => void startSetup()}>
          {t('settings.mfa.setup.action')}
        </Button>
      </div>
    );
  }

  return (
    <Card
      title={t('settings.mfa.title')}
      description={t('settings.mfa.description')}
      actions={status}
    >
      {error ? (
        <Alert tone="danger" live="assertive" className="mb-4">
          {error}
        </Alert>
      ) : null}
      {body}
      <ConfirmDialog
        open={regenOpen}
        onOpenChange={setRegenOpen}
        tone="primary"
        title={t('settings.mfa.regenerate.title')}
        description={t('settings.mfa.regenerate.body')}
        confirmLabel={t('settings.mfa.regenerate.confirm')}
        onConfirm={() => void regenerate()}
        pending={regenPending}
        error={regenError}
      />
      <DisableMfaDialog
        open={disableOpen}
        onOpenChange={setDisableOpen}
        onDisabled={() => {
          setDisableOpen(false);
          toast.show({ tone: 'success', title: t('settings.mfa.disable.done') });
          void refreshUser();
        }}
      />
    </Card>
  );
}
