-- Operator cost dashboard (spec §17): aggregate counts only, never rows or
-- per-user values, and only for platform admins. The API role cannot read
-- other users' rows, so the aggregation runs as a narrow definer function.
create or replace function montra.admin_usage(p_days integer) returns jsonb
language plpgsql stable security definer set search_path = montra, pg_temp as $$
declare
  since timestamptz := now() - make_interval(days => greatest(1, least(p_days, 365)));
begin
  if montra.current_platform_role() is distinct from 'admin' then
    raise exception 'admin only' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'window_days', greatest(1, least(p_days, 365)),
    'users', jsonb_build_object(
      'active', (select count(*) from users where status = 'active'),
      'new', (select count(*) from users where created_at >= since),
      'pending_deletion', (select count(*) from users where status = 'pending_deletion')),
    'storage', (select jsonb_build_object('bytes', coalesce(sum(size_bytes), 0), 'files', count(*))
                from files where status in ('uploaded','processing','ready')),
    'storage_by_area', (select coalesce(jsonb_object_agg(storage_area, b), '{}'::jsonb)
                        from (select storage_area, coalesce(sum(size_bytes), 0) b from files
                              where status in ('uploaded','processing','ready') group by 1) x),
    'notifications', (select coalesce(jsonb_object_agg(channel || ':' || status, n), '{}'::jsonb)
                      from (select channel, status, count(*) n from notification_deliveries where created_at >= since group by 1, 2) x),
    'jobs', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb)
             from (select status, count(*) n from jobs where created_at >= since group by 1) x),
    'dead_jobs_by_type', (select coalesce(jsonb_object_agg(type, n), '{}'::jsonb)
                          from (select type, count(*) n from jobs where status = 'dead' and created_at >= since group by 1) x),
    'ai', (select jsonb_build_object('requests', count(*), 'cost_micro_usd', coalesce(sum(cost_micro_usd), 0))
           from ai_usage where created_at >= since),
    'imports', (select count(*) from import_batches where created_at >= since),
    'reports', (select count(*) from reports where requested_at >= since),
    'transactions_created', (select count(*) from transactions where created_at >= since),
    'support_open', (select count(*) from support_requests where status in ('open','in_progress')),
    'daily', (select coalesce(jsonb_agg(jsonb_build_object('date', d::date,
                 'new_users', (select count(*) from users u where u.created_at >= d and u.created_at < d + interval '1 day'),
                 'transactions', (select count(*) from transactions t where t.created_at >= d and t.created_at < d + interval '1 day'),
                 'emails_sent', (select count(*) from notification_deliveries nd where nd.channel = 'email' and nd.status = 'sent'
                                   and nd.created_at >= d and nd.created_at < d + interval '1 day'))
               order by d), '[]'::jsonb)
              from generate_series(date_trunc('day', since), date_trunc('day', now()), interval '1 day') d)
  );
end
$$;
revoke all on function montra.admin_usage(integer) from public;
grant execute on function montra.admin_usage(integer) to montra_app;
