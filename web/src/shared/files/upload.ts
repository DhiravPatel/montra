import { api } from '@/shared/api/client';
import { apiData } from '@/shared/api/request';
import type { components } from '@/shared/api/schema';
import {
  browserImageCodec,
  type DecodedImage,
  type ImageCodec,
  imageKind,
  prepareImage,
} from './imageCompression';

export type FileRecord = components['schemas']['FileDTO'];
export type FilePurpose = components['schemas']['UploadIntentInput']['purpose'];

interface PurposePolicy {
  /** Value for an <input type="file" accept>. */
  accept: string;
  /** Largest file the server accepts for this purpose. */
  maxBytes: number;
}

const IMAGES = 'image/jpeg,image/png,image/webp,image/heic,.jpg,.jpeg,.png,.webp,.heic';
const MB = 1024 * 1024;

/**
 * Client-side mirror of the server's per-purpose file policy (backend
 * internal/files Policies). The server re-checks type (by content), size
 * and checksum; this only gives early, friendly feedback. Statement imports
 * offer CSV, XLSX and OFX: reading PDF statements needs AI, which is off.
 */
export const filePolicies = {
  receipt: { accept: `${IMAGES},application/pdf,.pdf`, maxBytes: 15 * MB },
  bill_document: { accept: `${IMAGES},application/pdf,.pdf`, maxBytes: 15 * MB },
  transaction_attachment: { accept: `${IMAGES},application/pdf,.pdf`, maxBytes: 15 * MB },
  goal_attachment: { accept: `${IMAGES},application/pdf,.pdf`, maxBytes: 15 * MB },
  subscription_invoice: {
    accept: 'application/pdf,image/jpeg,image/png,.pdf,.jpg,.jpeg,.png',
    maxBytes: 15 * MB,
  },
  statement_import: {
    accept:
      'text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/x-ofx,.csv,.xlsx,.ofx,.qfx',
    maxBytes: 10 * MB,
  },
  avatar: { accept: 'image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp', maxBytes: 5 * MB },
  group_attachment: { accept: `${IMAGES},application/pdf,.pdf`, maxBytes: 15 * MB },
  trip_document: { accept: `${IMAGES},application/pdf,.pdf`, maxBytes: 15 * MB },
} as const satisfies Record<FilePurpose, PurposePolicy>;

/** Thrown before any request when a file is larger than its purpose allows. */
export class FileTooLargeError extends Error {
  readonly maxBytes: number;

  constructor(maxBytes: number) {
    super('File too large');
    this.name = 'FileTooLargeError';
    this.maxBytes = maxBytes;
  }
}

/** Lowercase hex SHA-256 of the file content (Web Crypto). */
export async function sha256Hex(blob: Blob): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', await blob.arrayBuffer());
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export interface UploadOptions {
  purpose: FilePurpose;
  /** Required for group purposes (group_attachment, trip_document). */
  groupId?: string;
  signal?: AbortSignal;
  /** Image decoder/encoder (tests); defaults to the browser's. */
  codec?: ImageCodec | null;
}

/** Whether the purpose takes JPEG files (so a photo may be converted to JPEG). */
function acceptsJpeg(purpose: FilePurpose): boolean {
  return filePolicies[purpose].accept.split(',').includes('image/jpeg');
}

/**
 * The bytes that will actually be uploaded: photos for purposes that take
 * images are scaled down and stripped of metadata (imageCompression.ts);
 * everything else, PDFs included, is sent exactly as picked.
 */
export async function prepareForUpload<Image extends DecodedImage>(
  file: File,
  purpose: FilePurpose,
  codec: ImageCodec<Image> | null,
): Promise<File> {
  if (!imageKind(file) || !filePolicies[purpose].accept.includes('image/')) return file;
  const prepared = await prepareImage(file, codec, { allowJpegOutput: acceptsJpeg(purpose) });
  return prepared.file;
}

/**
 * Uploads a file through the API (spec §16): prepare it (photos are scaled
 * down and lose their metadata, COST-001), authorize an upload intent,
 * send the bytes with the single-use upload token and checksum, then
 * finalize. Resolves with the ready file record; the caller then links it
 * (receipt, import, attachment). Errors are ApiErrors from the server (for
 * example storage_quota_exceeded or an unsupported type).
 */
export async function uploadFile(picked: File, options: UploadOptions): Promise<FileRecord> {
  const { purpose, groupId, signal } = options;
  const policy = filePolicies[purpose];
  // Size, checksum, name and type all describe the prepared bytes: exactly what is sent.
  const file =
    options.codec === undefined
      ? await prepareForUpload(picked, purpose, browserImageCodec())
      : await prepareForUpload(picked, purpose, options.codec);
  if (file.size > policy.maxBytes) throw new FileTooLargeError(policy.maxBytes);
  const checksum = await sha256Hex(file);
  const intent = await apiData(
    api.POST('/files/upload-intent', {
      body: {
        purpose,
        filename: file.name || 'upload',
        content_type: file.type || 'application/octet-stream',
        size_bytes: file.size,
        checksum_sha256: checksum,
        ...(groupId ? { group_id: groupId } : {}),
      },
      ...(signal ? { signal } : {}),
    }),
  );
  const fileId = intent.file.id;
  const token = intent.headers['X-Upload-Token'] ?? '';
  await apiData(
    api.PUT('/files/{fileId}/content', {
      params: {
        path: { fileId },
        header: { 'X-Upload-Token': token, 'X-Upload-Checksum': checksum },
      },
      // The bytes go as-is (openapi-fetch would otherwise JSON-encode them).
      body: file as unknown as string,
      bodySerializer: (body: unknown) => body as BodyInit,
      headers: { 'Content-Type': 'application/octet-stream' },
      ...(signal ? { signal } : {}),
    }),
  );
  return apiData(
    api.POST('/files/{fileId}/complete', {
      params: { path: { fileId } },
      ...(signal ? { signal } : {}),
    }),
  );
}
