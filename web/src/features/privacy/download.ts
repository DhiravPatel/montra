import { api } from '@/shared/api/client';
import { ApiError, toApiError } from '@/shared/api/errors';
import type { FileAccess } from './types';

/*
 * Export downloads. The API issues a short-lived signed link
 * (`…/files/{id}/content?exp&sig&sub`: IDs and a signature only). The file
 * is fetched through the API client, so it travels the same way as every
 * other call, and is saved under the server's file name.
 */

const CONTENT_PATH =
  /\/files\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/content$/i;

const FALLBACK_NAME = 'montra-export.zip';
const RESERVED = new Set(['\\', '/', ':', '*', '?', '"', '<', '>', '|']);

/** A file name safe to save (no folders, reserved or control characters). */
export function exportFileName(name: string): string {
  const cleaned = Array.from(name, (char) =>
    RESERVED.has(char) || char.charCodeAt(0) < 32 ? '-' : char,
  )
    .join('')
    .trim()
    .slice(0, 150);
  return cleaned && !/^\.+$/.test(cleaned) ? cleaned : FALLBACK_NAME;
}

function saveBlob(blob: Blob, fileName: string): void {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  link.rel = 'noopener';
  document.body.append(link);
  link.click();
  link.remove();
  // Some browsers read the file after the click returns; release it a minute later.
  setTimeout(() => {
    URL.revokeObjectURL(url);
  }, 60_000);
}

/** Downloads a ready export. A link of another shape (a storage provider's) is opened directly. */
export async function downloadExport(access: FileAccess): Promise<void> {
  let url: URL;
  try {
    url = new URL(access.url, window.location.origin);
  } catch {
    throw new ApiError({ status: 0, code: 'UNKNOWN_ERROR', message: 'Unexpected download link.' });
  }
  const fileId = CONTENT_PATH.exec(url.pathname)?.[1];
  if (fileId) {
    const query: { exp?: string; sig?: string; sub?: string } = {};
    for (const key of ['exp', 'sig', 'sub'] as const) {
      const value = url.searchParams.get(key);
      if (value !== null) query[key] = value;
    }
    const result = await api.GET('/files/{fileId}/content', {
      params: { path: { fileId }, query },
      parseAs: 'blob',
    });
    if (!result.response.ok) throw toApiError(result.response, result.error);
    const blob = result.data ?? new Blob([], { type: access.content_type });
    saveBlob(blob, exportFileName(access.filename));
    return;
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') {
    throw new ApiError({ status: 0, code: 'UNKNOWN_ERROR', message: 'Unexpected download link.' });
  }
  window.location.assign(url.toString());
}
