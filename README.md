# Montra

Montra is a free personal-finance product: accounts and transactions,
budgets, bills, subscriptions, goals, receipts and statement imports,
reports, shared groups and settlements, communities and challenges, and an
optional AI assistant. It ships as a web portal and Android/iOS apps. All
business logic lives in one Go API.

Every feature is free, with no premium tiers or paywalls. Montra never asks
for bank passwords, UPI PINs, OTPs or CVVs, and never reads SMS.

The authoritative product specification is
`Montra_Full_Feature_Production_Spec.md`. Progress is tracked in
[`docs/IMPLEMENTATION_STATUS.md`](docs/IMPLEMENTATION_STATUS.md).

## Repository

| Path | What |
|---|---|
| `backend/` | Go 1.26 API (`cmd/api`), worker (`cmd/worker`: jobs, scheduler, outbox), migrator (`cmd/migrate`), OpenAPI exporter (`cmd/openapi`). Huma v2 on chi, pgx v5 + sqlc |
| `supabase/migrations/` | PostgreSQL schema (`montra`), with row-level security on every table |
| `contracts/openapi/montra.v1.json` | The API contract, generated from the Go code and checked in CI |
| `web/` | React 19 + strict TypeScript portal (Vite, TanStack Query, openapi-fetch), prepared for manual Vercel deployment |
| `mobile/` | Flutter app (Riverpod, go_router, dio) for Android and iOS |
| `scripts/` | Local database bootstrap and documentation generators |
| `docs/` | Architecture, decisions, security, privacy, operations and status |

## Local development

Prerequisites: an existing local PostgreSQL (Docker is not needed),
Go 1.26, Node 22 + pnpm 10, and Flutter. See
[`docs/OPERATIONS.md`](docs/OPERATIONS.md) for the verified versions.

```sh
make db-bootstrap   # creates Montra roles + montra_dev/montra_test on your existing PostgreSQL (prints the target first)
make migrate        # applies migrations to montra_dev
make seed           # optional synthetic data
make api            # Go API on :8080
make worker         # jobs, scheduler, outbox (second terminal)
make web            # web portal on :5173 (proxies /api to :8080)
make mobile         # Flutter app (Android emulator reaches the API at 10.0.2.2)
```

Local development uses only local adapters:

- files on disk;
- emails written to `.data/mail`;
- push, AI and bank integrations off.

Nothing contacts Appwrite or other cloud services.

## Checks

```sh
make check              # everything CI runs
make test-integration   # Go integration, RLS and API tests against montra_test (sequential)
make lint               # golangci-lint
make contract-check     # contract matches the Go API
```

`make help` lists every target.

## Documentation

| Topic | Document |
|---|---|
| Status and next steps | [IMPLEMENTATION_STATUS](docs/IMPLEMENTATION_STATUS.md), [IMPLEMENTATION_PLAN](docs/IMPLEMENTATION_PLAN.md), [REQUIREMENTS_TRACEABILITY](docs/REQUIREMENTS_TRACEABILITY.md) |
| Design | [ARCHITECTURE](docs/ARCHITECTURE.md), [DECISIONS](docs/DECISIONS.md) (ADRs), [DATA_MODEL](docs/DATA_MODEL.md), [API](docs/API.md), [METRICS](docs/METRICS.md), [BACKGROUND_JOBS](docs/BACKGROUND_JOBS.md) |
| Security and privacy | [SECURITY](docs/SECURITY.md), [THREAT_MODEL](docs/THREAT_MODEL.md), [AUTHORIZATION_MATRIX](docs/AUTHORIZATION_MATRIX.md), [RLS_POLICY_MATRIX](docs/RLS_POLICY_MATRIX.md), [PRIVACY](docs/PRIVACY.md) |
| Running it | [OPERATIONS](docs/OPERATIONS.md), [DEPLOYMENT](docs/DEPLOYMENT.md), [RUNBOOKS](docs/RUNBOOKS.md), [TESTING](docs/TESTING.md) |

## Deployment

Deployment is manual and owner-run ([`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)).
CI builds and tests only. It never deploys, publishes apps or touches
production data.
