import type { ReactNode } from 'react';
import { useT } from '@/shared/i18n/I18nContext';
import { Alert } from './Alert';
import { Button } from './Button';
import { Dialog } from './Dialog';

interface ConfirmDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: ReactNode;
  confirmLabel: string;
  cancelLabel?: string;
  tone?: 'danger' | 'primary';
  onConfirm: () => void;
  pending?: boolean;
  /** Error from the last attempt, shown inside the dialog. */
  error?: string | null;
}

/** Confirmation for destructive or significant actions. Cancel receives focus first. */
export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel,
  cancelLabel,
  tone = 'danger',
  onConfirm,
  pending = false,
  error,
}: ConfirmDialogProps) {
  const t = useT();
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      description={description}
      busy={pending}
      size="sm"
    >
      {error ? (
        <Alert tone="danger" live="assertive" className="mb-4">
          {error}
        </Alert>
      ) : null}
      <div className="flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
        <Button
          variant="secondary"
          disabled={pending}
          onClick={() => {
            onOpenChange(false);
          }}
        >
          {cancelLabel ?? t('common.cancel')}
        </Button>
        <Button variant={tone} loading={pending} onClick={onConfirm}>
          {confirmLabel}
        </Button>
      </div>
    </Dialog>
  );
}
