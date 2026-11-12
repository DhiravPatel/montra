import { hasTripDetails, isGroupType, isSplitMethod } from './labels';
import type { GroupDetail, GroupInput, GroupPatch, GroupType, SplitMethod } from './types';

/** Form state (plain strings; checked by the form's schema). */
export interface GroupFormValues {
  name: string;
  /** '' until the user chooses (creating). */
  groupType: string;
  description: string;
  baseCurrency: string;
  timezone: string;
  defaultSplitMethod: string;
  simplifyDebts: boolean;
  allowMemberInvites: boolean;
  /** Invitation links create a join request for the admins instead of joining. */
  requireJoinApproval: boolean;
  rules: string;
  startDate: string;
  endDate: string;
  destination: string;
}

/** Values the schema accepted, with the contract enums narrowed. */
export type ValidGroupValues = Omit<GroupFormValues, 'groupType' | 'defaultSplitMethod'> & {
  groupType: GroupType;
  defaultSplitMethod: SplitMethod;
};

export function validGroupValues(values: GroupFormValues): ValidGroupValues | null {
  const { groupType, defaultSplitMethod } = values;
  if (!isGroupType(groupType) || !isSplitMethod(defaultSplitMethod)) return null;
  return { ...values, groupType, defaultSplitMethod };
}

/** A new group starts in the user's own currency and time zone. */
export function emptyGroupValues(currency: string, timezone: string): GroupFormValues {
  return {
    name: '',
    groupType: '',
    description: '',
    baseCurrency: currency,
    timezone,
    defaultSplitMethod: 'equal',
    simplifyDebts: true,
    allowMemberInvites: true,
    requireJoinApproval: false,
    rules: '',
    startDate: '',
    endDate: '',
    destination: '',
  };
}

export function groupToValues(group: GroupDetail): GroupFormValues {
  return {
    name: group.name,
    groupType: group.group_type,
    description: group.description ?? '',
    baseCurrency: group.base_currency,
    timezone: group.timezone,
    defaultSplitMethod: group.default_split_method,
    simplifyDebts: group.simplify_debts,
    allowMemberInvites: group.allow_member_invites,
    requireJoinApproval: group.require_join_approval,
    rules: group.rules ?? '',
    startDate: group.start_date ?? '',
    endDate: group.end_date ?? '',
    destination: group.destination ?? '',
  };
}

/** Create body: only what was filled in (the API applies its defaults to the rest). */
export function toCreateInput(values: ValidGroupValues): GroupInput {
  const body: GroupInput = {
    name: values.name.trim(),
    group_type: values.groupType,
    base_currency: values.baseCurrency,
    timezone: values.timezone,
    default_split_method: values.defaultSplitMethod,
    simplify_debts: values.simplifyDebts,
    allow_member_invites: values.allowMemberInvites,
    require_join_approval: values.requireJoinApproval,
  };
  const description = values.description.trim();
  const rules = values.rules.trim();
  if (description) body.description = description;
  if (rules) body.rules = rules;
  if (hasTripDetails(values.groupType)) {
    const destination = values.destination.trim();
    if (values.startDate) body.start_date = values.startDate;
    if (values.endDate) body.end_date = values.endDate;
    if (destination) body.destination = destination;
  }
  return body;
}

/**
 * The complete settings as the API would store them for `values`: trimmed
 * text, and trip dates and destination cleared when the group is no longer
 * a trip or event. Empty strings mean "cleared", as PATCH expects.
 */
function settingsOf(values: ValidGroupValues): Omit<GroupPatch, 'version'> {
  const trip = hasTripDetails(values.groupType);
  return {
    name: values.name.trim(),
    group_type: values.groupType,
    description: values.description.trim(),
    base_currency: values.baseCurrency,
    timezone: values.timezone,
    default_split_method: values.defaultSplitMethod,
    simplify_debts: values.simplifyDebts,
    allow_member_invites: values.allowMemberInvites,
    require_join_approval: values.requireJoinApproval,
    rules: values.rules.trim(),
    start_date: trip ? values.startDate : '',
    end_date: trip ? values.endDate : '',
    destination: trip ? values.destination.trim() : '',
  };
}

/**
 * Update body: PATCH /groups/{id} changes only the fields sent, so only
 * the settings that differ from the loaded group go in, with the version
 * that was edited (a stale version answers 409 VERSION_CONFLICT). Text and
 * dates are cleared with an empty string. `null` when nothing changed.
 */
export function toUpdateInput(group: GroupDetail, values: ValidGroupValues): GroupPatch | null {
  const current = settingsOf(validGroupValues(groupToValues(group)) ?? values);
  const next = settingsOf(values);
  const patch: GroupPatch = { version: group.version };
  let changed = false;
  for (const key of Object.keys(next) as (keyof typeof next)[]) {
    if (next[key] === current[key]) continue;
    // Each key's value type matches on both sides (same shape).
    Object.assign(patch, { [key]: next[key] });
    changed = true;
  }
  return changed ? patch : null;
}
