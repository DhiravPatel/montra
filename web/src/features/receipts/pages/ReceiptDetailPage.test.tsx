import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import type { ReceiptDetail } from '@/features/receipts/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACCOUNT_CASH,
  TX_GROCERIES,
  makeAccount,
  makeTransaction,
  money,
  starterCategories,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import {
  PAGE_FILE,
  RECEIPT_ID,
  RECEIPT_OTHER,
  RECORDED_TX,
  makeCandidate,
  makeExtraction,
  makeReceiptDetail,
  makeReviewedReceipt,
  previewHandlers,
  signedUrl,
} from '@/tests/receiptsFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });
const path = `/receipts/${RECEIPT_ID}`;

/** GET /receipts/{id} answering with each record in turn (the last one repeats). */
function receiptHandler(...records: ReceiptDetail[]) {
  let calls = 0;
  return http.get(`${API}/receipts/:id`, () => {
    const record = records[Math.min(calls, records.length - 1)]!;
    calls += 1;
    return HttpResponse.json(envelope(record));
  });
}

describe('ReceiptDetailPage', () => {
  it('shows the page, the saved details and their history, and never offers automatic reading', async () => {
    server.use(receiptHandler(makeReviewedReceipt()), ...previewHandlers());
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    expect(screen.getByText('Reviewed')).toBeInTheDocument();

    const image = await screen.findByRole('img', { name: 'Receipt image' });
    expect(image.getAttribute('src')).toMatch(/^data:image\/png;base64,/);

    const details = screen.getByRole('region', { name: 'Details' });
    expect(within(details).getByLabelText(/^Merchant/)).toHaveValue('Cafe Uno');
    expect(within(details).getByLabelText('Date on the receipt')).toHaveValue('2026-11-04');
    expect(within(details).getByLabelText(/^Time/)).toHaveValue('13:05');
    expect(within(details).getByLabelText('Total')).toHaveValue('450.00');
    expect(within(details).getByLabelText(/^Tip/)).toHaveValue('30.00');
    const item = within(details).getByRole('group', { name: 'Item 1' });
    expect(within(item).getByLabelText(/^Description/)).toHaveValue('Thali');
    expect(within(item).getByLabelText(/^Quantity/)).toHaveValue('2');
    expect(within(details).getByRole('button', { name: 'Save changes' })).toBeInTheDocument();

    const history = screen.getByRole('region', { name: 'History' });
    expect(within(history).getByText('Details entered by you')).toBeInTheDocument();
    expect(within(history).getByText(/^Version 1 · /)).toBeInTheDocument();

    const link = screen.getByRole('region', { name: 'Transaction' });
    expect(within(link).getByRole('button', { name: 'Record as expense' })).toBeInTheDocument();
    expect(
      within(link).getByRole('button', { name: 'Link existing transaction' }),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /read|scan|process/i })).not.toBeInTheDocument();
  });

  it('saves the typed details with exact amounts and the record version', async () => {
    const patches: unknown[] = [];
    server.use(
      receiptHandler(makeReceiptDetail(), makeReviewedReceipt({ version: 2 })),
      ...previewHandlers(),
      http.patch(`${API}/receipts/:id/review`, async ({ request }) => {
        patches.push(await request.json());
        return HttpResponse.json(envelope(makeReviewedReceipt({ version: 2 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Receipt');
    const details = screen.getByRole('region', { name: 'Details' });
    await user.type(await within(details).findByLabelText(/^Merchant/), 'Cafe Uno');
    await user.type(within(details).getByLabelText('Date on the receipt'), '2026-11-04');
    await user.type(within(details).getByLabelText('Total'), '1,234.5');
    await user.type(within(details).getByLabelText(/^Tax/), '0');
    await user.type(within(details).getByLabelText(/^Paid with/), 'Card ending 1234');
    await user.click(within(details).getByRole('button', { name: 'Add item' }));
    const item = within(details).getByRole('group', { name: 'Item 1' });
    await user.type(within(item).getByLabelText(/^Description/), 'Thali');
    await user.type(within(item).getByLabelText(/^Quantity/), '2');
    await user.type(within(item).getByLabelText(/^Amount/), '1234.50');
    // A blank line is left out.
    await user.click(within(details).getByRole('button', { name: 'Add item' }));
    await user.click(within(details).getByRole('button', { name: 'Save details' }));

    expect(await screen.findByText('Details saved')).toBeInTheDocument();
    expect(patches).toEqual([
      {
        receipt_date: '2026-11-04',
        total: '1234.50',
        currency: 'INR',
        version: 1,
        merchant_name: 'Cafe Uno',
        tax: '0.00',
        payment_hint: 'Card ending 1234',
        line_items: [{ description: 'Thali', quantity: '2', amount: '1234.50' }],
      },
    ]);
  });

  it('checks the details before saving and never sends a full card number', async () => {
    const patch = vi.fn();
    server.use(
      receiptHandler(makeReceiptDetail()),
      ...previewHandlers(),
      http.patch(`${API}/receipts/:id/review`, () => {
        patch();
        return HttpResponse.json(envelope(makeReviewedReceipt()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Receipt');
    const details = screen.getByRole('region', { name: 'Details' });
    await user.type(await within(details).findByLabelText(/^Paid with/), '4111 1111 1111 1111');
    await user.type(within(details).getByLabelText(/^Tip/), '1.234');
    await user.click(within(details).getByRole('button', { name: 'Save details' }));

    expect(await within(details).findByText('Choose a date.')).toBeInTheDocument();
    expect(within(details).getByText('Enter an amount.')).toBeInTheDocument();
    expect(
      within(details).getByText('INR amounts can have at most 2 decimal places.'),
    ).toBeInTheDocument();
    expect(
      within(details).getByText('Enter only the last 4 digits of a card or account.'),
    ).toBeInTheDocument();

    await user.type(within(details).getByLabelText('Date on the receipt'), '2099-01-01');
    await user.click(within(details).getByRole('button', { name: 'Save details' }));
    expect(
      await within(details).findByText('The receipt date can’t be in the future.'),
    ).toBeInTheDocument();
    expect(patch).not.toHaveBeenCalled();
  });

  it('reloads the receipt and warns when it changed elsewhere (version conflict)', async () => {
    server.use(
      receiptHandler(
        makeReviewedReceipt({ version: 2 }),
        makeReviewedReceipt({
          version: 3,
          current: makeExtraction({ merchant_name: 'Cafe Duo', version: 2 }),
        }),
      ),
      ...previewHandlers(),
      http.patch(`${API}/receipts/:id/review`, () =>
        HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    const details = screen.getByRole('region', { name: 'Details' });
    const merchant = await within(details).findByLabelText(/^Merchant/);
    await user.clear(merchant);
    await user.type(merchant, 'Cafe Uno Express');
    await user.click(within(details).getByRole('button', { name: 'Save changes' }));

    expect(await screen.findByText('This was changed somewhere else')).toBeInTheDocument();
    await findPageHeading('Cafe Duo');
    expect(within(details).getByLabelText(/^Merchant/)).toHaveValue('Cafe Duo');
  });

  it('links an existing transaction from the suggestions', async () => {
    const matches: unknown[] = [];
    server.use(
      receiptHandler(
        makeReviewedReceipt(),
        makeReviewedReceipt({ status: 'matched', transaction_id: TX_GROCERIES, version: 3 }),
      ),
      ...previewHandlers(),
      http.get(`${API}/receipts/:id/match-candidates`, () =>
        HttpResponse.json(
          envelope([
            makeCandidate({
              reasons: ['Same amount as the total', 'Same date', 'Same merchant', 'Brand new'],
              reason_codes: ['same_amount', 'same_date', 'same_merchant'],
            }),
          ]),
        ),
      ),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([]))),
      http.post(`${API}/receipts/:id/match-transaction`, async ({ request }) => {
        matches.push(await request.json());
        return HttpResponse.json(envelope(makeReviewedReceipt({ status: 'matched' })));
      }),
      http.get(`${API}/transactions/:id`, () =>
        HttpResponse.json(envelope(makeTransaction({ amount: money('450.00') }))),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    await user.click(screen.getByRole('button', { name: 'Link existing transaction' }));
    const dialog = await screen.findByRole('dialog', { name: 'Link a transaction' });
    const suggestion = await within(dialog).findByRole('radio', { name: /Cafe Uno/ });
    const option = suggestion.closest('label')!;
    expect(within(option).getByText('Same amount as the total')).toBeInTheDocument();
    expect(within(option).getByText('Same merchant')).toBeInTheDocument();
    expect(within(option).queryByText('Brand new')).not.toBeInTheDocument();
    await user.click(suggestion);
    await user.click(within(dialog).getByRole('button', { name: 'Link receipt' }));

    expect(await screen.findByText('Receipt linked')).toBeInTheDocument();
    expect(matches).toEqual([{ transaction_id: TX_GROCERIES }]);
    const link = await screen.findByRole('link', { name: 'Big Bazaar' });
    expect(link).toHaveAttribute('href', `/transactions/${TX_GROCERIES}`);
  });

  it('confirms a link once and closes the dialog even when the link unmounts it, and unlinking does not reopen it', async () => {
    let linked = false;
    let candidateCalls = 0;
    server.use(
      http.get(`${API}/receipts/:id`, () =>
        HttpResponse.json(
          envelope(
            linked
              ? makeReviewedReceipt({ status: 'matched', transaction_id: TX_GROCERIES, version: 3 })
              : makeReviewedReceipt({ version: 4 }),
          ),
        ),
      ),
      ...previewHandlers(),
      // The refresh after linking reloads the receipt before the suggestions: the
      // linked receipt removes the dialog while the write is still settling.
      http.get(`${API}/receipts/:id/match-candidates`, async () => {
        candidateCalls += 1;
        if (candidateCalls > 1) await delay(150);
        return HttpResponse.json(envelope([makeCandidate()]));
      }),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([]))),
      http.post(`${API}/receipts/:id/match-transaction`, () => {
        linked = true;
        return HttpResponse.json(
          envelope(makeReviewedReceipt({ status: 'matched', transaction_id: TX_GROCERIES })),
        );
      }),
      http.get(`${API}/transactions/:id`, () => HttpResponse.json(envelope(makeTransaction()))),
      http.post(`${API}/receipts/:id/unlink`, () => {
        linked = false;
        return HttpResponse.json(envelope(makeReviewedReceipt({ version: 4 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    await user.click(screen.getByRole('button', { name: 'Link existing transaction' }));
    const dialog = await screen.findByRole('dialog', { name: 'Link a transaction' });
    await user.click(await within(dialog).findByRole('radio', { name: /Cafe Uno/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Link receipt' }));

    expect(await screen.findByText('Receipt linked')).toBeInTheDocument();
    const card = screen.getByRole('region', { name: 'Transaction' });
    expect(await within(card).findByRole('link', { name: 'Big Bazaar' })).toBeInTheDocument();
    expect(screen.queryByRole('dialog', { name: 'Link a transaction' })).not.toBeInTheDocument();
    // Let the slow refresh finish: still exactly one confirmation.
    await waitFor(() => {
      expect(candidateCalls).toBeGreaterThan(1);
    });
    await new Promise((resolve) => setTimeout(resolve, 200));
    expect(screen.getAllByText('Receipt linked')).toHaveLength(1);

    await user.click(within(card).getByRole('button', { name: 'Unlink' }));
    expect(await screen.findByText('Receipt unlinked')).toBeInTheDocument();
    expect(
      await screen.findByRole('button', { name: 'Link existing transaction' }),
    ).toBeInTheDocument();
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('explains when the chosen transaction already has a receipt', async () => {
    server.use(
      receiptHandler(makeReviewedReceipt()),
      ...previewHandlers(),
      http.get(`${API}/receipts/:id/match-candidates`, () =>
        HttpResponse.json(envelope([makeCandidate()])),
      ),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([]))),
      http.post(`${API}/receipts/:id/match-transaction`, () =>
        HttpResponse.json(errorBody({ code: 'DUPLICATE' }), { status: 409 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    await user.click(screen.getByRole('button', { name: 'Link existing transaction' }));
    const dialog = await screen.findByRole('dialog', { name: 'Link a transaction' });
    await user.click(await within(dialog).findByRole('radio', { name: /Cafe Uno/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Link receipt' }));
    expect(
      await within(dialog).findByText(
        'That transaction already has a receipt. Choose another one.',
      ),
    ).toBeInTheDocument();
  });

  it('records the purchase as an expense with an Idempotency-Key kept for retries', async () => {
    testBackend.accounts = [
      makeAccount(),
      makeAccount({ id: 'acc-usd', name: 'Travel card', currency: 'USD' }),
    ];
    testBackend.categories = starterCategories();
    const posts: { key: string | null; body: unknown }[] = [];
    server.use(
      receiptHandler(
        makeReviewedReceipt(),
        makeReviewedReceipt(),
        makeReviewedReceipt({ status: 'matched', transaction_id: RECORDED_TX, version: 3 }),
      ),
      ...previewHandlers(),
      http.post(`${API}/receipts/:id/create-transaction`, async ({ request }) => {
        posts.push({ key: request.headers.get('Idempotency-Key'), body: await request.json() });
        if (posts.length === 1) {
          return HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 });
        }
        return HttpResponse.json(
          envelope(makeReviewedReceipt({ status: 'matched', transaction_id: RECORDED_TX })),
          { status: 201 },
        );
      }),
      http.get(`${API}/transactions/:id`, () =>
        HttpResponse.json(
          envelope(
            makeTransaction({
              id: RECORDED_TX,
              amount: money('450.00'),
              merchant: { id: 'm1', name: 'Cafe Uno' },
              source: 'receipt',
              receipt_id: RECEIPT_ID,
            }),
          ),
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    await user.click(screen.getByRole('button', { name: 'Record as expense' }));
    const dialog = await screen.findByRole('dialog', { name: 'Record as expense' });
    expect(within(dialog).getByText('₹450.00')).toBeInTheDocument();
    // Only accounts in the receipt currency are offered (one here, chosen already).
    const account = within(dialog).getByLabelText('Account');
    expect(account).toHaveValue(ACCOUNT_CASH);
    expect(within(account).queryByRole('option', { name: /Travel card/ })).not.toBeInTheDocument();
    await user.selectOptions(within(dialog).getByLabelText(/^Category/), 'Groceries');

    await user.click(within(dialog).getByRole('button', { name: 'Record expense' }));
    expect(
      await within(dialog).findByText('Montra is temporarily unavailable. Try again in a moment.'),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Record expense' }));

    expect(await screen.findByText('Expense recorded and linked')).toBeInTheDocument();
    expect(posts).toHaveLength(2);
    expect(posts[0]!.key).toMatch(/^web-/);
    expect(posts[1]!.key).toBe(posts[0]!.key);
    expect(posts[1]!.body).toEqual({
      account_id: ACCOUNT_CASH,
      category_id: starterCategories()[0]!.id,
    });
    const linked = await screen.findByRole('link', { name: 'Cafe Uno' });
    expect(linked).toHaveAttribute('href', `/transactions/${RECORDED_TX}`);
  });

  it('shows a linked receipt read-only and unlinks it', async () => {
    let unlinked = 0;
    const linked = makeReviewedReceipt({
      status: 'matched',
      transaction_id: TX_GROCERIES,
      version: 3,
    });
    server.use(
      receiptHandler(linked, makeReviewedReceipt({ version: 4 })),
      ...previewHandlers(),
      http.get(`${API}/transactions/:id`, () => HttpResponse.json(envelope(makeTransaction()))),
      http.post(`${API}/receipts/:id/unlink`, () => {
        unlinked += 1;
        return HttpResponse.json(envelope(makeReviewedReceipt({ version: 4 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    expect(screen.getByText('Linked')).toBeInTheDocument();
    const details = screen.getByRole('region', { name: 'Details' });
    expect(
      within(details).getByText('Unlink the transaction to change these details.'),
    ).toBeInTheDocument();
    expect(within(details).queryByRole('textbox')).not.toBeInTheDocument();
    expect(within(details).getByText('₹450.00')).toBeInTheDocument();

    const card = screen.getByRole('region', { name: 'Transaction' });
    expect(await within(card).findByRole('link', { name: 'Big Bazaar' })).toHaveAttribute(
      'href',
      `/transactions/${TX_GROCERIES}`,
    );
    await user.click(within(card).getByRole('button', { name: 'Unlink' }));
    expect(await screen.findByText('Receipt unlinked')).toBeInTheDocument();
    expect(unlinked).toBe(1);
    expect(
      await screen.findByRole('button', { name: 'Link existing transaction' }),
    ).toBeInTheDocument();
  });

  it('discards after confirmation, with the version shown, and returns to the inbox', async () => {
    let discarded = 0;
    const versions: (string | null)[] = [];
    server.use(
      receiptHandler(makeReceiptDetail()),
      ...previewHandlers(),
      http.post(`${API}/receipts/:id/discard`, ({ request }) => {
        discarded += 1;
        versions.push(new URL(request.url).searchParams.get('version'));
        return HttpResponse.json(envelope(makeReceiptDetail({ status: 'discarded' })));
      }),
      http.get(`${API}/receipts`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(path, { user: signedIn() });
    await findPageHeading('Receipt');
    await user.click(screen.getByRole('button', { name: 'Discard receipt' }));
    const dialog = await screen.findByRole('dialog', { name: 'Discard this receipt?' });
    expect(
      within(dialog).getByText(
        'It leaves your inbox and can’t be changed or linked again. You can still find it under Discarded.',
      ),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    expect(discarded).toBe(0);

    await user.click(screen.getByRole('button', { name: 'Discard receipt' }));
    await user.click(
      within(await screen.findByRole('dialog', { name: 'Discard this receipt?' })).getByRole(
        'button',
        { name: 'Discard' },
      ),
    );
    expect(await screen.findByText('Receipt discarded')).toBeInTheDocument();
    expect(discarded).toBe(1);
    expect(versions).toEqual(['1']);
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/receipts');
    });
  });

  it('says when the receipt was already discarded elsewhere (409 receipt_discarded)', async () => {
    server.use(
      receiptHandler(makeReceiptDetail(), makeReceiptDetail({ status: 'discarded', version: 2 })),
      ...previewHandlers(),
      http.post(`${API}/receipts/:id/discard`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [{ code: 'receipt_discarded', message: 'Already discarded.' }],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Receipt');
    await user.click(screen.getByRole('button', { name: 'Discard receipt' }));
    await user.click(
      within(await screen.findByRole('dialog', { name: 'Discard this receipt?' })).getByRole(
        'button',
        { name: 'Discard' },
      ),
    );
    expect(
      await screen.findByText('This receipt was discarded. Restore it to change it.'),
    ).toBeInTheDocument();
    // The refreshed receipt shows its real state, with a way back.
    expect(await screen.findByRole('button', { name: 'Restore receipt' })).toBeInTheDocument();
  });

  it('restores a discarded receipt with the version shown', async () => {
    const versions: (string | null)[] = [];
    server.use(
      receiptHandler(
        makeReviewedReceipt({ status: 'discarded', version: 5 }),
        makeReviewedReceipt({ version: 6 }),
      ),
      ...previewHandlers(),
      http.post(`${API}/receipts/:id/restore`, ({ request }) => {
        versions.push(new URL(request.url).searchParams.get('version'));
        return HttpResponse.json(envelope(makeReviewedReceipt({ version: 6 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    expect(screen.getByText('This receipt was discarded')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Restore receipt' }));
    expect(await screen.findByText('Receipt restored')).toBeInTheDocument();
    expect(screen.getByText('Its saved details are back.')).toBeInTheDocument();
    expect(versions).toEqual(['5']);
    expect(await screen.findByRole('button', { name: 'Discard receipt' })).toBeInTheDocument();
    expect(screen.queryByText('This receipt was discarded')).not.toBeInTheDocument();
  });

  it('offers PDF pages as a download through a short-lived link', async () => {
    const tab = { opener: {}, location: { href: '' }, close: vi.fn() };
    const open = vi.spyOn(window, 'open').mockReturnValue(tab as unknown as Window);
    server.use(
      receiptHandler(
        makeReceiptDetail({
          files: [{ file_id: PAGE_FILE, page_no: 1, content_type: 'application/pdf' }],
        }),
      ),
      http.get(`${API}/files/:fileId/access`, ({ params }) =>
        HttpResponse.json(
          envelope({
            url: signedUrl(String(params.fileId)),
            expires_at: '2026-11-05T09:05:00Z',
            content_type: 'application/pdf',
            filename: 'receipt.pdf',
          }),
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Receipt');
    expect(screen.getByText('PDF document')).toBeInTheDocument();
    expect(screen.queryByRole('img')).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Download PDF' }));
    await waitFor(() => {
      expect(tab.location.href).toBe(signedUrl(PAGE_FILE));
    });
    expect(open).toHaveBeenCalledWith('', '_blank');
    expect(tab.opener).toBeNull();
  });

  it('shows values read automatically before only as history, never in the form', async () => {
    server.use(
      receiptHandler(
        makeReceiptDetail({
          status: 'needs_review',
          current: makeExtraction({ method: 'ai_vision', provider: 'vision', version: 1 }),
          history: [
            {
              id: 'old-read',
              version: 1,
              method: 'ai_vision',
              status: 'succeeded',
              created_at: '2026-11-04T08:31:00Z',
            },
          ],
        }),
      ),
      ...previewHandlers(),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Receipt');
    const details = screen.getByRole('region', { name: 'Details' });
    expect(await within(details).findByLabelText(/^Merchant/)).toHaveValue('');
    expect(within(details).getByLabelText('Total')).toHaveValue('');

    const history = screen.getByRole('region', { name: 'History' });
    expect(within(history).getByText('Read automatically (earlier)')).toBeInTheDocument();
    await user.click(within(history).getByRole('button', { name: 'Show values read earlier' }));
    expect(within(history).getByText('Cafe Uno')).toBeInTheDocument();
    // Recording needs the person's own review first.
    expect(screen.queryByRole('button', { name: 'Record as expense' })).not.toBeInTheDocument();
  });

  it('warns about a possible duplicate and shows a discarded receipt read-only', async () => {
    server.use(
      receiptHandler(
        makeReviewedReceipt({ status: 'discarded', duplicate_of_id: RECEIPT_OTHER, version: 5 }),
      ),
      ...previewHandlers(),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Cafe Uno');
    expect(screen.getByText('This may be a duplicate')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open the other receipt' })).toHaveAttribute(
      'href',
      `/receipts/${RECEIPT_OTHER}`,
    );
    expect(screen.getByText('This receipt was discarded')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Discard receipt' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Save/ })).not.toBeInTheDocument();
    expect(screen.getByText('Discarded receipts can’t be linked.')).toBeInTheDocument();
  });

  it('says when the receipt does not exist', async () => {
    server.use(
      http.get(`${API}/receipts/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('Receipt not found')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'All receipts' })).toHaveAttribute('href', '/receipts');
  });

  it('shows a recoverable error', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/receipts/:id`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(envelope(makeReceiptDetail()));
      }),
      ...previewHandlers(),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('We couldn’t load this receipt')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    await findPageHeading('Receipt');
  });
});
