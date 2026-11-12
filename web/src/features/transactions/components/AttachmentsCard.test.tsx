import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { Attachment, Transaction } from '@/shared/finance/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { TX_GROCERIES, makeTransaction } from '@/tests/financeFixtures';
import { server } from '@/tests/msw/server';
import {
  RECEIPT_ID,
  UPLOAD_FILE,
  pngFile,
  quotaExceeded,
  uploadHandlers,
} from '@/tests/receiptsFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });
const path = `/transactions/${TX_GROCERIES}`;

function attachment(overrides: Partial<Attachment> = {}): Attachment {
  return {
    file_id: UPLOAD_FILE,
    filename: 'invoice.png',
    content_type: 'image/png',
    size_bytes: 8,
    purpose: 'transaction_attachment',
    attached_at: '2026-11-05T08:00:00Z',
    ...overrides,
  };
}

/** The transaction detail page around the card; attachments are read from `files`. */
function pageHandlers(transaction: Transaction, files: { list: Attachment[] }) {
  return [
    http.get(`${API}/transactions/:id`, () => HttpResponse.json(envelope(transaction))),
    http.get(`${API}/transactions/:id/audit`, () => HttpResponse.json(envelope([]))),
    http.get(`${API}/transactions/:id/attachments`, () => HttpResponse.json(envelope(files.list))),
  ];
}

async function filesCard() {
  await findPageHeading('Big Bazaar');
  const card = screen.getByRole('region', { name: 'Files' });
  await within(card).findByText('No files attached');
  return card;
}

describe('AttachmentsCard', () => {
  it('uploads a file as a transaction attachment, then attaches it', async () => {
    const files = { list: [] as Attachment[] };
    const upload = uploadHandlers();
    const attached: unknown[] = [];
    server.use(
      ...pageHandlers(makeTransaction(), files),
      ...upload.handlers,
      http.post(`${API}/transactions/:id/attachments`, async ({ request, params }) => {
        attached.push({ id: params.id, body: await request.json() });
        files.list = [attachment()];
        return HttpResponse.json(envelope(makeTransaction({ attachment_count: 1, version: 4 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    const card = await filesCard();

    await user.upload(within(card).getByLabelText('Attach file'), pngFile('invoice.png'));

    expect(await screen.findByText('File attached')).toBeInTheDocument();
    expect(await within(card).findByText('invoice.png')).toBeInTheDocument();
    expect(upload.log.intents).toEqual([
      expect.objectContaining({
        purpose: 'transaction_attachment',
        filename: 'invoice.png',
        size_bytes: 8,
      }),
    ]);
    expect(upload.log.completes).toEqual([UPLOAD_FILE]);
    expect(attached).toEqual([{ id: TX_GROCERIES, body: { file_id: UPLOAD_FILE } }]);
    expect(upload.log.deleted).toEqual([]);
  });

  it('explains a refused upload (storage allowance) and attaches nothing', async () => {
    const upload = uploadHandlers({ refuse: quotaExceeded });
    let attachCalls = 0;
    server.use(
      ...pageHandlers(makeTransaction(), { list: [] }),
      ...upload.handlers,
      http.post(`${API}/transactions/:id/attachments`, () => {
        attachCalls += 1;
        return HttpResponse.json(envelope(makeTransaction()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    const card = await filesCard();
    await user.upload(within(card).getByLabelText('Attach file'), pngFile('invoice.png'));

    const alert = await within(card).findByRole('alert');
    expect(within(alert).getByText('Some files weren’t attached')).toBeInTheDocument();
    expect(
      within(alert).getByText(
        'invoice.png: This would go over your 2 GB storage allowance. Delete files you no longer need, then try again.',
      ),
    ).toBeInTheDocument();
    expect(attachCalls).toBe(0);
    await user.click(within(alert).getByRole('button', { name: 'Dismiss' }));
    expect(within(card).queryByRole('alert')).not.toBeInTheDocument();
  });

  it('refuses a file that is too large before contacting the server', async () => {
    const upload = uploadHandlers();
    server.use(...pageHandlers(makeTransaction(), { list: [] }), ...upload.handlers);
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    const card = await filesCard();
    await user.upload(
      within(card).getByLabelText('Attach file'),
      new File([new Uint8Array(15 * 1024 * 1024 + 1)], 'scan.png', { type: 'image/png' }),
    );
    expect(
      await within(card).findByText('scan.png: This file is larger than 15 MB.'),
    ).toBeInTheDocument();
    expect(upload.log.intents).toEqual([]);
  });

  it('deletes the uploaded file when the transaction refuses it', async () => {
    const upload = uploadHandlers();
    server.use(
      ...pageHandlers(makeTransaction(), { list: [] }),
      ...upload.handlers,
      http.post(`${API}/transactions/:id/attachments`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [{ code: 'file_not_attachable', message: 'Not attachable.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    const card = await filesCard();
    await user.upload(within(card).getByLabelText('Attach file'), pngFile('invoice.png'));
    expect(
      await within(card).findByText('invoice.png: This file can’t be attached to a transaction.'),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(upload.log.deleted).toEqual([UPLOAD_FILE]);
    });
  });

  it('stops an upload in progress', async () => {
    const upload = uploadHandlers({ hold: true });
    server.use(...pageHandlers(makeTransaction(), { list: [] }), ...upload.handlers);
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    const card = await filesCard();
    await user.upload(within(card).getByLabelText('Attach file'), pngFile('invoice.png'));
    expect(
      await within(card).findByText('Uploading invoice.png (1 of 1)…', { selector: 'span' }),
    ).toBeInTheDocument();
    expect(within(card).getByLabelText('Attach file')).toBeDisabled();
    await user.click(within(card).getByRole('button', { name: 'Stop' }));
    expect(await within(card).findByText('Upload stopped.')).toBeInTheDocument();
    expect(within(card).getByLabelText('Attach file')).toBeEnabled();
  });

  it('links to the receipt and offers no upload on a read-only transaction', async () => {
    server.use(
      ...pageHandlers(makeTransaction({ owned: false, receipt_id: RECEIPT_ID }), {
        list: [attachment({ purpose: 'receipt', filename: 'receipt.png' })],
      }),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    const card = screen.getByRole('region', { name: 'Files' });
    expect(await within(card).findByText('receipt.png')).toBeInTheDocument();
    expect(within(card).getByRole('link', { name: 'Open receipt' })).toHaveAttribute(
      'href',
      `/receipts/${RECEIPT_ID}`,
    );
    expect(within(card).queryByLabelText('Attach file')).not.toBeInTheDocument();
    expect(within(card).queryByRole('button', { name: /^Remove/ })).not.toBeInTheDocument();
  });
});
