-- Personal finance core: accounts, payment methods, categories, rules, tags,
-- merchants, transactions, transfers, append-only ledger (ADR-007), audit,
-- saved filters and FX rates.
set local search_path = montra, extensions, public;

create table financial_accounts (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references users(id) on delete cascade,
  group_id              uuid,
  shared_with_group     boolean not null default false,
  name                  text not null check (char_length(name) between 1 and 80),
  account_type          text not null check (account_type in ('cash','bank','savings','credit_card','debit_card',
                          'prepaid_card','digital_wallet','upi','loan','investment','household_ledger','custom')),
  is_liability          boolean not null generated always as (account_type in ('credit_card','loan')) stored,
  currency              text not null references currencies(code),
  institution_label     text check (char_length(institution_label) <= 80),
  icon                  text check (char_length(icon) <= 40),
  color                 text check (color ~ '^#[0-9A-Fa-f]{6}$'),
  notes                 text check (char_length(notes) <= 1000),
  masked_number         text check (masked_number ~ '^[0-9]{2,4}$'),
  include_in_overview   boolean not null default true,
  credit_limit_minor    bigint check (credit_limit_minor >= 0),
  statement_day         smallint check (statement_day between 1 and 31),
  payment_due_day       smallint check (payment_due_day between 1 and 31),
  opening_date          date not null,
  opening_transaction_id uuid,
  balance_source        text not null default 'calculated' check (balance_source in ('manual','calculated','imported','provider')),
  status                text not null default 'active' check (status in ('active','archived','closed')),
  display_order         integer not null default 0,
  last_reconciled_at    timestamptz,
  last_reconciled_balance_minor bigint,
  last_import_at        timestamptz,
  last_provider_sync_at timestamptz,
  version               integer not null default 1,
  archived_at           timestamptz,
  closed_at             timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint financial_accounts_shared_requires_group check (not shared_with_group or group_id is not null)
);
create index financial_accounts_user_idx on financial_accounts (user_id, status, display_order);
create index financial_accounts_group_idx on financial_accounts (group_id) where group_id is not null;
select add_touch_trigger('financial_accounts');
select apply_owner_rls('financial_accounts');
revoke delete on financial_accounts from montra_app;

create table payment_methods (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references users(id) on delete cascade,
  kind          text not null check (kind in ('cash','upi','debit_card','credit_card','bank_transfer','wallet','cheque','other')),
  label         text not null check (char_length(label) between 1 and 60),
  account_id    uuid references financial_accounts(id) on delete set null,
  masked_hint   text check (char_length(masked_hint) <= 24),
  network       text check (network in ('visa','mastercard','rupay','amex','discover','diners','jcb','upi','other')),
  is_default    boolean not null default false,
  archived_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index payment_methods_user_idx on payment_methods (user_id) where archived_at is null;
select add_touch_trigger('payment_methods');
select apply_owner_rls('payment_methods');

create table categories (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references users(id) on delete cascade,
  parent_id          uuid references categories(id) on delete restrict,
  name               text not null check (char_length(name) between 1 and 60),
  kind               text not null check (kind in ('expense','income','both')),
  icon               text check (char_length(icon) <= 40),
  color              text check (color ~ '^#[0-9A-Fa-f]{6}$'),
  system_key         text check (system_key ~ '^[a-z_]{2,40}$'),
  include_in_budgets boolean not null default true,
  sort_order         integer not null default 0,
  status             text not null default 'active' check (status in ('active','archived','merged')),
  merged_into_id     uuid references categories(id) on delete set null,
  version            integer not null default 1,
  archived_at        timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint categories_not_own_parent check (parent_id is null or parent_id <> id)
);
create unique index categories_unique_name on categories (user_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name)) where status = 'active';
create unique index categories_system_key on categories (user_id, system_key) where system_key is not null and status <> 'merged';
create index categories_user_idx on categories (user_id, status, sort_order);
create index categories_parent_idx on categories (parent_id) where parent_id is not null;
select add_touch_trigger('categories');
select apply_owner_rls('categories');
revoke delete on categories from montra_app;

-- Enforce a two-level hierarchy within one user's categories (prevents cycles).
create or replace function montra.categories_check_parent() returns trigger
language plpgsql as $$
declare
  p_parent uuid;
  p_user   uuid;
begin
  if new.parent_id is null then
    return new;
  end if;
  select c.parent_id, c.user_id into p_parent, p_user from montra.categories c where c.id = new.parent_id;
  if not found then
    raise exception 'parent category not found' using errcode = '23503', constraint = 'categories_parent_id_fkey';
  end if;
  if p_user <> new.user_id then
    raise exception 'parent category belongs to another user' using errcode = '23514', constraint = 'categories_parent_owner';
  end if;
  if p_parent is not null then
    raise exception 'categories support at most two levels' using errcode = '23514', constraint = 'categories_max_depth';
  end if;
  if tg_op = 'UPDATE' and exists (select 1 from montra.categories c where c.parent_id = new.id and c.status = 'active') then
    raise exception 'a category with subcategories cannot become a subcategory' using errcode = '23514', constraint = 'categories_max_depth';
  end if;
  return new;
end $$;
create trigger categories_check_parent before insert or update of parent_id on categories
  for each row execute function montra.categories_check_parent();

create table merchants (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  name                text not null check (char_length(name) between 1 and 120),
  name_normalized     text not null check (char_length(name_normalized) between 1 and 120),
  default_category_id uuid references categories(id) on delete set null,
  website             text check (char_length(website) <= 200),
  notes               text check (char_length(notes) <= 1000),
  status              text not null default 'active' check (status in ('active','archived','merged')),
  merged_into_id      uuid references merchants(id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create unique index merchants_user_name_key on merchants (user_id, name_normalized) where status <> 'merged';
create index merchants_name_trgm on merchants using gin (name_normalized gin_trgm_ops);
select add_touch_trigger('merchants');
select apply_owner_rls('merchants');

create table merchant_aliases (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references users(id) on delete cascade,
  merchant_id      uuid not null references merchants(id) on delete cascade,
  alias            text not null check (char_length(alias) between 1 and 200),
  alias_normalized text not null check (char_length(alias_normalized) between 1 and 200),
  source           text not null default 'user' check (source in ('user','import','receipt','suggestion_confirmed')),
  created_at       timestamptz not null default now()
);
create unique index merchant_aliases_key on merchant_aliases (user_id, alias_normalized);
create index merchant_aliases_merchant_idx on merchant_aliases (merchant_id);
select apply_owner_rls('merchant_aliases');

create table tags (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  name            text not null check (char_length(name) between 1 and 40),
  name_normalized text not null check (char_length(name_normalized) between 1 and 40),
  color           text check (color ~ '^#[0-9A-Fa-f]{6}$'),
  archived_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create unique index tags_user_name_key on tags (user_id, name_normalized);
select add_touch_trigger('tags');
select apply_owner_rls('tags');

create table category_rules (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references users(id) on delete cascade,
  name             text not null check (char_length(name) between 1 and 80),
  priority         integer not null default 100 check (priority between 0 and 10000),
  enabled          boolean not null default true,
  match_field      text not null check (match_field in ('description','merchant','any')),
  match_type       text not null check (match_type in ('contains','equals','starts_with','regex')),
  pattern          text not null check (char_length(pattern) between 1 and 200),
  amount_min_minor bigint check (amount_min_minor >= 0),
  amount_max_minor bigint check (amount_max_minor >= 0),
  account_id       uuid references financial_accounts(id) on delete cascade,
  transaction_type text check (transaction_type in ('expense','income')),
  set_category_id  uuid not null references categories(id) on delete cascade,
  set_merchant_id  uuid references merchants(id) on delete set null,
  apply_to         text not null default 'all' check (apply_to in ('manual','imports','all')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint category_rules_amount_range check (amount_min_minor is null or amount_max_minor is null or amount_min_minor <= amount_max_minor)
);
create index category_rules_user_idx on category_rules (user_id, enabled, priority);
select add_touch_trigger('category_rules');
select apply_owner_rls('category_rules');

create table transactions (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references users(id) on delete cascade,
  account_id              uuid not null references financial_accounts(id) on delete cascade,
  group_id                uuid,
  type                    text not null check (type in ('expense','income','transfer','refund','reimbursement',
                            'adjustment','opening_balance','group_expense','settlement')),
  direction               text not null check (direction in ('inflow','outflow')),
  status                  text not null default 'posted' check (status in ('draft','pending','posted','voided','reversed')),
  amount_minor            bigint not null check (amount_minor > 0 and amount_minor <= 1000000000000000),
  currency                text not null references currencies(code),
  original_amount_minor   bigint check (original_amount_minor > 0 and original_amount_minor <= 1000000000000000),
  original_currency       text references currencies(code),
  fx_rate                 numeric(30,12) check (fx_rate > 0),
  fx_rate_source          text check (fx_rate_source in ('manual','ecb','provider','statement')),
  fx_rate_at              timestamptz,
  fx_fee_minor            bigint check (fx_fee_minor >= 0),
  occurred_at             timestamptz not null,
  local_date              date not null,
  timezone                text not null check (char_length(timezone) between 1 and 64),
  posted_at               timestamptz,
  category_id             uuid references categories(id),
  merchant_id             uuid references merchants(id) on delete set null,
  payment_method_id       uuid references payment_methods(id) on delete set null,
  description             text check (char_length(description) <= 500),
  notes                   text check (char_length(notes) <= 4000),
  location_text           text check (char_length(location_text) <= 200),
  original_transaction_id uuid references transactions(id),
  transfer_id             uuid,
  recurring_rule_id       uuid,
  recurring_occurrence_id uuid,
  group_expense_id        uuid,
  settlement_id           uuid,
  personal_share_minor    bigint,
  source                  text not null default 'manual' check (source in ('manual','import','receipt','recurring',
                            'integration','correction','group','system')),
  import_row_id           uuid,
  receipt_id              uuid,
  external_id             text check (char_length(external_id) <= 200),
  source_fingerprint      text check (char_length(source_fingerprint) <= 128),
  reconciliation_state    text not null default 'unreconciled' check (reconciliation_state in ('unreconciled','matched','reconciled','excluded')),
  is_correction           boolean not null default false,
  version                 integer not null default 1,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  deleted_at              timestamptz,
  constraint transactions_direction_matches_type check (
    (type in ('expense','group_expense') and direction = 'outflow') or
    (type in ('income','refund','reimbursement') and direction = 'inflow') or
    (type in ('transfer','adjustment','opening_balance','settlement'))),
  constraint transactions_reimbursement_links_original check (type <> 'reimbursement' or original_transaction_id is not null),
  constraint transactions_transfer_has_transfer check (type <> 'transfer' or transfer_id is not null),
  constraint transactions_share_only_group check (personal_share_minor is null or (type = 'group_expense' and personal_share_minor between 0 and amount_minor)),
  constraint transactions_fx_pair check ((original_currency is null) = (original_amount_minor is null)),
  constraint transactions_not_self_original check (original_transaction_id is null or original_transaction_id <> id),
  constraint transactions_deleted_is_voided check (deleted_at is null or status = 'voided')
);
create index transactions_user_date_idx on transactions (user_id, local_date desc, id desc) where deleted_at is null;
create index transactions_account_date_idx on transactions (account_id, local_date desc, id desc);
create index transactions_user_category_idx on transactions (user_id, category_id, local_date) where deleted_at is null;
create index transactions_user_merchant_idx on transactions (user_id, merchant_id, local_date) where merchant_id is not null;
create index transactions_original_idx on transactions (original_transaction_id) where original_transaction_id is not null;
create index transactions_transfer_idx on transactions (transfer_id) where transfer_id is not null;
create index transactions_group_idx on transactions (group_id, local_date) where group_id is not null;
create index transactions_fingerprint_idx on transactions (user_id, source_fingerprint) where source_fingerprint is not null;
create unique index transactions_external_id_key on transactions (account_id, external_id) where external_id is not null and deleted_at is null;
create index transactions_description_trgm on transactions using gin (description gin_trgm_ops);
create index transactions_recurring_idx on transactions (recurring_rule_id) where recurring_rule_id is not null;
select add_touch_trigger('transactions');
select apply_owner_rls('transactions');
revoke delete on transactions from montra_app;

alter table financial_accounts add constraint financial_accounts_opening_tx_fkey
  foreign key (opening_transaction_id) references transactions(id) on delete set null deferrable initially deferred;

create table transfers (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references users(id) on delete cascade,
  from_account_id      uuid not null references financial_accounts(id) on delete cascade,
  to_account_id        uuid not null references financial_accounts(id) on delete cascade,
  from_transaction_id  uuid not null references transactions(id) on delete cascade deferrable initially deferred,
  to_transaction_id    uuid not null references transactions(id) on delete cascade deferrable initially deferred,
  fee_transaction_id   uuid references transactions(id) on delete set null deferrable initially deferred,
  from_amount_minor    bigint not null check (from_amount_minor > 0),
  from_currency        text not null references currencies(code),
  to_amount_minor      bigint not null check (to_amount_minor > 0),
  to_currency          text not null references currencies(code),
  fx_rate              numeric(30,12) check (fx_rate > 0),
  fx_rate_source       text check (fx_rate_source in ('manual','ecb','provider','statement')),
  fx_rate_at           timestamptz,
  fee_minor            bigint not null default 0 check (fee_minor >= 0),
  rounding_delta_minor bigint not null default 0,
  status               text not null default 'posted' check (status in ('posted','voided')),
  reversal_of_id       uuid references transfers(id),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint transfers_distinct_accounts check (from_account_id <> to_account_id),
  constraint transfers_fx_required check (from_currency = to_currency or fx_rate is not null)
);
create index transfers_user_idx on transfers (user_id, created_at desc);
select add_touch_trigger('transfers');
select apply_owner_rls('transfers');
revoke delete on transfers from montra_app;

alter table transactions add constraint transactions_transfer_fkey
  foreign key (transfer_id) references transfers(id) on delete cascade deferrable initially deferred;

-- Authoritative balance source. Entries are never updated or deleted by the
-- API: edits append reversing entries (ADR-007).
create table account_ledger_entries (
  id                  bigint generated always as identity primary key,
  user_id             uuid not null references users(id) on delete cascade,
  account_id          uuid not null references financial_accounts(id) on delete cascade,
  transaction_id      uuid not null references transactions(id) on delete cascade,
  transaction_version integer not null,
  entry_kind          text not null check (entry_kind in ('post','reverse')),
  amount_minor        bigint not null check (amount_minor <> 0),
  currency            text not null references currencies(code),
  effective_date      date not null,
  created_at          timestamptz not null default now()
);
create index ledger_account_date_idx on account_ledger_entries (account_id, effective_date, id);
create index ledger_transaction_idx on account_ledger_entries (transaction_id);
create index ledger_user_idx on account_ledger_entries (user_id, effective_date);
select apply_owner_rls('account_ledger_entries');
select make_append_only('account_ledger_entries');

create table transaction_tags (
  transaction_id uuid not null references transactions(id) on delete cascade,
  tag_id         uuid not null references tags(id) on delete cascade,
  user_id        uuid not null references users(id) on delete cascade,
  created_at     timestamptz not null default now(),
  primary key (transaction_id, tag_id)
);
create index transaction_tags_tag_idx on transaction_tags (tag_id);
select apply_owner_rls('transaction_tags');

create table transaction_audit_events (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references users(id) on delete cascade,
  transaction_id uuid not null references transactions(id) on delete cascade,
  actor_user_id  uuid,
  actor_kind     text not null default 'user' check (actor_kind in ('user','system','import','recurring','integration')),
  action         text not null check (action in ('created','updated','voided','restored','refund_added','reimbursement_added',
                   'reconciled','unreconciled','attachment_added','attachment_removed','bulk_updated','duplicated',
                   'imported','rule_categorized','receipt_linked','tags_changed')),
  version        integer not null,
  changes        jsonb not null default '{}'::jsonb,
  request_id     text,
  created_at     timestamptz not null default now()
);
create index transaction_audit_tx_idx on transaction_audit_events (transaction_id, id);
select apply_owner_rls('transaction_audit_events');
select make_append_only('transaction_audit_events');

create table saved_filters (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  scope      text not null check (scope in ('transactions','reports','search')),
  name       text not null check (char_length(name) between 1 and 80),
  filter     jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index saved_filters_name_key on saved_filters (user_id, scope, lower(name));
select add_touch_trigger('saved_filters');
select apply_owner_rls('saved_filters');

-- Exchange rates. user_id NULL = provider/system rate (read-only to users);
-- user rows are manual overrides owned by that user.
create table fx_rates (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid references users(id) on delete cascade,
  base_currency  text not null references currencies(code),
  quote_currency text not null references currencies(code),
  rate           numeric(30,12) not null check (rate > 0),
  source         text not null check (source in ('manual','ecb','provider')),
  as_of          timestamptz not null,
  created_at     timestamptz not null default now(),
  constraint fx_rates_distinct check (base_currency <> quote_currency)
);
create unique index fx_rates_key on fx_rates (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), base_currency, quote_currency, source, as_of);
create index fx_rates_lookup_idx on fx_rates (base_currency, quote_currency, as_of desc);
select apply_worker_rls('fx_rates');
create policy app_fx_read on fx_rates for select to montra_app using (user_id is null or user_id = montra.current_user_id());
create policy app_fx_write on fx_rates for insert to montra_app with check (user_id = montra.current_user_id() and source = 'manual');
create policy app_fx_update on fx_rates for update to montra_app using (user_id = montra.current_user_id()) with check (user_id = montra.current_user_id());
create policy app_fx_delete on fx_rates for delete to montra_app using (user_id = montra.current_user_id());

alter table user_preferences add constraint user_preferences_default_account_fkey
  foreign key (default_account_id) references financial_accounts(id) on delete set null;
