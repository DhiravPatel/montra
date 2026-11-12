-- Groups fixes reported by the web client.
set local search_path = montra, extensions, public;

---------------------------------------------------------------------------
-- Join approval
---------------------------------------------------------------------------
-- require_join_approval was stored but never enforced: link holders always
-- joined directly. The API now enforces it, so new groups start without
-- approval and existing groups keep the behaviour they had (admins can turn
-- approval on). Nothing observable changes for them, so the version stays
-- and the touch trigger is held off (group lists are ordered by updated_at).
alter table groups alter column require_join_approval set default false;
alter table groups disable trigger touch_updated_at;
update groups set require_join_approval = false where require_join_approval;
alter table groups enable trigger touch_updated_at;

-- A join request created by accepting an invitation link remembers it.
alter table group_join_requests add column if not exists invitation_id uuid references group_invitations(id) on delete set null;

---------------------------------------------------------------------------
-- Invitations
---------------------------------------------------------------------------
-- What the holder of a link token (not yet a member) may see: the group's
-- name, type, size, whether joining needs approval, and who created the
-- link: their display name, and their username only when
-- montra.minimal_profile shows it to the holder (discoverable or related).
-- Inviter details are withheld when the holder and the inviter blocked
-- each other (the API then treats the link as invalid).
create or replace function montra.group_invitation_preview(p_hash bytea)
returns table (invitation_id uuid, group_id uuid, group_name text, group_type text, status text, expires_at timestamptz,
               max_uses integer, use_count integer, group_status text, require_join_approval boolean, member_count integer,
               invited_by uuid, inviter_display_name text, inviter_username text, inviter_blocked boolean)
language sql stable security definer set search_path = montra, pg_temp as $$
  select i.id, g.id, g.name, g.group_type, i.status, i.expires_at, i.max_uses, i.use_count, g.status, g.require_join_approval,
    (select count(*) from montra.group_members m where m.group_id = g.id and m.status = 'active')::integer,
    i.invited_by,
    case when not montra.is_blocked_between(montra.current_user_id(), i.invited_by) then p.display_name end,
    (select mp.username from montra.minimal_profile(i.invited_by) mp),
    montra.is_blocked_between(montra.current_user_id(), i.invited_by)
  from montra.group_invitations i
  join montra.groups g on g.id = i.group_id
  left join montra.profiles p on p.user_id = i.invited_by
  where i.token_hash = p_hash and i.kind = 'link' and montra.current_user_id() is not null
$$;
revoke all on function montra.group_invitation_preview(bytea) from public;
grant execute on function montra.group_invitation_preview(bytea) to montra_app;

-- A link holder who is not a member yet (their acceptance became a join
-- request because the group requires approval) counts their use of the
-- link in the same transaction. The update policy already trusts the
-- transaction-local montra.redeem_invitation_id (set by the API after it
-- validated the token); PostgreSQL also applies the select policy to the
-- rows an update reads (use_count + 1), so the select policy trusts it too.
drop policy if exists app_invitations_select on group_invitations;
create policy app_invitations_select on group_invitations for select to montra_app
  using (montra.is_group_member(group_id) or invitee_user_id = montra.current_user_id()
         or id::text = current_setting('montra.redeem_invitation_id', true));

-- The invitee of a username invitation sees the group's name and whether
-- it is still active (archived or deleted groups cannot be joined).
create or replace function montra.group_for_invitee(p_invitation uuid)
returns table (group_name text, group_status text)
language sql stable security definer set search_path = montra, pg_temp as $$
  select g.name, g.status from montra.group_invitations i join montra.groups g on g.id = i.group_id
  where i.id = p_invitation and i.invitee_user_id = montra.current_user_id()
$$;
revoke all on function montra.group_for_invitee(uuid) from public;
grant execute on function montra.group_for_invitee(uuid) to montra_app;

---------------------------------------------------------------------------
-- Recurring shared bills: any active member adds a due occurrence
---------------------------------------------------------------------------
-- RLS lets only a rule's creator and the group's admins lock or update a
-- group rule, yet any active member may add a due occurrence (ADR-040),
-- which records the outcome on the rule. These two helpers do exactly that
-- for active members of the rule's group and nothing else; the policies on
-- recurring_rules are unchanged.

-- Locks the rule row for an active member of its group (false otherwise).
create or replace function montra.lock_group_rule(p_rule uuid) returns boolean
language plpgsql volatile security definer set search_path = montra, pg_temp as $$
declare
  v_group uuid;
begin
  select r.group_id into v_group from montra.recurring_rules r where r.id = p_rule and r.kind = 'group_expense';
  if v_group is null or not montra.is_group_member(v_group) then
    return false;
  end if;
  perform 1 from montra.recurring_rules r where r.id = p_rule for update;
  return true;
end
$$;
revoke all on function montra.lock_group_rule(uuid) from public;
grant execute on function montra.lock_group_rule(uuid) to montra_app, montra_worker;

-- Records the rule's progress after an occurrence was added or skipped:
-- the next date (from its schedule), next run and completed count (from
-- its occurrences), and the ended state once nothing is left. The status
-- may only stay as it is or move from active to ended.
create or replace function montra.record_group_rule_progress(p_rule uuid, p_next date, p_status text) returns void
language plpgsql volatile security definer set search_path = montra, pg_temp as $$
declare
  v_group  uuid;
  v_status text;
begin
  select r.group_id into v_group from montra.recurring_rules r where r.id = p_rule and r.kind = 'group_expense';
  if v_group is null or not montra.is_group_member(v_group) then
    raise exception 'not an active member of this group' using errcode = '42501';
  end if;
  select r.status into v_status from montra.recurring_rules r where r.id = p_rule for update;
  if p_status is distinct from v_status and not (v_status = 'active' and p_status = 'ended') then
    raise exception 'only the rule''s creator or the group''s admins change its status' using errcode = '42501';
  end if;
  update montra.recurring_rules r set
    status = p_status,
    next_occurrence_date = case when p_status = 'active' then p_next end,
    next_run_at = case when p_status = 'active' then
      (select min(o.due_at) from montra.recurring_occurrences o where o.rule_id = p_rule and o.status = 'scheduled') end,
    occurrences_count = (select count(*) from montra.recurring_occurrences o where o.rule_id = p_rule and o.status in ('posted','paid'))
  where r.id = p_rule;
end
$$;
revoke all on function montra.record_group_rule_progress(uuid, date, text) from public;
grant execute on function montra.record_group_rule_progress(uuid, date, text) to montra_app, montra_worker;

---------------------------------------------------------------------------
-- Expense list
---------------------------------------------------------------------------
-- GET /groups/{id}/expenses pages newest first by (expense_date,
-- created_at, id).
create index if not exists group_expenses_group_page_idx on group_expenses (group_id, expense_date desc, created_at desc, id desc);
