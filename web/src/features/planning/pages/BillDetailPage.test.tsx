import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import type { BillPaymentCandidate } from '@/shared/finance/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { ACCOUNT_CASH, makeAccount } from '@/tests/financeFixtures';
import {
  BILL_ID,
  OCC_DUE,
  OCC_NEXT,
  TX_BILL_PAYMENT,
  makeBill,
  makeCandidate,
  makeOccurrence,
} from '@/tests/planningFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const path = `/planning/bills/${BILL_ID}`;

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function serveBill(bill = makeBill()) {
  server.use(http.get(`${API}/bills/:id`, () => HttpResponse.json(envelope(bill))));
}

beforeAll(async () => {
  await import('./BillDetailPage');
});

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
  testBackend.accounts = [makeAccount()];
});

describe('BillDetailPage', () => {
  it('shows the payment state, schedule and payment history', async () => {
    serveBill();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    expect(screen.getByText('BESCOM', { selector: 'header *' })).toBeInTheDocument();

    const status = screen.getByRole('region', { name: 'Payment status' });
    expect(within(status).getByText('Due today')).toBeInTheDocument();
    expect(within(status).getByText(/November 5, 2026/)).toBeInTheDocument();
    expect(within(status).getByRole('link', { name: 'View payment' })).toHaveAttribute(
      'href',
      `/transactions/${TX_BILL_PAYMENT}`,
    );

    const details = screen.getByRole('region', { name: 'Details' });
    expect(within(details).getByText('Every month on day 5')).toBeInTheDocument();
    expect(within(details).getByText('1 day before')).toBeInTheDocument();
    expect(within(details).getByText('No end date')).toBeInTheDocument();
    expect(await within(details).findByText('Wallet')).toBeInTheDocument();

    const history = screen.getByRole('region', { name: 'Payments' });
    expect(within(history).getAllByRole('listitem')).toHaveLength(3);
    expect(within(history).getByText('Paid')).toBeInTheDocument();
    expect(
      within(history).getByRole('button', { name: 'Mark paid: due December 5, 2026' }),
    ).toBeInTheDocument();
    expect(
      within(history).getByRole('button', { name: 'Skip: due November 5, 2026' }),
    ).toBeInTheDocument();
  });

  it('records a new payment, retrying with the same Idempotency-Key until it succeeds', async () => {
    serveBill();
    const requests: { key: string | null; body: unknown }[] = [];
    server.use(
      http.post(`${API}/bills/:id/mark-paid`, async ({ request }) => {
        requests.push({ key: request.headers.get('Idempotency-Key'), body: await request.json() });
        if (requests.length === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(envelope(makeBill({ state: 'paid' })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Mark paid' }));
    const dialog = await screen.findByRole('dialog', { name: 'Mark “Electricity” paid' });
    await user.click(within(dialog).getByRole('radio', { name: /Record a new payment/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Continue' }));

    const form = await screen.findByRole('dialog', {
      name: 'Record the payment for “Electricity”',
    });
    expect(await within(form).findByLabelText('Paid from')).toHaveValue(ACCOUNT_CASH);
    const amount = within(form).getByLabelText('Amount paid');
    expect(amount).toHaveValue('1200.00');
    await user.clear(amount);
    await user.type(amount, '1250');
    expect(within(form).getByLabelText('Paid on')).toHaveValue('2026-11-05');
    await user.click(within(form).getByRole('button', { name: 'Record payment' }));
    expect(
      await within(form).findByText('Something went wrong on our side. Try again in a moment.'),
    ).toBeInTheDocument();
    await user.click(within(form).getByRole('button', { name: 'Record payment' }));

    expect(await screen.findByText('“Electricity” marked as paid')).toBeInTheDocument();
    expect(requests).toHaveLength(2);
    expect(requests[0]?.key).toBeTruthy();
    expect(requests[1]?.key).toBe(requests[0]?.key);
    expect(requests[1]?.body).toEqual({
      occurrence_id: OCC_DUE,
      create_transaction: true,
      account_id: ACCOUNT_CASH,
      amount: '1250.00',
      paid_on: '2026-11-05',
    });

    // The next payment is a new draft with its own key.
    await user.click(screen.getByRole('button', { name: 'Mark paid: due December 5, 2026' }));
    const next = await screen.findByRole('dialog', { name: 'Mark “Electricity” paid' });
    await user.click(within(next).getByRole('radio', { name: /Record a new payment/ }));
    await user.click(within(next).getByRole('button', { name: 'Continue' }));
    const nextForm = await screen.findByRole('dialog', {
      name: 'Record the payment for “Electricity”',
    });
    await within(nextForm).findByLabelText('Paid from');
    await user.click(within(nextForm).getByRole('button', { name: 'Record payment' }));
    await screen.findAllByText('“Electricity” marked as paid');
    expect(requests).toHaveLength(3);
    expect(requests[2]?.key).not.toBe(requests[0]?.key);
    expect(requests[2]?.body).toMatchObject({ occurrence_id: OCC_NEXT, amount: '1200.00' });
  });

  it('explains when the chosen payment is already linked elsewhere', async () => {
    serveBill();
    server.use(
      http.get(`${API}/bills/:id/payment-candidates`, () =>
        HttpResponse.json(
          envelope([
            makeCandidate({
              // A reason code newer than this client.
              reason_codes: [
                'same_provider',
                'brand_new',
              ] as unknown as BillPaymentCandidate['reason_codes'],
              reasons: ['Same provider', 'A new reason'],
              days_from_due: 3,
            }),
          ]),
        ),
      ),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([]))),
      http.post(`${API}/bills/:id/mark-paid`, () =>
        HttpResponse.json(errorBody({ code: 'DUPLICATE' }), { status: 409 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Mark paid' }));
    await user.click(await screen.findByRole('button', { name: 'Continue' }));
    const picker = await screen.findByRole('dialog', {
      name: 'Link the payment for “Electricity”',
    });
    // Reasons the web app does not know yet are shown as the API sent them.
    expect(await within(picker).findByText('A new reason')).toBeInTheDocument();
    expect(within(picker).getByText('Same provider')).toBeInTheDocument();
    expect(within(picker).getByText('3 days after the due date')).toBeInTheDocument();
    await user.click(within(picker).getByRole('radio', { name: /BESCOM/ }));
    await user.click(within(picker).getByRole('button', { name: 'Link payment' }));
    expect(
      await within(picker).findByText(
        'That transaction is already linked to another payment. Choose a different one.',
      ),
    ).toBeInTheDocument();
  });

  it('skips one payment after confirmation and can undo it', async () => {
    const skipped = makeOccurrence({
      id: OCC_NEXT,
      status: 'skipped',
      occurrence_date: '2026-12-05',
      effective_date: '2026-12-05',
    });
    let skipBody: unknown;
    const reopens: { key: string | null; body: unknown; id: string }[] = [];
    serveBill();
    server.use(
      http.post(`${API}/bills/:id/skip`, async ({ request }) => {
        skipBody = await request.json();
        serveBill(makeBill({ occurrences: [skipped, makeOccurrence()] }));
        return HttpResponse.json(envelope(makeBill()));
      }),
      http.post(`${API}/recurring-occurrences/:id/actions`, async ({ request, params }) => {
        reopens.push({
          key: request.headers.get('Idempotency-Key'),
          body: await request.json(),
          id: String(params.id),
        });
        return HttpResponse.json(envelope(makeOccurrence({ id: OCC_NEXT })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Skip: due December 5, 2026' }));
    const confirm = await screen.findByRole('dialog', { name: 'Skip this payment?' });
    expect(within(confirm).getByText(/nothing is due for December 5, 2026/)).toBeInTheDocument();
    await user.click(within(confirm).getByRole('button', { name: 'Skip payment' }));
    expect(await screen.findByText('Payment skipped')).toBeInTheDocument();
    expect(skipBody).toEqual({ occurrence_id: OCC_NEXT });

    await user.click(
      await screen.findByRole('button', { name: 'Undo skip: due December 5, 2026' }),
    );
    expect(await screen.findByText('The payment is due again')).toBeInTheDocument();
    expect(reopens).toHaveLength(1);
    expect(reopens[0]).toMatchObject({ id: OCC_NEXT, body: { action: 'reopen' } });
    expect(reopens[0]?.key).toMatch(/^web-/);
  });

  it('archives after confirmation with the lifecycle action and the version on screen', async () => {
    const calls: string[] = [];
    serveBill();
    server.use(
      http.post(`${API}/bills/:id/:action`, ({ request, params }) => {
        calls.push(`${String(params.action)}${new URL(request.url).search}`);
        const archived = makeBill({ status: 'archived', state: 'archived', version: 5 });
        serveBill(archived);
        return HttpResponse.json(envelope(archived));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Archive' }));
    const dialog = await screen.findByRole('dialog', { name: 'Archive this bill?' });
    await user.click(within(dialog).getByRole('button', { name: 'Archive bill' }));
    expect(await screen.findByText('Bill archived')).toBeInTheDocument();

    // An archived bill can be restored (and is no longer paid or paused from here).
    await user.click(await screen.findByRole('button', { name: 'Restore' }));
    expect(await screen.findByText('Bill restored')).toBeInTheDocument();
    expect(calls).toEqual(['archive?version=4', 'restore?version=5']);
  });

  it('pauses an active bill and resumes a paused one', async () => {
    const calls: string[] = [];
    serveBill();
    server.use(
      http.post(`${API}/bills/:id/:action`, ({ request, params }) => {
        calls.push(`${String(params.action)}${new URL(request.url).search}`);
        const next =
          params.action === 'pause'
            ? makeBill({ status: 'paused', state: 'paused', version: 5 })
            : makeBill({ version: 6 });
        serveBill(next);
        return HttpResponse.json(envelope(next));
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Pause' }));
    expect(
      await screen.findByText('Bill paused. No reminders until you resume it.'),
    ).toBeInTheDocument();
    await user.click(await screen.findByRole('button', { name: 'Resume' }));
    expect(await screen.findByText('Bill resumed')).toBeInTheDocument();
    expect(calls).toEqual(['pause?version=4', 'resume?version=5']);
  });

  it('explains a status change that no longer fits and loads the latest bill', async () => {
    let loads = 0;
    let pauses = 0;
    server.use(
      http.get(`${API}/bills/:id`, () => {
        loads += 1;
        return HttpResponse.json(envelope(makeBill()));
      }),
      http.post(`${API}/bills/:id/pause`, () => {
        pauses += 1;
        const from = pauses === 1 ? 'archived' : 'paused';
        return HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: `A bill cannot move from ${from} to paused.`,
                code: 'invalid_status_transition',
                params: { from, to: 'paused' },
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Pause' }));
    expect(
      await screen.findByText(
        'This can’t change from archived to paused. Its status may have changed somewhere else, so we’ve loaded the latest version.',
      ),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(loads).toBeGreaterThan(1);
    });

    await user.click(screen.getByRole('button', { name: 'Pause' }));
    expect(
      await screen.findByText(
        'It’s already paused. It may have changed somewhere else, so we’ve loaded the latest version.',
      ),
    ).toBeInTheDocument();
  });

  it('reloads when pausing hits a version conflict', async () => {
    let loads = 0;
    server.use(
      http.get(`${API}/bills/:id`, () => {
        loads += 1;
        return HttpResponse.json(envelope(makeBill({ version: 4 + loads })));
      }),
      http.post(`${API}/bills/:id/pause`, () =>
        HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Pause' }));
    expect(
      await screen.findByText(
        'This bill was changed somewhere else. We’ve loaded the latest version; try again.',
      ),
    ).toBeInTheDocument();
    expect(loads).toBeGreaterThan(1);
  });

  it('shows a moved payment with its new date', async () => {
    serveBill(
      makeBill({
        occurrences: [
          makeOccurrence({
            occurrence_date: '2026-11-05',
            effective_date: '2026-11-12',
            postponed_to: '2026-11-12',
          }),
        ],
      }),
    );
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    const history = screen.getByRole('region', { name: 'Payments' });
    expect(within(history).getByText('November 5, 2026')).toBeInTheDocument();
    expect(within(history).getByText('Moved to Nov 12, 2026')).toBeInTheDocument();
    // A moved payment keeps its status; actions name the date it is now due.
    expect(within(history).getByText('Upcoming')).toBeInTheDocument();
    expect(
      within(history).getByRole('button', { name: 'Mark paid: due November 12, 2026' }),
    ).toBeInTheDocument();
  });

  it('explains a payment that was already handled while choosing a match', async () => {
    let loads = 0;
    server.use(
      http.get(`${API}/bills/:id`, () => {
        loads += 1;
        return HttpResponse.json(envelope(makeBill()));
      }),
      http.get(`${API}/bills/:id/payment-candidates`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                message: 'That occurrence is already paid, skipped or not part of this bill.',
                code: 'occurrence_not_open',
              },
            ],
          }),
          { status: 409 },
        ),
      ),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Mark paid' }));
    await user.click(await screen.findByRole('button', { name: 'Continue' }));
    const picker = await screen.findByRole('dialog', {
      name: 'Link the payment for “Electricity”',
    });
    expect(
      await within(picker).findByText(
        'This payment is already paid or skipped. We’ve refreshed it, so check before trying again.',
      ),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(loads).toBeGreaterThan(1);
    });
  });

  it('suggests no matches when nothing recorded looks like the payment', async () => {
    serveBill();
    server.use(
      http.get(`${API}/bills/:id/payment-candidates`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/transactions`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    await user.click(screen.getByRole('button', { name: 'Mark paid' }));
    await user.click(await screen.findByRole('button', { name: 'Continue' }));
    const picker = await screen.findByRole('dialog', {
      name: 'Link the payment for “Electricity”',
    });
    expect(
      await within(picker).findByText(
        'No recorded payment looks like this one yet. You can search your transactions below.',
      ),
    ).toBeInTheDocument();
  });

  it('is read-only for someone who did not add the bill', async () => {
    serveBill(makeBill({ owned: false }));
    renderRoute(path, { user: signedIn() });
    await findPageHeading('Electricity');
    expect(
      screen.getByText('Only the person who added this bill can change it or record its payments.'),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Mark paid' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Edit' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Skip/ })).not.toBeInTheDocument();
  });

  it('shows not found, error and permission states', async () => {
    server.use(
      http.get(`${API}/bills/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    const first = renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('Bill not found')).toBeInTheDocument();
    first.unmount();

    server.use(
      http.get(`${API}/bills/:id`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-bill' }), {
          status: 500,
        }),
      ),
    );
    const second = renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('We couldn’t load this bill')).toBeInTheDocument();
    expect(screen.getByText('req-bill')).toBeInTheDocument();
    second.unmount();

    server.use(
      http.get(`${API}/bills/:id`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute(path, { user: signedIn() });
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
