import type { Message } from '../../types';

/** English `transfers` messages (source of truth for their keys). */
const messages = {
  'transfers.add': 'Transfer',
  'transfers.create.title': 'Transfer between your accounts',
  'transfers.create.description':
    'Move money from one of your accounts to another, for example paying your credit card from your bank account.',
  'transfers.create.done': 'Transfer saved',
  'transfers.form.from': 'From account',
  'transfers.form.to': 'To account',
  'transfers.form.fromRequired': 'Choose the account the money leaves.',
  'transfers.form.toRequired': 'Choose the account the money goes to.',
  'transfers.form.sameAccount': 'Choose two different accounts.',
  'transfers.form.amount': 'Amount sent',
  'transfers.form.amountHelp': 'In the “from” account’s currency.',
  'transfers.form.crossCurrency':
    'These accounts use different currencies ({from} and {to}). Tell us how much arrived, or the exchange rate.',
  'transfers.form.fxMode': 'What do you know?',
  'transfers.form.fxAmount': 'The amount received',
  'transfers.form.fxRate': 'The exchange rate',
  'transfers.form.toAmount': 'Amount received',
  'transfers.form.rate': 'Exchange rate',
  'transfers.form.rateHelp': 'How many {to} for 1 {from}, for example 83.1234.',
  'transfers.form.fee': 'Fee',
  'transfers.form.feeHelp': 'Charged to the “from” account and recorded as a separate expense.',
  'transfers.form.submit': 'Save transfer',
  'transfers.form.notAllowed':
    'This transfer isn’t possible. Both accounts must be yours and active.',
  'transfers.form.needTwoTitle': 'You need two accounts',
  'transfers.form.needTwoBody':
    'A transfer moves money between two of your active accounts. Add another account first.',
} as const satisfies Record<string, Message>;

export default messages;
