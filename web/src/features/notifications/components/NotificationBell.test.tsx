import { act, render, screen, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { MemoryRouter } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AppProviders } from '@/app/providers/AppProviders';
import { API, errorBody, makeUser } from '@/tests/fixtures';
import { serveUnreadCount } from '@/tests/notificationsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { createTestQueryClient } from '@/tests/render';
import { NotificationBell } from './NotificationBell';

function renderBell(compact = false) {
  testBackend.user = makeUser({ onboarding_completed: true });
  return render(
    <AppProviders queryClient={createTestQueryClient()} language="en">
      <MemoryRouter initialEntries={['/dashboard']}>
        <NotificationBell compact={compact} />
      </MemoryRouter>
    </AppProviders>,
  );
}

function setVisibility(state: 'visible' | 'hidden') {
  Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => state });
  // Bubbles to window, where TanStack Query listens too.
  document.dispatchEvent(new Event('visibilitychange', { bubbles: true }));
}

afterEach(() => {
  Reflect.deleteProperty(document, 'visibilityState');
});

describe('NotificationBell', () => {
  it('links to the notification center with the unread count in its accessible name', async () => {
    serveUnreadCount(3);
    renderBell();
    const bell = await screen.findByRole('link', { name: 'Notifications, 3 unread' });
    expect(bell).toHaveAttribute('href', '/notifications');
    // The visible badge repeats the number but is hidden from assistive tech.
    const badge = within(bell).getByText('3');
    expect(badge).toHaveAttribute('aria-hidden', 'true');
    // Absolutely positioned over the icon: showing it never shifts the layout.
    expect(badge.className).toContain('absolute');
  });

  it('says when nothing is unread and caps the badge at 99+', async () => {
    serveUnreadCount(0);
    const { unmount } = renderBell(true);
    const bell = await screen.findByRole('link', { name: 'Notifications, none unread' });
    expect(within(bell).queryByText('0')).not.toBeInTheDocument();
    unmount();

    serveUnreadCount(250);
    renderBell();
    const busy = await screen.findByRole('link', { name: 'Notifications, 250 unread' });
    expect(within(busy).getByText('99+')).toBeInTheDocument();
  });

  it('keeps a plain name when the count cannot be loaded', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/notifications/unread-count`, () => {
        calls += 1;
        return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
      }),
    );
    renderBell();
    await vi.waitFor(() => {
      expect(calls).toBeGreaterThan(0);
    });
    expect(await screen.findByRole('link', { name: 'Notifications' })).toHaveAttribute(
      'href',
      '/notifications',
    );
  });

  it('polls about once a minute while visible, pauses while hidden and catches up when shown', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const served = serveUnreadCount(1, 2, 5);
    renderBell();
    expect(
      await screen.findByRole('link', { name: 'Notifications, 1 unread' }),
    ).toBeInTheDocument();

    await act(() => vi.advanceTimersByTimeAsync(60_000));
    expect(
      await screen.findByRole('link', { name: 'Notifications, 2 unread' }),
    ).toBeInTheDocument();
    expect(served.calls).toBe(2);

    setVisibility('hidden');
    await act(() => vi.advanceTimersByTimeAsync(5 * 60_000));
    expect(served.calls).toBe(2);
    expect(screen.getByRole('link', { name: 'Notifications, 2 unread' })).toBeInTheDocument();

    setVisibility('visible');
    expect(
      await screen.findByRole('link', { name: 'Notifications, 5 unread' }),
    ).toBeInTheDocument();
    expect(served.calls).toBe(3);
  });
});
