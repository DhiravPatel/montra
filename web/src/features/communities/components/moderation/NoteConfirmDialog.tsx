import { type ReactNode, useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextArea } from '@/shared/components/TextArea';
import { useT } from '@/shared/i18n/I18nContext';

/**
 * A confirmation with an optional note for the moderation log (reversing an
 * action, deciding an appeal). Cancel is the first button; Escape closes
 * unless the action is running.
 */
export function NoteConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  noteLabel,
  noteHelp,
  noteMax,
  confirmLabel,
  tone = 'primary',
  pending,
  error,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: ReactNode;
  noteLabel: string;
  noteHelp?: string;
  noteMax: number;
  confirmLabel: string;
  tone?: 'primary' | 'danger';
  pending: boolean;
  error: string | null;
  onConfirm: (note: string) => void;
}) {
  const t = useT();
  const [note, setNote] = useState('');
  const [noteError, setNoteError] = useState<string | null>(null);
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) {
          setNote('');
          setNoteError(null);
        }
        onOpenChange(next);
      }}
      title={title}
      description={description}
      busy={pending}
    >
      <div className="space-y-5">
        {error ? (
          <Alert tone="danger" live="assertive">
            {error}
          </Alert>
        ) : null}
        <TextArea
          label={noteLabel}
          help={noteHelp}
          optional
          rows={3}
          maxLength={noteMax}
          value={note}
          error={noteError ?? undefined}
          onChange={(event) => {
            setNote(event.target.value);
            setNoteError(null);
          }}
        />
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            disabled={pending}
            onClick={() => {
              onOpenChange(false);
            }}
          >
            {t('common.cancel')}
          </Button>
          <Button
            variant={tone}
            loading={pending}
            onClick={() => {
              const text = note.trim();
              if (Array.from(text).length > noteMax) {
                setNoteError(t('validation.maxLength', { max: noteMax }));
                return;
              }
              onConfirm(text);
            }}
          >
            {confirmLabel}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
