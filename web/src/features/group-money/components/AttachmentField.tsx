import { type ReactNode, useId, useRef } from 'react';
import { Button } from '@/shared/components/Button';
import { FieldError, FieldHelp } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { filePolicies } from '@/shared/files/upload';
import { useI18n } from '@/shared/i18n/I18nContext';
import { fileProblem, fileProblemMessage, formatFileSize } from '@/features/receipts/uploads';

interface AttachmentFieldProps {
  label: string;
  file: File | null;
  /** A file problem found before upload, or an upload error. */
  error: string | null;
  onChange: (file: File | null, problem: string | null) => void;
  /** Shown above the picker (e.g. "keep the current attachment"). */
  children?: ReactNode;
}

/**
 * An optional photo or PDF (a receipt or proof of payment), uploaded to the
 * group (purpose group_attachment) when the form is saved. Size and type are
 * checked early; the server checks the content again.
 */
export function AttachmentField({ label, file, error, onChange, children }: AttachmentFieldProps) {
  const { t, formatLocale } = useI18n();
  const inputId = useId();
  const helpId = `${inputId}-help`;
  const errorId = `${inputId}-error`;
  const input = useRef<HTMLInputElement>(null);
  const policy = filePolicies.group_attachment;

  return (
    <div className="space-y-2">
      <label htmlFor={inputId} className="block text-sm font-medium text-fg">
        {label} <span className="font-normal text-fg-muted">({t('common.optional')})</span>
      </label>
      {children}
      <input
        ref={input}
        id={inputId}
        type="file"
        accept={policy.accept}
        aria-describedby={[helpId, error ? errorId : null].filter(Boolean).join(' ')}
        aria-invalid={error ? true : undefined}
        className="block w-full text-sm text-fg file:me-3 file:rounded-md file:border file:border-line-strong file:bg-surface file:px-3 file:py-2 file:text-sm file:font-medium file:text-fg"
        onChange={(event) => {
          const picked = event.target.files?.[0] ?? null;
          if (!picked) {
            onChange(null, null);
            return;
          }
          const problem = fileProblem(picked, 'group_attachment');
          onChange(
            problem ? null : picked,
            problem ? fileProblemMessage(problem, 'group_attachment', t, formatLocale) : null,
          );
          if (problem && input.current) input.current.value = '';
        }}
      />
      <FieldHelp id={helpId}>
        {t('groupMoney.attachment.help', { size: formatFileSize(policy.maxBytes, formatLocale) })}
      </FieldHelp>
      {file ? (
        <div className="flex flex-wrap items-center gap-3 text-sm text-fg">
          <Icon name="paperclip" className="size-4 text-fg-muted" />
          <span className="min-w-0 break-all">{file.name}</span>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              onChange(null, null);
              if (input.current) input.current.value = '';
            }}
          >
            {t('groupMoney.attachment.remove')}
          </Button>
        </div>
      ) : null}
      {error ? <FieldError id={errorId}>{error}</FieldError> : null}
    </div>
  );
}
