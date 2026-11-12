import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { delay, http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import type { OwnProfile } from '@/features/social/types';
import type { Preferences } from '@/shared/finance/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { ACCOUNT_CARD, ACCOUNT_CASH, makeAccount, makePreferences } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import {
  pngFile,
  previewHandlers,
  signedUrl,
  UPLOAD_FILE,
  uploadHandlers,
} from '@/tests/receiptsFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';
import { makeOwnProfile } from '@/tests/socialFixtures';

const PATH = '/settings/profile';
const signedIn = () => makeUser({ onboarding_completed: true });

interface Backend {
  profile: OwnProfile;
  profilePatches: Record<string, unknown>[];
  preferencePatches: Record<string, unknown>[];
}

/** GET/PATCH /me and PATCH /me/preferences like the API (partial updates), recording bodies. */
function settingsBackend(profile: OwnProfile = makeOwnProfile()): Backend {
  const backend: Backend = { profile, profilePatches: [], preferencePatches: [] };
  server.use(
    http.get(`${API}/me`, () =>
      HttpResponse.json(
        envelope({
          account: testBackend.user,
          profile: backend.profile,
          preferences: testBackend.preferences,
        }),
      ),
    ),
    http.patch(`${API}/me`, async ({ request }) => {
      const body = (await request.json()) as Record<string, unknown>;
      backend.profilePatches.push(body);
      backend.profile = applyPatch(backend.profile, body);
      return HttpResponse.json(envelope(backend.profile));
    }),
    http.patch(`${API}/me/preferences`, async ({ request }) => {
      const body = (await request.json()) as Record<string, unknown>;
      backend.preferencePatches.push(body);
      const { clear_default_account: clearAccount, ...rest } = body;
      testBackend.preferences = applyPatch<Preferences>(
        testBackend.preferences,
        clearAccount ? { ...rest, default_account_id: '' } : rest,
      );
      return HttpResponse.json(envelope(testBackend.preferences));
    }),
  );
  return backend;
}

/** A loaded card (the loading state carries the same title, so wait for its save button). */
async function findCard(name: string, save: string) {
  await screen.findByRole('button', { name: save });
  return screen.getByRole('region', { name });
}

/**
 * Applies a partial update like the API: absent fields stay, `""` clears an
 * optional field, other values replace it.
 */
function applyPatch<T extends object>(record: T, body: Record<string, unknown>): T {
  const cleared = new Set(
    Object.entries(body)
      .filter(([, value]) => value === '')
      .map(([key]) => key),
  );
  const kept = Object.entries(record).filter(([key]) => !cleared.has(key));
  const set = Object.entries(body).filter(([, value]) => value !== '');
  return Object.fromEntries([...kept, ...set, ['updated_at', '2026-11-12T10:00:00Z']]) as T;
}

async function openPage() {
  const user = userEvent.setup();
  const view = renderRoute(PATH, { user: signedIn() });
  await findPageHeading('Profile and preferences');
  return { user, ...view };
}

describe('ProfileSettingsPage — profile', () => {
  it('sends only the changed profile fields, with "" to clear text', async () => {
    const backend = settingsBackend(
      makeOwnProfile({ bio: 'Saving for a bike', interests: ['Cricket'], coarse_location: 'Pune' }),
    );
    const { user } = await openPage();
    const card = await findCard('Your profile', 'Save profile');
    const name = within(card).getByLabelText('Display name');
    expect(name).toHaveValue('Asha Rao');
    await user.clear(name);
    await user.type(name, 'Asha R.');
    await user.clear(within(card).getByLabelText(/^Bio/));
    const interests = within(card).getByLabelText(/^Interests/);
    await user.clear(interests);
    await user.type(interests, 'Cricket, cooking , ,travel');
    await user.click(within(card).getByRole('button', { name: 'Save profile' }));

    expect(await screen.findByText('Profile saved')).toBeInTheDocument();
    expect(backend.profilePatches).toEqual([
      { display_name: 'Asha R.', bio: '', interests: ['Cricket', 'cooking', 'travel'] },
    ]);
    // Saving again without changes sends nothing.
    await user.click(within(card).getByRole('button', { name: 'Save profile' }));
    expect(
      await screen.findByText('Nothing to save: you haven’t changed anything'),
    ).toBeInTheDocument();
    expect(backend.profilePatches).toHaveLength(1);
  });

  it('saves who can see the profile and send requests', async () => {
    const backend = settingsBackend();
    const { user } = await openPage();
    const card = await findCard('Your profile', 'Save profile');
    await user.click(within(card).getByRole('radio', { name: /^Anyone on Montra/ }));
    await user.click(within(card).getByLabelText('Let people find me by my username'));
    await user.click(within(card).getByLabelText('Show my challenge achievements on my profile'));
    await user.click(within(card).getByRole('radio', { name: /^Nobody/ }));
    await user.click(within(card).getByRole('button', { name: 'Save profile' }));
    await screen.findByText('Profile saved');
    expect(backend.profilePatches).toEqual([
      {
        profile_visibility: 'public',
        discoverable_by_username: false,
        show_achievements: true,
        allow_friend_requests: 'nobody',
      },
    ]);
  });

  it('explains username refusals: taken (409), reserved and invalid (422)', async () => {
    const answers = [
      HttpResponse.json(
        errorBody({
          code: 'CONFLICT',
          details: [
            { field: 'body.username', code: 'username_taken', message: 'That username is taken.' },
          ],
        }),
        { status: 409 },
      ),
      HttpResponse.json(
        errorBody({
          code: 'VALIDATION_ERROR',
          details: [
            {
              field: 'body.username',
              code: 'username_reserved',
              message: 'This username is reserved.',
            },
          ],
        }),
        { status: 422 },
      ),
      HttpResponse.json(
        errorBody({
          code: 'VALIDATION_ERROR',
          details: [
            {
              field: 'body.username',
              code: 'username_invalid',
              message: "Use 3-30 lowercase letters, digits, '_' or '.'.",
            },
          ],
        }),
        { status: 422 },
      ),
    ];
    const bodies: unknown[] = [];
    settingsBackend();
    server.use(
      http.patch(`${API}/me`, async ({ request }) => {
        bodies.push(await request.json());
        return answers.shift() ?? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }));
      }),
    );
    const { user } = await openPage();
    const card = await findCard('Your profile', 'Save profile');
    const username = within(card).getByLabelText(/^Username/);
    const save = within(card).getByRole('button', { name: 'Save profile' });

    // Checked here first: nothing is sent for a username that can't be valid.
    await user.clear(username);
    await user.type(username, 'ab');
    await user.click(save);
    expect(
      await within(card).findByText(
        'Use 3 to 30 characters: lowercase letters, numbers, dots and underscores.',
      ),
    ).toBeInTheDocument();
    expect(bodies).toHaveLength(0);

    await user.clear(username);
    await user.type(username, '@Meera.R');
    await user.click(save);
    expect(
      await within(card).findByText('That username is taken. Try another one.'),
    ).toBeInTheDocument();
    expect(username).toHaveFocus();
    expect(bodies[0]).toEqual({ username: 'meera.r' });

    await user.clear(username);
    await user.type(username, 'support');
    await user.click(save);
    expect(
      await within(card).findByText('That username is kept for Montra. Choose another one.'),
    ).toBeInTheDocument();

    await user.clear(username);
    await user.type(username, 'asha_99');
    await user.click(save);
    expect(
      await within(card).findByText(
        'Use 3 to 30 characters: lowercase letters, numbers, dots and underscores.',
      ),
    ).toBeInTheDocument();
    expect(bodies).toHaveLength(3);
  });

  it('removes the username with an empty value', async () => {
    const backend = settingsBackend();
    const { user } = await openPage();
    const card = await findCard('Your profile', 'Save profile');
    await user.clear(within(card).getByLabelText(/^Username/));
    await user.click(within(card).getByRole('button', { name: 'Save profile' }));
    await screen.findByText('Profile saved');
    expect(backend.profilePatches).toEqual([{ username: '' }]);
  });

  it('shows loading, then permission denied, and an error with retry for preferences', async () => {
    let failPreferences = true;
    server.use(
      http.get(`${API}/me`, async () => {
        await delay(20);
        return HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 });
      }),
      http.get(`${API}/me/preferences`, () =>
        failPreferences
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(envelope(testBackend.preferences)),
      ),
    );
    const { user } = await openPage();
    expect(screen.getByText('Loading your profile…')).toBeInTheDocument();
    const profile = screen.getByRole('region', { name: 'Your profile' });
    expect(await within(profile).findByText('You don’t have access to this')).toBeInTheDocument();
    const region = screen.getByRole('region', { name: 'Region, money and display' });
    expect(
      await within(region).findByText('We couldn’t load your preferences'),
    ).toBeInTheDocument();
    failPreferences = false;
    await user.click(within(region).getByRole('button', { name: 'Try again' }));
    expect(await screen.findByRole('button', { name: 'Save preferences' })).toBeInTheDocument();
  });
});

describe('ProfileSettingsPage — avatar', () => {
  it('uploads a photo with purpose avatar, then links it and shows it', async () => {
    const backend = settingsBackend();
    const { handlers, log } = uploadHandlers();
    server.use(...handlers, ...previewHandlers());
    const { user } = await openPage();
    const card = await screen.findByRole('region', { name: 'Profile photo' });
    expect(within(card).getByText('AR')).toBeInTheDocument();
    await user.upload(within(card).getByLabelText('Choose a profile photo'), pngFile('me.png'));

    expect(await screen.findByText('Profile photo updated')).toBeInTheDocument();
    expect(log.intents[0]).toMatchObject({
      purpose: 'avatar',
      filename: 'me.png',
      content_type: 'image/png',
    });
    expect(log.completes).toEqual([UPLOAD_FILE]);
    expect(backend.profilePatches).toEqual([{ avatar_file_id: UPLOAD_FILE }]);
    // Shown through GET /files/{id}/access, downloaded into a data: URL.
    const image = await within(card).findByRole('img', { name: 'Your profile photo' });
    expect(image.getAttribute('src')).toMatch(/^data:image\/png;base64,/);
    expect(image.getAttribute('src')).not.toContain(signedUrl(UPLOAD_FILE));
  });

  it('refuses other file types before uploading', async () => {
    settingsBackend();
    const { handlers, log } = uploadHandlers();
    server.use(...handlers);
    const user = userEvent.setup({ applyAccept: false });
    renderRoute(PATH, { user: signedIn() });
    await findPageHeading('Profile and preferences');
    const card = await screen.findByRole('region', { name: 'Profile photo' });
    await user.upload(
      within(card).getByLabelText('Choose a profile photo'),
      new File(['%PDF'], 'scan.pdf', { type: 'application/pdf' }),
    );
    expect(await within(card).findByText('Choose a JPG, PNG or WebP image.')).toBeInTheDocument();
    expect(log.intents).toHaveLength(0);
  });

  it('explains avatar_file_invalid', async () => {
    settingsBackend();
    const { handlers } = uploadHandlers();
    server.use(
      ...handlers,
      http.patch(`${API}/me`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.avatar_file_id',
                code: 'avatar_file_invalid',
                message: 'Upload the image with purpose avatar and finish the upload first.',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const { user } = await openPage();
    const card = await screen.findByRole('region', { name: 'Profile photo' });
    await user.upload(within(card).getByLabelText('Choose a profile photo'), pngFile());
    expect(
      await within(card).findByText(
        'That image can’t be used as your photo. Upload it again and wait for the upload to finish.',
      ),
    ).toBeInTheDocument();
  });

  it('removes the photo with an empty avatar_file_id after confirming', async () => {
    const backend = settingsBackend(makeOwnProfile({ avatar_file_id: UPLOAD_FILE }));
    server.use(...previewHandlers());
    const { user } = await openPage();
    const card = await screen.findByRole('region', { name: 'Profile photo' });
    await within(card).findByRole('img', { name: 'Your profile photo' });
    await user.click(within(card).getByRole('button', { name: 'Remove photo' }));
    const dialog = await screen.findByRole('dialog', { name: 'Remove your profile photo?' });
    await user.click(within(dialog).getByRole('button', { name: 'Remove photo' }));
    expect(await screen.findByText('Profile photo removed')).toBeInTheDocument();
    expect(backend.profilePatches).toEqual([{ avatar_file_id: '' }]);
    expect(await within(card).findByText('AR')).toBeInTheDocument();
  });
});

describe('ProfileSettingsPage — preferences', () => {
  it('explains a main-currency change and sends only the changed preferences', async () => {
    testBackend.accounts = [makeAccount(), makeAccount({ id: ACCOUNT_CARD, name: 'Card' })];
    testBackend.preferences = makePreferences({
      display_currency: 'USD',
      country: 'IN',
      default_account_id: ACCOUNT_CASH,
    });
    const backend = settingsBackend();
    const { user } = await openPage();
    const card = await findCard('Region, money and display', 'Save preferences');
    await user.selectOptions(within(card).getByLabelText('Main currency'), 'EUR');
    expect(within(card).getByText('What changing your main currency does')).toBeInTheDocument();
    expect(
      within(card).getByText(
        'New records will start in EUR instead of INR. Amounts you’ve already recorded, your accounts and their balances keep their currency and are not converted, and totals in different currencies are still shown separately.',
      ),
    ).toBeInTheDocument();
    await user.selectOptions(within(card).getByLabelText(/^Display currency/), '');
    await user.selectOptions(within(card).getByLabelText(/^Country/), '');
    await user.selectOptions(within(card).getByLabelText('Date format'), 'ymd');
    await user.selectOptions(within(card).getByLabelText('Number format'), 'indian');
    await user.selectOptions(within(card).getByLabelText('Week starts on'), '0');
    await user.selectOptions(within(card).getByLabelText('Month starts on day'), '25');
    await user.selectOptions(within(card).getByLabelText('Default period'), 'last_30_days');
    await user.selectOptions(within(card).getByLabelText(/^Default account/), '');
    await user.click(within(card).getByRole('button', { name: 'Save preferences' }));

    expect(await screen.findByText('Preferences saved')).toBeInTheDocument();
    expect(backend.preferencePatches).toEqual([
      {
        base_currency: 'EUR',
        display_currency: '',
        country: '',
        date_format: 'ymd',
        number_format: 'indian',
        week_start: 0,
        month_start_day: 25,
        clear_default_account: true,
        default_date_range: 'last_30_days',
      },
    ]);
    // The form now starts from the saved values: choosing an account sends just that.
    await user.selectOptions(within(card).getByLabelText(/^Default account/), ACCOUNT_CARD);
    await user.click(within(card).getByRole('button', { name: 'Save preferences' }));
    await waitFor(() => {
      expect(backend.preferencePatches).toHaveLength(2);
    });
    expect(backend.preferencePatches[1]).toEqual({ default_account_id: ACCOUNT_CARD });
  });

  it('applies a saved theme across the app', async () => {
    const backend = settingsBackend();
    const { user } = await openPage();
    const card = await findCard('Region, money and display', 'Save preferences');
    await user.selectOptions(within(card).getByLabelText('Theme'), 'dark');
    await user.click(within(card).getByRole('button', { name: 'Save preferences' }));
    await screen.findByText('Preferences saved');
    expect(backend.preferencePatches).toEqual([{ theme: 'dark' }]);
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark');
  });

  it('shows field errors from the API next to the field', async () => {
    settingsBackend();
    server.use(
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
    const { user } = await openPage();
    const card = await findCard('Region, money and display', 'Save preferences');
    await user.selectOptions(within(card).getByLabelText('Time zone'), 'UTC');
    await user.click(within(card).getByRole('button', { name: 'Save preferences' }));
    expect(await within(card).findByText('Unknown time zone.')).toBeInTheDocument();
    expect(within(card).getByLabelText('Time zone')).toHaveFocus();
  });
});

describe('ProfileSettingsPage — accessibility', () => {
  it('saves reduced motion, high contrast and text size, and applies them at once', async () => {
    const backend = settingsBackend();
    const { user } = await openPage();
    const root = document.documentElement;
    expect(root).not.toHaveAttribute('data-motion');
    const card = await findCard('Accessibility', 'Save accessibility settings');
    await user.click(within(card).getByLabelText('Reduce motion'));
    await user.click(within(card).getByLabelText('High contrast'));
    await user.selectOptions(within(card).getByLabelText('Text size'), '125');
    await user.click(within(card).getByRole('button', { name: 'Save accessibility settings' }));

    expect(await screen.findByText('Accessibility settings saved')).toBeInTheDocument();
    expect(backend.preferencePatches).toEqual([
      { reduced_motion: true, high_contrast: true, text_scale_percent: 125 },
    ]);
    await waitFor(() => {
      expect(root).toHaveAttribute('data-motion', 'reduce');
    });
    expect(root).toHaveAttribute('data-contrast', 'high');
    expect(root.style.fontSize).toBe('125%');

    // Back to the defaults: only the text size changes.
    await user.selectOptions(within(card).getByLabelText('Text size'), '100');
    await user.click(within(card).getByRole('button', { name: 'Save accessibility settings' }));
    await waitFor(() => {
      expect(root.style.fontSize).toBe('');
    });
    expect(backend.preferencePatches[1]).toEqual({ text_scale_percent: 100 });
  });
});

describe('Profile and preferences navigation', () => {
  it('is reachable from the account menu and the navigation', async () => {
    settingsBackend();
    const user = userEvent.setup();
    renderRoute('/account', { user: signedIn() });
    await findPageHeading('Your account');
    const [trigger] = screen.getAllByRole('button', { name: 'Account menu' });
    await user.click(trigger!);
    const menu = await screen.findByRole('menu', { name: 'Account menu' });
    expect(within(menu).getByRole('menuitem', { name: 'Profile and preferences' })).toHaveAttribute(
      'href',
      PATH,
    );
    await user.keyboard('{Escape}');
    expect(screen.getAllByRole('link', { name: 'Preferences' })[0]).toHaveAttribute('href', PATH);
    expect(screen.getByRole('link', { name: 'Edit profile' })).toHaveAttribute('href', PATH);
  });

  it('redirects /settings to the profile and preferences screen', async () => {
    settingsBackend();
    const { router } = renderRoute('/settings', { user: signedIn() });
    await findPageHeading('Profile and preferences');
    expect(router.state.location.pathname).toBe(PATH);
  });
});
