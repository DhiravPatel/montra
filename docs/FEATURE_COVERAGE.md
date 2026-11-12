# Montra — Feature Coverage

Per-section summary of `docs/REQUIREMENTS_TRACEABILITY.md` after the P13
backend verification pass and the P13 client verification pass (both
2026-11-12). Row-level evidence (test names, files, limitations) lives in
the matrix; this page is the roll-up.

**Status: backend and clients verified row by row.** The 67 rows whose
Location includes web, mobile or `all` were re-checked against the web and
mobile code and their test assertions; the last column of the table counts
them per section. No row was upgraded on the strength of an agent report.

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
| 3. Authentication & lifecycle (§4.1, §20B.2) | 19 | 1 | 1 | 2 | 12 | 3 | 0 | 5 |
| 4. Dashboard (§4.2, §20B.3) | 11 | 0 | 2 | 1 | 6 | 2 | 0 | 5 |
| 5. Accounts & payment methods (§4.3, §20B.4) | 16 | 0 | 0 | 3 | 11 | 2 | 0 | 1 |
| 6. Transactions (§4.4, §20B.5, §18) | 24 | 0 | 0 | 3 | 12 | 9 | 0 | 1 |
| 7. Categories, tags, merchants (§4.5, §20B.6) | 10 | 0 | 0 | 1 | 7 | 2 | 0 | 0 |
| 8. Budgets (§4.6, §20B.7) | 11 | 0 | 1 | 2 | 6 | 2 | 0 | 1 |
| 9. Recurring & bills (§4.7, §20B.8) | 11 | 0 | 0 | 0 | 5 | 6 | 0 | 1 |
| 10. Subscriptions (§4.8, §20B.9) | 8 | 0 | 0 | 0 | 1 | 6 | 1 | 2 |
| 11. Receipts & storage (§4.9, §10, §20B.10) | 16 | 0 | 3 | 1 | 10 | 2 | 0 | 1 |
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
| 22. Search, settings, help (§4.20, §4.21, §20B.21) | 6 | 0 | 2 | 1 | 3 | 0 | 0 | 2 |
| 23. Data model (§5) | 4 | 0 | 1 | 1 | 2 | 0 | 0 | 0 |
| 24. API (§6) | 11 | 0 | 0 | 1 | 7 | 3 | 0 | 0 |
| 25. Clients (§7, §20B.23) | 23 | 0 | 1 | 3 | 14 | 4 | 1 | 22 |
| 26. Backend, database, jobs (§8, §9, §11, §20B.22) | 24 | 0 | 5 | 7 | 12 | 0 | 0 | 1 |
| 27. Security, privacy, operations (§12, §13) | 23 | 0 | 5 | 5 | 8 | 3 | 2 | 4 |
| 28. Testing, deployment, a11y, l10n (§14–§16) | 18 | 1 | 5 | 7 | 4 | 1 | 0 | 4 |
| 29. Critical workflows, docs, decisions (§18, §22, §23) | 12 | 0 | 1 | 2 | 6 | 3 | 0 | 0 |
| **Total** | **415** | **2** | **40** | **51** | **217** | **99** | **6** | **67** |

Status histogram for the whole matrix:

| Status | After the backend pass | After the client pass |
|---|---|---|
| NOT_STARTED | 42 | 2 (AUTH-014 optional OAuth/passkeys; PA-001 no analytics pipeline) |
| IN_PROGRESS | 52 | 40 |
| IMPLEMENTED | 50 | 51 |
| TESTED | 184 | 217 |
| VERIFIED | 83 | 99 |
| BLOCKED | 4 | 6 (adds MOB-005 push, PRIV-005 legal texts) |
| Total | 415 | 415 |

Client rows changed in this pass (old → new): 15 to VERIFIED (GEN-001,
GEN-004, GEN-005, DASH-008, BILL-003, SUB-004, SUB-007, IMP-002, ANL-008,
SOC-001, INT-001, WEB-002, WEB-003, WEB-008, WEB-013), 36 to TESTED, 3 to
IMPLEMENTED (AUTHZ-011, WEB-001, WEB-011), 2 to BLOCKED (MOB-005,
PRIV-005), DASH-002, SET-001, WEB-014 and TEST-003 from NOT_STARTED to
IN_PROGRESS. AUTH-011, DASH-001, RCPT-001, AI-001, HELP-001 and OPS-002
stay IN_PROGRESS and PA-001 stays NOT_STARTED, now with the missing
pieces named.

## Notable gaps and limitations (clients)

| Area | Gaps found in the P13 client pass |
|---|---|
| Mobile, all areas | No on-device integration tests; emulator runs were manual. iOS never built or run (no Xcode). No accessibility guideline checks (`meetsGuideline`) and no TalkBack/VoiceOver review. |
| Web, all areas | No axe tests; Playwright runs desktop Chrome only (tablet/phone widths untested); E2E is not in CI and covers journeys 1–10 and 13 only (TEST-003). No automated bundle scan. 183 of 7,725 strings lack Hindi. About ten small forms validate without a schema. |
| Auth & onboarding | Mobile sign-up form and mobile sign-out are untested. Neither client has the optional goals onboarding step; mobile onboarding has no week/month start or notification step. Cookie Secure/SameSite never asserted. |
| Dashboard | Budget, bills/subscriptions, goals and group-balance cards/widgets are not built on either client; web Home has no alerts card. Web last-updated time is not asserted. |
| Accounts & transactions | Account restore is untested on both clients and close on mobile; adding income is untested on both. |
| Budgets | Creation is one guided form, not a step-by-step wizard (BUD-010). |
| Receipts | Mobile creates one-page receipts only; camera capture itself is untested on mobile; web has no camera capture. |
| Communities | Fixed 2026-11-12: mobile `safeLink` now refuses `user:password@` links like web (COMM-005 now VERIFIED). |
| Integrations | Syncing, partial and failed labels are not asserted on either client. |
| Settings & help | No profile/preferences settings screen on either client (display name, avatar, bio, currency, time zone, locale, default account). Help is five short topics; no guides, troubleshooting or status link. |
| Notifications | Mobile push is not built (needs owner Firebase/APNs credentials). Web push depends on the owner's VAPID keys. |
| Product analytics | No analytics is collected (PA-001). Web onboarding copy corrected 2026-11-12 to say so, matching mobile. |
| By owner decision | AI client screens deferred (AI backend off by default). Staff screens (support queue, platform moderation, admin usage) are web-only. |

## Notable gaps and limitations (backend)

| Section | Gaps found in P13 |
|---|---|
| 1. Architecture | No seed data: `make seed` runs, but `supabase/seeds/` does not exist (ARCH-010). No `backend/`, `supabase/` or `contracts/` README. No web import-boundary lint rule found (ARCH-004). No documented hosted RLS verification step (ARCH-013). |
| 2. Authorization | The RLS inventory test checks that RLS is enabled on every table and that there are no PUBLIC grants. It does not check FORCE RLS, that each table has a policy, or function grants (AUTHZ-010, downgraded). Attaching another user's file to a transaction is not tested (AUTHZ-014). |
| 3. Auth & lifecycle | Deactivate/reactivate has no tests (AUTH-018). Security events are asserted only for email verification and the MFA alert (AUTH-017). Token expiry (verification, reset, access TTL) is not asserted. The storage purge on account deletion is not asserted, and the due job is enqueued by hand in the test. OAuth/passkeys are not built (optional). |
| 4–6. Dashboard, accounts, transactions | No tests for `/dashboard/widgets`, account balance history, include-in-overview, `POST /transactions/{id}/duplicate`, bulk delete, saved filters, location text or attachment endpoints. Replay of `POST /transactions` itself is not asserted. |
| 8. Budgets | Snooze and quiet hours are untested (BUD-007, downgraded). Current-period vs future-only edit semantics are untested (BUD-009, downgraded). No time-zone-change boundary test. Group/trip budget progress is not asserted. |
| 9–10. Recurring, subscriptions | The 7-day retry window for failed auto-posts is not asserted. DST is covered by unit tests only. Group-shared subscriptions are untested. Unused-subscription hints need a usage source (blocked). |
| 11. Receipts & storage | Multi-page and PDF receipts, date/total/merchant duplicate detection, extraction timeout and EXIF stripping are untested. There is no file scanner (`scan_status = skipped`) and no community-media file purpose. The Appwrite adapter is tested only against a double. |
| 12. Imports | XLSX is unit-tested only. Category assignment on import rows and a successful one-to-many reconciliation via the API are untested. No provider adapters exist. |
| 13. Analytics & reports | No payment-method distribution (ANL-002). The report generation timestamp and the timestamps of disclosed conversion rates are not asserted. |
| 14–15. AI & insights | Everything runs against a scripted fake model; live-model quality, injection resistance and latency are unverified. Not tested: forecast ranges, estimates, the disclosure text, deleting one conversation, two insight rules (subscription price increase, missing recurring payment) and the "resolved" action. Seasonal patterns are not modelled. |
| 17–18. Social & communities | Not tested: friend-request decline, invite-link expiry and max uses, community ownership transfer and archive, pinned posts, post search, pin/lock/unban/escalation actions, and 2 of 6 group and challenge types. Personal friend invite links and contact discovery do not exist. |
| 19. Notifications | Quiet hours are not tested anywhere. Mark-read, archive and read-all are untested. Live SMTP/VAPID/FCM delivery is unverified. |
| 20. Integrations | Token refresh and the 20-page sync cap are untested. Only a sandbox adapter exists; no real provider. |
| 26. Backend & jobs | No circuit breakers, tracing, admin job list, manual-retry endpoint, preview-generation or scanning jobs. Scheduler leader election and backoff timing are not exercised by tests. `domain/currency` has no unit tests, and there is no forecast domain package. |
| 27. Security & ops | DAST/pentest, staging load test and restore drill are not done (need a hosted environment). TLS/`sslmode` for the hosted database is not documented. |
| 28. Deployment | No mobile store-submission checklist (DEP-003). No per-feature release-gate checklist (TEST-005). CI has not been observed running. |
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

- Client gaps listed above (dashboard cards, profile/preferences settings,
  onboarding goals step, mobile multi-page receipts, E2E journeys 11–26,
  mobile on-device tests, iOS).
- Refresh the readiness report (DOC-002).
