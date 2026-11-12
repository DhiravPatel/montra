-- Identity, sessions, profiles, preferences, consents and account lifecycle.
set local search_path = montra, extensions, public;

create table users (
  id                uuid primary key default gen_random_uuid(),
  email             text not null check (char_length(email) between 3 and 320),
  email_normalized  text not null check (email_normalized = lower(email_normalized)),
  email_verified_at timestamptz,
  status            text not null default 'active'
                    check (status in ('active','locked','deactivated','pending_deletion','deleted')),
  platform_role     text not null default 'user' check (platform_role in ('user','support','admin')),
  date_of_birth_confirmed_adult boolean not null default false,
  last_login_at     timestamptz,
  locked_until      timestamptz,
  deactivated_at    timestamptz,
  deleted_at        timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create unique index users_email_normalized_key on users (email_normalized);
select add_touch_trigger('users');
alter table users enable row level security;
create policy app_users_self on users for select to montra_app using (id = montra.current_user_id());
create policy app_users_insert_self on users for insert to montra_app with check (id = montra.current_user_id());
create policy app_users_update_self on users for update to montra_app using (id = montra.current_user_id()) with check (id = montra.current_user_id());
create policy worker_all on users for all to montra_worker using (true) with check (true);
revoke delete on users from montra_app;

create table user_credentials (
  user_id             uuid primary key references users(id) on delete cascade,
  password_hash       text not null,
  password_changed_at timestamptz not null default now(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
select add_touch_trigger('user_credentials');
select apply_owner_rls('user_credentials');

create table user_sessions (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  access_token_hash   bytea not null,
  access_expires_at   timestamptz not null,
  refresh_token_hash  bytea not null,
  refresh_expires_at  timestamptz not null,
  absolute_expires_at timestamptz not null,
  client_kind         text not null default 'unknown' check (client_kind in ('web','android','ios','unknown')),
  device_name         text check (char_length(device_name) <= 120),
  user_agent          text check (char_length(user_agent) <= 256),
  ip_hash             text,
  mfa_verified        boolean not null default false,
  last_reauth_at      timestamptz,
  last_seen_at        timestamptz not null default now(),
  revoked_at          timestamptz,
  revoked_reason      text check (revoked_reason in ('logout','logout_all','user_revoked','password_changed','refresh_reuse','account_deleted','admin','expired','mfa_changed')),
  created_at          timestamptz not null default now()
);
create unique index user_sessions_access_hash_key on user_sessions (access_token_hash);
create unique index user_sessions_refresh_hash_key on user_sessions (refresh_token_hash);
create index user_sessions_user_idx on user_sessions (user_id, created_at desc);
create index user_sessions_active_idx on user_sessions (user_id) where revoked_at is null;
select apply_owner_rls('user_sessions');

-- Superseded refresh tokens, retained to detect reuse (token theft).
create table user_session_refresh_history (
  token_hash  bytea primary key,
  session_id  uuid not null references user_sessions(id) on delete cascade,
  user_id     uuid not null references users(id) on delete cascade,
  rotated_at  timestamptz not null default now()
);
create index refresh_history_session_idx on user_session_refresh_history (session_id);
select apply_owner_rls('user_session_refresh_history');

create table auth_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  purpose     text not null check (purpose in ('email_verification','password_reset','email_change','mfa_challenge')),
  token_hash  bytea not null,
  payload     jsonb not null default '{}'::jsonb,
  expires_at  timestamptz not null,
  consumed_at timestamptz,
  attempts    integer not null default 0,
  created_at  timestamptz not null default now()
);
create unique index auth_tokens_hash_key on auth_tokens (token_hash);
create index auth_tokens_user_purpose_idx on auth_tokens (user_id, purpose, created_at desc);
select apply_owner_rls('auth_tokens');

create table mfa_factors (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references users(id) on delete cascade,
  kind              text not null default 'totp' check (kind = 'totp'),
  secret_ciphertext bytea not null,
  key_id            text not null,
  status            text not null default 'pending' check (status in ('pending','active','disabled')),
  last_used_step    bigint,
  created_at        timestamptz not null default now(),
  activated_at      timestamptz,
  disabled_at       timestamptz
);
create unique index mfa_factors_one_active on mfa_factors (user_id) where status = 'active';
select apply_owner_rls('mfa_factors');

create table mfa_recovery_codes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  code_hash  bytea not null,
  used_at    timestamptz,
  created_at timestamptz not null default now()
);
create unique index mfa_recovery_codes_hash_key on mfa_recovery_codes (user_id, code_hash);
select apply_owner_rls('mfa_recovery_codes');

-- Login throttling (hashes only, no addresses or emails in clear).
create table login_attempts (
  id           bigint generated always as identity primary key,
  email_hash   bytea not null,
  ip_hash      text,
  succeeded    boolean not null,
  attempted_at timestamptz not null default now()
);
create index login_attempts_email_idx on login_attempts (email_hash, attempted_at desc);
create index login_attempts_ip_idx on login_attempts (ip_hash, attempted_at desc);
select apply_worker_rls('login_attempts');
create policy app_login_attempts on login_attempts for all to montra_app using (true) with check (true);
revoke update on login_attempts from montra_app;

create table profiles (
  user_id                  uuid primary key references users(id) on delete cascade,
  display_name             text not null check (char_length(display_name) between 1 and 80),
  username                 text check (username ~ '^[a-z0-9_.]{3,30}$'),
  avatar_file_id           uuid,
  bio                      text check (char_length(bio) <= 280),
  interests                text[] not null default '{}' check (cardinality(interests) <= 10),
  coarse_location          text check (char_length(coarse_location) <= 80),
  profile_visibility       text not null default 'connections' check (profile_visibility in ('private','connections','public')),
  discoverable_by_username boolean not null default true,
  show_achievements        boolean not null default false,
  allow_friend_requests    text not null default 'everyone' check (allow_friend_requests in ('everyone','friends_of_friends','nobody')),
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
create unique index profiles_username_key on profiles (username) where username is not null;
create index profiles_username_trgm on profiles using gin (username gin_trgm_ops);
create index profiles_display_name_trgm on profiles using gin (display_name gin_trgm_ops);
select add_touch_trigger('profiles');
select apply_owner_rls('profiles');
-- Additional read policy for other users' profiles is added in the social
-- migration (needs connection/group helpers).

create table user_preferences (
  user_id                 uuid primary key references users(id) on delete cascade,
  locale                  text not null default 'en-IN' check (locale ~ '^[a-z]{2,3}(-[A-Z]{2})?$'),
  timezone                text not null default 'Asia/Kolkata' check (char_length(timezone) between 1 and 64),
  base_currency           text not null default 'INR' references currencies(code),
  display_currency        text references currencies(code),
  country                 text check (country ~ '^[A-Z]{2}$'),
  date_format             text not null default 'locale' check (date_format in ('locale','dmy','mdy','ymd')),
  number_format           text not null default 'locale' check (number_format in ('locale','indian','international')),
  week_start              smallint not null default 1 check (week_start between 0 and 6),
  month_start_day         smallint not null default 1 check (month_start_day between 1 and 28),
  theme                   text not null default 'system' check (theme in ('system','light','dark')),
  reduced_motion          boolean not null default false,
  high_contrast           boolean not null default false,
  text_scale_percent      smallint not null default 100 check (text_scale_percent between 80 and 200),
  default_date_range      text not null default 'this_month' check (default_date_range in ('today','yesterday','this_week','this_month','this_year','last_7_days','last_30_days','last_90_days')),
  default_account_id      uuid,
  income_range            text check (income_range in ('prefer_not_to_say','under_25k','25k_50k','50k_1l','1l_2l','2l_5l','above_5l')),
  quiet_hours_enabled     boolean not null default false,
  quiet_hours_start       time not null default '22:00',
  quiet_hours_end         time not null default '07:00',
  email_digest            text not null default 'off' check (email_digest in ('off','daily','weekly')),
  ai_enabled              boolean not null default false,
  ai_history_enabled      boolean not null default true,
  analytics_opt_in        boolean not null default false,
  onboarding_completed_at timestamptz,
  onboarding_state        jsonb not null default '{}'::jsonb,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);
select add_touch_trigger('user_preferences');
select apply_owner_rls('user_preferences');

create table dashboard_widgets (
  user_id    uuid not null references users(id) on delete cascade,
  widget_key text not null check (widget_key ~ '^[a-z_]{2,40}$'),
  position   smallint not null check (position between 0 and 100),
  visible    boolean not null default true,
  settings   jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, widget_key)
);
select apply_owner_rls('dashboard_widgets');

create table user_consents (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  consent_type text not null check (consent_type in ('terms','privacy_policy','ai_processing','ai_receipt_processing',
                 'marketing_email','product_analytics','location','contacts_discovery','push_notifications','integration')),
  version      text not null check (char_length(version) between 1 and 40),
  scope        text,
  granted_at   timestamptz not null default now(),
  revoked_at   timestamptz,
  client_kind  text,
  metadata     jsonb not null default '{}'::jsonb
);
create index user_consents_user_type_idx on user_consents (user_id, consent_type, granted_at desc);
create unique index user_consents_one_active on user_consents (user_id, consent_type, coalesce(scope, '')) where revoked_at is null;
select apply_owner_rls('user_consents');
revoke delete on user_consents from montra_app;

create table data_exports (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  status       text not null default 'queued' check (status in ('queued','running','completed','failed','expired')),
  format       text not null default 'json_zip' check (format in ('json_zip')),
  file_id      uuid,
  job_id       uuid,
  error_code   text,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at   timestamptz
);
create index data_exports_user_idx on data_exports (user_id, requested_at desc);
select apply_owner_rls('data_exports');

create table account_deletion_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  status        text not null default 'scheduled' check (status in ('scheduled','cancelled','processing','completed','failed')),
  reason        text check (char_length(reason) <= 1000),
  requested_at  timestamptz not null default now(),
  scheduled_for timestamptz not null,
  started_at    timestamptz,
  completed_at  timestamptz,
  cancelled_at  timestamptz,
  steps         jsonb not null default '{}'::jsonb,
  exceptions    jsonb not null default '[]'::jsonb,
  error_code    text,
  updated_at    timestamptz not null default now()
);
create unique index deletion_one_open on account_deletion_requests (user_id) where status in ('scheduled','processing');
create index deletion_due_idx on account_deletion_requests (scheduled_for) where status = 'scheduled';
select add_touch_trigger('account_deletion_requests');
select apply_owner_rls('account_deletion_requests');

-- Push endpoints (web push subscriptions, FCM tokens). The subscription is
-- encrypted at rest; endpoint_hash enforces uniqueness.
create table push_endpoints (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references users(id) on delete cascade,
  kind                    text not null check (kind in ('webpush','fcm')),
  endpoint_hash           bytea not null,
  subscription_ciphertext bytea not null,
  key_id                  text not null,
  device_label            text check (char_length(device_label) <= 120),
  failure_count           integer not null default 0,
  last_used_at            timestamptz,
  disabled_at             timestamptz,
  created_at              timestamptz not null default now()
);
create unique index push_endpoints_hash_key on push_endpoints (endpoint_hash);
create index push_endpoints_user_idx on push_endpoints (user_id) where disabled_at is null;
select apply_owner_rls('push_endpoints');

---------------------------------------------------------------------------
-- Pre-authentication lookups (SECURITY DEFINER). These are the only paths
-- through which the API role can read identity rows without an
-- authenticated identity. Each returns the minimum fields required.
---------------------------------------------------------------------------

create or replace function montra.auth_lookup_user(p_email_normalized text)
returns table (user_id uuid, status text, email_verified_at timestamptz, locked_until timestamptz,
               password_hash text, mfa_enabled boolean)
language sql stable security definer set search_path = montra, pg_temp as $$
  select u.id, u.status, u.email_verified_at, u.locked_until, c.password_hash,
         exists (select 1 from montra.mfa_factors f where f.user_id = u.id and f.status = 'active')
  from montra.users u
  left join montra.user_credentials c on c.user_id = u.id
  where u.email_normalized = p_email_normalized
$$;

create or replace function montra.auth_resolve_access(p_hash bytea)
returns table (session_id uuid, user_id uuid, access_expires_at timestamptz, revoked_at timestamptz,
               mfa_verified boolean, last_reauth_at timestamptz, client_kind text,
               user_status text, platform_role text, email_verified boolean)
language sql stable security definer set search_path = montra, pg_temp as $$
  select s.id, s.user_id, s.access_expires_at, s.revoked_at, s.mfa_verified, s.last_reauth_at, s.client_kind,
         u.status, u.platform_role, u.email_verified_at is not null
  from montra.user_sessions s join montra.users u on u.id = s.user_id
  where s.access_token_hash = p_hash
$$;

create or replace function montra.auth_resolve_refresh(p_hash bytea)
returns table (session_id uuid, user_id uuid, refresh_expires_at timestamptz, absolute_expires_at timestamptz,
               revoked_at timestamptz, user_status text, reused boolean)
language sql stable security definer set search_path = montra, pg_temp as $$
  select s.id, s.user_id, s.refresh_expires_at, s.absolute_expires_at, s.revoked_at, u.status, false
  from montra.user_sessions s join montra.users u on u.id = s.user_id
  where s.refresh_token_hash = p_hash
  union all
  select s.id, s.user_id, s.refresh_expires_at, s.absolute_expires_at, s.revoked_at, u.status, true
  from montra.user_session_refresh_history h
  join montra.user_sessions s on s.id = h.session_id
  join montra.users u on u.id = s.user_id
  where h.token_hash = p_hash
$$;

create or replace function montra.auth_lookup_token(p_hash bytea, p_purpose text)
returns table (token_id uuid, user_id uuid, expires_at timestamptz, consumed_at timestamptz, attempts integer, payload jsonb)
language sql stable security definer set search_path = montra, pg_temp as $$
  select t.id, t.user_id, t.expires_at, t.consumed_at, t.attempts, t.payload
  from montra.auth_tokens t where t.token_hash = p_hash and t.purpose = p_purpose
$$;

revoke all on function montra.auth_lookup_user(text) from public;
revoke all on function montra.auth_resolve_access(bytea) from public;
revoke all on function montra.auth_resolve_refresh(bytea) from public;
revoke all on function montra.auth_lookup_token(bytea, text) from public;
grant execute on function montra.auth_lookup_user(text) to montra_app;
grant execute on function montra.auth_resolve_access(bytea) to montra_app;
grant execute on function montra.auth_resolve_refresh(bytea) to montra_app;
grant execute on function montra.auth_lookup_token(bytea, text) to montra_app;

-- Platform role of the current user (for staff-only policies).
create or replace function montra.current_platform_role() returns text
language sql stable security definer set search_path = montra, pg_temp as $$
  select coalesce((select platform_role from montra.users where id = montra.current_user_id()), 'user')
$$;
revoke all on function montra.current_platform_role() from public;
grant execute on function montra.current_platform_role() to montra_app, montra_worker;
