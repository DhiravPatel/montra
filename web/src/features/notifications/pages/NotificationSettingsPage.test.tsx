import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { makePreferences } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  OLD_ENDPOINT_ID,
  PHONE_ENDPOINT_ID,
  PUSH_ENDPOINT_ID,
  TEST_VAPID_KEY,
  installFakePush,
  makeNotificationPreferences,
  makePushEndpoint,
  servePushConfig,
  servePushEndpoints,
  serveUnreadCount,
} from '@/tests/notificationsFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import type { NotificationPreference, NotificationPreferencePatch } from '../types';

const signedIn = () => makeUser({ onboarding_completed: true });
const main = () => within(screen.getByRole('main'));

function servePreferences(rows: NotificationPreference[] = makeNotificationPreferences()) {
  const patches: { items: NotificationPreferencePatch[] }[] = [];
  let current = rows;
  server.use(
    http.get(`${API}/notifications/preferences`, () => HttpResponse.json(envelope(current))),
    http.patch(`${API}/notifications/preferences`, async ({ request }) => {
      const body = (await request.json()) as { items: NotificationPreferencePatch[] };
      patches.push(body);
      // Like the API: only the fields an item carries change.
      current = current.map((row) => {
        const item = body.items.find(
          (candidate) => candidate.category === row.category && candidate.channel === row.channel,
        );
        if (!item) return row;
        return {
          ...row,
          ...(item.enabled === undefined ? {} : { enabled: item.enabled }),
          ...(item.digest === undefined ? {} : { digest: item.digest }),
        };
      });
      return HttpResponse.json(envelope(current));
    }),
  );
  return patches;
}

function vapidBytes() {
  return Array.from(atob(TEST_VAPID_KEY.replace(/-/g, '+').replace(/_/g, '/') + '='), (char) =>
    char.charCodeAt(0),
  );
}

let uninstall: (() => void) | null = null;

beforeEach(() => {
  serveUnreadCount(0);
  // The card lists registrations even where this browser cannot receive push.
  servePushEndpoints([]);
});

afterEach(() => {
  uninstall?.();
  uninstall = null;
});

describe('NotificationSettingsPage: what you are notified about', () => {
  it('shows security and account as always on, and saves only what changed in each row', async () => {
    const patches = servePreferences(
      makeNotificationPreferences({ 'goal|email': { enabled: true, digest: 'weekly' } }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');

    expect(
      await main().findByText('Security and account notifications are always on'),
    ).toBeInTheDocument();
    const security = main().getByRole('group', { name: 'Security' });
    expect(within(security).getByText('Always on in Montra and by email')).toBeInTheDocument();
    for (const name of ['In Montra: Security', 'Email: Security']) {
      const box = within(security).getByRole('checkbox', { name });
      expect(box).toBeChecked();
      expect(box).toBeDisabled();
      expect(box).toHaveAccessibleDescription('Always on');
    }
    expect(within(security).getByRole('checkbox', { name: 'Browser: Security' })).toBeEnabled();
    expect(main().getByRole('checkbox', { name: 'In Montra: Your Montra account' })).toBeDisabled();
    expect(main().getByRole('button', { name: 'Save preferences' })).toBeDisabled();

    // A stored weekly timing is shown as such (the server holds those emails for Monday).
    const timing = main().getByRole('combobox', { name: 'Email timing: Goals' });
    expect(timing).toHaveValue('weekly');
    expect(within(timing).getByRole('option', { name: 'Right away' })).toBeInTheDocument();
    expect(
      within(timing).getByRole('option', { name: 'In the weekly summary' }),
    ).toBeInTheDocument();

    await user.click(main().getByRole('checkbox', { name: 'Email: Budgets' }));
    await user.click(main().getByRole('checkbox', { name: 'Phone app: Goals' }));
    await user.selectOptions(timing, 'immediate');
    expect(main().getByText('3 unsaved changes')).toBeInTheDocument();
    await user.click(main().getByRole('button', { name: 'Save preferences' }));

    expect(await screen.findByText('Notification preferences saved')).toBeInTheDocument();
    // Only the changed field of each row is sent; the server keeps the rest.
    expect(patches).toEqual([
      {
        items: [
          { category: 'budget', channel: 'email', enabled: true },
          { category: 'goal', channel: 'email', digest: 'immediate' },
          { category: 'goal', channel: 'push', enabled: false },
        ],
      },
    ]);
    await waitFor(() => {
      expect(main().getByRole('button', { name: 'Save preferences' })).toBeDisabled();
    });
    expect(main().getByRole('checkbox', { name: 'Email: Budgets' })).toBeChecked();
    expect(main().getByRole('combobox', { name: 'Email timing: Goals' })).toHaveValue('immediate');
  });

  it('offers a weekly summary per category, overriding the account setting', async () => {
    const patches = servePreferences(
      makeNotificationPreferences({ 'budget|email': { enabled: true, digest: 'immediate' } }),
    );
    testBackend.preferences = makePreferences({ email_digest: 'daily' });
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');

    expect(await main().findByText(/Your account setting is a daily summary/)).toBeInTheDocument();
    const timing = main().getByRole('combobox', { name: 'Email timing: Budgets' });
    expect(timing).toHaveValue('immediate');
    expect(
      within(timing).getByRole('option', { name: 'With your account setting (daily summary)' }),
    ).toBeInTheDocument();

    await user.selectOptions(timing, 'weekly');
    await user.click(main().getByRole('button', { name: 'Save preferences' }));

    expect(await screen.findByText('Notification preferences saved')).toBeInTheDocument();
    expect(patches).toEqual([
      { items: [{ category: 'budget', channel: 'email', digest: 'weekly' }] },
    ]);
    expect(main().getByRole('combobox', { name: 'Email timing: Budgets' })).toHaveValue('weekly');
  });

  it('keeps changes and explains a failed save', async () => {
    servePreferences();
    server.use(
      http.patch(`${API}/notifications/preferences`, () =>
        HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    await user.click(await main().findByRole('checkbox', { name: 'Browser: Trips' }));
    await user.click(main().getByRole('button', { name: 'Save preferences' }));
    expect(
      await main().findByText('Montra is temporarily unavailable. Try again in a moment.'),
    ).toBeInTheDocument();
    expect(main().getByRole('checkbox', { name: 'Browser: Trips' })).not.toBeChecked();
    await user.click(main().getByRole('button', { name: 'Undo changes' }));
    expect(main().getByRole('checkbox', { name: 'Browser: Trips' })).toBeChecked();
  });

  it('explains a refusal to turn off an always-on category', async () => {
    servePreferences();
    server.use(
      http.patch(`${API}/notifications/preferences`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.items[0].enabled',
                message: 'Security and account notifications cannot be turned off.',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    await user.click(await main().findByRole('checkbox', { name: 'Email: Goals' }));
    await user.click(main().getByRole('button', { name: 'Save preferences' }));
    expect(await main().findByRole('alert')).toHaveTextContent(
      'Security and account notifications are always on',
    );
  });

  it('shows an error with retry when preferences cannot be loaded', async () => {
    let fail = true;
    server.use(
      http.get(`${API}/notifications/preferences`, () =>
        fail
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope(makeNotificationPreferences())),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(
      await main().findByText('We couldn’t load your notification preferences'),
    ).toBeInTheDocument();
    fail = false;
    await user.click(main().getByRole('button', { name: 'Try again' }));
    expect(await main().findByRole('group', { name: 'Security' })).toBeInTheDocument();
  });
});

describe('NotificationSettingsPage: email summaries and quiet hours', () => {
  it('saves the summary email setting and quiet hours', async () => {
    servePreferences();
    const bodies: unknown[] = [];
    server.use(
      http.patch(`${API}/me/preferences`, async ({ request }) => {
        const body = (await request.json()) as Record<string, unknown>;
        bodies.push(body);
        testBackend.preferences = { ...testBackend.preferences, ...body };
        return HttpResponse.json(envelope(testBackend.preferences));
      }),
    );
    testBackend.preferences = makePreferences({ email_digest: 'off' });
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');

    const digest = await main().findByRole('group', { name: 'Optional emails' });
    await user.click(within(digest).getByRole('radio', { name: /Daily summary/ }));
    await user.click(main().getByRole('button', { name: 'Save email setting' }));
    expect(await screen.findByText('Email summary setting saved')).toBeInTheDocument();
    // With a summary chosen, "right away" categories follow it.
    expect(await main().findByText(/Your account setting is a daily summary/)).toBeInTheDocument();

    await user.click(
      main().getByRole('checkbox', { name: 'Pause notifications during quiet hours' }),
    );
    const from = main().getByLabelText('From');
    await user.clear(from);
    await user.type(from, '23:30');
    await user.click(main().getByRole('button', { name: 'Save quiet hours' }));
    expect(await screen.findByText('Quiet hours saved')).toBeInTheDocument();
    expect(bodies).toEqual([
      { email_digest: 'daily' },
      { quiet_hours_enabled: true, quiet_hours_start: '23:30', quiet_hours_end: '07:00' },
    ]);
  });
});

describe('NotificationSettingsPage: browser notifications', () => {
  beforeEach(() => {
    servePreferences();
  });

  it('says so when this browser cannot show notifications, but still lists devices', async () => {
    servePushEndpoints([
      makePushEndpoint({
        id: PHONE_ENDPOINT_ID,
        kind: 'fcm',
        device_label: undefined,
        current_session: false,
      }),
    ]);
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(await main().findByText('This browser can’t show notifications')).toBeInTheDocument();
    expect(
      main().queryByRole('button', { name: 'Turn on browser notifications' }),
    ).not.toBeInTheDocument();
    const devices = await main().findByRole('region', {
      name: 'Browsers and devices receiving notifications',
    });
    expect(within(devices).getByText('Phone app')).toBeInTheDocument();
    expect(within(devices).getByRole('button', { name: 'Remove Phone app' })).toBeInTheDocument();
  });

  it('says so when the server cannot send browser notifications', async () => {
    const push = installFakePush();
    uninstall = push.uninstall;
    servePushConfig({ available: false, vapid_public_key: undefined });
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(
      await main().findByText('Browser notifications aren’t available on this server'),
    ).toBeInTheDocument();
    expect(
      main().queryByRole('button', { name: 'Turn on browser notifications' }),
    ).not.toBeInTheDocument();
    expect(push.serviceWorker.register).not.toHaveBeenCalled();
  });

  it('shows an error with retry when the server cannot be asked', async () => {
    const push = installFakePush();
    uninstall = push.uninstall;
    let fail = true;
    server.use(
      http.get(`${API}/notifications/push-config`, () =>
        fail
          ? HttpResponse.json(errorBody({ code: 'SERVICE_UNAVAILABLE' }), { status: 503 })
          : HttpResponse.json(
              envelope({ web_push: { available: true, vapid_public_key: TEST_VAPID_KEY } }),
            ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(
      await main().findByText('We couldn’t check whether browser notifications are available'),
    ).toBeInTheDocument();
    fail = false;
    await user.click(main().getByRole('button', { name: 'Try again' }));
    expect(
      await main().findByRole('button', { name: 'Turn on browser notifications' }),
    ).toBeInTheDocument();
  });

  it('subscribes only after an explicit click, with the server key, and registers this browser', async () => {
    const push = installFakePush({ permission: 'default', answer: 'granted' });
    uninstall = push.uninstall;
    servePushConfig();
    const endpoints = servePushEndpoints([]);
    const bodies: unknown[] = [];
    server.use(
      http.post(`${API}/me/push-endpoints`, async ({ request }) => {
        bodies.push(await request.json());
        endpoints.endpoints = [makePushEndpoint()];
        return HttpResponse.json(envelope({ id: PUSH_ENDPOINT_ID }), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    const turnOn = await main().findByRole('button', { name: 'Turn on browser notifications' });
    expect(main().getByText('Off for this browser')).toBeInTheDocument();
    // Nothing is asked or registered until the user acts.
    expect(push.notification.requestPermission).not.toHaveBeenCalled();
    expect(push.serviceWorker.register).not.toHaveBeenCalled();

    await user.click(turnOn);
    expect(
      await screen.findByText('Browser notifications are on for this browser'),
    ).toBeInTheDocument();
    expect(await main().findByText('On for this browser')).toBeInTheDocument();
    expect(push.notification.requestPermission).toHaveBeenCalledTimes(1);
    expect(push.serviceWorker.register).toHaveBeenCalledWith('/push-sw.js', { scope: '/' });
    expect(push.pushManager.subscribe).toHaveBeenCalledTimes(1);
    const options = push.pushManager.subscribe.mock.calls[0]?.[0];
    expect(options).toMatchObject({ userVisibleOnly: true });
    expect(Array.from(options?.applicationServerKey ?? [])).toEqual(vapidBytes());
    expect(bodies).toEqual([
      {
        kind: 'webpush',
        subscription: {
          endpoint: 'https://fcm.googleapis.com/fcm/send/test-endpoint-1',
          expirationTime: null,
          keys: expect.objectContaining({ auth: 'tBHItJI5svbpez7KI4CCXg' }) as unknown,
        },
        device_label: expect.any(String) as unknown,
      },
    ]);
    // The new registration appears in the list as this browser.
    const devices = main().getByRole('region', {
      name: 'Browsers and devices receiving notifications',
    });
    expect(await within(devices).findByText('This browser')).toBeInTheDocument();
    expect(within(devices).getByText('Chrome on macOS')).toBeInTheDocument();
  });

  it('explains a denied permission and never subscribes', async () => {
    const push = installFakePush({ permission: 'default', answer: 'denied' });
    uninstall = push.uninstall;
    servePushConfig();
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    await user.click(await main().findByRole('button', { name: 'Turn on browser notifications' }));
    // Announced once (role=alert), with how to allow notifications again.
    const alert = await main().findByRole('alert');
    expect(alert).toHaveTextContent('Notifications are blocked in this browser');
    expect(alert).toHaveTextContent(/change the notification setting for this site/);
    await waitFor(() => {
      expect(
        main().queryByRole('button', { name: 'Turn on browser notifications' }),
      ).not.toBeInTheDocument();
    });
    expect(main().getAllByText('Notifications are blocked in this browser')).toHaveLength(1);
    expect(push.notification.requestPermission).toHaveBeenCalledTimes(1);
    expect(push.serviceWorker.register).not.toHaveBeenCalled();
    expect(push.pushManager.subscribe).not.toHaveBeenCalled();
  });

  it('shows how to unblock when the browser already blocks notifications', async () => {
    const push = installFakePush({ permission: 'denied' });
    uninstall = push.uninstall;
    servePushConfig();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(
      await main().findByText('Notifications are blocked in this browser'),
    ).toBeInTheDocument();
    expect(
      main().queryByRole('button', { name: 'Turn on browser notifications' }),
    ).not.toBeInTheDocument();
    expect(push.notification.requestPermission).not.toHaveBeenCalled();
  });

  it('starts a fresh subscription when this browser is registered to another account', async () => {
    const push = installFakePush({ permission: 'granted', subscribed: false });
    uninstall = push.uninstall;
    servePushConfig();
    const endpoints = servePushEndpoints([]);
    const registered: string[] = [];
    server.use(
      http.post(`${API}/me/push-endpoints`, async ({ request }) => {
        const body = (await request.json()) as { subscription: { endpoint: string } };
        registered.push(body.subscription.endpoint);
        if (registered.length === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'CONFLICT',
              message: 'This device is registered to another account.',
            }),
            { status: 409 },
          );
        }
        endpoints.endpoints = [makePushEndpoint()];
        return HttpResponse.json(envelope({ id: PUSH_ENDPOINT_ID }), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    await user.click(await main().findByRole('button', { name: 'Turn on browser notifications' }));
    expect(await main().findByText('On for this browser')).toBeInTheDocument();
    expect(registered).toEqual([
      'https://fcm.googleapis.com/fcm/send/test-endpoint-1',
      'https://fcm.googleapis.com/fcm/send/test-endpoint-2',
    ]);
    expect(push.state.unsubscribed).toEqual([
      'https://fcm.googleapis.com/fcm/send/test-endpoint-1',
    ]);
    // An already granted permission is not asked for again.
    expect(push.notification.requestPermission).not.toHaveBeenCalled();
  });

  it('undoes the browser subscription when Montra refuses the push service', async () => {
    const push = installFakePush({ permission: 'granted' });
    uninstall = push.uninstall;
    servePushConfig();
    server.use(
      http.post(`${API}/me/push-endpoints`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              { field: 'body.subscription', message: 'This push service is not supported.' },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    await user.click(await main().findByRole('button', { name: 'Turn on browser notifications' }));
    expect(
      await main().findByText(/can’t send notifications through this browser’s push service/),
    ).toBeInTheDocument();
    expect(push.state.subscription).toBeNull();
    expect(main().getByText('Off for this browser')).toBeInTheDocument();
  });

  it('turns off this browser: removes its listed registration and unsubscribes', async () => {
    const push = installFakePush({ permission: 'granted', subscribed: true });
    uninstall = push.uninstall;
    servePushConfig();
    const endpoints = servePushEndpoints([makePushEndpoint()]);
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(await main().findByText('On for this browser')).toBeInTheDocument();

    await user.click(main().getByRole('button', { name: 'Turn off for this browser' }));
    expect(
      await screen.findByText('Browser notifications are off for this browser'),
    ).toBeInTheDocument();
    expect(await main().findByText('Off for this browser')).toBeInTheDocument();
    expect(endpoints.deleted).toEqual([PUSH_ENDPOINT_ID]);
    expect(push.state.unsubscribed).toEqual([
      'https://fcm.googleapis.com/fcm/send/test-endpoint-1',
    ]);
    expect(push.notification.requestPermission).not.toHaveBeenCalled();
    // No registration is made just to learn an ID (the list carries it).
    expect(
      await main().findByText('No browser or device is registered for notifications.'),
    ).toBeInTheDocument();
  });

  it('notices a browser subscribed in an earlier session and offers to register it again', async () => {
    const push = installFakePush({ permission: 'granted', subscribed: true });
    uninstall = push.uninstall;
    servePushConfig();
    // Registrations end with the session: only an old browser is listed, not this session's.
    const endpoints = servePushEndpoints([
      makePushEndpoint({
        id: OLD_ENDPOINT_ID,
        device_label: 'Firefox on Linux',
        current_session: false,
        last_used_at: undefined,
      }),
    ]);
    const bodies: unknown[] = [];
    server.use(
      http.post(`${API}/me/push-endpoints`, async ({ request }) => {
        bodies.push(await request.json());
        endpoints.endpoints = [...endpoints.endpoints, makePushEndpoint()];
        return HttpResponse.json(envelope({ id: PUSH_ENDPOINT_ID }), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(
      await main().findByText('This browser needs to be registered again'),
    ).toBeInTheDocument();
    expect(main().getByText(/Browser notifications end with each sign-in/)).toBeInTheDocument();
    expect(main().queryByText('On for this browser')).not.toBeInTheDocument();

    await user.click(main().getByRole('button', { name: 'Register this browser again' }));

    expect(await main().findByText('On for this browser')).toBeInTheDocument();
    // The existing browser subscription is reused: no new prompt, no new subscription.
    expect(push.notification.requestPermission).not.toHaveBeenCalled();
    expect(push.pushManager.subscribe).not.toHaveBeenCalled();
    expect(bodies).toHaveLength(1);
    const devices = main().getByRole('region', {
      name: 'Browsers and devices receiving notifications',
    });
    expect(within(devices).getByText('Firefox on Linux')).toBeInTheDocument();
    expect(within(devices).getByText(/No notifications sent yet/)).toBeInTheDocument();
    expect(within(devices).getByText('This browser')).toBeInTheDocument();
  });

  it('offers to register again when the push service stopped delivering to this browser', async () => {
    const push = installFakePush({ permission: 'granted', subscribed: true });
    uninstall = push.uninstall;
    servePushConfig();
    servePushEndpoints([makePushEndpoint({ disabled_at: '2026-11-04T11:00:00Z' })]);
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(
      await main().findByText('This browser needs to be registered again'),
    ).toBeInTheDocument();
    expect(main().getByText(/The push service stopped delivering to this browser/)).toBeVisible();
    expect(main().getByRole('button', { name: 'Register this browser again' })).toBeInTheDocument();
    const devices = main().getByRole('region', {
      name: 'Browsers and devices receiving notifications',
    });
    expect(within(devices).getByText('Stopped')).toBeInTheDocument();
  });

  it('removes another browser or device after confirming', async () => {
    const push = installFakePush({ permission: 'granted', subscribed: true });
    uninstall = push.uninstall;
    servePushConfig();
    const endpoints = servePushEndpoints([
      makePushEndpoint(),
      makePushEndpoint({
        id: PHONE_ENDPOINT_ID,
        kind: 'fcm',
        device_label: 'Pixel 8',
        current_session: false,
      }),
    ]);
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    const devices = await main().findByRole('region', {
      name: 'Browsers and devices receiving notifications',
    });
    expect(await within(devices).findByText('Pixel 8')).toBeInTheDocument();
    // This browser is managed by the switch above, not removed from the list.
    expect(
      within(devices).queryByRole('button', { name: 'Remove Chrome on macOS' }),
    ).not.toBeInTheDocument();

    await user.click(within(devices).getByRole('button', { name: 'Remove Pixel 8' }));
    const dialog = await screen.findByRole('dialog', { name: 'Remove this browser or device?' });
    expect(dialog).toHaveTextContent('Pixel 8 will stop getting notifications');
    await user.click(within(dialog).getByRole('button', { name: 'Remove' }));

    expect(
      await screen.findByText('Removed. It won’t get notifications any more.'),
    ).toBeInTheDocument();
    expect(endpoints.deleted).toEqual([PHONE_ENDPOINT_ID]);
    await waitFor(() => {
      expect(within(devices).queryByText('Pixel 8')).not.toBeInTheDocument();
    });
    expect(main().getByText('On for this browser')).toBeInTheDocument();
  });

  it('shows an error with retry when the device list cannot be loaded', async () => {
    let fail = true;
    server.use(
      http.get(`${API}/me/push-endpoints`, () =>
        fail
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope([makePushEndpoint({ current_session: false })])),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/settings/notifications', { user: signedIn() });
    await findPageHeading('Notification settings');
    expect(
      await main().findByText('We couldn’t load your browsers and devices'),
    ).toBeInTheDocument();
    fail = false;
    await user.click(main().getByRole('button', { name: 'Try again' }));
    expect(await main().findByText('Chrome on macOS')).toBeInTheDocument();
  });
});
