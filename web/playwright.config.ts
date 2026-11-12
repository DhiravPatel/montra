import { defineConfig, devices } from '@playwright/test';

// E2E journeys run against a real local stack: the Go API (+ worker) and a
// Vite dev server started on a dedicated port so they never attach to some
// other dev server. Set PW_CHANNEL=chrome to use the installed Google Chrome
// instead of downloading Playwright's bundled browsers.
const port = Number(process.env.E2E_PORT ?? 5199);
const baseURL = process.env.E2E_BASE_URL ?? `http://localhost:${port}`;
const channel = process.env.PW_CHANNEL;
const browser = channel ? { channel } : {};

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  // Journeys sign in many throwaway users; the API allows ~10 sign-ins a
  // minute per IP, so helpers wait out 429s and need the headroom.
  timeout: 120_000,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    trace: 'retain-on-failure',
  },
  projects: [
    {
      name: 'desktop-chromium',
      use: { ...devices['Desktop Chrome'], ...browser },
    },
    {
      // Phone: bottom tab bar + "More" menu instead of the sidebar (< md).
      name: 'phone-chromium',
      use: { ...devices['Pixel 7'], ...browser },
    },
    {
      // Tablet portrait: exactly the md breakpoint (768px), touch input.
      name: 'tablet-chromium',
      use: {
        ...devices['Desktop Chrome'],
        ...browser,
        viewport: { width: 768, height: 1024 },
        hasTouch: true,
      },
    },
  ],
  webServer: process.env.E2E_BASE_URL
    ? undefined
    : {
        command: `pnpm exec vite --port ${port} --strictPort`,
        url: baseURL,
        // Never reuse: an unrelated server on the port must fail loudly.
        reuseExistingServer: false,
        timeout: 60_000,
      },
});
