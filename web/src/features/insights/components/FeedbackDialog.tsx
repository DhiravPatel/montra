import { type SubmitEvent, useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextArea } from '@/shared/components/TextArea';
import { useI18n } from '@/shared/i18n/I18nContext';
import { insightText } from '../messages';
import type { Insight } from '../types';

/** The API keeps notes up to 500 characters. */
const NOTE_MAX = 500;

interface FeedbackDialogProps {
  /** The insight being reported; null when closed. */
  insight: Insight | null;
  pending: boolean;
  error: string | null;
  onOpenChange: (open: boolean) => void;
  /** Sends `incorrect` feedback with the trimmed note (may be empty). */
  onSubmit: (note: string) => void;
}

/** "Something's wrong" feedback with an optional note (mount with a key per insight). */
export function FeedbackDialog({
  insight,
  pending,
  error,
  onOpenChange,
  onSubmit,
}: FeedbackDialogProps) {
  const { t, formatLocale } = useI18n();
  const [note, setNote] = useState('');

  const submit = (event: SubmitEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (pending) return;
    onSubmit(note.trim());
  };

  return (
    <Dialog
      open={insight !== null}
      onOpenChange={onOpenChange}
      title={t('insights.feedback.dialog.title')}
      description={t('insights.feedback.dialog.description')}
      busy={pending}
    >
      <form onSubmit={submit} className="space-y-4" noValidate>
        {insight ? (
          <p className="text-sm font-medium text-fg">
            {insightText(insight, t, formatLocale).title}
          </p>
        ) : null}
        {error ? (
          <Alert tone="danger" live="assertive">
            {error}
          </Alert>
        ) : null}
        <TextArea
          label={t('insights.feedback.dialog.note')}
          optional
          help={t('insights.feedback.dialog.noteHelp', { count: NOTE_MAX })}
          value={note}
          onChange={(event) => {
            setNote(event.target.value);
          }}
          maxLength={NOTE_MAX}
          rows={4}
        />
        <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <Button
            variant="secondary"
            aria-disabled={pending || undefined}
            onClick={() => {
              if (!pending) onOpenChange(false);
            }}
          >
            {t('common.cancel')}
          </Button>
          <Button type="submit" loading={pending}>
            {t('insights.feedback.dialog.submit')}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
