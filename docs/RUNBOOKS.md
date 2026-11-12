# Montra — Runbooks

Incident procedures for the owner's on-call (spec §13). Signals come from:

- `/health/live` and `/health/ready`;
- Prometheus metrics (`/metrics`): HTTP, jobs, notifications, AI;
- structured logs, which carry request IDs and never contain personal
  values.

Run SQL as the **worker or owner role**, read-only unless a step says
otherwise. Take a backup before any write.

## General

1. Acknowledge. Note the start time and the request IDs from user reports.
2. Check `/health/ready`: it reports the database, storage, email, AI and
   environment. Then check the error-rate and latency dashboards.
3. Contain first (scale, disable a feature flag or provider), then
   diagnose.
4. Write the incident record (timeline, impact, user data affected yes or
   no, follow-ups). Privacy incidents follow their own section.

## API or database outage

- **Signals:** `/health/ready` shows `database` failing; 5xx rate up;
  `SERVICE_UNAVAILABLE` responses.
- **Actions:**
  1. Check the Supabase status and the project's connection count.
  2. Restart the API instances if they hold broken connections; pgx
     reconnects on its own.
  3. If the database is down, the clients show offline or error states
     and do not lose committed data. Wait for Supabase recovery, or
     restore (see "Backup restore").
- **After:** confirm the worker resumed. Leases recover running jobs and
  the scheduler catches up missed buckets.

## Supabase connection exhaustion

- **Signals:** "too many connections" or pool timeouts in logs; latency
  spike.
- **Actions:**
  1. Lower `DATABASE_MAX_CONNS` per instance, or the instance count.
  2. Move to the session or transaction pooler
     (`DATABASE_SIMPLE_PROTOCOL=true` for transaction mode).
  3. Check `pg_stat_activity` for long transactions: statement timeout
     is 15 s, and jobs hold no long transactions by design.

## Appwrite outage

- **Signals:** `STORAGE_UNAVAILABLE` errors; uploads, receipts, exports
  and reports failing.
- **Actions:**
  1. Nothing else is affected. Financial data stays in PostgreSQL.
  2. Uploads fail cleanly. Abandoned uploads are rejected after 24 h.
  3. File-deletion jobs retry with backoff.
- **After:** check `files` rows stuck in `deleting` (cleanup retries
  hourly) and re-run failed report or export jobs (`jobs.Retry`).

## Queue backlog or worker crash

- **Signals:** `montra_job_queue_depth{status="queued"}` growing; no
  "scheduler leadership acquired" log; notifications or imports delayed.
- **Actions:**
  1. Restart or scale the worker. Leases re-queue jobs held by dead
     workers, and only one scheduler leader runs.
  2. Find hot types:
     `select type, status, count(*) from jobs group by 1,2 order by 3 desc`.
  3. Dead jobs: `select type, last_error_code, count(*) from jobs where
     status = 'dead' group by 1,2`. Fix the cause, then re-queue with
     `jobs.Retry`.
  4. Integration runs stuck more than 2 h are failed automatically by
     `integrations.schedule`.

## AI provider outage

- **Signals:** AI errors in metrics; `PROVIDER_UNAVAILABLE`.
- **Actions:** none are required. Ask and summaries fall back to the
  deterministic answer, and receipt extraction stays manual. To stop
  calls entirely, set `AI_PROVIDER=disabled` and restart. Review cost in
  `ai_usage`.

## Bank or integration provider outage (when a provider is enabled)

- **Signals:** `integration_sync_runs` with `failed` or `partial` and
  `provider_error`; connections in `failed`.
- **Actions:**
  1. Syncs retry through jobs with backoff, and scheduled syncs resume
     every 6 h.
  2. To stop a misbehaving provider, unregister its adapter (remove its
     credentials and restart). Connections then show as unavailable.
  3. Users keep manual entry and imports.

## Webhook incident (forged or replayed events, floods)

- **Signals:** `quarantined` rows climbing in
  `integration_webhook_events`; 401 spikes on `/webhooks/{provider}`.
- **Actions:**
  1. Quarantined events change nothing.
  2. If the signing secret may have leaked, rotate it with the provider
     and in `WEBHOOK_SECRETS`, and restart.
  3. Block abusive IPs at the edge.
  4. Verified events for unknown or revoked connections are `ignored`.

## Data corruption (wrong balances or duplicates)

- **Signals:** user reports; reconciliation mismatches.
- **Actions:**
  1. Do not edit rows by hand. Balances come from
     `account_ledger_entries` and audit trails show every change
     (`transaction_audit_events`).
  2. Find the cause through request IDs and audit entries.
  3. Fix through the API, which voids, restores or corrects with
     reversing entries. Or write a one-off, reviewed migration with a
     backup taken first.
  4. Duplicate creates are prevented by idempotency keys and unique keys.
     Investigate any duplicate as a bug.

## Account takeover

- **Signals:** user report; security events (new sign-ins, password or
  two-step changes) from unusual places.
- **Actions:**
  1. Verify the requester's identity through the support channel.
  2. Revoke all of the user's sessions
     (`update user_sessions set revoked_at = now(), revoked_reason =
     'support' where user_id = $1 and revoked_at is null`), or have the
     user use "sign out everywhere".
  3. Force a password reset.
  4. Review `security_events` and the audit trail for changes made by
     the attacker.
  5. Revert those changes through the API.

## Privacy incident (suspected data exposure)

1. Contain: disable the affected endpoint or feature (deploy a fix, or
   restrict at the edge).
2. Preserve evidence: logs (no personal values), audit and security
   events, and the deployment version.
3. Assess scope: which users, which data categories (docs/PRIVACY.md).
4. Get legal review for notification duties (for example the DPDP Act
   2023 in India). Notify affected users and authorities as required.
5. Add a regression test (RLS or API) before closing.

## Failed account deletion

- **Signals:** `account_deletion_requests` stuck in `processing`;
  `privacy.delete_account` jobs dead (`deletion_step_*` or
  `deletion_files` codes).
- **Actions:**
  1. Fix the cause. Storage outages are the usual one.
  2. Re-queue the job. Steps are idempotent: access is blocked first,
     and later steps re-run safely.
  3. Never mark a request completed by hand.

## Backup restore

1. Prefer point-in-time recovery into a **new** Supabase project or
   branch. Never overwrite production in place.
2. Run `migrate status` against the restored copy and verify the
   checksums.
3. Point a staging API and worker at it. Smoke test, and check row counts
   for key tables.
4. Switch production by changing the connection secrets, after approval.
5. **Drill:** before launch and then quarterly. Record the restore time.

## Deployment rollback

- **API or worker:** redeploy the previous image tag. Migrations are
  additive, so the previous version runs on the newer schema.
- **Web:** promote the previous Vercel deployment.
- **Mobile:** halt the staged rollout in the store consoles. Server
  changes stay backward compatible with the previous app version.

## Secret rotation

Follow docs/DEPLOYMENT.md §7. After rotating, check `/health/ready`,
sign-in, a file download (signed URLs), push delivery (if configured) and
AI (if configured).
