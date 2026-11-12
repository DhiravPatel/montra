import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import { todayInTimeZone } from '@/shared/formatting/dates';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { MONEY_GROUP, makeReport, serveMoneyGroup } from '@/tests/groupMoneyFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const PATH = `/groups/${MONEY_GROUP}/reports`;

function serveReport(report = makeReport()) {
  const seen: string[] = [];
  server.use(
    http.get(`${API}/groups/:id/reports`, ({ request }) => {
      seen.push(new URL(request.url).search);
      return HttpResponse.json(envelope(report));
    }),
  );
  return seen;
}

/** Captures saved files instead of downloading them. */
function captureDownloads() {
  const files: { name: string; blob: Blob }[] = [];
  let pending: Blob | null = null;
  Object.assign(URL, {
    createObjectURL: vi.fn((blob: Blob) => {
      pending = blob;
      return 'blob:group-export';
    }),
    revokeObjectURL: vi.fn(),
  });
  const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (
    this: HTMLAnchorElement,
  ) {
    if (pending) files.push({ name: this.download, blob: pending });
  });
  return {
    files,
    restore: () => {
      click.mockRestore();
    },
  };
}

describe('GroupReportsPage', () => {
  it('shows server totals with a table alternative for every chart', async () => {
    serveMoneyGroup();
    serveReport();
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Reports');
    const summary = await screen.findByRole('region', { name: 'Summary' });
    expect(within(summary).getByText('₹3,019.99')).toBeInTheDocument();
    expect(within(summary).getByText('5 expenses')).toBeInTheDocument();
    expect(within(summary).getByText('1 disputed')).toBeInTheDocument();
    expect(within(summary).getByText('₹1,006.66')).toBeInTheDocument();
    expect(within(summary).getByText('Shared by 3 people')).toBeInTheDocument();
    expect(within(summary).getByText('₹1,216.64')).toBeInTheDocument();

    const categories = screen.getByRole('figure', { name: 'Spending by category in INR' });
    expect(
      within(categories).getByText('Most spent on Utilities: ₹1,999.99 across 2 expenses.'),
    ).toBeInTheDocument();
    await user.click(within(categories).getByRole('button', { name: 'Show as table' }));
    const table = within(categories).getByRole('table', { name: 'Spending by category in INR' });
    expect(within(table).getByRole('row', { name: /Food & dining/ })).toHaveTextContent('₹880.00');
    expect(within(table).getByRole('row', { name: /Uncategorized/ })).toHaveTextContent('₹140.00');

    const months = screen.getByRole('figure', { name: 'Spending by month in INR' });
    await user.click(within(months).getByRole('button', { name: 'Show as table' }));
    expect(within(months).getByRole('row', { name: /November 2026/ })).toHaveTextContent(
      '₹2,020.00',
    );

    const people = screen.getByRole('figure', { name: 'Shares by person in INR' });
    await user.click(within(people).getByRole('button', { name: 'Show as table' }));
    const ravi = within(people).getByRole('row', { name: /Ravi Kumar/ });
    expect(ravi).toHaveTextContent('₹1,879.99');
    expect(ravi).toHaveTextContent('₹836.72');

    // Other currencies are listed per currency, never added together.
    const other = screen.getByRole('table', { name: 'Paid in other currencies' });
    const usd = within(other).getByRole('row', { name: /USD/ });
    expect(usd).toHaveTextContent('$100.00');
    expect(usd).toHaveTextContent('₹8,325.00');
    const payments = screen.getByRole('region', { name: 'Payments between members' });
    expect(within(payments).getByText('₹950.00')).toBeInTheDocument();
    expect(within(payments).getByText('3 payments')).toBeInTheDocument();
  });

  it('asks for a date range and checks its order first', async () => {
    serveMoneyGroup();
    const seen = serveReport();
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Reports');
    await screen.findByRole('region', { name: 'Summary' });
    await user.type(screen.getByLabelText('From'), '2026-11-30');
    await user.type(screen.getByLabelText('To'), '2026-11-01');
    await user.click(screen.getByRole('button', { name: 'Apply' }));
    expect(screen.getByLabelText('To')).toHaveAccessibleDescription(
      /The start date must be on or before the end date./,
    );
    await user.clear(screen.getByLabelText('From'));
    await user.type(screen.getByLabelText('From'), '2026-10-01');
    await user.click(screen.getByRole('button', { name: 'Apply' }));
    expect(await screen.findByText(/^From .* to .*\.$/)).toBeInTheDocument();
    expect(seen).toEqual(['', '?from=2026-10-01&to=2026-11-01']);
    await user.click(screen.getByRole('button', { name: 'All time' }));
    expect(await screen.findByText('All shared expenses so far.')).toBeInTheDocument();
  });

  it('downloads the CSV with the server’s dated file name', async () => {
    serveMoneyGroup();
    serveReport();
    server.use(
      http.get(
        `${API}/groups/:id/export`,
        () =>
          new HttpResponse('record,date,description\nexpense,2026-11-04,Groceries\n', {
            headers: {
              'Content-Type': 'text/csv; charset=utf-8',
              'Content-Disposition': 'attachment; filename="flat-4b-expenses-2026-11-06.csv"',
            },
          }),
      ),
    );
    const downloads = captureDownloads();
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Reports');
    await user.click(await screen.findByRole('button', { name: 'Download CSV' }));
    expect(await screen.findByText('Download started')).toBeInTheDocument();
    expect(downloads.files).toHaveLength(1);
    expect(downloads.files[0]!.name).toBe('flat-4b-expenses-2026-11-06.csv');
    expect(downloads.files[0]!.blob.type).toBe('text/csv;charset=utf-8');
    expect(await downloads.files[0]!.blob.text()).toBe(
      'record,date,description\nexpense,2026-11-04,Groceries\n',
    );
    downloads.restore();
  });

  it('uses a neutral file name when the server’s is unexpected', async () => {
    serveMoneyGroup();
    serveReport();
    server.use(
      http.get(
        `${API}/groups/:id/export`,
        () =>
          new HttpResponse('record\n', {
            headers: {
              'Content-Type': 'text/csv',
              'Content-Disposition': 'attachment; filename="../../etc/passwd"',
            },
          }),
      ),
    );
    const downloads = captureDownloads();
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Reports');
    await user.click(await screen.findByRole('button', { name: 'Download CSV' }));
    expect(await screen.findByText('Download started')).toBeInTheDocument();
    expect(downloads.files[0]!.name).toBe(`group-expenses-${todayInTimeZone('Asia/Kolkata')}.csv`);
    downloads.restore();
  });

  it('says when an export fails', async () => {
    serveMoneyGroup();
    serveReport();
    server.use(
      http.get(`${API}/groups/:id/export`, () =>
        HttpResponse.json(errorBody({ code: 'RATE_LIMITED' }), { status: 429 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Reports');
    await user.click(await screen.findByRole('button', { name: 'Download CSV' }));
    expect(await screen.findByText('We couldn’t download the CSV')).toBeInTheDocument();
  });

  it('shows an empty state and a recoverable error', async () => {
    serveMoneyGroup();
    serveReport(makeReport({ expense_count: 0, by_category: [], by_member: [], by_month: [] }));
    const { unmount } = renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Reports');
    expect(await screen.findByText('Nothing to report yet')).toBeInTheDocument();
    unmount();

    server.use(
      http.get(`${API}/groups/:id/reports`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-rep' }), {
          status: 500,
        }),
      ),
    );
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Reports');
    expect(await screen.findByText('We couldn’t load the report')).toBeInTheDocument();
    expect(screen.getByText('req-rep')).toBeInTheDocument();
  });
});
