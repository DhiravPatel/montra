-- Record how a goal became achieved: 'progress' (saved reached the target;
-- a later withdrawal below target reopens it automatically) or 'manual'
-- (the person marked it achieved; it stays achieved, withdrawals are still
-- accepted). Existing achieved goals keep the automatic behaviour.
-- Idempotent and forward-only.
set local search_path = montra, extensions, public;

alter table montra.goals add column if not exists achieved_by text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'goals_achieved_by_check') then
    alter table montra.goals add constraint goals_achieved_by_check
      check (achieved_by is null or achieved_by in ('progress','manual'));
  end if;
end $$;
update montra.goals set achieved_by = 'progress' where status = 'achieved' and achieved_by is null;
