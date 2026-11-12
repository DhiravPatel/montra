import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { makeConversion, makeManualRate, makeProviderRate, RATE_MINE } from '@/tests/fxFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const signedIn = () => makeUser({ onboarding_completed: true });

function serveRates(rates = [makeManualRate(), makeProviderRate()], record: URL[] = []) {
  return http.get(`${API}/fx/rates`, ({ request }) => {
    record.push(new URL(request.url));
    return HttpResponse.json(envelope(rates));
  });
}

async function openPage() {
  const user = userEvent.setup();
  renderRoute('/settings/exchange-rates', { user: signedIn() });
  await findPageHeading('Exchange rates');
  return user;
}

describe('ExchangeRatesPage', () => {
  beforeEach(() => {
    // "Today" in the user's time zone (Asia/Kolkata) is 4 November 2026.
    vi.useFakeTimers({ toFake: ['Date'], now: new Date('2026-11-04T10:00:00Z') });
  });

  it('explains that rates never change recorded transactions', async () => {
    server.use(serveRates([]));
    await openPage();
    expect(screen.getByText('Rates never change your records')).toBeInTheDocument();
    expect(
      screen.getByText(/Every transaction keeps the currency and amount you recorded/),
    ).toBeInTheDocument();
    expect(await screen.findByText('No exchange rates yet')).toBeInTheDocument();
  });

  it('lists your rates and provider rates with their source and date', async () => {
    server.use(serveRates());
    await openPage();
    const list = screen.getByRole('region', { name: 'Rates' });
    const mine = await within(list).findByRole('region', { name: 'Your rates' });
    expect(within(mine).getByText('1 USD = 83.1234 INR')).toBeInTheDocument();
    expect(within(mine).getByText('Your rate')).toBeInTheDocument();
    expect(within(mine).getByText('As of November 1, 2026')).toBeInTheDocument();
    expect(within(mine).getByRole('button', { name: 'Delete rate USD → INR' })).toBeInTheDocument();

    const provider = within(list).getByRole('region', { name: 'Provider rates' });
    expect(within(provider).getByText('1 EUR = 89.5 INR')).toBeInTheDocument();
    expect(within(provider).getByText('European Central Bank')).toBeInTheDocument();
    expect(within(provider).queryByRole('button')).not.toBeInTheDocument();
  });

  it('filters the list by currency on the server', async () => {
    const requests: URL[] = [];
    server.use(serveRates(undefined, requests));
    const user = await openPage();
    await screen.findByText('1 USD = 83.1234 INR');
    const list = screen.getByRole('region', { name: 'Rates' });
    await user.selectOptions(within(list).getByLabelText('From currency (optional)'), 'USD');
    await waitFor(() => {
      expect(requests.at(-1)?.searchParams.get('base')).toBe('USD');
    });
    expect(requests.at(-1)?.searchParams.has('quote')).toBe(false);
  });

  it('shows an error with retry when rates cannot be loaded', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/fx/rates`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope([makeManualRate()]));
      }),
    );
    const user = await openPage();
    expect(await screen.findByText('We couldn’t load exchange rates')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('1 USD = 83.1234 INR')).toBeInTheDocument();
  });

  it('shows the permission state when rates cannot be read', async () => {
    server.use(
      http.get(`${API}/fx/rates`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    await openPage();
    const list = screen.getByRole('region', { name: 'Rates' });
    expect(await within(list).findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('checks a manual rate exactly before saving it', async () => {
    const bodies: unknown[] = [];
    let listCalls = 0;
    server.use(
      http.get(`${API}/fx/rates`, () => {
        listCalls += 1;
        return HttpResponse.json(envelope(listCalls === 1 ? [] : [makeManualRate()]));
      }),
      http.post(`${API}/fx/rates`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeManualRate()), { status: 201 });
      }),
    );
    const user = await openPage();
    const card = screen.getByRole('region', { name: 'Add your own rate' });
    const rate = await within(card).findByLabelText('Rate');
    const save = within(card).getByRole('button', { name: 'Save rate' });

    await user.click(save);
    expect(await within(card).findByText('Enter a rate.')).toBeInTheDocument();
    expect(within(card).getByText('Choose a currency.')).toBeInTheDocument();

    await user.selectOptions(within(card).getByLabelText('From currency'), 'INR');
    await user.type(rate, '83,1234');
    await user.click(save);
    expect(
      await within(card).findByText('Choose a different currency from the first one.'),
    ).toBeInTheDocument();
    expect(
      within(card).getByText(
        'Enter a positive rate using digits, like 83.1234 (up to 12 decimal places).',
      ),
    ).toBeInTheDocument();

    await user.selectOptions(within(card).getByLabelText('From currency'), 'USD');
    await user.clear(rate);
    await user.type(rate, '83.1234567890123');
    await user.click(save);
    expect(
      await within(card).findByText(
        'Enter a positive rate using digits, like 83.1234 (up to 12 decimal places).',
      ),
    ).toBeInTheDocument();
    await user.clear(rate);
    await user.type(rate, '0');
    await user.click(save);
    expect(await within(card).findByText('Enter a rate greater than zero.')).toBeInTheDocument();

    const date = within(card).getByLabelText('Applies from');
    await user.clear(date);
    await user.type(date, '2026-11-05');
    await user.clear(rate);
    await user.type(rate, '83.12340');
    // The exact rate is previewed as typed, without trailing zeros.
    expect(within(card).getByText('1 USD = 83.1234 INR')).toBeInTheDocument();
    await user.click(save);
    expect(await within(card).findByText('Choose today or an earlier date.')).toBeInTheDocument();
    expect(bodies).toHaveLength(0);

    await user.clear(date);
    await user.type(date, '2026-11-04');
    await user.click(save);
    expect(await screen.findByText('Rate saved')).toBeInTheDocument();
    // Today is sent as a bare date: the API reads it as that day in the user's time zone.
    expect(bodies).toEqual([{ base: 'USD', quote: 'INR', rate: '83.1234', as_of: '2026-11-04' }]);
    expect(await screen.findByRole('region', { name: 'Your rates' })).toBeInTheDocument();
    expect(within(card).getByLabelText('Rate')).toHaveValue('');
  });

  it('sends the chosen day as a bare date and shows server checks on the field', async () => {
    const bodies: unknown[] = [];
    server.use(
      serveRates([]),
      http.post(`${API}/fx/rates`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              { field: 'body.rate', message: 'Enter a positive exact rate such as 83.1234.' },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = await openPage();
    const card = screen.getByRole('region', { name: 'Add your own rate' });
    await user.selectOptions(await within(card).findByLabelText('From currency'), 'EUR');
    await user.type(within(card).getByLabelText('Rate'), '89.5');
    const date = within(card).getByLabelText('Applies from');
    await user.clear(date);
    await user.type(date, '2026-10-31');
    await user.click(within(card).getByRole('button', { name: 'Save rate' }));
    expect(
      await within(card).findByText(
        'Enter a positive rate using digits, like 83.1234 (up to 12 decimal places).',
      ),
    ).toBeInTheDocument();
    expect(bodies).toEqual([{ base: 'EUR', quote: 'INR', rate: '89.5', as_of: '2026-10-31' }]);
  });

  it('deletes your own rate only after confirming', async () => {
    const deleted: string[] = [];
    let listCalls = 0;
    server.use(
      http.get(`${API}/fx/rates`, () => {
        listCalls += 1;
        return HttpResponse.json(
          envelope(listCalls === 1 ? [makeManualRate(), makeProviderRate()] : [makeProviderRate()]),
        );
      }),
      http.delete(`${API}/fx/rates/:id`, ({ params }) => {
        deleted.push(String(params.id));
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = await openPage();
    await user.click(await screen.findByRole('button', { name: 'Delete rate USD → INR' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this rate?' });
    expect(
      within(dialog).getByText('1 USD = 83.1234 INR · As of November 1, 2026'),
    ).toBeInTheDocument();
    expect(within(dialog).getByText(/Your transactions don’t change\./)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    expect(deleted).toHaveLength(0);

    await user.click(screen.getByRole('button', { name: 'Delete rate USD → INR' }));
    await user.click(
      within(await screen.findByRole('dialog')).getByRole('button', { name: 'Delete rate' }),
    );
    expect(await screen.findByText('Rate deleted')).toBeInTheDocument();
    expect(deleted).toEqual([RATE_MINE]);
    await waitFor(() => {
      expect(screen.queryByRole('region', { name: 'Your rates' })).not.toBeInTheDocument();
    });
  });

  it('converts an amount and discloses the rate used and its date', async () => {
    const requests: URL[] = [];
    server.use(
      serveRates([]),
      http.get(`${API}/fx/convert`, ({ request }) => {
        const url = new URL(request.url);
        requests.push(url);
        return HttpResponse.json(
          envelope(
            makeConversion(
              url.searchParams.get('policy') === 'historical' ? { policy: 'historical' } : {},
            ),
          ),
        );
      }),
    );
    const user = await openPage();
    const card = screen.getByRole('region', { name: 'Convert an amount' });
    await user.selectOptions(await within(card).findByLabelText('From'), 'USD');
    await user.type(within(card).getByLabelText('Amount'), '10.5');
    await user.click(within(card).getByRole('button', { name: 'Convert' }));

    const result = await within(card).findByRole('status');
    expect(await within(result).findByText('Converted amount')).toBeInTheDocument();
    expect(within(result).getByText('$10.50')).toBeInTheDocument();
    expect(within(result).getByText('₹872.80')).toBeInTheDocument();
    expect(within(result).getByText('1 USD = 83.1234 INR')).toBeInTheDocument();
    expect(within(result).getByText('Manual rate')).toBeInTheDocument();
    expect(within(result).getByText('As of November 1, 2026')).toBeInTheDocument();
    expect(within(result).getByText(/The latest available rate was used\./)).toBeInTheDocument();
    expect(within(result).getByText(/rounded to the smallest unit/)).toBeInTheDocument();
    expect(requests[0]?.searchParams.get('amount')).toBe('10.50');
    expect(requests[0]?.searchParams.get('from')).toBe('USD');
    expect(requests[0]?.searchParams.get('to')).toBe('INR');
    expect(requests[0]?.searchParams.get('policy')).toBe('current');

    await user.click(within(card).getByLabelText('Rate on a date'));
    const date = within(card).getByLabelText('Date');
    await user.clear(date);
    await user.type(date, '2026-11-02');
    await user.click(within(card).getByRole('button', { name: 'Convert' }));
    expect(
      await within(card).findByText(/The latest rate on or before Nov 2, 2026 was used\./),
    ).toBeInTheDocument();
    expect(requests.at(-1)?.searchParams.get('policy')).toBe('historical');
    expect(requests.at(-1)?.searchParams.get('date')).toBe('2026-11-02');
  });

  it('checks the amount for the currency and explains a missing rate', async () => {
    const requests: URL[] = [];
    server.use(
      serveRates([]),
      http.get(`${API}/fx/convert`, ({ request }) => {
        requests.push(new URL(request.url));
        return HttpResponse.json(
          errorBody({
            code: 'NOT_FOUND',
            message: 'No exchange rate is available for USD→JPY. Add a manual rate.',
          }),
          { status: 404 },
        );
      }),
    );
    const user = await openPage();
    const card = screen.getByRole('region', { name: 'Convert an amount' });
    await user.selectOptions(await within(card).findByLabelText('From'), 'JPY');
    await user.selectOptions(within(card).getByLabelText('To'), 'USD');
    await user.type(within(card).getByLabelText('Amount'), '10.5');
    await user.click(within(card).getByRole('button', { name: 'Convert' }));
    expect(
      await within(card).findByText('JPY amounts are whole numbers, without decimals.'),
    ).toBeInTheDocument();
    expect(requests).toHaveLength(0);

    await user.selectOptions(within(card).getByLabelText('From'), 'USD');
    await user.selectOptions(within(card).getByLabelText('To'), 'JPY');
    await user.click(within(card).getByRole('button', { name: 'Convert' }));
    expect(
      await within(card).findByText(
        'No exchange rate is available for USD → JPY. Add a rate below to convert between them.',
      ),
    ).toBeInTheDocument();
    expect(requests).toHaveLength(1);
  });
});
