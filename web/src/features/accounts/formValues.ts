import { isAccountType } from '@/shared/finance/labels';
import type { Account } from '@/shared/finance/types';
import { absDecimal, decimalToInput } from '@/shared/formatting/decimal';

export interface AccountFormValues {
  name: string;
  /** An AccountType once chosen ('' until then). */
  accountType: string;
  currency: string;
  /** Create only. For credit cards and loans: the amount owed (entered as a positive number). */
  openingBalance: string;
  openingDate: string;
  institutionLabel: string;
  maskedNumber: string;
  creditLimit: string;
  statementDay: string;
  paymentDueDay: string;
  includeInOverview: boolean;
  notes: string;
}

/** Canonical amounts after validation (exact decimal strings for the API). */
export interface AccountFormResult {
  values: AccountFormValues;
  /** Signed as the API expects (negative = owed on credit cards and loans). */
  openingBalance: string | null;
  creditLimit: string | null;
}

export function emptyAccountValues(currency: string, today: string): AccountFormValues {
  return {
    name: '',
    accountType: '',
    currency,
    openingBalance: '',
    openingDate: today,
    institutionLabel: '',
    maskedNumber: '',
    creditLimit: '',
    statementDay: '',
    paymentDueDay: '',
    includeInOverview: true,
    notes: '',
  };
}

export function accountToValues(account: Account, locale: string): AccountFormValues {
  return {
    name: account.name,
    accountType: isAccountType(account.account_type) ? account.account_type : 'custom',
    currency: account.currency,
    openingBalance: '',
    openingDate: account.opening_date,
    institutionLabel: account.institution_label ?? '',
    maskedNumber: account.masked_number ?? '',
    creditLimit: account.credit_limit
      ? decimalToInput(absDecimal(account.credit_limit.amount), locale)
      : '',
    statementDay: account.statement_day ? String(account.statement_day) : '',
    paymentDueDay: account.payment_due_day ? String(account.payment_due_day) : '',
    includeInOverview: account.include_in_overview,
    notes: account.notes ?? '',
  };
}
