# Montra — RLS Policy Matrix

Row-level security is defence in depth (spec §3, §9). The Go backend
authorizes every request first; PostgreSQL RLS makes a missed check fail
closed instead of leaking another user's rows.

## Model

| Role | Used by | Access |
|---|---|---|
| `montra_owner` | migrations only (`cmd/migrate`) | owns the `montra` schema and every object; never used at runtime |
| `montra_app` | the API process | subject to RLS on every table; sees rows through policies keyed on `montra.current_user_id()` |
| `montra_worker` | the worker process (jobs, scheduler, outbox relay) | `worker_all` policies on every table (system work across users); still no DDL and append-only tables stay append-only |
| `PUBLIC` | — | no grants on any table or function |

- **Identity.** `database.WithUserTx` / `WithUserReadTx` run
  `set_config('montra.user_id', <uuid>, true)` and a fixed `search_path`
  inside the transaction. `WithAnonTx` sets no user, so owner policies
  match nothing. `montra.current_user_id()` reads the setting (NULL when
  unset).
- **Building blocks** (`000001_foundation`):
  - `apply_owner_rls(table, owner_col)` adds `app_owner_all`
    (`owner_col = me()` for all commands) plus `worker_all`.
  - `apply_worker_rls(table)` adds `worker_all` only; API access is then
    granted with explicit, table-specific policies.
  - `make_append_only(table)` revokes UPDATE/DELETE from the API role
    (and UPDATE from the worker).
- **Cross-user reads** never widen table policies. They go through the
  SECURITY DEFINER helpers listed below. Each requires an identity,
  returns minimal data (for example the minimal profile: name, username,
  avatar) and honours blocks both ways.
- **Guard triggers** (ADR-044) sit behind permissive own-row update
  policies on membership, invitation and community tables. They stop
  self-promotion, self-unbanning and undoing moderator decisions.
- **Postgres semantics that matter here:**
  - `UPDATE` and `SELECT … FOR UPDATE` rows must pass the SELECT policy as
    well as the UPDATE policy.
  - `INSERT … ON CONFLICT (target)` needs SELECT on the conflict columns,
    so write-only tables use target-less `ON CONFLICT DO NOTHING`.
  - The API role sees only its own `users` row.
- **Verification.** `backend/tests/rls`:
  - every table has RLS and no public access;
  - owner isolation; no identity sees nothing;
  - group boundaries; household sharing is read-only for members;
  - append-only tables;
  - profile visibility and blocking; discovery helpers return only
    minimal profiles;
  - community and group guards;
  - the webhook inbox is write-only and queuing is narrow.

  API suites also assert cross-user 404s per module.

## Policy patterns

| Pattern | Tables (examples) | Rule |
|---|---|---|
| Owner | accounts, transactions, budgets, goals, receipts, imports, notifications, push endpoints, integrations, AI conversations | `user_id = me()` for every command |
| Group member | groups, group members, shared expenses, splits, settlements, comments, activity | read: `is_group_member(group_id)`; writes need membership or `is_group_admin`; settlements, comments, revisions, disputes and activity cannot be deleted by the API role |
| Household share | shared accounts | members read through `budget_access` / account-share rows; only the owner writes |
| Community | communities, members, posts, comments, reactions, polls | `can_view_community_content`, `is_community_member`, `is_community_moderator` |
| Worker only | jobs (except own-user insert/select/cancel), outbox, webhook inbox, provider FX rates | no API read; narrow API inserts where noted |
| Append-only | audit tables, ledger entries, FX rates, transaction audit events | no UPDATE/DELETE for the API role |

<!-- generated -->

Generated from the local schema at migration `20261104000027` by `scripts/docs/gen_rls_matrix.sh`. `me()` is `montra.current_user_id()`; grants use S/I/U/D. Policies are permissive unless noted.

### Security-definer helpers

| Function | Arguments | Executable by |
|---|---|---|
| `admin_usage` | `p_days integer` | montra_app |
| `are_connected` | `p_a uuid, p_b uuid` | montra_app, montra_worker |
| `auth_lookup_token` | `p_hash bytea, p_purpose text` | montra_app |
| `auth_lookup_user` | `p_email_normalized text` | montra_app |
| `auth_resolve_access` | `p_hash bytea` | montra_app |
| `auth_resolve_refresh` | `p_hash bytea` | montra_app |
| `blocked_user_profile` | `p_user uuid` | montra_app |
| `budget_access` | `p_budget uuid` | montra_app, montra_worker |
| `budget_owner_ref_count` | `p_budget uuid, p_kind text, p_ids uuid[]` | montra_app |
| `can_view_challenge` | `p_challenge uuid` | montra_app, montra_worker |
| `can_view_community_content` | `p_comm uuid` | montra_app, montra_worker |
| `can_view_profile` | `p_user uuid` | montra_app, montra_worker |
| `challenge_participant_count` | `p_challenge uuid` | montra_app |
| `challenge_participant_profile` | `p_challenge uuid, p_user uuid` | montra_app |
| `community_content_guard` | `—` | triggers only |
| `community_invitation_by_token` | `p_hash bytea` | montra_app |
| `community_invitation_preview` | `p_hash bytea` | montra_app |
| `community_invitations_decline_guard` | `—` | triggers only |
| `community_member_count` | `p_comm uuid` | montra_app |
| `community_member_profile` | `p_comm uuid, p_user uuid` | montra_app |
| `community_members_guard` | `—` | triggers only |
| `community_name_for_invitee` | `p_invitation uuid` | montra_app |
| `community_role` | `p_comm uuid` | montra_app, montra_worker |
| `current_platform_role` | `—` | montra_app, montra_worker |
| `discoverable_user_id` | `p_username text` | montra_app |
| `end_session_push_endpoints` | `—` | triggers only |
| `enqueue_webhook_event` | `p_event_id uuid` | montra_app |
| `friend_request_allowed` | `p_target uuid` | montra_app |
| `goal_access` | `p_goal uuid` | montra_app, montra_worker |
| `group_exists_for_join` | `p_group uuid` | montra_app |
| `group_for_invitee` | `p_invitation uuid` | montra_app |
| `group_invitation_by_token` | `p_hash bytea` | montra_app |
| `group_invitation_preview` | `p_hash bytea` | montra_app |
| `group_members_guard` | `—` | triggers only |
| `group_name_for_invitee` | `p_invitation uuid` | montra_app |
| `group_role` | `p_group uuid` | montra_app, montra_worker |
| `invitations_guard` | `—` | triggers only |
| `is_blocked_between` | `p_a uuid, p_b uuid` | montra_app, montra_worker |
| `is_community_member` | `p_comm uuid` | montra_app, montra_worker |
| `is_community_moderator` | `p_comm uuid` | montra_app, montra_worker |
| `is_group_admin` | `p_group uuid` | montra_app, montra_worker |
| `is_group_member` | `p_group uuid` | montra_app, montra_worker |
| `lock_group_rule` | `p_rule uuid` | montra_app, montra_worker |
| `minimal_profile` | `p_user uuid` | montra_app |
| `my_community_sanction` | `—` | montra_app |
| `poll_results` | `p_poll uuid` | montra_app |
| `record_group_rule_progress` | `p_rule uuid, p_next date, p_status text` | montra_app, montra_worker |
| `search_discoverable` | `p_query text, p_limit integer` | montra_app |
| `share_active_group` | `p_a uuid, p_b uuid` | montra_app, montra_worker |
| `support_contact_window` | `p_email text, p_since timestamp with time zone, p_cap integer` | montra_app, montra_worker |
| `user_is_active` | `p_user uuid` | montra_app |

### Tables

| Table | RLS | API grants | Worker grants | API-role policies (command: condition) |
|---|---|---|---|---|
| `account_deletion_requests` | on | SIUD | SIUD | all: user_id = me() |
| `account_ledger_entries` | on | SI | SID | all: user_id = me() |
| `account_reconciliations` | on | SIUD | SIUD | all: user_id = me() |
| `ai_conversations` | on | SIUD | SIUD | all: user_id = me() |
| `ai_messages` | on | SIUD | SIUD | all: user_id = me() |
| `ai_usage` | on | SI | SID | all: user_id = me() |
| `audit_events` | on | SI | SID | insert: true ⟂ check NOT (actor_user_id IS DISTINCT FROM me())<br>select: user_id = me() |
| `auth_tokens` | on | SIUD | SIUD | all: user_id = me() |
| `bills` | on | SIU | SIUD | insert: true ⟂ check (user_id = me()) AND ((group_id IS NULL) OR is_group_member(group_id))<br>select: (user_id = me()) OR ((group_id IS NOT NULL) AND is_group_member(group_id))<br>update: (user_id = me()) OR ((group_id IS NOT NULL) AND is_group_admin(group_id)) |
| `budget_alerts` | on | SIUD | SIUD | all: user_id = me() |
| `budget_allocations` | on | SIUD | SIUD | select: budget_access(budget_id) IS NOT NULL<br>all: budget_access(budget_id) = ANY (ARRAY['owner', 'editor']) |
| `budget_members` | on | SIUD | SIUD | delete: user_id = me()<br>select: budget_access(budget_id) IS NOT NULL<br>all: budget_access(budget_id) = 'owner' |
| `budget_period_snapshots` | on | SIUD | SIUD | select: budget_access(budget_id) IS NOT NULL<br>update: budget_access(budget_id) = ANY (ARRAY['owner', 'editor'])<br>insert: true ⟂ check budget_access(budget_id) = ANY (ARRAY['owner', 'editor']) |
| `budgets` | on | SIU | SIUD | insert: true ⟂ check (owner_user_id = me()) AND ((group_id IS NULL) OR is_group_member(group_id))<br>select: (owner_user_id = me()) OR (budget_access(id) IS NOT NULL)<br>update: budget_access(id) = ANY (ARRAY['owner', 'editor']) |
| `categories` | on | SIUD | SIUD | all: user_id = me() |
| `category_rules` | on | SIUD | SIUD | all: user_id = me() |
| `challenge_participants` | on | SIU | SIUD | insert: true ⟂ check (user_id = me()) AND can_view_challenge(challenge_id)<br>select: (user_id = me()) OR (share_progress AND can_view_challenge(challenge_id))<br>update: user_id = me() |
| `challenge_progress_events` | on | SIUD | SIUD | all: user_id = me() |
| `challenges` | on | SIU | SIUD | insert: true ⟂ check created_by = me()<br>select: can_view_challenge(id)<br>update: (created_by = me()) OR ((community_id IS NOT NULL) AND is_community_moderator(community_id)) ⟂ check true |
| `communities` | on | SIU | SIUD | insert: true ⟂ check created_by = me()<br>select: (visibility = ANY (ARRAY['public', 'private'])) OR is_community_member(id) OR (created_by = me()) OR ((id) = current_setting('join_community_id', true))<br>update: is_community_moderator(id) |
| `community_comments` | on | SIU | SIUD | insert: true ⟂ check (author_id = me()) AND is_community_member(community_id)<br>select: can_view_community_content(community_id) AND ((status = 'published') OR (author_id = me()) OR is_community_moderator(community_id))<br>update: (author_id = me()) OR is_community_moderator(community_id) ⟂ check true |
| `community_invitations` | on | SIUD | SIUD | insert: true ⟂ check is_community_moderator(community_id) AND (created_by = me())<br>select: is_community_moderator(community_id) OR (invitee_user_id = me()) OR ((id) = current_setting('redeem_invitation_id', true))<br>update: is_community_moderator(community_id) OR (invitee_user_id = me()) OR ((id) = current_setting('redeem_invitation_id', true)) ⟂ check true |
| `community_members` | on | SIU | SIUD | insert: true ⟂ check is_community_moderator(community_id) OR ((user_id = me()) AND (role = 'member') AND ((((community_id) = current_setting('join_community_id', true)) AND (stat…<br>select: (user_id = me()) OR can_view_community_content(community_id) OR is_community_moderator(community_id)<br>update: (user_id = me()) OR is_community_moderator(community_id) ⟂ check true |
| `community_poll_options` | on | SIU | SIUD | insert: true ⟂ check is_community_member(community_id)<br>select: can_view_community_content(community_id) |
| `community_poll_votes` | on | SIUD | SIUD | all: user_id = me()<br>insert: true ⟂ check is_community_member(community_id) |
| `community_polls` | on | SIU | SIUD | insert: true ⟂ check is_community_member(community_id)<br>select: can_view_community_content(community_id) |
| `community_posts` | on | SIU | SIUD | insert: true ⟂ check (author_id = me()) AND is_community_member(community_id)<br>select: can_view_community_content(community_id) AND ((status = 'published') OR (author_id = me()) OR is_community_moderator(community_id))<br>update: (author_id = me()) OR is_community_moderator(community_id) ⟂ check true |
| `community_reactions` | on | SIUD | SIUD | delete: user_id = me()<br>insert: true ⟂ check (user_id = me()) AND can_view_community_content(community_id)<br>select: can_view_community_content(community_id) |
| `community_reports` | on | SIU | SIUD | insert: true ⟂ check reporter_id = me()<br>select: (reporter_id = me()) OR ((community_id IS NOT NULL) AND is_community_moderator(community_id)) OR (current_platform_role() = ANY (ARRAY['admin', 'support']))<br>update: ((community_id IS NOT NULL) AND is_community_moderator(community_id)) OR (current_platform_role() = ANY (ARRAY['admin', 'support'])) ⟂ check true |
| `currencies` | on | S | S | select: true |
| `dashboard_widgets` | on | SIUD | SIUD | all: user_id = me() |
| `data_exports` | on | SIUD | SIUD | all: user_id = me() |
| `files` | on | SIU | SIUD | select: (purpose = 'avatar') AND (status = 'ready') AND can_view_profile(owner_user_id)<br>select: (storage_area = 'group') AND (group_id IS NOT NULL) AND is_group_member(group_id)<br>all: owner_user_id = me() |
| `financial_accounts` | on | SIU | SIUD | select: shared_with_group AND (group_id IS NOT NULL) AND is_group_member(group_id)<br>all: user_id = me() |
| `friend_requests` | on | SIU | SIUD | insert: true ⟂ check requester_id = me()<br>select: (requester_id = me()) OR (addressee_id = me())<br>update: (requester_id = me()) OR (addressee_id = me()) ⟂ check true |
| `fx_rates` | on | SIUD | SIUD | delete: user_id = me()<br>select: (user_id IS NULL) OR (user_id = me())<br>update: user_id = me()<br>insert: true ⟂ check (user_id = me()) AND (source = 'manual') |
| `goal_contributions` | on | SIU | SIUD | insert: true ⟂ check (user_id = me()) AND (goal_access(goal_id) = ANY (ARRAY['owner', 'contributor']))<br>select: goal_access(goal_id) IS NOT NULL<br>update: user_id = me() |
| `goal_members` | on | SIUD | SIUD | delete: goal_access(goal_id) = 'owner'<br>insert: true ⟂ check goal_access(goal_id) = 'owner'<br>delete: user_id = me()<br>select: goal_access(goal_id) IS NOT NULL<br>update: (goal_access(goal_id) = 'owner') OR (user_id = me()) |
| `goal_milestones` | on | SIUD | SIUD | select: goal_access(goal_id) IS NOT NULL<br>all: goal_access(goal_id) = 'owner' |
| `goals` | on | SIU | SIUD | insert: true ⟂ check (owner_user_id = me()) AND ((group_id IS NULL) OR is_group_member(group_id))<br>select: (owner_user_id = me()) OR (goal_access(id) IS NOT NULL)<br>update: owner_user_id = me() |
| `group_activity_events` | on | SI | SID | insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_disputes` | on | SIU | SIUD | insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_expense_comments` | on | SIU | SIUD | insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_expense_item_shares` | on | SIUD | SIUD | delete: is_group_member(group_id)<br>insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_expense_items` | on | SIUD | SIUD | delete: is_group_member(group_id)<br>insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_expense_payers` | on | SIUD | SIUD | delete: is_group_member(group_id)<br>insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_expense_revisions` | on | SI | SID | insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_expense_shares` | on | SIUD | SIUD | delete: is_group_member(group_id)<br>insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_expenses` | on | SIU | SIUD | insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `group_invitations` | on | SIU | SIUD | insert: true ⟂ check is_group_member(group_id) AND (invited_by = me())<br>select: is_group_member(group_id) OR (invitee_user_id = me()) OR ((id) = current_setting('redeem_invitation_id', true))<br>update: is_group_member(group_id) OR (invitee_user_id = me()) OR ((id) = current_setting('redeem_invitation_id', true)) ⟂ check true |
| `group_join_requests` | on | SIU | SIUD | insert: true ⟂ check (user_id = me()) AND (status = 'pending')<br>select: (user_id = me()) OR is_group_admin(group_id)<br>update: (user_id = me()) OR is_group_admin(group_id) ⟂ check true |
| `group_members` | on | SIU | SIUD | insert: true ⟂ check is_group_admin(group_id) OR ((user_id = me()) AND (role = 'member') AND (status = 'active') AND ((group_id) = current_setting('join_group_id', true))) OR ((u…<br>select: is_group_member(group_id) OR (user_id = me())<br>update: is_group_admin(group_id) OR (user_id = me()) ⟂ check is_group_admin(group_id) OR ((user_id = me()) AND (role <> 'owner')) OR (user_id = me()) |
| `groups` | on | SIU | SIUD | insert: true ⟂ check created_by = me()<br>select: is_group_member(id) OR (created_by = me())<br>update: is_group_admin(id) |
| `idempotency_keys` | on | SIUD | SIUD | all: user_id = me() |
| `import_batches` | on | SIUD | SIUD | all: user_id = me() |
| `import_rows` | on | SIUD | SIUD | all: user_id = me() |
| `insight_feedback` | on | SIUD | SIUD | all: user_id = me() |
| `insight_mutes` | on | SIUD | SIUD | all: user_id = me() |
| `insights` | on | SIUD | SIUD | all: user_id = me() |
| `integration_connections` | on | SIUD | SIUD | all: user_id = me() |
| `integration_sync_runs` | on | SIUD | SIUD | all: user_id = me() |
| `integration_webhook_events` | on | I | SIUD | insert: true |
| `job_attempts` | on | SIUD | SIUD | none (no API access) |
| `jobs` | on | SIUD | SIUD | update: user_id = me()<br>insert: true ⟂ check user_id = me()<br>select: user_id = me() |
| `login_attempts` | on | SID | SIUD | all: true |
| `merchant_aliases` | on | SIUD | SIUD | all: user_id = me() |
| `merchants` | on | SIUD | SIUD | all: user_id = me() |
| `mfa_factors` | on | SIUD | SIUD | all: user_id = me() |
| `mfa_recovery_codes` | on | SIUD | SIUD | all: user_id = me() |
| `moderation_actions` | on | SIU | SIUD | insert: true ⟂ check (moderator_id = me()) AND (((community_id IS NOT NULL) AND is_community_moderator(community_id)) OR (current_platform_role() = ANY (ARRAY['admin', 'support'])))<br>select: (target_user_id = me()) OR ((community_id IS NOT NULL) AND is_community_moderator(community_id)) OR (current_platform_role() = ANY (ARRAY['admin', 'support']))<br>update: ((community_id IS NOT NULL) AND is_community_moderator(community_id)) OR (current_platform_role() = ANY (ARRAY['admin', 'support'])) ⟂ check true |
| `moderation_appeals` | on | SIU | SIUD | insert: true ⟂ check appellant_id = me()<br>select: (appellant_id = me()) OR ((community_id IS NOT NULL) AND is_community_moderator(community_id)) OR (current_platform_role() = ANY (ARRAY['admin', 'support']))<br>update: ((community_id IS NOT NULL) AND is_community_moderator(community_id)) OR (current_platform_role() = ANY (ARRAY['admin', 'support'])) ⟂ check true |
| `notification_deliveries` | on | SIUD | SIUD | all: user_id = me() |
| `notification_preferences` | on | SIUD | SIUD | all: user_id = me() |
| `notifications` | on | SIUD | SIUD | all: user_id = me() |
| `outbox_events` | on | I | SIUD | insert: true |
| `payment_methods` | on | SIUD | SIUD | all: user_id = me() |
| `profiles` | on | SIUD | SIUD | all: user_id = me()<br>select: can_view_profile(user_id) |
| `push_endpoints` | on | SIUD | SIUD | all: user_id = me() |
| `receipt_extractions` | on | SIUD | SIUD | all: user_id = me() |
| `receipt_files` | on | SIUD | SIUD | all: user_id = me() |
| `receipt_line_items` | on | SIUD | SIUD | all: user_id = me() |
| `receipts` | on | SIUD | SIUD | all: user_id = me() |
| `reconciliation_match_items` | on | SIUD | SIUD | all: user_id = me() |
| `reconciliation_matches` | on | SIUD | SIUD | all: user_id = me() |
| `recurring_occurrences` | on | SIUD | SIUD | delete: (user_id = me()) AND (status = 'scheduled') AND (transaction_id IS NULL)<br>select: (user_id = me()) OR ((group_id IS NOT NULL) AND is_group_member(group_id))<br>update: (user_id = me()) OR ((group_id IS NOT NULL) AND is_group_member(group_id))<br>insert: true ⟂ check user_id = me() |
| `recurring_rules` | on | SIUD | SIUD | delete: user_id = me()<br>insert: true ⟂ check (user_id = me()) AND ((group_id IS NULL) OR is_group_member(group_id))<br>select: (user_id = me()) OR ((group_id IS NOT NULL) AND is_group_member(group_id))<br>update: (user_id = me()) OR ((group_id IS NOT NULL) AND is_group_admin(group_id)) |
| `reports` | on | SIUD | SIUD | delete: user_id = me()<br>insert: true ⟂ check (user_id = me()) AND ((group_id IS NULL) OR is_group_member(group_id))<br>select: user_id = me()<br>update: user_id = me() |
| `saved_filters` | on | SIUD | SIUD | all: user_id = me() |
| `scheduled_reports` | on | SIUD | SIUD | all: user_id = me() |
| `schema_migrations` | **off** | — | — | none (no API access) |
| `search_history` | on | SIUD | SIUD | all: user_id = me() |
| `security_events` | on | SI | SID | insert: true<br>select: user_id = me() |
| `settlements` | on | SIU | SIUD | insert: true ⟂ check is_group_member(group_id)<br>select: is_group_member(group_id)<br>update: is_group_member(group_id) |
| `subscription_detection_candidates` | on | SIUD | SIUD | all: user_id = me() |
| `subscription_events` | on | SI | SID | all: user_id = me() |
| `subscription_payments` | on | SIUD | SIUD | all: user_id = me() ⟂ check (user_id = me()) AND (EXISTS ( SELECT 1 FROM subscriptions s WHERE ((s.id = subscription_payments.subscription_id) AND (s.user_id = me())))) AND (EXISTS ( SE… |
| `subscriptions` | on | SIU | SIUD | insert: true ⟂ check (user_id = me()) AND ((group_id IS NULL) OR is_group_member(group_id))<br>select: (user_id = me()) OR ((group_id IS NOT NULL) AND is_group_member(group_id))<br>update: user_id = me() |
| `support_messages` | on | SI | SIUD | insert: true ⟂ check (author_user_id = me()) AND (EXISTS ( SELECT 1 FROM support_requests r WHERE ((r.id = support_messages.request_id) AND (((support_messages.author_role = 'req…<br>select: EXISTS ( SELECT 1 FROM support_requests r WHERE ((r.id = support_messages.request_id) AND ((r.user_id = me()) OR (current_platform_role() = ANY (ARRAY['admin… |
| `support_requests` | on | SIU | SIUD | insert: true ⟂ check NOT (user_id IS DISTINCT FROM me())<br>select: (user_id = me()) OR (current_platform_role() = ANY (ARRAY['admin', 'support']))<br>update: current_platform_role() = ANY (ARRAY['admin', 'support']) ⟂ check true |
| `tags` | on | SIUD | SIUD | all: user_id = me() |
| `transaction_attachments` | on | SIUD | SIUD | all: user_id = me() |
| `transaction_audit_events` | on | SI | SID | all: user_id = me() |
| `transaction_tags` | on | SIUD | SIUD | all: user_id = me() |
| `transactions` | on | SIU | SIUD | all: user_id = me()<br>select: EXISTS ( SELECT 1 FROM financial_accounts a WHERE ((a.id = transactions.account_id) AND a.shared_with_group AND (a.group_id IS NOT NULL) AND is_group_member(… |
| `transfers` | on | SIU | SIUD | all: user_id = me() |
| `user_blocks` | on | SIUD | SIUD | all: blocker_id = me() |
| `user_connections` | on | SID | SIUD | delete: (user_id = me()) OR (friend_id = me())<br>insert: true ⟂ check (user_id = me()) OR (friend_id = me())<br>select: (user_id = me()) OR (friend_id = me()) |
| `user_consents` | on | SIU | SIUD | all: user_id = me() |
| `user_credentials` | on | SIUD | SIUD | all: user_id = me() |
| `user_mutes` | on | SIUD | SIUD | all: muter_id = me() |
| `user_preferences` | on | SIUD | SIUD | all: user_id = me() |
| `user_session_refresh_history` | on | SIUD | SIUD | all: user_id = me() |
| `user_sessions` | on | SIUD | SIUD | all: user_id = me() |
| `users` | on | SIU | SIUD | insert: true ⟂ check id = me()<br>select: id = me()<br>update: id = me() |
