-- Organize screens: categorization rules, tags and merchants get optimistic
-- concurrency like categories and payment methods (writes check `version`
-- when the client sends it).
alter table category_rules add column if not exists version integer not null default 1 check (version >= 1);
alter table tags add column if not exists version integer not null default 1 check (version >= 1);
alter table merchants add column if not exists version integer not null default 1 check (version >= 1);

-- A rule's amount bounds are minor units of this currency (set whenever a
-- bound is). Earlier rules were shown in the owner's base currency, so they
-- keep it.
alter table category_rules add column if not exists amount_currency text references currencies(code);
update category_rules r set amount_currency = p.base_currency
  from user_preferences p
  where p.user_id = r.user_id and r.amount_currency is null
    and (r.amount_min_minor is not null or r.amount_max_minor is not null);
