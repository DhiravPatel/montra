import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { DetectionConfirmInput } from '@/shared/finance/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { makeAccount, starterCategories } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import {
  DETECTION_SPOTIFY,
  MERCHANT_SPOTIFY,
  SUB_GYM,
  makeDetection,
  makeSubscription,
} from '@/tests/subscriptionsFixtures';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const TITLE = 'Subscriptions found in your transactions';

describe('SubscriptionReviewPage', () => {
  it('explains each find from its evidence and adds it only after confirmation', async () => {
    testBackend.accounts = [makeAccount()];
    testBackend.categories = starterCategories();
    const bodies: DetectionConfirmInput[] = [];
    server.use(
      http.get(`${API}/subscriptions/detections`, ({ request }) => {
        expect(new URL(request.url).searchParams.get('status')).toBe('pending');
        return HttpResponse.json(envelope([makeDetection()]));
      }),
      http.post(`${API}/subscriptions/detections/:id/confirm`, async ({ params, request }) => {
        expect(params.id).toBe(DETECTION_SPOTIFY);
        bodies.push((await request.json()) as DetectionConfirmInput);
        return HttpResponse.json(
          envelope(makeSubscription({ id: SUB_GYM, name: 'Spotify Premium', source: 'detected' })),
          { status: 201 },
        );
      }),
      http.get(`${API}/subscriptions/:id`, () =>
        HttpResponse.json(
          envelope(makeSubscription({ id: SUB_GYM, name: 'Spotify Premium', source: 'detected' })),
        ),
      ),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/subscriptions/review', { user: signedIn() });
    await findPageHeading(TITLE);

    const item = (await screen.findByRole('heading', { name: 'Spotify' })).closest('li')!;
    expect(within(item).getByText(/Monthly/)).toBeInTheDocument();
    expect(within(item).getByText('₹199.00')).toBeInTheDocument();
    expect(within(item).getByText('₹9.95')).toBeInTheDocument();
    // confidence_bp 9660 (basis points) as a whole percentage.
    expect(within(item).getByText('97% confidence')).toBeInTheDocument();
    // Each reason_codes entry in the interface language, from the evidence numbers.
    expect(within(item).getByText('5 charges, usually every 30 days')).toBeInTheDocument();
    expect(
      within(item).getByText('4 of 4 gaps between charges match the usual interval'),
    ).toBeInTheDocument();
    expect(
      within(item).getByText('5 of 5 amounts are within 5% of the typical charge'),
    ).toBeInTheDocument();
    // The English reasons are not shown.
    expect(within(item).queryByText(/typically every 30 days/)).toBeNull();
    expect(within(item).getByText('Last charge on October 12, 2026')).toBeInTheDocument();
    expect(
      within(item).getByText('Next charge expected around November 12, 2026'),
    ).toBeInTheDocument();
    expect(within(item).getByRole('link', { name: 'See the charges' })).toHaveAttribute(
      'href',
      `/transactions?merchant_id=${MERCHANT_SPOTIFY}`,
    );

    await user.click(within(item).getByRole('button', { name: 'Add as subscription: Spotify' }));
    const dialog = await screen.findByRole('dialog', { name: 'Add this subscription' });
    const name = await within(dialog).findByLabelText('Name');
    expect(name).toHaveValue('Spotify');
    expect(within(dialog).getByLabelText(/^Price per billing cycle/)).toHaveValue('199.00');
    expect(within(dialog).getByLabelText(/^Next renewal/)).toHaveValue('2026-11-12');
    await user.clear(name);
    await user.type(name, 'Spotify Premium');
    await user.click(within(dialog).getByRole('button', { name: 'Add subscription' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/subscriptions/${SUB_GYM}`);
    });
    expect(bodies).toEqual([
      { name: 'Spotify Premium', amount: '199.00', next_renewal_date: '2026-11-12' },
    ]);
    expect(await screen.findByText('Subscription added')).toBeInTheDocument();
  });

  it('dismisses a suggestion after confirmation and shows when nothing is left', async () => {
    let dismissed = false;
    server.use(
      http.get(`${API}/subscriptions/detections`, () =>
        HttpResponse.json(envelope(dismissed ? [] : [makeDetection()])),
      ),
      http.post(`${API}/subscriptions/detections/:id/dismiss`, () => {
        dismissed = true;
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/subscriptions/review', { user: signedIn() });
    await findPageHeading(TITLE);
    await user.click(await screen.findByRole('button', { name: 'Dismiss: Spotify' }));
    const dialog = await screen.findByRole('dialog', { name: 'Dismiss this suggestion?' });
    expect(
      within(dialog).getByText('Spotify won’t be suggested again. Your transactions don’t change.'),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Dismiss' }));
    expect(await screen.findByText('Suggestion dismissed')).toBeInTheDocument();
    expect(await screen.findByText('Nothing to review')).toBeInTheDocument();
    expect(dismissed).toBe(true);
  });

  it('starts a background check and can show the ones already handled', async () => {
    const statuses: string[] = [];
    let refreshed = 0;
    server.use(
      http.get(`${API}/subscriptions/detections`, ({ request }) => {
        const status = new URL(request.url).searchParams.get('status') ?? '';
        statuses.push(status);
        return HttpResponse.json(
          envelope(status === 'confirmed' ? [makeDetection({ status: 'confirmed' })] : []),
        );
      }),
      http.post(`${API}/subscriptions/detections/refresh`, () => {
        refreshed += 1;
        return HttpResponse.json(envelope({ ok: true }), { status: 202 });
      }),
    );
    const user = userEvent.setup();
    const { router } = renderRoute('/subscriptions/review', { user: signedIn() });
    await findPageHeading(TITLE);
    expect(await screen.findByText('Nothing to review')).toBeInTheDocument();

    await user.click(screen.getAllByRole('button', { name: 'Look for new subscriptions' })[0]!);
    expect(await screen.findByText('Checking your transactions')).toBeInTheDocument();
    expect(refreshed).toBe(1);

    await user.click(screen.getByLabelText('Added'));
    expect(await screen.findByText('Added as a subscription')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Add as subscription: Spotify' })).toBeNull();
    expect(router.state.location.search).toBe('?status=confirmed');
    expect(statuses).toEqual(['pending', 'confirmed']);
  });

  it('tells the user when a suggestion was already handled elsewhere', async () => {
    testBackend.accounts = [makeAccount()];
    server.use(
      http.get(`${API}/subscriptions/detections`, () =>
        HttpResponse.json(envelope([makeDetection()])),
      ),
      http.post(`${API}/subscriptions/detections/:id/confirm`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                code: 'detection_already_decided',
                message: 'This detection was already confirmed.',
                params: { status: 'confirmed' },
              },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/subscriptions/review', { user: signedIn() });
    await findPageHeading(TITLE);
    await user.click(await screen.findByRole('button', { name: 'Add as subscription: Spotify' }));
    const dialog = await screen.findByRole('dialog', { name: 'Add this subscription' });
    await within(dialog).findByLabelText('Name');
    await user.click(within(dialog).getByRole('button', { name: 'Add subscription' }));
    expect(
      await within(dialog).findByText(
        'This suggestion was already handled. The list is up to date now.',
      ),
    ).toBeInTheDocument();
  });

  it('explains when the charges behind a suggestion are gone', async () => {
    testBackend.accounts = [makeAccount()];
    server.use(
      http.get(`${API}/subscriptions/detections`, () =>
        HttpResponse.json(envelope([makeDetection()])),
      ),
      http.post(`${API}/subscriptions/detections/:id/confirm`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                code: 'detection_evidence_missing',
                message: 'The supporting transactions no longer exist; dismiss this detection.',
              },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/subscriptions/review', { user: signedIn() });
    await findPageHeading(TITLE);
    await user.click(await screen.findByRole('button', { name: 'Add as subscription: Spotify' }));
    const dialog = await screen.findByRole('dialog', { name: 'Add this subscription' });
    await within(dialog).findByLabelText('Name');
    await user.click(within(dialog).getByRole('button', { name: 'Add subscription' }));
    expect(
      await within(dialog).findByText(
        'The charges behind this suggestion no longer exist, so it can’t be added. Dismiss it instead.',
      ),
    ).toBeInTheDocument();
  });

  it('shows a retryable error and the permission state', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/subscriptions/detections`, () => {
        calls += 1;
        if (calls === 1) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 });
        }
        return HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/subscriptions/review', { user: signedIn() });
    await findPageHeading(TITLE);
    expect(await screen.findByText('We couldn’t load possible subscriptions')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
