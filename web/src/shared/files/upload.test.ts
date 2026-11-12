import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { ApiError } from '@/shared/api/errors';
import { API, envelope, errorBody } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { FileTooLargeError, filePolicies, sha256Hex, uploadFile } from './upload';

const FILE_ID = '5b1f8a52-7d2e-4c2a-9f4a-1d1e2f3a4b5c';

function fileRecord(status: 'pending_upload' | 'uploaded' | 'ready') {
  return {
    id: FILE_ID,
    purpose: 'receipt',
    status,
    original_filename: 'lunch.png',
    created_at: '2026-11-05T08:00:00Z',
  };
}

describe('uploadFile', () => {
  it('authorizes, sends the bytes with the token and checksum, then finalizes', async () => {
    const file = new File([new Uint8Array([137, 80, 78, 71, 1, 2, 3])], 'lunch.png', {
      type: 'image/png',
    });
    const checksum = await sha256Hex(file);
    const seen: string[] = [];
    let intentBody: unknown;
    let put: { token: string | null; checksum: string | null; type: string | null; size: number } =
      { token: null, checksum: null, type: null, size: 0 };
    server.use(
      http.post(`${API}/files/upload-intent`, async ({ request }) => {
        seen.push('intent');
        intentBody = await request.json();
        return HttpResponse.json(
          envelope({
            file: fileRecord('pending_upload'),
            upload_url: `http://localhost:8080/api/v1/files/${FILE_ID}/content`,
            method: 'PUT',
            headers: { 'X-Upload-Token': 'tok-123', 'Content-Type': 'application/octet-stream' },
            expires_at: '2026-11-05T08:15:00Z',
            max_bytes: 15728640,
          }),
          { status: 201 },
        );
      }),
      http.put(`${API}/files/${FILE_ID}/content`, async ({ request }) => {
        seen.push('content');
        put = {
          token: request.headers.get('X-Upload-Token'),
          checksum: request.headers.get('X-Upload-Checksum'),
          type: request.headers.get('Content-Type'),
          size: (await request.arrayBuffer()).byteLength,
        };
        return HttpResponse.json(envelope(fileRecord('uploaded')));
      }),
      http.post(`${API}/files/${FILE_ID}/complete`, () => {
        seen.push('complete');
        return HttpResponse.json(envelope(fileRecord('ready')));
      }),
    );

    const record = await uploadFile(file, { purpose: 'receipt' });

    expect(record.status).toBe('ready');
    expect(seen).toEqual(['intent', 'content', 'complete']);
    expect(intentBody).toEqual({
      purpose: 'receipt',
      filename: 'lunch.png',
      content_type: 'image/png',
      size_bytes: 7,
      checksum_sha256: checksum,
    });
    expect(put).toEqual({
      token: 'tok-123',
      checksum,
      type: 'application/octet-stream',
      size: 7,
    });
  });

  it('refuses files above the purpose limit before contacting the server', async () => {
    const big = new File([new Uint8Array(filePolicies.avatar.maxBytes + 1)], 'me.png', {
      type: 'image/png',
    });
    await expect(uploadFile(big, { purpose: 'avatar' })).rejects.toBeInstanceOf(FileTooLargeError);
  });

  it('surfaces the server reason when the upload is refused', async () => {
    server.use(
      http.post(`${API}/files/upload-intent`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                message: 'Storage limit reached.',
                code: 'storage_quota_exceeded',
                params: { quota_bytes: '4000' },
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const file = new File(['a,b\n1,2\n'], 'statement.csv', { type: 'text/csv' });
    const error = await uploadFile(file, { purpose: 'statement_import' }).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).status).toBe(422);
  });

  it('offers CSV, XLSX and OFX for statements, never PDF', () => {
    expect(filePolicies.statement_import.accept).toContain('.csv');
    expect(filePolicies.statement_import.accept).toContain('.xlsx');
    expect(filePolicies.statement_import.accept).toContain('.ofx');
    expect(filePolicies.statement_import.accept).not.toContain('pdf');
  });
});
