-- Communities, moderation and challenges fixes reported by the web client.
-- Idempotent and forward-only.
set local search_path = montra, extensions, public;

---------------------------------------------------------------------------
-- Optimistic concurrency for settings edited by several people
---------------------------------------------------------------------------
-- PATCH /communities/{id} (moderators) and PATCH /challenges/{id} (the
-- creator) change only the fields sent and must send the current version
-- (409 VERSION_CONFLICT when stale). Status changes (archive, restore,
-- suspension, cancellation) move the version too.
alter table communities add column if not exists version integer not null default 1 check (version >= 1);
alter table challenges add column if not exists version integer not null default 1 check (version >= 1);

---------------------------------------------------------------------------
-- Community invitations: decline, list and revoke
---------------------------------------------------------------------------
-- The invitee of a username invitation may decline it; moderators list
-- and revoke invitations.
alter table community_invitations add column if not exists declined_at timestamptz;
create index if not exists community_invitations_community_idx on community_invitations (community_id, created_at desc);
create index if not exists community_invitations_invitee_idx on community_invitations (invitee_user_id, created_at desc)
  where invitee_user_id is not null;

-- montra.invitations_guard (000014) lets an invitee update their own
-- invitation row without touching what it is for; it does not know
-- declined_at. Non-moderators may only set it once, on an unused, unrevoked
-- invitation addressed to them, and a declined invitation cannot be used.
create or replace function montra.community_invitations_decline_guard() returns trigger
language plpgsql security definer set search_path = montra, pg_temp as $$
declare me uuid := montra.current_user_id();
begin
  if me is null or montra.is_community_moderator(old.community_id) then
    return new;
  end if;
  if new.declined_at is distinct from old.declined_at
     and (old.declined_at is not null or new.declined_at is null or old.invitee_user_id is distinct from me
          or old.used_at is not null or old.revoked_at is not null) then
    raise exception 'invitation change not allowed' using errcode = '42501';
  end if;
  if old.declined_at is not null and new.used_at is distinct from old.used_at then
    raise exception 'invitation change not allowed' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists community_invitations_decline_guard on community_invitations;
create trigger community_invitations_decline_guard before update on community_invitations
  for each row execute function montra.community_invitations_decline_guard();

-- What the holder of a link token (not yet a member) may see before
-- joining: the community's name, URL name, status and size, the
-- invitation's state, the holder's own membership status, and who created
-- the link: their display name (withheld when the holder and the creator
-- blocked each other) and their username only when montra.minimal_profile
-- shows it to the holder.
create or replace function montra.community_invitation_preview(p_hash bytea)
returns table (invitation_id uuid, community_id uuid, community_name text, community_slug text, community_status text,
               member_count integer, expires_at timestamptz, used_at timestamptz, revoked_at timestamptz, declined_at timestamptz,
               invited_by uuid, inviter_display_name text, inviter_username text, inviter_blocked boolean, my_status text)
language sql stable security definer set search_path = montra, pg_temp as $$
  select i.id, c.id, c.name, c.slug, c.status,
    (select count(*) from montra.community_members m where m.community_id = c.id and m.status = 'active')::integer,
    i.expires_at, i.used_at, i.revoked_at, i.declined_at,
    i.created_by,
    case when not montra.is_blocked_between(montra.current_user_id(), i.created_by) then p.display_name end,
    (select mp.username from montra.minimal_profile(i.created_by) mp),
    i.created_by is not null and montra.is_blocked_between(montra.current_user_id(), i.created_by),
    (select m.status from montra.community_members m where m.community_id = c.id and m.user_id = montra.current_user_id())
  from montra.community_invitations i
  join montra.communities c on c.id = i.community_id
  left join montra.profiles p on p.user_id = i.created_by
  where i.token_hash = p_hash and montra.current_user_id() is not null
$$;
revoke all on function montra.community_invitation_preview(bytea) from public;
grant execute on function montra.community_invitation_preview(bytea) to montra_app;

---------------------------------------------------------------------------
-- Moderation
---------------------------------------------------------------------------
-- GET /moderation/actions (staff) pages platform actions newest first;
-- appeal state is looked up per action.
create index if not exists moderation_actions_platform_idx on moderation_actions (created_at desc, id desc) where community_id is null;
create index if not exists moderation_appeals_action_idx on moderation_appeals (action_id, created_at desc);
