-- P8b: communities, challenges and moderation access helpers.
--
-- Content authors and leaderboard entries are shown by their minimal
-- profile (display name, username, avatar) only — never bio, balances or
-- finance data — and only to people who can see that content.

create index if not exists community_comments_author_idx on community_comments (author_id, created_at desc);
create index if not exists community_reports_reporter_idx on community_reports (reporter_id, created_at desc);
create index if not exists challenges_scope_idx on challenges (visibility, status, starts_on);
create index if not exists challenges_community_idx on challenges (community_id) where community_id is not null;
create index if not exists challenges_group_idx on challenges (group_id) where group_id is not null;
create index if not exists challenge_participants_user_idx on challenge_participants (user_id, status);

-- Author names on community content the caller can see.
create or replace function montra.community_member_profile(p_comm uuid, p_user uuid)
returns table (display_name text, username text, avatar_file_id uuid)
language sql stable security definer set search_path = montra, pg_temp as $$
  select p.display_name, p.username, p.avatar_file_id from montra.profiles p
  where p.user_id = p_user and montra.current_user_id() is not null
    and montra.can_view_community_content(p_comm)
    and not montra.is_blocked_between(montra.current_user_id(), p_user)
    and exists (select 1 from montra.community_members m where m.community_id = p_comm and m.user_id = p_user)
$$;
revoke all on function montra.community_member_profile(uuid, uuid) from public;
grant execute on function montra.community_member_profile(uuid, uuid) to montra_app;

-- Names on a challenge leaderboard (participants who opted in).
create or replace function montra.challenge_participant_profile(p_challenge uuid, p_user uuid)
returns table (display_name text, username text, avatar_file_id uuid)
language sql stable security definer set search_path = montra, pg_temp as $$
  select p.display_name, p.username, p.avatar_file_id from montra.profiles p
  where p.user_id = p_user and montra.current_user_id() is not null
    and montra.can_view_challenge(p_challenge)
    and not montra.is_blocked_between(montra.current_user_id(), p_user)
    and exists (select 1 from montra.challenge_participants cp where cp.challenge_id = p_challenge and cp.user_id = p_user
                and (cp.user_id = montra.current_user_id() or (cp.share_progress and cp.show_on_leaderboard)))
$$;
revoke all on function montra.challenge_participant_profile(uuid, uuid) from public;
grant execute on function montra.challenge_participant_profile(uuid, uuid) to montra_app;

-- Participant counts for challenges the caller can see (rows of people who
-- do not share progress stay hidden; only the count is disclosed).
create or replace function montra.challenge_participant_count(p_challenge uuid) returns integer
language sql stable security definer set search_path = montra, pg_temp as $$
  select case when montra.can_view_challenge(p_challenge)
    then (select count(*)::int from montra.challenge_participants where challenge_id = p_challenge and status <> 'left') else 0 end
$$;
revoke all on function montra.challenge_participant_count(uuid) from public;
grant execute on function montra.challenge_participant_count(uuid) to montra_app;

-- Member counts for communities the caller can see.
create or replace function montra.community_member_count(p_comm uuid) returns integer
language sql stable security definer set search_path = montra, pg_temp as $$
  select case when exists (select 1 from montra.communities c where c.id = p_comm
                           and (c.visibility in ('public','private') or montra.is_community_member(p_comm)))
    then (select count(*)::int from montra.community_members where community_id = p_comm and status = 'active') else 0 end
$$;
revoke all on function montra.community_member_count(uuid) from public;
grant execute on function montra.community_member_count(uuid) to montra_app;

-- The caller's active platform-wide restriction or ban on community
-- participation (moderation_actions with no community; staff create them).
create or replace function montra.my_community_sanction() returns text
language sql stable security definer set search_path = montra, pg_temp as $$
  select a.action from montra.moderation_actions a
  where a.community_id is null and a.target_user_id = montra.current_user_id() and a.action in ('restrict','ban')
    and a.reversed_at is null and (a.expires_at is null or a.expires_at > now())
  order by case a.action when 'ban' then 0 else 1 end limit 1
$$;
revoke all on function montra.my_community_sanction() from public;
grant execute on function montra.my_community_sanction() to montra_app;

-- Invitees of invite-only communities may see the community's name only.
create or replace function montra.community_name_for_invitee(p_invitation uuid) returns text
language sql stable security definer set search_path = montra, pg_temp as $$
  select c.name from montra.community_invitations i join montra.communities c on c.id = i.community_id
  where i.id = p_invitation and i.invitee_user_id = montra.current_user_id()
$$;
revoke all on function montra.community_name_for_invitee(uuid) from public;
grant execute on function montra.community_name_for_invitee(uuid) to montra_app;

-- Row-level guards for the API role. The update policies allow a member to
-- update their own membership row and an author their own content (with
-- check (true)); these triggers stop self-promotion, self-unbanning,
-- clearing restrictions, and undoing moderator decisions. Moderators,
-- platform staff and the worker (no identity) are governed by policies.
create or replace function montra.community_members_guard() returns trigger
language plpgsql security definer set search_path = montra, pg_temp as $$
declare me uuid := montra.current_user_id();
begin
  if me is null or montra.is_community_moderator(old.community_id) then
    return new;
  end if;
  if old.user_id <> me or new.user_id <> old.user_id or new.community_id <> old.community_id
     or (new.role <> old.role and new.role <> 'member')
     or new.restricted_until is distinct from old.restricted_until
     or (old.status = 'banned') or (new.status = 'banned') then
    raise exception 'membership change not allowed' using errcode = '42501';
  end if;
  if new.status = 'active' and old.status <> 'active' and not exists (
       select 1 from montra.communities c where c.id = new.community_id and c.status = 'active'
       and (c.visibility = 'public' or c.id::text = current_setting('montra.join_community_id', true))) then
    raise exception 'joining needs approval or an invitation' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger community_members_guard before update on community_members
  for each row execute function montra.community_members_guard();

create or replace function montra.community_content_guard() returns trigger
language plpgsql security definer set search_path = montra, pg_temp as $$
declare me uuid := montra.current_user_id();
begin
  if me is null or montra.is_community_moderator(old.community_id) then
    return new;
  end if;
  if old.author_id is distinct from me or new.author_id is distinct from old.author_id or new.community_id <> old.community_id
     or (new.status <> old.status and new.status <> 'deleted') then
    raise exception 'content change not allowed' using errcode = '42501';
  end if;
  if tg_table_name = 'community_posts' then
    if new.pinned <> old.pinned or new.locked <> old.locked or new.removed_reason is distinct from old.removed_reason
       or (new.label = 'verified_guidance' and old.label <> 'verified_guidance') then
      raise exception 'content change not allowed' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger community_posts_guard before update on community_posts
  for each row execute function montra.community_content_guard();
create trigger community_comments_guard before update on community_comments
  for each row execute function montra.community_content_guard();

-- Votes are owner rows; voting also requires active membership (restrictive
-- policies are ANDed with the owner policy).
create policy app_votes_member on community_poll_votes as restrictive for insert to montra_app
  with check (montra.is_community_member(community_id));

-- Fix: in the original policy the unqualified "status" inside the EXISTS
-- subquery resolved to communities.status, so private join requests were
-- refused and public joins did not check the member row's status.
drop policy app_cm_insert on community_members;
create policy app_cm_insert on community_members for insert to montra_app with check (
  montra.is_community_moderator(community_members.community_id)
  or (community_members.user_id = montra.current_user_id() and community_members.role = 'member' and (
        (community_members.community_id::text = current_setting('montra.join_community_id', true) and community_members.status = 'active')
        or exists (select 1 from montra.communities c where c.id = community_members.community_id and c.status = 'active'
                   and ((c.visibility = 'public' and community_members.status = 'active')
                     or (c.visibility = 'private' and community_members.status = 'pending')))))
  or (community_members.user_id = montra.current_user_id() and community_members.role = 'owner' and community_members.status = 'active'
      and exists (select 1 from montra.communities c where c.id = community_members.community_id and c.created_by = montra.current_user_id())));

-- Group members may change only their own notification level, leave, or
-- rejoin through a validated invitation (montra.join_group_id); roles and
-- other members' rows are for admins (the update policy's with check
-- allows any own-row change, so this guard closes self-promotion).
create or replace function montra.group_members_guard() returns trigger
language plpgsql security definer set search_path = montra, pg_temp as $$
declare me uuid := montra.current_user_id();
begin
  if me is null or montra.is_group_admin(old.group_id) then
    return new;
  end if;
  if old.user_id <> me or new.user_id <> old.user_id or new.group_id <> old.group_id then
    raise exception 'membership change not allowed' using errcode = '42501';
  end if;
  if new.status = 'active' and old.status <> 'active' then
    if old.group_id::text is distinct from current_setting('montra.join_group_id', true) or new.role <> 'member' then
      raise exception 'joining needs a valid invitation' using errcode = '42501';
    end if;
  elsif new.role <> old.role then
    raise exception 'role change not allowed' using errcode = '42501';
  end if;
  if new.status not in (old.status, 'left', 'active') then
    raise exception 'membership change not allowed' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger group_members_guard before update on group_members
  for each row execute function montra.group_members_guard();

-- Invitation rows: non-admins (invitees, link redeemers) may only advance
-- the status/use count; what the invitation is for cannot change.
create or replace function montra.invitations_guard() returns trigger
language plpgsql security definer set search_path = montra, pg_temp as $$
declare me uuid := montra.current_user_id();
begin
  if me is null then
    return new;
  end if;
  if tg_table_name = 'group_invitations' then
    if montra.is_group_admin(old.group_id) then
      return new;
    end if;
    if new.group_id <> old.group_id or new.invitee_user_id is distinct from old.invitee_user_id or new.token_hash is distinct from old.token_hash
       or new.kind <> old.kind or new.max_uses is distinct from old.max_uses or new.expires_at <> old.expires_at
       or new.invited_by is distinct from old.invited_by or new.use_count < old.use_count then
      raise exception 'invitation change not allowed' using errcode = '42501';
    end if;
  else
    if montra.is_community_moderator(old.community_id) then
      return new;
    end if;
    if new.community_id <> old.community_id or new.invitee_user_id is distinct from old.invitee_user_id
       or new.token_hash is distinct from old.token_hash or new.expires_at <> old.expires_at or new.created_by is distinct from old.created_by
       or new.revoked_at is distinct from old.revoked_at or (old.used_at is not null and new.used_at is distinct from old.used_at) then
      raise exception 'invitation change not allowed' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger group_invitations_guard before update on group_invitations
  for each row execute function montra.invitations_guard();
create trigger community_invitations_guard before update on community_invitations
  for each row execute function montra.invitations_guard();

-- Redeeming a link invitation must be able to see (and so mark used) the
-- invitation row; updates are only applied to rows the select policy shows.
drop policy app_ci_select on community_invitations;
create policy app_ci_select on community_invitations for select to montra_app
  using (montra.is_community_moderator(community_id) or invitee_user_id = montra.current_user_id()
         or id::text = current_setting('montra.redeem_invitation_id', true));
