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
| Web E2E | Playwright | `web/e2e` | local API + `montra_test`-like DB | yes |
| Flutter unit/widget | `flutter test` | `mobile/test` | VM | yes |
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
make test-web        # Vitest
make test-mobile     # flutter test
make e2e             # Playwright journeys (starts API + web)
```

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
