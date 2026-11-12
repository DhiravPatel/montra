import { isApiError } from '@/shared/api/errors';
import { type FilePurpose, FileTooLargeError, filePolicies } from '@/shared/files/upload';
import { describeError } from '@/shared/i18n/describeError';
import type { Translate } from '@/shared/i18n/types';

/*
 * Upload helpers for receipt pages and transaction attachments: early,
 * friendly checks before any request (the server re-checks the content,
 * size and checksum) and localized reasons for refused uploads.
 */

/** A file size such as "15 MB" or "200 kB" in the interface locale. */
export function formatFileSize(bytes: number, locale: string): string {
  const units = ['byte', 'kilobyte', 'megabyte', 'gigabyte'] as const;
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return new Intl.NumberFormat(locale, {
    style: 'unit',
    unit: units[unit],
    unitDisplay: 'short',
    maximumFractionDigits: unit === 0 ? 0 : 1,
  }).format(value);
}

// The server decides by the file name's extension first (then by content).
const EXTENSION_ALIASES: Readonly<Record<string, string>> = { jpeg: 'jpg', heif: 'heic' };

function extensionOf(name: string): string {
  const dot = name.lastIndexOf('.');
  const extension = dot >= 0 ? name.slice(dot + 1).toLowerCase() : '';
  return EXTENSION_ALIASES[extension] ?? extension;
}

function acceptedExtensions(purpose: FilePurpose): ReadonlySet<string> {
  return new Set(
    filePolicies[purpose].accept
      .split(',')
      .filter((token) => token.startsWith('.'))
      .map((token) => extensionOf(token)),
  );
}

export type FileProblem = 'empty' | 'tooLarge' | 'type';

/** Problems visible before uploading (null when the file can be sent). */
export function fileProblem(file: File, purpose: FilePurpose): FileProblem | null {
  if (!acceptedExtensions(purpose).has(extensionOf(file.name))) return 'type';
  if (file.size === 0) return 'empty';
  if (file.size > filePolicies[purpose].maxBytes) return 'tooLarge';
  return null;
}

export function fileProblemMessage(
  problem: FileProblem,
  purpose: FilePurpose,
  t: Translate,
  locale: string,
): string {
  switch (problem) {
    case 'empty':
      return t('receipts.upload.errors.empty');
    case 'type':
      return t('receipts.upload.errors.type');
    case 'tooLarge':
      return uploadErrorMessage(new FileTooLargeError(filePolicies[purpose].maxBytes), t, locale);
  }
}

function byteParam(params: unknown, key: string): number | null {
  if (typeof params !== 'object' || params === null || !(key in params)) return null;
  const value: unknown = (params as Record<string, unknown>)[key];
  const parsed =
    typeof value === 'number'
      ? value
      : typeof value === 'string'
        ? Number.parseInt(value, 10)
        : NaN;
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

/** Why an upload was refused, in the interface language. */
export function uploadErrorMessage(error: unknown, t: Translate, locale: string): string {
  if (error instanceof FileTooLargeError) {
    return t('receipts.upload.errors.tooLarge', { size: formatFileSize(error.maxBytes, locale) });
  }
  if (isApiError(error)) {
    const quota = error.details.find((detail) => detail.code === 'storage_quota_exceeded');
    if (quota) {
      const allowance = byteParam(quota.params, 'quota_bytes');
      return allowance
        ? t('receipts.upload.errors.quota', { size: formatFileSize(allowance, locale) })
        : t('receipts.upload.errors.quotaGeneric');
    }
    switch (error.code) {
      case 'PAYLOAD_TOO_LARGE':
        return t('receipts.upload.errors.tooLargeGeneric');
      case 'UNSUPPORTED_MEDIA_TYPE':
        return t('receipts.upload.errors.type');
      case 'GONE':
        return t('receipts.upload.errors.expired');
      default:
        break;
    }
  }
  return describeError(error, t);
}

/**
 * True when a request was cancelled on purpose (AbortController). Checked
 * by name, not class: the error can come from another realm or be wrapped
 * by the API client (`cause`).
 */
export function isAbortError(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  if ('name' in error && error.name === 'AbortError') return true;
  return 'cause' in error && error.cause !== error && isAbortError(error.cause);
}

/** Whether a failure came from stopping the work (the signal was aborted). */
export function wasStopped(error: unknown, signal: AbortSignal): boolean {
  return signal.aborted || isAbortError(error);
}

/**
 * Whether a failed request certainly changed nothing on the server (a 4xx
 * answer). After a network error or a 5xx the outcome is unknown.
 */
export function failedForSure(error: unknown): boolean {
  return isApiError(error) && error.status >= 400 && error.status < 500;
}
