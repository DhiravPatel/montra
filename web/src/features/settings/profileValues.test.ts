import { describe, expect, it } from 'vitest';
import { makePreferences } from '@/tests/financeFixtures';
import { makeOwnProfile } from '@/tests/socialFixtures';
import {
  accessibilityPatch,
  accessibilityValues,
  parseInterests,
  profilePatch,
  profileValues,
  regionPatch,
  regionValues,
} from './profileValues';

describe('profile and preference patches', () => {
  it('parses interests: trimmed, without blanks or repeats', () => {
    expect(parseInterests(' Cricket, cooking,, cricket ,Travel ')).toEqual([
      'Cricket',
      'cooking',
      'Travel',
    ]);
    expect(parseInterests('')).toEqual([]);
  });

  it('sends nothing when nothing changed', () => {
    const profile = makeOwnProfile({ bio: 'Hi', interests: ['Cricket'] });
    expect(profilePatch(profileValues(profile), profile)).toEqual({});
    const preferences = makePreferences({ country: 'IN', display_currency: 'USD' });
    expect(regionPatch(regionValues(preferences), preferences)).toEqual({});
    expect(accessibilityPatch(accessibilityValues(preferences), preferences)).toEqual({});
  });

  it('normalizes the username and clears optional text with ""', () => {
    const profile = makeOwnProfile({ username: 'asha', bio: 'Hi', coarse_location: 'Pune' });
    const values = {
      ...profileValues(profile),
      username: ' @Asha.R ',
      bio: ' ',
      coarseLocation: '',
    };
    expect(profilePatch(values, profile)).toEqual({
      username: 'asha.r',
      bio: '',
      coarse_location: '',
    });
  });

  it('clears the default account with clear_default_account and sends numbers as numbers', () => {
    const preferences = makePreferences({ default_account_id: 'acc-1' });
    expect(
      regionPatch(
        { ...regionValues(preferences), defaultAccountId: '', weekStart: '0', monthStartDay: '5' },
        preferences,
      ),
    ).toEqual({ clear_default_account: true, week_start: 0, month_start_day: 5 });
    expect(
      accessibilityPatch({ ...accessibilityValues(preferences), textScale: '175' }, preferences),
    ).toEqual({ text_scale_percent: 175 });
  });
});
