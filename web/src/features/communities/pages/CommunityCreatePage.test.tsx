import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import {
  COMMUNITY_ID,
  dailyCapped,
  fieldError,
  makeCommunity,
  rateLimited,
  serveCommunity,
} from '@/tests/communitiesFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

async function openCreate() {
  const user = userEvent.setup();
  const result = renderRoute('/communities/new', {
    user: makeUser({ onboarding_completed: true }),
  });
  await findPageHeading('Create a community');
  return { user, ...result };
}

describe('CommunityCreatePage', () => {
  it('creates a community with its join policy and opens it', async () => {
    let body: unknown = null;
    const created = makeCommunity({
      name: 'Salary Circle',
      visibility: 'private',
      my_role: 'owner',
      member_count: 1,
    });
    serveCommunity(created, { posts: [] });
    server.use(
      http.post(`${API}/communities`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(envelope(created), { status: 201 });
      }),
    );
    const { user, router } = await openCreate();
    expect(document.title).toBe('Create a community · Montra');

    await user.type(screen.getByLabelText('Name'), '  Salary Circle ');
    await user.type(screen.getByLabelText(/Web address/), 'salary-circle');
    await user.type(screen.getByLabelText(/Description/), 'Negotiating pay, kindly.');
    await user.type(screen.getByLabelText(/Rules/), 'No names of employers.');
    await user.type(screen.getByLabelText(/Topics/), 'Careers, salary,  careers ');
    await user.click(screen.getByRole('radio', { name: /Private/ }));
    await user.click(screen.getByRole('button', { name: 'Create community' }));

    await waitFor(() => {
      expect(router.state.location.pathname).toBe(`/communities/${COMMUNITY_ID}`);
    });
    expect(body).toEqual({
      name: 'Salary Circle',
      slug: 'salary-circle',
      description: 'Negotiating pay, kindly.',
      rules: 'No names of employers.',
      topics: ['careers', 'salary'],
      visibility: 'private',
    });
    expect(await screen.findByText('Created Salary Circle')).toBeInTheDocument();
  });

  it('checks fields before sending, including payment secrets', async () => {
    let calls = 0;
    server.use(
      http.post(`${API}/communities`, () => {
        calls += 1;
        return HttpResponse.json(envelope(makeCommunity()), { status: 201 });
      }),
    );
    const { user } = await openCreate();
    await user.type(screen.getByLabelText('Name'), 'ab');
    await user.type(screen.getByLabelText(/Web address/), 'Not OK!');
    await user.type(screen.getByLabelText(/Description/), 'My card is 4111 1111 1111 1111');
    await user.type(screen.getByLabelText(/Topics/), 'good, bad!topic');
    await user.click(screen.getByRole('button', { name: 'Create community' }));

    expect(await screen.findByText('Use at least 3 characters.')).toBeInTheDocument();
    expect(screen.getByLabelText(/Web address/)).toHaveAccessibleDescription(
      /Use 3 to 60 lowercase letters, numbers and hyphens\./,
    );
    expect(screen.getByLabelText(/Description/)).toHaveAccessibleDescription(
      /Never share card numbers, CVVs, PINs, OTPs or passwords\./,
    );
    expect(screen.getByLabelText(/Topics/)).toHaveAccessibleDescription(/Topics are short words/);
    expect(calls).toBe(0);
  });

  it('asks for another web address when it is taken', async () => {
    server.use(
      http.post(`${API}/communities`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            message: 'That community URL is taken.',
            details: [{ field: 'body.slug', message: 'Choose another URL name.' }],
          }),
          { status: 409 },
        ),
      ),
    );
    const { user } = await openCreate();
    await user.type(screen.getByLabelText('Name'), 'Frugal Living');
    await user.click(screen.getByRole('button', { name: 'Create community' }));
    await waitFor(() => {
      expect(screen.getByLabelText(/Web address/)).toHaveAccessibleDescription(
        /That web address is taken\. Choose another\./,
      );
    });
  });

  it('shows the API’s coded field problems in the interface language, with their values', async () => {
    let calls = 0;
    server.use(
      http.post(`${API}/communities`, () => {
        calls += 1;
        if (calls === 1) {
          return fieldError(
            'body.description',
            'invalid_characters',
            'This text contains characters that are not allowed.',
          );
        }
        if (calls === 2) {
          return HttpResponse.json(
            errorBody({
              code: 'VALIDATION_ERROR',
              details: [
                {
                  field: 'body.name',
                  message: 'expected length <= 80',
                  code: 'too_long',
                  params: { max: '80' },
                },
                {
                  field: 'body.topics',
                  message: 'Topics are short words.',
                  code: 'invalid_topic',
                  params: { index: '1' },
                },
              ],
            }),
            { status: 422 },
          );
        }
        // A code this app does not know: the API's message is shown as sent.
        return fieldError('body.rules', 'brand_new_code', 'Rules need a closing line.');
      }),
    );
    const { user } = await openCreate();
    await user.type(screen.getByLabelText('Name'), 'Frugal Living');
    await user.type(screen.getByLabelText(/Description/), 'Hello');
    await user.click(screen.getByRole('button', { name: 'Create community' }));
    await waitFor(() => {
      expect(screen.getByLabelText(/Description/)).toHaveAccessibleDescription(
        /This text has characters that can’t be used\./,
      );
    });
    await user.click(screen.getByRole('button', { name: 'Create community' }));
    await waitFor(() => {
      expect(screen.getByLabelText('Name')).toHaveAccessibleDescription(
        /Use 80 characters or fewer\./,
      );
    });
    expect(screen.getByLabelText(/Topics/)).toHaveAccessibleDescription(
      /Topic 2 isn’t valid: use letters, numbers, spaces and hyphens, up to 30 characters\./,
    );
    await user.click(screen.getByRole('button', { name: 'Create community' }));
    await waitFor(() => {
      expect(screen.getByLabelText(/Rules/)).toHaveAccessibleDescription(
        /Rules need a closing line\./,
      );
    });
  });

  it('explains the daily limit calmly, with when to try again when the API says', async () => {
    let calls = 0;
    server.use(
      http.post(`${API}/communities`, () => {
        calls += 1;
        return calls === 1 ? rateLimited() : dailyCapped('communities', 3, 7200);
      }),
    );
    const { user } = await openCreate();
    await user.type(screen.getByLabelText('Name'), 'Frugal Living');
    await user.click(screen.getByRole('button', { name: 'Create community' }));
    expect(
      await screen.findByText('You’ve reached today’s limit for this. You can try again later.'),
    ).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Create community' }));
    expect(
      await screen.findByText(
        'You’ve reached today’s limit of 3 new communities. You can try again in 2 hours.',
      ),
    ).toBeInTheDocument();
  });
});
