-- Shared budgets: collaborators see aggregate progress computed by the
-- owner's context or the worker (they can never read the owner's
-- transactions). The current period is cached with its computation time;
-- closed periods double as rollover snapshots.
set local search_path = montra, extensions, public;

alter table budget_period_snapshots add column allocations_spent jsonb not null default '{}'::jsonb;
alter table budget_period_snapshots add column transaction_count bigint not null default 0;
alter table budget_period_snapshots add column other_currency_count bigint not null default 0;

create policy app_bps_update on budget_period_snapshots for update to montra_app
  using (montra.budget_access(budget_id) in ('owner','editor')) with check (montra.budget_access(budget_id) in ('owner','editor'));

-- Members may leave shared budgets and goals themselves.
create policy app_bm_leave on budget_members for delete to montra_app using (user_id = montra.current_user_id());
create policy app_gm_leave on goal_members for delete to montra_app using (user_id = montra.current_user_id());
