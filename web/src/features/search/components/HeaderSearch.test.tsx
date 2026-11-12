import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { API, envelope, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { makeRecent, makeResults, shellHandlers } from '@/tests/searchFixtures';

const user0 = () => makeUser({ onboarding_completed: true });

/** jsdom has no layout: pretend the given elements are on screen (the shell hides one entry by CSS). */
function renderedWhen(predicate: (element: Element) => boolean) {
  vi.spyOn(Element.prototype, 'getClientRects').mockImplementation(function (this: Element) {
    return { length: predicate(this) ? 1 : 0 } as unknown as DOMRectList;
  });
}

function sidebarField() {
  return screen.getByRole('searchbox', { name: 'Search Montra' });
}

describe('HeaderSearch', () => {
  beforeEach(() => {
    server.use(
      ...shellHandlers(),
      http.get(`${API}/insights`, () => HttpResponse.json(envelope([]))),
    );
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('submits from the sidebar to /search without putting the query in the URL', async () => {
    const searches: URLSearchParams[] = [];
    server.use(
      http.get(`${API}/search`, ({ request }) => {
        const params = new URL(request.url).searchParams;
        searches.push(params);
        return HttpResponse.json(envelope(makeResults(params.get('q') ?? '')));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');

    await user.type(sidebarField(), '  Blue   Tokai {Enter}');

    await findPageHeading('Search');
    expect(await screen.findByRole('heading', { level: 2, name: /Transactions/ })).toBeVisible();
    // The query travels in history state only: never in the URL or the tab title.
    expect(router.state.location.pathname).toBe('/search');
    expect(router.state.location.search).toBe('');
    expect(router.state.location.state).toMatchObject({ q: 'Blue Tokai' });
    expect(document.title).toBe('Search · Montra');
    // A submitted search is remembered in recent searches.
    expect(searches).toHaveLength(1);
    expect(Object.fromEntries(searches[0]!)).toEqual({
      q: 'Blue Tokai',
      scope: 'all',
      limit: '5',
      sort: 'relevance',
      save: 'true',
    });
    expect(screen.getByRole('searchbox', { name: 'Search for' })).toHaveValue('Blue Tokai');
    // The sidebar field gives way to the page's own field.
    expect(screen.queryByRole('searchbox', { name: 'Search Montra' })).not.toBeInTheDocument();
  });

  it('moves focus to the sidebar field with "/" but never while typing in a field', async () => {
    renderedWhen((element) => element instanceof HTMLInputElement);
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    const field = sidebarField();
    expect(field).toHaveAttribute('aria-keyshortcuts', '/');

    await user.keyboard('/');
    expect(field).toHaveFocus();
    expect(field).toHaveValue('');

    // Inside a field "/" is just text.
    await user.type(field, 'a/b');
    expect(field).toHaveValue('a/b');

    // Modified key presses are left to the browser.
    field.blur();
    await user.keyboard('{Control>}/{/Control}');
    expect(field).not.toHaveFocus();
  });

  it('opens the search page with "/" on small screens, where only the search icon shows', async () => {
    renderedWhen((element) => element instanceof HTMLAnchorElement);
    server.use(http.get(`${API}/search/recent`, () => HttpResponse.json(envelope([makeRecent()]))));
    const user = userEvent.setup();
    const { router } = renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    expect(screen.getByRole('link', { name: 'Open search' })).toHaveAttribute('href', '/search');

    await user.keyboard('/');

    await findPageHeading('Search');
    const field = screen.getByRole('searchbox', { name: 'Search for' });
    await waitFor(() => {
      expect(field).toHaveFocus();
    });
    expect(router.state.location.search).toBe('');
    expect(await screen.findByRole('button', { name: /blue tokai/ })).toBeVisible();
  });

  it('opens the search page from the search icon', async () => {
    server.use(http.get(`${API}/search/recent`, () => HttpResponse.json(envelope([]))));
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');

    await user.click(screen.getByRole('link', { name: 'Open search' }));

    await findPageHeading('Search');
    await waitFor(() => {
      expect(screen.getByRole('searchbox', { name: 'Search for' })).toHaveFocus();
    });
    expect(screen.getByRole('link', { name: 'Open search' })).toHaveAttribute(
      'aria-current',
      'page',
    );
  });
});
