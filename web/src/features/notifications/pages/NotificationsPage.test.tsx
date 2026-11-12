import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  BILL_ID,
  EXPENSE_ID,
  GOAL_ID,
  GROUP_ID,
  NOTIFICATION_BILL,
  NOTIFICATION_EXPENSE,
  NOTIFICATION_GOAL,
  NOTIFICATION_SECURITY,
  SUPPORT_REQUEST_ID,
  makeNotification,
  notificationPage,
  securityNotification,
  serveUnreadCount,
  supportReplyNotification,
} from '@/tests/notificationsFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import type { AppNotification } from '../types';

const signedIn = () => makeUser({ onboarding_completed: true });

/** The main content (the bell in the shell also says "Notifications"). */
const main = () => within(screen.getByRole('main'));

/** The shell mounts the bell twice (sidebar and small-screen header); both show the count. */
async function expectBell(name: string) {
  expect(await screen.findAllByRole('link', { name })).toHaveLength(2);
}

function billNotification(): AppNotification {
  return makeNotification({
    id: NOTIFICATION_BILL,
    category: 'bill',
    event_type: 'recurring_due_soon',
    title: 'A bill is due soon',
    body: 'Open the schedule to record or skip this occurrence.',
    // The server's own path differs from the web route; links are built from IDs.
    deep_link: `/bills/${BILL_ID}`,
    entity_type: 'bill',
    entity_id: BILL_ID,
    created_at: '2026-11-03T09:00:00Z',
  });
}

function expenseNotification(): AppNotification {
  return makeNotification({
    id: NOTIFICATION_EXPENSE,
    category: 'group',
    event_type: 'expense_added',
    title: 'New expense in Goa trip',
    body: 'Open the group to see it.',
    deep_link: `/groups/${GROUP_ID}/expenses/${EXPENSE_ID}`,
    entity_type: 'group_expense',
    entity_id: EXPENSE_ID,
    group_id: GROUP_ID,
    read_at: '2026-11-03T10:00:00Z',
    created_at: '2026-11-02T09:00:00Z',
  });
}

/** Serves GET /notifications from a mutable list and records each query. */
function serveList(items: AppNotification[]) {
  const state = { items, queries: [] as URLSearchParams[] };
  server.use(
    http.get(`${API}/notifications`, ({ request }) => {
      const query = new URL(request.url).searchParams;
      state.queries.push(query);
      let list = state.items;
      if (query.get('unread') === 'true') list = list.filter((item) => !item.read_at);
      list = list.filter((item) =>
        query.get('archived') === 'true' ? Boolean(item.archived_at) : !item.archived_at,
      );
      const category = query.get('category');
      if (category) list = list.filter((item) => item.category === category);
      return HttpResponse.json(notificationPage(list));
    }),
  );
  return state;
}

/** Serves PATCH /notifications/{id}: applies the change to the list and records bodies. */
function servePatch(state: { items: AppNotification[] }) {
  const bodies: { id: string; body: unknown }[] = [];
  server.use(
    http.patch(`${API}/notifications/:id`, async ({ request, params }) => {
      const body = (await request.json()) as { read?: boolean; archived?: boolean };
      const id = String(params.id);
      bodies.push({ id, body });
      state.items = state.items.map((item) => {
        if (item.id !== id) return item;
        const next = { ...item };
        if (body.read === true) next.read_at = '2026-11-04T10:00:00Z';
        if (body.read === false) delete next.read_at;
        if (body.archived === true) next.archived_at = '2026-11-04T10:00:00Z';
        if (body.archived === false) delete next.archived_at;
        return next;
      });
      const updated = state.items.find((item) => item.id === id);
      if (!updated) {
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }
      return HttpResponse.json(envelope(updated));
    }),
  );
  return bodies;
}

describe('NotificationsPage', () => {
  it('lists notifications with unread markers and links built from record IDs', async () => {
    serveUnreadCount(3);
    const list = serveList([
      makeNotification(),
      billNotification(),
      expenseNotification(),
      securityNotification(),
      supportReplyNotification(),
    ]);
    renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');

    const goal = await main().findByRole('link', { name: 'Emergency fund reached 50%' });
    expect(goal).toHaveAttribute('href', `/goals/${GOAL_ID}`);
    expect(main().getByRole('link', { name: 'A bill is due soon' })).toHaveAttribute(
      'href',
      `/planning/bills/${BILL_ID}`,
    );
    expect(main().getByRole('link', { name: 'New expense in Goa trip' })).toHaveAttribute(
      'href',
      `/groups/${GROUP_ID}/expenses/${EXPENSE_ID}`,
    );
    expect(main().getByRole('link', { name: 'Your password was changed' })).toHaveAttribute(
      'href',
      '/settings/security',
    );
    // A support reply opens the request's thread (reference only in the title, never the text).
    const reply = main().getByRole('link', { name: 'Support replied to request D4E5F6A7' });
    expect(reply).toHaveAttribute('href', `/help/requests/${SUPPORT_REQUEST_ID}`);
    expect(reply.closest('li')).toHaveTextContent('Your Montra account');
    // Unread ones say so in words (three unread here), not by color alone.
    expect(main().getAllByText('New')).toHaveLength(3);
    expect(
      main().getByRole('button', { name: 'Mark as unread: Your password was changed' }),
    ).toBeInTheDocument();
    expect(main().getByText('Showing 5 notifications')).toBeInTheDocument();
    expect(list.queries[0]?.get('limit')).toBe('30');
    expect(list.queries[0]?.has('unread')).toBe(false);
    expect(list.queries[0]?.has('archived')).toBe(false);
    await expectBell('Notifications, 3 unread');
  });

  it('marks one read and unread again, refreshing the bell', async () => {
    const counts = serveUnreadCount(1, 0, 1);
    const list = serveList([makeNotification()]);
    const bodies = servePatch(list);
    const user = userEvent.setup();
    renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');
    await expectBell('Notifications, 1 unread');

    await user.click(
      await main().findByRole('button', { name: 'Mark as read: Emergency fund reached 50%' }),
    );
    expect(
      await main().findByRole('button', { name: 'Mark as unread: Emergency fund reached 50%' }),
    ).toBeInTheDocument();
    expect(main().queryByText('New')).not.toBeInTheDocument();
    await expectBell('Notifications, none unread');

    await user.click(
      main().getByRole('button', { name: 'Mark as unread: Emergency fund reached 50%' }),
    );
    expect(await main().findByText('New')).toBeInTheDocument();
    await expectBell('Notifications, 1 unread');
    expect(bodies).toEqual([
      { id: NOTIFICATION_GOAL, body: { read: true } },
      { id: NOTIFICATION_GOAL, body: { read: false } },
    ]);
    expect(counts.calls).toBe(3);
  });

  it('opening a notification marks it read and goes to the related page', async () => {
    serveUnreadCount(1, 0);
    const list = serveList([securityNotification({ read_at: undefined })]);
    const bodies = servePatch(list);
    const user = userEvent.setup();
    const { router } = renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');
    await user.click(await main().findByRole('link', { name: 'Your password was changed' }));
    await findPageHeading('Security');
    expect(router.state.location.pathname).toBe('/settings/security');
    await waitFor(() => {
      expect(bodies).toEqual([{ id: NOTIFICATION_SECURITY, body: { read: true } }]);
    });
    await expectBell('Notifications, none unread');
  });

  it('marks everything as read', async () => {
    serveUnreadCount(2, 0);
    const list = serveList([makeNotification(), billNotification()]);
    let calls = 0;
    server.use(
      http.post(`${API}/notifications/read-all`, () => {
        calls += 1;
        list.items = list.items.map((item) => ({ ...item, read_at: '2026-11-04T10:00:00Z' }));
        return HttpResponse.json(envelope({ updated: 2 }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');
    expect(await main().findAllByText('New')).toHaveLength(2);
    await expectBell('Notifications, 2 unread');

    await user.click(main().getByRole('button', { name: 'Mark all as read' }));
    expect(await screen.findByText('Marked 2 notifications as read')).toBeInTheDocument();
    await waitFor(() => {
      expect(main().queryByText('New')).not.toBeInTheDocument();
    });
    await expectBell('Notifications, none unread');
    expect(main().getByRole('button', { name: 'Mark all as read' })).toBeDisabled();
    expect(calls).toBe(1);
  });

  it('filters by view and category (kept in the URL) and loads more pages', async () => {
    serveUnreadCount(1);
    const queries: URLSearchParams[] = [];
    server.use(
      http.get(`${API}/notifications`, ({ request }) => {
        const query = new URL(request.url).searchParams;
        queries.push(query);
        if (query.get('cursor') === 'page-2') {
          return HttpResponse.json(notificationPage([billNotification()]));
        }
        return HttpResponse.json(notificationPage([makeNotification()], 'page-2'));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');
    await main().findByRole('link', { name: 'Emergency fund reached 50%' });

    await user.click(main().getByRole('button', { name: 'Load more' }));
    expect(await main().findByRole('link', { name: 'A bill is due soon' })).toBeInTheDocument();
    expect(queries.at(-1)?.get('cursor')).toBe('page-2');
    expect(main().queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
    expect(main().getByText('Showing 2 notifications')).toBeInTheDocument();

    await user.click(main().getByRole('radio', { name: 'Unread' }));
    await waitFor(() => {
      expect(queries.at(-1)?.get('unread')).toBe('true');
    });
    await user.selectOptions(main().getByLabelText(/^Category/), 'goal');
    await waitFor(() => {
      expect(queries.at(-1)?.get('category')).toBe('goal');
    });
    expect(queries.at(-1)?.get('unread')).toBe('true');
    expect(router.state.location.search).toBe('?view=unread&category=goal');

    await user.click(main().getByRole('radio', { name: 'Archived' }));
    await waitFor(() => {
      expect(queries.at(-1)?.get('archived')).toBe('true');
    });
    expect(queries.at(-1)?.has('unread')).toBe(false);
  });

  it('archives a notification and brings it back from the archive', async () => {
    serveUnreadCount(1);
    const list = serveList([makeNotification()]);
    const bodies = servePatch(list);
    const user = userEvent.setup();
    renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');

    await user.click(
      await main().findByRole('button', { name: 'Archive: Emergency fund reached 50%' }),
    );
    expect(await screen.findByText('Notification archived')).toBeInTheDocument();
    expect(await main().findByText('You’re all caught up')).toBeInTheDocument();

    await user.click(main().getByRole('radio', { name: 'Archived' }));
    await user.click(
      await main().findByRole('button', { name: 'Move to inbox: Emergency fund reached 50%' }),
    );
    expect(await screen.findByText('Notification moved to your inbox')).toBeInTheDocument();
    expect(await main().findByText('Nothing archived')).toBeInTheDocument();
    expect(bodies.map((entry) => entry.body)).toEqual([{ archived: true }, { archived: false }]);
  });

  it('shows the empty state for a category', async () => {
    serveUnreadCount(0);
    serveList([]);
    renderRoute('/notifications?category=budget', { user: signedIn() });
    await findPageHeading('Notifications');
    expect(await main().findByText('You’re all caught up')).toBeInTheDocument();
    expect(main().getByText('There’s nothing here about Budgets.')).toBeInTheDocument();
    expect(main().getByRole('button', { name: 'Mark all as read' })).toBeDisabled();
  });

  it('shows an error with retry, and permission denied on 403', async () => {
    serveUnreadCount(0);
    let fail = true;
    server.use(
      http.get(`${API}/notifications`, () =>
        fail
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(notificationPage([makeNotification()])),
      ),
    );
    const user = userEvent.setup();
    const { unmount } = renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');
    expect(await main().findByText('We couldn’t load your notifications')).toBeInTheDocument();
    fail = false;
    await user.click(main().getByRole('button', { name: 'Try again' }));
    expect(
      await main().findByRole('link', { name: 'Emergency fund reached 50%' }),
    ).toBeInTheDocument();
    unmount();

    server.use(
      http.get(`${API}/notifications`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');
    expect(await main().findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('keeps a failed change visible and explained', async () => {
    serveUnreadCount(1);
    serveList([makeNotification()]);
    server.use(
      http.patch(`${API}/notifications/:id`, () =>
        HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/notifications', { user: signedIn() });
    await findPageHeading('Notifications');
    await user.click(
      await main().findByRole('button', { name: 'Mark as read: Emergency fund reached 50%' }),
    );
    expect(await screen.findByText('We couldn’t update that notification')).toBeInTheDocument();
    expect(main().getByText('New')).toBeInTheDocument();
  });
});
