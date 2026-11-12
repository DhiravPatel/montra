-- Receipts and social fixes reported by the web client.
set local search_path = montra, extensions, public;

---------------------------------------------------------------------------
-- Receipts
---------------------------------------------------------------------------
-- The inbox pages newest first; pages are looked up by file (a file is a
-- page of only one receipt that is not discarded, and file deletion
-- cascades through this index).
create index if not exists receipts_user_created_idx on receipts (user_id, created_at desc, id desc);
create index if not exists receipt_files_file_idx on receipt_files (file_id);

-- Warnings carry stable codes next to the English text, in the same order,
-- with one params object per warning (values the code refers to).
alter table receipt_extractions add column if not exists warning_codes text[] not null default '{}';
alter table receipt_extractions add column if not exists warning_params jsonb not null default '[]'::jsonb;

-- Failed readings stored an empty warning when consent was missing.
update receipt_extractions
set warnings = array['Automatic reading needs your AI permission (Settings → AI); enter the details yourself.']
where status = 'failed' and error_code = 'consent_required' and warnings = array['']::text[];

-- Codes for warnings stored before codes existed (the texts the API wrote;
-- a failed reading's warning carries its error_code; anything else is a
-- note from the reader).
update receipt_extractions e
set warning_codes = coalesce((
      select array_agg(case
        when e.status = 'failed' and e.error_code is not null then e.error_code
        when w.msg = 'Subtotal, tax, tip and discount do not add up to the total.' then 'totals_mismatch'
        when w.msg like 'Line items add up to %, not the subtotal.' then 'line_items_mismatch'
        when w.msg like 'An amount could not be read:%' then 'amount_unreadable'
        when w.msg = 'The date could not be read; check it.' then 'date_unreadable'
        when w.msg = 'The currency on the receipt was not recognized; check it.' then 'currency_unrecognized'
        else 'reader_note' end order by w.ord)
      from unnest(e.warnings) with ordinality as w(msg, ord)), '{}'),
    warning_params = coalesce((
      select jsonb_agg(case when e.status <> 'failed' and w.msg like 'An amount could not be read: %'
        then jsonb_build_object('value', substr(w.msg, 30)) else '{}'::jsonb end order by w.ord)
      from unnest(e.warnings) with ordinality as w(msg, ord)), '[]'::jsonb)
where cardinality(e.warning_codes) <> cardinality(e.warnings);

-- Card and account numbers in payment hints: digits joined only by spaces,
-- dashes or dots form one number, and a number with five or more digits
-- keeps only its last four ("4111 1111 1111 1111" → "•••• 1111"). The API
-- masks before storing (internal/receipts maskPAN, which also treats other
-- Unicode spaces, dashes and dots as separators, so this never changes a
-- value it stored). The trigger keeps any write path from storing a number,
-- and the update masks hints stored before separators were covered.
create or replace function montra.mask_payment_hint(p text) returns text
language plpgsql immutable strict set search_path = montra, pg_temp as $$
declare
  rest   text := p;
  masked text := '';
  m      text[];
  num    text;
  pos    integer;
  digits text;
begin
  loop
    m := regexp_match(rest, '[0-9](?:[[:space:].\u00a0\u2007\u2009\u202f\u2010-\u2015\u2212-]*[0-9])*');
    exit when m is null;
    num := m[1];
    pos := strpos(rest, num);
    digits := regexp_replace(num, '[^0-9]', '', 'g');
    masked := masked || left(rest, pos - 1)
      || case when length(digits) >= 5 then '•••• ' || right(digits, 4) else num end;
    rest := substr(rest, pos + length(num));
  end loop;
  return masked || rest;
end
$$;

create or replace function montra.receipt_extractions_mask_hint() returns trigger
language plpgsql set search_path = montra, pg_temp as $$
begin
  new.payment_hint := montra.mask_payment_hint(new.payment_hint);
  return new;
end
$$;
drop trigger if exists receipt_extractions_mask_hint on receipt_extractions;
create trigger receipt_extractions_mask_hint before insert or update of payment_hint on receipt_extractions
  for each row execute function montra.receipt_extractions_mask_hint();

update receipt_extractions set payment_hint = montra.mask_payment_hint(payment_hint)
where payment_hint is distinct from montra.mask_payment_hint(payment_hint);

---------------------------------------------------------------------------
-- Social
---------------------------------------------------------------------------
-- Discovery is opt-in: new profiles are not discoverable by username until
-- the person turns it on. Existing profiles keep their current setting.
alter table profiles alter column discoverable_by_username set default false;

-- People are found only by their exact username (case-insensitive, a
-- leading @ ignored), never by a partial one: opted-in, active users only,
-- blocks hide both ways. Same signature for GET /users/search and the
-- users section of GET /search.
create or replace function montra.search_discoverable(p_query text, p_limit integer)
returns table (user_id uuid, display_name text, username text, avatar_file_id uuid)
language sql stable security definer set search_path = montra, pg_temp as $$
  select p.user_id, p.display_name, p.username, p.avatar_file_id
  from montra.profiles p join montra.users u on u.id = p.user_id
  where montra.current_user_id() is not null
    and p.username is not null and p.discoverable_by_username and u.status = 'active'
    and p.username = lower(regexp_replace(btrim(p_query), '^@', ''))
    and p.user_id <> montra.current_user_id()
    and not montra.is_blocked_between(montra.current_user_id(), p.user_id)
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;
revoke all on function montra.search_discoverable(text, integer) from public;
grant execute on function montra.search_discoverable(text, integer) to montra_app;

-- The block list shows whom the caller blocked: display name and username
-- only (never avatar, bio or anything else), and only to the blocker.
-- Everything else stays hidden both ways.
create or replace function montra.blocked_user_profile(p_user uuid)
returns table (display_name text, username text)
language sql stable security definer set search_path = montra, pg_temp as $$
  select p.display_name, p.username from montra.profiles p
  where p.user_id = p_user and montra.current_user_id() is not null
    and exists (select 1 from montra.user_blocks b where b.blocker_id = montra.current_user_id() and b.blocked_id = p_user)
$$;
revoke all on function montra.blocked_user_profile(uuid) from public;
grant execute on function montra.blocked_user_profile(uuid) to montra_app;
