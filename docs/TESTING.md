# Montra — Testing Strategy

Tests are part of each feature's definition of done (spec §14, §21).

## Test classes

| Class | Tooling | Location | Runs against | Locally? |
|---|---|---|---|---|
| Go unit + fuzz | `go test`, `go test -fuzz` | `backend/internal/**/*_test.go` | pure code | yes |
| Go integration | `go test -tags=integration` | `backend/internal/**/*_integration_test.go`, `backend/tests/` | local PostgreSQL `montra_test` | yes |
| RLS tests | Go integration (connects as `montra_app`) | `backend/tests/rls` | `montra_test` | yes |
| Migration tests | `cmd/migrate` from empty + re-run | `backend/internal/platform/migrate` | `montra_test` | yes |
| API/contract tests | Go httptest + OpenAPI drift check | `backend/tests/api`, `contracts/` | `montra_test` | yes |
| Web unit/component | Vitest + Testing Library | `web/src/**/*.test.tsx` | jsdom | yes |
| Web E2E | Playwright | `web/e2e` | local API + worker (dev API, or a throwaway stack) | yes; CI `e2e` workflow |
| Flutter unit/widget | `flutter test` | `mobile/test` | VM | yes |
| Mobile on-device | Flutter `integration_test` | `mobile/integration_test` | Android emulator + live API | yes; CI `e2e` workflow |
| Provider tests (Appwrite, SMTP, push, AI, FX, banks) | Go, build tag `provider` | `backend/tests/provider` | **hosted env only** | **no** (spec §1.3A.9) |
| Manual verification | checklists | `docs/DEPLOYMENT.md` | hosted | owner |

Appwrite adapter logic is covered locally by unit tests that use an
`httptest.Server` test double emulating documented Appwrite responses;
these never contact Appwrite. Live Appwrite verification is a separate,
owner-run provider test.

## Database test safety

- Integration tests require `TEST_DATABASE_URL` whose database name ends
  in `_test`; the harness refuses any other target.
- The harness resets only schema `montra` inside that database, then runs
  all migrations, so every run proves migrations apply from empty.

## Required coverage per feature

Normal behavior, invalid input, unauthorized access (User A vs User B),
boundary conditions, concurrency (where relevant), duplicate requests
(idempotency), rollback on failure, failure recovery, financial accuracy.

## Synthetic data rules

Seeds and fixtures are deterministic and clearly synthetic (names like
"Test User A", merchants like "Sample Grocer"). They include multiple
currencies (INR, USD, JPY, KWD), negative balances, refunds, partial
settlements, duplicate imports, leap years, DST transitions, large amounts,
malformed files, malicious filenames, and cross-tenant records.

## Commands

```sh
make test            # all local test suites (unit + integration + web + mobile)
make test-backend    # Go unit tests
make test-integration# Go integration + RLS tests against montra_test
make web-test        # Vitest
make mobile-test     # flutter test
make e2e             # Playwright journeys, all three projects (starts Vite; needs a running API)
make e2e-mobile      # integration_test journeys on the running Android emulator (API on :8080)
```

## End-to-end tests (web and mobile)

Both suites run against a real API and worker, never against mocks. Each run
creates throwaway users named `e2e.<timestamp>.<tag>@example.com` and only
touches their data. The API must run with `APP_ENV=development`,
`AUTH_DEV_AUTO_VERIFY_EMAIL=true` (sign-in right after sign-up) and,
for the web suite, `AUTH_DEV_RATE_PER_MINUTE=600` (journeys sign in many
users).

### Throwaway stack (`scripts/ci/e2e-stack.sh`)

`scripts/ci/e2e-stack.sh start` builds the api, worker and migrate
binaries, generates throwaway keys (`openssl rand -base64 32`), applies
`supabase/migrations` with `migrate up`, and starts the API and worker from
its state directory (default `.data/e2e-stack`, git-ignored) so
`backend/.env.local` is never loaded. It uses local storage and the dev
mailbox inside that directory, refuses non-local databases, and refuses to
start when something already answers on the chosen port. `stop` stops only
the processes it started. CI uses the same script.

To run it next to a running dev stack (`:8080`, `montra_dev`) without
touching either:

```sh
# 1. A separate database, created the way scripts/db/bootstrap.sh does
#    (reuses the existing montra_* roles; the name must end in _test or _dev).
psql -h localhost -d postgres <<'SQL'
create database montra_e2e_test owner montra_owner encoding 'UTF8' template template0;
revoke connect, temporary on database montra_e2e_test from public;
grant connect on database montra_e2e_test to montra_owner, montra_app, montra_worker;
SQL
psql -h localhost -d montra_e2e_test -c 'revoke create on schema public from public'

# 2. API on :8091, worker metrics on :9191. Role passwords as in backend/.env.local.
export E2E_DATABASE_MIGRATION_URL='postgres://montra_owner:<pw>@localhost:5432/montra_e2e_test?sslmode=disable'
export E2E_DATABASE_URL='postgres://montra_app:<pw>@localhost:5432/montra_e2e_test?sslmode=disable'
export E2E_WORKER_DATABASE_URL='postgres://montra_worker:<pw>@localhost:5432/montra_e2e_test?sslmode=disable'
export E2E_API_PORT=8091 E2E_WORKER_METRICS_ADDR=127.0.0.1:9191
scripts/ci/e2e-stack.sh start

# 3. Afterwards
scripts/ci/e2e-stack.sh stop
psql -h localhost -d postgres -c 'drop database montra_e2e_test'
```

### Web (Playwright)

`pnpm e2e` (in `web/`) runs `web/e2e` on three projects: desktop, phone
(Pixel 7) and tablet (768 px, touch). Playwright starts Vite on
`E2E_PORT` (default 5199, never reused) and Vite proxies `/api` to
`MONTRA_API_PROXY_TARGET` (default `http://localhost:8080`). Journeys that
open verification links read `.eml` files from `MONTRA_DEV_MAILBOX`
(default `backend/.data/mail`). `PW_CHANNEL=chrome` uses the installed
Chrome instead of Playwright's bundled Chromium.

Against the throwaway stack above:

```sh
cd web
E2E_PORT=5299 MONTRA_API_PROXY_TARGET=http://127.0.0.1:8091 \
MONTRA_DEV_MAILBOX="$PWD/../.data/e2e-stack/mail" PW_CHANNEL=chrome pnpm e2e
```

Reports go to `web/playwright-report` and traces of failed tests to
`web/test-results` (`pnpm exec playwright show-report`).

### Mobile (Flutter `integration_test`)

`mobile/integration_test/app_journeys_test.dart` drives the real app on a
device: sign up a throwaway user `e2e.<timestamp>.ci@example.com`, sign in
(auto-verified), skip onboarding, add an account, add an expense and an
income and find both on Home, create a group and add a shared expense, then
sign out. The API origin is the app's own `--dart-define=API_BASE_URL`
(the emulator reaches the host at `10.0.2.2`). Session tokens and
preferences are kept in memory during the test, so a session already signed
in on the emulator is neither read nor replaced.

```sh
flutter emulators --launch Pixel_10_Pro
cd mobile
flutter test integration_test -d emulator-5554 --no-uninstall \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080   # or :8091 for the throwaway stack
```

`flutter test integration_test` installs a debug build of
`app.montra.mobile` over the installed app (app data is kept) and restarts
it. Without `--no-uninstall` it uninstalls the app afterwards, which deletes
the app data of whoever else uses the emulator.

### CI (`.github/workflows/e2e.yml`)

Runs on pull requests, pushes to `main` and manual dispatch, when web,
mobile, backend, migrations, the contract or the e2e tooling change. It
never deploys and uses no repository secrets.

| Job | What it does |
|---|---|
| `web-e2e` | PostgreSQL 17 service container; `.github/actions/e2e-backend` creates `montra_owner`/`montra_app`/`montra_worker` (passwords generated per run) and `montra_e2e_test` as `scripts/db/bootstrap.sh` does, then `scripts/ci/e2e-stack.sh start` (API on `127.0.0.1:8080`). Installs pnpm dependencies and Playwright's bundled Chromium and runs `pnpm e2e` (all three projects, `CI=true`: 2 retries, `test.only` forbidden). On failure uploads `playwright-report` (HTML report, `web/test-results` traces) and the API/worker logs. |
| `mobile-e2e` | Same backend. Enables KVM, then `reactivecircus/android-emulator-runner` boots an API 34 x86_64 emulator and runs `flutter test integration_test --dart-define=API_BASE_URL=http://10.0.2.2:8080`; `10.0.2.2` is the runner's loopback, where the API listens. Uploads the API/worker logs on failure. |

Limits:

- The CI emulator is an API 34 `google_apis` x86_64 image with software
  rendering (`swiftshader_indirect`). It boots in a few minutes and is
  slower than a local emulator; the journey's waits allow 30 s per step.
- Flutter is the latest stable release (`subosito/flutter-action`), as in the
  `mobile` CI job, not a pinned version.
- iOS on-device tests are not run (no macOS runner is configured).
- Real providers (Appwrite, SMTP, push, AI, FX feeds) are not used: the
  stack runs local storage, the dev mailbox, AI disabled and manual FX.

## Current suites

| Suite | Location | Covers |
|---|---|---|
| Domain unit tests | `backend/internal/domain/*` | money (fuzzed), split (fuzzed), settlement, ledger, period, recurrence (month ends 28–31, leap years, DST gaps/overlaps, counts/end dates), budgetcalc, subdetect (cadence bands, tolerance, stale series, same-day retries), textsafe (cleaning, secrets, links; fuzzed), challenges streaks, statement (CSV/XLSX/OFX, encodings, limits, amounts, dates, totals; 3 fuzz targets), reconcile (scoring, assignment, subset sums); `internal/reports/render` (formula-safe CSV, XLSX round-trip through the import parser, PDF pagination/limits, JSON) |
| Platform unit tests | `backend/internal/platform/{crypto,storage}` | Argon2id, TOTP RFC 6238 vectors, envelope encryption, storage adapters |
| Notification channel unit tests | `backend/internal/notifications` | RFC 8291 encryption round trip, VAPID JWT, push-host allowlist, gone/retry classification, FCM token exchange + send against `httptest`, digest rules |
| RLS integration | `backend/tests/rls` | owner isolation, no-identity denial, group boundaries, household sharing, append-only tables, profile visibility/blocking, discovery/minimal-profile helpers (blocks, opt-outs, anonymous), settlements group scope, community/group guard triggers, webhook inbox write-only + narrow definer queuing |
| API integration | `backend/tests/api` | auth/MFA/sessions/CSRF/rate limits, files, export/deletion, finance (5 suites), budgets (3), planning (7: recurring outage recovery + retries, pause/resume/edit-future/confirm idempotency, bills linking/overdue/reminders, subscriptions detection/cancellation and reminders, goals contributions/forecast/sharing/export/reminders + calendar), imports/receipts/reconciliation (4), FX + reports + planning analytics (3), contract regressions (2), social + groups (5: discovery/requests/controls/blocks/mutes; invitations/roles/join requests/leave/archive/delete/isolation; all five splits, multiple payers, balances, settlement lifecycle, disputes, revisions, report + formula-safe export; linked personal records synced by the worker on edit/delete/void; recurring shared bills (scheduler adds once, manual add/skip, personal-endpoint isolation, calendar, single failure notice) + foreign-currency expenses), communities/moderation/challenges (3: membership kinds, invitations, posts, polls, comments, reactions, spam caps, secrets, links, blocks; reports, auto-hide, queues, actions, reversal, appeals, platform sanctions; challenges, streaks, consent leaderboards), AI + insights (4: consent/preferences/deterministic mode/history; grounding verification, injection, redaction, cross-user isolation, fair use, consent revocation; categorize/duplicates/receipts/PDF statements/insights/notifications; rule thresholds with sparse history, refunds, currencies, changed income, snooze), notifications (2: Web Push delivered to a local TLS push service that decrypts as a browser and verifies VAPID, retries, gone endpoints; email digest at 08:00 local, one-click unsubscribe, tampered tokens, security emails without unsubscribe), integrations (2: registry, consent, OAuth state binding/single use, encrypted tokens, cursor backfill, dedupe, pending→posted, reversals, user deletions not resurrected, currency mismatch, webhooks valid/duplicate/forged/stale/unknown/late, isolation, scheduled sync, consent expiry notice, disconnect with data deletion; failed exchange, abandoned-run recovery) |
| Web | `web/src/**/*.test.ts(x)`, `web/e2e` | Vitest + Testing Library + MSW (unmocked requests fail); Playwright against the local API |
| Mobile | `mobile/test` | unit + widget tests; generated models checked against the contract |

Integrations are tested with a test-only sandbox adapter registered in the test (`tests/api/integrations_test.go`); no bank or aggregator is contacted. Web Push is tested against a local `httptest` TLS server allowed through `PushHostsExtra`.
AI features are tested with a scripted fake model (`tests/api/ai_test.go`) and the Anthropic adapter against a local `httptest` fake of the Messages API (`internal/ai/llm`); no test calls a real provider. Receipt extraction is also tested with a fake `Extractor`, and the ECB rate feed
with an `httptest` server (test doubles); no external provider is called. Scheduled jobs are tested by calling the worker-process services
(`apitest.Server.WorkerSvcs`) with an injected clock (`Service.Now`) to
simulate outages and elapsed time, plus a queued-job run through the real
worker and relay.

## Cross-cutting guards

- **Notification text:** every API test checks every notification created
  through `notifications.Create`. A title or body containing an amount,
  currency symbol or currency code fails the test
  (`internal/testutil/apitest`).
- **Logs:** `TestLogsNeverContainPersonalValues` runs the production logger
  across auth, finance, groups, AI, webhooks and worker jobs, and fails if
  any personal value appears.
- **Inventories:**
  - `TestAuthorizationInventory` keeps the public-operation allowlist
    explicit.
  - `TestJobInventory` checks that every periodic job has a handler.

## Load tests

`make load-test` (`backend/cmd/loadtest`) runs synthetic users through a
read-heavy mix (8 reads : 2 writes): dashboard, transaction lists,
accounts, analytics, budgets, the unread count and transaction creates.
It reports p50/p95/p99 per operation and fails when read p95 ≥ 500 ms,
write p95 ≥ 800 ms or the error rate is ≥ 1 % (ADR-025).

- It refuses non-local targets unless `-allow-remote` is passed, and must
  never target production.
- Locally it creates `loadtest.*@example.com` users and reads their
  verification emails from the dev mailbox. Users are remembered in
  `backend/.data/loadtest-users.json` (git-ignored).
- The API's per-user and per-IP rate limits stay on during the run; 429s
  count as errors.

## Results

Recorded with dates and commands in `docs/IMPLEMENTATION_STATUS.md` under
"Test results log". A test is reported as passing only after it ran.
