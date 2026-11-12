/**
 * Saves CSV text as a file. The name is the server's sanitized one (or a
 * neutral fallback); the CSV itself never passes through storage.
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

/** A neutral file name when the server's is missing or unexpected. */
export function fallbackExportName(today: string): string {
  return `group-expenses-${today}.csv`;
}
