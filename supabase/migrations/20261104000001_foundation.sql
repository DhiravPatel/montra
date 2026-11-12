-- Montra foundation: schema, extensions, identity helpers, RLS helpers,
-- currency registry and operational tables (jobs, outbox, idempotency, audit).
-- Target: PostgreSQL 15+ (Supabase). Requires roles montra_app and
-- montra_worker to exist (scripts/db/bootstrap.sh locally,
-- infra/supabase/roles.sql on Supabase).

set local search_path = montra, extensions, public;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'montra_app')
     or not exists (select 1 from pg_roles where rolname = 'montra_worker') then
    raise exception 'roles montra_app and montra_worker must exist before migrating (see infra/supabase/roles.sql)';
  end if;
end $$;

create schema if not exists montra;
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

revoke all on schema montra from public;
grant usage on schema montra to montra_app, montra_worker;
grant usage on schema extensions to montra_app, montra_worker;

-- Runtime roles get DML on tables created by the migration role. Specific
-- tables revoke UPDATE/DELETE below to make them append-only.
alter default privileges in schema montra grant select, insert, update, delete on tables to montra_app, montra_worker;
alter default privileges in schema montra grant usage, select on sequences to montra_app, montra_worker;
-- PUBLIC has no USAGE on schema montra, so it cannot call montra functions.
-- SECURITY DEFINER functions additionally revoke PUBLIC execute explicitly.

-- schema_migrations is created by the runner; runtime roles have no access.
revoke all on table montra.schema_migrations from montra_app, montra_worker;

---------------------------------------------------------------------------
-- Identity helpers
---------------------------------------------------------------------------

-- The authenticated user for the current transaction (set by the backend via
-- set_config('montra.user_id', <uuid>, true)). NULL when unauthenticated.
create or replace function montra.current_user_id() returns uuid
language sql stable parallel safe as $$
  select nullif(current_setting('montra.user_id', true), '')::uuid
$$;
grant execute on function montra.current_user_id() to montra_app, montra_worker;

create or replace function montra.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Adds the updated_at trigger to a table.
create or replace function montra.add_touch_trigger(tbl regclass) returns void
language plpgsql as $$
begin
  execute format('create trigger touch_updated_at before update on %s for each row execute function montra.touch_updated_at()', tbl);
end $$;

-- Standard owner-scoped RLS: the API role sees and writes only rows whose
-- owner column equals the current user; the worker role has system scope
-- (worker code performs explicit authorization).
create or replace function montra.apply_owner_rls(tbl regclass, owner_col text default 'user_id') returns void
language plpgsql as $$
begin
  execute format('alter table %s enable row level security', tbl);
  execute format('create policy app_owner_all on %s for all to montra_app using (%I = montra.current_user_id()) with check (%I = montra.current_user_id())', tbl, owner_col, owner_col);
  execute format('create policy worker_all on %s for all to montra_worker using (true) with check (true)', tbl);
end $$;

-- Enables RLS with only the worker system policy; API access must be added
-- explicitly with table-specific policies.
create or replace function montra.apply_worker_rls(tbl regclass) returns void
language plpgsql as $$
begin
  execute format('alter table %s enable row level security', tbl);
  execute format('create policy worker_all on %s for all to montra_worker using (true) with check (true)', tbl);
end $$;

-- Makes a table append-only for the runtime roles.
create or replace function montra.make_append_only(tbl regclass, allow_worker_delete boolean default true) returns void
language plpgsql as $$
begin
  execute format('revoke update, delete on %s from montra_app', tbl);
  execute format('revoke update on %s from montra_worker', tbl);
  if not allow_worker_delete then
    execute format('revoke delete on %s from montra_worker', tbl);
  end if;
end $$;

---------------------------------------------------------------------------
-- Currency registry (ISO 4217). Must match backend/internal/domain/currency.
---------------------------------------------------------------------------

create table currencies (
  code      text primary key check (code ~ '^[A-Z]{3}$'),
  name      text not null,
  exponent  smallint not null check (exponent between 0 and 4),
  symbol    text,
  active    boolean not null default true
);

insert into currencies (code, name, exponent, symbol) values
 ('AED','UAE Dirham',2,null),('AFN','Afghani',2,null),('ALL','Lek',2,null),('AMD','Armenian Dram',2,null),
 ('AOA','Kwanza',2,null),('ARS','Argentine Peso',2,null),('AUD','Australian Dollar',2,'A$'),('AWG','Aruban Florin',2,null),
 ('AZN','Azerbaijan Manat',2,null),('BAM','Convertible Mark',2,null),('BBD','Barbados Dollar',2,null),('BDT','Taka',2,'৳'),
 ('BGN','Bulgarian Lev',2,null),('BHD','Bahraini Dinar',3,null),('BIF','Burundi Franc',0,null),('BMD','Bermudian Dollar',2,null),
 ('BND','Brunei Dollar',2,null),('BOB','Boliviano',2,null),('BRL','Brazilian Real',2,'R$'),('BSD','Bahamian Dollar',2,null),
 ('BTN','Ngultrum',2,null),('BWP','Pula',2,null),('BYN','Belarusian Ruble',2,null),('BZD','Belize Dollar',2,null),
 ('CAD','Canadian Dollar',2,'CA$'),('CDF','Congolese Franc',2,null),('CHF','Swiss Franc',2,null),('CLP','Chilean Peso',0,null),
 ('CNY','Yuan Renminbi',2,'¥'),('COP','Colombian Peso',2,null),('CRC','Costa Rican Colon',2,null),('CUP','Cuban Peso',2,null),
 ('CVE','Cabo Verde Escudo',2,null),('CZK','Czech Koruna',2,null),('DJF','Djibouti Franc',0,null),('DKK','Danish Krone',2,null),
 ('DOP','Dominican Peso',2,null),('DZD','Algerian Dinar',2,null),('EGP','Egyptian Pound',2,null),('ERN','Nakfa',2,null),
 ('ETB','Ethiopian Birr',2,null),('EUR','Euro',2,'€'),('FJD','Fiji Dollar',2,null),('FKP','Falkland Islands Pound',2,null),
 ('GBP','Pound Sterling',2,'£'),('GEL','Lari',2,null),('GHS','Ghana Cedi',2,null),('GIP','Gibraltar Pound',2,null),
 ('GMD','Dalasi',2,null),('GNF','Guinean Franc',0,null),('GTQ','Quetzal',2,null),('GYD','Guyana Dollar',2,null),
 ('HKD','Hong Kong Dollar',2,'HK$'),('HNL','Lempira',2,null),('HTG','Gourde',2,null),('HUF','Forint',2,null),
 ('IDR','Rupiah',2,null),('ILS','New Israeli Sheqel',2,'₪'),('INR','Indian Rupee',2,'₹'),('IQD','Iraqi Dinar',3,null),
 ('IRR','Iranian Rial',2,null),('ISK','Iceland Krona',0,null),('JMD','Jamaican Dollar',2,null),('JOD','Jordanian Dinar',3,null),
 ('JPY','Yen',0,'¥'),('KES','Kenyan Shilling',2,null),('KGS','Som',2,null),('KHR','Riel',2,null),
 ('KMF','Comorian Franc',0,null),('KPW','North Korean Won',2,null),('KRW','Won',0,'₩'),('KWD','Kuwaiti Dinar',3,null),
 ('KYD','Cayman Islands Dollar',2,null),('KZT','Tenge',2,null),('LAK','Lao Kip',2,null),('LBP','Lebanese Pound',2,null),
 ('LKR','Sri Lanka Rupee',2,null),('LRD','Liberian Dollar',2,null),('LSL','Loti',2,null),('LYD','Libyan Dinar',3,null),
 ('MAD','Moroccan Dirham',2,null),('MDL','Moldovan Leu',2,null),('MGA','Malagasy Ariary',2,null),('MKD','Denar',2,null),
 ('MMK','Kyat',2,null),('MNT','Tugrik',2,null),('MOP','Pataca',2,null),('MRU','Ouguiya',2,null),
 ('MUR','Mauritius Rupee',2,null),('MVR','Rufiyaa',2,null),('MWK','Malawi Kwacha',2,null),('MXN','Mexican Peso',2,'MX$'),
 ('MYR','Malaysian Ringgit',2,null),('MZN','Mozambique Metical',2,null),('NAD','Namibia Dollar',2,null),('NGN','Naira',2,'₦'),
 ('NIO','Cordoba Oro',2,null),('NOK','Norwegian Krone',2,null),('NPR','Nepalese Rupee',2,null),('NZD','New Zealand Dollar',2,'NZ$'),
 ('OMR','Rial Omani',3,null),('PAB','Balboa',2,null),('PEN','Sol',2,null),('PGK','Kina',2,null),
 ('PHP','Philippine Peso',2,'₱'),('PKR','Pakistan Rupee',2,null),('PLN','Zloty',2,null),('PYG','Guarani',0,null),
 ('QAR','Qatari Rial',2,null),('RON','Romanian Leu',2,null),('RSD','Serbian Dinar',2,null),('RUB','Russian Ruble',2,null),
 ('RWF','Rwanda Franc',0,null),('SAR','Saudi Riyal',2,null),('SBD','Solomon Islands Dollar',2,null),('SCR','Seychelles Rupee',2,null),
 ('SDG','Sudanese Pound',2,null),('SEK','Swedish Krona',2,null),('SGD','Singapore Dollar',2,'S$'),('SHP','Saint Helena Pound',2,null),
 ('SLE','Leone',2,null),('SOS','Somali Shilling',2,null),('SRD','Surinam Dollar',2,null),('SSP','South Sudanese Pound',2,null),
 ('STN','Dobra',2,null),('SYP','Syrian Pound',2,null),('SZL','Lilangeni',2,null),('THB','Baht',2,'฿'),
 ('TJS','Somoni',2,null),('TMT','Turkmenistan New Manat',2,null),('TND','Tunisian Dinar',3,null),('TOP','Pa''anga',2,null),
 ('TRY','Turkish Lira',2,null),('TTD','Trinidad and Tobago Dollar',2,null),('TWD','New Taiwan Dollar',2,'NT$'),('TZS','Tanzanian Shilling',2,null),
 ('UAH','Hryvnia',2,null),('UGX','Uganda Shilling',0,null),('USD','US Dollar',2,'$'),('UYU','Peso Uruguayo',2,null),
 ('UZS','Uzbekistan Sum',2,null),('VES','Bolivar Soberano',2,null),('VND','Dong',0,'₫'),('VUV','Vatu',0,null),
 ('WST','Tala',2,null),('XAF','CFA Franc BEAC',0,null),('XCD','East Caribbean Dollar',2,null),('XCG','Caribbean Guilder',2,null),
 ('XOF','CFA Franc BCEAO',0,null),('XPF','CFP Franc',0,null),('YER','Yemeni Rial',2,null),('ZAR','Rand',2,'R'),
 ('ZMW','Zambian Kwacha',2,null),('ZWG','Zimbabwe Gold',2,null);

alter table currencies enable row level security;
create policy currencies_read on currencies for select to montra_app, montra_worker using (true);
revoke insert, update, delete on currencies from montra_app, montra_worker;

---------------------------------------------------------------------------
-- Durable jobs (ADR-008)
---------------------------------------------------------------------------

create table jobs (
  id             uuid primary key default gen_random_uuid(),
  type           text not null check (char_length(type) between 1 and 80),
  queue          text not null default 'default',
  user_id        uuid,
  payload        jsonb not null default '{}'::jsonb,
  status         text not null default 'queued'
                 check (status in ('queued','running','succeeded','failed','dead','cancelled')),
  priority       smallint not null default 100,
  attempts       integer not null default 0 check (attempts >= 0),
  max_attempts   integer not null default 8 check (max_attempts between 1 and 50),
  run_after      timestamptz not null default now(),
  locked_by      text,
  locked_until   timestamptz,
  dedupe_key     text,
  correlation_id text,
  progress       jsonb not null default '{}'::jsonb,
  result         jsonb,
  last_error_code text,
  last_error     text,
  cancel_requested boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  started_at     timestamptz,
  finished_at    timestamptz
);
create unique index jobs_dedupe_key_key on jobs (dedupe_key) where dedupe_key is not null;
create index jobs_ready_idx on jobs (queue, priority, run_after) where status = 'queued';
create index jobs_running_lease_idx on jobs (locked_until) where status = 'running';
create index jobs_user_idx on jobs (user_id, created_at desc) where user_id is not null;
create index jobs_status_type_idx on jobs (status, type);
select add_touch_trigger('jobs');
select apply_worker_rls('jobs');
create policy app_jobs_select on jobs for select to montra_app using (user_id = montra.current_user_id());
create policy app_jobs_insert on jobs for insert to montra_app with check (user_id = montra.current_user_id());
create policy app_jobs_cancel on jobs for update to montra_app using (user_id = montra.current_user_id()) with check (user_id = montra.current_user_id());

create table job_attempts (
  id          bigint generated always as identity primary key,
  job_id      uuid not null references jobs(id) on delete cascade,
  attempt     integer not null,
  worker_id   text not null,
  started_at  timestamptz not null default now(),
  finished_at timestamptz,
  outcome     text check (outcome in ('succeeded','retry','failed','dead','cancelled','lease_expired')),
  error_code  text,
  error       text,
  duration_ms integer
);
create index job_attempts_job_idx on job_attempts (job_id, attempt);
select apply_worker_rls('job_attempts');

-- Transactional outbox: domain writes insert events in the same transaction;
-- the worker relays them to jobs/notifications.
create table outbox_events (
  id           bigint generated always as identity primary key,
  event_type   text not null,
  aggregate_type text not null,
  aggregate_id uuid,
  user_id      uuid,
  group_id     uuid,
  payload      jsonb not null default '{}'::jsonb,
  request_id   text,
  created_at   timestamptz not null default now(),
  processed_at timestamptz,
  attempts     integer not null default 0,
  last_error   text
);
create index outbox_unprocessed_idx on outbox_events (id) where processed_at is null;
select apply_worker_rls('outbox_events');
create policy app_outbox_insert on outbox_events for insert to montra_app with check (true);
revoke select, update, delete on outbox_events from montra_app;

---------------------------------------------------------------------------
-- Idempotency keys (spec §6): one stored response per (user, key).
---------------------------------------------------------------------------

create table idempotency_keys (
  user_id        uuid not null,
  key            text not null check (char_length(key) between 8 and 128),
  operation      text not null,
  request_hash   text not null,
  status         text not null default 'in_progress' check (status in ('in_progress','completed')),
  response_status integer,
  response_body  jsonb,
  resource_id    uuid,
  created_at     timestamptz not null default now(),
  completed_at   timestamptz,
  expires_at     timestamptz not null default now() + interval '24 hours',
  primary key (user_id, key)
);
create index idempotency_expires_idx on idempotency_keys (expires_at);
select apply_owner_rls('idempotency_keys');

---------------------------------------------------------------------------
-- Audit and security events (append-only)
---------------------------------------------------------------------------

create table audit_events (
  id            bigint generated always as identity primary key,
  user_id       uuid,          -- owner/subject whose data was affected
  group_id      uuid,
  actor_user_id uuid,          -- who performed the action (null = system)
  actor_kind    text not null default 'user' check (actor_kind in ('user','system','support','admin','moderator')),
  entity_type   text not null,
  entity_id     uuid,
  action        text not null,
  changes       jsonb not null default '{}'::jsonb,
  request_id    text,
  created_at    timestamptz not null default now()
);
create index audit_user_idx on audit_events (user_id, created_at desc);
create index audit_entity_idx on audit_events (entity_type, entity_id, created_at desc);
create index audit_group_idx on audit_events (group_id, created_at desc) where group_id is not null;
select apply_worker_rls('audit_events');
create policy app_audit_insert on audit_events for insert to montra_app
  with check (actor_user_id is not distinct from montra.current_user_id());
create policy app_audit_select on audit_events for select to montra_app using (user_id = montra.current_user_id());
select make_append_only('audit_events');

create table security_events (
  id          bigint generated always as identity primary key,
  user_id     uuid,
  event_type  text not null,
  severity    text not null default 'info' check (severity in ('info','warning','critical')),
  ip_hash     text,
  user_agent  text,
  client_kind text,
  session_id  uuid,
  details     jsonb not null default '{}'::jsonb,
  request_id  text,
  created_at  timestamptz not null default now()
);
create index security_events_user_idx on security_events (user_id, created_at desc);
create index security_events_type_idx on security_events (event_type, created_at desc);
select apply_worker_rls('security_events');
create policy app_security_insert on security_events for insert to montra_app with check (true);
create policy app_security_select on security_events for select to montra_app using (user_id = montra.current_user_id());
select make_append_only('security_events');

comment on schema montra is 'Montra application schema. All tables have RLS enabled; see docs/RLS_POLICY_MATRIX.md.';
