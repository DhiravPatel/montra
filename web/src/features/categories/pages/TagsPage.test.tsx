import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { TAG_HOME, TAG_TRIP, makeTagRecord } from '@/tests/categoriesFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

const trip = makeTagRecord({
  id: TAG_TRIP,
  name: 'goa trip',
  usage_count: 0,
  color: '#2563EB',
  archived_at: '2026-10-01T00:00:00Z',
});

describe('TagsPage', () => {
  it('lists active tags with usage that links to their transactions', async () => {
    testBackend.tags = [makeTagRecord(), trip];
    const user = userEvent.setup();
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');

    const usage = await screen.findByRole('link', { name: 'Used on 3 transactions' });
    expect(usage).toHaveAttribute('href', `/transactions?tag_id=${TAG_HOME}&range=all`);
    expect(screen.queryByText('goa trip')).not.toBeInTheDocument();

    await user.click(screen.getByLabelText('Show archived'));
    expect(screen.getByText('goa trip')).toBeInTheDocument();
    expect(screen.getByText('Not used yet')).toBeInTheDocument();
    expect(screen.getByText('Archived')).toBeInTheDocument();
  });

  it('creates a tag and explains a duplicate name', async () => {
    const bodies: unknown[] = [];
    server.use(
      http.post(`${API}/tags`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'CONFLICT',
              details: [
                {
                  message: 'A tag with this name already exists.',
                  code: 'name_taken',
                  params: { name: 'home' },
                },
              ],
            }),
            { status: 409 },
          );
        }
        return HttpResponse.json(envelope(makeTagRecord({ name: 'work trip' })), {
          status: 201,
        });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');
    expect(await screen.findByText('No tags yet')).toBeInTheDocument();
    await user.click(screen.getAllByRole('button', { name: 'Add tag' })[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Add a tag' });
    await user.type(within(dialog).getByLabelText('Name'), 'home');
    await user.click(within(dialog).getByRole('button', { name: 'Add tag' }));
    expect(
      await within(dialog).findByText('You already have a tag with this name.'),
    ).toBeInTheDocument();

    const name = within(dialog).getByLabelText('Name');
    await user.clear(name);
    await user.type(name, 'work trip');
    await user.click(within(dialog).getByRole('radio', { name: 'Blue' }));
    await user.click(within(dialog).getByRole('button', { name: 'Add tag' }));
    expect(await screen.findByText('Tag added')).toBeInTheDocument();
    expect(bodies).toEqual([{ name: 'home' }, { name: 'work trip', color: '#2563EB' }]);
  });

  it('renames a tag, sending only what changed with its version', async () => {
    testBackend.tags = [makeTagRecord({ color: '#16A34A' })];
    let patched: unknown;
    server.use(
      http.patch(`${API}/tags/:id`, async ({ request }) => {
        patched = await request.json();
        return HttpResponse.json(envelope(makeTagRecord({ name: 'house', version: 2 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');
    await user.click(await screen.findByRole('button', { name: 'Edit: home' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit tag' });
    expect(within(dialog).getByRole('radio', { name: 'Green' })).toBeChecked();
    const name = within(dialog).getByLabelText('Name');
    await user.clear(name);
    await user.type(name, 'house');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Tag updated')).toBeInTheDocument();
    expect(patched).toEqual({ version: 1, name: 'house' });
  });

  it('removes a tag’s color', async () => {
    testBackend.tags = [makeTagRecord({ color: '#16A34A' })];
    let patched: unknown;
    server.use(
      http.patch(`${API}/tags/:id`, async ({ request }) => {
        patched = await request.json();
        return HttpResponse.json(envelope(makeTagRecord({ version: 2 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');
    await user.click(await screen.findByRole('button', { name: 'Edit: home' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit tag' });
    await user.click(within(dialog).getByRole('radio', { name: 'No color' }));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Tag updated')).toBeInTheDocument();
    expect(patched).toEqual({ version: 1, clear_color: true });
  });

  it('reloads the tag after a version conflict', async () => {
    testBackend.tags = [makeTagRecord()];
    const bodies: unknown[] = [];
    const reloads: string[] = [];
    server.use(
      // The dialog reloads the one tag after the conflict (GET /tags/{id}).
      http.get(`${API}/tags/:id`, ({ params }) => {
        reloads.push(String(params.id));
        return HttpResponse.json(envelope(testBackend.tags.find((tag) => tag.id === params.id)));
      }),
      http.patch(`${API}/tags/:id`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          // Someone renamed it meanwhile.
          testBackend.tags = [makeTagRecord({ name: 'household', version: 2 })];
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeTagRecord({ name: 'house', version: 3 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');
    await user.click(await screen.findByRole('button', { name: 'Edit: home' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit tag' });
    const name = within(dialog).getByLabelText('Name');
    await user.clear(name);
    await user.type(name, 'house');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));

    expect(await within(dialog).findByText('This was changed somewhere else')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Name')).toHaveValue('household');
    });
    const reloaded = within(dialog).getByLabelText('Name');
    await user.clear(reloaded);
    await user.type(reloaded, 'house');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Tag updated')).toBeInTheDocument();
    expect(bodies).toEqual([
      { version: 1, name: 'house' },
      { version: 2, name: 'house' },
    ]);
    expect(reloads).toEqual([TAG_HOME]);
  });

  it('archives and unarchives tags', async () => {
    testBackend.tags = [makeTagRecord(), trip];
    const bodies: unknown[] = [];
    server.use(
      http.patch(`${API}/tags/:id`, async ({ params, request }) => {
        bodies.push({ id: params.id, body: await request.json() });
        return HttpResponse.json(envelope(makeTagRecord()));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');
    await user.click(await screen.findByRole('button', { name: 'Archive: home' }));
    expect(
      await screen.findByText('Tag archived. It stays on past transactions.'),
    ).toBeInTheDocument();
    await user.click(screen.getByLabelText('Show archived'));
    await user.click(screen.getByRole('button', { name: 'Unarchive: goa trip' }));
    expect(await screen.findByText('Tag is active again')).toBeInTheDocument();
    expect(bodies).toEqual([
      { id: TAG_HOME, body: { archived: true, version: 1 } },
      { id: TAG_TRIP, body: { archived: false, version: 1 } },
    ]);
  });

  it('deletes a tag after confirming how many transactions lose it', async () => {
    testBackend.tags = [makeTagRecord()];
    let deleted = '';
    server.use(
      http.delete(`${API}/tags/:id`, ({ params }) => {
        deleted = String(params.id);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');
    await user.click(await screen.findByRole('button', { name: 'Delete: home' }));
    const confirm = await screen.findByRole('dialog', { name: 'Delete this tag?' });
    expect(
      within(confirm).getByText(
        '“home” will be removed from 3 transactions. The transactions themselves stay.',
      ),
    ).toBeInTheDocument();
    await user.click(within(confirm).getByRole('button', { name: 'Delete tag' }));
    expect(await screen.findByText('Tag deleted')).toBeInTheDocument();
    expect(deleted).toBe(TAG_HOME);
  });

  it('shows a recoverable error', async () => {
    server.use(
      http.get(`${API}/tags`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-tags' }), {
          status: 500,
        }),
      ),
    );
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');
    expect(await screen.findByText('We couldn’t load your tags')).toBeInTheDocument();
    expect(screen.getByText('req-tags')).toBeInTheDocument();
  });

  it('shows a permission message when access is denied', async () => {
    server.use(
      http.get(`${API}/tags`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/categories/tags', { user: signedIn() });
    await findPageHeading('Tags');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
