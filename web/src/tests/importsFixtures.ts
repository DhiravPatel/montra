import { http, HttpResponse } from 'msw';
import type { FileRecord } from '@/shared/files/upload';
import type { ImportBatch, ImportRow, ImportRowPage } from '@/features/imports/types';
import { API, envelope } from './fixtures';
import { ACCOUNT_CASH, money } from './financeFixtures';

/** Statement import fixtures shaped like the contract (tests only). */

export const IMPORT_ID = 'a1111111-1111-4111-8111-111111111111';
export const IMPORT_OLD = 'a2222222-2222-4222-8222-222222222222';
export const FILE_ID = 'f1111111-1111-4111-8111-111111111111';
export const ROW_PREAMBLE = 'e0000000-0000-4000-8000-000000000001';
export const ROW_HEADER = 'e0000000-0000-4000-8000-000000000002';
export const ROW_DUPLICATE = 'e0000000-0000-4000-8000-000000000003';
export const ROW_SALARY = 'e0000000-0000-4000-8000-000000000004';
export const ROW_COFFEE = 'e0000000-0000-4000-8000-000000000005';
export const ROW_INVALID = 'e0000000-0000-4000-8000-000000000007';
export const ROW_FAILED = 'e0000000-0000-4000-8000-000000000008';
export const TX_EXISTING = '77777777-7777-4777-8777-777777777710';
export const TX_IMPORTED = '77777777-7777-4777-8777-777777777711';

/** A previewed CSV import of the wallet: what the server returns once rows are read. */
export function makeBatch(overrides: Partial<ImportBatch> = {}): ImportBatch {
  return {
    id: IMPORT_ID,
    account_id: ACCOUNT_CASH,
    currency: 'INR',
    file_id: FILE_ID,
    source_format: 'csv',
    parser_version: 'csv-1',
    status: 'preview_ready',
    encoding: 'utf-8',
    header: ['Txn Date', 'Narration', 'Ref No', 'Withdrawal Amt', 'Deposit Amt', 'Closing Balance'],
    mapping: {
      header_row: 1,
      date_column: 0,
      date_format: 'DD/MM/YYYY',
      sign_convention: 'negative_is_outflow',
      debit_column: 3,
      credit_column: 4,
      decimal_separator: '.',
      description_columns: [1],
      reference_column: 2,
      balance_column: 5,
    },
    mapping_notes: [],
    mapping_note_codes: [],
    mapping_note_params: {},
    total_rows: 5,
    valid_rows: 3,
    invalid_rows: 1,
    duplicate_rows: 1,
    to_import_rows: 2,
    imported_count: 0,
    skipped_count: 0,
    failed_count: 0,
    statement_start: '2026-10-26',
    statement_end: '2026-11-03',
    statement_opening_balance: money('50000.00'),
    statement_closing_balance: money('108629.50'),
    totals: {
      valid_rows: 3,
      inflow: money('60000.00'),
      outflow: money('1370.50'),
      net: money('58629.50'),
      inflow_minor: 6000000,
      outflow_minor: 137050,
      net_minor: 5862950,
      balance_check: 'ok',
      opening_balance: money('50000.00'),
      closing_balance: money('108629.50'),
      opening_balance_minor: 5000000,
      closing_balance_minor: 10862950,
      first_date: '2026-10-26',
      last_date: '2026-11-03',
      order: 'ascending',
    },
    cancel_requested: false,
    version: 1,
    created_at: '2026-11-05T08:55:53Z',
    ...overrides,
  };
}

/** A just-created import: the server reads the file in the background. */
export function makeNewBatch(overrides: Partial<ImportBatch> = {}): ImportBatch {
  return makeBatch({
    status: 'uploaded',
    header: [],
    mapping: undefined,
    mapping_notes: [],
    mapping_note_codes: [],
    mapping_note_params: {},
    total_rows: 0,
    valid_rows: 0,
    invalid_rows: 0,
    duplicate_rows: 0,
    to_import_rows: 0,
    statement_start: undefined,
    statement_end: undefined,
    statement_opening_balance: undefined,
    statement_closing_balance: undefined,
    totals: undefined,
    parser_version: undefined,
    encoding: undefined,
    ...overrides,
  });
}

/** A file without recognizable headings: the user maps the columns. */
export function makeUnmappedBatch(overrides: Partial<ImportBatch> = {}): ImportBatch {
  return makeNewBatch({
    status: 'needs_mapping',
    parser_version: 'csv-1',
    encoding: 'utf-8',
    mapping: {
      header_row: -1,
      date_column: -1,
      date_format: '',
      sign_convention: 'negative_is_outflow',
      decimal_separator: '.',
    },
    mapping_notes: ['No header row was found; map the columns manually.'],
    mapping_note_codes: ['no_header_row'],
    ...overrides,
  });
}

export function makeRow(overrides: Partial<ImportRow> = {}): ImportRow {
  return {
    id: ROW_SALARY,
    row_number: 4,
    raw: ['27/10/2026', 'SALARY ACME LTD', 'NEFT77', '', '60,000.00', '1,08,749.50'],
    posted_date: '2026-10-27',
    amount: money('60000.00'),
    direction: 'inflow',
    description: 'SALARY ACME LTD',
    reference: 'NEFT77',
    balance: money('108749.50'),
    status: 'ready',
    ...overrides,
  };
}

/** The rows of the previewed import, in file order. */
export function previewRows(): ImportRow[] {
  return [
    {
      id: ROW_PREAMBLE,
      row_number: 1,
      raw: ['Statement for account XXXX1234'],
      status: 'skipped',
      error_code: 'preamble',
      error_message: 'Text before the header row.',
    },
    {
      id: ROW_HEADER,
      row_number: 2,
      raw: ['Txn Date', 'Narration', 'Ref No', 'Withdrawal Amt', 'Deposit Amt', 'Closing Balance'],
      status: 'skipped',
      error_code: 'header',
      error_message: 'Header row.',
    },
    makeRow({
      id: ROW_DUPLICATE,
      row_number: 3,
      raw: ['26/10/2026', 'UPI-GROCER-WEEKLY SHOP', 'UPI001', '1,250.50', '', '48,749.50'],
      posted_date: '2026-10-26',
      amount: money('1250.50'),
      direction: 'outflow',
      description: 'UPI-GROCER-WEEKLY SHOP',
      reference: 'UPI001',
      balance: money('48749.50'),
      status: 'duplicate',
      error_code: 'possible_duplicate',
      error_message:
        'Possible duplicate of an existing transaction (Same amount and direction, Same date, Similar description).',
      error_params: { days_apart: '0' },
      duplicate_reason_codes: ['same_amount_direction', 'same_date', 'similar_description'],
      duplicate_of_transaction_id: TX_EXISTING,
    }),
    makeRow(),
    makeRow({
      id: ROW_COFFEE,
      row_number: 5,
      raw: ['28/10/2026', 'COFFEE HOUSE', '', '120.00', '', '1,08,629.50'],
      posted_date: '2026-10-28',
      amount: money('120.00'),
      direction: 'outflow',
      description: 'COFFEE HOUSE',
      reference: undefined,
      balance: money('108629.50'),
    }),
    {
      id: ROW_INVALID,
      row_number: 7,
      raw: ['31/10/2026', 'BOOKSTORE', '', 'abc', '', '1,08,509.50'],
      status: 'invalid',
      error_code: 'bad_amount',
      error_field: 'amount',
      error_params: { currency: 'INR' },
      error_message: 'The debit or credit is not a number in INR precision.',
    },
  ];
}

/** The raw rows of a file without headings (all rows still "parsed"). */
export function unmappedRows(): ImportRow[] {
  return [
    ['When', 'What', 'How much'],
    ['2026-11-02', 'Lunch', '-250.00'],
    ['2026-11-03', 'Refund', '80.00'],
  ].map((raw, index) => ({
    id: `e1000000-0000-4000-8000-00000000000${index + 1}`,
    row_number: index + 1,
    raw,
    status: 'parsed' as const,
  }));
}

/** The list envelope of a cursor-paged endpoint (`meta.next_cursor` / `has_more`). */
export function pageEnvelope<T>(data: T[], nextCursor?: string) {
  const base = envelope(data);
  return {
    ...base,
    meta: {
      ...base.meta,
      has_more: nextCursor !== undefined,
      ...(nextCursor === undefined ? {} : { next_cursor: nextCursor }),
    },
  };
}

export function rowsPage(rows: ImportRow[], nextCursor?: number): ImportRowPage {
  return { rows, ...(nextCursor === undefined ? {} : { next_cursor: nextCursor }) };
}

/** Serves GET /imports/{id}/rows from a list, honouring the status filter and the cursor. */
export function serveRows(rows: () => ImportRow[], seen: URL[] = []) {
  return http.get(`${API}/imports/:id/rows`, ({ request }) => {
    const url = new URL(request.url);
    seen.push(url);
    const status = url.searchParams.get('status') ?? '';
    const after = Number(url.searchParams.get('after_row') ?? '0');
    const limit = Number(url.searchParams.get('limit') ?? '200');
    const matching = rows().filter(
      (row) => (status === '' || row.status === status) && row.row_number > after,
    );
    const page = matching.slice(0, limit);
    const next = matching.length > limit ? page[page.length - 1]?.row_number : undefined;
    return HttpResponse.json(envelope(rowsPage(page, next)));
  });
}

export function fileRecord(status: FileRecord['status']): FileRecord {
  return {
    id: FILE_ID,
    purpose: 'statement_import',
    status,
    original_filename: 'statement.csv',
    content_type: 'text/csv',
    size_bytes: 120,
    created_at: '2026-11-05T08:55:53Z',
  };
}

/** The upload flow for a statement: intent → bytes → complete. */
export function uploadHandlers(seen: string[] = []) {
  return [
    http.post(`${API}/files/upload-intent`, () => {
      seen.push('intent');
      return HttpResponse.json(
        envelope({
          file: fileRecord('pending_upload'),
          upload_url: `http://localhost:8080/api/v1/files/${FILE_ID}/content`,
          method: 'PUT',
          headers: { 'X-Upload-Token': 'tok-123', 'Content-Type': 'application/octet-stream' },
          expires_at: '2026-11-05T09:10:00Z',
          max_bytes: 10485760,
        }),
        { status: 201 },
      );
    }),
    http.put(`${API}/files/:id/content`, () => {
      seen.push('content');
      return HttpResponse.json(envelope(fileRecord('uploaded')));
    }),
    http.post(`${API}/files/:id/complete`, () => {
      seen.push('complete');
      return HttpResponse.json(envelope(fileRecord('ready')));
    }),
  ];
}

export function statementFile(name = 'statement.csv', type = 'text/csv') {
  return new File(['Txn Date,Narration,Amount\n26/10/2026,Coffee,-120.00\n'], name, { type });
}
