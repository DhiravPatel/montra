import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { SubscriptionInput, SubscriptionPatch } from '@/shared/finance/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACCOUNT_CASH,
  CATEGORY_GROCERIES,
  makeAccount,
  money,
  starterCategories,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { SUB_NETFLIX, makeSubscription } from '@/tests/subscriptionsFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function withReferenceData() {
  testBackend.accounts = [makeAccount()];
  testBackend.categories = starterCategories();
}

describe('SubscriptionCreatePage', () => {
  it('validates, then sends the subscription with an Idempotency-Key and reuses it on retry', async () => {
    withReferenceData();
    const bodies: SubscriptionInput[] = [];
    const keys: (string | null)[] = [];
    server.use(
      http.post(`${API}/subscriptions`, async ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        bodies.push((await request.json()) as SubscriptionInput);
        if (bodies.length === 1) {
          // The response is lost: the retry must not add it twice.
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(envelope(makeSubscription({ version: 1 })), { status: 201 });
      }),
      http.get(`${API}/subscriptions/:id`, () => HttpResponse.json(envelope(makeSubscription()))),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/subscriptions/new', { user: signedIn() });
    await findPageHeading('Add a subscription');
    const name = await screen.findByLabelText('Name');

    // Required fields and a non-https cancellation page are caught before sending.
    await user.click(screen.getByRole('button', { name: 'How to cancel (optional)' }));
    await user.type(screen.getByLabelText(/^Cancellation page/), 'http://netflix.com/cancel');
    await user.click(screen.getByRole('button', { name: 'Add subscription' }));
    expect(await screen.findByText('Enter a name.')).toBeInTheDocument();
    expect(screen.getByText('Enter an amount.')).toBeInTheDocument();
    expect(screen.getByText('Enter a web address that starts with https://')).toBeInTheDocument();
    expect(bodies).toHaveLength(0);

    await user.type(name, 'Netflix');
    await user.type(screen.getByLabelText('Plan (optional)'), 'Standard');
    await user.type(screen.getByLabelText(/^Merchant or payee/), 'Netflix');
    await user.type(screen.getByLabelText(/^Price per billing cycle/), '649');
    await user.clear(screen.getByLabelText('Started on'));
    await user.type(screen.getByLabelText('Started on'), '2026-10-10');
    await user.click(screen.getByLabelText('1 day before'));
    await user.selectOptions(screen.getByLabelText(/^Paid from/), ACCOUNT_CASH);
    await user.selectOptions(screen.getByLabelText(/^Category/), CATEGORY_GROCERIES);
    const url = screen.getByLabelText(/^Cancellation page/);
    await user.clear(url);
    await user.type(url, 'https://www.netflix.com/cancelplan');
    await user.click(screen.getByRole('button', { name: 'Add a step' }));
    await user.type(screen.getByLabelText('Step 1'), 'Download invoices');
    await user.click(screen.getByRole('button', { name: 'Add subscription' }));
    expect(await screen.findByText(/Something went wrong|server/i)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Add subscription' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/subscriptions/${SUB_NETFLIX}`);
    });
    expect(keys[0]).toMatch(/^web-/);
    expect(keys[1]).toBe(keys[0]);
    expect(bodies).toHaveLength(2);
    expect(bodies[1]).toEqual(bodies[0]);
    expect(bodies[0]).toEqual({
      name: 'Netflix',
      plan_name: 'Standard',
      merchant_name: 'Netflix',
      amount: '649.00',
      currency: 'INR',
      billing_frequency: 'monthly',
      start_date: '2026-10-10',
      reminder_days_before: [3, 1],
      payment_account_id: ACCOUNT_CASH,
      category_id: CATEGORY_GROCERIES,
      cancellation_url: 'https://www.netflix.com/cancelplan',
      cancellation_checklist: [{ item: 'Download invoices', done: false }],
    });
    expect(await screen.findByText('Subscription added')).toBeInTheDocument();
  });

  it('explains the fair-use limit when adding one more', async () => {
    withReferenceData();
    server.use(
      http.post(`${API}/subscriptions`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                code: 'record_limit_reached',
                message: 'You can keep up to 500 of these.',
                params: { resource: 'subscriptions', limit: '500' },
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/subscriptions/new', { user: signedIn() });
    await findPageHeading('Add a subscription');
    await user.type(await screen.findByLabelText('Name'), 'Gym');
    await user.type(screen.getByLabelText(/^Price per billing cycle/), '1500');
    await user.click(screen.getByRole('button', { name: 'Add subscription' }));
    expect(
      await screen.findByText(
        'You can keep up to 500 open subscriptions. Mark ones you no longer pay for as cancelled, then try again.',
      ),
    ).toBeInTheDocument();
  });

  it('asks for the custom interval and shows server field errors next to the field', async () => {
    withReferenceData();
    const bodies: SubscriptionInput[] = [];
    server.use(
      http.post(`${API}/subscriptions`, async ({ request }) => {
        bodies.push((await request.json()) as SubscriptionInput);
        return HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.trial_ends_on',
                message: 'The trial cannot end before the start date.',
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/subscriptions/new', { user: signedIn() });
    await findPageHeading('Add a subscription');
    await user.type(await screen.findByLabelText('Name'), 'Gym');
    await user.type(screen.getByLabelText(/^Price per billing cycle/), '1,500.50');
    await user.selectOptions(screen.getByLabelText('Billing cycle'), 'custom');
    await user.clear(screen.getByLabelText('Every'));
    await user.type(screen.getByLabelText('Every'), '0');
    await user.click(screen.getByRole('button', { name: 'Add subscription' }));
    expect(await screen.findByText('Enter a whole number from 1 to 366.')).toBeInTheDocument();

    await user.clear(screen.getByLabelText('Every'));
    await user.type(screen.getByLabelText('Every'), '3');
    await user.selectOptions(screen.getByLabelText('Unit'), 'month');
    await user.click(screen.getByRole('button', { name: 'Add subscription' }));
    expect(
      await screen.findByText('The trial cannot end before the start date.'),
    ).toBeInTheDocument();
    expect(bodies[0]).toMatchObject({
      amount: '1500.50',
      billing_frequency: 'custom',
      interval_count: 3,
      interval_unit: 'month',
    });
  });
});

describe('SubscriptionEditPage', () => {
  it('sends only the changed fields with clear, and reloads after a conflict', async () => {
    withReferenceData();
    const saved = makeSubscription({
      invoice_file_id: '0f0f0f0f-0000-4000-8000-000000000001',
      category_id: CATEGORY_GROCERIES,
      notes: 'Family plan',
    });
    const bodies: SubscriptionPatch[] = [];
    let reads = 0;
    server.use(
      http.get(`${API}/subscriptions/:id`, () => {
        reads += 1;
        return HttpResponse.json(
          envelope(reads === 1 ? saved : { ...saved, name: 'Netflix HD', version: 3 }),
        );
      }),
      http.patch(`${API}/subscriptions/:id`, async ({ request }) => {
        const body = (await request.json()) as SubscriptionPatch;
        bodies.push(body);
        if (bodies.length === 1) {
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope({ ...saved, amount: money('799.00'), version: 4 }));
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute(`/subscriptions/${SUB_NETFLIX}/edit`, { user: signedIn() });
    await findPageHeading('Edit subscription');
    const price = await screen.findByLabelText(/^Price per billing cycle/);
    expect(price).toHaveValue('649.00');
    // No cancellation date for a subscription that is not cancelled.
    expect(screen.queryByLabelText('Cancelled on')).toBeNull();
    await user.clear(price);
    await user.type(price, '799');
    await user.selectOptions(screen.getByLabelText(/^Category/), '');
    await user.clear(screen.getByLabelText(/^Notes/));
    await user.click(screen.getByRole('button', { name: 'Save' }));

    expect(
      await screen.findByText(/Someone changed this subscription while you were editing/),
    ).toBeInTheDocument();
    // Only what changed: the emptied note as "", the removed category in clear. The
    // invoice and everything else the form did not change are left out (kept).
    expect(bodies[0]).toEqual({
      version: 2,
      amount: '799.00',
      notes: '',
      clear: ['category_id'],
    });

    // The form now shows the latest saved values (version 3).
    await waitFor(() => {
      expect(screen.getByLabelText('Name')).toHaveValue('Netflix HD');
    });
    const reloaded = screen.getByLabelText(/^Price per billing cycle/);
    await user.clear(reloaded);
    await user.type(reloaded, '799');
    await user.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/subscriptions/${SUB_NETFLIX}`);
    });
    expect(bodies[1]).toEqual({ version: 3, amount: '799.00' });
    expect(await screen.findByText('Subscription updated')).toBeInTheDocument();
  });

  it('corrects the cancellation date of a cancelled subscription', async () => {
    withReferenceData();
    const saved = makeSubscription({
      status: 'cancelled',
      cancelled_on: '2026-11-01',
      next_renewal_date: undefined,
    });
    const bodies: SubscriptionPatch[] = [];
    server.use(
      http.get(`${API}/subscriptions/:id`, () => HttpResponse.json(envelope(saved))),
      http.patch(`${API}/subscriptions/:id`, async ({ request }) => {
        bodies.push((await request.json()) as SubscriptionPatch);
        if (bodies.length === 1) {
          // Reactivated on another device meanwhile.
          return HttpResponse.json(
            errorBody({
              code: 'DOMAIN_RULE_VIOLATION',
              details: [
                {
                  code: 'subscription_not_cancelled',
                  message: 'Only a cancelled subscription has a cancellation date.',
                },
              ],
            }),
            { status: 422 },
          );
        }
        return HttpResponse.json(envelope({ ...saved, cancelled_on: '2026-10-30', version: 3 }));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/subscriptions/${SUB_NETFLIX}/edit`, { user: signedIn() });
    await findPageHeading('Edit subscription');
    const date = await screen.findByLabelText('Cancelled on');
    expect(date).toHaveValue('2026-11-01');
    await user.clear(date);
    await user.type(date, '2026-10-30');
    await user.click(screen.getByRole('button', { name: 'Save' }));
    expect(
      await screen.findByText('Only a cancelled subscription has a cancellation date.'),
    ).toBeInTheDocument();
    expect(bodies[0]).toEqual({ version: 2, cancelled_on: '2026-10-30' });

    await user.click(screen.getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Subscription updated')).toBeInTheDocument();
    expect(bodies).toHaveLength(2);
  });

  it('does not offer editing to people it is only shared with', async () => {
    server.use(
      http.get(`${API}/subscriptions/:id`, () =>
        HttpResponse.json(envelope(makeSubscription({ owned: false }))),
      ),
    );
    renderRoute(`/subscriptions/${SUB_NETFLIX}/edit`, { user: signedIn() });
    expect(await screen.findByText('Shared with you to view')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Save' })).toBeNull();
  });

  it('explains when the subscription no longer exists', async () => {
    server.use(
      http.get(`${API}/subscriptions/:id`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    renderRoute(`/subscriptions/${SUB_NETFLIX}/edit`, { user: signedIn() });
    expect(await screen.findByText('Subscription not found')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Back to subscriptions' })).toHaveAttribute(
      'href',
      '/subscriptions',
    );
  });
});
