-- Budgets, recurring rules/occurrences, bills, subscriptions and goals.
set local search_path = montra, extensions, public;

---------------------------------------------------------------------------
-- Budgets
---------------------------------------------------------------------------
create table budgets (
  id                    uuid primary key default gen_random_uuid(),
  owner_user_id         uuid not null references users(id) on delete cascade,
  group_id              uuid references groups(id) on delete cascade,
  name                  text not null check (char_length(name) between 1 and 80),
  budget_type           text not null check (budget_type in ('total','category','merchant','account','envelope','zero_based')),
  period                text not null check (period in ('weekly','monthly','annual','custom')),
  timezone              text not null check (char_length(timezone) between 1 and 64),
  currency              text not null references currencies(code),
  limit_minor           bigint not null check (limit_minor >= 0 and limit_minor <= 1000000000000000),
  rollover_policy       text not null default 'none' check (rollover_policy in ('none','carry_unused','carry_overspend','carry_both')),
  rollover_cap_minor    bigint check (rollover_cap_minor >= 0),
  include_pending       boolean not null default false,
  refunds_restore       boolean not null default true,
  count_group_shares    boolean not null default true,
  included_account_ids  uuid[] not null default '{}',
  excluded_category_ids uuid[] not null default '{}',
  merchant_ids          uuid[] not null default '{}',
  alert_thresholds      smallint[] not null default '{50,75,90,100}',
  alert_forecast        boolean not null default true,
  visibility            text not null default 'private' check (visibility in ('private','members')),
  status                text not null default 'active' check (status in ('active','paused','archived')),
  starts_on             date not null,
  ends_on               date,
  notes                 text check (char_length(notes) <= 1000),
  version               integer not null default 1,
  archived_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint budgets_custom_has_end check (period <> 'custom' or ends_on is not null),
  constraint budgets_dates check (ends_on is null or starts_on <= ends_on),
  constraint budgets_thresholds check (alert_thresholds <@ '{1,5,10,20,25,30,40,50,60,70,75,80,90,95,100,110,125,150}'::smallint[])
);
create index budgets_owner_idx on budgets (owner_user_id, status);
create index budgets_group_idx on budgets (group_id) where group_id is not null;
select add_touch_trigger('budgets');

create table budget_members (
  budget_id  uuid not null references budgets(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  role       text not null default 'viewer' check (role in ('editor','viewer')),
  allocation_minor bigint check (allocation_minor >= 0),
  created_at timestamptz not null default now(),
  primary key (budget_id, user_id)
);

create or replace function montra.budget_access(p_budget uuid) returns text
language sql stable security definer set search_path = montra, pg_temp as $$
  select case
    when b.owner_user_id = montra.current_user_id() then 'owner'
    when exists (select 1 from montra.budget_members m where m.budget_id = b.id and m.user_id = montra.current_user_id() and m.role = 'editor') then 'editor'
    when exists (select 1 from montra.budget_members m where m.budget_id = b.id and m.user_id = montra.current_user_id()) then 'viewer'
    when b.group_id is not null and b.visibility = 'members' and montra.is_group_admin(b.group_id) then 'editor'
    when b.group_id is not null and b.visibility = 'members' and montra.is_group_member(b.group_id) then 'viewer'
  end
  from montra.budgets b where b.id = p_budget
$$;
revoke all on function montra.budget_access(uuid) from public;
grant execute on function montra.budget_access(uuid) to montra_app, montra_worker;

select apply_worker_rls('budgets');
create policy app_budgets_select on budgets for select to montra_app
  using (owner_user_id = montra.current_user_id() or montra.budget_access(id) is not null);
create policy app_budgets_insert on budgets for insert to montra_app
  with check (owner_user_id = montra.current_user_id() and (group_id is null or montra.is_group_member(group_id)));
create policy app_budgets_update on budgets for update to montra_app
  using (montra.budget_access(id) in ('owner','editor')) with check (montra.budget_access(id) in ('owner','editor'));
revoke delete on budgets from montra_app;

select apply_worker_rls('budget_members');
create policy app_bm_select on budget_members for select to montra_app using (montra.budget_access(budget_id) is not null);
create policy app_bm_write on budget_members for all to montra_app
  using (montra.budget_access(budget_id) = 'owner') with check (montra.budget_access(budget_id) = 'owner');

create table budget_allocations (
  id               uuid primary key default gen_random_uuid(),
  budget_id        uuid not null references budgets(id) on delete cascade,
  category_id      uuid references categories(id) on delete cascade,
  merchant_id      uuid references merchants(id) on delete cascade,
  account_id       uuid references financial_accounts(id) on delete cascade,
  member_user_id   uuid references users(id) on delete cascade,
  label            text check (char_length(label) <= 80),
  limit_minor      bigint not null check (limit_minor >= 0),
  rollover_policy  text check (rollover_policy in ('none','carry_unused','carry_overspend','carry_both')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint budget_allocations_target check (num_nonnulls(category_id, merchant_id, account_id, member_user_id) <= 1)
);
create index budget_allocations_budget_idx on budget_allocations (budget_id);
select add_touch_trigger('budget_allocations');
select apply_worker_rls('budget_allocations');
create policy app_ba_select on budget_allocations for select to montra_app using (montra.budget_access(budget_id) is not null);
create policy app_ba_write on budget_allocations for all to montra_app
  using (montra.budget_access(budget_id) in ('owner','editor')) with check (montra.budget_access(budget_id) in ('owner','editor'));

-- Closed-period snapshots make rollover deterministic (derived, not truth).
create table budget_period_snapshots (
  budget_id          uuid not null references budgets(id) on delete cascade,
  period_start       date not null,
  period_end         date not null,
  limit_minor        bigint not null,
  rollover_in_minor  bigint not null default 0,
  spent_minor        bigint not null,
  rollover_out_minor bigint not null default 0,
  computed_at        timestamptz not null default now(),
  primary key (budget_id, period_start)
);
select apply_worker_rls('budget_period_snapshots');
create policy app_bps_select on budget_period_snapshots for select to montra_app using (montra.budget_access(budget_id) is not null);
create policy app_bps_write on budget_period_snapshots for insert to montra_app with check (montra.budget_access(budget_id) in ('owner','editor'));

create table budget_alerts (
  id            uuid primary key default gen_random_uuid(),
  budget_id     uuid not null references budgets(id) on delete cascade,
  user_id       uuid not null references users(id) on delete cascade,
  period_start  date not null,
  kind          text not null check (kind in ('threshold','forecast_overspend','unusual_spend')),
  threshold     smallint not null default 0,
  spent_minor   bigint not null,
  limit_minor   bigint not null,
  status        text not null default 'active' check (status in ('active','dismissed','snoozed')),
  snoozed_until timestamptz,
  triggered_at  timestamptz not null default now(),
  notified_at   timestamptz,
  updated_at    timestamptz not null default now()
);
create unique index budget_alerts_dedupe on budget_alerts (budget_id, user_id, period_start, kind, threshold);
create index budget_alerts_user_idx on budget_alerts (user_id, status, triggered_at desc);
select add_touch_trigger('budget_alerts');
select apply_owner_rls('budget_alerts');

---------------------------------------------------------------------------
-- Recurring rules and occurrences
---------------------------------------------------------------------------
create table recurring_rules (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  group_id            uuid references groups(id) on delete cascade,
  kind                text not null check (kind in ('expense','income','transfer','bill','subscription','group_expense')),
  name                text not null check (char_length(name) between 1 and 120),
  frequency           text not null check (frequency in ('daily','weekly','biweekly','monthly','bimonthly','quarterly',
                        'semiannual','yearly','custom')),
  interval_count      smallint not null default 1 check (interval_count between 1 and 366),
  interval_unit       text check (interval_unit in ('day','week','month','year')),
  by_month_day        smallint check (by_month_day = -1 or by_month_day between 1 and 31),
  by_weekday          smallint check (by_weekday between 0 and 6),
  by_week_of_month    smallint check (by_week_of_month = -1 or by_week_of_month between 1 and 5),
  start_date          date not null,
  end_date            date,
  max_occurrences     integer check (max_occurrences between 1 and 10000),
  timezone            text not null check (char_length(timezone) between 1 and 64),
  local_time          time not null default '09:00',
  amount_minor        bigint check (amount_minor > 0),
  amount_is_variable  boolean not null default false,
  currency            text references currencies(code),
  account_id          uuid references financial_accounts(id) on delete set null,
  to_account_id       uuid references financial_accounts(id) on delete set null,
  category_id         uuid references categories(id) on delete set null,
  merchant_id         uuid references merchants(id) on delete set null,
  payment_method_id   uuid references payment_methods(id) on delete set null,
  description         text check (char_length(description) <= 500),
  notes               text check (char_length(notes) <= 2000),
  group_split         jsonb,
  auto_post           boolean not null default false,
  reminder_days_before smallint[] not null default '{1}',
  status              text not null default 'active' check (status in ('active','paused','ended')),
  next_occurrence_date date,
  next_run_at         timestamptz,
  generated_through   date,
  occurrences_count   integer not null default 0,
  version             integer not null default 1,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint recurring_rules_custom check (frequency <> 'custom' or interval_unit is not null),
  constraint recurring_rules_dates check (end_date is null or start_date <= end_date),
  constraint recurring_rules_transfer check (kind <> 'transfer' or (account_id is not null and to_account_id is not null))
);
create index recurring_rules_due_idx on recurring_rules (next_run_at) where status = 'active';
create index recurring_rules_user_idx on recurring_rules (user_id, status);
create index recurring_rules_group_idx on recurring_rules (group_id) where group_id is not null;
select add_touch_trigger('recurring_rules');
select apply_worker_rls('recurring_rules');
create policy app_rr_select on recurring_rules for select to montra_app
  using (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_member(group_id)));
create policy app_rr_insert on recurring_rules for insert to montra_app
  with check (user_id = montra.current_user_id() and (group_id is null or montra.is_group_member(group_id)));
create policy app_rr_update on recurring_rules for update to montra_app
  using (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_admin(group_id)))
  with check (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_admin(group_id)));
create policy app_rr_delete on recurring_rules for delete to montra_app using (user_id = montra.current_user_id());

create table recurring_occurrences (
  id             uuid primary key default gen_random_uuid(),
  rule_id        uuid not null references recurring_rules(id) on delete cascade,
  user_id        uuid not null references users(id) on delete cascade,
  group_id       uuid references groups(id) on delete cascade,
  occurrence_date date not null,
  due_at         timestamptz not null,
  status         text not null default 'scheduled' check (status in ('scheduled','posted','paid','skipped','overdue',
                   'cancelled','postponed')),
  amount_minor   bigint check (amount_minor > 0),
  overrides      jsonb not null default '{}'::jsonb,
  postponed_to   date,
  transaction_id uuid references transactions(id) on delete set null,
  group_expense_id uuid references group_expenses(id) on delete set null,
  reminder_sent_at timestamptz,
  overdue_notified_at timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index recurring_occurrences_key on recurring_occurrences (rule_id, occurrence_date);
create index recurring_occurrences_user_due_idx on recurring_occurrences (user_id, due_at) where status in ('scheduled','overdue');
create index recurring_occurrences_tx_idx on recurring_occurrences (transaction_id) where transaction_id is not null;
select add_touch_trigger('recurring_occurrences');
select apply_worker_rls('recurring_occurrences');
create policy app_ro_select on recurring_occurrences for select to montra_app
  using (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_member(group_id)));
create policy app_ro_write on recurring_occurrences for insert to montra_app with check (user_id = montra.current_user_id());
create policy app_ro_update on recurring_occurrences for update to montra_app
  using (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_member(group_id)))
  with check (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_member(group_id)));

alter table transactions add constraint transactions_recurring_rule_fkey foreign key (recurring_rule_id) references recurring_rules(id) on delete set null;
alter table transactions add constraint transactions_recurring_occurrence_fkey foreign key (recurring_occurrence_id) references recurring_occurrences(id) on delete set null;
alter table group_expenses add constraint group_expenses_recurring_rule_fkey foreign key (recurring_rule_id) references recurring_rules(id) on delete set null;

---------------------------------------------------------------------------
-- Bills
---------------------------------------------------------------------------
create table bills (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references users(id) on delete cascade,
  group_id              uuid references groups(id) on delete cascade,
  name                  text not null check (char_length(name) between 1 and 120),
  provider_name         text check (char_length(provider_name) <= 120),
  category_id           uuid references categories(id) on delete set null,
  expected_amount_minor bigint check (expected_amount_minor > 0),
  amount_is_variable    boolean not null default false,
  currency              text not null references currencies(code),
  payment_account_id    uuid references financial_accounts(id) on delete set null,
  recurring_rule_id     uuid not null references recurring_rules(id) on delete restrict,
  document_file_id      uuid references files(id) on delete set null,
  notes                 text check (char_length(notes) <= 2000),
  status                text not null default 'active' check (status in ('active','paused','archived')),
  version               integer not null default 1,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index bills_user_idx on bills (user_id, status);
create unique index bills_rule_key on bills (recurring_rule_id);
select add_touch_trigger('bills');
select apply_worker_rls('bills');
create policy app_bills_select on bills for select to montra_app
  using (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_member(group_id)));
create policy app_bills_insert on bills for insert to montra_app
  with check (user_id = montra.current_user_id() and (group_id is null or montra.is_group_member(group_id)));
create policy app_bills_update on bills for update to montra_app
  using (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_admin(group_id)))
  with check (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_admin(group_id)));
revoke delete on bills from montra_app;

---------------------------------------------------------------------------
-- Subscriptions
---------------------------------------------------------------------------
create table subscription_detection_candidates (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references users(id) on delete cascade,
  merchant_id             uuid references merchants(id) on delete set null,
  merchant_label          text not null check (char_length(merchant_label) <= 200),
  amount_minor            bigint not null check (amount_minor > 0),
  currency                text not null references currencies(code),
  amount_tolerance_minor  bigint not null default 0 check (amount_tolerance_minor >= 0),
  cadence                 text not null check (cadence in ('weekly','monthly','quarterly','semiannual','yearly')),
  confidence              numeric(4,3) not null check (confidence between 0 and 1),
  evidence_transaction_ids uuid[] not null,
  evidence                jsonb not null default '{}'::jsonb,
  next_expected_date      date,
  fingerprint             text not null check (char_length(fingerprint) <= 128),
  status                  text not null default 'pending' check (status in ('pending','confirmed','dismissed')),
  decided_at              timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);
create unique index subscription_candidates_fp on subscription_detection_candidates (user_id, fingerprint);
select add_touch_trigger('subscription_detection_candidates');
select apply_owner_rls('subscription_detection_candidates');

create table subscriptions (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references users(id) on delete cascade,
  group_id                 uuid references groups(id) on delete set null,
  name                     text not null check (char_length(name) between 1 and 120),
  plan_name                text check (char_length(plan_name) <= 120),
  merchant_id              uuid references merchants(id) on delete set null,
  category_id              uuid references categories(id) on delete set null,
  amount_minor             bigint not null check (amount_minor > 0),
  currency                 text not null references currencies(code),
  billing_frequency        text not null check (billing_frequency in ('weekly','monthly','quarterly','semiannual','yearly','custom')),
  interval_count           smallint not null default 1 check (interval_count between 1 and 366),
  interval_unit            text check (interval_unit in ('day','week','month','year')),
  start_date               date not null,
  next_renewal_date        date,
  trial_ends_on            date,
  payment_account_id       uuid references financial_accounts(id) on delete set null,
  payment_method_id        uuid references payment_methods(id) on delete set null,
  status                   text not null default 'active' check (status in ('trial','active','paused','cancellation_pending','cancelled')),
  source                   text not null default 'manual' check (source in ('manual','detected')),
  detection_candidate_id   uuid references subscription_detection_candidates(id) on delete set null,
  cancellation_url         text check (char_length(cancellation_url) <= 500 and cancellation_url ~ '^https://'),
  cancellation_instructions text check (char_length(cancellation_instructions) <= 4000),
  cancellation_checklist   jsonb not null default '[]'::jsonb,
  invoice_file_id          uuid references files(id) on delete set null,
  notes                    text check (char_length(notes) <= 2000),
  reminder_days_before     smallint[] not null default '{3}',
  last_verified_at         timestamptz,
  cancelled_at             timestamptz,
  cancellation_confirmed_by uuid references users(id) on delete set null,
  version                  integer not null default 1,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  constraint subscriptions_custom check (billing_frequency <> 'custom' or interval_unit is not null)
);
create index subscriptions_user_idx on subscriptions (user_id, status, next_renewal_date);
create index subscriptions_renewal_idx on subscriptions (next_renewal_date) where status in ('trial','active');
select add_touch_trigger('subscriptions');
select apply_worker_rls('subscriptions');
create policy app_subs_select on subscriptions for select to montra_app
  using (user_id = montra.current_user_id() or (group_id is not null and montra.is_group_member(group_id)));
create policy app_subs_insert on subscriptions for insert to montra_app
  with check (user_id = montra.current_user_id() and (group_id is null or montra.is_group_member(group_id)));
create policy app_subs_update on subscriptions for update to montra_app
  using (user_id = montra.current_user_id()) with check (user_id = montra.current_user_id());
revoke delete on subscriptions from montra_app;

create table subscription_events (
  id               uuid primary key default gen_random_uuid(),
  subscription_id  uuid not null references subscriptions(id) on delete cascade,
  user_id          uuid not null references users(id) on delete cascade,
  kind             text not null check (kind in ('created','price_changed','renewed','payment_recorded','trial_started',
                     'trial_ending','paused','resumed','cancellation_started','cancelled','reactivated','verified','edited')),
  old_amount_minor bigint,
  new_amount_minor bigint,
  transaction_id   uuid references transactions(id) on delete set null,
  occurred_on      date not null,
  note             text check (char_length(note) <= 500),
  created_at       timestamptz not null default now()
);
create index subscription_events_sub_idx on subscription_events (subscription_id, occurred_on desc);
create unique index subscription_events_payment_key on subscription_events (subscription_id, transaction_id) where transaction_id is not null;
select apply_owner_rls('subscription_events');
select make_append_only('subscription_events');

---------------------------------------------------------------------------
-- Goals
---------------------------------------------------------------------------
create table goals (
  id                         uuid primary key default gen_random_uuid(),
  owner_user_id              uuid not null references users(id) on delete cascade,
  group_id                   uuid references groups(id) on delete cascade,
  name                       text not null check (char_length(name) between 1 and 120),
  description                text check (char_length(description) <= 2000),
  goal_type                  text not null check (goal_type in ('emergency_fund','travel','education','device','vehicle',
                               'home','event','debt_payoff','large_purchase','custom')),
  target_amount_minor        bigint not null check (target_amount_minor > 0 and target_amount_minor <= 1000000000000000),
  currency                   text not null references currencies(code),
  starting_amount_minor      bigint not null default 0 check (starting_amount_minor >= 0),
  start_date                 date not null,
  target_date                date,
  priority                   smallint not null default 3 check (priority between 1 and 5),
  linked_account_id          uuid references financial_accounts(id) on delete set null,
  contribution_schedule      text not null default 'none' check (contribution_schedule in ('none','weekly','biweekly','monthly')),
  planned_contribution_minor bigint check (planned_contribution_minor > 0),
  visibility                 text not null default 'private' check (visibility in ('private','members')),
  reminders_enabled          boolean not null default false,
  status                     text not null default 'active' check (status in ('active','paused','achieved','cancelled','archived')),
  notes                      text check (char_length(notes) <= 2000),
  achieved_at                timestamptz,
  version                    integer not null default 1,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now(),
  constraint goals_dates check (target_date is null or start_date <= target_date)
);
create index goals_owner_idx on goals (owner_user_id, status);
create index goals_group_idx on goals (group_id) where group_id is not null;
select add_touch_trigger('goals');

create table goal_members (
  goal_id                 uuid not null references goals(id) on delete cascade,
  user_id                 uuid not null references users(id) on delete cascade,
  role                    text not null default 'contributor' check (role in ('contributor','viewer')),
  contribution_visibility text not null default 'amounts' check (contribution_visibility in ('amounts','percent_only','hidden')),
  joined_at               timestamptz not null default now(),
  left_at                 timestamptz,
  primary key (goal_id, user_id)
);

create or replace function montra.goal_access(p_goal uuid) returns text
language sql stable security definer set search_path = montra, pg_temp as $$
  select case
    when g.owner_user_id = montra.current_user_id() then 'owner'
    when exists (select 1 from montra.goal_members m where m.goal_id = g.id and m.user_id = montra.current_user_id()
                 and m.left_at is null and m.role = 'contributor') then 'contributor'
    when exists (select 1 from montra.goal_members m where m.goal_id = g.id and m.user_id = montra.current_user_id()
                 and m.left_at is null) then 'viewer'
    when g.group_id is not null and g.visibility = 'members' and montra.is_group_member(g.group_id) then 'contributor'
  end
  from montra.goals g where g.id = p_goal
$$;
revoke all on function montra.goal_access(uuid) from public;
grant execute on function montra.goal_access(uuid) to montra_app, montra_worker;

select apply_worker_rls('goals');
create policy app_goals_select on goals for select to montra_app
  using (owner_user_id = montra.current_user_id() or montra.goal_access(id) is not null);
create policy app_goals_insert on goals for insert to montra_app
  with check (owner_user_id = montra.current_user_id() and (group_id is null or montra.is_group_member(group_id)));
create policy app_goals_update on goals for update to montra_app
  using (owner_user_id = montra.current_user_id()) with check (owner_user_id = montra.current_user_id());
revoke delete on goals from montra_app;

select apply_worker_rls('goal_members');
create policy app_gm_select on goal_members for select to montra_app using (montra.goal_access(goal_id) is not null);
create policy app_gm_insert on goal_members for insert to montra_app with check (montra.goal_access(goal_id) = 'owner');
create policy app_gm_update on goal_members for update to montra_app
  using (montra.goal_access(goal_id) = 'owner' or user_id = montra.current_user_id())
  with check (montra.goal_access(goal_id) = 'owner' or user_id = montra.current_user_id());
create policy app_gm_delete on goal_members for delete to montra_app using (montra.goal_access(goal_id) = 'owner');

create table goal_contributions (
  id              uuid primary key default gen_random_uuid(),
  goal_id         uuid not null references goals(id) on delete cascade,
  user_id         uuid not null references users(id) on delete cascade,
  kind            text not null default 'contribution' check (kind in ('contribution','withdrawal')),
  amount_minor    bigint not null check (amount_minor > 0 and amount_minor <= 1000000000000000),
  currency        text not null references currencies(code),
  status          text not null default 'recorded' check (status in ('planned','recorded','verified')),
  transaction_id  uuid references transactions(id) on delete set null,
  contributed_on  date not null,
  note            text check (char_length(note) <= 500),
  voided_at       timestamptz,
  created_at      timestamptz not null default now()
);
create index goal_contributions_goal_idx on goal_contributions (goal_id, contributed_on desc);
create unique index goal_contributions_tx_key on goal_contributions (transaction_id) where transaction_id is not null and voided_at is null;
select apply_worker_rls('goal_contributions');
create policy app_gc_select on goal_contributions for select to montra_app using (montra.goal_access(goal_id) is not null);
create policy app_gc_insert on goal_contributions for insert to montra_app
  with check (user_id = montra.current_user_id() and montra.goal_access(goal_id) in ('owner','contributor'));
create policy app_gc_update on goal_contributions for update to montra_app
  using (user_id = montra.current_user_id()) with check (user_id = montra.current_user_id());
revoke delete on goal_contributions from montra_app;

create table goal_milestones (
  id          uuid primary key default gen_random_uuid(),
  goal_id     uuid not null references goals(id) on delete cascade,
  percent     smallint not null check (percent between 1 and 100),
  label       text check (char_length(label) <= 80),
  reached_at  timestamptz,
  notified_at timestamptz,
  created_at  timestamptz not null default now()
);
create unique index goal_milestones_key on goal_milestones (goal_id, percent);
select apply_worker_rls('goal_milestones');
create policy app_gms_select on goal_milestones for select to montra_app using (montra.goal_access(goal_id) is not null);
create policy app_gms_write on goal_milestones for all to montra_app
  using (montra.goal_access(goal_id) = 'owner') with check (montra.goal_access(goal_id) = 'owner');
