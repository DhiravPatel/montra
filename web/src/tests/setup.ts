import '@testing-library/jest-dom/vitest';
import { cleanup, configure } from '@testing-library/react';
import { afterAll, afterEach, beforeAll, vi } from 'vitest';
import { forgetCsrfToken } from '@/shared/api/csrf';
import { loadAllCatalogs } from '@/shared/i18n/catalogs';
import { resetSessionRecoveryForTests } from '@/shared/api/session-recovery';
import { resetTestBackend } from './msw/backend';
import { server } from './msw/server';

// Lazy routes load on first use; leave headroom when many test files run in parallel.
configure({ asyncUtilTimeout: 3000 });

// jsdom gaps used by Radix, React Router and the theme provider.
window.matchMedia = (query: string) =>
  ({
    matches: false,
    media: query,
    onchange: null,
    addEventListener: () => undefined,
    removeEventListener: () => undefined,
    dispatchEvent: () => false,
  }) as unknown as MediaQueryList;
window.scrollTo = () => undefined;
Element.prototype.scrollIntoView = () => undefined;
Element.prototype.hasPointerCapture = () => false;
Element.prototype.releasePointerCapture = () => undefined;
if (!('ResizeObserver' in window)) {
  class ResizeObserverStub {
    observe() {
      // no layout in jsdom
    }
    unobserve() {
      // no layout in jsdom
    }
    disconnect() {
      // no layout in jsdom
    }
  }
  Object.assign(window, { ResizeObserver: ResizeObserverStub });
}

function clearCookies() {
  for (const cookie of document.cookie.split(';')) {
    const name = cookie.split('=')[0]?.trim();
    if (name) document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
  }
}

// The app loads message catalogs with its routes; tests render any screen
// directly, so every namespace in both languages is loaded up front.
await loadAllCatalogs();

beforeAll(() => {
  // Any request without a handler fails the test (MSW 3 option name).
  server.listen({ onUnhandledFrame: 'error' });
});

afterEach(() => {
  cleanup();
  server.resetHandlers();
  resetTestBackend();
  resetSessionRecoveryForTests();
  forgetCsrfToken();
  clearCookies();
  window.history.replaceState(null, '', '/');
  document.documentElement.removeAttribute('data-theme');
  vi.useRealTimers();
});

afterAll(() => {
  server.close();
});
