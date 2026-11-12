import { describe, expect, it } from 'vitest';
import {
  BILL_ID,
  GOAL_ID,
  GROUP_ID,
  SUPPORT_REQUEST_ID,
  TEST_VAPID_KEY,
  makeNotification,
  makeUnsubscribeToken,
  supportReplyNotification,
} from '@/tests/notificationsFixtures';
import { notificationLink } from './links';
import { decodeVapidKey, deviceLabel, serverPushKey } from './push/browserPush';
import { previewCategory, readUnsubscribeToken } from './unsubscribeToken';

const ID = 'd4e5f6a7-4444-4d5e-8f60-000000000030';

describe('notificationLink', () => {
  it('builds web routes from entity types and IDs, not from the server path', () => {
    const link = (overrides: Parameters<typeof makeNotification>[0]) =>
      notificationLink(makeNotification(overrides));
    expect(link({ entity_type: 'goal', entity_id: GOAL_ID })).toBe(`/goals/${GOAL_ID}`);
    expect(link({ entity_type: 'bill', entity_id: BILL_ID, deep_link: `/bills/${BILL_ID}` })).toBe(
      `/planning/bills/${BILL_ID}`,
    );
    expect(
      link({ entity_type: 'recurring_rule', entity_id: ID, deep_link: `/recurring/${ID}` }),
    ).toBe(`/planning/recurring/${ID}`);
    expect(link({ entity_type: 'insight', entity_id: ID, deep_link: `/insights/${ID}` })).toBe(
      `/insights/${ID}`,
    );
    expect(link({ entity_type: 'insight', entity_id: 'not-an-id' })).toBe('/insights');
    expect(link({ entity_type: 'report', entity_id: ID })).toBe('/reports');
    expect(
      link({
        entity_type: 'data_export',
        entity_id: ID,
        deep_link: `/settings/privacy?export=${ID}`,
      }),
    ).toBe(`/settings/privacy?export=${ID}`);
    expect(notificationLink(supportReplyNotification())).toBe(
      `/help/requests/${SUPPORT_REQUEST_ID}`,
    );
    expect(link({ entity_type: 'settlement', entity_id: ID, group_id: GROUP_ID })).toBe(
      `/groups/${GROUP_ID}/settlements/${ID}`,
    );
    expect(link({ entity_type: 'group_join_request', entity_id: ID, group_id: GROUP_ID })).toBe(
      `/groups/${GROUP_ID}/settings`,
    );
    expect(
      link({ entity_type: 'group_recurring_expense', entity_id: ID, group_id: GROUP_ID }),
    ).toBe(`/groups/${GROUP_ID}/recurring`);
    expect(
      link({ entity_type: 'group', entity_id: GROUP_ID, event_type: 'trip_ended_unsettled' }),
    ).toBe(`/groups/${GROUP_ID}/balances`);
    expect(link({ entity_type: 'community', entity_id: ID, event_type: 'community_report' })).toBe(
      `/communities/${ID}/moderation`,
    );
    expect(
      link({ entity_type: 'community', entity_id: ID, event_type: 'community_join_request' }),
    ).toBe(`/communities/${ID}/settings`);
    expect(link({ entity_type: 'community_post', entity_id: ID, event_type: 'mention' })).toBe(
      `/posts/${ID}`,
    );
    expect(link({ entity_type: 'group', entity_id: GROUP_ID, event_type: 'trip_starting' })).toBe(
      `/groups/${GROUP_ID}`,
    );
    expect(
      link({ entity_type: 'challenge', entity_id: ID, event_type: 'challenge_milestone' }),
    ).toBe(`/challenges/${ID}`);
    expect(
      link({
        entity_type: 'moderation_action',
        entity_id: ID,
        event_type: 'moderation_appeal_overturned',
      }),
    ).toBe('/settings/moderation');
    expect(link({ entity_type: 'community_post', entity_id: ID })).toBe(`/posts/${ID}`);
    expect(
      link({ entity_type: 'moderation_action', entity_id: ID, deep_link: '/me/moderation' }),
    ).toBe('/settings/moderation');
    expect(link({ entity_type: 'integration_connection', entity_id: ID })).toBe(
      '/settings/integrations',
    );
  });

  it('falls back to the category home and never trusts free text', () => {
    expect(
      notificationLink(
        makeNotification({
          category: 'security',
          entity_type: undefined,
          entity_id: undefined,
          deep_link: '/settings/security',
        }),
      ),
    ).toBe('/settings/security');
    expect(
      notificationLink(
        makeNotification({
          entity_type: 'goal',
          entity_id: '../../admin',
          deep_link: '//evil.example',
        }),
      ),
    ).toBe('/goals');
    expect(
      notificationLink(
        makeNotification({ category: 'system', entity_type: undefined, entity_id: undefined }),
      ),
    ).toBeNull();
    expect(
      notificationLink(
        makeNotification({
          category: 'account',
          event_type: 'deletion_scheduled',
          entity_type: undefined,
          entity_id: undefined,
        }),
      ),
    ).toBe('/settings/privacy');
  });
});

describe('unsubscribe tokens', () => {
  it('reads a token from the fragment and previews its category', () => {
    const token = makeUnsubscribeToken('budget');
    expect(readUnsubscribeToken(`#token=${token}`)).toBe(token);
    expect(previewCategory(token)).toBe('budget');
    expect(readUnsubscribeToken('#token=abc')).toBeNull();
    expect(readUnsubscribeToken('#other=1')).toBeNull();
    expect(readUnsubscribeToken(`#token=${'a'.repeat(30)}`)).toBeNull();
    expect(previewCategory('bm9wZQ.c2ln')).toBeNull();
  });
});

describe('browser push helpers', () => {
  it('accepts only uncompressed P-256 VAPID keys', () => {
    const key = decodeVapidKey(TEST_VAPID_KEY);
    expect(key?.length).toBe(65);
    expect(key?.[0]).toBe(4);
    expect(decodeVapidKey('not a key')).toBeNull();
    expect(decodeVapidKey('AAAA')).toBeNull();
  });

  it('subscribes only with the key the server serves as available', () => {
    expect(serverPushKey({ available: true, vapid_public_key: TEST_VAPID_KEY })?.length).toBe(65);
    expect(serverPushKey({ available: false })).toBeNull();
    expect(serverPushKey({ available: false, vapid_public_key: TEST_VAPID_KEY })).toBeNull();
    expect(serverPushKey({ available: true, vapid_public_key: 'AAAA' })).toBeNull();
    expect(serverPushKey({ available: true })).toBeNull();
  });

  it('names the browser without identifying details', () => {
    expect(
      deviceLabel(
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
      ),
    ).toBe('Chrome on macOS');
    expect(
      deviceLabel(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) Gecko/20100101 Firefox/132.0',
      ),
    ).toBe('Firefox on Windows');
    expect(deviceLabel('Something else')).toBe('Browser');
  });
});
