import { describe, expect, it } from 'vitest';
import { makeAction } from '@/tests/moderationFixtures';
import { appealWindow, isInForce, standingFrom } from './standing';

const NOW = Date.parse('2026-11-05T10:00:00Z');

describe('standingFrom', () => {
  it('reports an account-wide ban before a restriction, with its end', () => {
    const standing = standingFrom(
      [
        makeAction({
          id: 'r',
          action: 'restrict',
          target_type: 'profile',
          community_id: undefined,
          expires_at: '2026-11-08T10:00:00Z',
        }),
        makeAction({
          id: 'b',
          action: 'ban',
          target_type: 'profile',
          community_id: undefined,
          expires_at: '2026-12-01T10:00:00Z',
        }),
      ],
      NOW,
    );
    expect(standing.account).toEqual({ action: 'ban', until: '2026-12-01T10:00:00Z' });
  });

  it('treats a ban without an end as open-ended', () => {
    const standing = standingFrom(
      [
        makeAction({
          action: 'ban',
          target_type: 'profile',
          community_id: undefined,
          expires_at: undefined,
        }),
      ],
      NOW,
    );
    expect(standing.account).toEqual({ action: 'ban', until: null });
  });

  it('ignores reversed and expired sanctions', () => {
    const standing = standingFrom(
      [
        makeAction({
          id: 'a',
          action: 'restrict',
          target_type: 'profile',
          community_id: undefined,
          expires_at: '2026-11-04T10:00:00Z',
        }),
        makeAction({
          id: 'b',
          action: 'ban',
          target_type: 'profile',
          community_id: undefined,
          reversed_at: '2026-11-03T10:00:00Z',
        }),
        makeAction({
          id: 'c',
          action: 'restrict',
          target_type: 'member',
          expires_at: '2026-11-05T09:00:00Z',
        }),
      ],
      NOW,
    );
    expect(standing).toEqual({ account: null, restrictedIn: 0, bannedFrom: 0 });
  });

  it('counts community bans until a later unban, and restrictions per community', () => {
    const community = 'f5d08c6d-1e7b-4f4a-8d8c-7b8a9f0e1d6f';
    const other = 'a1b2c3d4-0000-4000-8000-000000000002';
    const standing = standingFrom(
      [
        makeAction({
          id: 'u',
          action: 'unban',
          target_type: 'member',
          community_id: community,
          created_at: '2026-11-04T10:00:00Z',
        }),
        makeAction({
          id: 'b1',
          action: 'ban',
          target_type: 'member',
          community_id: community,
          created_at: '2026-11-01T10:00:00Z',
        }),
        makeAction({
          id: 'b2',
          action: 'ban',
          target_type: 'member',
          community_id: other,
          created_at: '2026-11-02T10:00:00Z',
        }),
        makeAction({
          id: 'r1',
          action: 'restrict',
          target_type: 'member',
          community_id: other,
          expires_at: '2026-11-06T10:00:00Z',
        }),
        makeAction({
          id: 'r2',
          action: 'restrict',
          target_type: 'member',
          community_id: other,
          expires_at: '2026-11-07T10:00:00Z',
        }),
      ],
      NOW,
    );
    expect(standing).toEqual({ account: null, restrictedIn: 1, bannedFrom: 1 });
  });
});

describe('appealWindow', () => {
  it('is open for 30 days after the action and closed afterwards', () => {
    const open = appealWindow(makeAction({ created_at: '2026-10-10T10:00:00Z' }), NOW);
    expect(open.state).toBe('open');
    if (open.state === 'open') expect(open.deadline.toISOString()).toBe('2026-11-09T10:00:00.000Z');
    expect(appealWindow(makeAction({ created_at: '2026-10-01T10:00:00Z' }), NOW).state).toBe(
      'closed',
    );
  });

  it('is not offered for actions the API marks as not appealable', () => {
    expect(appealWindow(makeAction({ appealable: false }), NOW).state).toBe('none');
  });
});

describe('isInForce', () => {
  it('needs the action unreversed and unexpired', () => {
    expect(isInForce(makeAction({ action: 'ban', expires_at: undefined }), NOW)).toBe(true);
    expect(
      isInForce(makeAction({ action: 'restrict', expires_at: '2026-11-05T11:00:00Z' }), NOW),
    ).toBe(true);
    expect(
      isInForce(makeAction({ action: 'restrict', expires_at: '2026-11-05T09:00:00Z' }), NOW),
    ).toBe(false);
    expect(isInForce(makeAction({ action: 'ban', reversed_at: '2026-11-05T09:00:00Z' }), NOW)).toBe(
      false,
    );
  });
});
