import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { sha256Hex } from '@/shared/files/upload';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { pageEnvelope } from '@/tests/importsFixtures';
import {
  PAGE_FILE_2,
  RECEIPT_ID,
  RECEIPT_OTHER,
  UPLOAD_FILE,
  UPLOAD_FILE_2,
  makeExtraction,
  makeReceipt,
  makeReceiptDetail,
  pngFile,
  previewHandlers,
  quotaExceeded,
  uploadHandlers,
} from '@/tests/receiptsFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

function listHandler(receipts = [makeReceipt()], seen: string[] = []) {
  return http.get(`${API}/receipts`, ({ request }) => {
    seen.push(new URL(request.url).search);
    return HttpResponse.json(envelope(receipts));
  });
}

/** Records POST /receipts bodies (and their Idempotency-Keys) and answers with a new receipt per call. */
function createHandler(
  bodies: unknown[],
  ids: readonly string[] = [RECEIPT_ID, RECEIPT_OTHER],
  keys: (string | null)[] = [],
) {
  return http.post(`${API}/receipts`, async ({ request }) => {
    const body = (await request.json()) as { file_ids: string[] };
    bodies.push(body);
    keys.push(request.headers.get('Idempotency-Key'));
    const id = ids[bodies.length - 1] ?? RECEIPT_ID;
    return HttpResponse.json(
      envelope(
        makeReceipt({
          id,
          files: body.file_ids.map((fileId, index) => ({
            file_id: fileId,
            page_no: index + 1,
            content_type: 'image/png',
          })),
        }),
      ),
      { status: 201 },
    );
  });
}

async function openAddDialog(user: ReturnType<typeof userEvent.setup>) {
  // The page header's button (an empty inbox offers a second one).
  await user.click(screen.getAllByRole('button', { name: 'Add receipt' })[0]!);
  return screen.findByRole('dialog', { name: 'Add a receipt' });
}

describe('ReceiptsPage', () => {
  it('lists the inbox with statuses, saved values and duplicate warnings', async () => {
    const seen: string[] = [];
    server.use(
      listHandler(
        [
          makeReceipt({
            status: 'reviewed',
            current: makeExtraction(),
            version: 2,
          }),
          makeReceipt({
            id: RECEIPT_OTHER,
            status: 'needs_review',
            duplicate_of_id: RECEIPT_ID,
            files: [
              { file_id: UPLOAD_FILE, page_no: 1, content_type: 'image/png' },
              { file_id: PAGE_FILE_2, page_no: 2, content_type: 'application/pdf' },
            ],
          }),
        ],
        seen,
      ),
    );
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');

    const reviewed = await screen.findByRole('link', { name: 'Cafe Uno' });
    expect(reviewed).toHaveAttribute('href', `/receipts/${RECEIPT_ID}`);
    const reviewedRow = reviewed.closest('li')!;
    expect(within(reviewedRow).getByText('₹450.00')).toBeInTheDocument();
    expect(within(reviewedRow).getByText(/^Nov 4, 2026 · 1 page$/)).toBeInTheDocument();
    expect(within(reviewedRow).getByText('Reviewed')).toBeInTheDocument();

    const pending = screen.getByRole('link', { name: 'Receipt' });
    expect(pending).toHaveAttribute('href', `/receipts/${RECEIPT_OTHER}`);
    const pendingRow = pending.closest('li')!;
    expect(within(pendingRow).getByText(/^Added Nov 4, 2026 · 2 pages$/)).toBeInTheDocument();
    expect(within(pendingRow).getByText('Needs details')).toBeInTheDocument();
    expect(within(pendingRow).getByText('Possible duplicate')).toBeInTheDocument();

    expect(screen.getByText('Showing 2 receipts')).toBeInTheDocument();
    // The first page, no cursor; the inbox is paged in 50s.
    expect(seen).toEqual(['?limit=50']);
    expect(screen.queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
  });

  it('loads older receipts with the cursor from meta.next_cursor', async () => {
    const seen: URLSearchParams[] = [];
    server.use(
      http.get(`${API}/receipts`, ({ request }) => {
        const params = new URL(request.url).searchParams;
        seen.push(params);
        return params.get('cursor') === 'page-2'
          ? HttpResponse.json(pageEnvelope([makeReceipt({ id: RECEIPT_OTHER })]))
          : HttpResponse.json(
              pageEnvelope(
                [makeReceipt({ current: makeExtraction(), status: 'reviewed' })],
                'page-2',
              ),
            );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    expect(await screen.findByRole('link', { name: 'Cafe Uno' })).toBeInTheDocument();
    expect(
      screen.getByText('Showing your latest 1 receipt. Load more to see older ones.'),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Load more' }));
    expect(await screen.findByRole('link', { name: 'Receipt' })).toBeInTheDocument();
    expect(screen.getByText('Showing 2 receipts')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
    expect(seen.map((params) => params.get('cursor'))).toEqual([null, 'page-2']);
  });

  it('filters by status and keeps the choice in the address', async () => {
    const seen: string[] = [];
    server.use(
      http.get(`${API}/receipts`, ({ request }) => {
        const status = new URL(request.url).searchParams.get('status') ?? '';
        seen.push(status);
        return HttpResponse.json(
          envelope(
            status === 'matched'
              ? [makeReceipt({ status: 'matched', current: makeExtraction(), transaction_id: 'x' })]
              : [],
          ),
        );
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    expect(await screen.findByText('No receipts yet')).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Show'), 'Linked');
    expect(await screen.findByRole('link', { name: 'Cafe Uno' })).toBeInTheDocument();
    expect(router.state.location.search).toBe('?status=matched');
    expect(seen).toEqual(['', 'matched']);
  });

  it('shows a first-use empty state with a way to add a receipt', async () => {
    server.use(listHandler([]));
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    expect(await screen.findByText('No receipts yet')).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: 'Add receipt' })).toHaveLength(2);
  });

  it('says when a status has no receipts', async () => {
    server.use(listHandler([]));
    renderRoute('/receipts?status=discarded', { user: signedIn() });
    await findPageHeading('Receipts');
    expect(await screen.findByText('No receipts with this status')).toBeInTheDocument();
    expect(screen.getByLabelText('Show')).toHaveValue('discarded');
  });

  it('shows a recoverable error', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/receipts`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(
            errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-receipts' }),
            { status: 500 },
          );
        }
        return HttpResponse.json(envelope([makeReceipt()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    expect(await screen.findByText('We couldn’t load your receipts')).toBeInTheDocument();
    expect(screen.getByText('req-receipts')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('link', { name: 'Receipt' })).toBeInTheDocument();
  });

  it('shows a permission message when access is refused', async () => {
    server.use(
      http.get(`${API}/receipts`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('uploads a photo, creates the receipt without reading it and opens it for review', async () => {
    const upload = uploadHandlers();
    const created: unknown[] = [];
    const keys: (string | null)[] = [];
    server.use(
      listHandler([]),
      ...upload.handlers,
      createHandler(created, undefined, keys),
      http.get(`${API}/receipts/:id`, () =>
        HttpResponse.json(
          envelope(
            makeReceiptDetail({
              files: [{ file_id: UPLOAD_FILE, page_no: 1, content_type: 'image/png' }],
            }),
          ),
        ),
      ),
      ...previewHandlers(),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    await screen.findByText('No receipts yet');
    const dialog = await openAddDialog(user);

    const file = pngFile('lunch.png');
    await user.upload(within(dialog).getByLabelText('Choose files'), file);
    expect(within(dialog).getByText('lunch.png')).toBeInTheDocument();
    expect(within(dialog).getByText('8 byte · Ready')).toBeInTheDocument();
    await user.type(within(dialog).getByLabelText(/^Note/), 'Team lunch');
    await user.click(within(dialog).getByRole('button', { name: 'Add receipt' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/receipts/${RECEIPT_ID}`);
    });
    expect(await screen.findByText('Receipt added')).toBeInTheDocument();
    expect(upload.log.intents).toEqual([
      {
        purpose: 'receipt',
        filename: 'lunch.png',
        content_type: 'image/png',
        size_bytes: 8,
        checksum_sha256: await sha256Hex(file),
      },
    ]);
    expect(upload.log.contents).toEqual([
      { fileId: UPLOAD_FILE, token: `token-${UPLOAD_FILE}`, size: 8 },
    ]);
    expect(upload.log.completes).toEqual([UPLOAD_FILE]);
    // No reading is asked for (neither read_automatically nor the deprecated skip_extraction).
    expect(created).toEqual([{ file_ids: [UPLOAD_FILE], notes: 'Team lunch' }]);
    expect(keys[0]).toMatch(/^web-[0-9a-f-]{36}$/);
    expect(upload.log.deleted).toEqual([]);
    expect(await findPageHeading('Receipt')).toBeInTheDocument();
  });

  it('keeps the same Idempotency-Key when the same receipt is tried again', async () => {
    const upload = uploadHandlers();
    const keys: (string | null)[] = [];
    server.use(
      listHandler([]),
      ...upload.handlers,
      http.post(`${API}/receipts`, ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        if (keys.length === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(envelope(makeReceipt()), { status: 201 });
      }),
      http.get(`${API}/receipts/:id`, () => HttpResponse.json(envelope(makeReceiptDetail()))),
      ...previewHandlers(),
    );
    const user = userEvent.setup();
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    const dialog = await openAddDialog(user);
    await user.upload(within(dialog).getByLabelText('Choose files'), pngFile());
    await user.click(within(dialog).getByRole('button', { name: 'Add receipt' }));
    expect((await within(dialog).findAllByText(/Something went wrong/)).length).toBeGreaterThan(0);
    // The page was uploaded once; only the receipt request is repeated, with the same key.
    await user.click(within(dialog).getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('Receipt added')).toBeInTheDocument();
    expect(upload.log.intents).toHaveLength(1);
    expect(keys).toHaveLength(2);
    expect(keys[1]).toBe(keys[0]);
  });

  it('explains a page that already belongs to another receipt (409 file_in_use)', async () => {
    const upload = uploadHandlers();
    server.use(
      listHandler([]),
      ...upload.handlers,
      http.post(`${API}/receipts`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                code: 'file_in_use',
                message: 'This file is already a page of another receipt.',
                params: { file_id: UPLOAD_FILE, receipt_id: RECEIPT_OTHER },
              },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    const dialog = await openAddDialog(user);
    await user.upload(within(dialog).getByLabelText('Choose files'), pngFile());
    await user.click(within(dialog).getByRole('button', { name: 'Add receipt' }));
    expect(
      (
        await within(dialog).findAllByText(
          'A page is already part of another receipt. Remove it here, or discard that receipt first.',
        )
      ).length,
    ).toBeGreaterThan(0);
  });

  it('adds several files as the pages of one receipt, in the chosen order', async () => {
    const upload = uploadHandlers();
    const created: unknown[] = [];
    server.use(
      listHandler([]),
      ...upload.handlers,
      createHandler(created),
      http.get(`${API}/receipts/:id`, () => HttpResponse.json(envelope(makeReceiptDetail()))),
      ...previewHandlers(),
    );
    const user = userEvent.setup();
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    const dialog = await openAddDialog(user);
    await user.upload(within(dialog).getByLabelText('Choose files'), [
      pngFile('top.png'),
      new File(['%PDF-1.4'], 'bottom.pdf', { type: 'application/pdf' }),
    ]);
    expect(within(dialog).getByText('Page 1: top.png')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Move bottom.pdf up' }));
    expect(within(dialog).getByText('Page 1: bottom.pdf')).toBeInTheDocument();
    expect(within(dialog).getByRole('radio', { name: /Pages of one receipt/ })).toBeChecked();

    await user.click(within(dialog).getByRole('button', { name: 'Add receipt' }));
    await screen.findByText('Receipt added');
    expect(upload.log.intents.map((intent) => intent.filename)).toEqual(['bottom.pdf', 'top.png']);
    expect(created).toEqual([{ file_ids: [UPLOAD_FILE, UPLOAD_FILE_2] }]);
  });

  it('adds separate receipts, one per file', async () => {
    const upload = uploadHandlers();
    const created: unknown[] = [];
    server.use(listHandler([]), ...upload.handlers, createHandler(created));
    const user = userEvent.setup();
    const { router } = renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    const dialog = await openAddDialog(user);
    await user.upload(within(dialog).getByLabelText('Choose files'), [
      pngFile('one.png'),
      pngFile('two.png'),
    ]);
    await user.click(within(dialog).getByRole('radio', { name: /Separate receipts/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Add 2 receipts' }));

    expect(await screen.findByText('2 receipts added')).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(created).toEqual([{ file_ids: [UPLOAD_FILE] }, { file_ids: [UPLOAD_FILE_2] }]);
    expect(router.state.location.pathname).toBe('/receipts');
  });

  it('explains a refused upload (storage allowance) and creates nothing', async () => {
    const upload = uploadHandlers({ refuse: quotaExceeded });
    const created: unknown[] = [];
    server.use(listHandler([]), ...upload.handlers, createHandler(created));
    const user = userEvent.setup();
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    const dialog = await openAddDialog(user);
    await user.upload(within(dialog).getByLabelText('Choose files'), pngFile());
    await user.click(within(dialog).getByRole('button', { name: 'Add receipt' }));

    expect(
      await within(dialog).findByText(
        'This would go over your 2 GB storage allowance. Delete files you no longer need, then try again.',
      ),
    ).toBeInTheDocument();
    expect(
      within(dialog).getByText('Some pages couldn’t be uploaded. Remove them or try again.'),
    ).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: 'Try again' })).toBeInTheDocument();
    expect(created).toEqual([]);
    expect(upload.log.contents).toEqual([]);
  });

  it('refuses unsuitable files before uploading anything', async () => {
    const upload = uploadHandlers();
    server.use(listHandler([]), ...upload.handlers);
    const user = userEvent.setup({ applyAccept: false });
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    const dialog = await openAddDialog(user);
    await user.upload(within(dialog).getByLabelText('Choose files'), [
      // PDFs are sent as they are, so the 15 MB limit applies before uploading. (Photos
      // are scaled down first; their limit is checked on the prepared file.)
      new File([new Uint8Array(15 * 1024 * 1024 + 1)], 'huge.pdf', { type: 'application/pdf' }),
      new File(['a,b'], 'notes.txt', { type: 'text/plain' }),
      new File([], 'empty.png', { type: 'image/png' }),
    ]);

    const alert = within(dialog).getByRole('alert');
    expect(within(alert).getByText('Some files weren’t added')).toBeInTheDocument();
    expect(
      within(alert).getByText('huge.pdf: This file is larger than 15 MB.'),
    ).toBeInTheDocument();
    expect(
      within(alert).getByText(
        'notes.txt: This file type isn’t supported. Use a JPG, PNG, WebP or HEIC photo, or a PDF.',
      ),
    ).toBeInTheDocument();
    expect(within(alert).getByText('empty.png: This file is empty.')).toBeInTheDocument();
    expect(within(dialog).queryByRole('heading', { name: /file/ })).not.toBeInTheDocument();

    await user.click(within(dialog).getByRole('button', { name: 'Add receipt' }));
    expect(within(dialog).getByText('Choose at least one file.')).toBeInTheDocument();
    expect(upload.log.intents).toEqual([]);
  });

  it('stops an upload in progress and keeps the files for another try', async () => {
    const upload = uploadHandlers({ hold: true });
    const created: unknown[] = [];
    server.use(listHandler([]), ...upload.handlers, createHandler(created));
    const user = userEvent.setup();
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    const dialog = await openAddDialog(user);
    await user.upload(within(dialog).getByLabelText('Choose files'), pngFile());
    await user.click(within(dialog).getByRole('button', { name: 'Add receipt' }));

    expect(await within(dialog).findByText('Uploaded 0 of 1…')).toBeInTheDocument();
    expect(
      within(dialog).getByRole('progressbar', { name: 'Upload progress' }),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Stop upload' }));

    expect(
      await within(dialog).findByText(
        'Upload stopped. Your files are still listed, so you can continue or remove them.',
      ),
    ).toBeInTheDocument();
    expect(within(dialog).getByText('8 byte · Ready')).toBeInTheDocument();
    expect(created).toEqual([]);
  });

  it('deletes pages that were uploaded but never became a receipt', async () => {
    const upload = uploadHandlers();
    let intents = 0;
    server.use(
      listHandler([]),
      // The second page is refused, so no receipt is created.
      http.post(`${API}/files/upload-intent`, async ({ request }) => {
        intents += 1;
        if (intents === 2) {
          return HttpResponse.json(
            errorBody({ code: 'UNSUPPORTED_MEDIA_TYPE', message: 'Not accepted.' }),
            { status: 415 },
          );
        }
        const body = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json(
          envelope({
            file: {
              id: UPLOAD_FILE,
              purpose: body.purpose,
              status: 'pending_upload',
              created_at: '2026-11-05T08:00:00Z',
            },
            upload_url: `http://localhost:8080/api/v1/files/${UPLOAD_FILE}/content`,
            method: 'PUT',
            headers: { 'X-Upload-Token': 'token' },
            expires_at: '2026-11-05T08:15:00Z',
            max_bytes: 15728640,
          }),
          { status: 201 },
        );
      }),
      ...upload.handlers.slice(1),
    );
    const user = userEvent.setup();
    renderRoute('/receipts', { user: signedIn() });
    await findPageHeading('Receipts');
    const dialog = await openAddDialog(user);
    await user.upload(within(dialog).getByLabelText('Choose files'), [
      pngFile('first.png'),
      pngFile('second.png'),
    ]);
    await user.click(within(dialog).getByRole('button', { name: 'Add receipt' }));
    expect(
      await within(dialog).findByText(
        'This file type isn’t supported. Use a JPG, PNG, WebP or HEIC photo, or a PDF.',
      ),
    ).toBeInTheDocument();
    expect(within(dialog).getByText('8 byte · Uploaded')).toBeInTheDocument();

    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => {
      expect(upload.log.deleted).toEqual([UPLOAD_FILE]);
    });
  });
});
