import type { Preferences, PreferencesPatch } from '@/shared/finance/types';
import type { OwnProfile, OwnProfilePatch } from '@/features/social/types';
import { normalizeUsername } from '@/features/social/people';

/*
 * Form values for the profile and preferences screen and the partial
 * updates built from them: only fields that changed are sent, and an empty
 * text clears an optional field (`""` for username, bio, location, display
 * currency and country; `clear_default_account` for the default account).
 */

export const MAX_INTERESTS = 10;
export const MAX_INTEREST_LENGTH = 40;

export interface ProfileValues {
  displayName: string;
  username: string;
  bio: string;
  /** Comma-separated; at most 10 interests of up to 40 characters. */
  interests: string;
  coarseLocation: string;
  profileVisibility: OwnProfile['profile_visibility'];
  discoverable: boolean;
  allowFriendRequests: OwnProfile['allow_friend_requests'];
}

export function profileValues(profile: OwnProfile): ProfileValues {
  return {
    displayName: profile.display_name,
    username: profile.username ?? '',
    bio: profile.bio ?? '',
    interests: profile.interests.join(', '),
    coarseLocation: profile.coarse_location ?? '',
    profileVisibility: profile.profile_visibility,
    discoverable: profile.discoverable_by_username,
    allowFriendRequests: profile.allow_friend_requests,
  };
}

/** "Cooking, travel ,, cricket" → ["Cooking", "travel", "cricket"] (duplicates dropped). */
export function parseInterests(text: string): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const part of text.split(',')) {
    const interest = part.trim();
    const key = interest.toLocaleLowerCase();
    if (interest && !seen.has(key)) {
      seen.add(key);
      out.push(interest);
    }
  }
  return out;
}

function sameList(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && a.every((item, index) => item === b[index]);
}

/**
 * PATCH /me body with only the changed fields (`{}` when nothing changed).
 * `show_achievements` is never sent: nothing shows achievements yet, so the
 * stored value is left as it is.
 */
export function profilePatch(values: ProfileValues, profile: OwnProfile): OwnProfilePatch {
  const patch: OwnProfilePatch = {};
  const displayName = values.displayName.trim();
  if (displayName !== profile.display_name) patch.display_name = displayName;
  const username = normalizeUsername(values.username);
  if (username !== (profile.username ?? '')) patch.username = username;
  const bio = values.bio.trim();
  if (bio !== (profile.bio ?? '')) patch.bio = bio;
  const location = values.coarseLocation.trim();
  if (location !== (profile.coarse_location ?? '')) patch.coarse_location = location;
  const interests = parseInterests(values.interests);
  if (!sameList(interests, profile.interests)) patch.interests = interests;
  if (values.profileVisibility !== profile.profile_visibility) {
    patch.profile_visibility = values.profileVisibility;
  }
  if (values.discoverable !== profile.discoverable_by_username) {
    patch.discoverable_by_username = values.discoverable;
  }
  if (values.allowFriendRequests !== profile.allow_friend_requests) {
    patch.allow_friend_requests = values.allowFriendRequests;
  }
  return patch;
}

export type DefaultDateRange = NonNullable<PreferencesPatch['default_date_range']>;

/** The periods the API accepts as the default (a subset of the list filters). */
export const DEFAULT_DATE_RANGES = [
  'today',
  'yesterday',
  'this_week',
  'this_month',
  'this_year',
  'last_7_days',
  'last_30_days',
  'last_90_days',
] as const satisfies readonly DefaultDateRange[];

type MissingRanges = Exclude<DefaultDateRange, (typeof DEFAULT_DATE_RANGES)[number]>;
/** Compile-time check: every period the contract accepts is offered. */
export const defaultRangesAreListed: [MissingRanges] extends [never] ? true : MissingRanges = true;

export function isDefaultDateRange(value: string): value is DefaultDateRange {
  return (DEFAULT_DATE_RANGES as readonly string[]).includes(value);
}

export interface RegionValues {
  baseCurrency: string;
  /** "" = no display currency. */
  displayCurrency: string;
  /** "" = not set. */
  country: string;
  timezone: string;
  locale: string;
  dateFormat: Preferences['date_format'];
  numberFormat: Preferences['number_format'];
  weekStart: string;
  monthStartDay: string;
  /** "" = no default account. */
  defaultAccountId: string;
  defaultDateRange: string;
  theme: Preferences['theme'];
}

export function regionValues(preferences: Preferences): RegionValues {
  return {
    baseCurrency: preferences.base_currency,
    displayCurrency: preferences.display_currency ?? '',
    country: preferences.country ?? '',
    timezone: preferences.timezone,
    locale: preferences.locale,
    dateFormat: preferences.date_format,
    numberFormat: preferences.number_format,
    weekStart: String(preferences.week_start),
    monthStartDay: String(preferences.month_start_day),
    defaultAccountId: preferences.default_account_id ?? '',
    defaultDateRange: preferences.default_date_range,
    theme: preferences.theme,
  };
}

/** PATCH /me/preferences body for the regional and display fields that changed. */
export function regionPatch(values: RegionValues, preferences: Preferences): PreferencesPatch {
  const patch: PreferencesPatch = {};
  if (values.baseCurrency !== preferences.base_currency) patch.base_currency = values.baseCurrency;
  if (values.displayCurrency !== (preferences.display_currency ?? '')) {
    patch.display_currency = values.displayCurrency;
  }
  if (values.country !== (preferences.country ?? '')) patch.country = values.country;
  if (values.timezone !== preferences.timezone) patch.timezone = values.timezone;
  if (values.locale !== preferences.locale) patch.locale = values.locale;
  if (values.dateFormat !== preferences.date_format) patch.date_format = values.dateFormat;
  if (values.numberFormat !== preferences.number_format) patch.number_format = values.numberFormat;
  if (Number(values.weekStart) !== preferences.week_start) {
    patch.week_start = Number(values.weekStart);
  }
  if (Number(values.monthStartDay) !== preferences.month_start_day) {
    patch.month_start_day = Number(values.monthStartDay);
  }
  if (values.defaultAccountId !== (preferences.default_account_id ?? '')) {
    if (values.defaultAccountId) patch.default_account_id = values.defaultAccountId;
    else patch.clear_default_account = true;
  }
  if (
    values.defaultDateRange !== preferences.default_date_range &&
    isDefaultDateRange(values.defaultDateRange)
  ) {
    patch.default_date_range = values.defaultDateRange;
  }
  if (values.theme !== preferences.theme) patch.theme = values.theme;
  return patch;
}

/** Text sizes offered (the API accepts 80-200 %). */
export const TEXT_SCALES = [80, 90, 100, 110, 125, 150, 175, 200] as const;

export interface AccessibilityValues {
  reducedMotion: boolean;
  highContrast: boolean;
  textScale: string;
}

export function accessibilityValues(preferences: Preferences): AccessibilityValues {
  return {
    reducedMotion: preferences.reduced_motion,
    highContrast: preferences.high_contrast,
    textScale: String(preferences.text_scale_percent),
  };
}

export function accessibilityPatch(
  values: AccessibilityValues,
  preferences: Preferences,
): PreferencesPatch {
  const patch: PreferencesPatch = {};
  if (values.reducedMotion !== preferences.reduced_motion) {
    patch.reduced_motion = values.reducedMotion;
  }
  if (values.highContrast !== preferences.high_contrast) patch.high_contrast = values.highContrast;
  if (Number(values.textScale) !== preferences.text_scale_percent) {
    patch.text_scale_percent = Number(values.textScale);
  }
  return patch;
}
