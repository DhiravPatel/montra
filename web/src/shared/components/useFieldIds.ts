import { useId } from 'react';

export interface FieldIds {
  inputId: string;
  helpId: string;
  errorId: string;
  /** Value for aria-describedby: help text first, then the error. */
  describedBy: string | undefined;
}

export function useFieldIds(id: string | undefined, hasHelp: boolean, hasError: boolean): FieldIds {
  const generated = useId();
  const inputId = id ?? generated;
  const helpId = `${inputId}-help`;
  const errorId = `${inputId}-error`;
  const describedBy = [hasHelp ? helpId : null, hasError ? errorId : null]
    .filter(Boolean)
    .join(' ');
  return { inputId, helpId, errorId, describedBy: describedBy || undefined };
}
