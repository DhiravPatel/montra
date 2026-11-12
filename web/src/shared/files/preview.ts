import { api } from '@/shared/api/client';
import { networkError, toApiError } from '@/shared/api/errors';
import { apiData } from '@/shared/api/request';
import type { components } from '@/shared/api/schema';
import { isAbortError } from './uploadChecks';

export type FileAccess = components['schemas']['Access'];

/** A file ready to show: images as a `data:` URL, other files (PDF) as `src: null`. */
export interface FilePreview {
  contentType: string;
  src: string | null;
}

function signalOption(signal?: AbortSignal) {
  return signal ? { signal } : {};
}

/** A short-lived signed link to one of your files (authorization is checked on every call). */
export function fileAccess(fileId: string, signal?: AbortSignal): Promise<FileAccess> {
  return apiData(
    api.GET('/files/{fileId}/access', { params: { path: { fileId } }, ...signalOption(signal) }),
  );
}

function readAsDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') resolve(reader.result);
      else reject(new Error('Unexpected preview data'));
    };
    reader.onerror = () => {
      reject(reader.error ?? new Error('Preview could not be read'));
    };
    reader.readAsDataURL(blob);
  });
}

/**
 * Downloads an image through its short-lived signed link and keeps it as a
 * `data:` URL: the app's Content-Security-Policy allows `data:` images but
 * not images from the storage origin. Nothing is written to disk or storage.
 */
export async function loadFilePreview(fileId: string, signal?: AbortSignal): Promise<FilePreview> {
  const access = await fileAccess(fileId, signal);
  const contentType = access.content_type;
  if (!contentType.startsWith('image/')) return { contentType, src: null };
  let response: Response;
  try {
    // The link is signed for this user and expires in minutes: no cookies or referrer needed.
    response = await fetch(access.url, {
      credentials: 'omit',
      referrerPolicy: 'no-referrer',
      ...signalOption(signal),
    });
  } catch (error) {
    if (isAbortError(error)) throw error;
    throw networkError(error);
  }
  if (!response.ok) throw toApiError(response, null);
  const bytes = await response.arrayBuffer();
  return { contentType, src: await readAsDataUrl(new Blob([bytes], { type: contentType })) };
}
