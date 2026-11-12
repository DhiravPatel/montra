import { delay, http, HttpResponse } from 'msw';
import type {
  Receipt,
  ReceiptDetail,
  ReceiptExtraction,
  ReceiptMatchCandidate,
} from '@/features/receipts/types';
import type { FileRecord } from '@/shared/files/upload';
import { API, envelope, errorBody } from './fixtures';
import { TX_GROCERIES, money } from './financeFixtures';

/** Receipt fixtures shaped like the contract (checked against the dev API). */

export const RECEIPT_ID = 'c0c0c0c0-3333-4333-8333-000000000001';
export const RECEIPT_OTHER = 'c0c0c0c0-3333-4333-8333-000000000002';
export const PAGE_FILE = 'd0d0d0d0-4444-4444-8444-000000000001';
export const PAGE_FILE_2 = 'd0d0d0d0-4444-4444-8444-000000000002';
export const UPLOAD_FILE = 'd0d0d0d0-4444-4444-8444-0000000000a1';
export const UPLOAD_FILE_2 = 'd0d0d0d0-4444-4444-8444-0000000000a2';
export const EXTRACTION_ID = 'e0e0e0e0-5555-4555-8555-000000000001';
export const RECORDED_TX = '77777777-7777-4777-8777-7777777777a1';

/** Values the person entered (a `manual` extraction version). */
export function makeExtraction(overrides: Partial<ReceiptExtraction> = {}): ReceiptExtraction {
  return {
    id: EXTRACTION_ID,
    version: 1,
    method: 'manual',
    extractor_version: 'user-review-1',
    status: 'succeeded',
    merchant_name: 'Cafe Uno',
    receipt_date: '2026-11-04',
    receipt_time: '13:05',
    currency: 'INR',
    subtotal: money('400.00'),
    tax: money('20.00'),
    tip: money('30.00'),
    total: money('450.00'),
    receipt_number: 'A-12',
    field_confidence: { total: 1, receipt_date: 1 },
    overall_confidence: '1.000',
    warnings: [],
    warning_codes: [],
    warning_params: [],
    line_items: [
      {
        position: 1,
        description: 'Thali',
        quantity: '2.000',
        unit_price: money('200.00'),
        amount: money('400.00'),
        confidence: '1.000',
      },
    ],
    created_at: '2026-11-04T09:00:00Z',
    completed_at: '2026-11-04T09:00:00Z',
    ...overrides,
  };
}

export function makeReceipt(overrides: Partial<Receipt> = {}): Receipt {
  return {
    id: RECEIPT_ID,
    status: 'needs_review',
    files: [{ file_id: PAGE_FILE, page_no: 1, content_type: 'image/png' }],
    version: 1,
    created_at: '2026-11-04T08:30:00Z',
    ...overrides,
  };
}

export function makeReceiptDetail(overrides: Partial<ReceiptDetail> = {}): ReceiptDetail {
  return { ...makeReceipt(), history: [], ...overrides };
}

/** A receipt whose details the person saved once (status `reviewed`). */
export function makeReviewedReceipt(overrides: Partial<ReceiptDetail> = {}): ReceiptDetail {
  return makeReceiptDetail({
    status: 'reviewed',
    current: makeExtraction(),
    reviewed_at: '2026-11-04T09:00:00Z',
    version: 2,
    history: [
      {
        id: EXTRACTION_ID,
        version: 1,
        method: 'manual',
        status: 'succeeded',
        created_at: '2026-11-04T09:00:00Z',
      },
    ],
    ...overrides,
  });
}

export function makeCandidate(
  overrides: Partial<ReceiptMatchCandidate> = {},
): ReceiptMatchCandidate {
  return {
    transaction_id: TX_GROCERIES,
    local_date: '2026-11-04',
    amount: money('450.00'),
    account_name: 'Wallet',
    merchant: 'Cafe Uno',
    reasons: ['Same amount as the total', 'Same date', 'Same merchant'],
    reason_codes: ['same_amount', 'same_date', 'same_merchant'],
    ...overrides,
  };
}

export function makeFileRecord(overrides: Partial<FileRecord> = {}): FileRecord {
  return {
    id: UPLOAD_FILE,
    purpose: 'receipt',
    status: 'ready',
    original_filename: 'lunch.png',
    content_type: 'image/png',
    size_bytes: 8,
    created_at: '2026-11-05T08:00:00Z',
    ...overrides,
  };
}

/** The 8-byte PNG signature: enough for previews and uploads in tests. */
export const PNG_BYTES = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);

export function pngFile(name = 'lunch.png'): File {
  return new File([PNG_BYTES], name, { type: 'image/png' });
}

/** The short-lived link a page preview downloads (the signed URL from /files/{id}/access). */
export function signedUrl(fileId: string): string {
  return `https://files.example/${fileId}?sig=test`;
}

/** GET /files/{id}/access and the signed download for image pages. */
export function previewHandlers(contentType = 'image/png') {
  return [
    http.get(`${API}/files/:fileId/access`, ({ params }) =>
      HttpResponse.json(
        envelope({
          url: signedUrl(String(params.fileId)),
          expires_at: '2026-11-05T09:05:00Z',
          content_type: contentType,
          filename: 'page.png',
        }),
      ),
    ),
    http.get('https://files.example/:fileId', () =>
      HttpResponse.arrayBuffer(PNG_BYTES.slice().buffer, {
        headers: { 'Content-Type': contentType },
      }),
    ),
  ];
}

export interface UploadLog {
  intents: Record<string, unknown>[];
  contents: { fileId: string; token: string | null; size: number }[];
  completes: string[];
  deleted: string[];
}

interface UploadOptions {
  /** File IDs handed out by successive upload intents. */
  ids?: readonly string[];
  /** Refuse every upload intent with this error. */
  refuse?: { status: number; code: string; details?: Parameters<typeof errorBody>[0]['details'] };
  /** Keep the byte upload pending until the client stops it. */
  hold?: boolean;
}

/**
 * MSW handlers for the upload workflow (intent → bytes → complete) and
 * DELETE /files/{id}. Every call is recorded in the returned log.
 */
export function uploadHandlers({
  ids = [UPLOAD_FILE, UPLOAD_FILE_2],
  refuse,
  hold,
}: UploadOptions = {}) {
  const log: UploadLog = { intents: [], contents: [], completes: [], deleted: [] };
  const handlers = [
    http.post(`${API}/files/upload-intent`, async ({ request }) => {
      const body = (await request.json()) as Record<string, unknown>;
      log.intents.push(body);
      if (refuse) {
        return HttpResponse.json(errorBody({ code: refuse.code, details: refuse.details ?? [] }), {
          status: refuse.status,
        });
      }
      const id = ids[log.intents.length - 1] ?? UPLOAD_FILE;
      return HttpResponse.json(
        envelope({
          file: makeFileRecord({
            id,
            purpose: String(body.purpose),
            status: 'pending_upload',
            original_filename: String(body.filename),
          }),
          upload_url: `http://localhost:8080/api/v1/files/${id}/content`,
          method: 'PUT',
          headers: { 'X-Upload-Token': `token-${id}`, 'Content-Type': 'application/octet-stream' },
          expires_at: '2026-11-05T08:15:00Z',
          max_bytes: 15728640,
        }),
        { status: 201 },
      );
    }),
    http.put(`${API}/files/:fileId/content`, async ({ params, request }) => {
      if (hold) await delay('infinite');
      const fileId = String(params.fileId);
      log.contents.push({
        fileId,
        token: request.headers.get('X-Upload-Token'),
        size: (await request.arrayBuffer()).byteLength,
      });
      return HttpResponse.json(envelope(makeFileRecord({ id: fileId, status: 'uploaded' })));
    }),
    http.post(`${API}/files/:fileId/complete`, ({ params }) => {
      const fileId = String(params.fileId);
      log.completes.push(fileId);
      return HttpResponse.json(envelope(makeFileRecord({ id: fileId, status: 'ready' })));
    }),
    http.delete(`${API}/files/:fileId`, ({ params }) => {
      log.deleted.push(String(params.fileId));
      return HttpResponse.json(envelope({ ok: true }));
    }),
  ];
  return { handlers, log };
}

/** 422 storage_quota_exceeded, as the API sends it (a coded domain rule). */
export const quotaExceeded = {
  status: 422,
  code: 'DOMAIN_RULE_VIOLATION',
  details: [
    {
      code: 'storage_quota_exceeded',
      message: 'This upload would exceed your 2048 MB storage allowance.',
      params: { used_bytes: '2147480000', quota_bytes: '2147483648' },
    },
  ],
};
