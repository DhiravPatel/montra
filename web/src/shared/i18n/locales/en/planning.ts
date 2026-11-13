import type { Message } from '../../types';

/** English `planning` messages (source of truth for their keys). */
const messages = {
  // Round 2: planning (calendar, bills, recurring items, schedules)
  'planning.subnav.label': 'Planning sections',
  'planning.subnav.upcoming': 'Upcoming',
  'planning.subnav.bills': 'Bills',
  'planning.subnav.recurring': 'Recurring',
  'planning.rule.bill_inactive': 'This bill is archived. Restore it before recording payments.',
  'planning.rule.transfer_needs_two_accounts': 'A recurring transfer needs two different accounts.',
  'planning.rule.cross_currency_transfer_not_auto_posted':
    'Transfers between currencies need the received amount each time, so they can’t be recorded automatically.',
  'planning.rule.bills_not_auto_posted':
    'Bills are confirmed by linking or recording the actual payment, not automatically.',
  'planning.rule.auto_post_needs_amount_and_account':
    'Recording automatically needs a fixed amount and an account.',
  'planning.rule.use_bill_screen':
    'This schedule belongs to a bill. Change it from the bill’s page.',
  'planning.rule.postpone_needs_later_open_occurrence':
    'Choose a later date. Only upcoming or overdue items can be moved.',
  'planning.rule.transaction_voided': 'That transaction was deleted, so it can’t be linked.',
  'planning.rule.transfer_missing_destination':
    'This transfer has no destination account. Edit the schedule first.',
  'planning.errors.alreadyHandled':
    'This was already handled or changed. We’ve refreshed it, so check and try again if needed.',
  'planning.errors.alreadyLinked':
    'That transaction is already linked to another payment. Choose a different one.',
  'planning.errors.changedElsewhere':
    'This was changed somewhere else. We’ve loaded the latest version; try again.',
  'planning.conflict.schedule_ended':
    'This schedule has ended. Edit it to set new dates before resuming it.',
  'planning.conflict.rule_in_use':
    'This item is in use, so it can’t be deleted. Stop it instead; its history is kept.',
  'planning.conflict.no_open_occurrence':
    'There’s nothing unpaid or upcoming here right now. We’ve refreshed it.',
  'planning.conflict.occurrence_not_open':
    'This payment is already paid or skipped. We’ve refreshed it, so check before trying again.',
  'planning.conflict.occurrence_not_skipped':
    'Only skipped items can be made due again. We’ve refreshed it.',
  'planning.conflict.occurrence_already_handled':
    'This was already recorded, linked or skipped. We’ve refreshed it, so check before trying again.',
} as const satisfies Record<string, Message>;

export default messages;
