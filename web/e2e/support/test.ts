import { type BrowserContext, test as base } from '@playwright/test';

export { expect } from '@playwright/test';

/**
 * The API allows a burst of ~60 reads per user (then ~10 a second). A
 * journey driven at machine speed can exceed that where a person never
 * would, and the app then shows "Too many requests… try again in 1 second"
 * with a "Try again" button. Retrying reads after the Retry-After delay keeps
 * the journeys about their subject; writes are never retried here (the
 * auth helpers in session.ts handle sign-in/sign-up limits explicitly).
 */
export async function retryRateLimitedReads(context: BrowserContext): Promise<void> {
  await context.route('**/api/v1/**', async (route) => {
    if (route.request().method() !== 'GET') {
      await route.fallback();
      return;
    }
    try {
      for (let attempt = 0; ; attempt += 1) {
        const response = await route.fetch();
        if (response.status() !== 429 || attempt >= 5) {
          await route.fulfill({ response });
          return;
        }
        const retryAfter = Number(response.headers()['retry-after'] ?? '1');
        const seconds = Number.isFinite(retryAfter) ? retryAfter : 1;
        await new Promise((resolve) => setTimeout(resolve, seconds * 1000 + 100));
      }
    } catch (error) {
      // A background read still in flight when the test ends (or its page
      // closes) is not a failure of the test.
      if (isClosed(error)) return;
      throw error;
    }
  });
}

function isClosed(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return /Test ended|has been closed|Target closed|context closed/i.test(message);
}

/** Playwright's `test`, with rate-limited reads retried in every test's context. */
export const test = base.extend({
  context: async ({ context }, provide) => {
    await retryRateLimitedReads(context);
    await provide(context);
    // Requests still in flight at the end must not fail the finished test.
    await context.unrouteAll({ behavior: 'ignoreErrors' });
  },
});
