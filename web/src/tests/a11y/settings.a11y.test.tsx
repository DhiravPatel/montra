import { screen, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';
import { describe, it, vi } from 'vitest';
import { expectNoAxeViolations } from '@/tests/axe';
import { API, envelope, makeSession, makeUser } from '@/tests/fixtures';
import { currentSession, testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import {
  makeConsent,
  makeDeletion,
  makeLegal,
  makeLimits,
  requiredConsents,
} from '@/tests/privacyFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';
import { REQUEST_ID_2, makeSupportRequest } from '@/tests/supportFixtures';

const signedIn = () => makeUser({ onboarding_completed: true });

describe('axe: settings and help pages', () => {
  it('security settings with signed-in devices', async () => {
    testBackend.sessions = [
      currentSession(),
      makeSession({ id: 'b9b9b9b9-0000-4000-8000-000000000001', device_name: 'Firefox on Linux' }),
    ];
    renderRoute('/settings/security', { user: signedIn() });
    await findPageHeading('Security');
    const devices = screen.getByRole('region', { name: 'Signed-in devices' });
    await within(devices).findByText('Firefox on Linux');
    await expectNoAxeViolations();
  });

  it('privacy settings', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
    server.use(
      http.get(`${API}/me/consents`, () =>
        HttpResponse.json(envelope([...requiredConsents(), makeConsent()])),
      ),
      http.get(`${API}/me/deletion-request`, () => HttpResponse.json(envelope(makeDeletion()))),
      http.get(`${API}/limits`, () => HttpResponse.json(envelope(makeLimits()))),
      http.get(`${API}/me/exports`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/legal`, () => HttpResponse.json(envelope(makeLegal()))),
    );
    renderRoute('/settings/privacy', { user: signedIn() });
    await findPageHeading('Privacy & data');
    const choices = screen.getByRole('region', { name: 'Your choices' });
    await within(choices).findByRole('heading', { name: 'Location on transactions' });
    await expectNoAxeViolations();
  });

  it('help with requests', async () => {
    server.use(
      http.get(`${API}/support/requests`, () =>
        HttpResponse.json(
          envelope([
            makeSupportRequest(),
            makeSupportRequest({
              id: REQUEST_ID_2,
              kind: 'privacy',
              subject: 'Delete old data',
              status: 'resolved',
            }),
          ]),
        ),
      ),
    );
    renderRoute('/help', { user: signedIn() });
    await findPageHeading('Help & support');
    const mine = screen.getByRole('region', { name: 'Your requests' });
    await within(mine).findByText('Delete old data');
    await expectNoAxeViolations();
  });
});
