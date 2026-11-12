import { useMutation, useQueryClient } from '@tanstack/react-query';
import { type SubmitEvent, useState } from 'react';
import { hasErrorCode } from '@/shared/api/errors';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextArea } from '@/shared/components/TextArea';
import { useToast } from '@/shared/components/toast/ToastContext';
import { useT } from '@/shared/i18n/I18nContext';
import { moderationApi } from '../../api';
import { reverseErrorMessage } from '../../errors';
import { moderationKeys } from '../../keys';

const NOTE_MAX = 500;

/**
 * Reverses an action (POST /moderation/actions/{id}/reverse): the effect is
 * undone where possible and the record is kept, marked as reversed. Opening
 * this dialog is the confirmation step.
 */
export function ReverseDialog({
  actionId,
  open,
  onOpenChange,
}: {
  actionId: string | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const t = useT();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const reverse = useMutation({
    mutationFn: ({ id, text }: { id: string; text: string }) => moderationApi.reverse(id, text),
  });

  const close = (next: boolean) => {
    if (!next) {
      setNote('');
      setError(null);
    }
    onOpenChange(next);
  };

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!actionId || reverse.isPending) return;
    const text = note.trim();
    if (text.length > NOTE_MAX) {
      setError(t('validation.maxLength', { max: NOTE_MAX }));
      return;
    }
    setError(null);
    reverse.mutate(
      { id: actionId, text },
      {
        onSuccess: () => {
          void queryClient.invalidateQueries({ queryKey: moderationKeys.staff() });
          toast.show({ tone: 'success', title: t('moderation.staff.reverse.done') });
          close(false);
        },
        onError: (failure) => {
          if (hasErrorCode(failure, 'CONFLICT')) {
            // Already reversed: nothing more to do here.
            toast.show({ tone: 'info', title: reverseErrorMessage(failure, t) });
            close(false);
            return;
          }
          setError(reverseErrorMessage(failure, t));
        },
      },
    );
  };

  return (
    <Dialog
      open={open}
      onOpenChange={close}
      title={t('moderation.staff.reverse.title')}
      description={t('moderation.staff.reverse.description')}
      busy={reverse.isPending}
    >
      <form onSubmit={submit} noValidate className="space-y-5">
        {error ? (
          <Alert tone="danger" live="assertive">
            {error}
          </Alert>
        ) : null}
        {actionId ? (
          <p className="text-sm text-fg-muted">
            {t('moderation.staff.reverse.actionId')}{' '}
            <code className="font-mono break-all text-fg">{actionId}</code>
          </p>
        ) : null}
        <TextArea
          label={t('moderation.staff.reverse.note')}
          optional
          help={t('moderation.staff.reverse.noteHelp')}
          maxLength={NOTE_MAX}
          value={note}
          onChange={(event) => {
            setNote(event.target.value);
          }}
        />
        <Alert tone="info">{t('moderation.staff.audit.short')}</Alert>
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={reverse.isPending}
            onClick={() => {
              close(false);
            }}
          >
            {t('common.cancel')}
          </Button>
          <Button type="submit" loading={reverse.isPending}>
            {t('moderation.staff.reverse.confirm')}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
