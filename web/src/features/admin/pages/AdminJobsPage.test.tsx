import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeAll, describe, expect, it } from 'vitest';
import type { Job, JobAttempt } from '@/features/admin/types';
import { expectNoAxeViolations } from '@/tests/axe';
import { API, envelope, errorBody, makeUser, meta } from '@/tests/fixtures';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

const admin = () => makeUser({ onboarding_completed: true, platform_role: 'admin' });
const support = () => makeUser({ onboarding_completed: true, platform_role: 'support' });

const JOB_DEAD = '0b6a1d2e-0000-4000-8000-000000000001';
const JOB_OK = '0b6a1d2e-0000-4000-8000-000000000002';

function makeJob(overrides: Partial<Job> = {}): Job {
  return {
    id: JOB_DEAD,
    type: 'notifications.deliver',
    queue: 'default',
    status: 'dead',
    priority: 100,
    attempts: 8,
    max_attempts: 8,
    last_error_code: 'provider_circuit_open',
    user_scoped: true,
    cancel_requested: false,
    retryable: true,
    run_after: '2026-11-13T06:00:00Z',
    created_at: '2026-11-13T05:00:00Z',
    updated_at: '2026-11-13T06:10:00Z',
    started_at: '2026-11-13T06:09:00Z',
    finished_at: '2026-11-13T06:10:00Z',
    ...overrides,
  };
}

function attempt(overrides: Partial<JobAttempt> = {}): JobAttempt {
  return {
    attempt: 1,
    worker_id: 'worker-a1',
    outcome: 'retry',
    error_code: 'provider_circuit_open',
    started_at: '2026-11-13T05:01:00Z',
    finished_at: '2026-11-13T05:01:02Z',
    duration_ms: 2010,
    ...overrides,
  };
}

function serveList(pages: Job[][], record: URL[] = []) {
  server.use(
    http.get(`${API}/admin/jobs`, ({ request }) => {
      const url = new URL(request.url);
      record.push(url);
      const page = url.searchParams.get('cursor') ? 1 : 0;
      return HttpResponse.json({
        data: pages[page] ?? [],
        meta: {
          ...meta(),
          ...(page === 0 && pages.length > 1 ? { next_cursor: 'c2', has_more: true } : {}),
        },
      });
    }),
  );
  return record;
}

function serveDetail(job: Job, attempts: JobAttempt[]) {
  server.use(
    http.get(`${API}/admin/jobs/:id`, ({ params }) =>
      params.id === job.id
        ? HttpResponse.json(envelope({ job, attempts }))
        : HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
    ),
  );
}

beforeAll(async () => {
  await import('./AdminJobsPage');
  await import('./AdminJobDetailPage');
});

describe('AdminJobsPage', () => {
  it('lists jobs with status, attempts and failure codes in words, and pages with the cursor', async () => {
    const requests = serveList([
      [
        makeJob(),
        makeJob({
          id: JOB_OK,
          type: 'budgets.evaluate',
          status: 'succeeded',
          attempts: 1,
          last_error_code: undefined,
          retryable: false,
          user_scoped: false,
        }),
      ],
      [
        makeJob({
          id: '0b6a1d2e-0000-4000-8000-000000000003',
          type: 'files.cleanup',
          status: 'queued',
          attempts: 0,
          last_error_code: undefined,
          retryable: false,
        }),
      ],
    ]);
    const user = userEvent.setup();
    renderRoute('/staff/jobs', { user: admin() });
    await findPageHeading('Background jobs');
    const table = await screen.findByRole('table', { name: 'Background jobs, newest first' });
    const dead = within(table).getByRole('row', { name: /notifications\.deliver/ });
    expect(within(dead).getByText('Dead')).toBeInTheDocument();
    expect(within(dead).getByText('8 of 8')).toBeInTheDocument();
    expect(within(dead).getByText('provider_circuit_open')).toBeInTheDocument();
    expect(
      within(dead).getByText(
        'An external provider is temporarily unavailable. The job will retry after a cool-down.',
      ),
    ).toBeInTheDocument();
    expect(
      within(dead).getByRole('link', { name: /Details of notifications\.deliver job/ }),
    ).toHaveAttribute('href', `/staff/jobs/${JOB_DEAD}`);
    expect(requests[0]?.searchParams.get('limit')).toBe('50');

    await user.click(screen.getByRole('button', { name: 'Load more jobs' }));
    expect(await within(table).findByText('files.cleanup')).toBeInTheDocument();
    expect(requests[1]?.searchParams.get('cursor')).toBe('c2');
    await expectNoAxeViolations();
  });

  it('filters by status, type and dates through the address', async () => {
    const requests = serveList([[]]);
    const user = userEvent.setup();
    const { router } = renderRoute('/staff/jobs', { user: admin() });
    await findPageHeading('Background jobs');
    expect(await screen.findByText('No jobs match these filters.')).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText(/^Status/), 'failed');
    await user.type(screen.getByLabelText(/^Job type/), 'imports.process');
    await user.type(screen.getByLabelText(/^Created from/), '2026-11-10');
    await user.type(screen.getByLabelText(/^Created to/), '2026-11-01');
    await user.click(screen.getByRole('button', { name: 'Apply filters' }));
    expect(
      await screen.findByText('The “to” date must be on or after the “from” date.'),
    ).toBeInTheDocument();
    await user.clear(screen.getByLabelText(/^Created to/));
    await user.type(screen.getByLabelText(/^Created to/), '2026-11-12');
    await user.click(screen.getByRole('button', { name: 'Apply filters' }));
    await waitFor(() => {
      const last = requests.at(-1)!.searchParams;
      expect(last.get('status')).toBe('failed');
      expect(last.get('type')).toBe('imports.process');
      expect(last.get('from')).toBe('2026-11-10');
      expect(last.get('to')).toBe('2026-11-12');
    });
    expect(router.state.location.search).toContain('status=failed');
  });

  it('is not shown to support staff, and makes no request for them', async () => {
    const requests = serveList([[makeJob()]]);
    renderRoute('/staff/jobs', { user: support() });
    await findPageHeading('Background jobs');
    expect(screen.getByText('This page is for Montra admins')).toBeInTheDocument();
    expect(requests).toEqual([]);
    expect(screen.queryByRole('link', { name: 'Jobs' })).not.toBeInTheDocument();
  });

  it('shows the admin a Jobs link in the staff navigation', async () => {
    serveList([[]]);
    renderRoute('/staff/jobs', { user: admin() });
    await findPageHeading('Background jobs');
    expect(screen.getAllByRole('link', { name: 'Jobs' }).length).toBeGreaterThan(0);
  });

  it('treats a 403 from the API as no access', async () => {
    server.use(
      http.get(`${API}/admin/jobs`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/staff/jobs', { user: admin() });
    expect(await screen.findByText('This page is for Montra admins')).toBeInTheDocument();
  });
});

describe('AdminJobDetailPage', () => {
  it('shows the job and its attempts, and retries it after confirming with an Idempotency-Key', async () => {
    serveDetail(makeJob(), [
      attempt(),
      attempt({ attempt: 2, outcome: 'dead', worker_id: 'worker-b2', duration_ms: 15 }),
    ]);
    const keys: (string | null)[] = [];
    server.use(
      http.post(`${API}/admin/jobs/:id/retry`, ({ request }) => {
        keys.push(request.headers.get('Idempotency-Key'));
        return HttpResponse.json(envelope(makeJob({ status: 'queued', retryable: false })));
      }),
    );
    const user = userEvent.setup();
    renderRoute(`/staff/jobs/${JOB_DEAD}`, { user: admin() });
    await findPageHeading('notifications.deliver');
    const attempts = screen.getByRole('table', { name: 'Attempts of this job, first to last' });
    expect(within(attempts).getByRole('row', { name: /worker-b2/ })).toHaveTextContent('Dead');
    expect(within(attempts).getByText('2,010 ms')).toBeInTheDocument();
    expect(screen.getByText('Acts for one person (not disclosed)')).toBeInTheDocument();
    await expectNoAxeViolations();

    await user.click(screen.getByRole('button', { name: 'Retry job' }));
    const dialog = await screen.findByRole('dialog', { name: 'Retry this job?' });
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    expect(keys).toEqual([]);

    await user.click(screen.getByRole('button', { name: 'Retry job' }));
    await user.click(
      within(await screen.findByRole('dialog', { name: 'Retry this job?' })).getByRole('button', {
        name: 'Retry now',
      }),
    );
    expect(await screen.findByText('Job queued to run again')).toBeInTheDocument();
    expect(keys).toHaveLength(1);
    expect(keys[0]).toMatch(/^web-[0-9a-f-]{36}$/);
  });

  it('disables retry for a job that is not failed or dead', async () => {
    serveDetail(
      makeJob({ id: JOB_OK, status: 'succeeded', retryable: false, last_error_code: undefined }),
      [],
    );
    renderRoute(`/staff/jobs/${JOB_OK}`, { user: admin() });
    await findPageHeading('notifications.deliver');
    expect(screen.getByRole('button', { name: 'Retry job' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Retry job' })).toHaveAccessibleDescription(
      'Only failed or dead jobs can be retried. This one is succeeded.',
    );
    expect(screen.getByText('No attempts yet.')).toBeInTheDocument();
  });

  it('explains job_not_retryable with the status the job has now', async () => {
    serveDetail(makeJob({ status: 'failed' }), [attempt()]);
    server.use(
      http.post(`${API}/admin/jobs/:id/retry`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                field: 'path.id',
                code: 'job_not_retryable',
                message: 'Only failed or dead jobs can be retried.',
                params: { status: 'running', from: 'running', to: 'queued' },
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute(`/staff/jobs/${JOB_DEAD}`, { user: admin() });
    await findPageHeading('notifications.deliver');
    await user.click(screen.getByRole('button', { name: 'Retry job' }));
    const dialog = await screen.findByRole('dialog', { name: 'Retry this job?' });
    await user.click(within(dialog).getByRole('button', { name: 'Retry now' }));
    expect(
      await within(dialog).findByText('This job can’t be retried any more: it is running now.'),
    ).toBeInTheDocument();
  });

  it('says when a job does not exist', async () => {
    serveDetail(makeJob(), []);
    renderRoute('/staff/jobs/0b6a1d2e-0000-4000-8000-00000000ffff', { user: admin() });
    expect(
      await screen.findByText('This job doesn’t exist, or it was cleaned up.'),
    ).toBeInTheDocument();
  });
});
