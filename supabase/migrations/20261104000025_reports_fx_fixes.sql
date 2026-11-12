-- Reports fixes reported by the web client: owners delete their reports,
-- a report keeps the dates it was requested for, and scheduled reports are
-- edited with optimistic concurrency. Forward-only and safe to re-run.
set local search_path = montra, extensions, public;

---------------------------------------------------------------------------
-- Reports
---------------------------------------------------------------------------
-- DELETE /reports/{id}: only the owner removes a report (the stored file
-- goes through the files deletion job in the same transaction).
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'montra' and tablename = 'reports' and policyname = 'app_reports_delete') then
    create policy app_reports_delete on reports for delete to montra_app
      using (user_id = montra.current_user_id());
  end if;
end $$;

-- The window a report covers, resolved in the owner's calendar when it is
-- requested, so a named range such as last_month stays fixed for that
-- report (retries and late runs use the same dates). Null for reports of
-- current state (accounts, budgets, subscriptions, goals, recurring) and
-- for reports requested before this migration.
alter table reports add column if not exists window_from date;
alter table reports add column if not exists window_to date;
alter table reports drop constraint if exists reports_window_check;
alter table reports add constraint reports_window_check
  check ((window_from is null) = (window_to is null) and (window_to is null or window_to >= window_from));

-- The hourly reports.schedules run fails reports whose generation job
-- ended without a result; only unfinished reports are looked at.
create index if not exists reports_unfinished_job_idx on reports (job_id) where status in ('queued','running');

---------------------------------------------------------------------------
-- Scheduled reports
---------------------------------------------------------------------------
-- PATCH /reports/schedules/{id} sends the version it read; a concurrent
-- change answers VERSION_CONFLICT.
alter table scheduled_reports add column if not exists version integer not null default 1;
alter table scheduled_reports drop constraint if exists scheduled_reports_version_check;
alter table scheduled_reports add constraint scheduled_reports_version_check check (version >= 1);
