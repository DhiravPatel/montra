import type { Account, AccountPatch } from '@/shared/finance/types';
import { compareDecimal } from '@/shared/formatting/decimal';
import type { AccountFormResult } from './formValues';

/** Only the fields the person changed, plus the version they edited (optimistic concurrency). */
export function toAccountPatch(account: Account, result: AccountFormResult): AccountPatch {
  const { values, creditLimit } = result;
  const patch: AccountPatch = { version: account.version };
  const name = values.name.trim();
  if (name !== account.name) patch.name = name;
  if (values.currency !== account.currency) patch.currency = values.currency;
  const institution = values.institutionLabel.trim();
  if (institution !== (account.institution_label ?? '')) patch.institution_label = institution;
  const masked = values.maskedNumber.trim();
  if (masked !== (account.masked_number ?? '')) patch.masked_number = masked;
  if (values.includeInOverview !== account.include_in_overview) {
    patch.include_in_overview = values.includeInOverview;
  }
  const currentLimit = account.credit_limit?.amount ?? null;
  const limitChanged =
    creditLimit === null
      ? currentLimit !== null
      : currentLimit === null || compareDecimal(creditLimit, currentLimit) !== 0;
  if (limitChanged) {
    patch.credit_limit = creditLimit ?? ''; // empty string clears
  }
  // 0 clears a day that was set.
  const statementDay = values.statementDay ? Number(values.statementDay) : 0;
  if (statementDay !== (account.statement_day ?? 0)) patch.statement_day = statementDay;
  const dueDay = values.paymentDueDay ? Number(values.paymentDueDay) : 0;
  if (dueDay !== (account.payment_due_day ?? 0)) patch.payment_due_day = dueDay;
  const notes = values.notes.trim();
  if (notes !== (account.notes ?? '')) patch.notes = notes;
  return patch;
}
