-- Query plan review indexes R1-R3 (DB-005, docs/QUERY_PLAN_REVIEW.md).
--   R1 transactions (group_expense_id): the per-row "my transaction" lookup
--      in the group expense list seq scanned transactions for every expense,
--      and the ON DELETE SET NULL action from group_expenses had no index.
--   R2 transactions (settlement_id): the same pattern in the settlements
--      list and jobs, and the ON DELETE SET NULL action from settlements.
--   R3 budget_members (user_id): the budget list selects the caller's
--      memberships by user (the primary key leads with budget_id).
-- Idempotent and forward-only.
--
-- Production rollout: these are plain CREATE INDEX statements, which hold a
-- SHARE lock on the table (writes wait) while the index builds. cmd/migrate
-- runs a file marked "-- montra:no-transaction" as one multi-statement
-- query, which PostgreSQL still treats as an implicit transaction block, so
-- CREATE INDEX CONCURRENTLY cannot be used in a file with several statements.
-- On a populated database, build each index beforehand from a psql session
-- as the owner role, one statement at a time (outside any transaction):
--   create index concurrently if not exists transactions_group_expense_idx
--     on montra.transactions (group_expense_id) where group_expense_id is not null;
--   create index concurrently if not exists transactions_settlement_idx
--     on montra.transactions (settlement_id) where settlement_id is not null;
--   create index concurrently if not exists budget_members_user_idx
--     on montra.budget_members (user_id);
-- then confirm none is left INVALID by a failed build
--   select indexrelid::regclass from pg_index where not indisvalid;
-- (drop an invalid one with DROP INDEX CONCURRENTLY and rebuild it) and run
-- the migration, which then finds the indexes and only records itself.
set local search_path = montra, extensions, public;

create index if not exists transactions_group_expense_idx on montra.transactions (group_expense_id)
  where group_expense_id is not null;
create index if not exists transactions_settlement_idx on montra.transactions (settlement_id)
  where settlement_id is not null;
create index if not exists budget_members_user_idx on montra.budget_members (user_id);
