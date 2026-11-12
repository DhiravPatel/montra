-- P10: webhook routing reference and digest bookkeeping.

-- The provider's connection reference from a verified webhook, so the
-- worker can route it without re-parsing the payload.
alter table integration_webhook_events add column if not exists external_ref text check (char_length(external_ref) <= 200);
create index if not exists integration_connections_ref_idx on integration_connections (provider, external_ref) where external_ref is not null;

-- Webhooks arrive without a signed-in user, and the API role may queue jobs
-- only for the current user. This helper queues exactly one job type for a
-- verified, still-waiting webhook event and nothing else.
create or replace function montra.enqueue_webhook_event(p_event_id uuid) returns void
language plpgsql security definer set search_path = montra, pg_temp as $$
begin
  if not exists (select 1 from montra.integration_webhook_events
                 where id = p_event_id and status = 'received' and signature_valid) then
    raise exception 'webhook event is not waiting' using errcode = 'P0002';
  end if;
  insert into montra.jobs (type, payload, priority, max_attempts, dedupe_key)
  values ('integrations.webhook', jsonb_build_object('event_id', p_event_id), 100, 8, 'webhook:' || p_event_id::text)
  on conflict (dedupe_key) where dedupe_key is not null do nothing;
end
$$;
revoke all on function montra.enqueue_webhook_event(uuid) from public;
grant execute on function montra.enqueue_webhook_event(uuid) to montra_app;
