import { describe, expect, it } from 'vitest';
import {
  MEMBER_ID,
  MOD_ID,
  POST_ID,
  makeCommunity,
  makeCommunityMember,
} from '@/tests/communitiesFixtures';
import { makeUser } from '@/tests/fixtures';
import { canActOnMember, canModerate, canParticipate, restrictionEnd } from './access';
import {
  hasPatchChanges,
  parseTopics,
  toCommunityInput,
  toCommunityPatch,
} from './communityFormValues';
import { actionsFor } from './moderationActions';

const now = Date.parse('2026-11-05T10:00:00Z');
const user = makeUser();

describe('access', () => {
  it('lets the owner, moderators and Montra staff moderate, as the API says', () => {
    expect(canModerate(makeCommunity({ my_role: 'owner' }))).toBe(true);
    expect(canModerate(makeCommunity({ my_role: 'moderator' }))).toBe(true);
    expect(canModerate(makeCommunity({ my_role: 'member' }))).toBe(false);
    // Staff are moderators everywhere although my_role is none: the API says so.
    expect(
      canModerate(makeCommunity({ my_role: 'none', my_status: 'none', can_moderate: true })),
    ).toBe(true);
  });

  it('allows taking part only for active members without a posting pause', () => {
    expect(canParticipate(makeCommunity(), now)).toBe(true);
    expect(canParticipate(makeCommunity({ my_status: 'pending', my_role: 'none' }), now)).toBe(
      false,
    );
    expect(canParticipate(makeCommunity({ status: 'archived' }), now)).toBe(false);
    expect(canParticipate(makeCommunity({ restricted_until: '2026-11-05T11:00:00Z' }), now)).toBe(
      false,
    );
    expect(canParticipate(makeCommunity({ restricted_until: '2026-11-05T09:00:00Z' }), now)).toBe(
      true,
    );
    expect(restrictionEnd(undefined, now)).toBeNull();
  });

  it('keeps moderators from acting on the owner, other moderators or themselves', () => {
    const moderator = makeCommunity({ my_role: 'moderator' });
    const owner = makeCommunity({ my_role: 'owner' });
    const member = makeCommunityMember();
    const otherMod = makeCommunityMember({ user_id: MOD_ID, role: 'moderator' });
    const self = makeCommunityMember({ user_id: user.id });
    expect(canActOnMember(moderator, user, member)).toBe(true);
    expect(canActOnMember(moderator, user, otherMod)).toBe(false);
    expect(canActOnMember(owner, user, otherMod)).toBe(true);
    expect(canActOnMember(owner, user, self)).toBe(false);
    expect(canActOnMember(owner, user, makeCommunityMember({ role: 'owner' }))).toBe(false);
  });
});

describe('moderation actions', () => {
  it('offers what applies to the target’s current state', () => {
    expect(
      actionsFor({
        type: 'post',
        id: POST_ID,
        summary: 'Post',
        state: { status: 'published', pinned: false, locked: true },
      }),
    ).toEqual(['hide', 'remove', 'pin', 'unlock', 'warn']);
    expect(
      actionsFor({ type: 'comment', id: 'c', summary: 'Comment', state: { status: 'hidden' } }),
    ).toEqual(['remove', 'restore', 'warn']);
    // Own posts: only pinning and locking.
    expect(
      actionsFor({
        type: 'post',
        id: POST_ID,
        summary: 'Post',
        state: { status: 'published', pinned: true, locked: false, own: true },
      }),
    ).toEqual(['unpin', 'lock']);
    // From a report the state is unknown; the report can be dismissed or escalated.
    expect(actionsFor({ type: 'comment', id: 'c', summary: 'x', reportId: 'r' })).toEqual([
      'hide',
      'remove',
      'restore',
      'warn',
      'dismiss_report',
      'escalate',
    ]);
    expect(actionsFor({ type: 'member', id: MEMBER_ID, summary: 'Meera' })).toEqual([
      'warn',
      'restrict',
      'ban',
    ]);
    expect(
      actionsFor({ type: 'member', id: MEMBER_ID, summary: 'Meera', state: { banned: true } }),
    ).toEqual(['unban']);
  });
});

describe('community form values', () => {
  it('normalizes topics like the API', () => {
    expect(parseTopics(' Saving, debt-free ,, SAVING,  side   hustle ')).toEqual([
      'saving',
      'debt-free',
      'side hustle',
    ]);
  });

  it('sends the complete community when creating, with the web address when chosen', () => {
    const values = {
      name: ' Frugal Living ',
      slug: 'Frugal-Living',
      description: '',
      rules: ' Be kind ',
      topics: 'saving',
      visibility: 'private' as const,
    };
    expect(toCommunityInput(values)).toEqual({
      name: 'Frugal Living',
      slug: 'frugal-living',
      description: '',
      rules: 'Be kind',
      topics: ['saving'],
      visibility: 'private',
    });
    expect(toCommunityInput({ ...values, slug: ' ' })).not.toHaveProperty('slug');
  });

  it('patches only what changed, with the version, clearing text with an empty string', () => {
    const community = makeCommunity({ version: 4 });
    const unchanged = toCommunityPatch(community, {
      name: ' Frugal Living ',
      slug: community.slug,
      description: community.description ?? '',
      rules: 'Be kind. No selling.',
      topics: ' saving , budgeting ',
      visibility: 'public',
    });
    expect(unchanged).toEqual({ version: 4 });
    expect(hasPatchChanges(unchanged)).toBe(false);
    const patch = toCommunityPatch(community, {
      name: 'Frugal Folks',
      slug: community.slug,
      description: '  ',
      rules: 'Be kind. No selling.',
      topics: 'budgeting, saving',
      visibility: 'private',
    });
    expect(patch).toEqual({
      version: 4,
      name: 'Frugal Folks',
      description: '',
      topics: ['budgeting', 'saving'],
      visibility: 'private',
    });
    expect(hasPatchChanges(patch)).toBe(true);
  });
});
