-- Notifications, integrations, AI, insights, reports/exports, search
-- history and support requests.
set local search_path = montra, extensions, public;

create table notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  category    text not null check (category in ('budget','bill','subscription','recurring','goal','group','settlement',
                'trip','community','challenge','security','import','receipt','export','account','insight','system')),
  event_type  text not null check (char_length(event_type) between 1 and 80),
  title       text not null check (char_length(title) between 1 and 160),
  body        text not null check (char_length(body) <= 500),
  deep_link   text check (deep_link ~ '^/[A-Za-z0-9/_?=&.-]*$' and char_length(deep_link) <= 300),
  entity_type text,
  entity_id   uuid,
  group_id    uuid references groups(id) on delete cascade,
  priority    text not null default 'normal' check (priority in ('low','normal','high','critical')),
  dedupe_key  text check (char_length(dedupe_key) <= 200),
  read_at     timestamptz,
  archived_at timestamptz,
  expires_at  timestamptz,
  created_at  timestamptz not null default now()
);
create unique index notifications_dedupe_key on notifications (user_id, dedupe_key) where dedupe_key is not null;
create index notifications_unread_idx on notifications (user_id, created_at desc) where read_at is null and archived_at is null;
create index notifications_user_idx on notifications (user_id, created_at desc);
select apply_owner_rls('notifications');

create table notification_preferences (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  category   text not null,
  group_id   uuid references groups(id) on delete cascade,
  channel    text not null check (channel in ('in_app','email','web_push','push')),
  enabled    boolean not null,
  digest     text not null default 'immediate' check (digest in ('immediate','daily','weekly')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index notification_preferences_key on notification_preferences
  (user_id, category, coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid), channel);
select add_touch_trigger('notification_preferences');
select apply_owner_rls('notification_preferences');

create table notification_deliveries (
  id                  uuid primary key default gen_random_uuid(),
  notification_id     uuid not null references notifications(id) on delete cascade,
  user_id             uuid not null references users(id) on delete cascade,
  channel             text not null check (channel in ('email','web_push','push')),
  status              text not null default 'pending' check (status in ('pending','sent','failed','skipped','dead')),
  skip_reason         text,
  attempts            integer not null default 0,
  last_error_code     text,
  provider_message_id text,
  scheduled_for       timestamptz not null default now(),
  sent_at             timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create unique index notification_deliveries_key on notification_deliveries (notification_id, channel);
create index notification_deliveries_pending_idx on notification_deliveries (scheduled_for) where status = 'pending';
select add_touch_trigger('notification_deliveries');
select apply_owner_rls('notification_deliveries');

---------------------------------------------------------------------------
-- Integrations (framework only; no provider enabled — ADR-016)
---------------------------------------------------------------------------
create table integration_connections (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references users(id) on delete cascade,
  provider             text not null check (provider ~ '^[a-z0-9_]{2,40}$'),
  status               text not null default 'pending' check (status in ('pending','connected','disconnected',
                         'consent_expired','syncing','partial','failed','revoked')),
  consent_id           uuid references user_consents(id) on delete set null,
  consent_purpose      text check (char_length(consent_purpose) <= 300),
  consent_scope        text[] not null default '{}',
  consent_granted_at   timestamptz,
  consent_expires_at   timestamptz,
  consent_revoked_at   timestamptz,
  oauth_state_hash     bytea,
  external_ref         text check (char_length(external_ref) <= 200),
  token_ciphertext     bytea,
  token_key_id         text,
  token_expires_at     timestamptz,
  sync_cursor          text check (char_length(sync_cursor) <= 2000),
  last_sync_at         timestamptz,
  last_sync_status     text,
  last_error_code      text,
  linked_account_id    uuid references financial_accounts(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index integration_connections_user_idx on integration_connections (user_id, provider);
create unique index integration_connections_state_key on integration_connections (oauth_state_hash) where oauth_state_hash is not null;
select add_touch_trigger('integration_connections');
select apply_owner_rls('integration_connections');

create table integration_sync_runs (
  id            uuid primary key default gen_random_uuid(),
  connection_id uuid not null references integration_connections(id) on delete cascade,
  user_id       uuid not null references users(id) on delete cascade,
  status        text not null default 'queued' check (status in ('queued','running','succeeded','partial','failed')),
  trigger       text not null default 'manual' check (trigger in ('manual','scheduled','webhook','backfill')),
  started_at    timestamptz,
  finished_at   timestamptz,
  items_fetched integer not null default 0,
  items_created integer not null default 0,
  items_updated integer not null default 0,
  items_skipped integer not null default 0,
  error_code    text,
  cursor_before text,
  cursor_after  text,
  created_at    timestamptz not null default now()
);
create index integration_sync_runs_conn_idx on integration_sync_runs (connection_id, created_at desc);
select apply_owner_rls('integration_sync_runs');

-- Webhook inbox: verified + deduplicated before processing. Payloads are
-- stored encrypted; only the digest is used for dedupe/forensics.
create table integration_webhook_events (
  id                 uuid primary key default gen_random_uuid(),
  provider           text not null check (provider ~ '^[a-z0-9_]{2,40}$'),
  event_id           text not null check (char_length(event_id) between 1 and 200),
  event_type         text check (char_length(event_type) <= 120),
  signature_valid    boolean not null,
  signed_at          timestamptz,
  payload_sha256     text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  payload_ciphertext bytea,
  key_id             text,
  status             text not null default 'received' check (status in ('received','processed','ignored','quarantined','failed')),
  connection_id      uuid references integration_connections(id) on delete set null,
  error_code         text,
  received_at        timestamptz not null default now(),
  processed_at       timestamptz
);
create unique index integration_webhook_events_key on integration_webhook_events (provider, event_id);
create index integration_webhook_events_status_idx on integration_webhook_events (status, received_at);
select apply_worker_rls('integration_webhook_events');
create policy app_webhook_insert on integration_webhook_events for insert to montra_app with check (true);
revoke select, update, delete on integration_webhook_events from montra_app;

---------------------------------------------------------------------------
-- AI assistant, usage accounting, insights
---------------------------------------------------------------------------
create table ai_conversations (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  title      text check (char_length(title) <= 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index ai_conversations_user_idx on ai_conversations (user_id, updated_at desc);
select add_touch_trigger('ai_conversations');
select apply_owner_rls('ai_conversations');

create table ai_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references ai_conversations(id) on delete cascade,
  user_id         uuid not null references users(id) on delete cascade,
  role            text not null check (role in ('user','assistant')),
  content         text not null check (char_length(content) <= 8000),
  answer          jsonb,
  grounding       jsonb not null default '{}'::jsonb,
  source          text not null default 'model' check (source in ('model','deterministic','user')),
  provider        text,
  model           text,
  safety_flags    text[] not null default '{}',
  created_at      timestamptz not null default now()
);
create index ai_messages_conv_idx on ai_messages (conversation_id, created_at);
select apply_owner_rls('ai_messages');

create table ai_usage (
  id             bigint generated always as identity primary key,
  user_id        uuid references users(id) on delete set null,
  feature        text not null,
  provider       text not null,
  model          text not null,
  input_tokens   integer not null default 0,
  output_tokens  integer not null default 0,
  cost_micro_usd bigint not null default 0,
  latency_ms     integer not null default 0,
  outcome        text not null check (outcome in ('ok','fallback','rejected_output','provider_error','rate_limited','blocked')),
  created_at     timestamptz not null default now()
);
create index ai_usage_user_day_idx on ai_usage (user_id, created_at desc);
select apply_owner_rls('ai_usage');
select make_append_only('ai_usage');

create table insights (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  kind          text not null check (kind in ('anomaly','savings','summary','forecast','budget','subscription','recurring')),
  subtype       text not null check (char_length(subtype) between 1 and 60),
  title         text not null check (char_length(title) between 1 and 160),
  body          text not null check (char_length(body) <= 2000),
  severity      text not null default 'info' check (severity in ('info','notice','warning')),
  confidence    numeric(4,3) check (confidence between 0 and 1),
  evidence      jsonb not null default '{}'::jsonb,
  period_start  date,
  period_end    date,
  source        text not null default 'rules' check (source in ('rules','ai')),
  status        text not null default 'active' check (status in ('active','dismissed','snoozed','expected','resolved','muted')),
  snoozed_until timestamptz,
  fingerprint   text not null check (char_length(fingerprint) <= 128),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index insights_fingerprint_key on insights (user_id, fingerprint);
create index insights_user_active_idx on insights (user_id, created_at desc) where status = 'active';
select add_touch_trigger('insights');
select apply_owner_rls('insights');

create table insight_feedback (
  id         uuid primary key default gen_random_uuid(),
  insight_id uuid not null references insights(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  feedback   text not null check (feedback in ('helpful','not_helpful','incorrect','expected')),
  note       text check (char_length(note) <= 500),
  created_at timestamptz not null default now()
);
create index insight_feedback_idx on insight_feedback (insight_id);
select apply_owner_rls('insight_feedback');

-- Insight muting rules (e.g. "never flag this merchant").
create table insight_mutes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  subtype    text not null,
  scope_key  text not null default '*',
  created_at timestamptz not null default now()
);
create unique index insight_mutes_key on insight_mutes (user_id, subtype, scope_key);
select apply_owner_rls('insight_mutes');

---------------------------------------------------------------------------
-- Reports and exports
---------------------------------------------------------------------------
create table reports (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  group_id     uuid references groups(id) on delete cascade,
  report_type  text not null check (report_type in ('monthly_summary','yearly_summary','income','expense','cash_flow',
                 'category','merchant','account','budget','subscription','recurring','group_settlement','trip',
                 'household','goal','transactions','custom')),
  title        text not null check (char_length(title) between 1 and 160),
  filters      jsonb not null default '{}'::jsonb,
  format       text not null check (format in ('csv','xlsx','pdf','json')),
  timezone     text not null,
  currency     text references currencies(code),
  status       text not null default 'queued' check (status in ('queued','running','completed','failed','expired')),
  job_id       uuid references jobs(id) on delete set null,
  file_id      uuid references files(id) on delete set null,
  row_count    integer,
  error_code   text,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at   timestamptz
);
create index reports_user_idx on reports (user_id, requested_at desc);
select apply_worker_rls('reports');
create policy app_reports_select on reports for select to montra_app
  using (user_id = montra.current_user_id());
create policy app_reports_insert on reports for insert to montra_app
  with check (user_id = montra.current_user_id() and (group_id is null or montra.is_group_member(group_id)));
create policy app_reports_update on reports for update to montra_app
  using (user_id = montra.current_user_id()) with check (user_id = montra.current_user_id());

create table scheduled_reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  report_type text not null,
  title       text not null check (char_length(title) between 1 and 160),
  filters     jsonb not null default '{}'::jsonb,
  format      text not null check (format in ('csv','xlsx','pdf','json')),
  cadence     text not null check (cadence in ('weekly','monthly')),
  next_run_at timestamptz not null,
  enabled     boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index scheduled_reports_due_idx on scheduled_reports (next_run_at) where enabled;
select add_touch_trigger('scheduled_reports');
select apply_owner_rls('scheduled_reports');

alter table data_exports add constraint data_exports_file_fkey foreign key (file_id) references files(id) on delete set null;
alter table data_exports add constraint data_exports_job_fkey foreign key (job_id) references jobs(id) on delete set null;

---------------------------------------------------------------------------
-- Search history and support
---------------------------------------------------------------------------
create table search_history (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  query      text not null check (char_length(query) between 1 and 200),
  scope      text not null default 'all' check (scope in ('all','transactions','merchants','accounts','groups','posts','users','goals')),
  created_at timestamptz not null default now()
);
create index search_history_user_idx on search_history (user_id, created_at desc);
select apply_owner_rls('search_history');

create table support_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references users(id) on delete set null,
  kind          text not null check (kind in ('support','bug','security','privacy','feedback')),
  subject       text not null check (char_length(subject) between 3 and 160),
  body          text not null check (char_length(body) between 1 and 5000),
  contact_email text check (char_length(contact_email) <= 320),
  client_kind   text,
  app_version   text,
  status        text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index support_requests_status_idx on support_requests (status, created_at);
select add_touch_trigger('support_requests');
select apply_worker_rls('support_requests');
create policy app_support_insert on support_requests for insert to montra_app
  with check (user_id is not distinct from montra.current_user_id());
create policy app_support_select on support_requests for select to montra_app
  using (user_id = montra.current_user_id() or montra.current_platform_role() in ('admin','support'));
create policy app_support_update on support_requests for update to montra_app
  using (montra.current_platform_role() in ('admin','support')) with check (true);
revoke delete on support_requests from montra_app;
