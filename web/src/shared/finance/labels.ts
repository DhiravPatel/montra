import type { IconName } from '@/shared/components/Icon';
import type { MessageKey } from '@/shared/i18n/types';
import type {
  Account,
  AccountType,
  DateRangePreset,
  PaymentMethodKind,
  PaymentNetwork,
  TransactionSort,
  TransactionSource,
  TransactionStatus,
  TransactionType,
} from './types';

/*
 * Localized labels for contract enums. The maps are typed against the
 * generated unions, so a value added to the contract fails compilation
 * until it has a label.
 */

export const ACCOUNT_TYPES = [
  'cash',
  'bank',
  'savings',
  'credit_card',
  'debit_card',
  'prepaid_card',
  'digital_wallet',
  'upi',
  'loan',
  'investment',
  'household_ledger',
  'custom',
] as const satisfies readonly AccountType[];

type MissingAccountTypes = Exclude<AccountType, (typeof ACCOUNT_TYPES)[number]>;
/** Compile-time check: every contract account type is listed above. */
export const accountTypesAreListed: [MissingAccountTypes] extends [never]
  ? true
  : MissingAccountTypes = true;

export const accountTypeLabel: Readonly<Record<AccountType, MessageKey>> = {
  cash: 'finance.accountType.cash',
  bank: 'finance.accountType.bank',
  savings: 'finance.accountType.savings',
  credit_card: 'finance.accountType.credit_card',
  debit_card: 'finance.accountType.debit_card',
  prepaid_card: 'finance.accountType.prepaid_card',
  digital_wallet: 'finance.accountType.digital_wallet',
  upi: 'finance.accountType.upi',
  loan: 'finance.accountType.loan',
  investment: 'finance.accountType.investment',
  household_ledger: 'finance.accountType.household_ledger',
  custom: 'finance.accountType.custom',
};

export const accountTypeGroupLabel: Readonly<Record<AccountType, MessageKey>> = {
  cash: 'finance.accountGroup.cash',
  bank: 'finance.accountGroup.bank',
  savings: 'finance.accountGroup.savings',
  credit_card: 'finance.accountGroup.credit_card',
  debit_card: 'finance.accountGroup.debit_card',
  prepaid_card: 'finance.accountGroup.prepaid_card',
  digital_wallet: 'finance.accountGroup.digital_wallet',
  upi: 'finance.accountGroup.upi',
  loan: 'finance.accountGroup.loan',
  investment: 'finance.accountGroup.investment',
  household_ledger: 'finance.accountGroup.household_ledger',
  custom: 'finance.accountGroup.custom',
};

export const accountTypeIcon: Readonly<Record<AccountType, IconName>> = {
  cash: 'banknote',
  bank: 'landmark',
  savings: 'landmark',
  credit_card: 'credit-card',
  debit_card: 'credit-card',
  prepaid_card: 'credit-card',
  digital_wallet: 'wallet',
  upi: 'smartphone',
  loan: 'receipt',
  investment: 'trending-up',
  household_ledger: 'users',
  custom: 'wallet',
};

export function isAccountType(value: string): value is AccountType {
  return (ACCOUNT_TYPES as readonly string[]).includes(value);
}

/**
 * Types whose balance is an amount owed. The contract documents this for
 * credit cards and loans ("enter the amount owed as negative"); for existing
 * accounts the API's `is_liability` is the source of truth.
 */
export const LIABILITY_ACCOUNT_TYPES: ReadonlySet<AccountType> = new Set(['credit_card', 'loan']);

export function accountLabel(account: Pick<Account, 'account_type'>): MessageKey {
  return isAccountType(account.account_type)
    ? accountTypeLabel[account.account_type]
    : 'finance.accountType.custom';
}

export function accountIcon(account: Pick<Account, 'account_type'>): IconName {
  return isAccountType(account.account_type) ? accountTypeIcon[account.account_type] : 'wallet';
}

export const transactionTypeLabel: Readonly<Record<TransactionType, MessageKey>> = {
  expense: 'finance.txType.expense',
  income: 'finance.txType.income',
  transfer: 'finance.txType.transfer',
  refund: 'finance.txType.refund',
  reimbursement: 'finance.txType.reimbursement',
  adjustment: 'finance.txType.adjustment',
  opening_balance: 'finance.txType.opening_balance',
  group_expense: 'finance.txType.group_expense',
  settlement: 'finance.txType.settlement',
};

export const TRANSACTION_TYPES = Object.keys(transactionTypeLabel) as TransactionType[];

export const transactionStatusLabel: Readonly<Record<TransactionStatus, MessageKey>> = {
  draft: 'finance.txStatus.draft',
  pending: 'finance.txStatus.pending',
  posted: 'finance.txStatus.posted',
  voided: 'finance.txStatus.voided',
  reversed: 'finance.txStatus.reversed',
};

export const transactionSourceLabel: Readonly<Record<TransactionSource, MessageKey>> = {
  manual: 'finance.source.manual',
  import: 'finance.source.import',
  receipt: 'finance.source.receipt',
  recurring: 'finance.source.recurring',
  integration: 'finance.source.integration',
  correction: 'finance.source.correction',
  group: 'finance.source.group',
  system: 'finance.source.system',
  '': 'finance.source.any',
};

export function sourceLabel(source: string): MessageKey {
  return source in transactionSourceLabel
    ? transactionSourceLabel[source as TransactionSource]
    : 'finance.source.other';
}

export const sortLabel: Readonly<Record<Exclude<TransactionSort, ''>, MessageKey>> = {
  date_desc: 'finance.sort.date_desc',
  date_asc: 'finance.sort.date_asc',
  amount_desc: 'finance.sort.amount_desc',
  amount_asc: 'finance.sort.amount_asc',
};

export const DATE_RANGE_PRESETS = [
  'today',
  'yesterday',
  'this_week',
  'last_week',
  'this_month',
  'last_month',
  'this_year',
  'last_year',
  'last_7_days',
  'last_30_days',
  'last_90_days',
] as const satisfies readonly DateRangePreset[];

export const rangeLabel: Readonly<Record<DateRangePreset, MessageKey>> = {
  today: 'finance.range.today',
  yesterday: 'finance.range.yesterday',
  this_week: 'finance.range.this_week',
  last_week: 'finance.range.last_week',
  this_month: 'finance.range.this_month',
  last_month: 'finance.range.last_month',
  this_year: 'finance.range.this_year',
  last_year: 'finance.range.last_year',
  last_7_days: 'finance.range.last_7_days',
  last_30_days: 'finance.range.last_30_days',
  last_90_days: 'finance.range.last_90_days',
};

export function isDateRangePreset(value: unknown): value is DateRangePreset {
  return typeof value === 'string' && (DATE_RANGE_PRESETS as readonly string[]).includes(value);
}

export const balanceSourceLabel: Readonly<Record<Account['balance_source'], MessageKey>> = {
  manual: 'finance.balanceSource.manual',
  calculated: 'finance.balanceSource.calculated',
  imported: 'finance.balanceSource.imported',
  provider: 'finance.balanceSource.provider',
};

export const reconciliationLabel: Readonly<
  Record<'unreconciled' | 'matched' | 'reconciled' | 'excluded', MessageKey>
> = {
  unreconciled: 'finance.reconciliation.unreconciled',
  matched: 'finance.reconciliation.matched',
  reconciled: 'finance.reconciliation.reconciled',
  excluded: 'finance.reconciliation.excluded',
};

export const PAYMENT_METHOD_KINDS = [
  'cash',
  'upi',
  'debit_card',
  'credit_card',
  'bank_transfer',
  'wallet',
  'cheque',
  'other',
] as const satisfies readonly PaymentMethodKind[];

export const paymentKindLabel: Readonly<Record<PaymentMethodKind, MessageKey>> = {
  cash: 'finance.paymentKind.cash',
  upi: 'finance.paymentKind.upi',
  debit_card: 'finance.paymentKind.debit_card',
  credit_card: 'finance.paymentKind.credit_card',
  bank_transfer: 'finance.paymentKind.bank_transfer',
  wallet: 'finance.paymentKind.wallet',
  cheque: 'finance.paymentKind.cheque',
  other: 'finance.paymentKind.other',
};

export const paymentKindIcon: Readonly<Record<PaymentMethodKind, IconName>> = {
  cash: 'banknote',
  upi: 'smartphone',
  debit_card: 'credit-card',
  credit_card: 'credit-card',
  bank_transfer: 'landmark',
  wallet: 'wallet',
  cheque: 'file',
  other: 'wallet',
};

export const PAYMENT_NETWORKS = [
  'visa',
  'mastercard',
  'rupay',
  'amex',
  'discover',
  'diners',
  'jcb',
  'upi',
  'other',
] as const satisfies readonly PaymentNetwork[];

export const networkLabel: Readonly<Record<PaymentNetwork, MessageKey>> = {
  visa: 'finance.network.visa',
  mastercard: 'finance.network.mastercard',
  rupay: 'finance.network.rupay',
  amex: 'finance.network.amex',
  discover: 'finance.network.discover',
  diners: 'finance.network.diners',
  jcb: 'finance.network.jcb',
  upi: 'finance.network.upi',
  other: 'finance.network.other',
};

export function isPaymentKind(value: string): value is PaymentMethodKind {
  return (PAYMENT_METHOD_KINDS as readonly string[]).includes(value);
}

export function isPaymentNetwork(value: string): value is PaymentNetwork {
  return (PAYMENT_NETWORKS as readonly string[]).includes(value);
}
