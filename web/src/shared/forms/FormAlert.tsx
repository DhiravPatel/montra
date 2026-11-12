import type { ReactNode } from 'react';
import { Alert } from '@/shared/components/Alert';

interface FormAlertProps {
  /** Form-level problem (not tied to one field); null renders nothing. */
  message: ReactNode;
  title?: string;
  tone?: 'danger' | 'warning' | 'info';
}

/** Announced summary at the top of a form after a failed submission. */
export function FormAlert({ message, title, tone = 'danger' }: FormAlertProps) {
  if (!message) return null;
  return (
    <Alert tone={tone} title={title} live="assertive">
      {message}
    </Alert>
  );
}
