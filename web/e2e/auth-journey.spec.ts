import { expect, type Page, test } from '@playwright/test';
import { waitForEmailLink } from './support/devMailbox';
import { totp, waitForNextTotpStep } from './support/totp';

/**
 * Full journey against the local Go API (and its worker, which delivers
 * dev-mailbox emails). Creates a throwaway account in the development
 * database. Run with: PW_CHANNEL=chrome pnpm e2e
 */
test.describe.configure({ mode: 'serial' });

const email = `e2e.${Date.now()}@example.com`;
const password = 'quiet-harbor-71-e2e';
let totpSecret = '';

async function signIn(page: Page) {
  await page.goto('/sign-in');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: 'Sign in' }).click();
}

test('sign up, verify the email link and sign in', async ({ page }) => {
  await page.goto('/sign-up');
  await page.getByLabel('Display name').fill('E2E Tester');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('New password').fill(password);
  await page.getByLabel('Main currency').selectOption('INR');
  await page.getByLabel(/I agree to the/).check();
  await page.getByLabel(/18 years of age or older/).check();
  await page.getByRole('button', { name: 'Create account' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Check your email' })).toBeVisible();

  // A local API may skip verification (AUTH_DEV_AUTO_VERIFY_EMAIL, development
  // only): then sign-in already works and no email is sent. Probe once.
  const probe = await page.request.post('/api/v1/auth/login', {
    data: { email, password },
    headers: { 'X-Montra-Client': 'android' },
  });
  if (probe.status() === 403) {
    const body = (await probe.json()) as { error?: { code?: string } };
    expect(body.error?.code).toBe('EMAIL_NOT_VERIFIED');
    // The API builds links from WEB_APP_URL; keep path + fragment, use this server's origin.
    const link = new URL(await waitForEmailLink(email, '/verify-email'));
    await page.goto(link.pathname + link.hash);
    await expect(page.getByText('Your email is verified')).toBeVisible();
    expect(new URL(page.url()).hash).toBe(''); // token removed from the address bar
  } else {
    expect(probe.status()).toBe(200);
  }

  await signIn(page);
  // A new account starts with the optional setup; skipping it lands on Home.
  await expect(page.getByRole('heading', { level: 1, name: 'Set up Montra' })).toBeVisible();
  await page.getByRole('button', { name: 'Skip setup' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Home' })).toBeVisible();
  await page.goto('/account');
  await expect(page.getByRole('heading', { level: 1, name: 'Your account' })).toBeVisible();
  await expect(page.getByText('Hello, E2E Tester. Here are your account details.')).toBeVisible();

  const cookies = await page.context().cookies();
  expect(cookies.find((cookie) => cookie.name === 'montra_at')?.httpOnly).toBe(true);
  expect(cookies.find((cookie) => cookie.name === 'montra_rt')?.httpOnly).toBe(true);
  expect(cookies.find((cookie) => cookie.name === 'montra_csrf')?.httpOnly).toBe(false);
  const storage = await page.evaluate(() =>
    JSON.stringify(
      Object.keys(window.localStorage).map((key) => [key, window.localStorage.getItem(key)]),
    ),
  );
  expect(storage).not.toMatch(/token|montra_at|montra_rt/i);
});

test('an expired access token is refreshed transparently', async ({ page }) => {
  await signIn(page);
  await expect(page.getByRole('heading', { level: 1, name: 'Home' })).toBeVisible();
  const before = (await page.context().cookies()).find(
    (cookie) => cookie.name === 'montra_rt',
  )?.value;

  // Simulate the 15-minute access token expiring.
  await page.context().clearCookies({ name: 'montra_at' });
  const refresh = page.waitForResponse((response) =>
    response.url().endsWith('/api/v1/auth/refresh'),
  );
  await page.goto('/settings/security');
  expect((await refresh).status()).toBe(200);

  await expect(page.getByRole('heading', { level: 1, name: 'Security' })).toBeVisible();
  const devices = page.getByRole('region', { name: 'Signed-in devices' });
  await expect(devices.getByText('This device')).toBeVisible();
  const after = (await page.context().cookies()).find(
    (cookie) => cookie.name === 'montra_rt',
  )?.value;
  expect(after).toBeTruthy();
  expect(after).not.toBe(before); // refresh token rotated
});

test('set up two-step verification, sign in with a code, then turn it off', async ({ page }) => {
  test.setTimeout(180_000);
  await signIn(page);
  await expect(page.getByRole('heading', { level: 1, name: 'Home' })).toBeVisible();
  await page.goto('/settings/security');

  await page.getByRole('button', { name: 'Set up two-step verification' }).click();
  // A fresh sign-in counts as re-authentication for the API, so the password
  // prompt may or may not appear.
  const qr = page.getByRole('img', { name: 'QR code for adding Montra to your authenticator app' });
  const reauth = page.getByRole('dialog', { name: 'Confirm it’s you' });
  await expect(qr.or(reauth)).toBeVisible();
  if (await reauth.isVisible()) {
    await reauth.getByLabel('Password').fill(password);
    await reauth.getByRole('button', { name: 'Confirm' }).click();
  }
  await expect(qr).toBeVisible();
  totpSecret = (await page.locator('code').first().innerText()).replace(/\s+/g, '');
  await page.getByLabel('Verification code').fill(totp(totpSecret));
  await page.getByRole('button', { name: 'Turn on' }).click();

  await expect(page.getByText('Save your recovery codes now')).toBeVisible();
  await expect(page.locator('ol li')).toHaveCount(10);
  await page.getByLabel('I’ve saved these codes somewhere safe').check();
  await page.getByRole('button', { name: 'Done' }).click();
  await expect(
    page.getByRole('region', { name: 'Two-step verification' }).getByText('On', { exact: true }),
  ).toBeVisible();

  // Sign out and back in: the code step appears.
  await page.getByRole('button', { name: 'Account menu' }).click();
  await page.getByRole('menuitem', { name: 'Sign out' }).click();
  await expect(page.getByText('You’ve signed out.')).toBeVisible();
  await waitForNextTotpStep();
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(
    page.getByRole('heading', { level: 1, name: 'Two-step verification' }),
  ).toBeVisible();
  await page.getByLabel('Verification code').fill(totp(totpSecret));
  await page.getByRole('button', { name: 'Verify' }).click();
  await expect(page.getByRole('heading', { level: 1, name: 'Home' })).toBeVisible();

  // Turn it off. Navigate in-app so this tab remembers the fresh sign-in;
  // the sign-in code cannot be reused, so wait for a new one.
  await page
    .getByRole('navigation', { name: 'Main' })
    .getByRole('link', { name: 'Security' })
    .click();
  await expect(page.getByRole('heading', { level: 1, name: 'Security' })).toBeVisible();
  await waitForNextTotpStep();
  await page.getByRole('button', { name: 'Turn off' }).click();
  const confirm = page.getByRole('dialog', { name: 'Confirm it’s you' });
  const disable = page.getByRole('dialog', { name: 'Turn off two-step verification?' });
  await expect(confirm.or(disable)).toBeVisible();
  if (await confirm.isVisible()) {
    await confirm.getByLabel('Password').fill(password);
    await confirm.getByLabel('Authenticator code').fill(totp(totpSecret));
    await confirm.getByRole('button', { name: 'Confirm' }).click();
    await expect(disable).toBeVisible();
    await waitForNextTotpStep();
  }
  await disable.getByLabel('Authenticator code').fill(totp(totpSecret));
  await disable.getByRole('button', { name: 'Turn off' }).click();
  await expect(page.getByText('Two-step verification is off')).toBeVisible();
});

test('sign out everywhere ends the session on the server', async ({ page }) => {
  await signIn(page);
  await expect(page.getByRole('heading', { level: 1, name: 'Home' })).toBeVisible();
  await page.goto('/settings/security');
  await page.getByRole('button', { name: 'Sign out everywhere' }).click();
  const dialog = page.getByRole('dialog', { name: 'Sign out on all devices?' });
  await dialog.getByRole('button', { name: 'Sign out everywhere' }).click();
  await expect(page.getByText('You’ve been signed out on all devices.')).toBeVisible();

  const session = await page.request.get('/api/v1/auth/session', {
    headers: { 'X-Montra-Client': 'web' },
  });
  expect(session.status()).toBe(401);
});
