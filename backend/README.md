# Montra backend (Go)

One Go module, `montra/backend` (Go 1.26), builds the API, the worker and
the tools around them. All business logic lives here. The web and mobile
clients talk to it only through the OpenAPI contract in
[`contracts/`](../contracts/README.md).

Stack:

- Huma v2 operations on chi;
- pgx v5 against PostgreSQL schema `montra` (sqlc for the auth and users
  queries, hand-written parameterized SQL elsewhere);
- Prometheus metrics and `slog` JSON logs.

## Layout

```text
cmd/
  api/        HTTP API server (:8080 by default)
  worker/     durable jobs, scheduler (leader-elected), outbox relay
  migrate/    forward-only migration runner: up | status | seed | reset
  openapi/    exports the contract; -check is the CI drift check
  seed/       deterministic demo data through the real services (dev/test only)
  loadtest/   local load test (refuses non-local targets)
internal/
  app/        composition root: builds services, routes, middleware, job handlers
  platform/   infrastructure: config, database, httpx, apperr, audit, outbox,
              jobs, idempotency, identity, ratelimit, caps, crypto, storage,
              email, logging, observability, breaker, migrate
  domain/     pure logic, no I/O: money, currency, ledger, period, recurrence,
              split, settlement, budgetcalc, subdetect, reconcile, statement,
              textsafe
  apitypes/   shared API value types (money as exact decimal strings)
  store/      sqlc: queries/*.sql in, db/ generated (do not edit db/)
  <feature>/  one package per feature: service, repository SQL, HTTP
              registration (http.go) and job handlers
  testutil/   dbtest (test database) and apitest (in-process API server)
  seed/       the demo data set used by cmd/seed
tests/
  rls/        row-level-security tests (connect as montra_app / montra_worker)
  api/        HTTP-level integration tests through apitest
```

The feature packages are admin, ai, analytics, auth, budgets, categories,
challenges, communities, fairuse, files, finance, fx, goals, groups,
imports, insights, integrations, moderation, notifications, privacy,
receipts, reconciliation, recurring, reports, search, social,
subscriptions, support and users.
[`docs/FEATURES.md`](../docs/FEATURES.md) explains each one end to end, and
[`docs/KNOWLEDGE_GRAPH.md`](../docs/KNOWLEDGE_GRAPH.md) maps packages to
operations, tables and jobs.

### Dependency rules

The rules are enforced by depguard in [`.golangci.yml`](.golangci.yml)
(ARCH-004; table in
[`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md#enforced-dependency-boundaries-arch-004)):

- `domain/*` imports only other domain packages. It never imports
  platform, store, feature packages, `net/http`, pgx or Huma.
- `platform/*` imports only platform. `apitypes` imports only domain.
  `store/*` imports nothing internal.
- A feature imports platform, domain, apitypes, store, its own
  subpackages and the cross-feature edges listed for it in
  `.golangci.yml` (mostly `finance` and `notifications`). A new edge is a
  design decision: add it in the same change, with a reason.
- `internal/app` is imported only by `cmd/*`, `internal/testutil` and
  `internal/seed`. `package main` exists only under `cmd/`
  (`make lint` checks this).

## Run

Prerequisites: a local PostgreSQL 15+ (no Docker), Go 1.26, and the
`montra_*` roles and databases from `make db-bootstrap`. Run the commands
from the repository root:

```sh
make db-bootstrap   # roles montra_owner/app/worker, databases montra_dev + montra_test, backend/.env.local
make migrate        # apply supabase/migrations to montra_dev (prints the target first)
make seed           # optional demo users demo.*@example.com (development/test only, idempotent)
make api            # API on :8080; docs at /api/v1/docs when HTTP_ENABLE_DOCS=true
make worker         # jobs, scheduler and outbox relay (second terminal)
```

Health endpoints:

- `GET /health/live`;
- `GET /health/ready` (database and adapters);
- `GET /metrics`, which requires `METRICS_TOKEN` when it is set.

The worker has no HTTP API. It serves metrics on `WORKER_METRICS_ADDR`
when that is set.

## Test

```sh
make test-backend       # unit tests: go test ./internal/... (no database)
make test-integration   # integration, RLS and API tests against montra_test, sequential (-p 1)
make fuzz               # short fuzz runs (money, split)
make lint               # go vet + golangci-lint (incl. depguard boundaries)
make vuln               # govulncheck
make load-test          # local load test against the running dev API (never production)
```

The integration harness (`internal/testutil/dbtest`) only accepts a
database whose name ends in `_test` (`TEST_DATABASE_*` in
`.env.local`). On every run it **drops and recreates schema `montra`**
there and applies all migrations from empty. Never point it at a database
whose data you need. `tests/api` starts the real API in process
(`apitest.New`) and calls it over HTTP.
[`docs/TESTING.md`](../docs/TESTING.md) lists the suites and the
per-feature release gate.

## Configuration

Configuration comes only from environment variables. In development,
`backend/.env.local` is loaded (git-ignored, written by
`scripts/db/bootstrap.sh`). [`.env.example`](.env.example) documents every
variable with placeholders only. `internal/platform/config/config.go` holds
the defaults and the validation.

Outside development, `APP_ENV=staging|production` refuses development
adapters, insecure cookies, wildcard CORS and the verification bypass, and
missing required secrets stop start-up.

Each process uses its own database role:

| Variable | Role | Used by |
|---|---|---|
| `DATABASE_URL` | `montra_app` (RLS enforced) | API; worker user-scoped reads |
| `WORKER_DATABASE_URL` | `montra_worker` | worker |
| `DATABASE_MIGRATION_URL` | `montra_owner` | `cmd/migrate` only, never the API or worker |

Hosted connections must use TLS. See the hosted connection guidance (TLS
and `sslmode`) in [`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md).

## Conventions

- **Transactions and identity.** Every API query runs in
  `database.WithUserTx` or `WithUserReadTx`. These set
  `montra.user_id` for row-level security, transaction-local, so they are
  safe behind a transaction pooler. The worker uses `WithSystemTx`.
  Services authorize explicitly; RLS is defence in depth
  ([`docs/RLS_POLICY_MATRIX.md`](../docs/RLS_POLICY_MATRIX.md)).
- **Money** is `amount_minor` (int64) plus an ISO 4217 currency. The API
  exchanges exact decimal strings (`domain/money`, `apitypes`). No floats.
- **Errors** go through `platform/apperr`. Domain rule violations use
  `apperr.Rule(code, …)` (422) and state conflicts use
  `apperr.ConflictCode(code, …)` (409). The code tables in
  [`docs/API.md`](../docs/API.md) are generated from them (`make docs`).
- **Writes** that create financial records take an `Idempotency-Key`
  (`platform/idempotency`). Editable rows carry `version`, and a mismatch
  returns `VERSION_CONFLICT`. Side effects go through the transactional
  outbox and durable jobs (`platform/outbox`, `platform/jobs`;
  [`docs/BACKGROUND_JOBS.md`](../docs/BACKGROUND_JOBS.md)). Sensitive
  changes write `audit_events`.
- **Operations** are registered in each feature's `http.go` with
  `httpx.Protected`/`httpx.Op`, including the rate-limit class and tags.
  The contract is generated from them. After changing one, run
  `make contract` and commit `contracts/openapi/montra.v1.json`.
- **Schema changes** are new files in `supabase/migrations`, never edits
  to applied ones ([`supabase/README.md`](../supabase/README.md)). After
  one, run `make sqlc` if `store/queries` is affected, then `make docs`
  (data dictionary, knowledge graph).
- **Logs** never contain personal values (`TestLogsNeverContainPersonalValues`).
  Notification texts never contain amounts.
- `gofmt` and golangci-lint must be clean (CI).

## Build and deploy

`make build-backend` builds `bin/api`, `bin/worker` and `bin/migrate`.
[`Dockerfile`](Dockerfile) builds one distroless image with all three
binaries plus the migrations. Build it from the repository root:

```sh
docker build -f backend/Dockerfile -t montra-backend:<version> --build-arg APP_VERSION=<version> .
```

CI builds the image but never pushes or deploys it. Deployment is manual
and owner-run ([`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md)).

## Links

- [ARCHITECTURE](../docs/ARCHITECTURE.md), [DECISIONS](../docs/DECISIONS.md)
  (ADRs), [API](../docs/API.md)
- [DATA_MODEL](../docs/DATA_MODEL.md), [DATA_DICTIONARY](../docs/DATA_DICTIONARY.md),
  [QUERY_PLAN_REVIEW](../docs/QUERY_PLAN_REVIEW.md)
- [SECURITY](../docs/SECURITY.md), [AUTHORIZATION_MATRIX](../docs/AUTHORIZATION_MATRIX.md),
  [RLS_POLICY_MATRIX](../docs/RLS_POLICY_MATRIX.md)
- [OPERATIONS](../docs/OPERATIONS.md), [RUNBOOKS](../docs/RUNBOOKS.md),
  [DEPLOYMENT](../docs/DEPLOYMENT.md)
