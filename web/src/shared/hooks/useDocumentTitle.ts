import { useEffect } from 'react';

/**
 * Sets the browser tab title. Pass only non-sensitive page names: never
 * emails, names, amounts, or other personal data.
 */
export function useDocumentTitle(title: string): void {
  useEffect(() => {
    document.title = title ? `${title} · Montra` : 'Montra';
  }, [title]);
}
