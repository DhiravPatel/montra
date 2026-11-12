import { expect, test } from './support/test';

test.describe('public pages', () => {
  test('landing page is honest about what exists and is keyboard friendly', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(
      'Understand your money, manage it together, and make better decisions.',
    );
    await expect(page.getByText('Montra is in early development.')).toBeVisible();

    await page.keyboard.press('Tab');
    const skip = page.getByRole('link', { name: 'Skip to main content' });
    await expect(skip).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page.locator('#main')).toBeFocused();
  });

  test('unknown routes show a not-found page', async ({ page }) => {
    await page.goto('/does-not-exist');
    await expect(page.getByRole('heading', { level: 1, name: 'Page not found' })).toBeVisible();
  });

  test('theme and language preferences apply and persist', async ({ page }) => {
    await page.goto('/sign-in');
    await page.getByRole('button', { name: 'Display and language' }).click();
    await page.getByRole('menuitemradio', { name: 'Dark' }).click();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');

    await page.getByRole('button', { name: 'Display and language' }).click();
    await page.getByRole('menuitemradio', { name: 'हिन्दी' }).click();
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('साइन इन करें');
    await expect(page.locator('html')).toHaveAttribute('lang', 'hi');

    await page.reload();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    await expect(page.getByRole('heading', { level: 1 })).toHaveText('साइन इन करें');
  });

  test('protected pages send anonymous visitors to sign in', async ({ page }) => {
    await page.goto('/settings/security');
    await expect(page).toHaveURL(/\/sign-in$/);
  });

  test('the sign-up currency picker uses GET /currencies and hides retired currencies', async ({
    page,
  }) => {
    await page.goto('/sign-up');
    const currency = page.getByLabel('Main currency');
    await expect(currency).toBeEnabled();
    const offered = await currency
      .locator('option')
      .evaluateAll((options) => options.map((option) => (option as HTMLOptionElement).value));
    expect(offered).toContain('INR');
    expect(offered).toContain('EUR');
    expect(offered).not.toContain('BGN'); // retired 2026-01-01, replaced by EUR
  });
});
