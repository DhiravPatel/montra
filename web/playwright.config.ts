import { defineConfig, devices } from '@playwright/test';

// E2E journeys run against a real local stack: the Go API (+ worker) and a
// Vite dev server started on a dedicated port so they never attach to some
// other dev server. Set PW_CHANNEL=chrome to use the installed Google Chrome
// instead of downloading Playwright's bundled browsers.
const port = Number(process.env.E2E_PORT ?? 5199);
const baseURL = process.env.E2E_BASE_URL ?? `http://localhost:${port}`;
const channel = process.env.PW_CHANNEL;

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    trace: 'retain-on-failure',
  },
  projects: [
    {
      name: 'desktop-chromium',
      use: { ...devices['Desktop Chrome'], ...(channel ? { channel } : {}) },
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
