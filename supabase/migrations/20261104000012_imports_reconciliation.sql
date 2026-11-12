-- Statement imports: bank-provided unique IDs (e.g. OFX FITID), mapping
-- notes shown to the user, and cooperative cancellation of processing.
alter table import_rows add column external_id text check (char_length(external_id) <= 200);
alter table import_batches add column mapping_notes text[] not null default '{}';
alter table import_batches add column cancel_requested_at timestamptz;

-- Reconciliation side effects are recorded per item so an unmatch restores
-- the exact prior state; a transaction or statement row can belong to at
-- most one active match.
alter table reconciliation_match_items
  add column effect text not null default 'none' check (effect in ('none','voided','row_skipped')),
  add column prev_row_status text,
  add column prev_reconciliation_state text,
  add column active boolean not null default true;
create unique index reconciliation_items_active_tx_key on reconciliation_match_items (transaction_id)
  where active and transaction_id is not null;
create unique index reconciliation_items_active_row_key on reconciliation_match_items (import_row_id)
  where active and import_row_id is not null;

-- A receipt documents one transaction, and a transaction has one receipt.
create unique index receipts_transaction_key on receipts (transaction_id) where transaction_id is not null and status <> 'discarded';

-- A statement row (fingerprint) is imported at most once per account, even
-- across concurrent batches; voided imports free the fingerprint.
create unique index transactions_source_fingerprint_key on transactions (account_id, source_fingerprint)
  where source_fingerprint is not null and deleted_at is null;
