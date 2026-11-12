-- Budget editors save budgets that reference the OWNER's accounts,
-- categories and merchants, which RLS hides from them. This helper counts
-- how many of the given IDs belong to the budget owner, only for callers
-- who may edit the budget, and reveals nothing else.
create or replace function montra.budget_owner_ref_count(p_budget uuid, p_kind text, p_ids uuid[]) returns integer
language plpgsql stable security definer set search_path = montra, pg_temp as $$
declare
  v_owner uuid;
  v_n integer;
begin
  if coalesce(montra.budget_access(p_budget), '') not in ('owner', 'editor') then
    raise exception 'no edit access' using errcode = '42501';
  end if;
  select owner_user_id into v_owner from budgets where id = p_budget;
  if p_kind = 'account' then
    select count(distinct id) into v_n from financial_accounts where user_id = v_owner and id = any(p_ids);
  elsif p_kind = 'category' then
    select count(distinct id) into v_n from categories where user_id = v_owner and id = any(p_ids);
  elsif p_kind = 'merchant' then
    select count(distinct id) into v_n from merchants where user_id = v_owner and id = any(p_ids);
  else
    raise exception 'unknown kind' using errcode = '22023';
  end if;
  return v_n;
end
$$;
revoke all on function montra.budget_owner_ref_count(uuid, text, uuid[]) from public;
grant execute on function montra.budget_owner_ref_count(uuid, text, uuid[]) to montra_app;
