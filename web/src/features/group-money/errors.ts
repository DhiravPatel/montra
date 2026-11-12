import { hasErrorCode } from '@/shared/api/errors';
import {
  detailParam,
  errorDetail,
  financeErrorMessage,
  statusTransitionMessage,
} from '@/shared/finance/domainErrors';
import { formatLocalDate, isLocalDate } from '@/shared/formatting/dates';
import type { MessageKey, Translate } from '@/shared/i18n/types';
import { settlementStatusLook } from './labels';
import type { SettlementStatus } from './types';

/**
 * Coded errors a group money screen can receive (docs/API.md "Domain rule
 * codes"): 422 DOMAIN_RULE_VIOLATION and 409 CONFLICT details. Shown in the
 * interface language; anything else falls back to the shared finance text.
 */
const ruleMessages: Readonly<Record<string, MessageKey>> = {
  split_mismatch: 'groupMoney.rule.split_mismatch',
  payers_total_mismatch: 'groupMoney.rule.payers_total_mismatch',
  items_exceed_total: 'groupMoney.rule.items_exceed_total',
  items_need_amount: 'groupMoney.rule.items_need_amount',
  payer_only: 'groupMoney.rule.payer_only',
  group_archived: 'groupMoney.rule.group_archived',
  settlement_dispute: 'groupMoney.rule.settlement_dispute',
  settlement_not_confirmed: 'groupMoney.rule.settlement_not_confirmed',
  settlement_not_paid: 'groupMoney.rule.settlement_not_paid',
  schedule_ended: 'groupMoney.rule.schedule_ended',
  // 409 CONFLICT: the record's state no longer allows the action.
  expense_deleted: 'groupMoney.rule.expense_deleted',
  expense_already_recorded: 'groupMoney.rule.expense_already_recorded',
  settlement_voided: 'groupMoney.rule.settlement_voided',
  settlement_not_proposed: 'groupMoney.rule.settlement_not_proposed',
  settlement_not_confirmable: 'groupMoney.rule.settlement_not_confirmable',
  settlement_not_disputable: 'groupMoney.rule.settlement_not_disputable',
  settlement_already_recorded: 'groupMoney.rule.settlement_already_recorded',
  occurrence_already_handled: 'groupMoney.rule.occurrence_already_handled',
  // 422 with values.
  fx_rate_unavailable: 'groupMoney.rule.fx_rate_unavailable',
  recurring_member_inactive: 'groupMoney.rule.recurring_member_inactive',
  recurring_template_invalid: 'groupMoney.rule.recurring_template_invalid',
  // Pausing a paused (or resuming an active) shared recurring expense: {from, to}.
  invalid_status_transition: 'finance.rule.invalid_status_transition_generic',
};

/** Variants that name the settlement's current status (`params.status`). */
const statusVariants: Readonly<Record<string, MessageKey>> = {
  settlement_not_proposed: 'groupMoney.rule.settlement_not_proposed_status',
  settlement_not_confirmable: 'groupMoney.rule.settlement_not_confirmable_status',
  settlement_not_disputable: 'groupMoney.rule.settlement_not_disputable_status',
};

/**
 * Codes that mean the record (or the group) changed somewhere else: the
 * screen reloads it so the controls match what the server allows now.
 */
const STATE_CONFLICTS: ReadonlySet<string> = new Set([
  'expense_deleted',
  'expense_already_recorded',
  'settlement_voided',
  'settlement_not_proposed',
  'settlement_not_confirmable',
  'settlement_not_disputable',
  'settlement_already_recorded',
  'occurrence_already_handled',
  'group_archived',
  'schedule_ended',
  'invalid_status_transition',
]);

/** The reason code of a coded group money error, when this feature knows it. */
export function groupRuleCode(error: unknown): string | null {
  const detail = errorDetail(error);
  return detail && detail.code in ruleMessages ? detail.code : null;
}

/** True for a coded 409/422 that says the record's state moved on (reload it). */
export function isStateConflict(error: unknown): boolean {
  const code = groupRuleCode(error);
  return code !== null && STATE_CONFLICTS.has(code);
}

interface Fallbacks {
  /** For a 409 CONFLICT without a code (e.g. "This expense was deleted."). */
  conflict?: string;
  /** For a 404 (the record is gone or no longer visible). */
  notFound?: string;
  /** For a 403 (the API refused this person). */
  forbidden?: string;
  /** Names the person a code refers to (`recurring_member_inactive`). */
  memberName?: (userId: string) => string;
}

function isSettlementStatus(value: string): value is SettlementStatus {
  return value in settlementStatusLook;
}

/** The sentence for a coded rule, with its values in the interface language. */
function ruleMessage(
  code: string,
  params: Readonly<Record<string, unknown>>,
  t: Translate,
  locale: string,
  fallbacks: Fallbacks,
): string {
  switch (code) {
    case 'settlement_not_proposed':
    case 'settlement_not_confirmable':
    case 'settlement_not_disputable': {
      const status = detailParam(params, 'status');
      const variant = statusVariants[code];
      if (status && variant && isSettlementStatus(status)) {
        return t(variant, { status: t(settlementStatusLook[status].label) });
      }
      break;
    }
    case 'occurrence_already_handled': {
      const status = detailParam(params, 'status');
      if (status === 'skipped') return t('groupMoney.rule.occurrence_already_handled_skipped');
      if (status === 'posted') return t('groupMoney.rule.occurrence_already_handled_added');
      break;
    }
    case 'fx_rate_unavailable': {
      const from = detailParam(params, 'from');
      const to = detailParam(params, 'to');
      const date = detailParam(params, 'date');
      if (from && to) {
        return t('groupMoney.rule.fx_rate_unavailable_pair', {
          from,
          to,
          date: date && isLocalDate(date) ? formatLocalDate(date, locale) : (date ?? ''),
        });
      }
      break;
    }
    case 'recurring_member_inactive': {
      const userId = detailParam(params, 'user_id');
      const name = userId && fallbacks.memberName ? fallbacks.memberName(userId) : null;
      if (name) return t('groupMoney.rule.recurring_member_inactive_named', { name });
      break;
    }
    case 'invalid_status_transition':
      return statusTransitionMessage(params, t);
    case 'recurring_template_invalid': {
      const field = detailParam(params, 'field');
      if (field) return t('groupMoney.rule.recurring_template_invalid_field', { field });
      break;
    }
    default:
      break;
  }
  const key = ruleMessages[code];
  return key ? t(key) : t('errors.UNKNOWN_ERROR');
}

/** A localized sentence for a failed group money request. */
export function groupMoneyErrorMessage(
  error: unknown,
  t: Translate,
  locale: string,
  fallbacks: Fallbacks = {},
): string {
  const detail = errorDetail(error);
  if (detail && detail.code in ruleMessages) {
    return ruleMessage(detail.code, detail.params, t, locale, fallbacks);
  }
  if (fallbacks.conflict && hasErrorCode(error, 'CONFLICT')) return fallbacks.conflict;
  if (fallbacks.notFound && hasErrorCode(error, 'NOT_FOUND')) return fallbacks.notFound;
  if (fallbacks.forbidden && hasErrorCode(error, 'FORBIDDEN')) return fallbacks.forbidden;
  if (hasErrorCode(error, 'FORBIDDEN')) return t('groupMoney.errors.forbidden');
  return financeErrorMessage(error, t, locale);
}
