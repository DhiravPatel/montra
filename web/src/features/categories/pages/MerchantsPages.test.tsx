import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { Merchant } from '@/shared/finance/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CATEGORY_GROCERIES,
  MERCHANT_BB_ONLINE,
  MERCHANT_BIG_BAZAAR,
  MERCHANT_SWIGGY,
  makeMerchant,
  makeMerchantDetail,
  makeMerchantMergeAffected,
  organizeCategories,
} from '@/tests/categoriesFixtures';
import { money } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const merchants = () => [
  makeMerchant(),
  makeMerchant({
    id: MERCHANT_BB_ONLINE,
    name: 'BigBazaar Online',
    transaction_count: 1,
    last_used_on: '2026-10-12',
  }),
  makeMerchant({
    id: MERCHANT_SWIGGY,
    name: 'Swiggy',
    transaction_count: 5,
    status: 'archived',
    aliases: ['SWIGGY*BLR', 'Swiggy Instamart'],
  }),
];

/** A list page with a cursor for the next one (meta.next_cursor). */
function page(items: Merchant[], nextCursor?: string) {
  const body = envelope(items);
  return nextCursor
    ? { ...body, meta: { ...body.meta, next_cursor: nextCursor, has_more: true } }
    : body;
}

/** GET /merchants filtered like the API: by status (default active) and search text. */
function serveMerchantList(all: Merchant[], requests: URLSearchParams[] = []) {
  server.use(
    http.get(`${API}/merchants`, ({ request }) => {
      const params = new URL(request.url).searchParams;
      requests.push(params);
      const status = params.get('status') ?? 'active';
      const q = (params.get('q') ?? '').toLowerCase();
      return HttpResponse.json(
        envelope(
          all.filter(
            (merchant) =>
              (status === 'all' || merchant.status === status) &&
              merchant.name.toLowerCase().includes(q),
          ),
        ),
      );
    }),
  );
  return requests;
}

function serveDetail(detail = makeMerchantDetail()) {
  server.use(http.get(`${API}/merchants/:id`, () => HttpResponse.json(envelope(detail))));
}

describe('MerchantsPage', () => {
  it('lists active merchants with counts and searches by name', async () => {
    const requests = serveMerchantList(merchants());
    const user = userEvent.setup();
    renderRoute('/categories/merchants', { user: signedIn() });
    await findPageHeading('Merchants');

    expect(await screen.findByRole('link', { name: 'Big Bazaar' })).toHaveAttribute(
      'href',
      `/categories/merchants/${MERCHANT_BIG_BAZAAR}`,
    );
    expect(screen.getByText('3 transactions · Last used Nov 3, 2026')).toBeInTheDocument();
    // Archived merchants need status=archived or all.
    expect(screen.queryByText('Swiggy')).not.toBeInTheDocument();
    expect(requests[0]?.get('status')).toBe('active');
    expect(requests[0]?.get('limit')).toBe('50');

    await user.type(screen.getByLabelText(/^Search merchants/), 'zomato');
    expect(await screen.findByText('No merchants match your search.')).toBeInTheDocument();
    expect(requests.map((params) => params.get('q'))).toContain('zomato');
  });

  it('filters merchants by status', async () => {
    const requests = serveMerchantList(merchants());
    const user = userEvent.setup();
    renderRoute('/categories/merchants', { user: signedIn() });
    await findPageHeading('Merchants');
    await screen.findByRole('link', { name: 'Big Bazaar' });

    await user.selectOptions(screen.getByLabelText('Show merchants'), 'archived');
    expect(await screen.findByRole('link', { name: 'Swiggy' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Big Bazaar' })).not.toBeInTheDocument();
    const row = screen.getByRole('link', { name: 'Swiggy' }).closest('li');
    expect(row).not.toBeNull();
    expect(
      within(row as HTMLElement).getByText(
        /5 transactions · Last used Nov 3, 2026 · 2 other names/,
      ),
    ).toBeInTheDocument();
    expect(within(row as HTMLElement).getByText('Archived')).toBeInTheDocument();
    expect(requests.at(-1)?.get('status')).toBe('archived');

    await user.selectOptions(screen.getByLabelText('Show merchants'), 'all');
    expect(await screen.findByRole('link', { name: 'Big Bazaar' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Swiggy' })).toBeInTheDocument();
    expect(requests.at(-1)?.get('status')).toBe('all');

    await user.selectOptions(screen.getByLabelText('Show merchants'), 'merged');
    expect(await screen.findByText('No merchants with this status.')).toBeInTheDocument();
  });

  it('loads more merchants with the cursor', async () => {
    const cursors: (string | null)[] = [];
    server.use(
      http.get(`${API}/merchants`, ({ request }) => {
        const cursor = new URL(request.url).searchParams.get('cursor');
        cursors.push(cursor);
        return HttpResponse.json(
          cursor === 'page-2'
            ? page([makeMerchant({ id: MERCHANT_SWIGGY, name: 'Swiggy' })])
            : page([makeMerchant()], 'page-2'),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/merchants', { user: signedIn() });
    await findPageHeading('Merchants');
    await screen.findByRole('link', { name: 'Big Bazaar' });

    await user.click(screen.getByRole('button', { name: 'Load more' }));
    expect(await screen.findByRole('link', { name: 'Swiggy' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Big Bazaar' })).toBeInTheDocument();
    expect(cursors).toEqual([null, 'page-2']);
    // The last page has no cursor, so there is nothing more to load.
    expect(screen.queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
  });

  it('shows a first-use empty state', async () => {
    renderRoute('/categories/merchants', { user: signedIn() });
    await findPageHeading('Merchants');
    expect(await screen.findByText('No merchants yet')).toBeInTheDocument();
  });

  it('shows a recoverable error', async () => {
    server.use(
      http.get(`${API}/merchants`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-merch' }), {
          status: 500,
        }),
      ),
    );
    renderRoute('/categories/merchants', { user: signedIn() });
    await findPageHeading('Merchants');
    expect(await screen.findByText('We couldn’t load your merchants')).toBeInTheDocument();
    expect(screen.getByText('req-merch')).toBeInTheDocument();
  });

  it('shows a permission message when access is denied', async () => {
    server.use(
      http.get(`${API}/merchants`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/categories/merchants', { user: signedIn() });
    await findPageHeading('Merchants');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});

describe('MerchantDetailPage', () => {
  it('shows spending per month, details and other names', async () => {
    testBackend.categories = organizeCategories();
    serveDetail(
      makeMerchantDetail({
        spending: [
          { month: '2026-10', total: money('300.00'), count: 1 },
          { month: '2026-11', total: money('4200.00'), count: 3 },
          { month: '2026-11', total: money('12.50', 'USD'), count: 1 },
        ],
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    expect(document.title).toBe('Merchant · Montra');

    // One chart per currency; amounts are never added across currencies.
    const inr = screen.getByRole('region', { name: 'Monthly spending in INR' });
    expect(
      within(inr).getByText(/Spending with this merchant from October 2026 to November 2026/),
    ).toBeInTheDocument();
    expect(within(inr).getByText(/Highest: ₹4,200.00 in November 2026/)).toBeInTheDocument();
    await user.click(within(inr).getByRole('button', { name: 'Show as table' }));
    const table = within(inr).getByRole('table');
    expect(within(table).getByText('₹300.00')).toBeInTheDocument();
    expect(screen.getByRole('region', { name: 'Monthly spending in USD' })).toBeInTheDocument();

    expect(screen.getByText('Groceries')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /bigbazaar\.example/ })).toHaveAttribute(
      'href',
      'https://bigbazaar.example',
    );
    expect(screen.getByText('BIGBAZAAR*1234')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'View transactions' })).toHaveAttribute(
      'href',
      `/transactions?merchant_id=${MERCHANT_BIG_BAZAAR}&range=all`,
    );
  });

  it('adds another name for the merchant', async () => {
    serveDetail();
    let body: unknown;
    server.use(
      http.post(`${API}/merchants/aliases`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(makeMerchantDetail()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Add name' }));
    expect(screen.getByText('Enter a name.')).toBeInTheDocument();
    await user.type(screen.getByLabelText('Another name'), 'BB RETAIL');
    await user.click(screen.getByRole('button', { name: 'Add name' }));
    expect(await screen.findByText('Name added')).toBeInTheDocument();
    expect(body).toEqual({ alias: 'BB RETAIL', merchant_id: MERCHANT_BIG_BAZAAR });
  });

  it('removes another name after confirmation', async () => {
    serveDetail();
    let body: unknown;
    server.use(
      http.post(`${API}/merchants/aliases/remove`, async ({ request }) => {
        body = await request.json();
        const detail = makeMerchantDetail({ aliases: [], version: 2 });
        serveDetail(detail);
        return HttpResponse.json(envelope(detail));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Remove “BIGBAZAAR*1234”' }));
    const confirm = await screen.findByRole('dialog', { name: 'Remove this name?' });
    expect(
      within(confirm).getByText(/New transactions named “BIGBAZAAR\*1234” won’t be matched/),
    ).toBeInTheDocument();
    await user.click(within(confirm).getByRole('button', { name: 'Remove name' }));
    expect(await screen.findByText('Name removed')).toBeInTheDocument();
    expect(body).toEqual({ alias: 'BIGBAZAAR*1234', merchant_id: MERCHANT_BIG_BAZAAR });
    expect(await screen.findByText('No other names yet.')).toBeInTheDocument();
  });

  it('edits only the changed fields with the version and clears the default category', async () => {
    testBackend.categories = organizeCategories();
    serveDetail();
    let patched: unknown;
    server.use(
      http.patch(`${API}/merchants/:id`, async ({ request }) => {
        patched = await request.json();
        return HttpResponse.json(envelope(makeMerchantDetail()));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Edit' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit merchant' });
    const defaultCategory = await within(dialog).findByLabelText(/^Default category/);
    expect(defaultCategory).toHaveValue(CATEGORY_GROCERIES);
    await user.selectOptions(defaultCategory, '');
    const website = within(dialog).getByLabelText(/^Website/);
    await user.clear(website);
    await user.type(website, 'bigbazaar');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(
      await within(dialog).findByText(
        'Enter a full web address starting with http:// or https://.',
      ),
    ).toBeInTheDocument();
    await user.clear(website);
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Merchant updated')).toBeInTheDocument();
    expect(patched).toEqual({ website: '', clear_default_category: true, version: 1 });
  });

  it('reloads the merchant after a version conflict', async () => {
    testBackend.categories = organizeCategories();
    serveDetail();
    const bodies: unknown[] = [];
    server.use(
      http.patch(`${API}/merchants/:id`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          // Someone renamed it meanwhile.
          serveDetail(makeMerchantDetail({ name: 'Big Bazaar Retail', version: 2 }));
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeMerchantDetail({ notes: 'Monthly', version: 3 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Edit' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit merchant' });
    const notes = await within(dialog).findByLabelText(/^Notes/);
    await user.clear(notes);
    await user.type(notes, 'Monthly');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));

    expect(await within(dialog).findByText('This was changed somewhere else')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Name')).toHaveValue('Big Bazaar Retail');
    });
    const reloaded = within(dialog).getByLabelText(/^Notes/);
    await user.clear(reloaded);
    await user.type(reloaded, 'Monthly');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Merchant updated')).toBeInTheDocument();
    expect(bodies).toEqual([
      { notes: 'Monthly', version: 1 },
      { notes: 'Monthly', version: 2 },
    ]);
  });

  it('offers to merge when another merchant already has the name', async () => {
    testBackend.categories = organizeCategories();
    serveDetail();
    let merged: unknown;
    server.use(
      http.patch(`${API}/merchants/:id`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                message: 'Another merchant already has this name; merge them instead.',
                code: 'name_taken',
                params: { name: 'Swiggy', merchant_id: MERCHANT_SWIGGY },
              },
            ],
          }),
          { status: 409 },
        ),
      ),
      http.post(`${API}/merchants/merge/preview`, () =>
        HttpResponse.json(
          envelope({
            preview: true,
            affected: makeMerchantMergeAffected({ transactions: 3, aliases: 2 }),
          }),
        ),
      ),
      http.post(`${API}/merchants/merge`, async ({ request }) => {
        merged = await request.json();
        serveDetail(makeMerchantDetail({ id: MERCHANT_SWIGGY, name: 'Swiggy', aliases: [] }));
        return HttpResponse.json(envelope(makeMerchantDetail({ id: MERCHANT_SWIGGY })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Edit' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit merchant' });
    const name = await within(dialog).findByLabelText('Name');
    await user.clear(name);
    await user.type(name, 'Swiggy');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(
      await within(dialog).findByText('Another merchant is already called “Swiggy”.'),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Merge into “Swiggy”' }));

    const merge = await screen.findByRole('dialog', { name: 'Merge into Swiggy' });
    const preview = await within(merge).findByRole('status', { name: 'What will change' });
    expect(await within(preview).findByText('3 transactions')).toBeInTheDocument();
    expect(within(preview).getByText('2 other names for Swiggy')).toBeInTheDocument();
    await user.click(within(merge).getByRole('button', { name: 'Merge' }));
    expect(await screen.findByText('Merchants merged')).toBeInTheDocument();
    expect(merged).toEqual({ source_ids: [MERCHANT_BIG_BAZAAR], target_id: MERCHANT_SWIGGY });
    // This merchant is now part of Swiggy, so its page opens.
    await findPageHeading('Swiggy');
  });

  it('archives after confirmation and can unarchive, sending the version', async () => {
    serveDetail();
    const bodies: unknown[] = [];
    server.use(
      http.patch(`${API}/merchants/:id`, async ({ request }) => {
        const body = (await request.json()) as { archived: boolean; version: number };
        bodies.push(body);
        const detail = makeMerchantDetail({
          status: body.archived ? 'archived' : 'active',
          version: body.version + 1,
        });
        serveDetail(detail);
        return HttpResponse.json(envelope(detail));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Archive merchant' }));
    const confirm = await screen.findByRole('dialog', { name: 'Archive this merchant?' });
    await user.click(within(confirm).getByRole('button', { name: 'Archive' }));
    expect(await screen.findByText('Merchant archived')).toBeInTheDocument();
    expect(await screen.findByText('This merchant is archived')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Unarchive' }));
    expect(await screen.findByText('Merchant is active again')).toBeInTheDocument();
    expect(bodies).toEqual([
      { archived: true, version: 1 },
      { archived: false, version: 2 },
    ]);
  });

  it('merges duplicates into this merchant after reviewing what moves', async () => {
    testBackend.merchants = merchants();
    serveDetail();
    let previewed: unknown;
    let merged: unknown;
    server.use(
      http.post(`${API}/merchants/merge/preview`, async ({ request }) => {
        previewed = await request.json();
        return HttpResponse.json(
          envelope({
            preview: true,
            affected: makeMerchantMergeAffected({
              transactions: 1,
              aliases: 2,
              budget_filters: 1,
            }),
          }),
        );
      }),
      http.post(`${API}/merchants/merge`, async ({ request }) => {
        merged = await request.json();
        return HttpResponse.json(envelope(makeMerchantDetail({ transaction_count: 4 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    await findPageHeading('Big Bazaar');
    await user.click(screen.getByRole('button', { name: 'Merge duplicates into this merchant' }));
    const dialog = await screen.findByRole('dialog', { name: 'Merge into Big Bazaar' });
    // The merchant itself is not offered.
    expect(
      await within(dialog).findByRole('checkbox', { name: /BigBazaar Online/ }),
    ).toBeInTheDocument();
    expect(within(dialog).queryByRole('checkbox', { name: /^Big Bazaar/ })).not.toBeInTheDocument();

    await user.click(within(dialog).getByRole('button', { name: 'Review merge' }));
    expect(within(dialog).getByText('Choose at least one merchant.')).toBeInTheDocument();
    await user.click(within(dialog).getByRole('checkbox', { name: /BigBazaar Online/ }));
    await user.click(within(dialog).getByRole('button', { name: 'Review merge' }));
    expect(within(dialog).getByText('Merge 1 merchant into Big Bazaar?')).toBeInTheDocument();
    expect(within(dialog).getByText('BigBazaar Online · 1 transaction')).toBeInTheDocument();
    const preview = await within(dialog).findByRole('status', { name: 'What will change' });
    expect(await within(preview).findByText('1 transaction')).toBeInTheDocument();
    expect(within(preview).getByText('2 other names for Big Bazaar')).toBeInTheDocument();
    expect(
      within(preview).getByText('1 merchant budget (it will track Big Bazaar instead)'),
    ).toBeInTheDocument();
    expect(previewed).toEqual({
      source_ids: [MERCHANT_BB_ONLINE],
      target_id: MERCHANT_BIG_BAZAAR,
    });

    await user.click(within(dialog).getByRole('button', { name: 'Merge' }));
    expect(await screen.findByText('Merchants merged')).toBeInTheDocument();
    await waitFor(() => {
      expect(merged).toEqual({ source_ids: [MERCHANT_BB_ONLINE], target_id: MERCHANT_BIG_BAZAAR });
    });
  });

  it('shows a merged merchant with a link to the one it was merged into', async () => {
    serveDetail(
      makeMerchantDetail({
        id: MERCHANT_BB_ONLINE,
        name: 'BigBazaar Online',
        status: 'merged',
        merged_into_id: MERCHANT_BIG_BAZAAR,
      }),
    );
    renderRoute(`/categories/merchants/${MERCHANT_BB_ONLINE}`, { user: signedIn() });
    await findPageHeading('BigBazaar Online');
    expect(screen.getByText('This merchant was merged')).toBeInTheDocument();
    expect(
      screen.getByRole('link', { name: 'Open the merchant it was merged into' }),
    ).toHaveAttribute('href', `/categories/merchants/${MERCHANT_BIG_BAZAAR}`);
    // A merged merchant cannot be changed.
    expect(screen.queryByRole('button', { name: 'Edit' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Add name' })).not.toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'Merge duplicates into this merchant' }),
    ).not.toBeInTheDocument();
  });

  it('says when the merchant no longer exists', async () => {
    server.use(
      http.get(`${API}/merchants/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    expect(await screen.findByRole('heading', { name: 'Merchant not found' })).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: 'All merchants' }).length).toBeGreaterThan(0);
  });

  it('shows a recoverable error', async () => {
    server.use(
      http.get(`${API}/merchants/:id`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-md' }), {
          status: 500,
        }),
      ),
    );
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    expect(
      await screen.findByRole('heading', { name: 'We couldn’t load this merchant' }),
    ).toBeInTheDocument();
    expect(screen.getByText('req-md')).toBeInTheDocument();
  });

  it('shows a permission message when access is denied', async () => {
    server.use(
      http.get(`${API}/merchants/:id`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute(`/categories/merchants/${MERCHANT_BIG_BAZAAR}`, { user: signedIn() });
    expect(
      await screen.findByRole('heading', { name: 'You don’t have access to this' }),
    ).toBeInTheDocument();
  });
});
