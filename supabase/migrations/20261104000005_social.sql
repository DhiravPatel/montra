-- Social finance: groups (households, trips, events), shared expenses,
-- settlements, friends, blocks, communities, challenges and moderation.
-- Users are never hard-deleted while referenced here (ADR-022): deletion
-- anonymizes the users row, so these FKs use ON DELETE RESTRICT/SET NULL.
set local search_path = montra, extensions, public;

create table groups (
  id                    uuid primary key default gen_random_uuid(),
  created_by            uuid references users(id) on delete set null,
  name                  text not null check (char_length(name) between 1 and 80),
  group_type            text not null check (group_type in ('household','roommates','trip','event','friends','custom')),
  description           text check (char_length(description) <= 1000),
  base_currency         text not null references currencies(code),
  timezone              text not null check (char_length(timezone) between 1 and 64),
  default_split_method  text not null default 'equal' check (default_split_method in ('equal','exact','percentage','shares','itemized')),
  simplify_debts        boolean not null default true,
  allow_member_invites  boolean not null default true,
  require_join_approval boolean not null default true,
  rules                 text check (char_length(rules) <= 2000),
  start_date            date,
  end_date              date,
  destination           text check (char_length(destination) <= 120),
  status                text not null default 'active' check (status in ('active','archived','deleted')),
  version               integer not null default 1,
  archived_at           timestamptz,
  deleted_at            timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint groups_dates check (start_date is null or end_date is null or start_date <= end_date)
);
select add_touch_trigger('groups');

create table group_members (
  id                    uuid primary key default gen_random_uuid(),
  group_id              uuid not null references groups(id) on delete cascade,
  user_id               uuid not null references users(id) on delete restrict,
  role                  text not null default 'member' check (role in ('owner','admin','member')),
  status                text not null default 'active' check (status in ('active','left','removed')),
  display_name_snapshot text check (char_length(display_name_snapshot) <= 80),
  notification_level    text not null default 'all' check (notification_level in ('all','important','none')),
  joined_at             timestamptz not null default now(),
  left_at               timestamptz,
  removed_by            uuid references users(id) on delete set null,
  updated_at            timestamptz not null default now()
);
create unique index group_members_key on group_members (group_id, user_id);
create unique index group_members_one_owner on group_members (group_id) where role = 'owner' and status = 'active';
create index group_members_user_idx on group_members (user_id) where status = 'active';
select add_touch_trigger('group_members');

---------------------------------------------------------------------------
-- Membership helpers (SECURITY DEFINER avoids recursive RLS evaluation).
---------------------------------------------------------------------------
create or replace function montra.is_group_member(p_group uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select exists (select 1 from montra.group_members m
                 where m.group_id = p_group and m.user_id = montra.current_user_id() and m.status = 'active')
$$;

create or replace function montra.group_role(p_group uuid) returns text
language sql stable security definer set search_path = montra, pg_temp as $$
  select m.role from montra.group_members m
  where m.group_id = p_group and m.user_id = montra.current_user_id() and m.status = 'active'
$$;

create or replace function montra.is_group_admin(p_group uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select coalesce(montra.group_role(p_group) in ('owner','admin'), false)
$$;

create or replace function montra.share_active_group(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select exists (select 1 from montra.group_members a join montra.group_members b on a.group_id = b.group_id
                 where a.user_id = p_a and b.user_id = p_b and a.status = 'active' and b.status = 'active')
$$;

revoke all on function montra.is_group_member(uuid) from public;
revoke all on function montra.group_role(uuid) from public;
revoke all on function montra.is_group_admin(uuid) from public;
revoke all on function montra.share_active_group(uuid, uuid) from public;
grant execute on function montra.is_group_member(uuid) to montra_app, montra_worker;
grant execute on function montra.group_role(uuid) to montra_app, montra_worker;
grant execute on function montra.is_group_admin(uuid) to montra_app, montra_worker;
grant execute on function montra.share_active_group(uuid, uuid) to montra_app, montra_worker;

select apply_worker_rls('groups');
create policy app_groups_select on groups for select to montra_app
  using (montra.is_group_member(id) or created_by = montra.current_user_id());
create policy app_groups_insert on groups for insert to montra_app with check (created_by = montra.current_user_id());
create policy app_groups_update on groups for update to montra_app using (montra.is_group_admin(id)) with check (montra.is_group_admin(id));
revoke delete on groups from montra_app;

select apply_worker_rls('group_members');
create policy app_members_select on group_members for select to montra_app
  using (montra.is_group_member(group_id) or user_id = montra.current_user_id());
-- Admins add members (approved join requests); a user may join themselves
-- only for the group named in the transaction-local montra.join_group_id
-- (set after the backend validated an invitation), or as owner of a group
-- they just created.
create policy app_members_insert on group_members for insert to montra_app with check (
  montra.is_group_admin(group_id)
  or (user_id = montra.current_user_id() and role = 'member' and status = 'active'
      and group_id::text = current_setting('montra.join_group_id', true))
  or (user_id = montra.current_user_id() and role = 'owner'
      and exists (select 1 from montra.groups g where g.id = group_id and g.created_by = montra.current_user_id())));
create policy app_members_update on group_members for update to montra_app
  using (montra.is_group_admin(group_id) or user_id = montra.current_user_id())
  with check (montra.is_group_admin(group_id) or (user_id = montra.current_user_id() and role <> 'owner') or user_id = montra.current_user_id());
revoke delete on group_members from montra_app;

create table group_invitations (
  id              uuid primary key default gen_random_uuid(),
  group_id        uuid not null references groups(id) on delete cascade,
  invited_by      uuid references users(id) on delete set null,
  kind            text not null check (kind in ('link','username')),
  invitee_user_id uuid references users(id) on delete cascade,
  token_hash      bytea,
  max_uses        integer check (max_uses between 1 and 1000),
  use_count       integer not null default 0,
  status          text not null default 'active' check (status in ('active','accepted','declined','revoked','expired')),
  expires_at      timestamptz not null,
  revoked_at      timestamptz,
  created_at      timestamptz not null default now(),
  constraint group_invitations_kind_fields check ((kind = 'link' and token_hash is not null) or (kind = 'username' and invitee_user_id is not null))
);
create unique index group_invitations_token_key on group_invitations (token_hash) where token_hash is not null;
create index group_invitations_group_idx on group_invitations (group_id, status);
create index group_invitations_invitee_idx on group_invitations (invitee_user_id) where invitee_user_id is not null;
select apply_worker_rls('group_invitations');
create policy app_invitations_select on group_invitations for select to montra_app
  using (montra.is_group_member(group_id) or invitee_user_id = montra.current_user_id());
create policy app_invitations_insert on group_invitations for insert to montra_app
  with check (montra.is_group_member(group_id) and invited_by = montra.current_user_id());
create policy app_invitations_update on group_invitations for update to montra_app
  using (montra.is_group_member(group_id) or invitee_user_id = montra.current_user_id()
         or id::text = current_setting('montra.redeem_invitation_id', true))
  with check (true);
revoke delete on group_invitations from montra_app;

-- Invitation preview for a token holder who is not yet a member.
create or replace function montra.group_invitation_by_token(p_hash bytea)
returns table (invitation_id uuid, group_id uuid, group_name text, group_type text, status text,
               expires_at timestamptz, max_uses integer, use_count integer, group_status text)
language sql stable security definer set search_path = montra, pg_temp as $$
  select i.id, g.id, g.name, g.group_type, i.status, i.expires_at, i.max_uses, i.use_count, g.status
  from montra.group_invitations i join montra.groups g on g.id = i.group_id
  where i.token_hash = p_hash and i.kind = 'link'
$$;
revoke all on function montra.group_invitation_by_token(bytea) from public;
grant execute on function montra.group_invitation_by_token(bytea) to montra_app;

create table group_join_requests (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups(id) on delete cascade,
  user_id     uuid not null references users(id) on delete cascade,
  message     text check (char_length(message) <= 300),
  status      text not null default 'pending' check (status in ('pending','approved','declined','cancelled')),
  decided_by  uuid references users(id) on delete set null,
  decided_at  timestamptz,
  created_at  timestamptz not null default now()
);
create unique index group_join_requests_pending on group_join_requests (group_id, user_id) where status = 'pending';
select apply_worker_rls('group_join_requests');
create policy app_join_req_select on group_join_requests for select to montra_app
  using (user_id = montra.current_user_id() or montra.is_group_admin(group_id));
create policy app_join_req_insert on group_join_requests for insert to montra_app
  with check (user_id = montra.current_user_id() and status = 'pending');
create policy app_join_req_update on group_join_requests for update to montra_app
  using (user_id = montra.current_user_id() or montra.is_group_admin(group_id)) with check (true);
revoke delete on group_join_requests from montra_app;

create table group_expenses (
  id                    uuid primary key default gen_random_uuid(),
  group_id              uuid not null references groups(id) on delete cascade,
  created_by            uuid references users(id) on delete set null,
  description           text not null check (char_length(description) between 1 and 200),
  category_key          text check (category_key ~ '^[a-z_]{2,40}$'),
  amount_minor          bigint not null check (amount_minor > 0 and amount_minor <= 1000000000000000),
  currency              text not null references currencies(code),
  original_amount_minor bigint check (original_amount_minor > 0),
  original_currency     text references currencies(code),
  fx_rate               numeric(30,12) check (fx_rate > 0),
  fx_rate_source        text check (fx_rate_source in ('manual','ecb','provider')),
  fx_rate_at            timestamptz,
  expense_date          date not null,
  split_method          text not null check (split_method in ('equal','exact','percentage','shares','itemized')),
  split_input           jsonb not null,
  receipt_file_id       uuid,
  notes                 text check (char_length(notes) <= 2000),
  status                text not null default 'active' check (status in ('active','disputed','deleted')),
  recurring_rule_id     uuid,
  version               integer not null default 1,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz,
  constraint group_expenses_fx_pair check ((original_currency is null) = (original_amount_minor is null))
);
create index group_expenses_group_date_idx on group_expenses (group_id, expense_date desc, id desc);
select add_touch_trigger('group_expenses');

create table group_expense_payers (
  expense_id   uuid not null references group_expenses(id) on delete cascade,
  group_id     uuid not null references groups(id) on delete cascade,
  user_id      uuid not null references users(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  primary key (expense_id, user_id)
);
create index group_expense_payers_user_idx on group_expense_payers (group_id, user_id);

create table group_expense_shares (
  expense_id  uuid not null references group_expenses(id) on delete cascade,
  group_id    uuid not null references groups(id) on delete cascade,
  user_id     uuid not null references users(id) on delete restrict,
  share_minor bigint not null check (share_minor >= 0),
  input_value text check (char_length(input_value) <= 40),
  position    smallint not null,
  primary key (expense_id, user_id)
);
create index group_expense_shares_user_idx on group_expense_shares (group_id, user_id);

create table group_expense_items (
  id           uuid primary key default gen_random_uuid(),
  expense_id   uuid not null references group_expenses(id) on delete cascade,
  group_id     uuid not null references groups(id) on delete cascade,
  position     smallint not null,
  description  text not null check (char_length(description) between 1 and 200),
  amount_minor bigint not null check (amount_minor >= 0),
  quantity     numeric(12,3) check (quantity > 0)
);
create unique index group_expense_items_pos_key on group_expense_items (expense_id, position);

create table group_expense_item_shares (
  item_id     uuid not null references group_expense_items(id) on delete cascade,
  expense_id  uuid not null references group_expenses(id) on delete cascade,
  group_id    uuid not null references groups(id) on delete cascade,
  user_id     uuid not null references users(id) on delete restrict,
  weight      integer not null default 1 check (weight > 0),
  share_minor bigint not null check (share_minor >= 0),
  primary key (item_id, user_id)
);

create table group_expense_comments (
  id         uuid primary key default gen_random_uuid(),
  expense_id uuid not null references group_expenses(id) on delete cascade,
  group_id   uuid not null references groups(id) on delete cascade,
  author_id  uuid references users(id) on delete set null,
  body       text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  edited_at  timestamptz,
  deleted_at timestamptz
);
create index group_expense_comments_idx on group_expense_comments (expense_id, created_at);

create table group_expense_revisions (
  id         uuid primary key default gen_random_uuid(),
  expense_id uuid not null references group_expenses(id) on delete cascade,
  group_id   uuid not null references groups(id) on delete cascade,
  version    integer not null,
  editor_id  uuid references users(id) on delete set null,
  snapshot   jsonb not null,
  created_at timestamptz not null default now()
);
create unique index group_expense_revisions_key on group_expense_revisions (expense_id, version);

create table settlements (
  id                     uuid primary key default gen_random_uuid(),
  group_id               uuid not null references groups(id) on delete cascade,
  payer_user_id          uuid not null references users(id) on delete restrict,
  payee_user_id          uuid not null references users(id) on delete restrict,
  amount_minor           bigint not null check (amount_minor > 0 and amount_minor <= 1000000000000000),
  currency               text not null references currencies(code),
  method                 text not null default 'other' check (method in ('cash','bank_transfer','upi','other')),
  status                 text not null default 'proposed' check (status in ('proposed','user_reported_paid','confirmed',
                           'disputed','voided')),
  verification           text not null default 'user_reported' check (verification in ('user_reported','provider_verified')),
  proposed_by            uuid references users(id) on delete set null,
  confirmed_by           uuid references users(id) on delete set null,
  confirmed_at           timestamptz,
  dispute_reason         text check (char_length(dispute_reason) <= 500),
  voided_by              uuid references users(id) on delete set null,
  void_reason            text check (char_length(void_reason) <= 500),
  voided_at              timestamptz,
  corrects_settlement_id uuid references settlements(id),
  note                   text check (char_length(note) <= 500),
  receipt_file_id        uuid,
  settled_on             date not null,
  version                integer not null default 1,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint settlements_distinct_parties check (payer_user_id <> payee_user_id)
);
create index settlements_group_idx on settlements (group_id, created_at desc);
select add_touch_trigger('settlements');

create table group_disputes (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references groups(id) on delete cascade,
  expense_id    uuid references group_expenses(id) on delete cascade,
  settlement_id uuid references settlements(id) on delete cascade,
  raised_by     uuid references users(id) on delete set null,
  reason        text not null check (char_length(reason) between 1 and 1000),
  status        text not null default 'open' check (status in ('open','resolved','withdrawn')),
  resolution    text check (char_length(resolution) <= 1000),
  resolved_by   uuid references users(id) on delete set null,
  resolved_at   timestamptz,
  created_at    timestamptz not null default now(),
  constraint group_disputes_target check ((expense_id is not null) <> (settlement_id is not null))
);
create index group_disputes_group_idx on group_disputes (group_id, status);

create table group_activity_events (
  id          bigint generated always as identity primary key,
  group_id    uuid not null references groups(id) on delete cascade,
  actor_id    uuid references users(id) on delete set null,
  kind        text not null,
  entity_type text not null,
  entity_id   uuid,
  summary     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index group_activity_idx on group_activity_events (group_id, id desc);

-- Group-scoped RLS for all group child tables.
do $$
declare t text;
begin
  foreach t in array array['group_expenses','group_expense_payers','group_expense_shares','group_expense_items',
                           'group_expense_item_shares','group_expense_comments','group_expense_revisions',
                           'settlements','group_disputes','group_activity_events']
  loop
    execute format('alter table montra.%I enable row level security', t);
    execute format('create policy worker_all on montra.%I for all to montra_worker using (true) with check (true)', t);
    execute format('create policy app_group_select on montra.%I for select to montra_app using (montra.is_group_member(group_id))', t);
    execute format('create policy app_group_insert on montra.%I for insert to montra_app with check (montra.is_group_member(group_id))', t);
    execute format('create policy app_group_update on montra.%I for update to montra_app using (montra.is_group_member(group_id)) with check (montra.is_group_member(group_id))', t);
  end loop;
end $$;
-- Shares/payers/items are replaced on edit (history kept in revisions).
create policy app_group_delete on group_expense_payers for delete to montra_app using (montra.is_group_member(group_id));
create policy app_group_delete on group_expense_shares for delete to montra_app using (montra.is_group_member(group_id));
create policy app_group_delete on group_expense_items for delete to montra_app using (montra.is_group_member(group_id));
create policy app_group_delete on group_expense_item_shares for delete to montra_app using (montra.is_group_member(group_id));
revoke delete on group_expenses, group_expense_comments, group_expense_revisions, settlements, group_disputes from montra_app;
select make_append_only('group_expense_revisions');
select make_append_only('group_activity_events');

-- Cross-references from personal records.
alter table financial_accounts add constraint financial_accounts_group_fkey foreign key (group_id) references groups(id) on delete set null;
alter table transactions add constraint transactions_group_fkey foreign key (group_id) references groups(id) on delete set null;
alter table transactions add constraint transactions_group_expense_fkey foreign key (group_expense_id) references group_expenses(id) on delete set null;
alter table transactions add constraint transactions_settlement_fkey foreign key (settlement_id) references settlements(id) on delete set null;
alter table files add constraint files_group_fkey foreign key (group_id) references groups(id) on delete set null;
alter table group_expenses add constraint group_expenses_receipt_file_fkey foreign key (receipt_file_id) references files(id) on delete set null;
alter table settlements add constraint settlements_receipt_file_fkey foreign key (receipt_file_id) references files(id) on delete set null;

-- Household-shared accounts/transactions and group files are readable by
-- active members (read-only); personal records stay owner-only otherwise.
create policy app_accounts_group_read on financial_accounts for select to montra_app
  using (shared_with_group and group_id is not null and montra.is_group_member(group_id));
create policy app_transactions_group_read on transactions for select to montra_app
  using (group_id is not null and montra.is_group_member(group_id));
create policy app_files_group_read on files for select to montra_app
  using (storage_area = 'group' and group_id is not null and montra.is_group_member(group_id));

---------------------------------------------------------------------------
-- Friends, blocks, mutes
---------------------------------------------------------------------------
create table friend_requests (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references users(id) on delete cascade,
  addressee_id uuid not null references users(id) on delete cascade,
  message      text check (char_length(message) <= 200),
  status       text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  constraint friend_requests_distinct check (requester_id <> addressee_id)
);
create unique index friend_requests_pending_pair on friend_requests (least(requester_id, addressee_id), greatest(requester_id, addressee_id)) where status = 'pending';
create index friend_requests_addressee_idx on friend_requests (addressee_id, status);
select apply_worker_rls('friend_requests');
create policy app_fr_select on friend_requests for select to montra_app
  using (requester_id = montra.current_user_id() or addressee_id = montra.current_user_id());
create policy app_fr_insert on friend_requests for insert to montra_app with check (requester_id = montra.current_user_id());
create policy app_fr_update on friend_requests for update to montra_app
  using (requester_id = montra.current_user_id() or addressee_id = montra.current_user_id()) with check (true);
revoke delete on friend_requests from montra_app;

create table user_connections (
  user_id    uuid not null references users(id) on delete cascade,
  friend_id  uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  constraint user_connections_distinct check (user_id <> friend_id)
);
create index user_connections_friend_idx on user_connections (friend_id);
select apply_worker_rls('user_connections');
create policy app_conn_select on user_connections for select to montra_app
  using (user_id = montra.current_user_id() or friend_id = montra.current_user_id());
create policy app_conn_insert on user_connections for insert to montra_app
  with check (user_id = montra.current_user_id() or friend_id = montra.current_user_id());
create policy app_conn_delete on user_connections for delete to montra_app
  using (user_id = montra.current_user_id() or friend_id = montra.current_user_id());
revoke update on user_connections from montra_app;

create table user_blocks (
  blocker_id uuid not null references users(id) on delete cascade,
  blocked_id uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_distinct check (blocker_id <> blocked_id)
);
select apply_owner_rls('user_blocks', 'blocker_id');

create table user_mutes (
  muter_id   uuid not null references users(id) on delete cascade,
  muted_id   uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (muter_id, muted_id),
  constraint user_mutes_distinct check (muter_id <> muted_id)
);
select apply_owner_rls('user_mutes', 'muter_id');

create or replace function montra.is_blocked_between(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select exists (select 1 from montra.user_blocks b
                 where (b.blocker_id = p_a and b.blocked_id = p_b) or (b.blocker_id = p_b and b.blocked_id = p_a))
$$;

create or replace function montra.are_connected(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select exists (select 1 from montra.user_connections c where c.user_id = p_a and c.friend_id = p_b)
$$;

-- Whether the current user may see another user's profile row. Column-level
-- minimization (e.g. private profiles show only name/avatar) is enforced by
-- the API layer. Balances/transactions are never part of profiles.
create or replace function montra.can_view_profile(p_user uuid) returns boolean
language plpgsql stable security definer set search_path = montra, pg_temp as $$
declare
  me uuid := montra.current_user_id();
  vis text;
begin
  if me is null then return false; end if;
  if p_user = me then return true; end if;
  if montra.is_blocked_between(me, p_user) then return false; end if;
  select profile_visibility into vis from montra.profiles where user_id = p_user;
  if vis is null then return false; end if;
  if vis = 'public' then return true; end if;
  if montra.share_active_group(me, p_user) then return true; end if;
  if vis = 'connections' and montra.are_connected(me, p_user) then return true; end if;
  if exists (select 1 from montra.friend_requests f where f.status = 'pending'
             and ((f.requester_id = p_user and f.addressee_id = me) or (f.requester_id = me and f.addressee_id = p_user))) then
    return true;
  end if;
  return false;
end $$;

revoke all on function montra.is_blocked_between(uuid, uuid) from public;
revoke all on function montra.are_connected(uuid, uuid) from public;
revoke all on function montra.can_view_profile(uuid) from public;
grant execute on function montra.is_blocked_between(uuid, uuid) to montra_app, montra_worker;
grant execute on function montra.are_connected(uuid, uuid) to montra_app, montra_worker;
grant execute on function montra.can_view_profile(uuid) to montra_app, montra_worker;

create policy app_profiles_view on profiles for select to montra_app using (montra.can_view_profile(user_id));

---------------------------------------------------------------------------
-- Communities
---------------------------------------------------------------------------
create table communities (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null check (slug ~ '^[a-z0-9-]{3,60}$'),
  name        text not null check (char_length(name) between 3 and 80),
  description text check (char_length(description) <= 2000),
  rules       text check (char_length(rules) <= 4000),
  topics      text[] not null default '{}' check (cardinality(topics) <= 10),
  visibility  text not null default 'public' check (visibility in ('public','private','invite_only')),
  created_by  uuid references users(id) on delete set null,
  status      text not null default 'active' check (status in ('active','archived','suspended')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index communities_slug_key on communities (slug);
create index communities_name_trgm on communities using gin (name gin_trgm_ops);
select add_touch_trigger('communities');

create table community_members (
  community_id     uuid not null references communities(id) on delete cascade,
  user_id          uuid not null references users(id) on delete cascade,
  role             text not null default 'member' check (role in ('owner','moderator','member')),
  status           text not null default 'active' check (status in ('active','pending','banned','left')),
  restricted_until timestamptz,
  joined_at        timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index community_members_user_idx on community_members (user_id, status);
select add_touch_trigger('community_members');

create or replace function montra.community_role(p_comm uuid) returns text
language sql stable security definer set search_path = montra, pg_temp as $$
  select m.role from montra.community_members m
  where m.community_id = p_comm and m.user_id = montra.current_user_id() and m.status = 'active'
$$;

create or replace function montra.is_community_member(p_comm uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select montra.community_role(p_comm) is not null
$$;

create or replace function montra.is_community_moderator(p_comm uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select coalesce(montra.community_role(p_comm) in ('owner','moderator'), false)
      or montra.current_platform_role() in ('admin','support')
$$;

create or replace function montra.can_view_community_content(p_comm uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select exists (select 1 from montra.communities c where c.id = p_comm and c.status = 'active' and c.visibility = 'public')
      or montra.is_community_member(p_comm)
      or montra.current_platform_role() in ('admin','support')
$$;

revoke all on function montra.community_role(uuid) from public;
revoke all on function montra.is_community_member(uuid) from public;
revoke all on function montra.is_community_moderator(uuid) from public;
revoke all on function montra.can_view_community_content(uuid) from public;
grant execute on function montra.community_role(uuid) to montra_app, montra_worker;
grant execute on function montra.is_community_member(uuid) to montra_app, montra_worker;
grant execute on function montra.is_community_moderator(uuid) to montra_app, montra_worker;
grant execute on function montra.can_view_community_content(uuid) to montra_app, montra_worker;

select apply_worker_rls('communities');
create policy app_comm_select on communities for select to montra_app
  using (visibility in ('public','private') or montra.is_community_member(id) or created_by = montra.current_user_id()
         or id::text = current_setting('montra.join_community_id', true));
create policy app_comm_insert on communities for insert to montra_app with check (created_by = montra.current_user_id());
create policy app_comm_update on communities for update to montra_app
  using (montra.is_community_moderator(id)) with check (montra.is_community_moderator(id));
revoke delete on communities from montra_app;

select apply_worker_rls('community_members');
create policy app_cm_select on community_members for select to montra_app
  using (user_id = montra.current_user_id() or montra.can_view_community_content(community_id) or montra.is_community_moderator(community_id));
create policy app_cm_insert on community_members for insert to montra_app with check (
  montra.is_community_moderator(community_id)
  or (user_id = montra.current_user_id() and role = 'member' and (
        community_id::text = current_setting('montra.join_community_id', true)
        or exists (select 1 from montra.communities c where c.id = community_id and c.status = 'active'
                   and ((c.visibility = 'public' and status = 'active') or (c.visibility = 'private' and status = 'pending')))))
  or (user_id = montra.current_user_id() and role = 'owner'
      and exists (select 1 from montra.communities c where c.id = community_id and c.created_by = montra.current_user_id())));
create policy app_cm_update on community_members for update to montra_app
  using (user_id = montra.current_user_id() or montra.is_community_moderator(community_id)) with check (true);
revoke delete on community_members from montra_app;

create table community_invitations (
  id              uuid primary key default gen_random_uuid(),
  community_id    uuid not null references communities(id) on delete cascade,
  created_by      uuid references users(id) on delete set null,
  invitee_user_id uuid references users(id) on delete cascade,
  token_hash      bytea,
  expires_at      timestamptz not null,
  used_at         timestamptz,
  revoked_at      timestamptz,
  created_at      timestamptz not null default now()
);
create unique index community_invitations_token_key on community_invitations (token_hash) where token_hash is not null;
select apply_worker_rls('community_invitations');
create policy app_ci_select on community_invitations for select to montra_app
  using (montra.is_community_moderator(community_id) or invitee_user_id = montra.current_user_id());
create policy app_ci_insert on community_invitations for insert to montra_app
  with check (montra.is_community_moderator(community_id) and created_by = montra.current_user_id());
create policy app_ci_update on community_invitations for update to montra_app
  using (montra.is_community_moderator(community_id) or invitee_user_id = montra.current_user_id()
         or id::text = current_setting('montra.redeem_invitation_id', true)) with check (true);

create or replace function montra.community_invitation_by_token(p_hash bytea)
returns table (invitation_id uuid, community_id uuid, community_name text, expires_at timestamptz,
               used_at timestamptz, revoked_at timestamptz)
language sql stable security definer set search_path = montra, pg_temp as $$
  select i.id, c.id, c.name, i.expires_at, i.used_at, i.revoked_at
  from montra.community_invitations i join montra.communities c on c.id = i.community_id
  where i.token_hash = p_hash
$$;
revoke all on function montra.community_invitation_by_token(bytea) from public;
grant execute on function montra.community_invitation_by_token(bytea) to montra_app;

create table community_posts (
  id             uuid primary key default gen_random_uuid(),
  community_id   uuid not null references communities(id) on delete cascade,
  author_id      uuid references users(id) on delete set null,
  kind           text not null default 'discussion' check (kind in ('discussion','question','resource','poll','challenge_update')),
  label          text not null default 'personal_experience' check (label in ('personal_experience','verified_guidance','question','resource')),
  title          text not null check (char_length(title) between 3 and 200),
  body           text not null check (char_length(body) <= 10000),
  link_url       text check (char_length(link_url) <= 500 and link_url ~ '^https://'),
  status         text not null default 'published' check (status in ('published','hidden','removed','deleted')),
  pinned         boolean not null default false,
  locked         boolean not null default false,
  removed_reason text check (char_length(removed_reason) <= 300),
  edited_at      timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index community_posts_feed_idx on community_posts (community_id, pinned desc, created_at desc) where status = 'published';
create index community_posts_author_idx on community_posts (author_id, created_at desc);
create index community_posts_title_trgm on community_posts using gin (title gin_trgm_ops);
select add_touch_trigger('community_posts');

create table community_comments (
  id                uuid primary key default gen_random_uuid(),
  post_id           uuid not null references community_posts(id) on delete cascade,
  community_id      uuid not null references communities(id) on delete cascade,
  author_id         uuid references users(id) on delete set null,
  parent_comment_id uuid references community_comments(id) on delete cascade,
  body              text not null check (char_length(body) between 1 and 4000),
  status            text not null default 'published' check (status in ('published','hidden','removed','deleted')),
  edited_at         timestamptz,
  created_at        timestamptz not null default now()
);
create index community_comments_post_idx on community_comments (post_id, created_at);

create table community_reactions (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references communities(id) on delete cascade,
  user_id      uuid not null references users(id) on delete cascade,
  post_id      uuid references community_posts(id) on delete cascade,
  comment_id   uuid references community_comments(id) on delete cascade,
  kind         text not null check (kind in ('like','helpful','insightful','support')),
  created_at   timestamptz not null default now(),
  constraint community_reactions_target check ((post_id is not null) <> (comment_id is not null))
);
create unique index community_reactions_key on community_reactions (user_id, coalesce(post_id, comment_id), kind);
create index community_reactions_post_idx on community_reactions (post_id) where post_id is not null;

create table community_polls (
  id             uuid primary key default gen_random_uuid(),
  post_id        uuid not null references community_posts(id) on delete cascade,
  community_id   uuid not null references communities(id) on delete cascade,
  question       text not null check (char_length(question) between 3 and 300),
  allow_multiple boolean not null default false,
  closes_at      timestamptz,
  created_at     timestamptz not null default now()
);
create unique index community_polls_post_key on community_polls (post_id);

create table community_poll_options (
  id           uuid primary key default gen_random_uuid(),
  poll_id      uuid not null references community_polls(id) on delete cascade,
  community_id uuid not null references communities(id) on delete cascade,
  position     smallint not null check (position between 1 and 10),
  label        text not null check (char_length(label) between 1 and 120)
);
create unique index community_poll_options_pos on community_poll_options (poll_id, position);

create table community_poll_votes (
  poll_id      uuid not null references community_polls(id) on delete cascade,
  option_id    uuid not null references community_poll_options(id) on delete cascade,
  community_id uuid not null references communities(id) on delete cascade,
  user_id      uuid not null references users(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (poll_id, option_id, user_id)
);

-- Community content RLS.
do $$
declare t text;
begin
  foreach t in array array['community_posts','community_comments','community_reactions','community_polls','community_poll_options']
  loop
    execute format('alter table montra.%I enable row level security', t);
    execute format('create policy worker_all on montra.%I for all to montra_worker using (true) with check (true)', t);
  end loop;
end $$;
create policy app_posts_select on community_posts for select to montra_app
  using (montra.can_view_community_content(community_id)
         and (status = 'published' or author_id = montra.current_user_id() or montra.is_community_moderator(community_id)));
create policy app_posts_insert on community_posts for insert to montra_app
  with check (author_id = montra.current_user_id() and montra.is_community_member(community_id));
create policy app_posts_update on community_posts for update to montra_app
  using (author_id = montra.current_user_id() or montra.is_community_moderator(community_id)) with check (true);
create policy app_comments_select on community_comments for select to montra_app
  using (montra.can_view_community_content(community_id)
         and (status = 'published' or author_id = montra.current_user_id() or montra.is_community_moderator(community_id)));
create policy app_comments_insert on community_comments for insert to montra_app
  with check (author_id = montra.current_user_id() and montra.is_community_member(community_id));
create policy app_comments_update on community_comments for update to montra_app
  using (author_id = montra.current_user_id() or montra.is_community_moderator(community_id)) with check (true);
create policy app_reactions_select on community_reactions for select to montra_app
  using (montra.can_view_community_content(community_id));
create policy app_reactions_insert on community_reactions for insert to montra_app
  with check (user_id = montra.current_user_id() and montra.can_view_community_content(community_id));
create policy app_reactions_delete on community_reactions for delete to montra_app using (user_id = montra.current_user_id());
create policy app_polls_select on community_polls for select to montra_app using (montra.can_view_community_content(community_id));
create policy app_polls_insert on community_polls for insert to montra_app with check (montra.is_community_member(community_id));
create policy app_poll_options_select on community_poll_options for select to montra_app using (montra.can_view_community_content(community_id));
create policy app_poll_options_insert on community_poll_options for insert to montra_app with check (montra.is_community_member(community_id));
revoke delete on community_posts, community_comments, community_polls, community_poll_options from montra_app;

-- Votes are private: users see only their own; totals via poll_results().
select apply_owner_rls('community_poll_votes');
create or replace function montra.poll_results(p_poll uuid)
returns table (option_id uuid, votes bigint)
language sql stable security definer set search_path = montra, pg_temp as $$
  select o.id, count(v.user_id)
  from montra.community_polls p
  join montra.community_poll_options o on o.poll_id = p.id
  left join montra.community_poll_votes v on v.option_id = o.id
  where p.id = p_poll and montra.can_view_community_content(p.community_id)
  group by o.id
$$;
revoke all on function montra.poll_results(uuid) from public;
grant execute on function montra.poll_results(uuid) to montra_app;

---------------------------------------------------------------------------
-- Reports, moderation, appeals
---------------------------------------------------------------------------
create table community_reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid references users(id) on delete set null,
  target_type  text not null check (target_type in ('post','comment','profile','group','community')),
  target_id    uuid not null,
  community_id uuid references communities(id) on delete cascade,
  reason       text not null check (reason in ('spam','abuse','harassment','scam','impersonation','misinformation','privacy','other')),
  details      text check (char_length(details) <= 1000),
  status       text not null default 'open' check (status in ('open','under_review','actioned','dismissed','escalated')),
  assigned_to  uuid references users(id) on delete set null,
  resolved_by  uuid references users(id) on delete set null,
  resolved_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index community_reports_queue_idx on community_reports (community_id, status, created_at);
create unique index community_reports_dedupe on community_reports (reporter_id, target_type, target_id) where status in ('open','under_review');
select add_touch_trigger('community_reports');
select apply_worker_rls('community_reports');
create policy app_reports_select on community_reports for select to montra_app
  using (reporter_id = montra.current_user_id()
         or (community_id is not null and montra.is_community_moderator(community_id))
         or montra.current_platform_role() in ('admin','support'));
create policy app_reports_insert on community_reports for insert to montra_app with check (reporter_id = montra.current_user_id());
create policy app_reports_update on community_reports for update to montra_app
  using ((community_id is not null and montra.is_community_moderator(community_id)) or montra.current_platform_role() in ('admin','support'))
  with check (true);
revoke delete on community_reports from montra_app;

create table moderation_actions (
  id             uuid primary key default gen_random_uuid(),
  community_id   uuid references communities(id) on delete cascade,
  moderator_id   uuid references users(id) on delete set null,
  target_type    text not null check (target_type in ('post','comment','profile','group','community','member')),
  target_id      uuid not null,
  target_user_id uuid references users(id) on delete set null,
  action         text not null check (action in ('hide','remove','restore','warn','restrict','ban','unban','pin','unpin',
                   'lock','unlock','dismiss_report','escalate','approve_member','reject_member')),
  reason         text check (char_length(reason) <= 500),
  report_id      uuid references community_reports(id) on delete set null,
  expires_at     timestamptz,
  reversed_at    timestamptz,
  reversed_by    uuid references users(id) on delete set null,
  created_at     timestamptz not null default now()
);
create index moderation_actions_comm_idx on moderation_actions (community_id, created_at desc);
create index moderation_actions_target_user_idx on moderation_actions (target_user_id, created_at desc);
select apply_worker_rls('moderation_actions');
create policy app_modact_select on moderation_actions for select to montra_app
  using (target_user_id = montra.current_user_id()
         or (community_id is not null and montra.is_community_moderator(community_id))
         or montra.current_platform_role() in ('admin','support'));
create policy app_modact_insert on moderation_actions for insert to montra_app
  with check (moderator_id = montra.current_user_id()
              and ((community_id is not null and montra.is_community_moderator(community_id)) or montra.current_platform_role() in ('admin','support')));
create policy app_modact_update on moderation_actions for update to montra_app
  using ((community_id is not null and montra.is_community_moderator(community_id)) or montra.current_platform_role() in ('admin','support'))
  with check (true);
revoke delete on moderation_actions from montra_app;

create table moderation_appeals (
  id            uuid primary key default gen_random_uuid(),
  action_id     uuid not null references moderation_actions(id) on delete cascade,
  community_id  uuid references communities(id) on delete cascade,
  appellant_id  uuid not null references users(id) on delete cascade,
  statement     text not null check (char_length(statement) between 1 and 2000),
  status        text not null default 'open' check (status in ('open','upheld','overturned')),
  decided_by    uuid references users(id) on delete set null,
  decided_at    timestamptz,
  decision_note text check (char_length(decision_note) <= 1000),
  created_at    timestamptz not null default now()
);
create unique index moderation_appeals_one_open on moderation_appeals (action_id) where status = 'open';
select apply_worker_rls('moderation_appeals');
create policy app_appeals_select on moderation_appeals for select to montra_app
  using (appellant_id = montra.current_user_id()
         or (community_id is not null and montra.is_community_moderator(community_id))
         or montra.current_platform_role() in ('admin','support'));
create policy app_appeals_insert on moderation_appeals for insert to montra_app with check (appellant_id = montra.current_user_id());
create policy app_appeals_update on moderation_appeals for update to montra_app
  using ((community_id is not null and montra.is_community_moderator(community_id)) or montra.current_platform_role() in ('admin','support'))
  with check (true);
revoke delete on moderation_appeals from montra_app;

---------------------------------------------------------------------------
-- Challenges (opt-in progress sharing; no absolute financial values)
---------------------------------------------------------------------------
create table challenges (
  id                  uuid primary key default gen_random_uuid(),
  community_id        uuid references communities(id) on delete cascade,
  group_id            uuid references groups(id) on delete cascade,
  created_by          uuid references users(id) on delete set null,
  title               text not null check (char_length(title) between 3 and 120),
  description         text check (char_length(description) <= 2000),
  challenge_type      text not null check (challenge_type in ('no_spend','savings_streak','grocery_budget','meal_planning','travel_savings','custom')),
  rules               text check (char_length(rules) <= 2000),
  metric              text not null check (metric in ('days','streak','milestones','percent')),
  target_value        integer not null check (target_value between 1 and 3650),
  starts_on           date not null,
  ends_on             date not null,
  visibility          text not null default 'private' check (visibility in ('public','community','group','private')),
  leaderboard_enabled boolean not null default false,
  status              text not null default 'active' check (status in ('draft','active','completed','cancelled')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint challenges_dates check (starts_on <= ends_on),
  constraint challenges_scope check (not (community_id is not null and group_id is not null))
);
select add_touch_trigger('challenges');

create table challenge_participants (
  challenge_id        uuid not null references challenges(id) on delete cascade,
  user_id             uuid not null references users(id) on delete cascade,
  status              text not null default 'active' check (status in ('active','completed','left')),
  share_progress      boolean not null default false,
  show_on_leaderboard boolean not null default false,
  progress_value      integer not null default 0 check (progress_value >= 0),
  current_streak      integer not null default 0 check (current_streak >= 0),
  best_streak         integer not null default 0 check (best_streak >= 0),
  joined_at           timestamptz not null default now(),
  completed_at        timestamptz,
  updated_at          timestamptz not null default now(),
  primary key (challenge_id, user_id)
);
select add_touch_trigger('challenge_participants');

create table challenge_progress_events (
  id           uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references challenges(id) on delete cascade,
  user_id      uuid not null references users(id) on delete cascade,
  recorded_on  date not null,
  value        integer not null check (value between 0 and 3650),
  note         text check (char_length(note) <= 300),
  created_at   timestamptz not null default now()
);
create unique index challenge_progress_day_key on challenge_progress_events (challenge_id, user_id, recorded_on);
select apply_owner_rls('challenge_progress_events');

create or replace function montra.can_view_challenge(p_challenge uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select exists (
    select 1 from montra.challenges c
    where c.id = p_challenge and (
      c.created_by = montra.current_user_id()
      or exists (select 1 from montra.challenge_participants p where p.challenge_id = c.id and p.user_id = montra.current_user_id())
      or c.visibility = 'public'
      or (c.visibility = 'community' and c.community_id is not null and montra.can_view_community_content(c.community_id))
      or (c.visibility = 'group' and c.group_id is not null and montra.is_group_member(c.group_id))))
$$;
revoke all on function montra.can_view_challenge(uuid) from public;
grant execute on function montra.can_view_challenge(uuid) to montra_app, montra_worker;

select apply_worker_rls('challenges');
create policy app_challenges_select on challenges for select to montra_app using (montra.can_view_challenge(id));
create policy app_challenges_insert on challenges for insert to montra_app with check (created_by = montra.current_user_id());
create policy app_challenges_update on challenges for update to montra_app
  using (created_by = montra.current_user_id() or (community_id is not null and montra.is_community_moderator(community_id)))
  with check (true);
revoke delete on challenges from montra_app;

select apply_worker_rls('challenge_participants');
create policy app_cp_select on challenge_participants for select to montra_app
  using (user_id = montra.current_user_id() or (share_progress and montra.can_view_challenge(challenge_id)));
create policy app_cp_insert on challenge_participants for insert to montra_app
  with check (user_id = montra.current_user_id() and montra.can_view_challenge(challenge_id));
create policy app_cp_update on challenge_participants for update to montra_app
  using (user_id = montra.current_user_id()) with check (user_id = montra.current_user_id());
revoke delete on challenge_participants from montra_app;
