-- Recurring schedules: owners may remove open future occurrences when they
-- edit "this and future", pause or stop a rule. Occurrences that were
-- posted, paid, skipped or linked to a transaction are history and remain.
create policy app_ro_delete on recurring_occurrences for delete to montra_app
  using (user_id = montra.current_user_id() and status = 'scheduled' and transaction_id is null);

-- A transaction can satisfy at most one occurrence (mark-paid by linking
-- never double counts a payment).
create unique index recurring_occurrences_tx_key on recurring_occurrences (transaction_id) where transaction_id is not null;
drop index if exists recurring_occurrences_tx_idx;

-- Auto-post failures are tracked per occurrence: a missed scheduler run is
-- always recovered, while an occurrence whose posting keeps failing (for
-- example, an archived account) is retried for a bounded window and then
-- handed to the user as overdue.
alter table recurring_occurrences
  add column auto_post_attempts smallint not null default 0 check (auto_post_attempts >= 0),
  add column first_failed_at timestamptz,
  add column last_failure_code text check (char_length(last_failure_code) <= 64);
