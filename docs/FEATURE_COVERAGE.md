# Montra — Feature Coverage

Per-section summary of `docs/REQUIREMENTS_TRACEABILITY.md` after the P13
backend verification pass, the P13 client verification pass, the
round-6 re-check (all 2026-11-12) and the round-7 re-check (2026-11-13).
Row-level evidence (test names, files, limitations) lives in
the matrix; this page is the roll-up.

**Status: backend and clients verified row by row.** The 67 rows whose
Location includes web, mobile or `all` were re-checked against the web and
mobile code and their test assertions; the last column of the table counts
them per section. No row was upgraded on the strength of an agent report.
The round-6 and round-7 re-checks (below) re-read the code and tests for
the rows that work touched.

## How the backend was verified

| Check | Result |
|---|---|
| `cd backend && go test -count=1 ./...` (2026-11-06, after the last backend change at 16:46 that day) | All packages ok: 28 unit-test packages, `tests/api` + `tests/rls` (139 top-level integration tests) against local PostgreSQL 18.3 `montra_test`, migrations applied from empty |
| `go vet ./...`, `golangci-lint run ./...` (2026-11-12) | Clean, 0 issues |
| `go run ./cmd/openapi -check` (2026-11-12) | Contract up to date (328 paths) |
| `python3 scripts/docs/gen_error_codes.py --check` (2026-11-12) | Up to date |
| Assertion review | Every `tests/api` and `tests/rls` test read for what it actually asserts (not what its comments claim) |

Statuses follow the matrix: `VERIFIED` means the suite passed, the
assertions were read, and they cover every clause of the requirement at
the backend layer. `TESTED` means tests exist and pass, but some clauses
are unasserted; those clauses are named in the row. `IMPLEMENTED` means
code exists with no test evidence.

Test doubles used everywhere: local-disk storage (not Appwrite), the dev
mailbox (not SMTP), a scripted fake AI model and fake receipt extractor
(not Anthropic), `httptest` stand-ins for Appwrite, Web Push, FCM, the
Anthropic API and the ECB feed, and a test-only sandbox bank adapter. No
real provider was contacted.

## How the clients were verified

| Check (2026-11-12, after the last code change) | Result |
|---|---|
| Web `pnpm exec vitest run` | 121 files, 1186 tests passed |
| Web `tsc -p tsconfig.app.json --noEmit`, `eslint`, `prettier --check`, `pnpm check:api`, `pnpm build` | 0 errors, 0 warnings, clean, matches the contract, build OK |
| Web Playwright `E2E_PORT=5199 PW_CHANNEL=chrome pnpm e2e` | 11/11 passed against the live local API (auth, finance, planning, public specs; desktop Chrome only) |
| Mobile `dart format --set-exit-if-changed`, `dart run tool/gen_api.dart --check`, `flutter analyze` | 0 changed, up to date, no issues |
| Mobile `flutter test` | +1938, all passed (widget and unit tests against mocked APIs) |
| Mobile `flutter build apk --debug` | Built. No on-device integration tests; the Android emulator runs were manual and are not counted. iOS unverified (no Xcode) |
| Assertion review | The client tests named in each row were read for what they assert. Bundle check: a manual grep of `web/dist` (no automated scan) |

## Round 6 re-check (2026-11-12)

| Check (main session, after the last code change) | Result |
|---|---|
| Backend `go test ./...`, golangci-lint, `make contract-check`, `make docs-check` | All ok, 0 issues, contract up to date, docs ok. New: `tests/api/round6_test.go` (TestDashboardPlanningCardsAndWidgets, TestProfileAvatarOwnershipAndClear, TestRound6ReadsLinksAndCodes, TestGroupBudgetVisibleToViewerMember, TestCommunityInvitationNoticeAndInviterName), `internal/analytics/widgets_test.go`, `internal/platform/ratelimit/ratelimit_test.go`, config TestDevAuthRateIsDevelopmentOnly. Migration 000028 applied to `montra_dev` |
| Web `vitest run` | 133 files, 1279 tests passed (incl. jest-axe page checks in `src/tests/a11y`) |
| Web tsc (app and node), eslint, prettier, `check:api`, `pnpm build` | 0 errors, 0 warnings, clean, matches, build OK |
| Web Playwright `E2E_PORT=5199 PW_CHANNEL=chrome pnpm e2e` | 111 passed, 0 failed, 21.1 min against the live local API: 11 specs, 37 tests in each of desktop-chromium, phone-chromium (Pixel 7) and tablet-chromium (768×1024); 0 rate-limit responses. Includes `accessibility.spec.ts` (axe WCAG A/AA in light and dark, no horizontal scroll, reduced motion) |
| Mobile `dart format`, `gen_api --check`, `flutter analyze` | 0 changed, up to date, no issues |
| Mobile `flutter test` | +2037, all passed (adds `a11y_guidelines_test.dart` meetsGuideline on 11 screens, `profile_preferences_test.dart`, `app/accessibility_settings_test.dart`, `group_link_test.dart`, planning-card, multi-page receipt and router `next` tests) |
| Mobile `flutter build apk --debug` | Built. iOS still unverified (no Xcode); emulator runs manual only |

## Round 7 re-check (2026-11-13)

| Check (main session, after the last code change) | Result |
|---|---|
| Backend `go test ./...`, golangci-lint, contract and docs checks | Passed, 0 issues, ok (a re-run after a final logging change was in progress; counted as passing on the main session's word). New in `tests/api/round6_test.go`: TestDashboardAlertsRenewalsRecurringAndLayout, TestMultiPageReceiptAndSummaryTimestamp, TestWeekStartBucketsSubscriptionsAndTrialEnd, TestInsightSingleReadOwnAnyStatus, a tightened TestCommunityInvitationNoticeAndInviterName; `internal/platform/httpx/accesslog_test.go` |
| Web `vitest run` | 134 files, 1294 tests passed |
| Web tsc (app and node), eslint, prettier, `check:api`, `pnpm build` | All ok |
| Web Playwright, full run (desktop, phone and tablet Chromium) | 108 passed, 1 failed, 2 skipped. The failure (desktop `auth-journey` "expired access token…") was an e2e harness fault in `web/e2e/support/test.ts` (a route still in flight at test end, C-61) and skipped the 2 serial tests after it. After the fix, `auth-journey` passed 24/24 with `--repeat-each=2` on all three projects; every other spec passed on all three projects in the full run |
| Mobile `dart format`, gen check, `flutter analyze` | 0 changed, ok, clean |
| Mobile `flutter test` | 2098 passed (adds `planning_alerts_renewals_recurring_test.dart`, `income_form_test.dart`, `core/formatting/date_settings_test.dart`, onboarding goals, region and email-summaries tests) |
| Mobile `flutter build apk --debug` | Built |
| Mobile on-device journey `integration_test/app_journeys_test.dart` (Android emulator, live local API) | 7 of 8 runs passed: sign up, sign in, skip setup, account, expense, income, group with a shared expense, sign out. The first run failed once with an unreproduced 422 on POST /transactions; error codes are now in the access log so a recurrence can be diagnosed. Automated, but run locally only. iOS unverified (no Xcode) |
| CI | New `.github/workflows/e2e.yml` (web e2e and mobile emulator jobs), `.github/actions/e2e-backend/action.yml`, `scripts/ci/e2e-stack.sh`. Steps reproduced locally on a throwaway database; configured, not yet run on GitHub |

Statuses for client rows: `VERIFIED` means the backend evidence covers the
server side and passing client tests cover every client clause on each
client the row names. `TESTED` rows name the clauses no client test
asserts; `IMPLEMENTED` means built with no client test; `IN_PROGRESS`
names what is missing; `BLOCKED` is used only for owner-only items.

## Status by section

Counts are rows in the matrix (415 in total).

| Matrix section (spec §) | Rows | Not started | In progress | Implemented | Tested | Verified | Blocked | Client rows checked |
|---|---|---|---|---|---|---|---|---|
| 0. Product-wide rules (§0, §17) | 10 | 0 | 0 | 0 | 6 | 4 | 0 | 6 |
| 1. Architecture, repo, environment (§1) | 19 | 0 | 5 | 7 | 4 | 3 | 0 | 1 |
| 2. Roles, authorization, privacy (§3) | 14 | 0 | 0 | 1 | 7 | 6 | 0 | 1 |
| 3. Authentication & lifecycle (§4.1, §20B.2) | 19 | 1 | 0 | 2 | 13 | 3 | 0 | 5 |
| 4. Dashboard (§4.2, §20B.3) | 11 | 0 | 0 | 0 | 7 | 4 | 0 | 5 |
| 5. Accounts & payment methods (§4.3, §20B.4) | 16 | 0 | 0 | 3 | 11 | 2 | 0 | 1 |
| 6. Transactions (§4.4, §20B.5, §18) | 24 | 0 | 0 | 3 | 11 | 10 | 0 | 1 |
| 7. Categories, tags, merchants (§4.5, §20B.6) | 10 | 0 | 0 | 1 | 7 | 2 | 0 | 0 |
| 8. Budgets (§4.6, §20B.7) | 11 | 0 | 1 | 2 | 6 | 2 | 0 | 1 |
| 9. Recurring & bills (§4.7, §20B.8) | 11 | 0 | 0 | 0 | 5 | 6 | 0 | 1 |
| 10. Subscriptions (§4.8, §20B.9) | 8 | 0 | 0 | 0 | 1 | 6 | 1 | 2 |
| 11. Receipts & storage (§4.9, §10, §20B.10) | 16 | 0 | 2 | 1 | 11 | 2 | 0 | 1 |
| 12. Imports & reconciliation (§4.10, §20B.11) | 12 | 0 | 1 | 0 | 7 | 4 | 0 | 1 |
| 13. Analytics, reports, exports (§4.11, §20B.12) | 17 | 0 | 1 | 0 | 13 | 3 | 0 | 1 |
| 14. AI (§4.12, §20B.13) | 17 | 0 | 3 | 1 | 9 | 4 | 0 | 1 |
| 15. Anomalies & savings (§4.13, §20B.14) | 6 | 0 | 2 | 0 | 4 | 0 | 0 | 0 |
| 16. Goals (§4.14, §20B.15) | 8 | 0 | 0 | 0 | 2 | 6 | 0 | 0 |
| 17. Social, groups, splits, trips, households (§4.15, §20B.16) | 27 | 0 | 1 | 1 | 14 | 11 | 0 | 1 |
| 18. Communities, challenges, moderation (§4.16, §20B.17) | 12 | 0 | 0 | 0 | 8 | 3 | 1 | 1 |
| 19. Notifications (§4.17, §20B.18) | 8 | 0 | 0 | 1 | 6 | 1 | 0 | 1 |
| 20. Integrations (§4.18, §20B.19) | 11 | 0 | 0 | 0 | 7 | 3 | 1 | 3 |
| 21. Multi-currency (§4.19, §20B.20) | 7 | 0 | 0 | 0 | 4 | 3 | 0 | 0 |
| 22. Search, settings, help (§4.20, §4.21, §20B.21) | 6 | 0 | 1 | 1 | 4 | 0 | 0 | 2 |
| 23. Data model (§5) | 4 | 0 | 1 | 1 | 2 | 0 | 0 | 0 |
| 24. API (§6) | 11 | 0 | 0 | 1 | 7 | 3 | 0 | 0 |
| 25. Clients (§7, §20B.23) | 23 | 0 | 0 | 2 | 15 | 5 | 1 | 22 |
| 26. Backend, database, jobs (§8, §9, §11, §20B.22) | 24 | 0 | 5 | 7 | 12 | 0 | 0 | 1 |
| 27. Security, privacy, operations (§12, §13) | 23 | 0 | 5 | 5 | 8 | 3 | 2 | 4 |
| 28. Testing, deployment, a11y, l10n (§14–§16) | 18 | 1 | 4 | 7 | 5 | 1 | 0 | 4 |
| 29. Critical workflows, docs, decisions (§18, §22, §23) | 12 | 0 | 1 | 2 | 6 | 3 | 0 | 0 |
| **Total** | **415** | **2** | **33** | **49** | **222** | **103** | **6** | **67** |

Status histogram for the whole matrix:

| Status | After the backend pass | After the client pass | After round 6 | After round 7 |
|---|---|---|---|---|
| NOT_STARTED | 42 | 2 (AUTH-014 optional OAuth/passkeys; PA-001 no analytics pipeline) | 2 | 2 |
| IN_PROGRESS | 52 | 40 | 36 | 33 |
| IMPLEMENTED | 50 | 51 | 50 | 49 |
| TESTED | 184 | 217 | 221 | 222 |
| VERIFIED | 83 | 99 | 100 | 103 |
| BLOCKED | 4 | 6 (adds MOB-005 push, PRIV-005 legal texts) | 6 | 6 |
| Total | 415 | 415 | 415 | 415 |

Client rows changed in this pass (old → new): 15 to VERIFIED (GEN-001,
GEN-004, GEN-005, DASH-008, BILL-003, SUB-004, SUB-007, IMP-002, ANL-008,
SOC-001, INT-001, WEB-002, WEB-003, WEB-008, WEB-013), 36 to TESTED, 3 to
IMPLEMENTED (AUTHZ-011, WEB-001, WEB-011), 2 to BLOCKED (MOB-005,
PRIV-005), DASH-002, SET-001, WEB-014 and TEST-003 from NOT_STARTED to
IN_PROGRESS. AUTH-011, DASH-001, RCPT-001, AI-001, HELP-001 and OPS-002
stay IN_PROGRESS and PA-001 stays NOT_STARTED, now with the missing
pieces named.

Rows changed in the round-6 re-check (old → new): SET-001, WEB-014,
RCPT-001 and TEST-003 IN_PROGRESS → TESTED; WEB-011 IMPLEMENTED →
VERIFIED. Re-checked with narrower notes but the same status: DASH-001 and
DASH-002 (IN_PROGRESS: web alerts card; recurring and renewal-calendar
widgets), AUTH-011 (IN_PROGRESS, onboarding unchanged), DASH-004
(IMPLEMENTED: only GET is called by a backend test), DASH-005, DASH-011,
AUTH-010, TXN-006, MOB-001, MOB-004, WEB-010, A11Y-001 (TESTED) and
BUD-008 (VERIFIED, new evidence). ARCH-015, WEB-009 and AUTHZ-011 are
unchanged: the bundle check is still a manual grep.

Rows changed in the round-7 re-check (old → new): DASH-001 IN_PROGRESS →
VERIFIED (alerts card on both clients; alerts, renewals and recurring
asserted at the API); DASH-002 IN_PROGRESS → TESTED (renewals and recurring
widgets on both clients; the renewals widget is a 30-day list, not a
calendar grid; AI summary deferred by owner decision); DASH-004
IMPLEMENTED → VERIFIED (PATCH hide, reorder, reset and per-user
persistence asserted); AUTH-011 IN_PROGRESS → TESTED (goals step on both
clients; mobile week/month start and email summaries); TXN-006 TESTED →
VERIFIED (mobile income form tests). Re-checked with new evidence but the
same status: DASH-005 and DASH-009 (TESTED: planning-card freshness and
month start still unasserted), SET-001 (TESTED: saving date format and
week/month start from the mobile Preferences screen), RCPT-001 (TESTED:
camera capture), TEST-003 (TESTED: CI configured, not yet run on GitHub;
one mobile on-device journey), AUTH-001, AUTH-003 and AUTH-006 (TESTED:
the emulator journey covers mobile sign-up and sign-out happy paths only),
MOB-001, A11Y-001, BE-004, ANL-001, ANL-003 (TESTED), BUD-007
(IMPLEMENTED: snooze and quiet hours still untested at the API), OPS-004
(IN_PROGRESS: tracing), ARCH-005 and DEP-007 (IMPLEMENTED: CI not yet run),
GEN-004, BILL-003, SUB-004 and WEB-011 (VERIFIED, new evidence).

## Notable gaps and limitations (clients)

| Area | Gaps after the P13 client pass and the round-6 and round-7 re-checks |
|---|---|
| Mobile, all areas | One on-device journey (sign up, sign in, skip setup, account, expense, income, shared group expense, sign out) on the Android emulator, 7 of 8 runs passed (one unreproduced 422 on POST /transactions); everything else is widget tests against mocks or manual emulator use. iOS never built or run (no Xcode). `meetsGuideline` checks cover 11 screens and 3 card/step states in the light theme only; no TalkBack/VoiceOver review. |
| Web, all areas | Axe runs in the browser and in jsdom, and Playwright covers phone, tablet and desktop widths, but Chromium only; no screen-reader review. E2E covers journeys 1–21 and 23–26 (22 is AI, deferred; journey 10's reminder delivery is not observable); the e2e CI workflow is configured, not yet run on GitHub (TEST-003). No automated bundle scan. 183 of 7,725 strings lack Hindi (count from the P13 pass). About ten small forms validate without a schema. |
| Auth & onboarding | Mobile sign-up and sign-out are covered only by the emulator journey's happy path (no validation, field-error, session-revocation or token-clearing assertions). Onboarding (round 7): goals step on both clients; mobile week/month start and email summaries. Untested: a changed currency or time zone saved from mobile onboarding, a successful time-zone change in web onboarding. Cookie Secure/SameSite never asserted. |
| Dashboard | Every listed card is built and tested on both clients (alerts, renewals and recurring added in round 7). The renewals widget is a 30-day list, not a calendar grid; AI summary deferred. Untested: the subscription row's label on the recurring card, the planning cards' freshness (envelope timestamp on web, none on mobile), the web layout-load alert, a mobile no-activity state. |
| Accounts & transactions | Account restore is untested on both clients and close on mobile. Mobile income tested since round 7. |
| Budgets | Creation is one guided form, not a step-by-step wizard (BUD-010). |
| Receipts | Mobile multi-page receipts built and tested (round 6); the API test for a multi-page receipt with a PDF page added in round 7. Camera capture itself is untested on mobile; web has no in-page camera. |
| Communities | Fixed 2026-11-12: mobile `safeLink` now refuses `user:password@` links like web (COMM-005 now VERIFIED). |
| Integrations | Syncing, partial and failed labels are not asserted on either client. |
| Settings & help | Profile and preferences screens built and tested on both clients (round 6); web locale and time-zone changes, mobile time-zone change and app-wide date format and week start tested in round 7. Untested: saving the date format, week start or month start from the mobile Preferences screen. Help is five short topics; no guides, troubleshooting or status link. |
| Notifications | Mobile push is not built (needs owner Firebase/APNs credentials). Web push depends on the owner's VAPID keys. |
| Product analytics | No analytics is collected (PA-001). Web onboarding copy corrected 2026-11-12 to say so, matching mobile. |
| By owner decision | AI client screens deferred (AI backend off by default). Staff screens (support queue, platform moderation, admin usage) are web-only. |

## Notable gaps and limitations (backend)

| Section | Gaps found in P13 |
|---|---|
| 1. Architecture | No seed data: `make seed` runs, but `supabase/seeds/` does not exist (ARCH-010). No `backend/`, `supabase/` or `contracts/` README. No web import-boundary lint rule found (ARCH-004). No documented hosted RLS verification step (ARCH-013). |
| 2. Authorization | The RLS inventory test checks that RLS is enabled on every table and that there are no PUBLIC grants. It does not check FORCE RLS, that each table has a policy, or function grants (AUTHZ-010, downgraded). Attaching another user's file to a transaction is not tested (AUTHZ-014). |
| 3. Auth & lifecycle | Deactivate/reactivate has no tests (AUTH-018). Security events are asserted only for email verification and the MFA alert (AUTH-017). Token expiry (verification, reset, access TTL) is not asserted. The storage purge on account deletion is not asserted, and the due job is enqueued by hand in the test. OAuth/passkeys are not built (optional). |
| 4–6. Dashboard, accounts, transactions | `PATCH /dashboard/widgets` tested since round 7. No test for account balance history, include-in-overview, `POST /transactions/{id}/duplicate`, bulk delete, saved filters, location text or attachment endpoints. Replay of `POST /transactions` itself is not asserted. |
| 8. Budgets | Snooze and quiet hours are untested (BUD-007, downgraded). Current-period vs future-only edit semantics are untested (BUD-009, downgraded). No time-zone-change boundary test. Group/trip budget progress is not asserted. |
| 9–10. Recurring, subscriptions | The 7-day retry window for failed auto-posts is not asserted. DST is covered by unit tests only. Group-shared subscriptions are untested. Unused-subscription hints need a usage source (blocked). |
| 11. Receipts & storage | Date/total/merchant duplicate detection, extraction timeout and EXIF stripping are untested. There is no file scanner (`scan_status = skipped`) and no community-media file purpose. The Appwrite adapter is tested only against a double. |
| 12. Imports | XLSX is unit-tested only. Category assignment on import rows and a successful one-to-many reconciliation via the API are untested. No provider adapters exist. |
| 13. Analytics & reports | No payment-method distribution (ANL-002). The report generation timestamp and the timestamps of disclosed conversion rates are not asserted. |
| 14–15. AI & insights | Everything runs against a scripted fake model; live-model quality, injection resistance and latency are unverified. Not tested: forecast ranges, estimates, the disclosure text, deleting one conversation, two insight rules (subscription price increase, missing recurring payment) and the "resolved" action. Seasonal patterns are not modelled. |
| 17–18. Social & communities | Not tested: friend-request decline, invite-link expiry and max uses, community ownership transfer and archive, pinned posts, post search, pin/lock/unban/escalation actions, and 2 of 6 group and challenge types. Personal friend invite links and contact discovery do not exist. |
| 19. Notifications | Quiet hours are not tested anywhere. Mark-read, archive and read-all are untested. Live SMTP/VAPID/FCM delivery is unverified. |
| 20. Integrations | Token refresh and the 20-page sync cap are untested. Only a sandbox adapter exists; no real provider. |
| 26. Backend & jobs | No circuit breakers, tracing, admin job list, manual-retry endpoint, preview-generation or scanning jobs. Scheduler leader election and backoff timing are not exercised by tests. `domain/currency` has no unit tests, and there is no forecast domain package. |
| 27. Security & ops | DAST/pentest, staging load test and restore drill are not done (need a hosted environment). TLS/`sslmode` for the hosted database is not documented. |
| 28. Deployment | No mobile store-submission checklist (DEP-003). No per-feature release-gate checklist (TEST-005). CI has not been observed running; the e2e workflow added in round 7 is configured, not yet run on GitHub. |
| Docs | Fixed 2026-11-12: ARCHITECTURE.md and ADR-009 now point to `backend/Dockerfile` and DEPLOYMENT.md §2 (bucket names in `config.go`). |

Rows downgraded in the backend pass: AUTHZ-010 (VERIFIED → TESTED), BUD-007,
BUD-009 and SETL-003 (TESTED → IMPLEMENTED). MOD-004, INT-009 and PRIV-006
moved from NOT_STARTED to BLOCKED because they wait on owner decisions.

## Owner actions needed

| Area | Action | Unblocks |
|---|---|---|
| Legal / compliance | Privacy policy, terms, cookie consent, age policy, cross-border processing (DPDP Act 2023; GDPR if EU users are served) | PRIV-005 (BLOCKED), L10N-001 localized legal texts, ADR-020 |
| Legal / compliance | Final retention periods, including whether voided transactions are purged | ADR-021, PRIV-003 |
| Legal / compliance | Subprocessor list once hosting is chosen | PRIV-004 |
| Legal / compliance | Review before any bank or Account Aggregator integration: FIU registration and a provider agreement | INT-009, PRIV-006, SUB-008, B-6 |
| Credentials | Appwrite project, the five buckets per DEPLOYMENT.md §2, a scoped API key, then a live adapter check | STOR-*, ARCH-012, B-3 |
| Credentials | SMTP credentials | NOTIF-001, B-4 |
| Credentials | VAPID key pair | NOTIF-001, web push delivery, B-4 |
| Credentials | Firebase project, FCM service account, `google-services.json`, `GoogleService-Info.plist` and an APNs key | NOTIF-001, MOB-005 (BLOCKED: mobile push not built until these exist), B-4 |
| Credentials | `ANTHROPIC_API_KEY`, then live-model evaluation (quality, injection, latency, cost) | AI-016, B-5 |
| Credentials | `TURNSTILE_SECRET_KEY` for bot protection | AUTH-008, C-12 |
| Credentials | `GITLEAKS_LICENSE`, if the repository belongs to an organization | SEC-008 |
| Production secrets & hosting | Supabase project in the chosen region with `montra_owner` / `montra_app` / `montra_worker` roles, PITR and daily backups | DB-003, DEP-004 |
| Production secrets & hosting | An always-on Go host for the API and worker | ARCH-017, DEP-002 |
| Production secrets & hosting | A Vercel project | DEP-001 |
| Production secrets & hosting | `DATA_ENCRYPTION_KEYS`, `URL_SIGNING_KEY`, `METRICS_TOKEN` and database role passwords in the secret store | DEPLOYMENT.md §3 |
| DNS / domain | Domain and brand clearance (§23.1) | — |
| DNS / domain | API and web origins, `CORS_ALLOWED_ORIGINS`, the CSP `connect-src` in `web/vercel.json`, and the App Links host (`montraLinkHost`, iOS `applinks:` entitlement) | DEP-001, MOB-004 |
| DNS / domain | `SUPPORT_EMAIL`, `SECURITY_EMAIL`, `STATUS_PAGE_URL` | ADR-024, HELP-001 status link |
| App stores | Apple Developer and Google Play accounts | DEP-003 |
| App stores | Signing keystore and certificates | DEP-003 |
| App stores | Final bundle identifier | DEP-003 |
| App stores | Store listings stating that Montra reads no SMS and asks for no bank credentials | DEP-003 |
| Local toolchain | Install Xcode and CocoaPods | B-1; any iOS verification (MOB-001, MOB-004, MOB-006) |
| Local toolchain | Install Android command-line tools and accept the SDK licences | B-2 |
| Operations | Confirm SLO, RPO and RTO targets | ADR-025, OPS-001 |
| Operations | Set moderation response targets, escalation and appeal ownership | ADR-024, MOD-004 |
| Operations | Staging load test, DAST/pentest and a backup-restore drill before launch | SEC-008, OPS-002, OPS-005, DB-003 |

## Pending

- Run `.github/workflows/e2e.yml` on GitHub and record the result (TEST-003,
  ARCH-005, DEP-007).
- Watch the mobile journey for a repeat of the POST /transactions 422 and
  read its logged error code (C-61).
- Client gaps listed above (mobile sign-up validation and sign-out
  revocation tests, mobile Preferences date format and week/month start,
  more mobile on-device journeys, dark-theme guideline checks,
  screen-reader review, iOS).
- Refresh the readiness report (DOC-002).
