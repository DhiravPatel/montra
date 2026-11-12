import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { ACCOUNT_CARD, ACCOUNT_CASH, makeAccount, makeCard } from '@/tests/financeFixtures';
import { IMPORT_ID, IMPORT_OLD, makeBatch, pageEnvelope } from '@/tests/importsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

beforeAll(async () => {
  await import('./ImportsPage');
});

beforeEach(() => {
  testBackend.accounts = [makeAccount(), makeCard()];
});

describe('ImportsPage', () => {
  it('lists imports with their status, server counts, dates and a way to continue', async () => {
    server.use(
      http.get(`${API}/imports`, () =>
        HttpResponse.json(
          envelope([
            makeBatch({
              status: 'completed',
              imported_count: 3,
              skipped_count: 1,
              duplicate_rows: 0,
              version: 2,
            }),
            makeBatch({
              id: IMPORT_OLD,
              account_id: ACCOUNT_CARD,
              status: 'needs_mapping',
              total_rows: 0,
              duplicate_rows: 0,
              statement_start: undefined,
              statement_end: undefined,
              created_at: '2026-11-01T10:00:00Z',
            }),
          ]),
        ),
      ),
    );
    renderRoute('/imports', { user: signedIn() });
    await findPageHeading('Statement imports');
    expect(screen.getAllByRole('link', { name: 'New import' })[0]).toHaveAttribute(
      'href',
      '/imports/new',
    );

    const history = screen.getByRole('region', { name: 'Import history' });
    const first = await within(history).findByRole('link', { name: /^Wallet · Nov 5, 2026/ });
    expect(first).toHaveAttribute('href', `/imports/${IMPORT_ID}`);
    const items = within(history).getAllByRole('listitem');
    expect(within(items[0]!).getByText('Imported')).toBeInTheDocument();
    expect(within(items[0]!).getByText('5 rows · 3 imported · 1 skipped')).toBeInTheDocument();
    expect(within(items[0]!).getByText('Statement: Oct 26 – Nov 3, 2026')).toBeInTheDocument();

    expect(within(items[1]!).getByText('Needs column setup')).toBeInTheDocument();
    expect(
      within(items[1]!).getByRole('link', { name: /^Continue review: HDFC Credit/ }),
    ).toHaveAttribute('href', `/imports/new?import_id=${IMPORT_OLD}`);
  });

  it('filters the history by account and starts a new import for that account', async () => {
    const seen: URL[] = [];
    server.use(
      http.get(`${API}/imports`, ({ request }) => {
        const url = new URL(request.url);
        seen.push(url);
        return HttpResponse.json(
          envelope(url.searchParams.get('account_id') === ACCOUNT_CASH ? [makeBatch()] : []),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/imports', { user: signedIn() });
    await findPageHeading('Statement imports');
    expect(await screen.findByText('No imports yet')).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText('Show imports for'), ACCOUNT_CASH);
    expect(await screen.findByText('Ready to review')).toBeInTheDocument();
    expect(seen.at(-1)?.searchParams.get('account_id')).toBe(ACCOUNT_CASH);
    expect(screen.getAllByRole('link', { name: 'New import' })[0]).toHaveAttribute(
      'href',
      `/imports/new?account_id=${ACCOUNT_CASH}`,
    );
  });

  it('shows a first-use empty state', async () => {
    server.use(http.get(`${API}/imports`, () => HttpResponse.json(envelope([]))));
    renderRoute('/imports', { user: signedIn() });
    await findPageHeading('Statement imports');
    expect(await screen.findByText('No imports yet')).toBeInTheDocument();
    expect(
      screen.getByText(/Download a statement from your bank as CSV, XLSX or OFX/),
    ).toBeInTheDocument();
  });

  it('shows a recoverable error and retries', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/imports`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-imp' }), {
            status: 500,
          });
        }
        return HttpResponse.json(envelope([makeBatch()]));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/imports', { user: signedIn() });
    await findPageHeading('Statement imports');
    expect(await screen.findByText('We couldn’t load your imports')).toBeInTheDocument();
    expect(screen.getByText('req-imp')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('Ready to review')).toBeInTheDocument();
  });

  it('shows a permission message when access is refused', async () => {
    server.use(
      http.get(`${API}/imports`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/imports', { user: signedIn() });
    await findPageHeading('Statement imports');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('loads older imports with the cursor from meta.next_cursor', async () => {
    const requests: URLSearchParams[] = [];
    server.use(
      http.get(`${API}/imports`, ({ request }) => {
        const params = new URL(request.url).searchParams;
        requests.push(params);
        return params.get('cursor') === 'page-2'
          ? HttpResponse.json(
              pageEnvelope([
                makeBatch({
                  id: IMPORT_OLD,
                  status: 'completed',
                  imported_count: 2,
                  created_at: '2026-10-01T10:00:00Z',
                }),
              ]),
            )
          : HttpResponse.json(
              pageEnvelope([makeBatch({ status: 'completed', imported_count: 3 })], 'page-2'),
            );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/imports', { user: signedIn() });
    await findPageHeading('Statement imports');
    const history = screen.getByRole('region', { name: 'Import history' });
    expect(await within(history).findByRole('link', { name: /Nov 5, 2026/ })).toBeInTheDocument();
    await user.click(within(history).getByRole('button', { name: 'Load more' }));
    expect(await within(history).findByRole('link', { name: /Oct 1, 2026/ })).toBeInTheDocument();
    expect(within(history).getByRole('link', { name: /Nov 5, 2026/ })).toBeInTheDocument();
    expect(within(history).queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
    expect(requests.map((params) => params.get('cursor'))).toEqual([null, 'page-2']);
    expect(requests[0]?.get('limit')).toBe('50');
  });

  it('refreshes the list while an import is in progress, then stops', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/imports`, () => {
        calls += 1;
        return HttpResponse.json(
          envelope([
            makeBatch(
              calls === 1
                ? { status: 'processing' }
                : { status: 'completed', imported_count: 3, version: 2 },
            ),
          ]),
        );
      }),
    );
    renderRoute('/imports', { user: signedIn() });
    await findPageHeading('Statement imports');
    expect(await screen.findByText('Importing')).toBeInTheDocument();
    expect(await screen.findByText('Imported')).toBeInTheDocument();
    await new Promise((resolve) => setTimeout(resolve, 1300));
    await waitFor(() => {
      expect(calls).toBe(2);
    });
  });
});
