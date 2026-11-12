import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { TRIP_ID, groupReadHandlers, makeTripDetail } from '@/tests/groupsFixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

async function openForm() {
  const user = userEvent.setup();
  const result = renderRoute('/groups/new', { user: signedIn() });
  await findPageHeading('Create a group');
  await screen.findByLabelText('Group name');
  return { user, ...result };
}

describe('GroupCreatePage', () => {
  it('checks the name and type before calling the API', async () => {
    let called = false;
    server.use(
      http.post(`${API}/groups`, () => {
        called = true;
        return HttpResponse.json(envelope(makeTripDetail()), { status: 201 });
      }),
    );
    const { user } = await openForm();
    await user.click(screen.getByRole('button', { name: 'Create group' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Group name')).toHaveAccessibleDescription(
        /Enter a group name\./,
      );
    });
    expect(screen.getByText('Choose what kind of group this is.')).toBeInTheDocument();
    expect(called).toBe(false);
  });

  it('asks for trip dates in order', async () => {
    const { user } = await openForm();
    await user.type(screen.getByLabelText('Group name'), 'Goa trip');
    await user.click(screen.getByRole('radio', { name: /^Trip/ }));
    await user.type(screen.getByLabelText(/^Start date/), '2026-12-24');
    await user.type(screen.getByLabelText(/^End date/), '2026-12-20');
    await user.click(screen.getByRole('button', { name: 'Create group' }));
    await waitFor(() => {
      expect(screen.getByLabelText(/^End date/)).toHaveAccessibleDescription(
        /The start date must be on or before the end date\./,
      );
    });
  });

  it('creates a trip with its dates and settings, then opens it', async () => {
    let body: unknown = null;
    const created = makeTripDetail();
    const reads = groupReadHandlers(created);
    server.use(
      http.post(`${API}/groups`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(created), { status: 201 });
      }),
      ...reads.handlers,
    );
    const { user, router } = await openForm();
    // Defaults come from the user's own currency and time zone.
    expect(screen.getByLabelText('Group currency')).toHaveValue('INR');
    expect(screen.getByLabelText('Time zone')).toHaveValue('Asia/Kolkata');
    // Trip fields appear only for trips and events.
    expect(screen.queryByLabelText(/^Start date/)).not.toBeInTheDocument();

    await user.type(screen.getByLabelText('Group name'), '  Goa trip ');
    await user.click(screen.getByRole('radio', { name: /^Trip/ }));
    await user.type(screen.getByLabelText(/^Start date/), '2026-12-20');
    await user.type(screen.getByLabelText(/^End date/), '2026-12-24');
    await user.type(screen.getByLabelText(/^Destination/), 'Goa');
    await user.selectOptions(screen.getByLabelText('Group currency'), 'EUR');
    await user.selectOptions(screen.getByLabelText('Usual way to split'), 'shares');
    await user.click(screen.getByLabelText('Members can invite people'));
    // Off by default; the help explains what approval changes.
    const approval = screen.getByLabelText('Approve people who join with a link');
    expect(approval).not.toBeChecked();
    expect(approval).toHaveAccessibleDescription(
      /a link creates a request that the owner or an admin approves/,
    );
    await user.click(approval);
    await user.type(screen.getByLabelText(/^Group rules/), 'Fuel is shared equally');
    await user.click(screen.getByRole('button', { name: 'Create group' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/groups/${TRIP_ID}`);
    });
    expect(body).toEqual({
      name: 'Goa trip',
      group_type: 'trip',
      base_currency: 'EUR',
      timezone: 'Asia/Kolkata',
      default_split_method: 'shares',
      simplify_debts: true,
      allow_member_invites: false,
      require_join_approval: true,
      rules: 'Fuel is shared equally',
      start_date: '2026-12-20',
      end_date: '2026-12-24',
      destination: 'Goa',
    });
    expect(await screen.findByText('Group created')).toBeInTheDocument();
    expect(await findPageHeading('Goa trip')).toBeInTheDocument();
  });

  it('prevents a second create while the first is still saving', async () => {
    let calls = 0;
    let release: () => void = () => undefined;
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    const reads = groupReadHandlers(makeTripDetail());
    server.use(
      http.post(`${API}/groups`, async () => {
        calls += 1;
        await gate;
        return HttpResponse.json(envelope(makeTripDetail()), { status: 201 });
      }),
      ...reads.handlers,
    );
    const { user, router } = await openForm();
    await user.type(screen.getByLabelText('Group name'), 'Goa trip');
    await user.click(screen.getByRole('radio', { name: /^Trip/ }));
    const submit = screen.getByRole('button', { name: 'Create group' });
    await user.click(submit);
    await waitFor(() => {
      expect(submit).toHaveAttribute('aria-disabled', 'true');
    });
    await user.click(submit);
    release();
    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/groups/${TRIP_ID}`);
    });
    expect(calls).toBe(1);
  });

  it('shows the API’s field errors on the form', async () => {
    server.use(
      http.post(`${API}/groups`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.timezone', message: 'Unknown time zone.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const { user } = await openForm();
    await user.type(screen.getByLabelText('Group name'), 'Flat 4B');
    await user.click(screen.getByRole('radio', { name: /^Roommates/ }));
    await user.click(screen.getByRole('button', { name: 'Create group' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Time zone')).toHaveAccessibleDescription(/Unknown time zone\./);
    });
  });

  it('explains a refused create (permission) and keeps the form', async () => {
    server.use(
      http.post(`${API}/groups`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    const { user } = await openForm();
    await user.type(screen.getByLabelText('Group name'), 'Flat 4B');
    await user.click(screen.getByRole('radio', { name: /^Roommates/ }));
    await user.click(screen.getByRole('button', { name: 'Create group' }));
    expect(await screen.findByText('You don’t have permission to do that.')).toBeInTheDocument();
    expect(screen.getByLabelText('Group name')).toHaveValue('Flat 4B');
  });

  it('shows a recoverable error when currencies cannot be loaded', async () => {
    server.use(
      http.get(`${API}/currencies`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
    );
    renderRoute('/groups/new', { user: signedIn() });
    await findPageHeading('Create a group');
    expect(await screen.findByRole('button', { name: 'Try again' })).toBeInTheDocument();
    expect(screen.queryByLabelText('Group name')).not.toBeInTheDocument();
  });
});
