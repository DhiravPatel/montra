import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { describe, expect, it } from 'vitest';
import { API, envelope, errorBody, makeUser } from '@/tests/fixtures';
import {
  CATEGORY_FOOD,
  CATEGORY_FRUIT,
  CATEGORY_GROCERIES,
  CATEGORY_OLD,
  CATEGORY_TRAVEL,
  archivedCategory,
  makeMergeAffected,
  organizeCategories,
} from '@/tests/categoriesFixtures';
import { makeCategory } from '@/tests/financeFixtures';
import { testBackend } from '@/tests/msw/backend';
import { server } from '@/tests/msw/server';
import { findPageHeading, renderRoute } from '@/tests/render';

function signedIn() {
  return makeUser({ onboarding_completed: true });
}

async function openRowMenu(user: ReturnType<typeof userEvent.setup>, name: string) {
  await user.click(await screen.findByRole('button', { name: `Actions for ${name}` }));
  return screen.findByRole('menu');
}

describe('CategoriesPage', () => {
  it('shows parents with their subcategories, kinds and transaction counts', async () => {
    testBackend.categories = organizeCategories();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');

    expect(await screen.findByText('Groceries')).toBeInTheDocument();
    expect(screen.getByText('Spending · 12 transactions')).toBeInTheDocument();
    expect(screen.getByText('Income · 0 transactions')).toBeInTheDocument();
    const subcategories = screen.getByRole('list', { name: 'Subcategories of Groceries' });
    expect(within(subcategories).getByText('Fruit')).toBeInTheDocument();
    // The organize area has its own tabs.
    const tabs = screen.getByRole('navigation', { name: 'Organize' });
    expect(within(tabs).getByRole('link', { name: 'Categories' })).toHaveAttribute(
      'aria-current',
      'page',
    );
  });

  it('adds a subcategory from a category’s menu', async () => {
    testBackend.categories = organizeCategories();
    let body: unknown;
    server.use(
      http.post(`${API}/categories`, async ({ request }) => {
        body = await request.json();
        return HttpResponse.json(
          envelope(
            makeCategory({ id: 'new-id', name: 'Vegetables', parent_id: CATEGORY_GROCERIES }),
          ),
          { status: 201 },
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    await openRowMenu(user, 'Groceries');
    await user.click(screen.getByRole('menuitem', { name: 'Add subcategory' }));

    const dialog = await screen.findByRole('dialog', { name: 'Add a subcategory' });
    expect(within(dialog).getByLabelText('Parent category')).toHaveValue(CATEGORY_GROCERIES);
    await user.click(within(dialog).getByRole('button', { name: 'Add category' }));
    expect(await within(dialog).findByText('Enter a name.')).toBeInTheDocument();
    expect(body).toBeUndefined();

    await user.type(within(dialog).getByLabelText('Name'), 'Vegetables');
    await user.click(within(dialog).getByRole('radio', { name: 'Green' }));
    await user.click(within(dialog).getByRole('button', { name: 'Add category' }));
    expect(await screen.findByText('Category added')).toBeInTheDocument();
    expect(body).toEqual({
      name: 'Vegetables',
      kind: 'expense',
      include_in_budgets: true,
      parent_id: CATEGORY_GROCERIES,
      color: '#16A34A',
    });
  });

  it('sends only what changed and reloads the category after a version conflict', async () => {
    testBackend.categories = organizeCategories();
    const bodies: unknown[] = [];
    const reloads: string[] = [];
    server.use(
      http.patch(`${API}/categories/:id`, async ({ request }) => {
        bodies.push(await request.json());
        if (bodies.length === 1) {
          // Someone renamed it meanwhile.
          testBackend.categories = testBackend.categories.map((category) =>
            category.id === CATEGORY_GROCERIES
              ? { ...category, name: 'Grocery', system_key: undefined, version: 2 }
              : category,
          );
          return HttpResponse.json(errorBody({ code: 'VERSION_CONFLICT' }), { status: 409 });
        }
        return HttpResponse.json(envelope(makeCategory({ name: 'Groceries & home', version: 3 })));
      }),
      // The latest version is read with GET /categories/{id}.
      http.get(`${API}/categories/:id`, ({ params }) => {
        reloads.push(String(params.id));
        return HttpResponse.json(
          envelope(testBackend.categories.find((category) => category.id === params.id)),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    await openRowMenu(user, 'Groceries');
    await user.click(screen.getByRole('menuitem', { name: 'Edit' }));

    const dialog = await screen.findByRole('dialog', { name: 'Edit category' });
    // A category with subcategories stays at the top level.
    expect(within(dialog).getByLabelText('Parent category')).toBeDisabled();
    const name = within(dialog).getByLabelText('Name');
    await user.clear(name);
    await user.type(name, 'Groceries & home');
    await user.click(within(dialog).getByLabelText('Count in budgets'));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => {
      expect(bodies).toHaveLength(1);
    });
    expect(bodies[0]).toEqual({
      version: 1,
      name: 'Groceries & home',
      include_in_budgets: false,
    });

    expect(
      await within(dialog).findByText(/This category was changed somewhere else/),
    ).toBeInTheDocument();
    await waitFor(() => {
      expect(within(dialog).getByLabelText('Name')).toHaveValue('Grocery');
    });
    const reloaded = within(dialog).getByLabelText('Name');
    await user.clear(reloaded);
    await user.type(reloaded, 'Groceries & home');
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Category updated')).toBeInTheDocument();
    expect(bodies[1]).toEqual({ version: 2, name: 'Groceries & home' });
    expect(reloads).toEqual([CATEGORY_GROCERIES]);
  });

  it('removes a category’s color and icon', async () => {
    testBackend.categories = organizeCategories().map((category) =>
      category.id === CATEGORY_FOOD
        ? { ...category, color: '#DC2626', icon: 'restaurant' }
        : category,
    );
    let patched: unknown;
    server.use(
      http.patch(`${API}/categories/:id`, async ({ request }) => {
        patched = await request.json();
        return HttpResponse.json(envelope(makeCategory({ id: CATEGORY_FOOD, version: 2 })));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    await openRowMenu(user, 'Food & dining');
    await user.click(screen.getByRole('menuitem', { name: 'Edit' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit category' });
    expect(within(dialog).getByRole('radio', { name: 'Red' })).toBeChecked();
    await user.click(within(dialog).getByRole('radio', { name: 'No color' }));
    await user.click(within(dialog).getByLabelText('Remove the saved icon'));
    await user.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Category updated')).toBeInTheDocument();
    expect(patched).toEqual({ version: 1, clear_color: true, icon: '' });
  });

  it('explains a name that is already used', async () => {
    testBackend.categories = organizeCategories();
    server.use(
      http.post(`${API}/categories`, () =>
        HttpResponse.json(
          errorBody({
            code: 'CONFLICT',
            details: [
              {
                message: 'A category with this name already exists at this level.',
                code: 'name_taken',
                params: { name: 'Travel' },
              },
            ],
          }),
          { status: 409 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    await user.click(await screen.findByRole('button', { name: 'Add category' }));
    const dialog = await screen.findByRole('dialog', { name: 'Add a category' });
    await user.type(within(dialog).getByLabelText('Name'), 'travel');
    await user.click(within(dialog).getByRole('button', { name: 'Add category' }));
    expect(
      await within(dialog).findByText('A category called “Travel” already exists at this level.'),
    ).toBeInTheDocument();
  });

  it('archives a category after confirmation and restores archived ones', async () => {
    testBackend.categories = [...organizeCategories(), archivedCategory()];
    const calls: string[] = [];
    server.use(
      http.post(`${API}/categories/:id/archive`, ({ params }) => {
        calls.push(`archive:${String(params.id)}`);
        return HttpResponse.json(envelope(makeCategory({ id: CATEGORY_FOOD, status: 'archived' })));
      }),
      http.post(`${API}/categories/:id/restore`, ({ params }) => {
        calls.push(`restore:${String(params.id)}`);
        return HttpResponse.json(envelope(archivedCategory()));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    await openRowMenu(user, 'Food & dining');
    await user.click(screen.getByRole('menuitem', { name: 'Archive' }));
    const confirm = await screen.findByRole('dialog', { name: 'Archive this category?' });
    expect(within(confirm).getByText(/Food & dining won’t be offered/)).toBeInTheDocument();
    await user.click(within(confirm).getByRole('button', { name: 'Archive' }));
    expect(await screen.findByText('Category archived')).toBeInTheDocument();
    expect(calls).toEqual([`archive:${CATEGORY_FOOD}`]);

    expect(screen.queryByText('Old hobby')).not.toBeInTheDocument();
    await user.click(screen.getByLabelText('Show archived'));
    await user.click(await screen.findByRole('button', { name: 'Restore: Old hobby' }));
    expect(await screen.findByText('Category restored')).toBeInTheDocument();
    expect(calls).toContain(`restore:${CATEGORY_OLD}`);
  });

  it('offers delete only for unused categories and explains a refusal with counts', async () => {
    testBackend.categories = organizeCategories();
    let attempts = 0;
    server.use(
      http.delete(`${API}/categories/:id`, () => {
        attempts += 1;
        if (attempts === 1) {
          return HttpResponse.json(
            errorBody({
              code: 'CONFLICT',
              details: [
                {
                  message: 'This category is used by existing records.',
                  code: 'category_in_use',
                  // Non-zero reference counts, as decimal strings.
                  params: { rules: '2', budget_filters: '1' },
                },
              ],
            }),
            { status: 409 },
          );
        }
        return HttpResponse.json(envelope({ ok: true }));
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');

    let menu = await openRowMenu(user, 'Groceries');
    expect(within(menu).queryByRole('menuitem', { name: 'Delete' })).not.toBeInTheDocument();
    await user.keyboard('{Escape}');

    menu = await openRowMenu(user, 'Travel');
    await user.click(within(menu).getByRole('menuitem', { name: 'Delete' }));
    const confirm = await screen.findByRole('dialog', { name: 'Delete this category?' });
    await user.click(within(confirm).getByRole('button', { name: 'Delete' }));
    expect(
      await within(confirm).findByText(
        'This category is still used by 2 category rules and 1 budget that leaves it out. Archive it or merge it into another category instead.',
      ),
    ).toBeInTheDocument();
    await user.click(within(confirm).getByRole('button', { name: 'Delete' }));
    expect(await screen.findByText('Category deleted')).toBeInTheDocument();
    expect(attempts).toBe(2);
    expect(CATEGORY_TRAVEL).toBeTruthy();
  });

  it('merges categories after showing what will move', async () => {
    testBackend.categories = organizeCategories();
    const bodies: unknown[] = [];
    server.use(
      http.post(`${API}/categories/merge`, async ({ request }) => {
        const body = (await request.json()) as { preview?: boolean };
        bodies.push(body);
        return HttpResponse.json(
          envelope({
            preview: body.preview ?? false,
            affected: makeMergeAffected({ transactions: 12, subcategories: 1, budget_filters: 2 }),
          }),
        );
      }),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    await user.click(screen.getByRole('button', { name: 'Merge categories' }));
    const dialog = await screen.findByRole('dialog', { name: 'Merge categories' });

    await user.click(within(dialog).getByRole('button', { name: 'Check what will change' }));
    expect(within(dialog).getByText('Choose the category to keep.')).toBeInTheDocument();
    expect(bodies).toHaveLength(0);

    await user.selectOptions(within(dialog).getByLabelText('Keep this category'), CATEGORY_FOOD);
    await user.click(within(dialog).getByRole('checkbox', { name: 'Groceries' }));
    await user.click(within(dialog).getByRole('button', { name: 'Check what will change' }));
    const preview = await within(dialog).findByRole('status', { name: 'What will change' });
    expect(within(preview).getByText('12 transactions')).toBeInTheDocument();
    expect(within(preview).getByText('1 subcategory')).toBeInTheDocument();
    expect(
      within(preview).getByText(
        '2 budget filters (those budgets will leave out Food & dining instead)',
      ),
    ).toBeInTheDocument();
    // Zero counts are not listed.
    expect(within(preview).queryByText(/bills?$/)).not.toBeInTheDocument();
    expect(bodies[0]).toEqual({
      source_ids: [CATEGORY_GROCERIES],
      target_id: CATEGORY_FOOD,
      preview: true,
    });

    await user.click(within(dialog).getByRole('button', { name: 'Merge categories' }));
    expect(await screen.findByText('Categories merged')).toBeInTheDocument();
    expect(bodies[1]).toEqual({
      source_ids: [CATEGORY_GROCERIES],
      target_id: CATEGORY_FOOD,
      preview: false,
    });
  });

  it('says when a merge moves nothing else', async () => {
    testBackend.categories = organizeCategories();
    server.use(
      http.post(`${API}/categories/merge`, () =>
        HttpResponse.json(envelope({ preview: true, affected: makeMergeAffected() })),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    await user.click(screen.getByRole('button', { name: 'Merge categories' }));
    const dialog = await screen.findByRole('dialog', { name: 'Merge categories' });
    await user.selectOptions(within(dialog).getByLabelText('Keep this category'), CATEGORY_FOOD);
    await user.click(within(dialog).getByRole('checkbox', { name: 'Travel' }));
    await user.click(within(dialog).getByRole('button', { name: 'Check what will change' }));
    expect(
      await within(dialog).findByText(
        'Nothing uses these categories yet, so only the categories themselves are merged.',
      ),
    ).toBeInTheDocument();
  });

  it('explains when a parent category cannot be merged into a subcategory', async () => {
    testBackend.categories = organizeCategories();
    server.use(
      http.post(`${API}/categories/merge`, () =>
        HttpResponse.json(
          errorBody({
            code: 'DOMAIN_RULE_VIOLATION',
            details: [
              {
                message:
                  'A category with subcategories can only be merged into a top-level category.',
                code: 'merge_target_must_be_top_level',
              },
            ],
          }),
          { status: 422 },
        ),
      ),
    );
    const user = userEvent.setup();
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    await user.click(screen.getByRole('button', { name: 'Merge categories' }));
    const dialog = await screen.findByRole('dialog', { name: 'Merge categories' });
    await user.selectOptions(within(dialog).getByLabelText('Keep this category'), CATEGORY_FRUIT);
    await user.click(within(dialog).getByRole('checkbox', { name: 'Groceries' }));
    await user.click(within(dialog).getByRole('button', { name: 'Check what will change' }));
    expect(
      await within(dialog).findByText(
        'A category with subcategories can only be merged into a top-level category.',
      ),
    ).toBeInTheDocument();
  });

  it('shows a first-use empty state', async () => {
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    expect(await screen.findByText('No categories yet')).toBeInTheDocument();
  });

  it('shows a recoverable error', async () => {
    server.use(
      http.get(`${API}/categories`, () =>
        HttpResponse.json(errorBody({ code: 'INTERNAL_ERROR', request_id: 'req-cat' }), {
          status: 500,
        }),
      ),
    );
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    expect(await screen.findByText('We couldn’t load your categories')).toBeInTheDocument();
    expect(screen.getAllByText('req-cat').length).toBeGreaterThan(0);
  });

  it('shows a permission message when access is denied', async () => {
    server.use(
      http.get(`${API}/categories`, () =>
        HttpResponse.json(errorBody({ code: 'FORBIDDEN' }), { status: 403 }),
      ),
    );
    renderRoute('/categories', { user: signedIn() });
    await findPageHeading('Categories');
    expect(await screen.findByText('You don’t have access to this')).toBeInTheDocument();
  });
});
