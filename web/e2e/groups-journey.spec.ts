import type { Page } from '@playwright/test';
import { expect } from './support/test';
import { groupWithMember, joinPath, test } from './support/groups';
import { api, navigateTo, newUser, pageHeading, todayInKolkata } from './support/session';

/**
 * Groups and shared expenses against the local Go API (spec §14 journeys
 * 14-18 and 26): two throwaway people in two browser contexts. Every amount
 * asserted here is computed by the server (shares, balances, suggestions,
 * budget progress); the browser only shows them.
 * Run with: PW_CHANNEL=chrome pnpm e2e
 */

/** A group page's id from the address bar (`/groups/<uuid>…`). */
function groupIdOf(page: Page): string {
  const match = /\/groups\/([0-9a-f-]{36})/.exec(page.url());
  if (!match?.[1]) throw new Error(`No group id in ${page.url()}`);
  return match[1];
}

function groupTab(page: Page, name: string) {
  return page.getByRole('navigation', { name: 'Group pages' }).getByRole('link', { name });
}

/** A row of the expense breakdown or balances table, by the person's name. */
function personRow(page: Page, region: string, person: string) {
  return page
    .getByRole('region', { name: region })
    .getByRole('row')
    .filter({ has: page.getByRole('rowheader', { name: person }) });
}

async function startExpense(page: Page, groupId: string, description: string, amount: string) {
  await page.goto(`/groups/${groupId}/expenses/new`);
  await expect(pageHeading(page, 'Add a shared expense')).toBeVisible();
  await page.getByLabel('Description').fill(description);
  await page.getByLabel('Amount', { exact: true }).fill(amount);
  // Whoever adds it paid the whole amount (the default).
  await expect(page.getByLabel('Paid by', { exact: true })).toHaveValue(/[0-9a-f-]{36}/);
}

async function saveExpense(page: Page, description: string) {
  await page.getByRole('button', { name: 'Add expense' }).click();
  await expect(pageHeading(page, description)).toBeVisible();
  await expect(page.getByText('Expense added').first()).toBeVisible();
}

test('a group from invitation to settling up, then a removed member is shut out', async ({
  page,
  secondPage: ravi,
}) => {
  test.setTimeout(240_000);
  // Asha (owner) in this context, Ravi in his own browser context.
  await newUser(page, 'groupowner', { name: 'Asha Rao' });
  await newUser(ravi, 'groupmember', { name: 'Ravi Kumar' });
  const groupName = `Flat 4B ${Date.now()}`;

  // 14. Asha creates the group from Groups.
  await page.goto('/dashboard');
  await expect(pageHeading(page, 'Home')).toBeVisible();
  await navigateTo(page, 'Groups');
  await expect(pageHeading(page, 'Groups')).toBeVisible();
  await page.getByRole('link', { name: 'Create group' }).first().click();
  await expect(pageHeading(page, 'Create a group')).toBeVisible();
  await page.getByLabel('Group name').fill(groupName);
  await page.getByRole('radio', { name: /^Roommates/ }).check();
  await expect(page.getByLabel('Group currency')).toHaveValue('INR');
  await page.getByRole('button', { name: 'Create group' }).click();
  await expect(pageHeading(page, groupName)).toBeVisible();
  const groupId = groupIdOf(page);

  // 14. …and creates a one-use invitation link in the group's settings.
  await groupTab(page, 'Settings').click();
  await expect(pageHeading(page, 'Group settings')).toBeVisible();
  const invitations = page.getByRole('region', { name: 'Invitations' });
  await expect(invitations.getByRole('radio', { name: 'Shareable link' })).toBeChecked();
  await invitations.getByLabel('Number of uses').selectOption('1');
  await invitations.getByRole('button', { name: 'Create invitation link' }).click();
  await expect(invitations.getByText('Your invitation link is ready')).toBeVisible();
  const link = await invitations.getByRole('textbox', { name: 'Invitation link' }).inputValue();
  expect(link).toMatch(/\/groups\/join#token=.+/);

  // Ravi opens the link, checks who invited him and joins.
  await ravi.goto(joinPath(link));
  await expect(pageHeading(ravi, 'Join a group')).toBeVisible();
  await expect(
    ravi.getByRole('heading', { level: 2, name: `You’re invited to join ${groupName}` }),
  ).toBeVisible();
  await expect(ravi.getByText('Invited by Asha Rao')).toBeVisible();
  await expect(ravi).not.toHaveURL(/token=/);
  await ravi.getByRole('button', { name: 'Join group' }).click();
  await expect(pageHeading(ravi, groupName)).toBeVisible();
  expect(groupIdOf(ravi)).toBe(groupId);

  // The link was single-use: Asha sees it used and Ravi as a member.
  await page.reload();
  await expect(page.getByRole('region', { name: 'Members' }).getByText('Ravi Kumar')).toBeVisible();
  await page
    .getByRole('region', { name: 'Invitations' })
    .getByLabel('Show past invitations')
    .check();
  await expect(
    page.getByRole('region', { name: 'Invitations' }).getByText('Used 1 of 1 time'),
  ).toBeVisible();

  // 15. An equal split: ₹1,000.00 between the two of them.
  await startExpense(page, groupId, 'Groceries', '1000');
  await expect(page.getByRole('radio', { name: 'Equally' })).toBeChecked();
  await expect(page.getByRole('checkbox', { name: 'You (Asha Rao)' })).toBeChecked();
  await expect(page.getByRole('checkbox', { name: 'Ravi Kumar' })).toBeChecked();
  await expect(page.getByText('Split equally between 2 people.')).toBeVisible();
  await saveExpense(page, 'Groceries');
  const split = 'Who paid and each person’s share';
  await expect(personRow(page, split, 'You')).toContainText('₹500.00');
  await expect(personRow(page, split, 'You')).toContainText('₹1,000.00');
  await expect(personRow(page, split, 'Ravi Kumar')).toContainText('₹500.00');

  // 15. An exact split: ₹1,500.00 as ₹600.00 and ₹900.00.
  await startExpense(page, groupId, 'Dinner', '1500');
  await page.getByRole('radio', { name: 'Exact amounts' }).check();
  await page.getByLabel('Amount for You (Asha Rao)').fill('600');
  await page.getByLabel('Amount for Ravi Kumar').fill('900');
  await expect(page.getByText('Adds up to the total.')).toBeVisible();
  await saveExpense(page, 'Dinner');
  await expect(personRow(page, split, 'You')).toContainText('₹600.00');
  await expect(personRow(page, split, 'Ravi Kumar')).toContainText('₹900.00');

  // 15. An itemized split: two items and ₹90.00 of tax shared by item.
  await startExpense(page, groupId, 'Supermarket', '990');
  await page.getByRole('radio', { name: 'By item' }).check();
  const first = page.getByRole('group', { name: 'Item 1' });
  await first.getByLabel('Item', { exact: true }).fill('Snacks');
  await first.getByLabel('Item amount').fill('600');
  await first.getByRole('checkbox', { name: 'You (Asha Rao)' }).check();
  await first.getByRole('checkbox', { name: 'Ravi Kumar' }).check();
  await page.getByRole('button', { name: 'Add an item' }).click();
  const second = page.getByRole('group', { name: 'Item 2' });
  await second.getByLabel('Item', { exact: true }).fill('Shampoo');
  await second.getByLabel('Item amount').fill('300');
  await second.getByRole('checkbox', { name: 'Ravi Kumar' }).check();
  await expect(page.getByText(/Items: ₹900\.00\. The other ₹90\.00/)).toBeVisible();
  await saveExpense(page, 'Supermarket');
  // Items: Asha 300, Ravi 300 + 300; the ₹90.00 follows the items 1:2.
  await expect(personRow(page, split, 'You')).toContainText('₹330.00');
  await expect(personRow(page, split, 'You')).toContainText('₹990.00');
  await expect(personRow(page, split, 'Ravi Kumar')).toContainText('₹660.00');
  const items = page.getByRole('region', { name: split }).getByRole('listitem');
  await expect(items.filter({ hasText: 'Snacks' })).toContainText('Ravi Kumar: ₹300.00');
  await expect(items.filter({ hasText: 'Shampoo' })).toContainText('Ravi Kumar: ₹300.00');

  // Both see the balances: Ravi owes 500 + 900 + 660 = ₹2,060.00.
  await groupTab(page, 'Balances').click();
  await expect(pageHeading(page, 'Balances')).toBeVisible();
  await expect(page.getByText('You’re owed ₹2,060.00')).toBeVisible();
  const everyone = 'Everyone’s balance';
  await expect(personRow(page, everyone, 'You')).toContainText('₹3,490.00');
  await expect(personRow(page, everyone, 'You')).toContainText('₹1,430.00');
  await expect(personRow(page, everyone, 'Ravi Kumar')).toContainText('Owes₹2,060.00');

  await ravi.goto(`/groups/${groupId}/balances`);
  await expect(pageHeading(ravi, 'Balances')).toBeVisible();
  await expect(ravi.getByText('You owe ₹2,060.00')).toBeVisible();
  await expect(personRow(ravi, everyone, 'You')).toContainText('₹2,060.00');

  // 16. The settlement suggestion, on both sides.
  const suggestions = (who: Page) => who.getByRole('region', { name: 'Suggested payments' });
  await expect(suggestions(page).getByRole('listitem')).toHaveCount(1);
  await expect(suggestions(page).getByRole('listitem')).toContainText(
    'Ravi Kumar owes you₹2,060.00',
  );
  await expect(suggestions(ravi).getByRole('listitem')).toContainText('You owe Asha Rao₹2,060.00');

  // 16. Ravi pays part of it back and records it from the suggestion.
  await suggestions(ravi)
    .getByRole('button', { name: 'Record this payment: You to Asha Rao' })
    .click();
  const record = ravi.getByRole('dialog', { name: 'Record a payment' });
  await expect(record.getByLabel('Amount', { exact: true })).toHaveValue(/^2,?060(\.00)?$/);
  await record.getByLabel('Amount', { exact: true }).fill('1000');
  await expect(record.getByRole('radio', { name: /^Yes, it’s paid/ })).toBeChecked();
  await record.getByRole('button', { name: 'Record payment' }).click();
  await expect(record).toBeHidden();
  await expect(ravi.getByText('Payment recorded. It counts once it’s confirmed.')).toBeVisible();
  const payments = (who: Page) => who.getByRole('region', { name: 'Payments' });
  await expect(payments(ravi).getByRole('link', { name: 'You paid Asha Rao' })).toBeVisible();
  await expect(payments(ravi).getByText('Paid, waiting for confirmation')).toBeVisible();
  // Not counted until Asha confirms it.
  await expect(ravi.getByText('You owe ₹2,060.00')).toBeVisible();
  await expect(
    ravi.getByText('₹1,000.00 you reported paying is waiting for confirmation.'),
  ).toBeVisible();

  // 17. Asha confirms she received it.
  await page.reload();
  await expect(
    page.getByText('₹1,000.00 reported paid to you is waiting for your confirmation.'),
  ).toBeVisible();
  await payments(page).getByRole('link', { name: 'Ravi Kumar paid you' }).click();
  await expect(pageHeading(page, 'Payment')).toBeVisible();
  await expect(page.getByText('Not counted yet')).toBeVisible();
  await expect(
    page.getByText('Reported by members. Montra didn’t verify or move this money.'),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Confirm I received it' }).click();
  const confirm = page.getByRole('dialog', { name: 'Confirm you received it?' });
  await confirm.getByRole('button', { name: 'Confirm', exact: true }).click();
  await expect(confirm).toBeHidden();
  await expect(page.getByText('Payment confirmed').first()).toBeVisible();
  await expect(page.getByText('Counts toward balances')).toBeVisible();
  await expect(page.getByText(/^Confirmed receiving it/)).toBeVisible();

  // The confirmed ₹1,000.00 counts: ₹1,060.00 is left, on both sides.
  await groupTab(page, 'Balances').click();
  await expect(page.getByText('You’re owed ₹1,060.00')).toBeVisible();
  await expect(suggestions(page).getByRole('listitem')).toContainText(
    'Ravi Kumar owes you₹1,060.00',
  );
  await expect(personRow(page, everyone, 'Ravi Kumar')).toContainText('₹1,000.00');
  await ravi.reload();
  await expect(ravi.getByText('You owe ₹1,060.00')).toBeVisible();
  await expect(payments(ravi).getByText('Confirmed', { exact: true })).toBeVisible();
  const balances = await api<{ my_net: { amount: string } }>(
    page,
    'GET',
    `/groups/${groupId}/balances`,
  );
  expect(balances.my_net.amount).toBe('1060.00');

  // 26. Asha removes Ravi (his open balance stays in the records)…
  await groupTab(page, 'Settings').click();
  await expect(pageHeading(page, 'Group settings')).toBeVisible();
  await page
    .getByRole('region', { name: 'Members' })
    .getByRole('button', { name: 'Remove: Ravi Kumar' })
    .click();
  const remove = page.getByRole('dialog', { name: 'Remove Ravi Kumar?' });
  await remove.getByRole('button', { name: 'Remove from group' }).click();
  await expect(remove).toBeHidden();
  await expect(page.getByText('Ravi Kumar was removed from the group')).toBeVisible();
  await groupTab(page, 'Balances').click();
  await expect(personRow(page, everyone, 'Ravi Kumar')).toContainText('Removed from the group');
  await expect(personRow(page, everyone, 'Ravi Kumar')).toContainText('Owes₹1,060.00');

  // …and Ravi is denied: the pages show the group as unavailable…
  await ravi.goto(`/groups/${groupId}`);
  await expect(
    ravi.getByRole('heading', { level: 2, name: 'This group isn’t available' }),
  ).toBeVisible();
  await expect(ravi.getByText(groupName)).toHaveCount(0);
  await ravi.goto(`/groups/${groupId}/balances`);
  await expect(ravi.getByRole('heading', { level: 2, name: 'Group not found' })).toBeVisible();
  await expect(ravi.getByText('₹1,060.00')).toHaveCount(0);

  // …and the API refuses every read and write.
  const denied = [403, 404];
  for (const path of ['', '/balances', '/expenses', '/settlements', '/settlement-suggestions']) {
    const response = await ravi.request.get(`/api/v1/groups/${groupId}${path}`, {
      headers: { 'X-Montra-Client': 'web' },
    });
    expect(denied, `GET /groups/{id}${path} → ${response.status()}`).toContain(response.status());
  }
  const csrf = (await ravi.context().cookies()).find((cookie) => cookie.name === 'montra_csrf');
  const write = await ravi.request.post(`/api/v1/groups/${groupId}/expenses`, {
    headers: {
      'X-Montra-Client': 'web',
      'X-CSRF-Token': csrf ? decodeURIComponent(csrf.value) : '',
      'Idempotency-Key': `e2e-${crypto.randomUUID()}`,
    },
    data: {
      description: 'Sneaky',
      amount: '10',
      split_method: 'equal',
      participants: [{ user_id: groupId }],
    },
  });
  expect(denied, `POST /groups/{id}/expenses → ${write.status()}`).toContain(write.status());
});

/** Setup for the household journeys: two members and two shared bills (₹2,000.50). */
async function household(page: Page, ravi: Page, name: string) {
  const asha = await newUser(page, 'homeowner', { name: 'Asha Rao' });
  const raviUser = await newUser(ravi, 'homemember', { name: 'Ravi Kumar' });
  const groupId = await groupWithMember(page, ravi, { name, group_type: 'household' });
  const both = [{ user_id: asha.id }, { user_id: raviUser.id }];
  await api(page, 'POST', `/groups/${groupId}/expenses`, {
    description: 'Electricity',
    amount: '1200',
    split_method: 'equal',
    participants: both,
    payers: [{ user_id: asha.id, amount: '1200' }],
  });
  await api(ravi, 'POST', `/groups/${groupId}/expenses`, {
    description: 'Groceries',
    amount: '800.50',
    split_method: 'equal',
    participants: both,
    payers: [{ user_id: raviUser.id, amount: '800.50' }],
  });
  return groupId;
}

test('a household budget counts every member’s shared expenses', async ({
  page,
  secondPage: ravi,
}) => {
  test.setTimeout(180_000);
  const name = `Home ${Date.now()}`;
  const groupId = await household(page, ravi, name);

  // 18. Asha creates a monthly budget for the household.
  await page.goto('/dashboard');
  await expect(pageHeading(page, 'Home')).toBeVisible();
  await navigateTo(page, 'Budgets');
  await page.getByRole('link', { name: 'Create budget' }).first().click();
  await expect(pageHeading(page, 'Create a budget')).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill('Household spending');
  await page.getByLabel(/^Track a group’s shared expenses/).selectOption({ label: name });
  await expect(page.getByText('Group budgets use the group’s currency.')).toBeVisible();
  await expect(page.getByRole('radio', { name: /^Group members/ })).toBeChecked();
  await page.getByRole('radio', { name: /^Overall/ }).check();
  await page.getByLabel('Period', { exact: true }).selectOption('monthly');
  await page.getByLabel(/^Limit for each period/).fill('5000');
  await page.getByRole('button', { name: 'Create budget' }).click();
  await expect(pageHeading(page, 'Household spending')).toBeVisible();
  // Both members' shared expenses count in full: 1200 + 800.50.
  await expect(page.getByText('₹2,000.50 of ₹5,000.00 spent').first()).toBeVisible();

  // A shared expense Ravi adds moves it too.
  await startExpense(ravi, groupId, 'Water', '499.50');
  await saveExpense(ravi, 'Water');
  await page.reload();
  await expect(page.getByText('₹2,500.00 of ₹5,000.00 spent').first()).toBeVisible();
});

test('household members can see a budget shared with the group', async ({
  page,
  secondPage: ravi,
}) => {
  test.setTimeout(180_000);
  const groupId = await household(page, ravi, `Home ${Date.now()}`);
  // Setup: Asha's budget for the household, visible to its members.
  const budget = await api<{ id: string }>(page, 'POST', '/budgets', {
    name: 'Household spending',
    budget_type: 'total',
    period: 'monthly',
    starts_on: todayInKolkata(),
    currency: 'INR',
    limit: '5000',
    group_id: groupId,
    visibility: 'members',
  });

  // 18. Ravi sees the household budget with the same server figures.
  const list = await ravi.request.get('/api/v1/budgets', {
    headers: { 'X-Montra-Client': 'web' },
  });
  expect(list.status(), await list.text()).toBe(200);
  await ravi.goto('/budgets');
  await expect(pageHeading(ravi, 'Budgets')).toBeVisible();
  const shared = ravi.getByRole('link', { name: 'Household spending' });
  await expect(shared).toBeVisible();
  await shared.click();
  await expect(ravi).toHaveURL(new RegExp(`/budgets/${budget.id}$`));
  await expect(pageHeading(ravi, 'Household spending')).toBeVisible();
  await expect(ravi.getByText('₹2,000.50 of ₹5,000.00 spent').first()).toBeVisible();
});
