import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Checkbox } from '@/shared/components/Checkbox';
import { Dialog } from '@/shared/components/Dialog';
import { useToast } from '@/shared/components/toast/ToastContext';
import { invalidateFinance } from '@/shared/finance/keys';
import { useT } from '@/shared/i18n/I18nContext';
import { integrationsApi } from '../api';
import { integrationErrorMessage } from '../errors';
import { integrationsKeys } from '../keys';
import type { Connection } from '../types';

interface DisconnectDialogProps {
  connection: Connection;
  providerName: string;
  /** `delete-data` removes what an already-ended connection imported. */
  mode: 'disconnect' | 'delete-data';
  onClose: () => void;
}

/**
 * Confirms a disconnection and says what happens to imported data: it
 * stays unless the user asks to delete it (DELETE ?confirm=true and
 * optionally delete_data=true, which voids the imported transactions).
 */
export function DisconnectDialog({
  connection,
  providerName,
  mode,
  onClose,
}: DisconnectDialogProps) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [deleteData, setDeleteData] = useState(mode === 'delete-data');
  const [error, setError] = useState<string | null>(null);
  const disconnect = useMutation({
    mutationFn: (withData: boolean) => integrationsApi.disconnect(connection.id, withData),
    onSettled: async (result) => {
      await queryClient.invalidateQueries({ queryKey: integrationsKeys.all });
      // Voided transactions change balances, lists and reports.
      if (result && result.deleted_records > 0) await invalidateFinance(queryClient);
    },
  });

  const confirm = () => {
    if (disconnect.isPending) return;
    setError(null);
    disconnect.mutate(deleteData, {
      onSuccess: (result) => {
        toast.show({
          tone: 'success',
          title:
            mode === 'delete-data'
              ? t('integrations.disconnect.dataDeleted')
              : t('integrations.disconnect.done', { provider: providerName }),
          description: deleteData
            ? t('integrations.disconnect.deletedCount', { count: result.deleted_records })
            : t('integrations.disconnect.kept'),
        });
        onClose();
      },
      onError: (failure) => {
        setError(integrationErrorMessage(failure, t, 'disconnect'));
      },
    });
  };

  return (
    <Dialog
      open
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
      title={
        mode === 'delete-data'
          ? t('integrations.disconnect.dataTitle')
          : t('integrations.disconnect.title', { provider: providerName })
      }
      description={
        mode === 'delete-data'
          ? t('integrations.disconnect.dataBody', { provider: providerName })
          : t('integrations.disconnect.body', { provider: providerName })
      }
      busy={disconnect.isPending}
      size="md"
    >
      <div className="space-y-4">
        {error ? (
          <Alert tone="danger" live="assertive">
            {error}
          </Alert>
        ) : null}
        {mode === 'disconnect' ? (
          <Checkbox
            label={t('integrations.disconnect.deleteData')}
            description={t('integrations.disconnect.deleteDataHelp')}
            checked={deleteData}
            disabled={disconnect.isPending}
            onChange={(event) => {
              setDeleteData(event.target.checked);
            }}
          />
        ) : (
          <p className="text-sm text-fg-muted">{t('integrations.disconnect.deleteDataHelp')}</p>
        )}
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button variant="secondary" disabled={disconnect.isPending} onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button variant="danger" loading={disconnect.isPending} onClick={confirm}>
            {mode === 'delete-data'
              ? t('integrations.disconnect.dataConfirm')
              : t('integrations.disconnect.confirm')}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
