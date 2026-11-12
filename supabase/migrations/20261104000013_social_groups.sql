-- Social notifications (friend requests, group invitations) get their own
-- preference category.
alter table notifications drop constraint notifications_category_check;
alter table notifications add constraint notifications_category_check check (category in ('budget','bill','subscription','recurring','goal',
  'group','settlement','trip','community','challenge','security','import','receipt','export','account','insight','system','social'));

-- The invitee of a username invitation may see the group's name (only).
create or replace function montra.group_name_for_invitee(p_invitation uuid) returns text
language sql stable security definer set search_path = montra, pg_temp as $$
  select g.name from montra.group_invitations i join montra.groups g on g.id = i.group_id
  where i.id = p_invitation and i.invitee_user_id = montra.current_user_id()
$$;
revoke all on function montra.group_name_for_invitee(uuid) from public;
grant execute on function montra.group_name_for_invitee(uuid) to montra_app;

-- Join requests need to know whether an (unguessable) group ID exists.
create or replace function montra.group_exists_for_join(p_group uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select exists (select 1 from montra.groups where id = p_group and status = 'active')
$$;
revoke all on function montra.group_exists_for_join(uuid) from public;
grant execute on function montra.group_exists_for_join(uuid) to montra_app;

-- Accounts other than the caller's are invisible through RLS on users, so
-- liveness checks go through this helper (UUIDs are unguessable).
create or replace function montra.user_is_active(p_user uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select montra.current_user_id() is not null
     and exists (select 1 from montra.users where id = p_user and status = 'active')
$$;
revoke all on function montra.user_is_active(uuid) from public;
grant execute on function montra.user_is_active(uuid) to montra_app;

-- Username search returns only the minimal profile (display name, username,
-- avatar) of active users who opted into discovery; blocks hide both ways.
-- LIKE wildcards in the query are escaped ('_' is legal in usernames).
create or replace function montra.search_discoverable(p_query text, p_limit integer)
returns table (user_id uuid, display_name text, username text, avatar_file_id uuid)
language sql stable security definer set search_path = montra, pg_temp as $$
  select p.user_id, p.display_name, p.username, p.avatar_file_id
  from montra.profiles p join montra.users u on u.id = p.user_id
  where montra.current_user_id() is not null
    and p.username is not null and p.discoverable_by_username and u.status = 'active'
    and p.username like replace(replace(replace(lower(p_query), '\', '\\'), '%', '\%'), '_', '\_') || '%'
    and p.user_id <> montra.current_user_id()
    and not montra.is_blocked_between(montra.current_user_id(), p.user_id)
  order by (p.username = lower(p_query)) desc, p.username
  limit least(greatest(coalesce(p_limit, 20), 1), 50)
$$;
revoke all on function montra.search_discoverable(text, integer) from public;
grant execute on function montra.search_discoverable(text, integer) to montra_app;

-- Exact username lookup for friend requests and group invitations.
create or replace function montra.discoverable_user_id(p_username text) returns uuid
language sql stable security definer set search_path = montra, pg_temp as $$
  select p.user_id from montra.profiles p join montra.users u on u.id = p.user_id
  where montra.current_user_id() is not null and p.username = lower(p_username) and p.discoverable_by_username
    and u.status = 'active' and p.user_id <> montra.current_user_id()
    and not montra.is_blocked_between(montra.current_user_id(), p.user_id)
$$;
revoke all on function montra.discoverable_user_id(text) from public;
grant execute on function montra.discoverable_user_id(text) to montra_app;

-- The minimal profile (display name, username, avatar; never bio, finance
-- data or balances) of someone the caller has a relationship with: a friend,
-- a pending request either way, a current or former co-member of a group,
-- someone asking to join a group the caller administers, a pending
-- invitation between them, or a user who opted into username discovery.
create or replace function montra.minimal_profile(p_user uuid)
returns table (display_name text, username text, avatar_file_id uuid)
language sql stable security definer set search_path = montra, pg_temp as $$
  select p.display_name, p.username, p.avatar_file_id from montra.profiles p
  where p.user_id = p_user and montra.current_user_id() is not null
    and not montra.is_blocked_between(montra.current_user_id(), p_user)
    and (p_user = montra.current_user_id()
      or montra.are_connected(montra.current_user_id(), p_user)
      or (p.discoverable_by_username and p.username is not null)
      or exists (select 1 from montra.friend_requests f where f.status = 'pending'
                 and ((f.requester_id = p_user and f.addressee_id = montra.current_user_id())
                   or (f.requester_id = montra.current_user_id() and f.addressee_id = p_user)))
      or exists (select 1 from montra.group_members a join montra.group_members b on a.group_id = b.group_id
                 where a.user_id = montra.current_user_id() and b.user_id = p_user)
      or exists (select 1 from montra.group_join_requests r join montra.group_members m on m.group_id = r.group_id
                 where r.user_id = p_user and r.status = 'pending' and m.user_id = montra.current_user_id()
                   and m.status = 'active' and m.role in ('owner','admin'))
      or exists (select 1 from montra.group_invitations i where i.status = 'active'
                 and ((i.invitee_user_id = p_user and i.invited_by = montra.current_user_id())
                   or (i.invitee_user_id = montra.current_user_id() and i.invited_by = p_user))))
$$;
revoke all on function montra.minimal_profile(uuid) from public;
grant execute on function montra.minimal_profile(uuid) to montra_app;

-- Honour the addressee's friend-request control (profiles.allow_friend_requests).
create or replace function montra.friend_request_allowed(p_target uuid) returns boolean
language sql stable security definer set search_path = montra, pg_temp as $$
  select montra.current_user_id() is not null and
    case coalesce((select allow_friend_requests from montra.profiles where user_id = p_target), 'everyone')
      when 'everyone' then true
      when 'nobody' then false
      else exists (select 1 from montra.user_connections a join montra.user_connections b on b.user_id = a.friend_id
                   where a.user_id = montra.current_user_id() and b.friend_id = p_target)
    end
$$;
revoke all on function montra.friend_request_allowed(uuid) from public;
grant execute on function montra.friend_request_allowed(uuid) to montra_app;
