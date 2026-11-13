# Montra database (`supabase/`)

`supabase/migrations/*.sql` is the only source of DDL for the PostgreSQL
schema `montra` (113 tables, row-level security on every one). The files
are plain SQL for PostgreSQL 15+ and Supabase, applied in order by the Go
runner `backend/cmd/migrate`. This project does not use the Supabase CLI,
`supabase db push` or the Supabase Data API.

Generated references:

- [`docs/DATA_DICTIONARY.md`](../docs/DATA_DICTIONARY.md): every table,
  column, constraint, index, policy and owning domain, computed from these
  files (`make docs`; CI fails when it is stale);
- [`docs/RLS_POLICY_MATRIX.md`](../docs/RLS_POLICY_MATRIX.md): policies,
  grants and security-definer functions read from a migrated database
  (`scripts/docs/gen_rls_matrix.sh`);
- [`docs/DATA_MODEL.md`](../docs/DATA_MODEL.md): entities, domains and the
  invariants the code relies on.

## Migrations

- **Names.** `YYYYMMDDHHMMSS_description.sql`, lower-case snake case
  (the runner rejects anything else). Start each file with
  `set local search_path = montra, extensions, public;`.
- **One transaction per file.** A file that cannot run in a transaction
  (for example `create index concurrently`) starts with the marker line
  `-- montra:no-transaction`.
- **Forward-only.** The runner records each file's SHA-256 checksum in
  `montra.schema_migrations` and aborts when an applied file changes. Fix
  a mistake with a new migration. Never edit, rename or delete an applied
  one (ADR-004).
- **Additive and backward compatible.** The previous API version must keep
  working on the new schema, because rollback means redeploying the
  previous image, not reverting SQL. Later migrations use idempotent forms
  (`add column if not exists`, `create index if not exists`, policies
  guarded by `if not exists (select … from pg_policies …)`).
- **Serialized.** A PostgreSQL advisory lock serializes concurrent runs.
- **After a change:**
  - `make sqlc` if `backend/internal/store/queries` reads the changed
    tables (sqlc reads this directory as its schema);
  - `make docs` (data dictionary and knowledge graph);
  - `scripts/docs/gen_rls_matrix.sh` after policy or grant changes;
  - an RLS test in `backend/tests/rls` for a new access rule.

## Roles

| Role | Purpose | Notes |
|---|---|---|
| `montra_owner` | owns schema `montra` and every object; runs migrations | never used by the API or worker |
| `montra_app` | API process | `NOBYPASSRLS`; every table's policies apply; identity from `montra.current_user_id()` (transaction-local `montra.user_id`) |
| `montra_worker` | worker process (jobs, scheduler, outbox) | `worker_all` policies (system scope); worker code authorizes explicitly; still cannot modify append-only tables |
| `PUBLIC` | — | no access: `revoke all on schema montra from public`, no table grants, definer functions revoke `PUBLIC` execute |

The roles must exist before the first migration. The foundation migration
checks this and stops otherwise. Locally `scripts/db/bootstrap.sh` creates
them, as login roles with `NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT
NOBYPASSRLS` and `search_path = montra, extensions`. On a hosted project
the owner creates them (see below).

## Row-level security

- The foundation migration defines the building blocks:
  - `apply_owner_rls(table, owner_col)`: `app_owner_all` (rows whose
    owner column is the current user) plus `worker_all`;
  - `apply_worker_rls(table)`: `worker_all` only, with table-specific API
    policies added next to it;
  - `make_append_only(table)`: revokes UPDATE and DELETE from the API
    role.
- Group, community and sharing access goes through `security definer`
  helpers such as `is_group_member` and `is_community_member`, with fixed
  `search_path`. Guard triggers stop self-promotion and similar abuses.
- Default privileges give both runtime roles SELECT, INSERT, UPDATE and
  DELETE on new tables. Migrations then revoke what a role must not do
  (each table's remaining privileges are in the data dictionary).
- `backend/tests/rls` proves the rules:
  - every table has RLS and no PUBLIC access;
  - owner isolation;
  - no identity sees nothing;
  - group boundaries, household sharing;
  - append-only tables;
  - profile visibility and discovery helpers;
  - guard triggers, the write-only webhook inbox and masked payment hints.

## Apply locally

Use the PostgreSQL already installed on the machine (no Docker). Run from
the repository root:

```sh
make db-bootstrap    # roles + montra_dev/montra_test + backend/.env.local (prints the target first)
make migrate         # up on montra_dev
make migrate-status  # applied (with time) or pending per file; flags checksum mismatches
make migrate-test    # up on montra_test
make seed            # optional demo data (demo.*@example.com) through the real services
make db-reset-dev    # DESTRUCTIVE, montra_dev only: drop schema montra and re-migrate (asks for confirmation)
```

`cmd/migrate` prints the target host and database before any change. It
applies to databases whose name ends in `_dev` or `_test` without
confirmation, and to any other database only with `-yes`. `reset` works
only on `_dev`/`_test` databases and needs `-confirm <database name>`. The
integration-test harness resets schema `montra` in the `_test` database on
every run.

## Hosted (Supabase) notes

These are owner actions. Nothing in this repository creates projects,
roles or secrets, or migrates a hosted database. The step-by-step procedure
is in [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md) §1, which also covers
the RLS verification and TLS (`sslmode=verify-full`).

- **Roles.** Create `montra_owner`, `montra_app` and `montra_worker` as
  the project's `postgres` user, with the same attributes as
  `scripts/db/bootstrap.sh` and strong passwords kept in the secret store.
  Give `montra_owner` `CREATE` on the database. Never run the API or
  worker as `postgres`, `service_role`, `anon` or `authenticated`.
- **Extensions.** The schema needs `pg_trgm` in schema `extensions`. On
  Supabase that schema belongs to the platform. Before the first
  migration, enable `pg_trgm` there as `postgres`, and grant
  `montra_owner` `USAGE` on schema `extensions` `WITH GRANT OPTION`,
  because the foundation migration grants that usage to the runtime roles.
  This has not been rehearsed on a hosted project yet. Do a dry run on a
  staging project first.
- **Data API.** Schema `montra` must not be in the Data API's exposed
  schemas. `anon` and `authenticated` have no grants on it, and the
  clients only talk to the Go API.
- **Migrations.** Run `migrate status`, then `migrate up -yes`, from the
  backend image with `DATABASE_MIGRATION_URL` set to the owner role, after
  a backup. Supabase's database is named `postgres`, so `-yes` is always
  required there.
- **Connections.** Use direct or session-mode connections. Behind the
  transaction pooler, set `DATABASE_SIMPLE_PROTOCOL=true`. Always use TLS
  with certificate verification.
- **Backups.** Turn on point-in-time recovery, and rehearse a restore
  before launch ([`docs/DISASTER_RECOVERY.md`](../docs/DISASTER_RECOVERY.md)).

The foundation migration's comments mention `infra/supabase/roles.sql`.
That file does not exist. The hosted role setup is the one described
above and in DEPLOYMENT.md §1.
