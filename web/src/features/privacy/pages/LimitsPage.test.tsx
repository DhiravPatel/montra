import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, describe, expect, it } from 'vitest';
import type { Limits } from '@/features/privacy/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { makeLimits } from '@/tests/privacyFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';

function serveLimits(limits: Limits) {
  server.use(http.get(`${API}/limits`, () => HttpResponse.json(envelope(limits))));
}

async function openLimits() {
  renderRoute('/settings/limits', { user: makeUser({ onboarding_completed: true }) });
  await findPageHeading('Fair-use limits');
}

beforeAll(async () => {
  await import('./LimitsPage');
});

describe('LimitsPage', () => {
  it('localizes the fair-use note by note_code and shows a newer note as sent', async () => {
    serveLimits(
      makeLimits({
        note_code: 'brand_new_note' as Limits['note_code'],
        note: 'A newer note from the server.',
      }),
    );
    await openLimits();
    const note = await screen.findByText('A newer note from the server.');
    expect(note).toHaveAttribute('lang', 'en');
    expect(screen.queryByText(/There are no paid plans or upgrades\./)).not.toBeInTheDocument();
  });

  it('shows every limit with its meaning, storage as a meter with text, and that it’s all free', async () => {
    serveLimits(makeLimits());
    await openLimits();
    expect(screen.getByText('Everything is free, for everyone')).toBeVisible();
    expect(
      screen.getByText(
        'There are no paid plans or upgrades. These limits are the same for every account; they keep Montra fast and affordable to run.',
      ),
    ).toBeVisible();

    const storage = await screen.findByRole('region', { name: 'Your storage' });
    expect(within(storage).getByText('512 MB of 2 GB used (25%)')).toBeVisible();
    const meter = within(storage).getByRole('meter', { name: 'Storage used' });
    expect(meter).toHaveAttribute('aria-valuenow', '25');
    expect(meter).toHaveAttribute('aria-valuetext', '512 MB of 2 GB used (25%)');
    expect(within(storage).queryByText('Almost full')).not.toBeInTheDocument();

    const records = screen.getByRole('region', { name: 'Limits on files and records' });
    const row = (label: string) => within(records).getByText(label).closest('div')!;
    expect(within(row('Largest file')).getByText('20 MB')).toBeVisible();
    expect(within(row('Statement import')).getByText('20,000 rows')).toBeVisible();
    expect(within(row('Recurring rules')).getByText('500')).toBeVisible();
    expect(
      within(row('Recurring rules')).getByText(
        'Recurring rules that haven’t ended. Bill schedules count too.',
      ),
    ).toBeVisible();
    expect(within(row('Bills')).getByText('200')).toBeVisible();
    expect(within(row('Subscriptions')).getByText('500')).toBeVisible();
    expect(within(row('Goals')).getByText('200')).toBeVisible();
    expect(within(row('Support requests')).getByText('10 per day')).toBeVisible();
    expect(within(row('Download window')).getByText('7 days')).toBeVisible();
    expect(within(row('Deletion grace period')).getByText('7 days')).toBeVisible();
    expect(within(row('AI requests')).getByText('Off')).toBeVisible();

    const rates = screen.getByRole('table', { name: 'Request rates' });
    const write = within(rates).getByRole('row', { name: /Saving changes/ });
    expect(within(write).getByText('240')).toBeVisible();
    expect(within(write).getByText('40')).toBeVisible();
    expect(within(rates).getAllByRole('row')).toHaveLength(7);
  });

  it('says so in words when storage is almost full or full', async () => {
    serveLimits(makeLimits({ storage_used_bytes: 1_932_735_283 }));
    const first = renderRoute('/settings/limits', {
      user: makeUser({ onboarding_completed: true }),
    });
    const storage = await screen.findByRole('region', { name: 'Your storage' });
    expect(within(storage).getByText('Almost full')).toBeVisible();
    expect(within(storage).getByText(/To make room, delete files/)).toBeVisible();
    first.unmount();

    serveLimits(makeLimits({ storage_used_bytes: 2_147_483_648 }));
    await openLimits();
    const full = await screen.findByRole('region', { name: 'Your storage' });
    expect(within(full).getByText('Full')).toBeVisible();
    expect(within(full).getByText('2 GB of 2 GB used (100%)')).toBeVisible();
  });

  it('shows usage without a meter when there is no storage cap', async () => {
    serveLimits(makeLimits({ storage_quota_bytes: 0, storage_used_bytes: 1536 }));
    await openLimits();
    const storage = await screen.findByRole('region', { name: 'Your storage' });
    expect(
      within(storage).getByText('You use 1.5 kB. There’s no storage cap right now.'),
    ).toBeVisible();
    expect(within(storage).queryByRole('meter')).not.toBeInTheDocument();
  });

  it('shows the AI allowance only when AI is on', async () => {
    serveLimits(makeLimits({ ai_requests_per_day: 50 }));
    await openLimits();
    const records = await screen.findByRole('region', { name: 'Limits on files and records' });
    const ai = within(records).getByText('AI requests').closest('div')!;
    expect(within(ai).getByText('50 per day')).toBeVisible();
  });

  it('offers a retry when the limits cannot be loaded', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/limits`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(envelope(makeLimits()));
      }),
    );
    const events = userEvent.setup();
    await openLimits();
    expect(await screen.findByText('We couldn’t load the limits')).toBeVisible();
    await events.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('region', { name: 'Your storage' })).toBeVisible();
  });

  it('shows the permission state on 403', async () => {
    server.use(
      http.get(`${API}/limits`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    await openLimits();
    expect(await screen.findByText('You don’t have access to this')).toBeVisible();
  });
});
