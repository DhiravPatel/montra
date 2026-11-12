import type { Page } from '@playwright/test';
import { test as base, expect } from './support/test';
import {
  addDays,
  apiResponse,
  bellName,
  communityIdFrom,
  notificationBell,
  openPeerPage,
  runStamp,
  unreadCount,
  waitForNotification,
} from './support/community';
import { api, navigateTo, newUser, pageHeading, todayInKolkata } from './support/session';

/**
 * Community journeys against the local Go API (spec §14 journeys 19–21 and
 * §4.16): public, private and invitation-only communities seen by two
 * people; a post with comments; and a community challenge whose leaderboard
 * reflects each person's opt-in. Community notifications (join requests,
 * approvals, comments, challenge milestones) are created by the API worker,
 * so they are awaited by polling, never by sleeping.
 *
 * `page` is the first person (A); `peer` is a second person (B) in a
 * separate browser context with the same device settings.
 * Run with: PW_CHANNEL=chrome pnpm exec playwright test e2e/community-journey.spec.ts
 */
const test = base.extend<{ peer: Page }>({
  peer: async ({ browser }, provide, testInfo) => {
    const peer = await openPeerPage(browser, testInfo);
    await provide(peer);
    await peer.context().close();
  },
});

interface CommunityRef {
  id: string;
  name: string;
}

/** Creates a community through the form; returns its ID from the page URL. */
async function createCommunity(
  page: Page,
  name: string,
  visibility: RegExp,
  description: string,
): Promise<CommunityRef> {
  await navigateTo(page, 'Communities');
  await expect(pageHeading(page, 'Communities')).toBeVisible();
  await page.getByRole('link', { name: 'Create a community' }).first().click();
  await expect(pageHeading(page, 'Create a community')).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill(name);
  await page.getByLabel(/^Description/).fill(description);
  await page.getByRole('radio', { name: visibility }).check();
  await page.getByRole('button', { name: 'Create community' }).click();
  await expect(pageHeading(page, name)).toBeVisible();
  return { id: communityIdFrom(page), name };
}

/** A throwaway user (API sign-up), signed in with the app open on Home. */
async function person(page: Page, tag: string, name: string) {
  await newUser(page, tag, { name });
  await page.goto('/dashboard');
  await expect(pageHeading(page, 'Home')).toBeVisible();
}

/** Opens the notification center from the bell (sidebar or phone header). */
async function openNotifications(page: Page) {
  await notificationBell(page).click();
  await expect(pageHeading(page, 'Notifications')).toBeVisible();
}

test('public, private and invitation-only communities: find, join, approve and invite', async ({
  page,
  peer,
}) => {
  test.setTimeout(300_000);
  const stamp = runStamp();
  await person(page, 'cmowner', 'Asha Owner');
  await person(peer, 'cmmember', 'Ravi Member');
  // B browses on the same kind of device as A.
  expect(peer.viewportSize()).toEqual(page.viewportSize());
  const username = `e2e_${stamp}`;
  // Setup: B has a username others may find, so B can be invited by name.
  await api(peer, 'PATCH', '/me', { username, discoverable_by_username: true });

  // A creates one community of each kind in the UI.
  const open = await createCommunity(
    page,
    `E2E Open ${stamp}`,
    /^Public/,
    'Saving tips anyone can read.',
  );
  await expect(page.getByText('Public', { exact: true }).first()).toBeVisible();
  const closed = await createCommunity(
    page,
    `E2E Closed ${stamp}`,
    /^Private/,
    'Members-only budgeting circle.',
  );
  const hidden = await createCommunity(
    page,
    `E2E Hidden ${stamp}`,
    /^Invitation only/,
    'Invite-only planning group.',
  );

  // B finds the public and the private community, never the invitation-only one.
  await navigateTo(peer, 'Communities');
  await expect(pageHeading(peer, 'Communities')).toBeVisible();
  const discover = peer.getByRole('region', { name: 'Find communities' });
  await discover.getByLabel('Search by name or description').fill(stamp);
  await expect(discover.getByRole('link', { name: open.name })).toBeVisible();
  await expect(discover.getByRole('link', { name: closed.name })).toBeVisible();
  await expect(discover.getByRole('link', { name: hidden.name })).toHaveCount(0);

  // B joins the public community straight away.
  await discover.getByRole('link', { name: open.name }).click();
  await expect(pageHeading(peer, open.name)).toBeVisible();
  await peer.getByRole('button', { name: 'Join community' }).click();
  await expect(peer.getByText(`You joined ${open.name}`)).toBeVisible();
  await expect(peer.getByRole('button', { name: 'Leave community' })).toBeVisible();
  await expect(peer.getByText('2 members').first()).toBeVisible();

  // The private one: posts stay hidden and joining is a request for a moderator.
  await peer.goto(`/communities/${closed.id}`);
  await expect(pageHeading(peer, closed.name)).toBeVisible();
  await expect(peer.getByText('Posts are for members')).toBeVisible();
  await expect(peer.getByRole('button', { name: 'Write a post' })).toHaveCount(0);
  await peer.getByRole('button', { name: 'Ask to join' }).click();
  await expect(peer.getByText('Request sent')).toBeVisible();
  await expect(peer.getByRole('button', { name: 'Cancel request' })).toBeVisible();
  await expect(
    peer.getByText('You’ll see the posts once a moderator approves your request.'),
  ).toBeVisible();

  // The invitation-only one is hidden from B: the page and the API both refuse.
  await peer.goto(`/communities/${hidden.id}`);
  await expect(peer.getByRole('heading', { name: 'We can’t find this community' })).toBeVisible();
  await expect(pageHeading(peer, hidden.name)).toHaveCount(0);
  await expect(peer.getByRole('button', { name: /^(Join community|Ask to join)$/ })).toHaveCount(0);
  const read = await apiResponse(peer, 'GET', `/communities/${hidden.id}`);
  expect(read.status(), await read.text()).toBe(404);
  const join = await apiResponse(peer, 'POST', `/communities/${hidden.id}/join`);
  expect(join.status(), await join.text()).toBe(404);

  // A is told about the request (worker notification); the bell counts it.
  const asked = `Someone asked to join ${closed.name}`;
  await waitForNotification(page, asked);
  const ownerUnread = await unreadCount(page);
  expect(ownerUnread).toBeGreaterThanOrEqual(1);
  await page.goto('/communities');
  await expect(notificationBell(page)).toHaveAccessibleName(bellName(ownerUnread));
  await openNotifications(page);
  await expect(page.getByText(asked)).toBeVisible();
  // Marking it read updates the bell at once.
  await page.getByRole('button', { name: `Mark as read: ${asked}` }).click();
  await expect(page.getByRole('button', { name: `Mark as unread: ${asked}` })).toBeVisible();
  await expect(notificationBell(page)).toHaveAccessibleName(bellName(ownerUnread - 1));
  // The notification leads to the community settings, where A approves B.
  await page.getByRole('link', { name: asked }).click();
  await expect(pageHeading(page, 'Community settings')).toBeVisible();
  const requests = page.getByRole('region', { name: 'Requests to join' });
  await requests.getByRole('button', { name: 'Approve Ravi Member' }).click();
  await expect(page.getByText('Ravi Member joined the community')).toBeVisible();
  await expect(requests.getByText('No requests waiting')).toBeVisible();

  // B is told the request was approved; opening it marks it read and shows the community.
  const approved = `You joined ${closed.name}`;
  await waitForNotification(peer, approved);
  const memberUnread = await unreadCount(peer);
  await peer.goto('/communities');
  await expect(notificationBell(peer)).toHaveAccessibleName(bellName(memberUnread));
  await openNotifications(peer);
  await peer.getByRole('link', { name: approved }).click();
  await expect(pageHeading(peer, closed.name)).toBeVisible();
  await expect(peer.getByRole('button', { name: 'Write a post' })).toBeVisible();
  await expect(peer.getByRole('button', { name: 'Leave community' })).toBeVisible();
  await expect(notificationBell(peer)).toHaveAccessibleName(bellName(memberUnread - 1));

  // A invites B to the invitation-only community by username.
  await page.goto(`/communities/${hidden.id}/settings`);
  await expect(pageHeading(page, 'Community settings')).toBeVisible();
  const invite = page.getByRole('region', { name: 'Invite people' });
  await invite.getByRole('radio', { name: 'By username' }).check();
  await invite.getByLabel(/^Username/).fill(username);
  await invite.getByRole('button', { name: 'Send invitation' }).click();
  await expect(page.getByText(`Invitation sent to @${username}`)).toBeVisible();

  // B accepts the invitation from the communities page and is in.
  await peer.goto('/communities');
  const invitations = peer.getByRole('region', { name: 'Invitations for you' });
  await expect(invitations.getByText(`Join ${hidden.name}`)).toBeVisible();
  // Who invited: an open invitation lets B see the inviter's name.
  await expect(invitations.getByText(/^Invited by Asha Owner/)).toBeVisible();
  await invitations.getByRole('button', { name: `Join ${hidden.name}` }).click();
  await expect(pageHeading(peer, hidden.name)).toBeVisible();
  await expect(peer.getByRole('button', { name: 'Leave community' })).toBeVisible();
  await expect(peer.getByRole('button', { name: 'Write a post' })).toBeVisible();
  const mine = peer.getByRole('region', { name: 'Your communities' });
  await peer.goto('/communities');
  for (const community of [open, closed, hidden]) {
    await expect(mine.getByRole('link', { name: community.name })).toBeVisible();
  }
});

test('a post with comments and a reply, seen by both people, with notifications', async ({
  page,
  peer,
}) => {
  test.setTimeout(240_000);
  const stamp = runStamp();
  await person(page, 'cmauthor', 'Asha Owner');
  await person(peer, 'cmposter', 'Ravi Member');
  // Setup: a public community A owns and B has joined.
  const community = await api<{ id: string; name: string }>(page, 'POST', '/communities', {
    name: `E2E Talk ${stamp}`,
    visibility: 'public',
    description: 'Talking about everyday saving.',
  });
  await api(peer, 'POST', `/communities/${community.id}/join`);
  const posterUnreadBefore = await unreadCount(peer);

  // B writes a post.
  const title = `How do you plan groceries ${stamp}?`;
  await peer.goto(`/communities/${community.id}`);
  await expect(pageHeading(peer, community.name)).toBeVisible();
  await peer.getByRole('button', { name: 'Write a post' }).click();
  await peer.getByRole('radio', { name: 'Question' }).check();
  await peer.getByLabel('Your question').fill(title);
  await peer.getByLabel(/^Details/).fill('I keep overspending at the weekend market.');
  await peer.getByRole('button', { name: 'Post', exact: true }).click();
  await expect(peer.getByText('Posted', { exact: true })).toBeVisible();
  const feedPost = peer.getByRole('article', { name: title });
  await expect(feedPost).toBeVisible();
  await expect(feedPost.getByText('Ravi Member')).toBeVisible();

  // A sees the post in the feed, opens it and comments.
  await navigateTo(page, 'Communities');
  await page
    .getByRole('region', { name: 'Your communities' })
    .getByRole('link', { name: community.name })
    .click();
  await expect(pageHeading(page, community.name)).toBeVisible();
  await page
    .getByRole('article', { name: title })
    .getByRole('link', { name: title, exact: true })
    .click();
  await expect(pageHeading(page, title)).toBeVisible();
  await expect(page.getByText('I keep overspending at the weekend market.')).toBeVisible();
  const comment = 'Make a list on Thursday and stick to it.';
  await page.getByLabel(/^Add a comment/).fill(comment);
  await page.getByRole('button', { name: 'Post comment' }).click();
  await expect(page.getByText('Comment posted')).toBeVisible();
  await expect(page.getByRole('article', { name: 'Comment by Asha Owner' })).toContainText(comment);
  await expect(page.getByRole('heading', { name: '1 comment' })).toBeVisible();

  // B is notified about the comment; the bell counts it.
  const commented = 'New comment on your post';
  await waitForNotification(peer, commented);
  await peer.goto('/communities');
  await expect(notificationBell(peer)).toHaveAccessibleName(bellName(posterUnreadBefore + 1));
  await openNotifications(peer);
  const item = peer.getByRole('listitem').filter({ hasText: commented });
  await expect(item.getByText('New', { exact: true })).toBeVisible();
  // Opening it marks it read and lands on the post with A's comment.
  await item.getByRole('link', { name: commented }).click();
  await expect(pageHeading(peer, title)).toBeVisible();
  await expect(peer.getByRole('article', { name: 'Comment by Asha Owner' })).toContainText(comment);
  await expect(notificationBell(peer)).toHaveAccessibleName(bellName(posterUnreadBefore));

  // B replies to A's comment; A sees the reply and is notified too.
  const ownerUnreadBefore = await unreadCount(page);
  await peer.getByRole('button', { name: 'Reply to Asha Owner' }).click();
  const reply = 'Thanks, I will try that this week.';
  await peer.getByLabel('Your reply to Asha Owner').fill(reply);
  await peer.getByRole('button', { name: 'Post reply' }).click();
  await expect(peer.getByText('Reply posted')).toBeVisible();
  await expect(peer.getByRole('article', { name: 'Comment by Ravi Member' })).toContainText(reply);

  const replied = 'New reply to your comment';
  await waitForNotification(page, replied);
  await page.reload();
  await expect(pageHeading(page, title)).toBeVisible();
  await expect(page.getByRole('article', { name: 'Comment by Ravi Member' })).toContainText(reply);
  await expect(page.getByRole('heading', { name: '2 comments' })).toBeVisible();
  await expect(notificationBell(page)).toHaveAccessibleName(bellName(ownerUnreadBefore + 1));
  await openNotifications(page);
  await expect(page.getByRole('link', { name: replied })).toBeVisible();
  await page.getByRole('button', { name: 'Mark all as read' }).click();
  await expect(page.getByRole('button', { name: `Mark as unread: ${replied}` })).toBeVisible();
  await expect(notificationBell(page)).toHaveAccessibleName(bellName(0));
});

test('a community challenge: join privately, check in, then opt in to the leaderboard', async ({
  page,
  peer,
}) => {
  test.setTimeout(240_000);
  const stamp = runStamp();
  await person(page, 'chowner', 'Asha Owner');
  await person(peer, 'chmember', 'Ravi Member');
  // Setup: a public community both people are in.
  const community = await api<{ id: string; name: string }>(page, 'POST', '/communities', {
    name: `E2E Savers ${stamp}`,
    visibility: 'public',
  });
  await api(peer, 'POST', `/communities/${community.id}/join`);
  const today = todayInKolkata();
  const title = `Cook at home ${stamp}`;

  // A creates a community challenge with an opt-in leaderboard and chooses to appear on it.
  await navigateTo(page, 'Challenges');
  await expect(pageHeading(page, 'Challenges')).toBeVisible();
  await page.getByRole('link', { name: 'New challenge' }).first().click();
  await expect(pageHeading(page, 'New challenge')).toBeVisible();
  await page.getByLabel(/^Title/).fill(title);
  await page.getByLabel(/^Type/).selectOption({ label: 'Meal planning' });
  await page.getByRole('radio', { name: /^Check-ins/ }).check();
  await page.getByLabel(/^Target/).fill('4');
  await expect(page.getByLabel(/^Starts on/)).toHaveValue(today);
  await page.getByLabel(/^Ends on/).fill(addDays(today, 30));
  await page.getByRole('radio', { name: /^A community/ }).check();
  await page.getByLabel(/^Community/).selectOption({ label: community.name });
  await page.getByRole('checkbox', { name: 'Add an opt-in leaderboard' }).check();
  await page
    .getByRole('checkbox', { name: 'Share my progress with people in this challenge' })
    .check();
  await page.getByRole('checkbox', { name: 'Show me on the leaderboard' }).check();
  await page.getByRole('button', { name: 'Create challenge' }).click();
  await expect(pageHeading(page, title)).toBeVisible();
  const challengeUrl = page.url();

  // A checks in once: 1 of 4 check-ins, and A is alone on the leaderboard.
  await page.getByLabel(/^Check-ins for this day/).fill('1');
  await page.getByRole('button', { name: 'Save check-in' }).click();
  await expect(page.getByText('Check-in saved')).toBeVisible();
  await expect(page.getByText('1 of 4 check-ins').first()).toBeVisible();
  const ownerBoard = page.getByRole('table', {
    name: 'People who chose to appear on the leaderboard',
  });
  await expect(ownerBoard.getByRole('row')).toHaveCount(2); // header + A
  await expect(ownerBoard.getByRole('row', { name: /Asha Owner/ })).toContainText(
    '25% of the target',
  );

  // B finds it among challenges open to join and joins with sharing left off.
  await navigateTo(peer, 'Challenges');
  await expect(pageHeading(peer, 'Challenges')).toBeVisible();
  await peer
    .getByRole('region', { name: 'Open to join' })
    .getByRole('link', { name: title })
    .click();
  await expect(pageHeading(peer, title)).toBeVisible();
  await expect(
    peer.getByText(
      'This challenge has an opt-in leaderboard. People who join can choose to appear on it.',
    ),
  ).toBeVisible();
  await peer.getByRole('button', { name: 'Join challenge' }).click();
  const join = peer.getByRole('dialog', { name: 'Join this challenge' });
  const share = join.getByRole('checkbox', {
    name: 'Share my progress with people in this challenge',
  });
  await expect(share).not.toBeChecked();
  await expect(join.getByRole('checkbox', { name: 'Show me on the leaderboard' })).toBeDisabled();
  await join.getByRole('button', { name: 'Join', exact: true }).click();
  await expect(peer.getByText('You joined the challenge')).toBeVisible();
  await expect(
    peer.getByText('Only you can see this. Share it only if you want to.'),
  ).toBeVisible();
  await expect(peer.getByText('Your progress is private right now.')).toBeVisible();

  // B records two check-ins (halfway): progress shows, the leaderboard stays closed to B.
  await peer.getByLabel(/^Check-ins for this day/).fill('2');
  await peer.getByRole('button', { name: 'Save check-in' }).click();
  await expect(peer.getByText('Check-in saved')).toBeVisible();
  await expect(peer.getByText('2 of 4 check-ins').first()).toBeVisible();
  await expect(
    peer.getByText(/^The leaderboard is shown only to people who appear on it/),
  ).toBeVisible();
  await expect(
    peer.getByRole('table', { name: 'People who chose to appear on the leaderboard' }),
  ).toHaveCount(0);

  // B's halfway milestone arrives as a notification.
  const halfway = `Halfway through ${title}`;
  await waitForNotification(peer, halfway);

  // B took part without opting in, so A's leaderboard still lists only A.
  await page.goto(challengeUrl);
  await expect(pageHeading(page, title)).toBeVisible();
  await expect(ownerBoard.getByRole('row')).toHaveCount(2);
  await expect(ownerBoard).not.toContainText('Ravi Member');

  // B opts in under Sharing and now sees the leaderboard with both people.
  const sharing = peer.getByRole('region', { name: 'Sharing' });
  await sharing
    .getByRole('checkbox', { name: 'Share my progress with people in this challenge' })
    .check();
  await sharing.getByRole('checkbox', { name: 'Show me on the leaderboard' }).check();
  await sharing.getByRole('button', { name: 'Save sharing' }).click();
  await expect(peer.getByText('Sharing updated')).toBeVisible();
  await expect(
    peer.getByText('People in this challenge can see your percentage, never your notes.'),
  ).toBeVisible();
  const memberBoard = peer.getByRole('table', {
    name: 'People who chose to appear on the leaderboard',
  });
  await expect(memberBoard.getByRole('row')).toHaveCount(3);
  await expect(memberBoard.getByRole('row', { name: /Ravi Member/ })).toContainText(
    '50% of the target',
  );
  await expect(memberBoard.getByRole('row', { name: /Ravi Member/ })).toContainText('You');
  await expect(memberBoard.getByRole('row', { name: /Asha Owner/ })).toContainText(
    '25% of the target',
  );
  // Ranked by percentage of the target, never by amounts.
  await expect(memberBoard.getByRole('row').nth(1)).toContainText('Ravi Member');

  // A now sees B on the leaderboard too.
  await page.reload();
  await expect(pageHeading(page, title)).toBeVisible();
  await expect(ownerBoard.getByRole('row')).toHaveCount(3);
  await expect(ownerBoard.getByRole('row', { name: /Ravi Member/ })).toContainText(
    '50% of the target',
  );

  // B reads the milestone notification and marks it read.
  await peer.reload();
  await expect(pageHeading(peer, title)).toBeVisible();
  const before = await unreadCount(peer);
  await expect(notificationBell(peer)).toHaveAccessibleName(bellName(before));
  await openNotifications(peer);
  await peer.getByRole('button', { name: `Mark as read: ${halfway}` }).click();
  await expect(peer.getByRole('button', { name: `Mark as unread: ${halfway}` })).toBeVisible();
  await expect(notificationBell(peer)).toHaveAccessibleName(bellName(before - 1));
});
