-- Operator job visibility (JOB-007): platform admins list jobs, see one
-- job's attempts and re-queue a failed or dead job. The API role cannot read
-- other people's jobs and the table policies are not widened. These narrow
-- SECURITY DEFINER helpers check the admin role themselves and return
-- operational columns only: never payloads, results, error messages, dedupe
-- or correlation keys, or the user a job acts for (only whether it has one).
-- Idempotent and forward-only.
set local search_path = montra, extensions, public;

create index if not exists jobs_created_idx on montra.jobs (created_at desc, id desc);

create or replace function montra.admin_jobs(p_id uuid, p_status text, p_type text, p_from timestamptz, p_to timestamptz,
  p_after_created timestamptz, p_after_id uuid, p_limit integer)
returns table (id uuid, type text, queue text, status text, priority smallint, attempts integer, max_attempts integer,
  last_error_code text, user_scoped boolean, cancel_requested boolean, run_after timestamptz, created_at timestamptz,
  updated_at timestamptz, started_at timestamptz, finished_at timestamptz)
language plpgsql stable security definer set search_path = montra, pg_temp as $$
#variable_conflict use_column
begin
  if montra.current_platform_role() is distinct from 'admin' then
    raise exception 'admin only' using errcode = '42501';
  end if;
  return query
    select j.id, j.type, j.queue, j.status, j.priority, j.attempts, j.max_attempts, j.last_error_code,
           j.user_id is not null, j.cancel_requested, j.run_after, j.created_at, j.updated_at, j.started_at, j.finished_at
    from montra.jobs j
    where (p_id is null or j.id = p_id)
      and (p_status is null or j.status = p_status)
      and (p_type is null or j.type = p_type)
      and (p_from is null or j.created_at >= p_from)
      and (p_to is null or j.created_at < p_to)
      and (p_after_created is null or (j.created_at, j.id) < (p_after_created, p_after_id))
    order by j.created_at desc, j.id desc
    limit greatest(1, least(coalesce(p_limit, 50), 201));
end
$$;
revoke all on function montra.admin_jobs(uuid, text, text, timestamptz, timestamptz, timestamptz, uuid, integer) from public;
grant execute on function montra.admin_jobs(uuid, text, text, timestamptz, timestamptz, timestamptz, uuid, integer) to montra_app;

create or replace function montra.admin_job_attempts(p_job uuid)
returns table (attempt integer, worker_id text, outcome text, error_code text, started_at timestamptz,
  finished_at timestamptz, duration_ms integer)
language plpgsql stable security definer set search_path = montra, pg_temp as $$
#variable_conflict use_column
begin
  if montra.current_platform_role() is distinct from 'admin' then
    raise exception 'admin only' using errcode = '42501';
  end if;
  return query
    select a.attempt, a.worker_id, a.outcome, a.error_code, a.started_at, a.finished_at, a.duration_ms
    from montra.job_attempts a where a.job_id = p_job
    order by a.attempt, a.id
    limit 200;
end
$$;
revoke all on function montra.admin_job_attempts(uuid) from public;
grant execute on function montra.admin_job_attempts(uuid) to montra_app;

-- Re-queues a failed or dead job exactly as jobs.Retry does (one more
-- attempt at least), under a row lock. Returns the status the job had, so
-- the caller can refuse other states; null when the job does not exist.
create or replace function montra.admin_job_retry(p_job uuid)
returns text
language plpgsql volatile security definer set search_path = montra, pg_temp as $$
declare
  prev text;
begin
  if montra.current_platform_role() is distinct from 'admin' then
    raise exception 'admin only' using errcode = '42501';
  end if;
  select j.status into prev from montra.jobs j where j.id = p_job for update;
  if not found then
    return null;
  end if;
  if prev in ('failed', 'dead') then
    update montra.jobs set status = 'queued', run_after = now(), locked_by = null, locked_until = null,
      max_attempts = least(50, greatest(max_attempts, attempts + 1)), cancel_requested = false, finished_at = null
    where id = p_job;
  end if;
  return prev;
end
$$;
revoke all on function montra.admin_job_retry(uuid) from public;
grant execute on function montra.admin_job_retry(uuid) to montra_app;
