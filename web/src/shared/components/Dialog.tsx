import * as RadixDialog from '@radix-ui/react-dialog';
import type { ReactNode, RefObject } from 'react';
import { useT } from '@/shared/i18n/I18nContext';
import { cx } from '@/shared/utils/cx';
import { IconButton } from './IconButton';

interface DialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: ReactNode;
  children?: ReactNode;
  /** While true the dialog cannot be dismissed (an action is running). */
  busy?: boolean;
  size?: 'sm' | 'md' | 'lg';
  /** Element to focus when the dialog opens (defaults to the first focusable). */
  initialFocusRef?: RefObject<HTMLElement | null>;
}

const widths = { sm: 'max-w-sm', md: 'max-w-md', lg: 'max-w-lg' } as const;

/** Accessible modal dialog (Radix): focus trap, Escape to close, labelled by its title. */
export function Dialog({
  open,
  onOpenChange,
  title,
  description,
  children,
  busy = false,
  size = 'md',
  initialFocusRef,
}: DialogProps) {
  const t = useT();
  return (
    <RadixDialog.Root
      open={open}
      onOpenChange={(next) => {
        if (busy && !next) return;
        onOpenChange(next);
      }}
    >
      <RadixDialog.Portal>
        <RadixDialog.Overlay className="fixed inset-0 z-40 bg-overlay" />
        <RadixDialog.Content
          className={cx(
            'fixed inset-x-4 top-1/2 z-50 mx-auto max-h-[calc(100dvh-2rem)] -translate-y-1/2 overflow-y-auto',
            'rounded-xl border border-line bg-surface p-6 text-fg shadow-overlay',
            widths[size],
          )}
          onOpenAutoFocus={
            initialFocusRef
              ? (event) => {
                  event.preventDefault();
                  initialFocusRef.current?.focus();
                }
              : undefined
          }
          {...(description ? {} : { 'aria-describedby': undefined })}
        >
          <RadixDialog.Title className="pe-10 text-lg font-semibold">{title}</RadixDialog.Title>
          {description ? (
            <RadixDialog.Description asChild>
              <div className="mt-2 text-sm text-fg-muted">{description}</div>
            </RadixDialog.Description>
          ) : null}
          <div className="mt-5">{children}</div>
          <RadixDialog.Close asChild>
            <IconButton
              icon="x"
              label={t('common.close')}
              size="sm"
              disabled={busy}
              className="absolute end-3 top-3"
            />
          </RadixDialog.Close>
        </RadixDialog.Content>
      </RadixDialog.Portal>
    </RadixDialog.Root>
  );
}
