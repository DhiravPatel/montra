import type { Message } from '../../types';

/** English `categories` messages (source of truth for their keys). */
const messages = {
  // Categories (starter names are localized by system key)
  'categories.uncategorized': 'Uncategorized',
  'categories.starter.food_dining': 'Food & dining',
  'categories.starter.groceries': 'Groceries',
  'categories.starter.transport': 'Transport',
  'categories.starter.fuel': 'Fuel',
  'categories.starter.housing_rent': 'Housing & rent',
  'categories.starter.utilities': 'Utilities',
  'categories.starter.shopping': 'Shopping',
  'categories.starter.healthcare': 'Healthcare',
  'categories.starter.education': 'Education',
  'categories.starter.entertainment': 'Entertainment',
  'categories.starter.travel': 'Travel',
  'categories.starter.personal_care': 'Personal care',
  'categories.starter.insurance': 'Insurance',
  'categories.starter.taxes_fees': 'Taxes & fees',
  'categories.starter.gifts_donations': 'Gifts & donations',
  'categories.starter.family': 'Family',
  'categories.starter.work_expenses': 'Work expenses',
  'categories.starter.salary': 'Salary',
  'categories.starter.freelance_income': 'Freelance income',
  'categories.starter.interest': 'Interest',
  'categories.starter.refunds': 'Refunds',
  'categories.starter.other': 'Other',
  'categories.kind.expense': 'Spending',
  'categories.kind.income': 'Income',
  'categories.kind.both': 'Spending and income',
} as const satisfies Record<string, Message>;

export default messages;
