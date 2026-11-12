import { type ReactNode, useState } from 'react';
import { Alert } from '@/shared/components/Alert';
import { Button } from '@/shared/components/Button';
import { Dialog } from '@/shared/components/Dialog';
import { TextArea } from '@/shared/components/TextArea';
import { useT } from '@/shared/i18n/I18nContext';

interface TextPromptDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: ReactNode;
  label: string;
  help?: string;
  /** Text is required (a reason to dispute or void); otherwise it may stay empty. */
  required?: boolean;
  requiredMessage?: string;
  maxLength: number;
  confirmLabel: string;
  tone?: 'danger' | 'primary';
  pending: boolean;
  /** Error from the last attempt, shown inside the dialog. */
  error: string | null;
  onConfirm: (text: string) => void;
  /** Extra fields shown under the text (e.g. an account to record it in). */
  children?: ReactNode;
}

/**
 * A confirmation that asks for a short text: a reason to dispute or void,
 * or a note when resolving. Cancel stays available until an action runs.
 */
export function TextPromptDialog(props: TextPromptDialogProps) {
  const { open, onOpenChange, title, description, pending } = props;
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      description={description}
      busy={pending}
    >
      {open ? <TextPromptBody {...props} /> : null}
    </Dialog>
  );
}

function TextPromptBody({
  onOpenChange,
  label,
  help,
  required = false,
  requiredMessage,
  maxLength,
  confirmLabel,
  tone = 'primary',
  pending,
  error,
  onConfirm,
  children,
}: TextPromptDialogProps) {
  const t = useT();
  const [text, setText] = useState('');
  const [missing, setMissing] = useState(false);
  return (
    <form
      noValidate
      className="space-y-4"
      onSubmit={(event) => {
        event.preventDefault();
        if (pending) return;
        const value = text.trim();
        if (required && !value) {
          setMissing(true);
          return;
        }
        onConfirm(value);
      }}
    >
      {error ? (
        <Alert tone="danger" live="assertive">
          {error}
        </Alert>
      ) : null}
      <TextArea
        label={label}
        help={help}
        optional={!required}
        maxLength={maxLength}
        value={text}
        error={missing ? (requiredMessage ?? t('groupMoney.prompt.required')) : undefined}
        onChange={(event) => {
          setText(event.target.value);
          if (missing && event.target.value.trim()) setMissing(false);
        }}
      />
      {children}
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
        <Button type="submit" variant={tone} loading={pending}>
          {confirmLabel}
        </Button>
      </div>
    </form>
  );
}
