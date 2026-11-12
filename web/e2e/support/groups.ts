import type { BrowserContextOptions, Page, TestInfo } from '@playwright/test';
import { api } from './session';
import { test as base, retryRateLimitedReads } from './test';

/**
 * `test` with `secondPage`: a second person in their own browser context,
 * with this project's viewport, device and base URL, so both sides of a
 * group journey run on the same kind of device. Closed after the test.
 */
export const test = base.extend<{ secondPage: Page }>({
  secondPage: async ({ browser }, provide, testInfo) => {
    const context = await browser.newContext(contextOptions(testInfo));
    await retryRateLimitedReads(context);
    await provide(await context.newPage());
    await context.close();
  },
});

function contextOptions(testInfo: TestInfo): BrowserContextOptions {
  const project = testInfo.project.use;
  const options: BrowserContextOptions = {};
  if (project.baseURL !== undefined) options.baseURL = project.baseURL;
  if (project.viewport !== undefined) options.viewport = project.viewport;
  if (project.userAgent !== undefined) options.userAgent = project.userAgent;
  if (project.deviceScaleFactor !== undefined)
    options.deviceScaleFactor = project.deviceScaleFactor;
  if (project.isMobile !== undefined) options.isMobile = project.isMobile;
  if (project.hasTouch !== undefined) options.hasTouch = project.hasTouch;
  if (project.locale !== undefined) options.locale = project.locale;
  return options;
}

/**
 * The path and fragment of an invitation link (`/groups/join#token=…`). The
 * API builds `share_url` from its configured web origin, which need not be
 * the dev server this run started, so the person opens the same path here.
 */
export function joinPath(link: string): string {
  const url = new URL(link);
  return `${url.pathname}${url.hash}`;
}

interface CreatedGroup {
  id: string;
}

interface CreatedInvitation {
  token?: string;
}

/**
 * Setup only (for journeys whose subject is not the group itself): `owner`
 * creates a group through the API and `member` joins it with a link.
 */
export async function groupWithMember(
  owner: Page,
  member: Page,
  body: { name: string; group_type: string },
): Promise<string> {
  const group = await api<CreatedGroup>(owner, 'POST', '/groups', {
    ...body,
    base_currency: 'INR',
    timezone: 'Asia/Kolkata',
    default_split_method: 'equal',
    simplify_debts: true,
    allow_member_invites: false,
    require_join_approval: false,
  });
  const invitation = await api<CreatedInvitation>(
    owner,
    'POST',
    `/groups/${group.id}/invitations`,
    {
      kind: 'link',
      expires_in_days: 1,
    },
  );
  if (!invitation.token) throw new Error('The invitation link has no token');
  await api(member, 'POST', '/group-invitations/accept', { token: invitation.token });
  return group.id;
}
