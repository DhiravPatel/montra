import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CATEGORY_TRAVEL,
  makeAccount,
  makePreferences,
  makeSummary,
  starterCategories,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

interface OnboardingBody {
  completed_steps: string[];
  skipped_steps: string[];
  complete: boolean;
}

function onboardingHandler(bodies: OnboardingBody[]) {
  return http.post(`${API}/me/onboarding`, async ({ request }) => {
    const body = (await request.json()) as OnboardingBody;
    bodies.push(body);
    if (body.complete && testBackend.user) {
      testBackend.user = { ...testBackend.user, onboarding_completed: true };
    }
    return HttpResponse.json(
      envelope({
        completed_steps: body.completed_steps,
        skipped_steps: body.skipped_steps,
        ...(body.complete ? { completed_at: '2026-11-04T10:00:00Z' } : {}),
      }),
    );
  });
}

async function stepHeading(name: string) {
  return screen.findByRole('heading', { level: 2, name });
}

describe('OnboardingPage', () => {
  it('walks through every optional step, saving each choice, and completes onboarding', async () => {
    testBackend.categories = starterCategories();
    const progress: OnboardingBody[] = [];
    const patches: unknown[] = [];
    const archived: string[] = [];
    let accountBody: unknown = null;
    server.use(
      onboardingHandler(progress),
      http.patch(`${API}/me/preferences`, async ({ request }) => {
        const patch = (await request.json()) as Record<string, unknown>;
        patches.push(patch);
        testBackend.preferences = { ...testBackend.preferences, ...patch };
        return HttpResponse.json(envelope(testBackend.preferences));
      }),
      http.post(`${API}/accounts`, async ({ request }) => {
        accountBody = await request.json();
        const account = makeAccount({
          name: 'Wallet',
          balance: { amount: '500.00', amount_minor: 50000, currency: 'EUR' },
          currency: 'EUR',
        });
        testBackend.accounts = [account];
        return HttpResponse.json(envelope(account), { status: 201 });
      }),
      http.post(`${API}/categories/:id/archive`, ({ params }) => {
        archived.push(String(params.id));
        return HttpResponse.json(envelope({ ...starterCategories()[1], status: 'archived' }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/onboarding', { user: makeUser() });
    await findPageHeading('Set up Montra');
    expect(await stepHeading('Welcome to Montra')).toBeInTheDocument();
    expect(screen.getByText('Step 1 of 7')).toBeInTheDocument();
    await user.click(await screen.findByRole('button', { name: 'Get started' }));

    // Privacy: explained, with one optional choice.
    const privacy = await stepHeading('Your privacy');
    await waitFor(() => {
      expect(privacy).toHaveFocus();
    });
    expect(screen.getByText(/never asks for bank passwords/)).toBeInTheDocument();
    await user.click(screen.getByLabelText(/Share anonymous usage statistics/));
    await user.click(screen.getByRole('button', { name: 'Continue' }));

    // Region: currency, time zone, week start.
    await stepHeading('Where you are');
    await user.selectOptions(await screen.findByLabelText('Main currency'), 'EUR');
    await user.selectOptions(screen.getByLabelText('Week starts on'), '0');
    await user.click(screen.getByRole('button', { name: 'Continue' }));

    // Income: skipped.
    await stepHeading('Your income (optional)');
    await user.click(screen.getByRole('button', { name: 'Skip this step' }));

    // First account.
    await stepHeading('Your first account');
    expect(screen.getByRole('button', { name: 'Continue' })).toBeDisabled();
    await user.type(await screen.findByLabelText('Account name'), 'Wallet');
    await user.selectOptions(screen.getByLabelText('Account type'), 'cash');
    await user.type(screen.getByLabelText(/^Current balance/), '500');
    await user.click(screen.getByRole('button', { name: 'Add account' }));
    expect(await screen.findByText('Added so far')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Continue' }));

    // Starter categories: untick one.
    await stepHeading('Categories');
    await user.click(await screen.findByLabelText('Travel'));
    await user.click(screen.getByRole('button', { name: 'Continue' }));

    // Email summaries.
    await stepHeading('Email summaries');
    await user.click(screen.getByLabelText(/^Weekly/));
    await user.click(screen.getByRole('button', { name: 'Finish' }));

    expect(await stepHeading('You’re all set')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Go to Home' })).toHaveAttribute('href', '/dashboard');

    expect(patches).toEqual([
      { analytics_opt_in: true },
      { country: 'IN', base_currency: 'EUR', week_start: 0 },
      { default_account_id: makeAccount().id },
      { email_digest: 'weekly' },
    ]);
    expect(accountBody).toMatchObject({
      name: 'Wallet',
      account_type: 'cash',
      currency: 'EUR',
      opening_balance: '500.00',
    });
    expect(archived).toEqual([CATEGORY_TRAVEL]);
    expect(progress.at(-1)).toEqual({
      completed_steps: [
        'welcome',
        'privacy',
        'country',
        'currency',
        'timezone',
        'accounts',
        'categories',
        'notifications',
      ],
      skipped_steps: ['income'],
      complete: true,
    });
    expect(progress.slice(0, -1).every((body) => !body.complete)).toBe(true);
  });

  it('skips the whole setup in one step and goes Home', async () => {
    const progress: OnboardingBody[] = [];
    server.use(
      onboardingHandler(progress),
      http.get(`${API}/dashboard/summary`, () => HttpResponse.json(envelope(makeSummary()))),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/onboarding', { user: makeUser() });
    await stepHeading('Welcome to Montra');
    await user.click(await screen.findByRole('button', { name: 'Skip setup' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe('/dashboard');
    });
    expect(progress).toEqual([
      {
        completed_steps: [],
        skipped_steps: [
          'welcome',
          'privacy',
          'country',
          'currency',
          'timezone',
          'income',
          'accounts',
          'categories',
          'notifications',
        ],
        complete: true,
      },
    ]);
    expect(
      await screen.findByText('Setup skipped. You can change your preferences at any time.'),
    ).toBeInTheDocument();
  });

  it('shows the API’s field error when a preference is rejected', async () => {
    testBackend.preferences = makePreferences();
    server.use(
      onboardingHandler([]),
      http.patch(`${API}/me/preferences`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.timezone', message: 'Unknown time zone.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/onboarding', { user: makeUser() });
    await stepHeading('Welcome to Montra');
    await user.click(await screen.findByRole('button', { name: 'Get started' }));
    await stepHeading('Your privacy');
    await user.click(screen.getByRole('button', { name: 'Skip this step' }));
    await stepHeading('Where you are');
    await user.selectOptions(await screen.findByLabelText('Time zone'), 'Europe/Paris');
    await user.click(screen.getByRole('button', { name: 'Continue' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Time zone')).toHaveAccessibleDescription(/Unknown time zone\./);
    });
    expect(screen.getByRole('heading', { level: 2, name: 'Where you are' })).toBeInTheDocument();
  });

  it('keeps the person on the last step when completing fails', async () => {
    server.use(
      http.post(`${API}/me/onboarding`, async ({ request }) => {
        const body = (await request.json()) as OnboardingBody;
        if (body.complete)
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        return HttpResponse.json(
          envelope({ completed_steps: body.completed_steps, skipped_steps: body.skipped_steps }),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/onboarding', { user: makeUser() });
    await stepHeading('Welcome to Montra');
    await user.click(await screen.findByRole('button', { name: 'Get started' }));
    for (const heading of [
      'Your privacy',
      'Where you are',
      'Your income (optional)',
      'Your first account',
      'Categories',
    ]) {
      await stepHeading(heading);
      await user.click(screen.getByRole('button', { name: 'Skip this step' }));
    }
    await stepHeading('Email summaries');
    await user.click(screen.getByRole('button', { name: 'Skip this step' }));
    expect(
      await screen.findByText('Something went wrong on our side. Try again in a moment.'),
    ).toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 2, name: 'Email summaries' })).toBeInTheDocument();
  });

  it('shows an error when preferences cannot be loaded', async () => {
    server.use(
      http.get(`${API}/me/preferences`, () =>
        HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 }),
      ),
    );
    renderRoute('/onboarding', { user: makeUser() });
    await findPageHeading('Set up Montra');
    expect(await screen.findByText('We couldn’t load your preferences')).toBeInTheDocument();
  });

  it('resumes at the first step that was neither completed nor skipped', async () => {
    testBackend.onboarding = {
      completed_steps: ['welcome', 'privacy'],
      skipped_steps: ['country', 'currency', 'timezone'],
    };
    const bodies: OnboardingBody[] = [];
    server.use(onboardingHandler(bodies));
    const user = userEvent.setup();
    renderRoute('/onboarding', { user: makeUser() });
    await findPageHeading('Set up Montra');
    expect(await stepHeading('Your income (optional)')).toBeInTheDocument();
    expect(screen.getByText('Step 4 of 7')).toBeInTheDocument();

    // Earlier answers are kept when the next step is recorded (the API merges them).
    await user.click(await screen.findByRole('button', { name: 'Skip this step' }));
    await waitFor(() => {
      expect(bodies).toHaveLength(1);
    });
    expect(bodies[0]).toEqual({
      completed_steps: ['welcome', 'privacy'],
      skipped_steps: ['country', 'currency', 'timezone', 'income'],
      complete: false,
    });
  });

  it('starts at the welcome when saved progress cannot be loaded', async () => {
    server.use(
      http.get(`${API}/me/onboarding`, () =>
        HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 }),
      ),
    );
    renderRoute('/onboarding', { user: makeUser() });
    await findPageHeading('Set up Montra');
    expect(await screen.findByText('Step 1 of 7')).toBeInTheDocument();
  });
});
