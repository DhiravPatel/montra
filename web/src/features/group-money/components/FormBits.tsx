import { FieldError } from '@/shared/components/FieldParts';
import { Icon } from '@/shared/components/Icon';
import { cx } from '@/shared/utils/cx';
import type { Guidance } from '../splitForm';

/**
 * Live form guidance ("₹20.00 left to assign"): a polite status message,
 * marked by icon and words (never color alone). It never blocks saving;
 * validation and the server decide.
 */
export function GuidanceLine({ guidance, id }: { guidance: Guidance | null; id?: string }) {
  return (
    <p
      id={id}
      role="status"
      className={cx(
        'flex min-h-5 items-start gap-2 text-sm',
        guidance?.tone === 'warning' ? 'font-medium text-fg' : 'text-fg-muted',
      )}
    >
      {guidance ? (
        <>
          <Icon
            name={
              guidance.tone === 'success'
                ? 'check-circle'
                : guidance.tone === 'warning'
                  ? 'alert-triangle'
                  : 'info'
            }
            className={cx(
              'mt-0.5 size-4 shrink-0',
              guidance.tone === 'success' && 'text-success',
              guidance.tone === 'warning' && 'text-warning',
            )}
          />
          <span>{guidance.text}</span>
        </>
      ) : null}
    </p>
  );
}

/** A whole-section problem (e.g. the split does not add up), tied to its fieldset. */
export function SectionError({ id, message }: { id: string; message: string | undefined }) {
  return message ? <FieldError id={id}>{message}</FieldError> : null;
}
