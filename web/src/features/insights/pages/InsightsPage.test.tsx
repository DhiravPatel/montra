import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { beforeEach, describe, expect, it } from 'vitest';
import type { Insight, InsightMute } from '@/features/insights/types';
import { CATEGORY_GROCERIES, TX_GROCERIES } from '@/tests/financeFixtures';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  BUDGET_DINING,
  INSIGHT_OVERSPEND,
  INSIGHT_UNUSUAL,
  insightPage,
  makeCashFlowInsight,
  makeFeedback,
  makeInsight,
  makeInsightMute,
  makeLegacyInsight,
  makeOverspendInsight,
  makePriceInsight,
} from '@/tests/insightsFixtures';
import { muteScopeOf } from '../evidence';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';
import { shellHandlers } from '@/tests/searchFixtures';

const user0 = () => makeUser({ onboarding_completed: true });

interface Backend {
  /** Every insight the account has; GET /insights filters it like the API. */
  insights: Insight[];
  /** Mute rules (GET /insights/mutes). */
  mutes: InsightMute[];
  calls: Record<string, string>[];
  ai: number;
}

/** A small stand-in for the insights API (lists, mutes, plus a counter for any /ai/* call). */
function insightsBackend(insights: Insight[], mutes: InsightMute[] = []): Backend {
  const backend: Backend = { insights, mutes, calls: [], ai: 0 };
  server.use(
    http.get(`${API}/insights`, ({ request }) => {
      const params = new URL(request.url).searchParams;
      backend.calls.push(Object.fromEntries(params));
      const kind = params.get('kind');
      const all = params.get('all') === 'true';
      return HttpResponse.json(
        insightPage(
          backend.insights.filter(
            (item) => (all || item.status === 'active') && (!kind || item.kind === kind),
          ),
        ),
      );
    }),
    http.get(`${API}/insights/mutes`, () => HttpResponse.json(envelope(backend.mutes))),
    http.delete(`${API}/insights/mutes`, ({ request }) => {
      const params = new URL(request.url).searchParams;
      const subtype = params.get('subtype') ?? '';
      const scope = params.get('scope') ?? '*';
      backend.calls.push({ unmute: `${subtype}|${scope}` });
      const before = backend.mutes.length;
      backend.mutes = backend.mutes.filter(
        (mute) => !(mute.subtype === subtype && mute.scope === scope),
      );
      if (backend.mutes.length === before) {
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }
      // Like the API: reopen the muted insights of the subtype that no remaining rule covers.
      const reopened: Insight[] = [];
      backend.insights = backend.insights.map((item) => {
        const covered = backend.mutes.some(
          (mute) =>
            mute.subtype === item.subtype &&
            (mute.scope === '*' || mute.scope === muteScopeOf(item)),
        );
        if (item.subtype !== subtype || item.status !== 'muted' || covered) return item;
        const next: Insight = { ...item, status: 'active' };
        reopened.push(next);
        return next;
      });
      return HttpResponse.json(
        envelope({ subtype, scope, reopened: reopened.length, insights: reopened }),
      );
    }),
    http.all(`${API}/ai/*`, () => {
      backend.ai += 1;
      return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
    }),
  );
  return backend;
}

/** Answers POST /insights/{id}/actions like the API and records the bodies. */
function actionsBackend(backend: Backend, changes: Partial<Insight> = {}) {
  const bodies: unknown[] = [];
  server.use(
    http.post(`${API}/insights/:id/actions`, async ({ params, request }) => {
      const body = (await request.json()) as { action: string };
      bodies.push(body);
      const status = (
        {
          dismiss: 'dismissed',
          snooze: 'snoozed',
          expected: 'expected',
          resolved: 'resolved',
          mute: 'muted',
          reopen: 'active',
        } as const
      )[body.action as 'dismiss'];
      const current = backend.insights.find((item) => item.id === params.id);
      if (!current) {
        return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
      }
      const updated: Insight = { ...current, status, ...changes };
      backend.insights = backend.insights.map((item) => (item.id === updated.id ? updated : item));
      if (body.action === 'mute') {
        backend.mutes = [
          ...backend.mutes,
          makeInsightMute({ subtype: current.subtype, scope: muteScopeOf(current) }),
        ];
      }
      return HttpResponse.json(envelope(updated));
    }),
  );
  return bodies;
}

function card(title: string) {
  return screen.getByRole('article', { name: title });
}

/** The value shown next to a fact label. */
function fact(container: HTMLElement, label: string) {
  const term = within(container).getByText(label, { selector: 'dt' });
  const value = term.nextElementSibling;
  if (!(value instanceof HTMLElement)) throw new Error(`no value for ${label}`);
  return value;
}

describe('InsightsPage', () => {
  beforeEach(() => {
    server.use(...shellHandlers());
  });

  it('lists rule-based insights with the explanation and the facts behind them', async () => {
    const backend = insightsBackend([makeInsight(), makeOverspendInsight(), makeCashFlowInsight()]);
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    expect(document.title).toBe('Insights · Montra');
    expect(await screen.findByText('3 insights')).toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 2, name: 'Active insights' })).toBeInTheDocument();

    const unusual = card('Unusually large Groceries expense');
    expect(within(unusual).getByText('Worth a look')).toBeInTheDocument();
    expect(within(unusual).getByText('Unusual activity')).toBeInTheDocument();
    expect(
      within(unusual).getByText(/is about 5.2× your usual Groceries transaction/),
    ).toBeVisible();
    expect(within(unusual).getByText(/Noticed November 4, 2026/)).toBeInTheDocument();
    expect(within(unusual).getByRole('link', { name: 'Open the transaction' })).toHaveAttribute(
      'href',
      `/transactions/${TX_GROCERIES}`,
    );

    await user.click(within(unusual).getByRole('button', { name: 'The numbers behind this' }));
    expect(fact(unusual, 'Amount')).toHaveTextContent('₹5,200.00');
    expect(fact(unusual, 'Usual amount (median)')).toHaveTextContent('₹1,000.00');
    expect(fact(unusual, 'Top of the usual range (95th percentile)')).toHaveTextContent(
      '₹2,400.00',
    );
    expect(fact(unusual, 'Transactions compared')).toHaveTextContent('12');
    expect(fact(unusual, 'Period checked')).toHaveTextContent('180 days');
    expect(fact(unusual, 'Period')).toHaveTextContent('Nov 3, 2026');
    // The rule is named by rule_code in the interface language.
    expect(fact(unusual, 'Rule used')).toHaveTextContent(
      'Amount at least 3× the usual (median) and above the 95th percentile',
    );
    expect(fact(unusual, 'How sure the rule is')).toHaveTextContent('60%');
    expect(fact(unusual, 'Found by')).toHaveTextContent(
      'Montra’s fixed rules, using only your own history',
    );

    // A savings suggestion shows the periods it is based on.
    const overspend = card('Dining out budget exceeded in 2 of the last 3 periods');
    expect(within(overspend).getByText('Savings idea')).toBeInTheDocument();
    expect(within(overspend).getByRole('link', { name: 'Open the budget' })).toHaveAttribute(
      'href',
      `/budgets/${BUDGET_DINING}`,
    );
    await user.click(within(overspend).getByRole('button', { name: 'The numbers behind this' }));
    const table = within(overspend).getByRole('table', { name: 'Recent budget periods' });
    const rows = within(table).getAllByRole('row');
    expect(rows).toHaveLength(4);
    expect(rows[1]).toHaveTextContent('Oct 1 – 31, 2026₹1,000.00₹1,500.00');
    expect(fact(overspend, 'Average amount over the limit')).toHaveTextContent('₹400.00');
    expect(fact(overspend, 'Assumptions')).toHaveTextContent('Past periods only');

    // Amounts in another currency keep it.
    const cashFlow = card('Last month’s cash flow changed');
    await user.click(within(cashFlow).getByRole('button', { name: 'The numbers behind this' }));
    expect(fact(cashFlow, 'Spending')).toHaveTextContent('$1,250.00');
    expect(fact(cashFlow, 'Usual spending')).toHaveTextContent('$900.00');
    expect(within(cashFlow).getByRole('link', { name: 'Open analytics' })).toHaveAttribute(
      'href',
      '/analytics',
    );

    // Rule-based insights are never presented as AI, and no AI endpoint is called.
    expect(screen.queryByText(/\bAI\b/)).not.toBeInTheDocument();
    expect(backend.ai).toBe(0);
    // Mute rules come from GET /insights/mutes, not from a second full list.
    expect(backend.calls).toEqual([{}]);
  });

  it('shows a calm empty state', async () => {
    insightsBackend([]);
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    expect(await screen.findByText('No insights right now')).toBeInTheDocument();
    expect(screen.getByText(/Montra checks your history once a day/)).toBeInTheDocument();
    expect(await screen.findByText('You haven’t muted any insight types.')).toBeInTheDocument();
  });

  it('shows an error with a retry', async () => {
    let fail = true;
    server.use(
      http.get(`${API}/insights`, ({ request }) => {
        const all = new URL(request.url).searchParams.get('all') === 'true';
        if (fail && !all) {
          return HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-9' }), {
            status: 500,
          });
        }
        return HttpResponse.json(insightPage(all ? [] : [makeInsight()]));
      }),
      http.get(`${API}/insights/mutes`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    expect(await screen.findByText('We couldn’t load your insights')).toBeInTheDocument();
    expect(screen.getByText('req-9')).toBeInTheDocument();

    fail = false;
    await user.click(screen.getByRole('button', { name: 'Try again' }));
    expect(
      await screen.findByRole('article', { name: 'Unusually large Groceries expense' }),
    ).toBeVisible();
  });

  it('shows permission denied when the API refuses', async () => {
    server.use(
      http.get(`${API}/insights`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
      http.get(`${API}/insights/mutes`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    expect((await screen.findAllByText('You don’t have access to this')).length).toBeGreaterThan(0);
  });

  it('dismisses an insight and moves focus to the list', async () => {
    const backend = insightsBackend([makeInsight(), makeOverspendInsight()]);
    const bodies = actionsBackend(backend);
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    const unusual = await screen.findByRole('article', {
      name: 'Unusually large Groceries expense',
    });

    await user.click(
      within(unusual).getByRole('button', { name: 'Dismiss: Unusually large Groceries expense' }),
    );

    expect(await screen.findByText('Insight dismissed')).toBeInTheDocument();
    expect(bodies).toEqual([{ action: 'dismiss' }]);
    await waitFor(() => {
      expect(
        screen.queryByRole('article', { name: 'Unusually large Groceries expense' }),
      ).toBeNull();
    });
    await waitFor(() => {
      expect(screen.getByRole('heading', { level: 2, name: 'Active insights' })).toHaveFocus();
    });
    expect(screen.getByText('1 insight')).toBeInTheDocument();
  });

  it('snoozes for the chosen number of days', async () => {
    const backend = insightsBackend([makeInsight()]);
    const bodies = actionsBackend(backend, { snoozed_until: '2026-12-04T03:30:00Z' });
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    await screen.findByRole('article', { name: 'Unusually large Groceries expense' });

    await user.click(
      screen.getByRole('button', { name: 'Snooze: Unusually large Groceries expense' }),
    );
    await user.click(await screen.findByRole('menuitem', { name: '30 days' }));

    expect(await screen.findByText('Snoozed until December 4, 2026')).toBeInTheDocument();
    expect(bodies).toEqual([{ action: 'snooze', snooze_days: 30 }]);
    expect(await screen.findByText('No insights right now')).toBeInTheDocument();
  });

  it('marks an insight as expected', async () => {
    const backend = insightsBackend([makeInsight()]);
    const bodies = actionsBackend(backend);
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    await screen.findByRole('article', { name: 'Unusually large Groceries expense' });

    await user.click(
      screen.getByRole('button', { name: 'More actions: Unusually large Groceries expense' }),
    );
    await user.click(await screen.findByRole('menuitem', { name: 'Mark as expected' }));

    expect(await screen.findByText('Marked as expected')).toBeInTheDocument();
    expect(bodies).toEqual([{ action: 'expected' }]);
  });

  it('mutes a kind of insight after confirming what it covers', async () => {
    const backend = insightsBackend([makeInsight()]);
    const bodies = actionsBackend(backend);
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    await screen.findByRole('article', { name: 'Unusually large Groceries expense' });

    await user.click(
      screen.getByRole('button', { name: 'More actions: Unusually large Groceries expense' }),
    );
    await user.click(
      await screen.findByRole('menuitem', { name: 'Stop showing insights like this…' }),
    );
    const dialog = await screen.findByRole('dialog', { name: 'Stop showing insights like this?' });
    expect(dialog).toHaveTextContent(
      'Montra won’t show “Unusually large expenses” insights for this category again.',
    );
    expect(bodies).toEqual([]);
    await user.click(within(dialog).getByRole('button', { name: 'Stop showing' }));

    expect(await screen.findByText('Muted. You won’t see insights like this.')).toBeInTheDocument();
    expect(bodies).toEqual([{ action: 'mute' }]);
    // It now appears under the muted insight types.
    expect(
      await screen.findByRole('button', { name: 'Unmute: Unusually large expenses' }),
    ).toBeInTheDocument();
  });

  it('records whether an insight helped, and keeps the answer from the server', async () => {
    const backend = insightsBackend([makeInsight(), makeOverspendInsight()]);
    const feedback: { id: string; body: unknown }[] = [];
    server.use(
      http.post(`${API}/insights/:id/feedback`, async ({ params, request }) => {
        const body = (await request.json()) as { feedback: 'helpful'; note?: string };
        feedback.push({ id: String(params.id), body });
        const current = backend.insights.find((item) => item.id === params.id);
        if (!current) return HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 });
        // The API answers with the insight and its my_feedback (one answer per person).
        const updated: Insight = {
          ...current,
          my_feedback: makeFeedback({ ...body, updated_at: new Date().toISOString() }),
        };
        backend.insights = backend.insights.map((item) =>
          item.id === updated.id ? updated : item,
        );
        return HttpResponse.json(envelope(updated));
      }),
    );
    const user = userEvent.setup();
    const { unmount } = renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    const unusual = await screen.findByRole('article', {
      name: 'Unusually large Groceries expense',
    });

    await user.click(within(unusual).getByRole('button', { name: 'Yes' }));
    const thanks = await within(unusual).findByText(/You said this was useful/);
    await waitFor(() => {
      expect(thanks).toHaveFocus();
    });
    expect(within(unusual).queryByRole('button', { name: 'Yes' })).not.toBeInTheDocument();

    const overspend = card('Dining out budget exceeded in 2 of the last 3 periods');
    await user.click(within(overspend).getByRole('button', { name: 'Something’s wrong' }));
    const dialog = await screen.findByRole('dialog', { name: 'What’s wrong with this insight?' });
    expect(dialog).toHaveTextContent('Please don’t include card numbers, PINs or passwords.');
    await user.type(within(dialog).getByLabelText(/What should we know/), '  I raised the limit  ');
    await user.click(within(dialog).getByRole('button', { name: 'Send feedback' }));

    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    });
    expect(feedback).toEqual([
      { id: INSIGHT_UNUSUAL, body: { feedback: 'helpful' } },
      { id: INSIGHT_OVERSPEND, body: { feedback: 'incorrect', note: 'I raised the limit' } },
    ]);
    expect(
      await within(overspend).findByText(/You told us something was wrong with it/),
    ).toBeInTheDocument();

    // The answer comes back from the server on the next visit (my_feedback).
    unmount();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    const again = await screen.findByRole('article', { name: 'Unusually large Groceries expense' });
    expect(within(again).getByText(/You said this was useful/)).toBeInTheDocument();

    // Answering again replaces the earlier answer.
    await user.click(within(again).getByRole('button', { name: 'Change your answer' }));
    await user.click(within(again).getByRole('button', { name: 'No' }));
    expect(await within(again).findByText(/You said this wasn’t useful/)).toBeInTheDocument();
    expect(feedback.at(-1)).toEqual({ id: INSIGHT_UNUSUAL, body: { feedback: 'not_helpful' } });
  });

  it('lists mute rules from the API and unmutes one, reopening what it covered', async () => {
    const backend = insightsBackend(
      [makeInsight({ status: 'muted' }), makePriceInsight({ status: 'muted' })],
      [
        makeInsightMute(),
        makeInsightMute({ subtype: 'cash_flow_change', scope: '*' }),
        makeInsightMute({
          subtype: 'subscription_price_increase',
          scope: makePriceInsight().evidence.scope as string,
        }),
      ],
    );
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    expect(await screen.findByText('No insights right now')).toBeInTheDocument();
    const muted = screen.getByRole('region', { name: 'Muted insight types' });
    expect(await within(muted).findByText('Unusually large expenses')).toBeInTheDocument();
    expect(
      within(muted).getByText(/For one category · Muted November 3, 2026/),
    ).toBeInTheDocument();
    expect(within(muted).getByText('Changes in monthly cash flow')).toBeInTheDocument();
    expect(within(muted).getByText(/Everywhere/)).toBeInTheDocument();
    expect(within(muted).getByText(/For one subscription/)).toBeInTheDocument();

    await user.click(
      within(muted).getByRole('button', { name: 'Unmute: Unusually large expenses' }),
    );

    // The API reports how many insights it reopened (no per-insight reopen calls).
    expect(await screen.findByText('Unmuted. 1 insight is back in your list.')).toBeInTheDocument();
    expect(backend.calls).toContainEqual({ unmute: `unusual_amount|${CATEGORY_GROCERIES}` });
    expect(
      await screen.findByRole('article', { name: 'Unusually large Groceries expense' }),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(
        within(muted).queryByRole('button', { name: 'Unmute: Unusually large expenses' }),
      ).not.toBeInTheDocument();
    });
    expect(backend.insights.map((item) => item.status)).toEqual(['active', 'muted']);
  });

  it('unmutes a rule that covered nothing still muted', async () => {
    insightsBackend([], [makeInsightMute({ subtype: 'cash_flow_change', scope: '*' })]);
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    await user.click(
      await screen.findByRole('button', { name: 'Unmute: Changes in monthly cash flow' }),
    );
    expect(
      await screen.findByText('Unmuted. Insights like this will show again.'),
    ).toBeInTheDocument();
    expect(await screen.findByText('You haven’t muted any insight types.')).toBeInTheDocument();
  });

  it('finishes unmuting when the rule was already removed', async () => {
    insightsBackend([makeInsight({ status: 'muted' })], [makeInsightMute()]);
    server.use(
      http.delete(`${API}/insights/mutes`, () =>
        HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    await user.click(
      await screen.findByRole('button', { name: 'Unmute: Unusually large expenses' }),
    );
    expect(
      await screen.findByText('Unmuted. Insights like this will show again.'),
    ).toBeInTheDocument();
  });

  it('unmutes from a muted card, bringing back everything that rule muted', async () => {
    const second = makeLegacyInsight({
      id: 'c3c3c3c3-0000-4000-8000-000000000009',
      title: 'Unusually large Groceries expense again',
      status: 'muted',
    });
    const backend = insightsBackend(
      [makeInsight({ status: 'muted' }), second],
      [makeInsightMute()],
    );
    const bodies = actionsBackend(backend);
    const user = userEvent.setup();
    renderRoute('/insights?show=all', { user: user0() });
    await findPageHeading('Insights');
    const muted = await screen.findByRole('article', { name: 'Unusually large Groceries expense' });
    expect(within(muted).getByText('Muted')).toBeInTheDocument();

    await user.click(
      within(muted).getByRole('button', { name: 'Unmute: Unusually large Groceries expense' }),
    );

    expect(
      await screen.findByText('Unmuted. 2 insights are back in your list.'),
    ).toBeInTheDocument();
    expect(backend.calls).toContainEqual({ unmute: `unusual_amount|${CATEGORY_GROCERIES}` });
    expect(bodies).toEqual([]);
    expect(backend.insights.map((item) => item.status)).toEqual(['active', 'active']);
  });

  it('shows insights in the interface language from message codes, with server money', async () => {
    insightsBackend([
      makePriceInsight({ title: 'English title', body: 'English body' }),
      makeCashFlowInsight({ title: 'English cash title', body: 'English cash body' }),
      makeLegacyInsight(),
      makeInsight({
        id: 'c1c1c1c1-0000-4000-8000-000000000098',
        message_code: 'brand_new_rule',
        title: 'Server-only title',
        body: 'Server-only body',
      }),
    ]);
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    const price = await screen.findByRole('article', { name: 'StreamBox costs more' });
    expect(
      within(price).getByText(
        'StreamBox went from ₹499.00 to ₹649.00 per billing cycle (Monthly), 30.06% more, on Nov 1, 2026.',
      ),
    ).toBeInTheDocument();
    const cash = screen.getByRole('article', { name: 'Last month’s cash flow changed' });
    expect(
      within(cash).getByText(
        /In October 2026, spending was \$1,250.00 against your usual \$900.00/,
      ),
    ).toBeInTheDocument();
    // No code, or a code this client does not know: the server's English text.
    expect(screen.getByRole('article', { name: 'Unusually large Fuel expense' })).toHaveTextContent(
      'An older insight with English text only.',
    );
    expect(screen.getByRole('article', { name: 'Server-only title' })).toHaveTextContent(
      'Server-only body',
    );
  });

  it('loads more insights page by page', async () => {
    const queries: Record<string, string>[] = [];
    server.use(
      http.get(`${API}/insights`, ({ request }) => {
        const params = Object.fromEntries(new URL(request.url).searchParams);
        if (params.all === 'true') return HttpResponse.json(insightPage([]));
        queries.push(params);
        return params.cursor === 'page-2'
          ? HttpResponse.json(insightPage([makeOverspendInsight()]))
          : HttpResponse.json(insightPage([makeInsight()], 'page-2'));
      }),
      http.get(`${API}/insights/mutes`, () => HttpResponse.json(envelope([]))),
    );
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    await screen.findByRole('article', { name: 'Unusually large Groceries expense' });
    expect(screen.getByText('1 insight so far')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Load more' }));
    expect(
      await screen.findByRole('article', {
        name: 'Dining out budget exceeded in 2 of the last 3 periods',
      }),
    ).toBeInTheDocument();
    expect(queries).toEqual([{}, { cursor: 'page-2' }]);
    expect(screen.queryByRole('button', { name: 'Load more' })).not.toBeInTheDocument();
    expect(screen.getByText('2 insights')).toBeInTheDocument();
  });

  it('filters by type, shows earlier insights and can show one again', async () => {
    const backend = insightsBackend([makeInsight(), makeOverspendInsight({ status: 'dismissed' })]);
    const bodies = actionsBackend(backend);
    const user = userEvent.setup();
    const { router } = renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    await screen.findByRole('article', { name: 'Unusually large Groceries expense' });

    await user.selectOptions(screen.getByRole('combobox', { name: 'Type' }), 'savings');
    expect(await screen.findByText('No insights of this type')).toBeInTheDocument();
    expect(backend.calls).toContainEqual({ kind: 'savings' });

    await user.click(screen.getByRole('radio', { name: 'All, including dismissed and muted' }));
    const overspend = await screen.findByRole('article', {
      name: 'Dining out budget exceeded in 2 of the last 3 periods',
    });
    expect(backend.calls).toContainEqual({ all: 'true', kind: 'savings' });
    expect(router.state.location.search).toBe('?show=all&kind=savings');
    expect(screen.getByRole('heading', { level: 2, name: 'All insights' })).toBeInTheDocument();
    expect(within(overspend).getByText('Dismissed')).toBeInTheDocument();

    await user.click(
      within(overspend).getByRole('button', {
        name: 'Show again: Dining out budget exceeded in 2 of the last 3 periods',
      }),
    );
    expect(await screen.findByText('The insight is back in your list')).toBeInTheDocument();
    expect(bodies).toEqual([{ action: 'reopen' }]);
    await waitFor(() => {
      expect(within(overspend).queryByText('Dismissed')).not.toBeInTheDocument();
    });
  });

  it('explains when an insight is gone or an action fails', async () => {
    insightsBackend([makeInsight(), makeOverspendInsight()]);
    let answer: 'gone' | 'error' = 'gone';
    server.use(
      http.post(`${API}/insights/:id/actions`, () =>
        answer === 'gone'
          ? HttpResponse.json(errorBody({ code: 'NOT_FOUND' }), { status: 404 })
          : HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR' }), { status: 500 }),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/insights', { user: user0() });
    await findPageHeading('Insights');
    await screen.findByRole('article', { name: 'Unusually large Groceries expense' });

    await user.click(
      screen.getByRole('button', { name: 'Dismiss: Unusually large Groceries expense' }),
    );
    expect(await screen.findByText('This insight is no longer available')).toBeInTheDocument();

    answer = 'error';
    await user.click(
      screen.getByRole('button', {
        name: 'Dismiss: Dining out budget exceeded in 2 of the last 3 periods',
      }),
    );
    expect(await screen.findByText('Couldn’t update the insight')).toBeInTheDocument();
  });
});
