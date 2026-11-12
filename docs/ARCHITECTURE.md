# Montra — Architecture

Authoritative product requirements: `Montra_Full_Feature_Production_Spec.md`.
Decisions referenced as ADR-nnn live in `docs/DECISIONS.md`.

## 1. System context

```mermaid
flowchart LR
  subgraph Clients
    M[Flutter app<br/>Android / iOS]
    W[React portal<br/>browser]
  end
  subgraph Vercel
    WS[Static web build<br/>+ SPA rewrites]
  end
  subgraph GoRuntime[Go-compatible runtime]
    API[Go API<br/>/api/v1]
    WK[Go worker<br/>jobs + scheduler]
  end
  DB[(Supabase PostgreSQL<br/>schema montra, RLS)]
  AW[(Appwrite Storage<br/>private buckets)]
  AI[Anthropic Claude<br/>consent-gated]
  EM[SMTP relay]
  PU[Web Push / FCM]
  FX[ECB reference rates<br/>optional]
  BP[Bank/AA providers<br/>disabled pending review]

  W -->|HTTPS, cookies + CSRF| WS
  W -->|HTTPS /api/v1| API
  M -->|HTTPS /api/v1, bearer| API
  API --> DB
  WK --> DB
  API --> AW
  WK --> AW
  WK --> AI
  API --> AI
  WK --> EM
  WK --> PU
  WK --> FX
  WK -.-> BP
```

Clients never connect to Supabase or Appwrite directly and never hold
privileged credentials. The Go backend is the sole owner of business rules,
authorization, money arithmetic, integrations, audit and job orchestration
(spec §1.1, §1.4).

## 2. Repository layout (ADR-001)

```text
backend/            Go module `montra/backend`
  cmd/api           HTTP API server
  cmd/worker        durable job worker + scheduler leader
  cmd/migrate       forward-only migration runner (ADR-004)
  cmd/openapi       exports the OpenAPI contract (+ `-check` drift mode)
  internal/
    platform/       config, logging, errors, httpx, database, jobs, outbox,
                    ratelimit, crypto, observability, storage, email, push
    domain/         pure packages: money, currency, split, ledger, period,
                    recurrence, budgetcalc, subdetect, settlement, statement
                    (file parsing/normalization), reconcile (fx and forecast
                    arrive with their phases)
    <feature>/      application services + repositories + HTTP registration:
                    auth, users, files, notifications, privacy, finance
                    (accounts, transactions, transfers, categories, tags,
                    merchants), analytics, budgets, recurring (rules,
                    occurrences, bills, calendar), subscriptions, goals,
                    imports, receipts, reconciliation
supabase/
  migrations/       YYYYMMDDHHMMSS_*.sql (PostgreSQL 15+ compatible)
  seeds/            deterministic synthetic dev/test seed data
  tests/            SQL-level RLS checks (run by Go integration tests)
storage/appwrite/   bucket definitions + permission conventions
contracts/openapi/  montra.v1.json (generated, committed, drift-checked)
web/                React + TypeScript portal (Vite); `pnpm gen:api` types
mobile/             Flutter application; `tool/gen_api.dart` models
infra/              Dockerfile, deployment templates (no secrets)
scripts/            bootstrap-db, dev, test helpers
docs/               all project documentation
.github/workflows/  CI (validate only, never deploy)
```

## 3. Backend layering

1. **Transport** — chi router, Huma operations (schema validation, OpenAPI).
2. **Authentication middleware** — resolves bearer token or session cookie
   to a session row; enforces CSRF for cookie-authenticated unsafe methods.
3. **Authorization** — explicit per-resource checks in services (owner,
   group role, community role); RLS as defense in depth.
4. **Application services** — use cases; own transaction boundaries,
   idempotency, audit and outbox events.
5. **Domain logic** — pure Go packages under `internal/domain`, no HTTP,
   SQL or UI imports; exhaustively unit/fuzz tested.
6. **Repositories** — parameterized SQL via pgx, always inside
   `database.WithUserTx` (sets `montra.user_id`) or `WithSystemTx` (worker).
7. **Integration adapters** — storage, email, push, AI, FX, OCR, providers;
   each behind an interface with timeouts and error classification.
8. **Durable jobs** — PostgreSQL queue (ADR-008).
9. **Observability** — slog JSON logs with request/job IDs and redaction,
   Prometheus metrics, optional OpenTelemetry traces.

## 4. Data flow: committed write → side effects

```mermaid
sequenceDiagram
  participant C as Client
  participant A as API service
  participant D as PostgreSQL
  participant W as Worker
  C->>A: POST /transactions (Idempotency-Key)
  A->>D: BEGIN; set montra.user_id
  A->>D: check idempotency key / version
  A->>D: insert transaction + ledger entries + audit + outbox
  A->>D: COMMIT
  A-->>C: 201 {data, meta}
  W->>D: claim outbox events (SKIP LOCKED)
  W->>D: enqueue jobs (budget evaluation, anomaly, notifications)
  W->>D: process job, record attempt, dedupe notification
```

## 5. Identity and sessions (ADR-002)

- Web: HttpOnly cookies + double-submit CSRF. Mobile: bearer access token
  in memory, refresh token in secure storage.
- Each request: hash token → `user_sessions` lookup (active, not expired,
  not revoked) → user status check (active, not deletion-locked).
- RLS propagation: `set_config('montra.user_id', <uuid>, true)` per
  transaction.

## 6. Storage (ADR-009/010)

Upload intent → backend-hosted single-use upload URL → content validation
(size, magic bytes, extension allow-list, checksum, image dimension limits,
EXIF stripping for previews) → storage adapter (`appwrite` in hosted
environments, `local_disk` in development only) → `files` metadata commit
→ processing job. Downloads: per-request authorization → short-lived signed
URL → streamed response with `Content-Disposition: attachment` and
`X-Content-Type-Options: nosniff`.

## 7. Jobs and scheduling (ADR-008)

Job classes and objectives are inventoried in `docs/BACKGROUND_JOBS.md`.
The scheduler enqueues time-bucketed periodic jobs with dedupe keys:
`recurring.generate` (15 min: materialize, auto-post, auto-add recurring
shared bills through the groups hook (ADR-040), overdue, bill and recurring
reminders), `subscriptions.renewals` (hourly), 
`subscriptions.detect_all` (daily fan-out to `subscriptions.detect`),
`goals.reminders` (6 h), `privacy.deletion_due`, `files.cleanup`,
`retention.cleanup`, `notifications.digest_scan` (hourly; digests at
08:00 local, ADR-047), `integrations.schedule` (30 min: abandoned-run
recovery, consent expiry, scheduled syncs, stale webhook re-queue,
ADR-048), `insights.generate_all` (daily). Request-driven jobs: `imports.parse`,
`imports.normalize`, `imports.process`, `imports.rollback`,
`receipts.extract`, `subscriptions.detect`, `notifications.deliver`
(per channel), `notifications.digest_send`, `integrations.sync` (one run;
cursor pages), `integrations.webhook` (queued for verified webhook events
through a definer helper). Outbox events drive per-change jobs
(`budgets.evaluate`, `goals.evaluate`, `goals.notify_member`,
`social.notify_friend_request`, `groups.notify_activity`,
`groups.join_requested`, `groups.sync_expense`, `groups.sync_settlement`,
`communities.notify_comment`, `communities.notify_membership`,
`moderation.reported` (moderator notice + auto-hide), `moderation.actioned`,
`challenges.notify_completed`).
Group activity fans out to members by notification level (ADR-039); edits
by one member to records linked to another member's personal ledger are
applied by the worker as `system` (ADR-036). Recurring
generation is idempotent through a unique `(rule_id, occurrence_date)`
constraint, a locked posting step and a unique occurrence→transaction
link (ADR-026). Notifications addressed to other users are created only
by worker jobs (owner-only RLS on `notifications`, ADR-028).

## 8. Deployment topology (ADR-011)

- **Web:** Vercel static hosting; `web/vercel.json` with SPA rewrites and
  security headers. `VITE_API_BASE_URL` points to the Go API.
- **API + worker:** one container image (`backend/Dockerfile`), two process
  types (`api`, `worker`), at least one worker instance always on.
- **Database:** Supabase PostgreSQL; migrations run manually by the owner
  with `cmd/migrate` against the hosted connection string.
- **Storage:** Appwrite buckets created by the owner per
  the buckets listed in `docs/DEPLOYMENT.md` §2 (names configured in `backend/internal/platform/config/config.go`).
- **Mobile:** store builds via Android/iOS release processes (not Vercel).

No deployment is performed by the implementation agent (spec §15).

## 9. Local development topology

| Component | Address | Notes |
|---|---|---|
| PostgreSQL 18.3 (existing Homebrew service) | `localhost:5432` | databases `montra_dev`, `montra_test` |
| Go API | `http://localhost:8080` | `/api/v1`, `/health/live`, `/health/ready`, `/metrics` |
| Go worker | — | same database, scheduler leader via advisory lock |
| React portal | `http://localhost:5173` | Vite dev server, `/api` proxied to `:8080` |
| Flutter | emulator/device | Android emulator uses `http://10.0.2.2:8080` |
| Storage | `.data/storage/` | `local_disk` dev adapter, never Appwrite |
| Email | `.data/mail/*.eml` | `dev_mailbox` adapter |

Startup order: database bootstrap → migrate → seed (optional) → API →
worker → web/mobile.
