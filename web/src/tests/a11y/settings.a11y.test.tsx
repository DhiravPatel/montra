import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
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
import { previewHandlers, UPLOAD_FILE } from '@/tests/receiptsFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';
import { makeOwnProfile } from '@/tests/socialFixtures';
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

  it('profile and preferences, with the photo in the account menu', async () => {
    const user = makeUser({ onboarding_completed: true, avatar_file_id: UPLOAD_FILE });
    server.use(
      http.get(`${API}/me`, () =>
        HttpResponse.json(
          envelope({
            account: user,
            profile: makeOwnProfile({ avatar_file_id: UPLOAD_FILE }),
            preferences: testBackend.preferences,
          }),
        ),
      ),
      ...previewHandlers(),
    );
    renderRoute('/settings/profile', { user });
    await findPageHeading('Profile and preferences');
    await screen.findByRole('button', { name: 'Save profile' });
    await screen.findByRole('img', { name: 'Your profile photo' });
    await screen.findByRole('group', { name: 'Who can see your profile' });
    await waitFor(() => {
      expect(document.querySelector('header img, aside img, nav img')).not.toBeNull();
    });
    await expectNoAxeViolations();
  });

  it('onboarding goal step with field errors', async () => {
    testBackend.onboarding = {
      completed_steps: ['welcome', 'privacy', 'country', 'currency', 'timezone', 'income'],
      skipped_steps: [],
    };
    const person = userEvent.setup();
    renderRoute('/onboarding', { user: makeUser() });
    await findPageHeading('Set up Montra');
    await screen.findByRole('heading', { level: 2, name: 'A first goal (optional)' });
    await person.click(await screen.findByRole('button', { name: 'Add goal and continue' }));
    await screen.findByText('Enter a name.');
    await expectNoAxeViolations();
  });
});
