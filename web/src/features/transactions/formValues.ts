import type { TagSelection } from '@/shared/finance/components/TagPicker';
import type {
  Transaction,
  TransactionInput,
  TransactionPatch,
  TransactionType,
} from '@/shared/finance/types';
import { compareDecimal, decimalToInput } from '@/shared/formatting/decimal';

export type EntryStatus = 'posted' | 'pending' | 'draft';

export interface TransactionFormValues {
  type: TransactionType;
  accountId: string;
  amount: string;
  localDate: string;
  categoryId: string;
  merchant: string;
  description: string;
  paymentMethodId: string;
  tags: TagSelection;
  status: EntryStatus;
  notes: string;
  foreign: boolean;
  originalAmount: string;
  originalCurrency: string;
}

/** Canonical amounts after validation. */
export interface TransactionFormResult {
  values: TransactionFormValues;
  amount: string;
  originalAmount: string | null;
}

/**
 * Types whose money fields belong to their own workflow (transfers,
 * adjustments, opening balances, group records): only descriptive fields can
 * be edited on them, as the API enforces.
 */
export const METADATA_ONLY_TYPES: ReadonlySet<TransactionType> = new Set([
  'transfer',
  'opening_balance',
  'adjustment',
  'group_expense',
  'settlement',
]);

export function isEntryStatus(value: string): value is EntryStatus {
  return value === 'posted' || value === 'pending' || value === 'draft';
}

export function emptyTransactionValues(
  type: TransactionType,
  accountId: string,
  today: string,
  paymentMethodId = '',
): TransactionFormValues {
  return {
    type,
    accountId,
    amount: '',
    localDate: today,
    categoryId: '',
    merchant: '',
    description: '',
    paymentMethodId,
    tags: { tagIds: [], newNames: [] },
    status: 'posted',
    notes: '',
    foreign: false,
    originalAmount: '',
    originalCurrency: '',
  };
}

export function transactionToValues(
  transaction: Transaction,
  locale: string,
): TransactionFormValues {
  return {
    type: transaction.type,
    accountId: transaction.account_id,
    amount: decimalToInput(transaction.amount.amount, locale),
    localDate: transaction.local_date,
    categoryId: transaction.category?.id ?? '',
    merchant: transaction.merchant?.name ?? '',
    description: transaction.description ?? '',
    paymentMethodId: transaction.payment_method_id ?? '',
    tags: { tagIds: transaction.tags.map((tag) => tag.id), newNames: [] },
    status: isEntryStatus(transaction.status) ? transaction.status : 'posted',
    notes: transaction.notes ?? '',
    foreign: Boolean(transaction.original_amount),
    originalAmount: transaction.original_amount
      ? decimalToInput(transaction.original_amount.amount, locale)
      : '',
    originalCurrency: transaction.original_amount?.currency ?? '',
  };
}

export function toTransactionInput(result: TransactionFormResult): TransactionInput {
  const { values } = result;
  if (values.type !== 'expense' && values.type !== 'income') {
    throw new Error('Only expenses and income are created with this form');
  }
  const body: TransactionInput = {
    type: values.type,
    account_id: values.accountId,
    amount: result.amount,
    local_date: values.localDate,
  };
  if (values.status !== 'posted') body.status = values.status;
  if (values.categoryId) body.category_id = values.categoryId;
  if (values.merchant.trim()) body.merchant_name = values.merchant.trim();
  if (values.description.trim()) body.description = values.description.trim();
  if (values.paymentMethodId) body.payment_method_id = values.paymentMethodId;
  if (values.tags.tagIds.length > 0) body.tag_ids = values.tags.tagIds;
  if (values.tags.newNames.length > 0) body.tag_names = values.tags.newNames;
  if (values.notes.trim()) body.notes = values.notes.trim();
  if (values.foreign && result.originalAmount && values.originalCurrency) {
    body.original_amount = result.originalAmount;
    body.original_currency = values.originalCurrency;
  }
  return body;
}

function sameTags(transaction: Transaction, tags: TagSelection): boolean {
  if (tags.newNames.length > 0) return false;
  const current = new Set(transaction.tags.map((tag) => tag.id));
  return current.size === tags.tagIds.length && tags.tagIds.every((id) => current.has(id));
}

/** Only what changed, plus the version that was edited (optimistic concurrency). */
export function toTransactionPatch(
  transaction: Transaction,
  result: TransactionFormResult,
): TransactionPatch {
  const { values } = result;
  const patch: TransactionPatch = { version: transaction.version };
  const metadataOnly = METADATA_ONLY_TYPES.has(transaction.type);
  if (!metadataOnly) {
    if (values.accountId !== transaction.account_id) patch.account_id = values.accountId;
    if (compareDecimal(result.amount, transaction.amount.amount) !== 0)
      patch.amount = result.amount;
    if (values.localDate !== transaction.local_date) patch.local_date = values.localDate;
    const currentCategory = transaction.category?.id ?? '';
    if (values.categoryId !== currentCategory) {
      if (values.categoryId) patch.category_id = values.categoryId;
      else patch.clear_category = true;
    }
    if (values.status !== transaction.status && isEntryStatus(values.status)) {
      patch.status = values.status;
    }
    const currentMethod = transaction.payment_method_id ?? '';
    if (values.paymentMethodId !== currentMethod) {
      if (values.paymentMethodId) patch.payment_method_id = values.paymentMethodId;
      else patch.clear_payment_method = true;
    }
    const hadOriginal = Boolean(transaction.original_amount);
    if (!values.foreign && hadOriginal) {
      patch.clear_original = true;
    } else if (values.foreign && result.originalAmount && values.originalCurrency) {
      const original = transaction.original_amount;
      const changed =
        original?.currency !== values.originalCurrency ||
        compareDecimal(original.amount, result.originalAmount) !== 0;
      if (changed) {
        patch.original_amount = result.originalAmount;
        patch.original_currency = values.originalCurrency;
      }
    }
  }
  const merchant = values.merchant.trim();
  if (merchant !== (transaction.merchant?.name ?? '')) {
    if (merchant) patch.merchant_name = merchant;
    else patch.clear_merchant = true;
  }
  const description = values.description.trim();
  if (description !== (transaction.description ?? '')) patch.description = description;
  const notes = values.notes.trim();
  if (notes !== (transaction.notes ?? '')) patch.notes = notes;
  if (!sameTags(transaction, values.tags)) {
    patch.tag_ids = values.tags.tagIds;
    if (values.tags.newNames.length > 0) patch.tag_names = values.tags.newNames;
  }
  return patch;
}
