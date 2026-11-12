-- Subscriptions and goals fixes reported by the web and mobile clients.
set local search_path = montra, extensions, public;

---------------------------------------------------------------------------
-- Subscription payment links
---------------------------------------------------------------------------
-- The current payment links of a subscription. Linking and unlinking are
-- both kept in subscription_events (append-only history: payment_recorded
-- and payment_unlinked); this table holds only the links in force. A
-- transaction backs at most one subscription payment.
create table if not exists subscription_payments (
  subscription_id uuid not null references subscriptions(id) on delete cascade,
  transaction_id  uuid not null references transactions(id) on delete cascade,
  user_id         uuid not null references users(id) on delete cascade,
  created_at      timestamptz not null default now(),
  primary key (subscription_id, transaction_id)
);
create unique index if not exists subscription_payments_tx_key on subscription_payments (transaction_id);
create index if not exists subscription_payments_user_idx on subscription_payments (user_id);
alter table subscription_payments enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'montra' and tablename = 'subscription_payments' and policyname = 'app_owner_all') then
    -- The owner links only their own transactions to their own subscriptions.
    create policy app_owner_all on subscription_payments for all to montra_app
      using (user_id = montra.current_user_id())
      with check (user_id = montra.current_user_id()
        and exists (select 1 from montra.subscriptions s where s.id = subscription_id and s.user_id = montra.current_user_id())
        and exists (select 1 from montra.transactions t where t.id = transaction_id and t.user_id = montra.current_user_id()));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'montra' and tablename = 'subscription_payments' and policyname = 'worker_all') then
    create policy worker_all on subscription_payments for all to montra_worker using (true) with check (true);
  end if;
end $$;

-- Existing links come from the payment history (oldest link wins when a
-- transaction was recorded for more than one subscription).
insert into subscription_payments (subscription_id, transaction_id, user_id, created_at)
select distinct on (e.transaction_id) e.subscription_id, e.transaction_id, e.user_id, e.created_at
from subscription_events e
where e.kind = 'payment_recorded' and e.transaction_id is not null
order by e.transaction_id, e.created_at
on conflict do nothing;

-- History: unlinking is recorded too, and a transaction may appear in
-- several events of one subscription (recorded, unlinked, recorded again,
-- price change from a payment). Uniqueness of links lives in
-- subscription_payments.
alter table subscription_events drop constraint if exists subscription_events_kind_check;
alter table subscription_events add constraint subscription_events_kind_check check (kind in ('created','price_changed','renewed',
  'payment_recorded','payment_unlinked','trial_started','trial_ending','paused','resumed','cancellation_started','cancelled','reactivated',
  'verified','edited'));
drop index if exists subscription_events_payment_key;
create index if not exists subscription_events_tx_idx on subscription_events (transaction_id) where transaction_id is not null;

-- System-written notes carry a stable code next to the English text.
alter table subscription_events add column if not exists note_code text check (note_code ~ '^[a-z][a-z0-9_]{0,63}$');
update subscription_events set note_code = 'matched_by_detection'
where kind = 'payment_recorded' and note = 'Matched by detection' and note_code is null;

---------------------------------------------------------------------------
-- Goals
---------------------------------------------------------------------------
-- The owner has no goal_members row; their contribution visibility lives on
-- the goal and is set through the same member endpoint.
alter table goals add column if not exists owner_contribution_visibility text not null default 'amounts'
  check (owner_contribution_visibility in ('amounts','percent_only','hidden'));
