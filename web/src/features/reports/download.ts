import { api } from '@/shared/api/client';
import { ApiError, toApiError } from '@/shared/api/errors';
import type { FileAccess } from './types';

/**
 * Report downloads. The API issues a short-lived signed link
 * (`…/files/{id}/content?exp&sig&sub`): IDs and a signature only, never
 * names or amounts. The file is fetched through the API client (same origin
 * and headers as every other call) and saved under the server's file name.
 */

const CONTENT_PATH =
  /\/files\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/content$/i;

interface SignedFile {
  fileId: string;
  query: { exp?: string; sig?: string; sub?: string };
}

/** The file ID and signature of a signed content link, or null for any other link. */
export function parseSignedFileUrl(url: string, origin: string): SignedFile | null {
  let parsed: URL;
  try {
    parsed = new URL(url, origin);
  } catch {
    return null;
  }
  const fileId = CONTENT_PATH.exec(parsed.pathname)?.[1];
  if (!fileId) return null;
  const query: SignedFile['query'] = {};
  for (const key of ['exp', 'sig', 'sub'] as const) {
    const value = parsed.searchParams.get(key);
    if (value !== null) query[key] = value;
  }
  return { fileId, query };
}

const RESERVED = new Set(['\\', '/', ':', '*', '?', '"', '<', '>', '|']);

/** A file name safe to save: no folders, reserved or control characters; a neutral fallback. */
export function safeFileName(name: string, extension: string): string {
  const cleaned = Array.from(name, (char) =>
    RESERVED.has(char) || char.charCodeAt(0) < 32 ? '-' : char,
  )
    .join('')
    .trim()
    .slice(0, 150);
  if (!cleaned || /^\.+$/.test(cleaned)) return `montra-report.${extension}`;
  return cleaned;
}

/** Fetches a signed report file as a Blob through the API client. */
async function fetchSignedFile(signed: SignedFile, access: FileAccess): Promise<Blob> {
  const result = await api.GET('/files/{fileId}/content', {
    params: { path: { fileId: signed.fileId }, query: signed.query },
    parseAs: 'blob',
  });
  if (!result.response.ok) throw toApiError(result.response, result.error);
  return result.data ?? new Blob([], { type: access.content_type });
}

/**
 * Downloads a report file and saves it under the server's file name. A link
 * of another shape (e.g. a storage provider's signed URL) is opened directly:
 * it is an attachment, so the page stays where it is.
 */
export async function downloadReportFile(access: FileAccess, extension: string): Promise<void> {
  const signed = parseSignedFileUrl(access.url, window.location.origin);
  if (signed) {
    const blob = await fetchSignedFile(signed, access);
    saveBlob(blob, safeFileName(access.filename, extension));
    return;
  }
  let url: URL | null;
  try {
    url = new URL(access.url);
  } catch {
    url = null;
  }
  if (!url || (url.protocol !== 'https:' && url.protocol !== 'http:')) {
    throw new ApiError({ status: 0, code: 'UNKNOWN_ERROR', message: 'Unexpected download link.' });
  }
  window.location.assign(url.toString());
}

/** Offers a Blob to the browser as a download (the object URL is released right after). */
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
