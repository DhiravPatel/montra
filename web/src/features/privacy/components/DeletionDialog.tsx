import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';
import { hasErrorCode } from '@/shared/api/errors';
import { isReauthCancelled, useReauth } from '@/shared/auth/reauth/ReauthContext';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextArea } from '@/shared/components/TextArea';
import { TextField } from '@/shared/components/TextField';
import { FormAlert } from '@/shared/forms/FormAlert';
import { describeError } from '@/shared/i18n/describeError';
import { useT } from '@/shared/i18n/I18nContext';
import { privacyApi } from '../api';
import { confirmWordMismatch, isDeletionAlreadyScheduled } from '../errors';
import { privacyKeys } from '../keys';
import type { Deletion } from '../types';

/** The word the API requires (in every language) to confirm deletion. */
const DELETE_WORD = 'DELETE';
const REASON_MAX = 1000;

interface Values {
  confirm: string;
  reason: string;
}

interface DeletionFormProps {
  graceDays: number | null;
  onScheduled: (deletion: Deletion) => void;
  onCancel: () => void;
  onPendingChange: (pending: boolean) => void;
}

function DeletionForm({ graceDays, onScheduled, onCancel, onPendingChange }: DeletionFormProps) {
  const t = useT();
  const queryClient = useQueryClient();
  const { withReauth } = useReauth();
  const [formError, setFormError] = useState<string | null>(null);
  const schema = useMemo(
    () =>
      z.object({
        confirm: z
          .string()
          .trim()
          .refine((value) => value.toUpperCase() === DELETE_WORD, {
            error: t('privacySettings.deletion.confirmMismatch', { word: DELETE_WORD }),
          }),
        reason: z
          .string()
          .trim()
          .max(REASON_MAX, { error: t('validation.maxLength', { max: REASON_MAX }) }),
      }),
    [t],
  );
  const form = useForm<Values, unknown, Values>({
    resolver: zodResolver(schema),
    defaultValues: { confirm: '', reason: '' },
  });
  const mutation = useMutation({
    mutationFn: (reason: string) =>
      withReauth(() =>
        privacyApi.requestDeletion({
          confirm: DELETE_WORD,
          ...(reason ? { reason } : {}),
        }),
      ),
    onSuccess: (deletion) => {
      queryClient.setQueryData(privacyKeys.deletion(), deletion);
    },
  });

  const onSubmit = form.handleSubmit(async (values) => {
    if (mutation.isPending) return;
    setFormError(null);
    onPendingChange(true);
    try {
      const deletion = await mutation.mutateAsync(values.reason);
      onScheduled(deletion);
    } catch (error) {
      if (isReauthCancelled(error)) return;
      const mismatch = confirmWordMismatch(error);
      if (isDeletionAlreadyScheduled(error)) {
        // Already scheduled (perhaps from another device): show the current state.
        void queryClient.invalidateQueries({ queryKey: privacyKeys.deletion() });
        setFormError(t('privacySettings.deletion.alreadyScheduled'));
      } else if (mismatch !== null) {
        form.setError(
          'confirm',
          {
            type: 'server',
            message: t('privacySettings.deletion.confirmMismatch', {
              word: mismatch || DELETE_WORD,
            }),
          },
          { shouldFocus: true },
        );
      } else if (hasErrorCode(error, 'VALIDATION_ERROR')) {
        const reason = error.details.some((detail) => detail.field === 'body.reason');
        if (reason) {
          form.setError(
            'reason',
            { type: 'server', message: t('validation.maxLength', { max: REASON_MAX }) },
            { shouldFocus: true },
          );
        } else {
          form.setError(
            'confirm',
            {
              type: 'server',
              message: t('privacySettings.deletion.confirmMismatch', { word: DELETE_WORD }),
            },
            { shouldFocus: true },
          );
        }
      } else {
        setFormError(describeError(error, t));
      }
    } finally {
      onPendingChange(false);
    }
  });

  const { errors } = form.formState;
  return (
    <form onSubmit={onSubmit} noValidate className="space-y-5">
      <FormAlert message={formError} />
      <p className="text-sm text-fg">
        {graceDays !== null
          ? t('privacySettings.deletion.dialogGrace', { count: graceDays })
          : t('privacySettings.deletion.dialogGraceUnknown')}
      </p>
      <TextField
        label={t('privacySettings.deletion.confirmLabel', { word: DELETE_WORD })}
        help={t('privacySettings.deletion.confirmHelp')}
        autoComplete="off"
        autoCapitalize="characters"
        spellCheck={false}
        error={errors.confirm?.message}
        {...form.register('confirm')}
      />
      <TextArea
        label={t('privacySettings.deletion.reason')}
        help={t('privacySettings.deletion.reasonHelp')}
        optional
        rows={3}
        maxLength={REASON_MAX}
        error={errors.reason?.message}
        {...form.register('reason')}
      />
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button variant="secondary" disabled={mutation.isPending} onClick={onCancel}>
          {t('privacySettings.deletion.keepAccount')}
        </Button>
        <Button type="submit" variant="danger" loading={mutation.isPending}>
          {t('privacySettings.deletion.schedule')}
        </Button>
      </div>
    </form>
  );
}

interface DeletionDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  graceDays: number | null;
  onScheduled: (deletion: Deletion) => void;
}

/** Final confirmation before scheduling account deletion (typed word + re-authentication). */
export function DeletionDialog({
  open,
  onOpenChange,
  graceDays,
  onScheduled,
}: DeletionDialogProps) {
  const t = useT();
  const [busy, setBusy] = useState(false);
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      busy={busy}
      title={t('privacySettings.deletion.dialogTitle')}
      description={t('privacySettings.deletion.dialogBody')}
    >
      {open ? (
        <DeletionForm
          graceDays={graceDays}
          onPendingChange={setBusy}
          onScheduled={onScheduled}
          onCancel={() => {
            onOpenChange(false);
          }}
        />
      ) : null}
    </Dialog>
  );
}
