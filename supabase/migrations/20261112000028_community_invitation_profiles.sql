-- People in an active community invitation addressed by username may see
-- each other's minimal profile (name, username, avatar), as for group
-- invitations: the invitee learns who invited them, and the inviter sees
-- whom they invited. Everything else is unchanged.
-- Idempotent and forward-only.
set local search_path = montra, extensions, public;
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
                   or (i.invitee_user_id = montra.current_user_id() and i.invited_by = p_user)))
      or exists (select 1 from montra.community_invitations ci
                 where ci.invitee_user_id is not null and ci.used_at is null and ci.revoked_at is null
                   and ci.declined_at is null and ci.expires_at > now()
                   and ((ci.invitee_user_id = p_user and ci.created_by = montra.current_user_id())
                     or (ci.invitee_user_id = montra.current_user_id() and ci.created_by = p_user))))
$$;
revoke all on function montra.minimal_profile(uuid) from public;
grant execute on function montra.minimal_profile(uuid) to montra_app;
