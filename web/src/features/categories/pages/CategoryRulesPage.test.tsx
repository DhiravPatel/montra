import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CATEGORY_FOOD,
  CATEGORY_TRAVEL,
  RULE_SWIGGY,
  RULE_UBER,
  makeRule,
  organizeCategories,
} from '@/tests/categoriesFixtures';
import { makeAccount, makeTransaction } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

function useRules(rules: ReturnType<typeof makeRule>[]) {
  server.use(http.get(`${API}/category-rules`, () => HttpResponse.json(envelope(rules))));
}

const taxi = makeRule({
  id: RULE_UBER,
  name: 'Taxi',
  priority: 20,
  enabled: false,
  match_field: 'description',
  match_type: 'starts_with',
  pattern: 'uber',
  set_category_id: CATEGORY_TRAVEL,
  transaction_type: 'expense',
  amount_min: '100.00',
  currency: 'INR',
  apply_to: 'imports',
});

describe('CategoryRulesPage', () => {
  it('lists rules in the order they run with readable summaries', async () => {
    testBackend.categories = organizeCategories();
    useRules([taxi, makeRule()]);
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');

    await screen.findByText('Food delivery');
    const items = screen.getAllByRole('listitem');
    const names = items
      .map((item) => within(item).queryByText(/^(Food delivery|Taxi)$/)?.textContent)
      .filter(Boolean);
    expect(names).toEqual(['Food delivery', 'Taxi']);
    expect(screen.getByText(/Description or merchant contains “swiggy”/)).toBeInTheDocument();
    expect(screen.getByText(/Sets the category to Food & dining/)).toBeInTheDocument();
    expect(screen.getByText(/Description starts with “uber”/)).toBeInTheDocument();
    // Amount bounds are shown in the rule's currency.
    expect(
      screen.getByText('Expenses only · Amount at least ₹100.00 · Imported transactions'),
    ).toBeInTheDocument();
    expect(screen.getByText('Off')).toBeInTheDocument();
    expect(screen.getByText('Priority 10')).toBeInTheDocument();
  });

  it('previews matching transactions and creates the rule', async () => {
    testBackend.categories = organizeCategories();
    testBackend.accounts = [makeAccount()];
    useRules([]);
    const previews: unknown[] = [];
    let created: unknown;
    server.use(
      http.post(`${API}/category-rules/preview`, async ({ request }) => {
        previews.push(await request.json());
        return HttpResponse.json(
          envelope({
            match_count: 3,
            sample: [makeTransaction({ description: 'swiggy dinner', merchant: undefined })],
          }),
        );
      }),
      http.post(`${API}/category-rules`, async ({ request }) => {
        created = await request.json();
        return HttpResponse.json(envelope(makeRule()), { status: 201 });
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    expect(await screen.findByText('No rules yet')).toBeInTheDocument();
    await user.click(screen.getAllByRole('button', { name: 'Add rule' })[0]!);

    const dialog = await screen.findByRole('dialog', { name: 'Add a rule' });
    await user.type(await within(dialog).findByLabelText(/^Rule name/), 'Food delivery');
    await user.type(within(dialog).getByLabelText('Text to match'), 'swiggy');
    await user.selectOptions(within(dialog).getByLabelText('Set the category to'), CATEGORY_FOOD);
    await user.type(within(dialog).getByLabelText(/^Smallest amount/), '100');
    await user.click(within(dialog).getByRole('button', { name: 'Show matching transactions' }));
    expect(await within(dialog).findByText('3 transactions match')).toBeInTheDocument();
    expect(within(dialog).getByText('swiggy dinner')).toBeInTheDocument();
    expect(previews[0]).toEqual({
      only_uncategorized: true,
      rule: {
        name: 'Food delivery',
        match_field: 'any',
        match_type: 'contains',
        pattern: 'swiggy',
        set_category_id: CATEGORY_FOOD,
        apply_to: 'all',
        priority: 100,
        enabled: true,
        amount_min: '100.00',
        currency: 'INR',
      },
    });

    await user.click(within(dialog).getByRole('button', { name: 'Add rule' }));
    expect(await screen.findByText('Rule added')).toBeInTheDocument();
    expect(created).toEqual((previews[0] as { rule: unknown }).rule);
  });

  it('shows a category error from the API on the category field', async () => {
    testBackend.categories = organizeCategories();
    useRules([]);
    server.use(
      http.post(`${API}/category-rules`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.set_category_id', message: 'The category is archived.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    await user.click((await screen.findAllByRole('button', { name: 'Add rule' }))[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Add a rule' });
    await user.type(await within(dialog).findByLabelText(/^Rule name/), 'Rides');
    await user.type(within(dialog).getByLabelText('Text to match'), 'uber');
    await user.selectOptions(within(dialog).getByLabelText('Set the category to'), CATEGORY_TRAVEL);
    await user.click(within(dialog).getByRole('button', { name: 'Add rule' }));
    expect(await within(dialog).findByText('The category is archived.')).toBeInTheDocument();
    expect(within(dialog).getByLabelText('Set the category to')).toHaveAttribute(
      'aria-invalid',
      'true',
    );
  });

  it('shows an invalid pattern on the pattern field', async () => {
    testBackend.categories = organizeCategories();
    useRules([]);
    server.use(
      http.post(`${API}/category-rules/preview`, () =>
        HttpResponse.json(
          errorBody({
            code: 'VALIDATION_ERROR',
            details: [{ field: 'body.rule.pattern', message: 'Invalid regular expression.' }],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    await user.click((await screen.findAllByRole('button', { name: 'Add rule' }))[0]!);
    const dialog = await screen.findByRole('dialog', { name: 'Add a rule' });
    await user.type(await within(dialog).findByLabelText(/^Rule name/), 'Rides');
    await user.selectOptions(within(dialog).getByLabelText('Match when it'), 'regex');
    expect(within(dialog).getByText(/A regular expression/)).toBeInTheDocument();
    await user.type(within(dialog).getByLabelText('Text to match'), '(uber');
    await user.selectOptions(within(dialog).getByLabelText('Set the category to'), CATEGORY_TRAVEL);
    await user.click(within(dialog).getByRole('button', { name: 'Show matching transactions' }));
    expect(
      await within(dialog).findByText('This pattern isn’t a valid regular expression.'),
    ).toBeInTheDocument();
  });

  it('replaces a rule when it is edited, sending its version', async () => {
    testBackend.categories = organizeCategories();
    useRules([makeRule()]);
    let replaced: { id: string; body: unknown } | null = null;
    server.use(
      http.put(`${API}/category-rules/:id`, async ({ params, request }) => {
        replaced = { id: String(params.id), body: await request.json() };
        return HttpResponse.json(envelope(makeRule({ priority: 5, version: 2 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    await user.click(await screen.findByRole('button', { name: 'Edit: Food delivery' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit rule' });
    const priority = await within(dialog).findByLabelText(/^Priority/);
    await user.clear(priority);
    await user.type(priority, '5');
    await user.click(within(dialog).getByLabelText('Rule is on'));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Rule updated')).toBeInTheDocument();
    expect(replaced).toEqual({
      id: RULE_SWIGGY,
      body: {
        name: 'Food delivery',
        match_field: 'any',
        match_type: 'contains',
        pattern: 'swiggy',
        set_category_id: CATEGORY_FOOD,
        apply_to: 'all',
        priority: 5,
        enabled: false,
        version: 1,
      },
    });
  });

  it('keeps a rule’s amounts in its own currency when editing', async () => {
    testBackend.categories = organizeCategories();
    useRules([makeRule({ amount_min: '5.00', amount_max: '20.00', currency: 'USD' })]);
    let replaced: unknown;
    server.use(
      http.put(`${API}/category-rules/:id`, async ({ request }) => {
        replaced = await request.json();
        return HttpResponse.json(envelope(makeRule({ version: 2 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    expect(await screen.findByText(/Amount \$5\.00 to \$20\.00/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Edit: Food delivery' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit rule' });
    expect(await within(dialog).findByLabelText('Currency of the amounts')).toHaveValue('USD');
    const priority = within(dialog).getByLabelText(/^Priority/);
    // An empty priority uses the default (100).
    await user.clear(priority);
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Rule updated')).toBeInTheDocument();
    expect(replaced).toMatchObject({
      amount_min: '5.00',
      amount_max: '20.00',
      currency: 'USD',
      priority: 100,
      version: 1,
    });
  });

  it('reloads the rule after a version conflict', async () => {
    testBackend.categories = organizeCategories();
    let rules = [makeRule()];
    const reloads: string[] = [];
    server.use(
      http.get(`${API}/category-rules`, () => HttpResponse.json(envelope(rules))),
      // The dialog reloads the one rule after the conflict (GET /category-rules/{id}).
      http.get(`${API}/category-rules/:id`, ({ params }) => {
        reloads.push(String(params.id));
        return HttpResponse.json(envelope(rules.find((rule) => rule.id === params.id)));
      }),
    );
    const bodies: { version?: number; name?: string }[] = [];
    server.use(
      http.put(`${API}/category-rules/:id`, async ({ request }) => {
        bodies.push((await request.json()) as { version?: number; name?: string });
        if (bodies.length === 1) {
          // Someone renamed it meanwhile.
          rules = [makeRule({ name: 'Delivery apps', version: 2 })];
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeRule({ version: 3 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    await user.click(await screen.findByRole('button', { name: 'Edit: Food delivery' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit rule' });
    await user.click(await within(dialog).findByLabelText('Rule is on'));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));

    expect(await within(dialog).findByText('This was changed somewhere else')).toBeInTheDocument();
    await waitFor(() => {
      expect(within(dialog).getByLabelText(/^Rule name/)).toHaveValue('Delivery apps');
    });
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Rule updated')).toBeInTheDocument();
    expect(bodies.map((body) => [body.version, body.name])).toEqual([
      [1, 'Food delivery'],
      [2, 'Delivery apps'],
    ]);
    expect(reloads).toEqual([makeRule().id]);
  });

  it('applies a saved rule to past transactions after confirmation', async () => {
    testBackend.categories = organizeCategories();
    useRules([makeRule()]);
    let applied: { id: string; body: unknown } | null = null;
    server.use(
      http.post(`${API}/category-rules/:id/apply`, async ({ params, request }) => {
        applied = { id: String(params.id), body: await request.json() };
        return HttpResponse.json(envelope({ match_count: 5, sample: [] }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    await user.click(await screen.findByRole('button', { name: 'Actions for Food delivery' }));
    await user.click(await screen.findByRole('menuitem', { name: 'Apply to past transactions' }));
    const dialog = await screen.findByRole('dialog', {
      name: 'Apply this rule to past transactions?',
    });
    expect(
      within(dialog).getByText(/Montra will set Food & dining on past transactions/),
    ).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Apply rule' }));
    expect(await screen.findByText('Rule applied to 5 transactions')).toBeInTheDocument();
    expect(applied).toEqual({ id: RULE_SWIGGY, body: { only_uncategorized: true } });
  });

  it('explains when a saved rule’s category is no longer available', async () => {
    testBackend.categories = organizeCategories();
    useRules([makeRule()]);
    server.use(
      http.post(`${API}/category-rules/:id/apply`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message: 'This rule’s category is archived or no longer fits the rule.',
                code: 'rule_category_unavailable',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    await user.click(await screen.findByRole('button', { name: 'Actions for Food delivery' }));
    await user.click(await screen.findByRole('menuitem', { name: 'Apply to past transactions' }));
    const dialog = await screen.findByRole('dialog', {
      name: 'Apply this rule to past transactions?',
    });
    await user.click(within(dialog).getByRole('button', { name: 'Apply rule' }));
    expect(
      await within(dialog).findByText(
        'This rule’s category is archived or no longer fits the rule. Restore the category or choose another one for the rule, then try again.',
      ),
    ).toBeInTheDocument();
  });

  it('deletes a rule after confirmation', async () => {
    testBackend.categories = organizeCategories();
    useRules([makeRule()]);
    let deleted = '';
    server.use(
      http.delete(`${API}/category-rules/:id`, ({ params }) => {
        deleted = String(params.id);
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    await user.click(await screen.findByRole('button', { name: 'Actions for Food delivery' }));
    await user.click(await screen.findByRole('menuitem', { name: 'Delete' }));
    const confirm = await screen.findByRole('dialog', { name: 'Delete this rule?' });
    await user.click(within(confirm).getByRole('button', { name: 'Delete rule' }));
    expect(await screen.findByText('Rule deleted')).toBeInTheDocument();
    await waitFor(() => {
      expect(deleted).toBe(RULE_SWIGGY);
    });
  });

  it('shows a recoverable error', async () => {
    server.use(
      http.get(`${API}/category-rules`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-rules' }), {
          status: 500,
        }),
      ),
    );
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    expect(await screen.findByText('We couldn’t load your rules')).toBeInTheDocument();
    expect(screen.getByText('req-rules')).toBeInTheDocument();
  });

  it('shows a permission message when access is denied', async () => {
    server.use(
      http.get(`${API}/category-rules`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/categories/rules', { user: signedIn() });
    await findPageHeading('Category rules');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
