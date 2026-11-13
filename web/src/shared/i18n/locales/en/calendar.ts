import type { Message } from '../../types';

/** English `calendar` messages (source of truth for their keys). */
const messages = {
  'calendar.title': 'Upcoming',
  'calendar.description':
    'Bills, recurring money, subscription renewals and goal dates in one place.',
  'calendar.loading': 'Loading what’s coming up…',
  'calendar.error': 'We couldn’t load your calendar',
  'calendar.empty.title': 'Nothing planned for {month}',
  'calendar.empty.body':
    'Add your bills and regular income or expenses to see them here before they’re due.',
  'calendar.previous': 'Previous month',
  'calendar.next': 'Next month',
  'calendar.thisMonth': 'This month',
  'calendar.showing': 'Showing {month}',
  'calendar.today': 'Today',
  'calendar.projectedNote':
    'Estimated items are worked out from the schedule and haven’t been created yet.',
  'calendar.kind.recurring': 'Recurring',
  'calendar.kind.bill': 'Bill',
  'calendar.kind.group_expense': 'Shared expense',
  'calendar.kind.subscription_renewal': 'Subscription renewal',
  'calendar.kind.trial_end': 'Free trial ends',
  'calendar.kind.goal_target': 'Goal target date',
  'calendar.status.projected': 'Estimated',
  'calendar.status.expected': 'Expected',
  'calendar.status.target': 'Target',
  'calendar.movedFrom': 'Moved from {date}',
  'calendar.commitments.title': 'Regular commitments',
  'calendar.commitments.description':
    'What your active schedules add up to, per month and per currency.',
  'calendar.commitments.loading': 'Loading commitments…',
  'calendar.commitments.error': 'We couldn’t load your regular commitments',
  'calendar.commitments.empty': 'No regular commitments yet.',
  'calendar.commitments.kind.expense': 'Recurring expenses',
  'calendar.commitments.kind.income': 'Recurring income',
  'calendar.commitments.kind.transfer': 'Recurring transfers',
  'calendar.commitments.kind.bill': 'Bills',
  'calendar.commitments.kind.subscription': 'Subscriptions',
  'calendar.commitments.kind.group_expense': 'Shared expenses',
  'calendar.commitments.count': { one: '{count} schedule', other: '{count} schedules' },
  'calendar.commitments.monthly': 'Per month',
  'calendar.commitments.next30': 'Next 30 days',
  'calendar.commitments.variable': {
    one: '{count} schedule has a changing amount and isn’t included.',
    other: '{count} schedules have changing amounts and aren’t included.',
  },
  'calendar.commitments.note.fixed_amounts_expectations':
    'Only fixed amounts are counted. Bills and income are what you expect, not money recorded yet.',
} as const satisfies Record<string, Message>;

export default messages;
