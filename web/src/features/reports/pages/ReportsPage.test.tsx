import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it, vi } from 'vitest';
import type { Report } from '@/features/reports/types';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  ACCOUNT_CASH,
  ACCOUNT_USD,
  makeAccount,
  money,
  starterCategories,
} from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import {
  makeAccess,
  makeExpiredReport,
  makeFailedReport,
  makeLimits,
  makeReport,
  makeRunningReport,
  makeSchedule,
  makeStalledReport,
  REPORT_FILE,
  REPORT_READY,
  SCHEDULE_MONTHLY,
} from '@/tests/reportsFixtures';

const signedIn = () => makeUser({ onboarding_completed: true });

interface Backend {
  /** Each GET /reports answers with the next list (the last one repeats). */
  lists?: Report[][];
  listRequests?: URL[];
}

/** GET /reports, /reports/schedules and /limits for a page visit. */
function reportsBackend({ lists = [[makeReport()]], listRequests = [] }: Backend = {}) {
  let call = 0;
  return [
    http.get(`${API}/reports`, ({ request }) => {
      listRequests.push(new URL(request.url));
      const list = lists[Math.min(call, lists.length - 1)] ?? [];
      call += 1;
      return HttpResponse.json(envelope(list));
    }),
    http.get(`${API}/reports/schedules`, () => HttpResponse.json(envelope([]))),
    http.get(`${API}/limits`, () => HttpResponse.json(envelope(makeLimits()))),
  ];
}

async function openPage() {
  const user = userEvent.setup();
  renderRoute('/reports', { user: signedIn() });
  await findPageHeading('Reports');
  return user;
}

function item(title: string) {
  const list = screen.getByRole('region', { name: 'Your reports' });
  const heading = within(list).getByText(title);
  const row = heading.closest('li');
  if (!row) throw new Error(`No list item for ${title}`);
  return row;
}

describe('ReportsPage — your reports', () => {
  it('lists reports with their state, period, filters and how long they stay available', async () => {
    server.use(
      ...reportsBackend({
        lists: [
          [
            makeReport(),
            makeRunningReport(),
            makeFailedReport(),
            makeExpiredReport(),
            makeStalledReport(),
          ],
        ],
      }),
    );
    await openPage();
    const list = screen.getByRole('region', { name: 'Your reports' });
    expect(
      await within(list).findByText(/A ready report can be downloaded for 7 days\./),
    ).toBeInTheDocument();

    const ready = await waitFor(() => item('Monthly summary'));
    expect(within(ready).getByText('Ready')).toBeInTheDocument();
    // The dates the API resolved when the report was requested (its window).
    expect(
      within(ready).getByText(/Monthly summary · CSV · Last month \(Oct 1\s–\s31, 2026\)/),
    ).toBeInTheDocument();
    expect(within(ready).getByText(/22 rows · Available until Nov 11, 2026/)).toBeInTheDocument();
    expect(
      within(ready).getByRole('button', { name: 'Download Monthly summary' }),
    ).toBeInTheDocument();
    expect(within(ready).queryByRole('button', { name: /again/ })).not.toBeInTheDocument();

    const running = item('November USD');
    expect(within(running).getByText('Being prepared')).toBeInTheDocument();
    expect(
      within(running).getByText(/Transactions · PDF · Nov 1\s–\s30, 2026/),
    ).toBeInTheDocument();
    expect(within(running).getByText('USD only · Includes pending')).toBeInTheDocument();
    expect(
      within(running).queryByRole('button', { name: /^Download|again/ }),
    ).not.toBeInTheDocument();
    // Any report can be deleted, even while it is prepared.
    expect(
      within(running).getByRole('button', { name: 'Delete report November USD' }),
    ).toBeInTheDocument();

    const failed = item('Everything');
    expect(within(failed).getByText('Couldn’t be created')).toBeInTheDocument();
    expect(
      within(failed).getByText(
        'This report is too long for a PDF. Choose CSV or Excel, or a shorter period.',
      ),
    ).toBeInTheDocument();
    expect(within(failed).getByText('1 account')).toBeInTheDocument();
    expect(
      within(failed).getByRole('button', { name: 'Generate again: Everything' }),
    ).toBeInTheDocument();

    const expired = item('Accounts');
    expect(within(expired).getByText('Expired')).toBeInTheDocument();
    expect(
      within(expired).getByText('Account balances · Excel (XLSX) · Current figures'),
    ).toBeInTheDocument();
    expect(within(expired).getByText(/Expired on Oct 27, 2026/)).toBeInTheDocument();
    expect(within(expired).queryByRole('button', { name: /^Download/ })).not.toBeInTheDocument();

    const stalled = item('Cash flow');
    expect(within(stalled).getByText('Waiting to start')).toBeInTheDocument();
    expect(
      within(stalled).getByText('This is taking longer than usual. You can generate it again.'),
    ).toBeInTheDocument();
    expect(within(stalled).getByText('Converted to INR')).toBeInTheDocument();
  });

  it('treats a ready report past its download window as expired', async () => {
    server.use(
      ...reportsBackend({
        lists: [[makeReport({ expires_at: '2026-11-04T09:00:00Z' })]],
      }),
    );
    await openPage();
    const row = await waitFor(() => item('Monthly summary'));
    expect(within(row).getByText('Expired')).toBeInTheDocument();
    expect(within(row).getByText(/Expired on Nov 4, 2026/)).toBeInTheDocument();
    expect(within(row).queryByRole('button', { name: /^Download/ })).not.toBeInTheDocument();
    expect(
      within(row).getByRole('button', { name: 'Generate again: Monthly summary' }),
    ).toBeInTheDocument();
  });

  it('shows an empty state with a way to start', async () => {
    server.use(...reportsBackend({ lists: [[]] }));
    const user = await openPage();
    expect(await screen.findByText('No reports yet')).toBeInTheDocument();
    const list = screen.getByRole('region', { name: 'Your reports' });
    await user.click(within(list).getByRole('button', { name: 'New report' }));
    expect(await screen.findByRole('dialog', { name: 'New report' })).toBeInTheDocument();
  });

  it('explains a failure to load and recovers with retry', async () => {
    let calls = 0;
    server.use(
      http.get(`${API}/reports`, () => {
        calls += 1;
        return calls === 1
          ? HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 })
          : HttpResponse.json(envelope([makeReport()]));
      }),
      ...reportsBackend(),
    );
    const user = await openPage();
    expect(await screen.findByText('We couldn’t load your reports')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(
      await screen.findByRole('button', { name: 'Download Monthly summary' }),
    ).toBeInTheDocument();
  });

  it('shows the permission state when reports are not available to this account', async () => {
    server.use(
      http.get(`${API}/reports`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
      ...reportsBackend(),
    );
    await openPage();
    const list = screen.getByRole('region', { name: 'Your reports' });
    expect(await within(list).findByText('You don’t have access to this')).toBeInTheDocument();
  });

  it('follows a report while it is prepared and says when it is ready', async () => {
    const listRequests: URL[] = [];
    server.use(
      ...reportsBackend({
        lists: [
          [makeRunningReport()],
          [
            makeRunningReport({
              status: 'completed',
              row_count: 2,
              completed_at: '2026-11-04T10:00:01Z',
              expires_at: '2026-11-11T10:00:01Z',
            }),
          ],
        ],
        listRequests,
      }),
    );
    await openPage();
    expect(await screen.findByText('Being prepared')).toBeInTheDocument();
    expect(
      await screen.findByText('“November USD” is ready to download', {}, { timeout: 6000 }),
    ).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Download November USD' })).toBeInTheDocument();
    expect(listRequests.length).toBeGreaterThanOrEqual(2);
  }, 10_000);
});

describe('ReportsPage — creating reports', () => {
  it('requests a report with the chosen type, format, period and filters', async () => {
    testBackend.accounts = [
      makeAccount(),
      makeAccount({
        id: ACCOUNT_USD,
        name: 'Travel card',
        currency: 'USD',
        balance: money('500.00', 'USD'),
      }),
    ];
    testBackend.categories = starterCategories();
    const bodies: unknown[] = [];
    server.use(
      ...reportsBackend({
        lists: [
          [makeReport()],
          [
            makeRunningReport({
              id: 'f0f0f0f0-1111-4111-8111-0000000000aa',
              report_type: 'income',
              title: 'November income',
              status: 'queued',
            }),
            makeReport(),
          ],
        ],
      }),
      http.post(`${API}/reports`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeRunningReport({ status: 'queued' })), {
          status: 202,
        });
      }),
    );
    const user = await openPage();
    await user.click(screen.getByRole('button', { name: 'New report' }));
    const dialog = await screen.findByRole('dialog', { name: 'New report' });

    await user.click(within(dialog).getByRole('button', { name: 'Create report' }));
    expect(await within(dialog).findByText('Choose a report.')).toBeInTheDocument();
    expect(bodies).toHaveLength(0);

    await user.selectOptions(within(dialog).getByLabelText('Report'), 'income');
    expect(
      within(dialog).getByText('Your income totals and how they changed over time.'),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByLabelText('Excel (XLSX)'));
    await user.selectOptions(within(dialog).getByLabelText('Period'), 'custom');
    await user.type(within(dialog).getByLabelText('From'), '2026-10-01');
    await user.type(within(dialog).getByLabelText('To'), '2026-10-31');
    await user.type(within(dialog).getByLabelText('Title (optional)'), 'November income');
    await user.selectOptions(within(dialog).getByLabelText('Account (optional)'), ACCOUNT_CASH);
    await user.selectOptions(within(dialog).getByLabelText('Only this currency (optional)'), 'INR');
    await user.selectOptions(
      within(dialog).getByLabelText('Also convert totals to (optional)'),
      'USD',
    );
    await user.click(within(dialog).getByLabelText('Include pending transactions'));
    await user.click(within(dialog).getByRole('button', { name: 'Create report' }));

    expect(await screen.findByText('Report requested')).toBeInTheDocument();
    expect(bodies).toEqual([
      {
        report_type: 'income',
        format: 'xlsx',
        title: 'November income',
        filters: {
          account_ids: [ACCOUNT_CASH],
          currency: 'INR',
          include_pending: true,
          types: ['income'],
          display_currency: 'USD',
          from: '2026-10-01',
          to: '2026-10-31',
        },
      },
    ]);
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(await screen.findByText('November income')).toBeInTheDocument();
  });

  it('takes no period or filters for reports of current figures', async () => {
    const bodies: unknown[] = [];
    server.use(
      ...reportsBackend(),
      http.post(`${API}/reports`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeExpiredReport({ status: 'queued' })), {
          status: 202,
        });
      }),
    );
    const user = await openPage();
    await user.click(screen.getByRole('button', { name: 'New report' }));
    const dialog = await screen.findByRole('dialog', { name: 'New report' });
    await user.selectOptions(within(dialog).getByLabelText('Report'), 'account');
    expect(within(dialog).queryByLabelText('Period')).not.toBeInTheDocument();
    expect(
      within(dialog).getByText(
        'This report shows your figures as they are when it is created, so no period or filters apply.',
      ),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Create report' }));
    expect(await screen.findByText('Report requested')).toBeInTheDocument();
    expect(bodies).toEqual([{ report_type: 'account', format: 'csv', filters: {} }]);
  });

  it('deletes a report after confirmation and refreshes the list', async () => {
    const deleted: string[] = [];
    let gone = false;
    server.use(
      http.get(`${API}/reports`, () =>
        HttpResponse.json(envelope(gone ? [] : [makeReport(), makeRunningReport()])),
      ),
      http.get(`${API}/reports/schedules`, () => HttpResponse.json(envelope([]))),
      http.get(`${API}/limits`, () => HttpResponse.json(envelope(makeLimits()))),
      http.delete(`${API}/reports/:id`, ({ params }) => {
        deleted.push(String(params.id));
        gone = true;
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = await openPage();
    const ready = await waitFor(() => item('Monthly summary'));
    await user.click(within(ready).getByRole('button', { name: 'Delete report Monthly summary' }));
    const dialog = await screen.findByRole('dialog', { name: 'Delete this report?' });
    expect(
      within(dialog).getByText(
        '“Monthly summary” and its file are deleted. Download links stop working.',
      ),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    expect(deleted).toEqual([]);

    await user.click(within(ready).getByRole('button', { name: 'Delete report Monthly summary' }));
    await user.click(
      within(await screen.findByRole('dialog', { name: 'Delete this report?' })).getByRole(
        'button',
        { name: 'Delete report' },
      ),
    );
    expect(await screen.findByText('Report deleted')).toBeInTheDocument();
    expect(deleted).toEqual([REPORT_READY]);
    expect(await screen.findByText('No reports yet')).toBeInTheDocument();
  });

  it('generates a failed report again with the same settings', async () => {
    const bodies: unknown[] = [];
    server.use(
      ...reportsBackend({ lists: [[makeFailedReport()]] }),
      http.post(`${API}/reports`, async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json(envelope(makeRunningReport({ status: 'queued' })), {
          status: 202,
        });
      }),
    );
    const user = await openPage();
    await user.click(await screen.findByRole('button', { name: 'Generate again: Everything' }));
    expect(await screen.findByText('Report requested')).toBeInTheDocument();
    expect(bodies).toEqual([
      {
        report_type: 'transactions',
        format: 'pdf',
        title: 'Everything',
        filters: { range: 'this_year', account_ids: ['11111111-1111-4111-8111-111111111111'] },
      },
    ]);
  });
});

describe('ReportsPage — downloads', () => {
  it('saves the file under the server’s name, fetched with IDs and a signature only', async () => {
    const contentRequests: URL[] = [];
    server.use(
      ...reportsBackend(),
      http.get(`${API}/reports/:id/download`, ({ params }) => {
        expect(params.id).toBe(REPORT_READY);
        return HttpResponse.json(envelope(makeAccess()));
      }),
      http.get(`${API}/files/:fileId/content`, ({ request }) => {
        contentRequests.push(new URL(request.url));
        return new HttpResponse('Report,Monthly summary\n', {
          headers: {
            'Content-Type': 'text/csv',
            'Content-Disposition': 'attachment; filename=monthly-summary-20261104.csv',
          },
        });
      }),
    );
    const blobs: Blob[] = [];
    const names: string[] = [];
    Object.assign(URL, {
      createObjectURL: vi.fn((blob: Blob) => {
        blobs.push(blob);
        return 'blob:report';
      }),
      revokeObjectURL: vi.fn(),
    });
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (
      this: HTMLAnchorElement,
    ) {
      names.push(this.download);
    });
    const user = await openPage();
    await user.click(await screen.findByRole('button', { name: 'Download Monthly summary' }));

    expect(await screen.findByText('Download started')).toBeInTheDocument();
    expect(names).toEqual(['monthly-summary-20261104.csv']);
    expect(await blobs[0]!.text()).toBe('Report,Monthly summary\n');
    // Same-origin API path; the only query values are the expiry, signature and owner ID.
    const url = contentRequests[0]!;
    expect(url.pathname).toBe(`/api/v1/files/${REPORT_FILE}/content`);
    expect([...url.searchParams.keys()].sort()).toEqual(['exp', 'sig', 'sub']);
    click.mockRestore();
  });

  it('explains an expired download and refreshes the list', async () => {
    const listRequests: URL[] = [];
    server.use(
      ...reportsBackend({ listRequests }),
      http.get(`${API}/reports/:id/download`, () =>
        HttpResponse.json(
          errorBody({ code: 'GONE', message: 'This report has expired. Generate it again.' }),
          { status: 410 },
        ),
      ),
    );
    const user = await openPage();
    await user.click(await screen.findByRole('button', { name: 'Download Monthly summary' }));
    expect(await screen.findByText('This report has expired')).toBeInTheDocument();
    expect(screen.getByText('Generate it again to download it.')).toBeInTheDocument();
    await waitFor(() => {
      expect(listRequests.length).toBeGreaterThanOrEqual(2);
    });
  });
});

describe('ReportsPage — schedules', () => {
  it('lists, adds and deletes scheduled reports', async () => {
    const bodies: unknown[] = [];
    const deleted: string[] = [];
    let schedules = [makeSchedule()];
    server.use(
      http.get(`${API}/reports/schedules`, () => HttpResponse.json(envelope(schedules))),
      ...reportsBackend(),
      http.post(`${API}/reports/schedules`, async ({ request }) => {
        bodies.push(await request.json());
        const created = makeSchedule({
          id: 'f2f2f2f2-3333-4333-8333-0000000000bb',
          report_type: 'cash_flow',
          title: 'Cash flow (weekly)',
          format: 'csv',
          cadence: 'weekly',
          next_run_at: '2026-11-09T00:30:00Z',
        });
        schedules = [...schedules, created];
        return HttpResponse.json(envelope(created), { status: 201 });
      }),
      http.delete(`${API}/reports/schedules/:id`, ({ params }) => {
        deleted.push(String(params.id));
        schedules = schedules.filter((schedule) => schedule.id !== params.id);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = await openPage();
    const card = screen.getByRole('region', { name: 'Scheduled reports' });
    expect(await within(card).findByText('Monthly summary (monthly)')).toBeInTheDocument();
    expect(within(card).getByText('Monthly summary · PDF · Every month')).toBeInTheDocument();
    expect(within(card).getByText(/Next report: Dec 1, 2026, 6:00\sAM/)).toBeInTheDocument();

    await user.click(within(card).getByRole('button', { name: 'Schedule a report' }));
    const dialog = await screen.findByRole('dialog', { name: 'Schedule a report' });
    await user.selectOptions(within(dialog).getByLabelText('Report'), 'cash_flow');
    await user.click(within(dialog).getByLabelText('Every week'));
    await user.click(within(dialog).getByLabelText('CSV'));
    await user.click(within(dialog).getByRole('button', { name: 'Save schedule' }));
    expect(await screen.findByText('Report scheduled')).toBeInTheDocument();
    expect(bodies).toEqual([
      { report_type: 'cash_flow', format: 'csv', cadence: 'weekly', filters: {} },
    ]);
    expect(await within(card).findByText('Cash flow (weekly)')).toBeInTheDocument();

    await user.click(
      within(card).getByRole('button', { name: 'Delete schedule Monthly summary (monthly)' }),
    );
    const confirm = await screen.findByRole('dialog', { name: 'Delete this schedule?' });
    expect(
      within(confirm).getByText(
        '“Monthly summary (monthly)” won’t be prepared again. Reports already created stay in your list.',
      ),
    ).toBeInTheDocument();
    await user.click(within(confirm).getByRole('button', { name: 'Delete schedule' }));
    expect(await screen.findByText('Schedule deleted')).toBeInTheDocument();
    expect(deleted).toEqual([SCHEDULE_MONTHLY]);
    await waitFor(() => {
      expect(within(card).queryByText('Monthly summary (monthly)')).not.toBeInTheDocument();
    });
  });

  it('pauses, resumes and edits a schedule with its version, and reloads it after a conflict', async () => {
    const patches: { id: string; body: Record<string, unknown> }[] = [];
    let schedule = makeSchedule();
    server.use(
      http.get(`${API}/reports/schedules`, () => HttpResponse.json(envelope([schedule]))),
      ...reportsBackend(),
      http.patch(`${API}/reports/schedules/:id`, async ({ params, request }) => {
        const body = (await request.json()) as Record<string, unknown>;
        patches.push({ id: String(params.id), body });
        if (body.title === 'Month in review') {
          // Someone changed it meanwhile.
          schedule = makeSchedule({ cadence: 'weekly', version: 9 });
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        schedule = {
          ...schedule,
          ...(typeof body.enabled === 'boolean' ? { enabled: body.enabled } : {}),
          ...(typeof body.title === 'string' && body.title ? { title: body.title } : {}),
          ...(typeof body.format === 'string' ? { format: body.format as 'csv' } : {}),
          version: schedule.version + 1,
        };
        return HttpResponse.json(envelope(schedule));
      }),
    );
    const user = await openPage();
    const card = screen.getByRole('region', { name: 'Scheduled reports' });
    await user.click(
      await within(card).findByRole('button', { name: 'Pause schedule Monthly summary (monthly)' }),
    );
    expect(await screen.findByText('Schedule paused')).toBeInTheDocument();
    expect(await within(card).findByText('Paused')).toBeInTheDocument();
    expect(within(card).queryByText(/Next report:/)).not.toBeInTheDocument();
    expect(patches[0]).toEqual({ id: SCHEDULE_MONTHLY, body: { enabled: false, version: 1 } });

    await user.click(
      within(card).getByRole('button', { name: 'Resume schedule Monthly summary (monthly)' }),
    );
    expect(await screen.findByText('Schedule resumed')).toBeInTheDocument();
    expect(patches[1]).toEqual({ id: SCHEDULE_MONTHLY, body: { enabled: true, version: 2 } });

    await user.click(
      within(card).getByRole('button', { name: 'Edit schedule Monthly summary (monthly)' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Edit scheduled report' });
    expect(within(dialog).getByText(/Report: Monthly summary\./)).toBeInTheDocument();
    expect(within(dialog).getByLabelText('Every month')).toBeChecked();
    const title = within(dialog).getByLabelText(/^Title/);
    await user.clear(title);
    await user.type(title, 'Month in review');
    await user.click(within(dialog).getByLabelText('CSV'));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    // The conflict: the latest schedule is loaded and the form starts again from it.
    expect(await within(dialog).findByText('This was changed somewhere else')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Every week')).toBeChecked();
    });
    expect(patches[2]).toEqual({
      id: SCHEDULE_MONTHLY,
      body: {
        title: 'Month in review',
        format: 'csv',
        cadence: 'monthly',
        filters: {},
        version: 3,
      },
    });
    const retitle = within(dialog).getByLabelText(/^Title/);
    await user.clear(retitle);
    await user.type(retitle, 'Week in review');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Schedule updated')).toBeInTheDocument();
    expect(patches[3]?.body).toEqual({
      title: 'Week in review',
      format: 'pdf',
      cadence: 'weekly',
      filters: {},
      version: 9,
    });
    expect(await within(card).findByText('Week in review')).toBeInTheDocument();
  });

  it('shows an empty state for schedules', async () => {
    server.use(...reportsBackend());
    await openPage();
    expect(await screen.findByText('No scheduled reports')).toBeInTheDocument();
  });
});
