import type { Message } from '../../types';

/** English `fx` messages (source of truth for their keys). */
const messages = {
  // Exchange rates
  'fx.title': 'Exchange rates',
  'fx.description': 'Rates for showing and converting amounts between currencies.',
  'fx.explain.title': 'Rates never change your records',
  'fx.explain.body':
    'Exchange rates are only used to show converted totals and to convert amounts here. Every transaction keeps the currency and amount you recorded, and adding or deleting a rate never changes it.',
  'fx.explain.history':
    'Rates are kept as history: a new rate applies from its date, and your own rates are used before provider rates.',
  'fx.rate.equation': '1 {base} = {rate} {quote}',
  'fx.rate.asOf': 'As of {date}',
  'fx.rate.inverted': 'Worked out from the {base} → {quote} rate.',
  'fx.source.manual': 'Manual rate',
  'fx.source.mine': 'Your rate',
  'fx.source.ecb': 'European Central Bank',
  'fx.source.provider': 'Rate provider',
  'fx.currencies.loading': 'Loading currencies…',
  'fx.currencies.error': 'We couldn’t load the list of currencies',
  'fx.form.chooseCurrency': 'Choose a currency',
  'fx.form.currencyRequired': 'Choose a currency.',
  'fx.form.sameCurrency': 'Choose a different currency from the first one.',
  'fx.form.pairInvalid': 'Choose two different supported currencies.',
  'fx.form.rateRequired': 'Enter a rate.',
  'fx.form.rateZero': 'Enter a rate greater than zero.',
  'fx.form.rateDecimalMark':
    'Use the comma for decimals and no other separators, for example {example}.',
  'fx.form.dateFuture': 'Choose today or an earlier date.',
  'fx.convert.title': 'Convert an amount',
  'fx.convert.description':
    'See an amount in another currency, with the rate used. Nothing is saved.',
  'fx.convert.from': 'From',
  'fx.convert.to': 'To',
  'fx.convert.amount': 'Amount',
  'fx.convert.policy': 'Rate to use',
  'fx.convert.policyCurrent': 'Latest rate',
  'fx.convert.policyHistorical': 'Rate on a date',
  'fx.convert.date': 'Date',
  'fx.convert.submit': 'Convert',
  'fx.convert.resultTitle': 'Converted amount',
  'fx.convert.usedCurrent': 'The latest available rate was used.',
  'fx.convert.usedHistorical': 'The latest rate on or before {date} was used.',
  'fx.convert.rounded': 'The result is rounded to the smallest unit of the currency.',
  'fx.convert.noRate':
    'No exchange rate is available for {from} → {to}. Add a rate below to convert between them.',
  'fx.convert.amountInvalid': 'Enter the amount in {currency} precision.',
  'fx.add.title': 'Add your own rate',
  'fx.add.description':
    'Use your own rate, for example the one your bank or card gave you. It is used before provider rates.',
  'fx.add.base': 'From currency',
  'fx.add.quote': 'To currency',
  'fx.add.rate': 'Rate',
  'fx.add.rateHelp':
    'How much of the second currency one unit of the first is worth, with up to {count} decimal places.',
  'fx.add.date': 'Applies from',
  'fx.add.dateHelp': 'A rate for the same pair and date replaces that day’s rate.',
  'fx.add.submit': 'Save rate',
  'fx.add.done': 'Rate saved',
  'fx.list.title': 'Rates',
  'fx.list.description':
    'The latest rate for each currency pair. Earlier rates are kept for history.',
  'fx.list.filters': 'Filter rates',
  'fx.list.base': 'From currency',
  'fx.list.quote': 'To currency',
  'fx.list.anyCurrency': 'Any currency',
  'fx.list.loading': 'Loading exchange rates…',
  'fx.list.error': 'We couldn’t load exchange rates',
  'fx.list.empty': 'No exchange rates yet',
  'fx.list.noMatches': 'No rates for these currencies',
  'fx.list.emptyBody':
    'Add your own rate to convert between two currencies. Rates from a provider appear here when one is set up.',
  'fx.list.mine': 'Your rates',
  'fx.list.provider': 'Provider rates',
  'fx.stale.list': 'Exchange rates couldn’t be refreshed, so this list may be out of date.',
  'fx.delete.action': 'Delete rate {pair}',
  'fx.delete.title': 'Delete this rate?',
  'fx.delete.body':
    'Conversions will use your earlier rate for this pair, or a provider rate if there is one. Your transactions don’t change.',
  'fx.delete.confirm': 'Delete rate',
  'fx.delete.done': 'Rate deleted',
  'fx.delete.gone': 'This rate was already deleted',
} as const satisfies Record<string, Message>;

export default messages;
