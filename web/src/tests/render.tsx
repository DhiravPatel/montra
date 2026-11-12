import { QueryClient } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { RouterProvider, createMemoryRouter } from 'react-router';
import { AppProviders } from '@/app/providers/AppProviders';
import { routes } from '@/app/router/routes';
import type { User } from '@/shared/api/types';
import { CSRF_COOKIE } from '@/shared/api/csrf';
import { testBackend } from './msw/backend';

interface RenderRouteOptions {
  /** Simulates a signed-in browser (session handler returns this user, CSRF cookie set). */
  user?: User;
}

export function createTestQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false, staleTime: Number.POSITIVE_INFINITY, refetchOnWindowFocus: false },
      mutations: { retry: false },
    },
  });
}

/** Renders the real route tree at `path` with all app providers (English). */
export function renderRoute(path: string, { user }: RenderRouteOptions = {}) {
  if (user) {
    testBackend.user = user;
    document.cookie = `${CSRF_COOKIE}=csrf-cookie-token; path=/`;
  }
  const router = createMemoryRouter(routes, { initialEntries: [path] });
  const queryClient = createTestQueryClient();
  const result = render(
    <AppProviders queryClient={queryClient} language="en">
      <RouterProvider router={router} />
    </AppProviders>,
  );
  return { ...result, router, queryClient };
}

/** Waits for the page's h1 (lazy routes resolve asynchronously). */
export function findPageHeading(name: string | RegExp) {
  return screen.findByRole('heading', { level: 1, name });
}
