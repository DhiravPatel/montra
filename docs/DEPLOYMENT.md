# Montra — Deployment Preparation

Everything here is prepared for a **manual, owner-run** deployment
(spec §15). Nothing in this repository deploys automatically: CI builds
and tests only. The steps below are for the owner. The development agent
does not run deployments, create cloud resources, change DNS, touch
production secrets, run production migrations or publish mobile apps.

## Topology (ADR-011)

| Component | Host | Artifact |
|---|---|---|
| Web portal | Vercel (static build + SPA rewrites) | `web/` with `web/vercel.json` |
| API | Go-capable always-on host (Fly.io, Render, Cloud Run, ECS/Fargate) | container image from `backend/Dockerfile`, command `/usr/local/bin/api` |
| Worker (jobs, scheduler, outbox) | same host, separate always-on process | same image, command `/usr/local/bin/worker` |
| Database | Supabase PostgreSQL (same region as the API) | `supabase/migrations` applied by `/usr/local/bin/migrate` |
| File storage | Appwrite (buckets per area) | — |
| Email / push / AI / FX | SMTP provider; Web Push (VAPID); FCM; Anthropic (optional); ECB (optional) | configuration only |

Recommended region for an India launch: the same region for Supabase and
the Go host (for example Mumbai).

## 1. Database (Supabase)

1. Create the project, and use a dedicated role setup mirroring
   `scripts/db/bootstrap.sh`:
   - `montra_owner` owns the schema and runs migrations;
   - `montra_app` is the API role, with RLS enforced and no BYPASSRLS;
   - `montra_worker` is the worker role.

   Give each role a strong password in the secret store. Do not use the
   Supabase `postgres` or `service_role` credentials at runtime.
2. Connections:
   - Prefer direct or session-mode connections.
   - With the transaction-mode pooler, set `DATABASE_SIMPLE_PROTOCOL=true`.
     Montra sets `montra.user_id` per transaction with `set_config(...,
     true)`, which is transaction-scoped and safe with transaction pooling.
   - Set `DATABASE_MAX_CONNS` to fit the plan.
3. Migrations (owner action, after a backup):
   1. Run `migrate status`, then `migrate up -yes`, from the image with
      `DATABASE_MIGRATION_URL` set to the **owner** role. `-yes` is
      required for any database whose name does not end in `_dev` or
      `_test`, and the command prints the target first.
   2. Migrations are forward-only and additive. Roll back by restoring
      the backup or with a new corrective migration, never by editing an
      applied file (checksums are verified).
4. Turn on point-in-time recovery and daily backups. Run a restore drill
   before launch (docs/RUNBOOKS.md).

## 2. Storage (Appwrite)

Create the buckets `private-user-docs`, `group-docs`, `public-media`,
`temp-processing` and `exports` (names overridable with
`APPWRITE_BUCKET_*`):

- file security on;
- no public read;
- maximum file size equal to or below `STORAGE_MAX_UPLOAD_BYTES`;
- allowed extensions per ADR-010.

Create an API key scoped to those buckets only. The API reaches Appwrite
server-side; clients never talk to Appwrite directly.

## 3. API and worker

Build from the repository root (CI does this on every change; the image
is never pushed by CI):

```sh
docker build -f backend/Dockerfile -t montra-backend:<version> --build-arg APP_VERSION=<version> .
```

Run two services from the same image:

- `api`: listens on `:8080`.
  - Health: `GET /health/live` (liveness) and `GET /health/ready`
    (database and adapters).
  - Metrics: `GET /metrics`, which requires `METRICS_TOKEN`.
- `worker`: no inbound port. Exactly one scheduler leader is elected
  automatically, so several workers are safe.

### Environment

`APP_ENV=production` refuses development adapters (`local_disk`,
`dev_mailbox`), insecure cookies, `*` CORS, the development
email-verification bypass (`AUTH_DEV_AUTO_VERIFY_EMAIL`) and
`AUTH_REQUIRE_EMAIL_VERIFIED=false`. Missing required secrets fail
start-up.

| Variable | Required | Notes |
|---|---|---|
| `APP_ENV` | yes | `production` (or `staging`) |
| `DATABASE_URL` | yes | `montra_app` role (API; worker for user-scoped reads) |
| `WORKER_DATABASE_URL` | worker | `montra_worker` role |
| `DATABASE_MIGRATION_URL` | migrate only | `montra_owner` role; never given to the API or worker services |
| `DATA_ENCRYPTION_KEYS` | yes | `kid:base64(32 bytes)[,kid2:...]`; the first key encrypts, all keys decrypt |
| `URL_SIGNING_KEY` | yes | base64 of 32 bytes (signed file URLs, unsubscribe tokens) |
| `PUBLIC_API_BASE_URL`, `WEB_APP_URL` | yes | public origins (email links, OAuth redirects) |
| `CORS_ALLOWED_ORIGINS` | yes | the web origin(s) |
| `AUTH_COOKIE_DOMAIN` | if the API and web share a parent domain | cookies stay `Secure`, `HttpOnly`, SameSite |
| `HTTP_TRUST_PROXY_HEADERS` | per host | `true` only behind a trusted proxy that sets `X-Forwarded-For` |
| `STORAGE_PROVIDER=appwrite`, `APPWRITE_ENDPOINT` (https), `APPWRITE_PROJECT_ID`, `APPWRITE_API_KEY` | yes | — |
| `EMAIL_PROVIDER=smtp`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `EMAIL_FROM` | yes | STARTTLS required |
| `SUPPORT_EMAIL`, `SECURITY_EMAIL`, `STATUS_PAGE_URL` | yes | shown to users |
| `METRICS_TOKEN` | yes | protects `/metrics` |
| `TURNSTILE_SECRET_KEY` | recommended | captcha on registration, sign-in and password-reset requests |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` | optional | Web Push (docs/OPERATIONS.md) |
| `FCM_PROJECT_ID`, `FCM_CREDENTIALS_FILE` | optional | native push; mount the service-account JSON as a secret file |
| `AI_PROVIDER=anthropic`, `ANTHROPIC_API_KEY`, `AI_MODEL` | optional | off by default |
| `FX_PROVIDER=ecb` | optional | daily reference rates |
| `WEBHOOK_SECRETS` | when a provider is enabled | per-provider webhook secrets |
| `RETENTION_*` | optional | ADR-021 windows (AI history, raw import rows, temp files, exports, security events, deletion grace) |
| `LOG_LEVEL`, `LOG_FORMAT` | optional | `info`, `json` |

All other settings (timeouts, TTLs, limits, worker concurrency) have safe
defaults in `backend/internal/platform/config/config.go`.

## 4. Web portal (Vercel)

1. Import the repository with root directory `web/`. `vercel.json` sets
   the install and build commands, the SPA rewrites and the security
   headers.
2. **Before the first deploy**, edit the `connect-src` entry of the
   Content-Security-Policy in `web/vercel.json`: replace
   `https://api.montra.example` with the real API origin.
3. Set `VITE_API_BASE_URL` to the API base, for example
   `https://api.<domain>/api/v1`. The default `/api/v1` assumes a
   same-origin proxy.
4. Set `VITE_SUPPORT_EMAIL` and `VITE_SECURITY_EMAIL`.
5. Deploy from the Vercel dashboard or with the owner's own CLI session.
   This repository never runs `vercel deploy`.

## 5. Mobile apps

- Build with `--dart-define=API_BASE_URL=https://api.<domain>/api/v1`.
  Release builds refuse non-https or missing URLs.
- The owner signs releases with their own keystore and Apple
  certificates, stored outside the repository. `.gitignore` excludes
  key files.
- FCM requires the owner's `google-services.json` and
  `GoogleService-Info.plist` (git-ignored).
- Store listings must state that Montra does not read SMS or
  notifications and never asks for bank credentials.

## 6. Release checklist

1. CI green on the release commit: backend (gofmt, vet, lint, sqlc,
   contract drift, unit with `-race`, integration/RLS/API, fuzz,
   govulncheck, binaries, image), web (typecheck, lint, test, build,
   audit) and mobile (analyze, test), plus the `e2e` workflow: Playwright
   journeys (`web-e2e`) and on-emulator Flutter journeys (`mobile-e2e`)
   against a throwaway API, worker and PostgreSQL started inside the job
   (docs/TESTING.md, "End-to-end tests"). These jobs never deploy and use
   no repository secrets.
2. Back up the database, then run `migrate status` and `migrate up -yes`.
3. Deploy the worker and API images. Check `/health/ready` and confirm
   the worker log shows scheduler leadership.
4. Deploy the web portal. Smoke test: sign up, verify, sign in, add an
   account and a transaction, export.
5. Roll back by redeploying the previous image or web build. Migrations
   are additive, so the previous version keeps working.

## 7. Secret rotation

- **`DATA_ENCRYPTION_KEYS`:** prepend a new key. New writes use it, and
  old rows decrypt with the old key. Remove the old key only after
  re-encryption, which is planned operations tooling.
- **`URL_SIGNING_KEY`:** rotation invalidates outstanding signed file
  URLs (5 min) and email unsubscribe links (60 days).
- **VAPID keys:** rotation invalidates browser push subscriptions; clients
  re-subscribe.
- **Database role passwords, SMTP, Appwrite, AI and FCM credentials:**
  rotate in the provider, update the secret store, restart the services.
