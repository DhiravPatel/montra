import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, describe, expect, it } from 'vitest';
import type { Usage } from '@/features/admin/types';
import { makeDaily, makeUsage } from '@/tests/adminFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const admin = () => makeUser({ onboarding_completed: true, platform_role: 'admin' });

function serveUsage(byDays: (days: number) => Usage = (days) => makeUsage({ window_days: days })) {
  const requested: number[] = [];
  server.use(
    http.get(`${API}/admin/usage`, ({ request }) => {
      const days = Number(new URL(request.url).searchParams.get('days'));
      requested.push(days);
      return HttpResponse.json(envelope(byDays(days)));
    }),
  );
  return requested;
}

async function openUsage(path = '/staff/usage') {
  const events = userEvent.setup();
  const view = renderRoute(path, { user: admin() });
  await findPageHeading('Usage');
  return { events, ...view };
}

beforeAll(async () => {
  await import('./AdminUsagePage');
});

describe('AdminUsagePage', () => {
  it('shows aggregate counts for the window, with a note that nothing personal is shown', async () => {
    const requested = serveUsage();
    await openUsage();
    expect(screen.getByText('Aggregate counts only')).toBeVisible();
    expect(screen.getByRole('radio', { name: 'Last 30 days' })).toBeChecked();

    const now = await screen.findByRole('region', { name: 'Right now' });
    const tile = (region: HTMLElement, label: string) =>
      within(region).getByText(label).closest('div')!;
    expect(within(tile(now, 'Active accounts')).getByText('1,284')).toBeVisible();
    expect(within(tile(now, 'Accounts being deleted')).getByText('2')).toBeVisible();
    expect(within(tile(now, 'Open support requests')).getByText('5')).toBeVisible();
    expect(within(tile(now, 'Stored files')).getByText('150 MB')).toBeVisible();
    expect(within(tile(now, 'Stored files')).getByText('412 files')).toBeVisible();

    const window = screen.getByRole('region', { name: 'In the last 30 days' });
    expect(within(tile(window, 'New accounts')).getByText('37')).toBeVisible();
    expect(within(tile(window, 'Transactions created')).getByText('3,640')).toBeVisible();
    expect(within(tile(window, 'Emails sent')).getByText('118')).toBeVisible();
    expect(within(tile(window, 'AI requests')).getByText('Cost $0.00')).toBeVisible();

    const dead = screen.getByRole('table', { name: 'Jobs that gave up' });
    expect(within(dead).getByRole('row', { name: /support\.notify_staff/ })).toHaveTextContent('3');
    const notifications = screen.getByRole('table', { name: 'Notification deliveries' });
    expect(within(notifications).getByRole('row', { name: /email sent/ })).toHaveTextContent('118');
    expect(requested).toEqual([30]);
  });

  it('draws the daily series as small multiples with a table alternative', async () => {
    serveUsage(() => makeUsage({ daily: makeDaily(3) }));
    const { events } = await openUsage();
    const daily = await screen.findByRole('figure', { name: 'Daily activity' });
    expect(within(daily).getByText('Daily counts from Nov 3, 2026 to Nov 5, 2026.')).toBeVisible();
    for (const name of ['New accounts', 'Transactions created', 'Emails sent']) {
      expect(within(daily).getByRole('heading', { name })).toBeVisible();
    }
    await events.click(within(daily).getByRole('button', { name: 'Show as table' }));
    const table = within(daily).getByRole('table', { name: 'Daily activity' });
    const rows = within(table).getAllByRole('row');
    expect(rows).toHaveLength(4);
    expect(rows[1]).toHaveTextContent('Nov 3, 2026');
    expect(
      within(rows[1]!)
        .getAllByRole('cell')
        .map((cell) => cell.textContent),
    ).toEqual(['2', '42', '7']);
  });

  it('switches the window, keeping it in the address', async () => {
    const requested = serveUsage();
    const { events, router } = await openUsage();
    await screen.findByRole('region', { name: 'In the last 30 days' });
    await events.click(screen.getByRole('radio', { name: 'Last 7 days' }));

    expect(await screen.findByRole('region', { name: 'In the last 7 days' })).toBeVisible();
    expect(router.state.location.search).toBe('?days=7');
    expect(requested).toEqual([30, 7]);
  });

  it('says when the window has no daily counts', async () => {
    serveUsage(() => makeUsage({ daily: [] }));
    await openUsage();
    expect(await screen.findByText('No days to show')).toBeVisible();
  });

  it('offers a retry when usage cannot be loaded', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/admin/usage`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope(makeUsage()));
      }),
    );
    const { events } = await openUsage();
    expect(await screen.findByText('We couldn’t load usage')).toBeVisible();
    await events.click(screen.getByRole('button', { name: 'Try again' }));
    await waitFor(() => {
      expect(screen.getByRole('region', { name: 'Right now' })).toBeVisible();
    });
  });

  it('shows the permission state to everyone but platform admins', async () => {
    server.use(
      http.get(`${API}/admin/usage`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/staff/usage', {
      user: makeUser({ onboarding_completed: true, platform_role: 'support' }),
    });
    await findPageHeading('Usage');
    expect(await screen.findByText('This page is for Montra admins')).toBeVisible();
    expect(screen.queryByRole('region', { name: 'Right now' })).not.toBeInTheDocument();
  });
});
