/** The only file name accepted from the server: neutral, with the user's local date. */
const SERVER_NAME = /^goal-contributions-\d{4}-\d{2}-\d{2}\.csv$/;

/**
 * The file name from a `Content-Disposition` header (`filename="…"` or the
 * RFC 5987 `filename*=UTF-8''…` form), accepted only when it is the API's
 * neutral `goal-contributions-YYYY-MM-DD.csv`, so a goal's name never ends up
 * in download lists or sync folders. Null otherwise (use the fallback).
 */
export function exportFileName(disposition: string | null): string | null {
  if (!disposition) return null;
  const extended = /filename\*\s*=\s*(?:UTF-8|utf-8)?''([^;]+)/.exec(disposition);
  const plain = /filename\s*=\s*"?([^";]+)"?/.exec(disposition);
  let raw = extended?.[1] ?? plain?.[1] ?? '';
  try {
    raw = decodeURIComponent(raw.trim());
  } catch {
    return null;
  }
  return SERVER_NAME.test(raw) ? raw : null;
}

/** The fallback name when the server's is missing or not the expected neutral one. */
export function fallbackExportName(today: string): string {
  return `goal-contributions-${today}.csv`;
}

/**
 * Saves CSV text as a file. The name is neutral (no goal name or amounts):
 * file names end up in download lists and sync folders.
 */
export function saveCsvFile(fileName: string, csv: string): void {
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  link.rel = 'noopener';
  document.body.append(link);
  link.click();
  link.remove();
  // Revoke after the click has been processed.
  setTimeout(() => {
    URL.revokeObjectURL(url);
  }, 0);
}
