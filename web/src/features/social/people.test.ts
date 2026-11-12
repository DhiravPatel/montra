import { describe, expect, it } from 'vitest';
import {
  makeIncomingRequest,
  makeOutgoingRequest,
  makePerson,
  ME_ID,
  MEERA_ID,
} from '@/tests/socialFixtures';
import {
  exactUsernameMatch,
  initials,
  isValidUsername,
  liveConnection,
  normalizeUsername,
  pendingRequestWith,
  splitRequests,
} from './people';

describe('usernames', () => {
  it('normalizes like the API: trims, drops a leading @, lowercases', () => {
    expect(normalizeUsername('  @Asha_Rao ')).toBe('asha_rao');
    expect(normalizeUsername('@ meera')).toBe('meera');
    expect(normalizeUsername('')).toBe('');
  });

  it('accepts 3-30 lowercase letters, digits, "_" and "."', () => {
    expect(isValidUsername('asha.rao_1')).toBe(true);
    expect(isValidUsername('ab')).toBe(false);
    expect(isValidUsername('a'.repeat(31))).toBe(false);
    expect(isValidUsername('asha rao')).toBe(false);
    expect(isValidUsername('Asha')).toBe(false);
    expect(isValidUsername('asha%')).toBe(false);
  });

  it('keeps only the exact username from search results', () => {
    const people = [makePerson({ username: 'meera_s2' }), makePerson({ username: 'meera_s' })];
    expect(exactUsernameMatch(people, 'meera_s')?.username).toBe('meera_s');
    expect(exactUsernameMatch(people, 'meera')).toBeNull();
    expect(exactUsernameMatch([makePerson({ username: undefined })], 'meera_s')).toBeNull();
  });
});

describe('requests', () => {
  it('splits pending requests by direction', () => {
    const incoming = makeIncomingRequest();
    const outgoing = makeOutgoingRequest();
    const answered = makeIncomingRequest({ id: 'other', status: 'accepted' });
    expect(splitRequests([incoming, outgoing, answered], ME_ID)).toEqual({
      incoming: [incoming],
      outgoing: [outgoing],
    });
  });

  it('finds the pending request with someone in either direction', () => {
    const outgoing = makeOutgoingRequest();
    expect(pendingRequestWith([outgoing], MEERA_ID)).toBe(outgoing);
    expect(pendingRequestWith([outgoing], 'someone-else')).toBeNull();
    expect(pendingRequestWith(undefined, MEERA_ID)).toBeNull();
  });

  it('takes the relationship from the live lists, not the search answer', () => {
    const meera = makePerson({ connection: 'none' });
    expect(liveConnection(meera, [], [makeOutgoingRequest()])).toBe('request_sent');
    expect(liveConnection(meera, [{ ...meera, connection: 'friend' }], [])).toBe('friend');
    expect(liveConnection(makePerson({ connection: 'request_sent' }), [], [])).toBe('none');
    // Until both lists load, the search answer is the best we know.
    expect(liveConnection(makePerson({ connection: 'request_sent' }), undefined, [])).toBe(
      'request_sent',
    );
    const kabir = makeIncomingRequest().from;
    expect(liveConnection(kabir, [], [makeIncomingRequest()])).toBe('request_received');
  });
});

describe('initials', () => {
  it('uses up to two words and keeps whole characters in any script', () => {
    expect(initials('Meera Shah', 'en')).toBe('MS');
    expect(initials('  asha  ', 'en')).toBe('A');
    expect(initials('Ravi Kumar Sharma', 'en')).toBe('RK');
    // A vowel sign stays with its letter (रा, not र).
    expect(initials('राव कुमार', 'hi')).toBe('राकु');
    expect(initials('', 'en')).toBe('');
  });
});
