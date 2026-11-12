# Montra — Disaster Recovery

Planning targets (ADR-025, owner to confirm before launch):

| Target | Value |
|---|---|
| RPO (data loss tolerance) | ≤ 5 minutes for PostgreSQL, using Supabase point-in-time recovery; ≤ 24 h for storage objects |
| RTO (time to restore service) | ≤ 4 hours for a regional or database failure |

## What must be recoverable

| Data | Store | Protection |
|---|---|---|
| All financial, social and account data | Supabase PostgreSQL | PITR + daily backups (owner enables); migrations in git rebuild the schema |
| Receipts, statements, attachments, exports | Appwrite buckets | provider backups or periodic bucket copy (owner configures); metadata and checksums in PostgreSQL |
| Configuration and secrets | host secret stores | owner-held offline copy of the encryption keys (`DATA_ENCRYPTION_KEYS`, `URL_SIGNING_KEY`) |
| Code and contract | git | CI rebuilds every artifact from source |

**Losing `DATA_ENCRYPTION_KEYS` makes the encrypted columns unreadable**:
MFA secrets, push subscriptions, integration tokens and webhook payloads.
Users would then have to re-enrol two-step verification and push. Keep
the keys in two independent secure locations.

## Scenarios

- **Database failure or corruption:** restore with PITR into a new project
  or branch (RUNBOOKS.md, "Backup restore"), verify migration checksums,
  then switch the connection secrets.
- **Region outage:**
  1. Provision Supabase, the Go host and Appwrite in another region.
  2. Restore the latest backup.
  3. Deploy the same image.
  4. Update DNS and the web CSP (owner actions).
- **Storage outage or loss:** the app keeps working without files
  (uploads fail cleanly). Restore buckets from backup. Downloads of
  missing objects fail with a storage error, and the database rows keep
  SHA-256 checksums so restored objects can be verified.
- **Bad deployment:** roll back (RUNBOOKS.md). Migrations are additive.
- **Compromised secrets:** rotate (DEPLOYMENT.md §7). If an encryption key
  is compromised, rotate it and re-encrypt the affected columns (planned
  tooling).

## Drills

- Restore drill before launch, then quarterly: restore PITR into a scratch
  project and run the API smoke tests against it. Record the RPO and RTO
  achieved in the incident log.
- Verify on each drill that the worker resumes cleanly (leases, scheduler
  catch-up) after the restored database comes up.
