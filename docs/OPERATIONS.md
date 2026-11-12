# Montra — Operations

## Local development

### Prerequisites (verified 2026-11-04)

Go 1.26+, Node 22 + pnpm 10, Flutter 3.47+, PostgreSQL server already
running locally (this machine: Homebrew `postgresql@18`, `localhost:5432`).
Add `~/go/bin` to `PATH` for `golangci-lint` and `air`, or use the Makefile,
which references the tools by absolute path when they are not on `PATH`.

### First-time setup

```sh
make db-bootstrap   # prints target server, creates montra roles + databases (idempotent)
make migrate        # applies supabase/migrations to montra_dev
make seed           # optional synthetic data
make api            # Go API on :8080
make worker         # Go worker (jobs + scheduler)
make web            # React portal on :5173
make mobile         # flutter run (choose device)
```

`scripts/db/bootstrap.sh` connects as the local superuser **only** to
create `montra_owner`, `montra_app`, `montra_worker`, `montra_dev` and
`montra_test`. It prints the host/port/database names before acting, never
drops anything, and writes generated passwords to the git-ignored
`backend/.env.local`.

### Ports

| Service | Port |
|---|---|
| PostgreSQL | 5432 (existing) |
| Go API | 8080 |
| Vite dev server | 5173 |

### Local email and verification

- **No real email locally:** `EMAIL_PROVIDER=dev_mailbox` writes every
  email as an `.eml` file to `backend/.data/mail/`. The worker must be
  running for messages to appear. Open the newest file to follow a link
  (bodies are quoted-printable, so a link may contain `=3D`; replace it
  with `=`).
- **Skipping verification:** `AUTH_DEV_AUTO_VERIFY_EMAIL=true` in
  `backend/.env.local` (on by default for local setups) marks accounts
  verified at sign-up, without sending an email, and verifies older
  unverified local accounts at their next sign-in. The API logs a warning
  at start-up while it is on.
- **Guards:** configuration refuses this setting unless
  `APP_ENV=development`, and refuses `AUTH_REQUIRE_EMAIL_VERIFIED=false`
  outside development and test (ADR-049).

### Local-only adapters

| Concern | Local | Hosted |
|---|---|---|
| Storage | `local_disk` → `.data/storage` (dev only) | Appwrite |
| Email | `dev_mailbox` → `.data/mail/*.eml` | SMTP |
| Push | disabled (tested against local stand-ins) | Web Push (VAPID) / FCM |
| AI | disabled unless key set | Anthropic |
| FX | manual | manual + ECB |
| Bank/AA integrations | none (test-only sandbox adapter in tests) | none until reviewed (ADR-016) |

## Hosted environments

Separate `development`, `staging`, `production` configurations (see
`docs/DEPLOYMENT.md`). The implementation agent never deploys or changes
hosted resources.

### Worker database connections

The worker needs two connection strings:

| Variable | Role | Used for |
|---|---|---|
| `WORKER_DATABASE_URL` | `montra_worker` (system scope via `worker_all` policies) | job queue, scheduler, outbox, reminders, imports, maintenance |
| `DATABASE_URL` | `montra_app` (RLS enforced) | work done on behalf of one user — report generation reads as the report owner |

If `DATABASE_URL` is missing or equal to the worker URL, report generation
fails closed (`reports_unavailable`) rather than reading with the worker role.

### AI provider

AI is off by default (`AI_PROVIDER=disabled`). To enable it in a hosted
environment the owner sets `AI_PROVIDER=anthropic`, `ANTHROPIC_API_KEY`
(secret store only) and optionally `AI_MODEL` (default `claude-opus-5-5`),
`AI_TIMEOUT` (45s), `AI_MAX_OUTPUT_TOKENS` and
`AI_DAILY_REQUEST_CAP_PER_USER` (200). Requests use the server-side
refusal fallback beta. Usage and estimated cost are in `ai_usage`
(no prompts or answers). Local development keeps AI disabled.

### Push and email channels

- Web Push: set `VAPID_PUBLIC_KEY` (base64url uncompressed P-256 point),
  `VAPID_PRIVATE_KEY` (base64url 32-byte scalar, secret store only) and
  `VAPID_SUBJECT` (`mailto:` or `https:` contact). Invalid keys fail
  start-up. Rotating the key pair invalidates existing browser
  subscriptions; clients re-subscribe with the new public key.
- FCM: set `FCM_PROJECT_ID` and `FCM_CREDENTIALS_FILE` (service-account
  JSON mounted as a secret, never committed).
- Email: SMTP settings per ADR-014. Digests go out from the hourly
  `notifications.digest_scan` job at 08:00 user-local time.
- Without credentials the channel reports `not_configured` and in-app
  notifications keep working.

### Integrations

No provider is enabled. Enabling one needs all of the following:

1. Legal and security review (ADR-016).
2. An adapter implementing `integrations.Adapter`, registered at start-up
   only when its credentials are present.
3. Its client secret and webhook secret in the secret store.
4. The provider's redirect URI set to
   `<WEB_APP_URL>/integrations/<provider>/callback`.

The worker runs `integrations.schedule` every 30 minutes. It recovers
abandoned runs, expires lapsed consents (notifying users), queues syncs
for connections idle for 6 h and re-queues verified webhook events still
waiting after 5 minutes.

To investigate webhooks, query `integration_webhook_events` as the worker
or owner role: `quarantined` means an invalid signature and `ignored` an
unknown or revoked connection. Payloads are stored encrypted.

### FX provider

`FX_PROVIDER=manual` (default) uses only user-entered rates. `FX_PROVIDER=ecb`
lets the worker fetch the ECB daily reference rates (`FX_ECB_URL`) every 6 h;
rates are appended, never rewritten. Enabling it makes outbound HTTPS
requests from the worker.

## Observability

- **Logs:** structured JSON (`LOG_FORMAT=json`) with request, user and job
  IDs. Sensitive keys are redacted by the handler, and no request bodies
  or personal values are logged (`TestLogsNeverContainPersonalValues`
  checks this across API and worker flows).
- **Metrics:** Prometheus at `GET /metrics` (requires `METRICS_TOKEN`).
  - HTTP requests and latency by route;
  - jobs processed, duration, retries and queue depth;
  - auth events;
  - RLS and permission denials;
  - external provider calls and latency (AI, Web Push, FCM, SMTP);
  - estimated AI cost;
  - notification outcomes per channel;
  - storage bytes;
  - import rows by outcome;
  - the overdue account-deletion backlog.
- **Alerts:** `ops/prometheus/alerts.yml` covers error rate, read and write
  p95 (ADR-025), RLS denials, sign-in failure spikes, job backlog, dead
  jobs, a stalled worker, the deletion backlog, provider and notification
  failure rates, and AI spend. Each alert links its runbook.
- **Traces:** not implemented. Request IDs join logs across the API and
  worker. OpenTelemetry is a post-launch option.
- **Imports:** `montra_import_rows_total` counts rows by outcome
  (imported, failed, duplicate).

## Runbooks

Runbooks for API/database outage, Supabase connection exhaustion, Appwrite
outage, queue backlog/worker crash, AI provider outage, bank integration
outage, webhook incident, data corruption, account takeover,
privacy incident, failed deletion, backup restore, deployment rollback and
secret rotation are maintained in `docs/RUNBOOKS.md` (Phase 12).

## SLOs (planning targets, ADR-025)

API availability 99.5 %/month; core read p95 < 500 ms; core write p95
< 800 ms; job objectives per class in `docs/BACKGROUND_JOBS.md`.
