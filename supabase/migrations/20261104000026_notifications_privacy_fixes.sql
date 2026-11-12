-- Notifications, insights, search, support and privacy fixes reported by the
-- web client. Forward-only, additive (the previous API version keeps
-- working) and safe to re-run.
set local search_path = montra, extensions, public;

---------------------------------------------------------------------------
-- Push endpoints end with the session that registered them
---------------------------------------------------------------------------
-- A browser or device receives pushes only while the session that
-- registered it is signed in: sign-out, sign-out everywhere, a revoked
-- session (and any other session end: password change, refresh-token
-- reuse, account deletion) removes its endpoints, so a shared browser
-- stops receiving the previous person's notifications.
alter table push_endpoints add column if not exists session_id uuid;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'push_endpoints_session_fkey') then
    alter table push_endpoints add constraint push_endpoints_session_fkey
      foreign key (session_id) references user_sessions(id) on delete cascade;
  end if;
end $$;
create index if not exists push_endpoints_session_idx on push_endpoints (session_id) where session_id is not null;

-- Endpoints without a session were registered before sessions were recorded
-- (or by a previous API version during a rollback) and cannot be attributed
-- to one device: privacy first, the user's next session end removes them
-- too, and the still signed-in browsers and devices register again.
create or replace function montra.end_session_push_endpoints() returns trigger
language plpgsql security definer set search_path = montra, pg_temp as $$
begin
  delete from montra.push_endpoints where session_id = new.id;
  delete from montra.push_endpoints where user_id = new.user_id and session_id is null;
  return null;
end $$;
revoke all on function montra.end_session_push_endpoints() from public;
drop trigger if exists end_session_push_endpoints on user_sessions;
create trigger end_session_push_endpoints after update of revoked_at on user_sessions
  for each row when (old.revoked_at is null and new.revoked_at is not null)
  execute function montra.end_session_push_endpoints();

---------------------------------------------------------------------------
-- Insights: localization codes and one feedback per person
---------------------------------------------------------------------------
-- message_code + message_params localize title and body; rule_code the
-- evidence rule. Insights created before this migration have none (clients
-- fall back to the English text; the API derives rule_code from subtype).
alter table insights add column if not exists message_code text check (message_code ~ '^[a-z0-9_]{1,60}$');
alter table insights add column if not exists message_params jsonb not null default '{}'::jsonb;
alter table insights add column if not exists rule_code text check (rule_code ~ '^[a-z0-9_]{1,80}$');

-- Repeated feedback updates the person's earlier answer instead of adding
-- rows: keep the newest answer per (insight, person), then enforce it.
alter table insight_feedback add column if not exists updated_at timestamptz;
delete from insight_feedback f using insight_feedback newer
  where newer.insight_id = f.insight_id and newer.user_id = f.user_id
    and (newer.created_at, newer.id) > (f.created_at, f.id);
create unique index if not exists insight_feedback_one_per_user on insight_feedback (insight_id, user_id);

---------------------------------------------------------------------------
-- Search: new sections can be remembered in recent searches
---------------------------------------------------------------------------
alter table search_history drop constraint if exists search_history_scope_check;
alter table search_history add constraint search_history_scope_check check (scope in ('all','transactions','merchants','accounts',
  'groups','posts','users','goals','categories','bills','subscriptions','recurring_rules','budgets'));

---------------------------------------------------------------------------
-- Support: a message thread per request
---------------------------------------------------------------------------
-- The requester and Montra support staff read and post; message text is
-- never copied into notifications, emails or audit events.
create table if not exists support_messages (
  id             uuid primary key default gen_random_uuid(),
  request_id     uuid not null references support_requests(id) on delete cascade,
  author_user_id uuid references users(id) on delete set null,
  author_role    text not null check (author_role in ('requester','staff')),
  body           text not null check (char_length(body) between 1 and 5000),
  created_at     timestamptz not null default now()
);
create index if not exists support_messages_request_idx on support_messages (request_id, created_at, id);
create index if not exists support_messages_author_idx on support_messages (author_user_id, created_at desc);
alter table support_messages enable row level security;
revoke update, delete on support_messages from montra_app;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'montra' and tablename = 'support_messages' and policyname = 'worker_all') then
    create policy worker_all on support_messages for all to montra_worker using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'montra' and tablename = 'support_messages' and policyname = 'app_support_messages_select') then
    create policy app_support_messages_select on support_messages for select to montra_app
      using (exists (select 1 from support_requests r where r.id = request_id
        and (r.user_id = montra.current_user_id() or montra.current_platform_role() in ('admin','support'))));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'montra' and tablename = 'support_messages' and policyname = 'app_support_messages_insert') then
    create policy app_support_messages_insert on support_messages for insert to montra_app
      with check (author_user_id = montra.current_user_id() and exists (select 1 from support_requests r where r.id = request_id
        and ((author_role = 'requester' and r.user_id = montra.current_user_id())
          or (author_role = 'staff' and montra.current_platform_role() in ('admin','support')))));
  end if;
end $$;

-- The signed-out contact form has a daily cap per contact address. The API
-- role cannot read anonymous requests, so this returns only how many were
-- sent from the address since p_since (at most p_cap) and the oldest of
-- them (when the next one is allowed).
create or replace function montra.support_contact_window(p_email text, p_since timestamptz, p_cap integer)
returns table (recent integer, oldest timestamptz)
language sql stable security definer set search_path = montra, pg_temp as $$
  with r as (
    select created_at from montra.support_requests
    where user_id is null and contact_email = lower(p_email) and created_at > p_since
    order by created_at desc limit greatest(p_cap, 1))
  select count(*)::integer, min(created_at) from r
$$;
revoke all on function montra.support_contact_window(text, timestamptz, integer) from public;
grant execute on function montra.support_contact_window(text, timestamptz, integer) to montra_app, montra_worker;
create index if not exists support_requests_contact_idx on support_requests (contact_email, created_at desc) where user_id is null;
