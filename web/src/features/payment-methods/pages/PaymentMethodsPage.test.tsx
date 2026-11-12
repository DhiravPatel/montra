import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { ACCOUNT_CASH, makeAccount, makePaymentMethod, METHOD_UPI } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const user0 = () => makeUser({ onboarding_completed: true });

describe('PaymentMethodsPage', () => {
  it('lists methods with masked details, the linked account and badges', async () => {
    testBackend.accounts = [makeAccount()];
    testBackend.paymentMethods = [
      makePaymentMethod({ is_default: true, account_id: ACCOUNT_CASH, masked_hint: 'asha@upi' }),
    ];
    renderRoute('/accounts/payment-methods', { user: user0() });
    await findPageHeading('Payment methods');
    expect(await screen.findByText('GPay')).toBeInTheDocument();
    expect(screen.getByText('UPI · asha@upi')).toBeInTheDocument();
    expect(await screen.findByText('Linked to Wallet')).toBeInTheDocument();
    expect(screen.getByText('Default')).toBeInTheDocument();
    // Accounts stays the current section in the main navigation.
    const nav = screen.getAllByRole('navigation', { name: 'Main', hidden: true })[0]!;
    expect(within(nav).getByRole('link', { name: 'Accounts', hidden: true })).toHaveAttribute(
      'aria-current',
      'page',
    );
  });

  it('shows an empty state', async () => {
    renderRoute('/accounts/payment-methods', { user: user0() });
    await findPageHeading('Payment methods');
    expect(await screen.findByText('No payment methods yet')).toBeInTheDocument();
  });

  it('creates a method and refuses full card numbers before calling the API', async () => {
    testBackend.accounts = [makeAccount()];
    let body: unknown = null;
    server.use(
      http.post(`${API}/payment-methods`, async ({ request }) => {
        body = await request.json();
        testBackend.paymentMethods = [
          makePaymentMethod({ kind: 'debit_card', label: 'HDFC debit' }),
        ];
        return HttpResponse.json(envelope(testBackend.paymentMethods[0]), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/accounts/payment-methods', { user: user0() });
    await findPageHeading('Payment methods');
    await user.click(screen.getAllByRole('button', { name: 'Add payment method' })[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Add a payment method' });
    await user.selectOptions(within(dialog).getByLabelText('Type'), 'debit_card');
    await user.type(within(dialog).getByLabelText('Name'), 'HDFC debit');
    await user.type(within(dialog).getByLabelText(/^Hint/), '4111 1111 1111 1111');
    await user.click(within(dialog).getByRole('button', { name: 'Add payment method' }));
    await waitFor(() => {
      expect(within(dialog).getByLabelText(/^Hint/)).toHaveAccessibleDescription(
        /Use at most the last 4 digits/,
      );
    });
    expect(body).toBeNull();

    await user.clear(within(dialog).getByLabelText(/^Hint/));
    await user.type(within(dialog).getByLabelText(/^Hint/), '•••• 1111');
    await user.selectOptions(within(dialog).getByLabelText(/^Card network/), 'rupay');
    await user.selectOptions(within(dialog).getByLabelText(/^Linked account/), ACCOUNT_CASH);
    await user.click(within(dialog).getByRole('button', { name: 'Add payment method' }));
    expect(await screen.findByText('Payment method added')).toBeInTheDocument();
    expect(body).toEqual({
      kind: 'debit_card',
      label: 'HDFC debit',
      is_default: false,
      network: 'rupay',
      masked_hint: '•••• 1111',
      account_id: ACCOUNT_CASH,
    });
  });

  it('sends only the changed fields with the version, and reloads after a conflict', async () => {
    testBackend.paymentMethods = [
      makePaymentMethod({ network: 'upi', masked_hint: 'asha@upi', version: 2 }),
    ];
    const bodies: unknown[] = [];
    server.use(
      http.patch(`${API}/payment-methods/:id`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makePaymentMethod({ label: 'Google Pay', version: 4 })));
      }),
      http.get(`${API}/payment-methods/:id`, () =>
        HttpResponse.json(
          envelope(
            makePaymentMethod({
              network: 'upi',
              masked_hint: 'asha@upi',
              label: 'G Pay',
              version: 3,
            }),
          ),
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/accounts/payment-methods', { user: user0() });
    await findPageHeading('Payment methods');
    await user.click(await screen.findByRole('button', { name: 'Edit: GPay' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit payment method' });
    const label = within(dialog).getByLabelText('Name');
    await user.clear(label);
    await user.type(label, 'Google Pay');
    await user.clear(within(dialog).getByLabelText(/^Hint/));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(bodies[0]).toEqual({ version: 2, label: 'Google Pay', masked_hint: '' });

    expect(await within(dialog).findByText(/It was changed somewhere else/)).toBeInTheDocument();
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Name')).toHaveValue('G Pay');
    });
    const reloaded = within(dialog).getByLabelText('Name');
    await user.clear(reloaded);
    await user.type(reloaded, 'Google Pay');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Payment method updated')).toBeInTheDocument();
    expect(bodies[1]).toEqual({ version: 3, label: 'Google Pay' });
  });

  it('restores an archived method', async () => {
    testBackend.paymentMethods = [makePaymentMethod({ archived_at: '2026-11-01T00:00:00Z' })];
    let restored = '';
    server.use(
      http.post(`${API}/payment-methods/:id/restore`, ({ params }) => {
        restored = String(params.id);
        testBackend.paymentMethods = [makePaymentMethod()];
        return HttpResponse.json(envelope(makePaymentMethod()));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/accounts/payment-methods', { user: user0() });
    await findPageHeading('Payment methods');
    await user.click(screen.getByLabelText('Show archived'));
    await user.click(await screen.findByRole('button', { name: 'Restore: GPay' }));
    expect(await screen.findByText('Payment method restored')).toBeInTheDocument();
    expect(restored).toBe(METHOD_UPI);
  });

  it('removes a method after confirmation and keeps the dialog open on failure', async () => {
    testBackend.paymentMethods = [makePaymentMethod()];
    let attempts = 0;
    server.use(
      http.delete(`${API}/payment-methods/:id`, ({ params }) => {
        attempts += 1;
        expect(params.id).toBe(METHOD_UPI);
        if (attempts === 1) {
          return HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 });
        }
        testBackend.paymentMethods = [];
        return HttpResponse.json(envelope({ deleted: false, archived: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/accounts/payment-methods', { user: user0() });
    await findPageHeading('Payment methods');
    await user.click(await screen.findByRole('button', { name: 'Remove: GPay' }));
    const dialog = await screen.findByRole('dialog', { name: 'Remove this payment method?' });
    await user.click(within(dialog).getByRole('button', { name: 'Remove' }));
    expect(
      await within(dialog).findByText('Montra is temporarily unavailable. Try again in a moment.'),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Remove' }));
    expect(
      await screen.findByText('Payment method archived because past transactions use it'),
    ).toBeInTheDocument();
    expect(await screen.findByText('No payment methods yet')).toBeInTheDocument();
  });
});
