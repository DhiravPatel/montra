import type {
  Candidate,
  Match,
  Reconciliation,
  StatementLine,
} from '@/features/reconciliation/types';
import { ACCOUNT_CASH, money } from './financeFixtures';
import { IMPORT_ID } from './importsFixtures';

/** Reconciliation fixtures shaped like the contract (tests only). */

export const RECON_ID = 'c0000000-0000-4000-8000-000000000001';
export const MATCH_ID = 'c0000000-0000-4000-8000-000000000002';
export const STATEMENT_ROW = 'e0000000-0000-4000-8000-000000000003';
export const TX_MANUAL = '77777777-7777-4777-8777-777777777720';
export const TX_IMPORTED_COPY = '77777777-7777-4777-8777-777777777721';
export const TX_PENDING = '77777777-7777-4777-8777-777777777722';
export const TX_POSTED = '77777777-7777-4777-8777-777777777723';

export function makeReconciliation(overrides: Partial<Reconciliation> = {}): Reconciliation {
  return {
    id: RECON_ID,
    account_id: ACCOUNT_CASH,
    statement_date: '2026-11-05',
    statement_balance: money('1.00'),
    ledger_balance: money('1500.50'),
    difference: money('-1499.50'),
    status: 'unbalanced',
    reconciled_count: 0,
    unmatched_statement_rows: 0,
    unreconciled_transactions: 6,
    created_at: '2026-11-05T08:55:54Z',
    ...overrides,
  };
}

/** A statement line that looks like a transaction entered by hand. */
export function statementCandidate(overrides: Partial<Candidate> = {}): Candidate {
  return {
    kind: 'statement_to_ledger',
    cardinality: 'one_to_one',
    left: {
      side: 'statement',
      import_row_id: STATEMENT_ROW,
      date: '2026-10-26',
      amount: money('1250.50'),
      direction: 'outflow',
      description: 'UPI-GROCER-WEEKLY SHOP',
      // eslint-disable-next-line @typescript-eslint/no-deprecated -- still required by the contract
      status: 'skipped',
      record_status: 'skipped',
    },
    right: [
      {
        side: 'ledger',
        transaction_id: TX_MANUAL,
        date: '2026-10-26',
        amount: money('1250.50'),
        direction: 'outflow',
        description: 'Grocer weekly shop',
        // eslint-disable-next-line @typescript-eslint/no-deprecated -- still required by the contract
        status: 'posted/manual',
        record_status: 'posted',
        source: 'manual',
      },
    ],
    confidence: '0.887',
    reasons: ['Same amount and direction', 'Same date', 'Similar description'],
    reason_codes: ['same_amount_direction', 'same_date', 'similar_description'],
    reason_params: { days_apart: '0' },
    ...overrides,
  };
}

/** The same income entered by hand and imported. */
export function duplicateCandidate(): Candidate {
  return {
    kind: 'manual_to_imported',
    cardinality: 'one_to_one',
    left: {
      side: 'ledger',
      transaction_id: TX_MANUAL,
      date: '2026-11-02',
      amount: money('1200.00'),
      direction: 'inflow',
      description: 'Interest',
      // eslint-disable-next-line @typescript-eslint/no-deprecated -- still required by the contract
      status: 'posted/manual',
      record_status: 'posted',
      source: 'manual',
    },
    right: [
      {
        side: 'ledger',
        transaction_id: TX_IMPORTED_COPY,
        date: '2026-11-02',
        amount: money('1200.00'),
        direction: 'inflow',
        description: 'INTEREST CREDIT',
        // eslint-disable-next-line @typescript-eslint/no-deprecated -- still required by the contract
        status: 'posted/import',
        record_status: 'posted',
        source: 'import',
      },
    ],
    confidence: '0.700',
    reasons: ['Same amount and direction', 'Same date'],
    reason_codes: ['same_amount_direction', 'same_date'],
    reason_params: { days_apart: '0' },
  };
}

export function makeMatch(overrides: Partial<Match> = {}): Match {
  return {
    id: MATCH_ID,
    account_id: ACCOUNT_CASH,
    kind: 'statement_to_ledger',
    cardinality: 'one_to_one',
    status: 'confirmed',
    confidence: '0.887',
    reasons: ['Same amount and direction', 'Same date', 'Similar description'],
    reason_codes: ['same_amount_direction', 'same_date', 'similar_description'],
    reason_params: { days_apart: '0' },
    total: money('1250.50'),
    items: [
      {
        side: 'statement',
        import_row_id: STATEMENT_ROW,
        date: '2026-10-26',
        direction: 'outflow',
        description: 'UPI-GROCER-WEEKLY SHOP',
        amount: money('1250.50'),
        effect: 'row_skipped',
        active: true,
        record_status: 'skipped',
      },
      {
        side: 'ledger',
        transaction_id: TX_MANUAL,
        date: '2026-10-26',
        direction: 'outflow',
        description: 'Grocer weekly shop',
        amount: money('1250.50'),
        effect: 'none',
        active: true,
        record_status: 'posted',
        source: 'manual',
      },
    ],
    confirmed_at: '2026-11-05T08:55:54Z',
    created_at: '2026-11-05T08:55:54Z',
    ...overrides,
  };
}

export const STATEMENT_ROW_COFFEE = 'e0000000-0000-4000-8000-000000000005';

/** A statement line the matcher found nothing for: the user can match it by hand. */
export function makeStatementLine(overrides: Partial<StatementLine> = {}): StatementLine {
  return {
    import_row_id: STATEMENT_ROW_COFFEE,
    batch_id: IMPORT_ID,
    row_number: 5,
    date: '2026-10-28',
    amount: money('120.00'),
    direction: 'outflow',
    description: 'COFFEE HOUSE',
    record_status: 'ready',
    ...overrides,
  };
}
