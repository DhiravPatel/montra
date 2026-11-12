-- Transactions are visible to other people only when they sit in an
-- account explicitly shared with a household/group the reader belongs to.
-- The previous policy keyed on transactions.group_id, which group-linked
-- personal records also carry (the expense's group), so group members could
-- read each other's linked personal records. Those stay owner-only
-- (ADR-036).
drop policy if exists app_transactions_group_read on transactions;
create policy app_transactions_group_read on transactions for select to montra_app
  using (exists (select 1 from financial_accounts a
                 where a.id = transactions.account_id and a.shared_with_group and a.group_id is not null
                   and montra.is_group_member(a.group_id)));
