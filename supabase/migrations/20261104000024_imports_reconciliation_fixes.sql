-- Imports and reconciliation fixes reported by the web client: stable codes
-- and values next to English reasons, reconciliation counts kept with the
-- history, the exact row state an unmatch restores, and indexes for keyset
-- pages. Forward-only and safe to re-run.
set local search_path = montra, extensions, public;

---------------------------------------------------------------------------
-- Import rows and batches
---------------------------------------------------------------------------
-- Values an error_code refers to (the row's currency for currency_mismatch,
-- the voided and kept counts of a rollback, ...). error_message stays the
-- English fallback.
alter table import_rows add column if not exists error_params jsonb
  check (error_params is null or jsonb_typeof(error_params) = 'object');
alter table import_batches add column if not exists error_params jsonb
  check (error_params is null or jsonb_typeof(error_params) = 'object');

-- possible_duplicate rows: why the row may repeat duplicate_of_transaction_id
-- (the reconciliation reason codes).
alter table import_rows add column if not exists duplicate_reason_codes text[];

-- Mapping notes carry stable codes (same order as mapping_notes) and the
-- values the codes refer to.
alter table import_batches add column if not exists mapping_note_codes text[] not null default '{}';
alter table import_batches add column if not exists mapping_note_params jsonb not null default '{}'::jsonb
  check (jsonb_typeof(mapping_note_params) = 'object');

-- Notes written before codes existed get theirs when every note is known
-- (otherwise clients keep showing the English notes).
update import_batches b set mapping_note_codes = c.codes, mapping_note_params = c.params
from (
  select x.id,
    array_agg(case
      when n.note = 'No header row was found; map the columns manually.' then 'no_header_row'
      when n.note like 'Dates could be day-first or month-first; day-first (%) was assumed.' then 'ambiguous_date_order'
      when n.note = 'The date format was not recognized.' then 'unknown_date_format'
      when n.note = 'Amounts use a decimal comma.' then 'decimal_comma'
      when n.note = 'Some required columns were not recognized; complete the mapping.' then 'mapping_incomplete'
      when n.note = 'Check whether negative amounts are money out (default) or money in.' then 'check_sign_convention'
      when n.note = 'Read by AI from a PDF: check every row, date and amount before confirming.' then 'pdf_read_by_ai'
    end order by n.ord) as codes,
    coalesce(jsonb_object_agg('assumed_date_format', substring(n.note from 'day-first \((.+)\) was assumed'))
      filter (where n.note like 'Dates could be day-first or month-first; day-first (%) was assumed.'), '{}'::jsonb) as params
  from import_batches x cross join lateral unnest(x.mapping_notes) with ordinality as n(note, ord)
  where cardinality(x.mapping_note_codes) = 0
  group by x.id
) c
where b.id = c.id and array_position(c.codes, null) is null;
update import_batches set mapping_note_params = mapping_note_params || jsonb_build_object('alternative_date_format',
    regexp_replace(mapping_note_params->>'assumed_date_format', '^DD(.)MM', 'MM\1DD'))
where (mapping_note_params ? 'assumed_date_format') and not (mapping_note_params ? 'alternative_date_format');

-- Keyset pages of an account's imports.
create index if not exists import_batches_account_idx on import_batches (account_id, created_at desc, id desc);

---------------------------------------------------------------------------
-- Reconciliation
---------------------------------------------------------------------------
-- Matches carry stable reason codes (same order as reasons) and the values
-- the codes refer to.
alter table reconciliation_matches add column if not exists reason_codes text[] not null default '{}';
alter table reconciliation_matches add column if not exists reason_params jsonb not null default '{}'::jsonb
  check (jsonb_typeof(reason_params) = 'object');

update reconciliation_matches m set reason_codes = c.codes
from (
  select x.id,
    array_agg(case
      when r.reason = 'Same amount and direction' then 'same_amount_direction'
      when r.reason = 'Same date' then 'same_date'
      when r.reason = 'One day apart' then 'one_day_apart'
      when r.reason = 'Within 3 days' then 'within_3_days'
      when r.reason = 'Within a week' then 'within_a_week'
      when r.reason = 'Same reference' then 'same_reference'
      when r.reason = 'Similar description' then 'similar_description'
      when r.reason = 'Amounts add up exactly' then 'amounts_add_up'
      when r.reason = 'All within a week' then 'all_within_a_week'
      when r.reason = 'Pending authorization replaced by the posted transaction' then 'pending_replaced_by_posted'
      when r.reason like 'Amounts differ (% pending, % posted)' then 'pending_amount_differs'
      when r.reason = 'The same transaction was entered manually and imported' then 'entered_manually_and_imported'
    end order by r.ord) as codes
  from reconciliation_matches x cross join lateral jsonb_array_elements_text(x.reasons) with ordinality as r(reason, ord)
  where cardinality(x.reason_codes) = 0
  group by x.id
) c
where m.id = c.id and array_position(c.codes, null) is null;

-- An unmatch restores the statement row exactly as it was (reason, values,
-- duplicate link and the user's decision), not just its status.
alter table reconciliation_match_items add column if not exists prev_row_state jsonb
  check (prev_row_state is null or jsonb_typeof(prev_row_state) = 'object');

-- Keyset pages of an account's matches.
create index if not exists reconciliation_matches_account_idx on reconciliation_matches (account_id, created_at desc, id desc);

-- Reconciliation history keeps what each reconciliation found. NULL means
-- the value was not recorded (reconciliations made before this migration).
alter table account_reconciliations add column if not exists reconciled_count integer check (reconciled_count >= 0);
alter table account_reconciliations add column if not exists unmatched_statement_rows integer check (unmatched_statement_rows >= 0);
alter table account_reconciliations add column if not exists unreconciled_transactions integer check (unreconciled_transactions >= 0);

-- The number of transactions an earlier reconciliation marked reconciled is
-- in its audit event.
update account_reconciliations r set reconciled_count = (e.changes->>'reconciled')::integer
from audit_events e
where e.entity_type = 'account_reconciliation' and e.entity_id = r.id and r.reconciled_count is null
  and coalesce(e.changes->>'reconciled', '') ~ '^[0-9]{1,9}$';
