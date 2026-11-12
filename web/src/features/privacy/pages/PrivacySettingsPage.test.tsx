import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Consent, Deletion, ExportJob, Legal, Limits } from '@/features/privacy/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import {
  EXPORT_FILE_ID,
  EXPORT_ID,
  completedExport,
  makeConsent,
  makeDeletion,
  makeExportAccess,
  makeExportJob,
  makeLegal,
  makeLimits,
  requiredConsents,
  scheduledDeletion,
} from '@/tests/privacyFixtures';
import { findPageHeading, renderRoute } from '@/tests/render';

const user = () => makeUser({ onboarding_completed: true });

interface PrivacyState {
  consents?: Consent[];
  deletion?: Deletion;
  limits?: Limits;
  /** GET /me/exports, newest first. */
  exports?: ExportJob[];
  legal?: Legal;
}

/** The page's reads; writes are declared by each test. */
function servePrivacy(state: PrivacyState = {}) {
  const current = {
    consents: state.consents ?? requiredConsents(),
    deletion: state.deletion ?? makeDeletion(),
    limits: state.limits ?? makeLimits(),
    exports: state.exports ?? [],
    legal: state.legal ?? makeLegal(),
    legalReads: 0,
  };
  server.use(
    http.get(`${API}/me/consents`, ({ request }) => {
      const history = new URL(request.url).searchParams.get('history') === 'true';
      return HttpResponse.json(
        envelope(history ? current.consents : current.consents.filter((c) => !c.revoked_at)),
      );
    }),
    http.get(`${API}/me/deletion-request`, () => HttpResponse.json(envelope(current.deletion))),
    http.get(`${API}/limits`, () => HttpResponse.json(envelope(current.limits))),
    http.get(`${API}/me/exports`, () => HttpResponse.json(envelope(current.exports))),
    http.get(`${API}/legal`, () => {
      current.legalReads += 1;
      return HttpResponse.json(envelope(current.legal));
    }),
  );
  return current;
}

const reauthRequired = () =>
  HttpResponse.json(
    errorBody({ code: 'REAUTH_REQUIRED', message: 'Confirm your password to continue.' }),
    { status: 401 },
  );

async function openPrivacy(path = '/settings/privacy') {
  const events = userEvent.setup();
  const view = renderRoute(path, { user: user() });
  await findPageHeading('Privacy & data');
  return { events, ...view };
}

async function reauthenticate(events: ReturnType<typeof userEvent.setup>) {
  const dialog = await screen.findByRole('dialog', { name: 'Confirm it’s you' });
  await events.type(within(dialog).getByLabelText('Password'), 'quiet-harbor-71');
  await events.click(within(dialog).getByRole('button', { name: 'Confirm' }));
}

beforeAll(async () => {
  await import('./PrivacySettingsPage');
});

beforeEach(() => {
  // Export expiry and deletion dates are compared with "now".
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-11-05T06:00:00Z'));
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('PrivacySettingsPage: consents', () => {
  it('explains each optional choice and shows the consents needed to use Montra', async () => {
    servePrivacy({ consents: [...requiredConsents(), makeConsent()] });
    await openPrivacy();
    const choices = screen.getByRole('region', { name: 'Your choices' });

    const location = (
      await within(choices).findByRole('heading', { name: 'Location on transactions' })
    ).closest('li')!;
    expect(within(location).getByText('On')).toBeInTheDocument();
    expect(
      within(location).getByText(
        'Lets you save a place name with a transaction, like the shop where you paid.',
      ),
    ).toBeInTheDocument();
    expect(
      within(location).getByText('Allowed Nov 2, 2026, 1:30 PM · wording version 2026-11-01'),
    ).toBeInTheDocument();
    expect(
      within(location).getByRole('button', { name: 'Withdraw: Location on transactions' }),
    ).toBeInTheDocument();

    const marketing = within(choices)
      .getByRole('heading', { name: 'Product news by email' })
      .closest('li')!;
    expect(within(marketing).getByText('Off')).toBeInTheDocument();
    expect(within(marketing).getByText(/Montra doesn’t send product news today/)).toBeVisible();
    expect(
      within(choices)
        .getByRole('heading', { name: 'Push notifications' })
        .closest('li')!
        .querySelector('a[href="/settings/notifications"]'),
    ).not.toBeNull();

    // AI consents are not offered on the web portal.
    expect(within(choices).queryByRole('heading', { name: 'AI features' })).not.toBeInTheDocument();

    expect(within(choices).getByRole('link', { name: 'Terms of use' })).toHaveAttribute(
      'href',
      '/terms',
    );
    expect(
      within(choices).getAllByText('Accepted Oct 1, 2026, 2:00 PM · version 2026-11-01'),
    ).toHaveLength(2);
    expect(
      within(choices).getByText(
        'You accepted these when you signed up. To withdraw them, delete your account below.',
      ),
    ).toBeInTheDocument();
  });

  it('gives and withdraws a consent with the wording version from GET /legal', async () => {
    const legal = makeLegal();
    legal.consents = legal.consents.map((consent) =>
      consent.type === 'location' ? { ...consent, version: '2026-11-20' } : consent,
    );
    const state = servePrivacy({ legal });
    const writes: { method: string; path: string; body: unknown }[] = [];
    server.use(
      http.post(`${API}/me/consents`, async ({ request }) => {
        const body = (await request.json()) as { consent_type: string; version: string };
        writes.push({ method: 'POST', path: '/me/consents', body });
        state.consents = [
          ...state.consents,
          makeConsent({ consent_type: body.consent_type, version: body.version }),
        ];
        return HttpResponse.json(envelope(state.consents.at(-1)), { status: 201 });
      }),
      http.delete(`${API}/me/consents/:type`, ({ params }) => {
        writes.push({ method: 'DELETE', path: `/me/consents/${String(params.type)}`, body: null });
        state.consents = state.consents.filter((c) => c.consent_type !== params.type);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { events } = await openPrivacy();
    await events.click(
      await screen.findByRole('button', { name: 'Allow: Location on transactions' }),
    );
    expect(await screen.findByText('Location on transactions: allowed')).toBeVisible();
    await events.click(
      await screen.findByRole('button', { name: 'Withdraw: Location on transactions' }),
    );
    expect(await screen.findByText('Location on transactions: consent withdrawn')).toBeVisible();
    expect(
      await screen.findByRole('button', { name: 'Allow: Location on transactions' }),
    ).toBeInTheDocument();
    expect(writes).toEqual([
      {
        method: 'POST',
        path: '/me/consents',
        body: { consent_type: 'location', version: '2026-11-20' },
      },
      { method: 'DELETE', path: '/me/consents/location', body: null },
    ]);
  });

  it('explains when the API expects a newer consent wording, then sends the new version', async () => {
    const state = servePrivacy();
    const sent: string[] = [];
    server.use(
      http.post(`${API}/me/consents`, async ({ request }) => {
        const body = (await request.json()) as { consent_type: string; version: string };
        sent.push(body.version);
        if (body.version === '2026-12-01') {
          return HttpResponse.json(envelope(makeConsent(body)), { status: 201 });
        }
        // The wording changed after the page loaded GET /legal.
        state.legal = makeLegal({
          consents: makeLegal().consents.map((consent) => ({ ...consent, version: '2026-12-01' })),
        });
        return HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [
              {
                field: 'body.version',
                message: 'Review the latest version (2026-12-01) before consenting.',
              },
            ],
          }),
          { status: 422 },
        );
      }),
    );
    const { events } = await openPrivacy();
    await events.click(await screen.findByRole('button', { name: 'Allow: Push notifications' }));
    expect(await screen.findByText('Push notifications didn’t change')).toBeVisible();
    expect(
      screen.getByText(
        'Montra just updated the wording of this consent. Try again to agree to the latest version.',
      ),
    ).toBeVisible();
    await events.click(screen.getByRole('button', { name: 'Allow: Push notifications' }));
    expect(await screen.findByText('Push notifications: allowed')).toBeVisible();
    expect(sent).toEqual(['2026-11-01', '2026-12-01']);
    expect(state.legalReads).toBe(2);
  });

  it('lists an AI consent given elsewhere so it can be withdrawn', async () => {
    servePrivacy({
      consents: [...requiredConsents(), makeConsent({ consent_type: 'ai_processing' })],
    });
    let revoked: string | null = null;
    server.use(
      http.delete(`${API}/me/consents/:type`, ({ params }) => {
        revoked = String(params.type);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { events } = await openPrivacy();
    const ai = (await screen.findByRole('heading', { name: 'AI features' })).closest('li')!;
    expect(within(ai).getByText(/You allowed this in another Montra app\./)).toBeVisible();
    expect(within(ai).queryByRole('button', { name: /^Allow/ })).not.toBeInTheDocument();
    await events.click(within(ai).getByRole('button', { name: 'Withdraw: AI features' }));
    await waitFor(() => {
      expect(revoked).toBe('ai_processing');
    });
  });

  it('shows the consent history on request', async () => {
    servePrivacy({
      consents: [
        ...requiredConsents(),
        makeConsent({ revoked_at: '2026-11-03T10:00:00Z', granted_at: '2026-11-02T08:00:00Z' }),
      ],
    });
    const { events } = await openPrivacy();
    await events.click(await screen.findByRole('button', { name: 'Show consent history' }));
    const table = await screen.findByRole('table', { name: 'Consent history' });
    const row = within(table).getByRole('row', { name: /Location on transactions/ });
    expect(within(row).getByText('Nov 3, 2026, 3:30 PM')).toBeInTheDocument();
    expect(within(table).getAllByText('Still on')).toHaveLength(2);
  });

  it('offers a retry when the choices cannot be loaded', async () => {
    servePrivacy();
    let calls = 0;
    server.use(
      http.get(`${API}/me/consents`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope(requiredConsents()));
      }),
    );
    const { events } = await openPrivacy();
    const choices = screen.getByRole('region', { name: 'Your choices' });
    expect(await within(choices).findByText('We couldn’t load your choices')).toBeVisible();
    await events.click(within(choices).getByRole('button', { name: 'Try again' }));
    expect(
      await within(choices).findByRole('heading', { name: 'Location on transactions' }),
    ).toBeVisible();
  });
});

describe('PrivacySettingsPage: data export', () => {
  it('asks for the password when the API requires it, then follows the export', async () => {
    servePrivacy();
    const posts: number[] = [];
    let reauthBody: unknown = null;
    let reauthenticated = false;
    server.use(
      http.post(`${API}/me/export`, () => {
        posts.push(posts.length + 1);
        if (!reauthenticated) return reauthRequired();
        return HttpResponse.json(envelope(makeExportJob()), { status: 202 });
      }),
      http.post(`${API}/auth/reauthenticate`, async ({ request }) => {
        reauthBody = await request.json();
        reauthenticated = true;
        return HttpResponse.json(envelope({ ok: true }));
      }),
      http.get(`${API}/me/export/:id`, () => HttpResponse.json(envelope(makeExportJob()))),
    );
    const { events, router } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Download your data' });
    expect(
      await within(card).findByText('The download stays available for 7 days after it’s ready.'),
    ).toBeInTheDocument();
    await events.click(within(card).getByRole('button', { name: 'Request my data' }));
    await reauthenticate(events);

    expect(await within(card).findByText('Your export is waiting to start')).toBeVisible();
    expect(screen.getByText('Export requested')).toBeVisible();
    expect(reauthBody).toEqual({ password: 'quiet-harbor-71' });
    expect(posts).toHaveLength(2);
    // Only the export's ID goes into the address, so a reload keeps following it.
    expect(router.state.location.search).toBe(`?export=${EXPORT_ID}`);
  });

  it('polls a running export until it is ready, and announces it', async () => {
    servePrivacy();
    let checks = 0;
    server.use(
      http.get(`${API}/me/export/:id`, () => {
        checks += 1;
        return HttpResponse.json(
          envelope(checks === 1 ? makeExportJob({ status: 'running' }) : completedExport()),
        );
      }),
    );
    await openPrivacy(`/settings/privacy?export=${EXPORT_ID}`);
    const card = screen.getByRole('region', { name: 'Download your data' });
    expect(await within(card).findByText('Preparing your export')).toBeVisible();
    // The next check comes about 2 seconds later.
    expect(
      await within(card).findByRole('button', { name: 'Download ZIP' }, { timeout: 5_000 }),
    ).toBeVisible();
    expect(screen.getAllByText('Your export is ready')).toHaveLength(2);
    expect(checks).toBe(2);
  });

  it('does nothing when the password prompt is cancelled', async () => {
    servePrivacy();
    let posts = 0;
    server.use(
      http.post(`${API}/me/export`, () => {
        posts += 1;
        return reauthRequired();
      }),
    );
    const { events, router } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Download your data' });
    await events.click(await within(card).findByRole('button', { name: 'Request my data' }));
    const dialog = await screen.findByRole('dialog', { name: 'Confirm it’s you' });
    await events.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(within(card).queryByRole('alert')).not.toBeInTheDocument();
    expect(posts).toBe(1);
    expect(router.state.location.search).toBe('');
  });

  it('downloads a ready export through a short-lived link', async () => {
    servePrivacy();
    const contentRequests: URL[] = [];
    server.use(
      http.get(`${API}/me/export/:id`, () => HttpResponse.json(envelope(completedExport()))),
      http.get(`${API}/files/:fileId/access`, ({ params }) => {
        expect(params.fileId).toBe(EXPORT_FILE_ID);
        return HttpResponse.json(envelope(makeExportAccess()));
      }),
      http.get(`${API}/files/:fileId/content`, ({ request }) => {
        contentRequests.push(new URL(request.url));
        return new HttpResponse('PK-zip-bytes', { headers: { 'Content-Type': 'application/zip' } });
      }),
    );
    const blobs: Blob[] = [];
    const names: string[] = [];
    Object.assign(URL, {
      createObjectURL: vi.fn((blob: Blob) => {
        blobs.push(blob);
        return 'blob:export';
      }),
      revokeObjectURL: vi.fn(),
    });
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (
      this: HTMLAnchorElement,
    ) {
      names.push(this.download);
    });
    const { events } = await openPrivacy(`/settings/privacy?export=${EXPORT_ID}`);
    const card = screen.getByRole('region', { name: 'Download your data' });
    expect(await within(card).findByText('Your export is ready')).toBeVisible();
    expect(
      within(card).getByText('You can download it until Nov 12, 2026, 11:29 AM.'),
    ).toBeVisible();
    await events.click(within(card).getByRole('button', { name: 'Download ZIP' }));

    expect(await screen.findByText('Download started')).toBeVisible();
    expect(names).toEqual(['montra-export-20261105.zip']);
    expect(await blobs[0]!.text()).toBe('PK-zip-bytes');
    const url = contentRequests[0]!;
    expect(url.pathname).toBe(`/api/v1/files/${EXPORT_FILE_ID}/content`);
    expect([...url.searchParams.keys()].sort()).toEqual(['exp', 'sig', 'sub']);
  });

  it('explains an expired download link', async () => {
    servePrivacy();
    server.use(
      http.get(`${API}/me/export/:id`, () => HttpResponse.json(envelope(completedExport()))),
      http.get(`${API}/files/:fileId/access`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    const { events } = await openPrivacy(`/settings/privacy?export=${EXPORT_ID}`);
    const card = screen.getByRole('region', { name: 'Download your data' });
    await events.click(await within(card).findByRole('button', { name: 'Download ZIP' }));
    expect(await screen.findByText('The download didn’t start')).toBeVisible();
    expect(
      screen.getByText('This download is no longer available. Request a new export.'),
    ).toBeVisible();
  });

  it.each<[string, ExportJob, string]>([
    [
      'failed',
      makeExportJob({ status: 'failed', error_code: 'export_failed' }),
      'We couldn’t prepare your export',
    ],
    ['expired', makeExportJob({ status: 'expired' }), 'This export has expired'],
    [
      'past its download window',
      completedExport({ expires_at: '2026-11-04T05:59:00Z' }),
      'This export has expired',
    ],
  ])('explains an export that is %s and offers a new one', async (_label, job, title) => {
    servePrivacy();
    server.use(http.get(`${API}/me/export/:id`, () => HttpResponse.json(envelope(job))));
    await openPrivacy(`/settings/privacy?export=${EXPORT_ID}`);
    const card = screen.getByRole('region', { name: 'Download your data' });
    expect(await within(card).findByText(title)).toBeVisible();
    expect(within(card).queryByRole('button', { name: 'Download ZIP' })).not.toBeInTheDocument();
    expect(
      within(card).getByRole('button', { name: /Try again|Request a new export/ }),
    ).toBeInTheDocument();
  });
});

describe('PrivacySettingsPage: deactivation and deletion', () => {
  it('deactivates after confirmation and the password, then signs out', async () => {
    servePrivacy();
    let deactivated = 0;
    let reauthenticated = false;
    server.use(
      http.post(`${API}/me/deactivate`, () => {
        if (!reauthenticated) return reauthRequired();
        deactivated += 1;
        return HttpResponse.json(envelope({ ok: true }));
      }),
      http.post(`${API}/auth/reauthenticate`, () => {
        reauthenticated = true;
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const { events } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Take a break' });
    await events.click(within(card).getByRole('button', { name: 'Deactivate account' }));
    const confirm = await screen.findByRole('dialog', { name: 'Deactivate your account?' });
    expect(deactivated).toBe(0);
    await events.click(within(confirm).getByRole('button', { name: 'Deactivate' }));
    await reauthenticate(events);

    await findPageHeading('Sign in');
    expect(screen.getByText('Your account is deactivated')).toBeVisible();
    expect(deactivated).toBe(1);
  });

  it('shows the API’s disclosure, schedules deletion with the typed word, then cancels it', async () => {
    const state = servePrivacy();
    const posted: unknown[] = [];
    let reauthenticated = false;
    let cancels = 0;
    server.use(
      http.post(`${API}/me/deletion-request`, async ({ request }) => {
        posted.push(await request.json());
        if (!reauthenticated) return reauthRequired();
        state.deletion = scheduledDeletion();
        return HttpResponse.json(envelope(state.deletion));
      }),
      http.post(`${API}/auth/reauthenticate`, () => {
        reauthenticated = true;
        return HttpResponse.json(envelope({ ok: true }));
      }),
      http.delete(`${API}/me/deletion-request`, () => {
        cancels += 1;
        state.deletion = makeDeletion({ ...scheduledDeletion(), status: 'cancelled' });
        return HttpResponse.json(envelope(state.deletion));
      }),
    );
    const { events } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Delete your account' });
    expect(
      await within(card).findByText(
        'Your account is deleted 7 days after you confirm. You can cancel at any time before then, and everything stays as it is.',
      ),
    ).toBeVisible();
    // Localized by consequence_codes, retained_codes and group_impact_details.
    expect(
      within(card).getByText('Files you uploaded will be removed from storage.'),
    ).toBeVisible();
    expect(
      within(card).getByText(
        'Ownership of “Flat 4B” will pass to its longest-standing admin or member.',
      ),
    ).toBeVisible();
    expect(within(card).getByText(/your name is replaced with “Deleted member”/)).toBeVisible();
    expect(
      within(card).queryByText(
        'Some of these details come from Montra’s servers and are shown in English.',
      ),
    ).not.toBeInTheDocument();

    await events.click(within(card).getByRole('button', { name: 'Delete my account…' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete your account?' });
    expect(
      within(dialog).getByText('It will be deleted 7 days from now unless you cancel.'),
    ).toBeVisible();
    await events.type(within(dialog).getByLabelText('Type DELETE to confirm'), 'delete');
    await events.type(within(dialog).getByLabelText(/Why are you leaving\?/), 'Moving on');
    await events.click(within(dialog).getByRole('button', { name: 'Schedule deletion' }));
    await reauthenticate(events);

    expect(await within(card).findByText('Your account is scheduled for deletion')).toBeVisible();
    expect(
      within(card).getByText(
        'It will be deleted on Nov 12, 2026, 11:30 AM. Until then you can cancel, and everything stays as it is.',
      ),
    ).toBeVisible();
    expect(
      screen.getByText(
        'Your account will be deleted on November 12, 2026. You can cancel until then.',
      ),
    ).toBeVisible();
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(posted).toEqual([
      { confirm: 'DELETE', reason: 'Moving on' },
      { confirm: 'DELETE', reason: 'Moving on' },
    ]);

    await events.click(within(card).getByRole('button', { name: 'Cancel deletion' }));
    expect(await screen.findByText('Deletion cancelled')).toBeVisible();
    expect(await within(card).findByRole('button', { name: 'Delete my account…' })).toBeVisible();
    expect(cancels).toBe(1);
  });

  it('does not schedule deletion without the typed word', async () => {
    servePrivacy();
    let posts = 0;
    server.use(
      http.post(`${API}/me/deletion-request`, () => {
        posts += 1;
        return HttpResponse.json(envelope(scheduledDeletion()));
      }),
    );
    const { events } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Delete your account' });
    await events.click(await within(card).findByRole('button', { name: 'Delete my account…' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete your account?' });
    const field = within(dialog).getByLabelText('Type DELETE to confirm');
    await events.type(field, 'remove');
    await events.click(within(dialog).getByRole('button', { name: 'Schedule deletion' }));
    await waitFor(() => {
      expect(field).toHaveAccessibleDescription(/Type DELETE exactly as shown\./);
    });
    await events.click(within(dialog).getByRole('button', { name: 'Keep my account' }));
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(posts).toBe(0);
  });

  it('shows a deletion already scheduled, and one that has started', async () => {
    servePrivacy({ deletion: scheduledDeletion() });
    const first = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Delete your account' });
    expect(await within(card).findByRole('button', { name: 'Cancel deletion' })).toBeVisible();
    expect(
      within(card).getByText('If you want a copy of your data, download an export before then.'),
    ).toBeVisible();
    first.unmount();

    servePrivacy({ deletion: scheduledDeletion({ status: 'processing' }) });
    await openPrivacy();
    expect(await screen.findByText('Your account is being deleted')).toBeVisible();
    expect(screen.queryByRole('button', { name: 'Delete my account…' })).not.toBeInTheDocument();
  });

  it('explains a deletion already scheduled elsewhere and a confirmation the API refused', async () => {
    servePrivacy();
    const answers = [
      {
        status: 422,
        body: errorBody({
          code: 'VALIDATION_ERROR',
          details: [
            {
              field: 'body.confirm',
              message: 'Type DELETE to confirm.',
              code: 'confirm_word_mismatch',
              params: { word: 'DELETE' },
            },
          ],
        }),
      },
      {
        status: 409,
        body: errorBody({
          code: 'CONFLICT',
          message: 'A deletion request is already scheduled.',
          details: [
            {
              message: 'A deletion request is already scheduled.',
              code: 'deletion_already_scheduled',
            },
          ],
        }),
      },
    ];
    const posted: unknown[] = [];
    server.use(
      http.post(`${API}/me/deletion-request`, async ({ request }) => {
        posted.push(await request.json());
        const answer = answers[posted.length - 1] ?? answers[1];
        return HttpResponse.json(answer?.body, { status: answer?.status });
      }),
    );
    const { events } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Delete your account' });
    await events.click(await within(card).findByRole('button', { name: 'Delete my account…' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete your account?' });
    const field = within(dialog).getByLabelText('Type DELETE to confirm');
    await events.type(field, 'DELETE');
    await events.click(within(dialog).getByRole('button', { name: 'Schedule deletion' }));
    // 422 confirm_word_mismatch names the word to type ({word}).
    await waitFor(() => {
      expect(field).toHaveAccessibleDescription(/Type DELETE exactly as shown\./);
    });

    await events.click(within(dialog).getByRole('button', { name: 'Schedule deletion' }));
    // 409 deletion_already_scheduled: the page shows the current state.
    expect(
      await within(dialog).findByText('A deletion is already scheduled. The page now shows it.'),
    ).toBeVisible();
    expect(posted).toEqual([{ confirm: 'DELETE' }, { confirm: 'DELETE' }]);
  });

  it('explains a cancel that finds nothing to cancel', async () => {
    const state = servePrivacy({ deletion: scheduledDeletion() });
    server.use(
      http.delete(`${API}/me/deletion-request`, () => {
        state.deletion = makeDeletion();
        return HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            message: 'There is no scheduled deletion to cancel.',
            details: [
              {
                message: 'There is no scheduled deletion to cancel.',
                code: 'no_deletion_scheduled',
              },
            ],
          }),
          { status: 409 },
        );
      }),
    );
    const { events } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Delete your account' });
    await events.click(await within(card).findByRole('button', { name: 'Cancel deletion' }));
    expect(await within(card).findByText('There’s no scheduled deletion to cancel.')).toBeVisible();
    expect(await within(card).findByRole('button', { name: 'Delete my account…' })).toBeVisible();
  });

  it('offers a retry when the deletion status cannot be loaded', async () => {
    servePrivacy();
    let calls = 0;
    server.use(
      http.get(`${API}/me/deletion-request`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope(makeDeletion()));
      }),
    );
    const { events } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Delete your account' });
    expect(await within(card).findByText('We couldn’t check your deletion status')).toBeVisible();
    await events.click(within(card).getByRole('button', { name: 'Try again' }));
    expect(await within(card).findByRole('button', { name: 'Delete my account…' })).toBeVisible();
  });
});

describe('PrivacySettingsPage: exports list (GET /me/exports)', () => {
  const OLDER_ID = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
  const OLDER_FILE_ID = '2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e';

  it('follows the newest export and lists earlier ones with their downloads', async () => {
    const newest = completedExport();
    const older = completedExport({
      id: OLDER_ID,
      file_id: OLDER_FILE_ID,
      requested_at: '2026-11-04T06:00:00Z',
      completed_at: '2026-11-04T06:01:00Z',
      expires_at: '2026-11-11T06:01:00Z',
    });
    const expired = makeExportJob({
      id: '3c4d5e6f-7a8b-4c9d-8e0f-2a3b4c5d6e7f',
      status: 'expired',
      requested_at: '2026-10-20T06:00:00Z',
    });
    servePrivacy({ exports: [newest, older, expired] });
    const accessed: string[] = [];
    server.use(
      http.get(`${API}/me/export/:id`, ({ params }) => {
        expect(params.id).toBe(EXPORT_ID);
        return HttpResponse.json(envelope(newest));
      }),
      http.get(`${API}/files/:fileId/access`, ({ params }) => {
        accessed.push(String(params.fileId));
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }),
    );
    const { events, router } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Download your data' });
    // No ?export= in the address: the newest export from the list is shown.
    expect(await within(card).findByText('Your export is ready')).toBeVisible();
    expect(router.state.location.search).toBe('');

    const history = within(card).getByRole('heading', { name: 'Earlier exports' }).parentElement!;
    const rows = within(history).getAllByRole('listitem');
    expect(rows).toHaveLength(2);
    expect(within(rows[0]!).getByText('Ready to download')).toBeVisible();
    expect(within(rows[0]!).getByText('Requested Nov 4, 2026, 11:30 AM')).toBeVisible();
    expect(within(rows[1]!).getByText('No longer available')).toBeVisible();
    expect(within(rows[1]!).queryByRole('button')).not.toBeInTheDocument();

    await events.click(
      within(rows[0]!).getByRole('button', {
        name: 'Download the export requested Nov 4, 2026, 11:30 AM',
      }),
    );
    expect(await screen.findByText('The download didn’t start')).toBeVisible();
    expect(accessed).toEqual([OLDER_FILE_ID]);
  });

  it('offers a first export when the list is empty, and a retry when it fails', async () => {
    servePrivacy();
    let calls = 0;
    server.use(
      http.get(`${API}/me/exports`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope([]));
      }),
    );
    const { events } = await openPrivacy();
    const card = screen.getByRole('region', { name: 'Download your data' });
    expect(await within(card).findByText('We couldn’t load your exports')).toBeVisible();
    await events.click(within(card).getByRole('button', { name: 'Try again' }));
    expect(await within(card).findByRole('button', { name: 'Request my data' })).toBeVisible();
    expect(
      within(card).queryByRole('heading', { name: 'Earlier exports' }),
    ).not.toBeInTheDocument();
  });
});

describe('PrivacySettingsPage: deletion disclosure codes', () => {
  it('shows sentences with unknown codes as the API sent them, marked as English', async () => {
    servePrivacy({
      deletion: makeDeletion({
        consequences: ['A brand new consequence.'],
        consequence_codes: ['brand_new_consequence'],
        group_impact: ['"Trip" has no other members and will be deleted.'],
        group_impact_details: [
          {
            code: 'group_deleted',
            params: { group_id: 'g1', group_name: 'Trip', outcome: 'deleted' },
            text: '"Trip" has no other members and will be deleted.',
          },
        ],
      }),
    });
    await openPrivacy();
    const card = screen.getByRole('region', { name: 'Delete your account' });
    const unknown = await within(card).findByText('A brand new consequence.');
    expect(unknown).toHaveAttribute('lang', 'en');
    expect(
      within(card).getByText('“Trip” has no other members, so it will be deleted.'),
    ).toBeVisible();
    expect(
      within(card).getByText(
        'Some of these details come from Montra’s servers and are shown in English.',
      ),
    ).toBeVisible();
  });
});
