# Montra — Pre-production Readiness Report

Date: 2026-11-13. Audience: the owner and reviewers. Requirement DOC-002
(spec §22).

Sources:

- [`IMPLEMENTATION_STATUS.md`](IMPLEMENTATION_STATUS.md), test results
  log, round 8 being the latest entry;
- [`REQUIREMENTS_TRACEABILITY.md`](REQUIREMENTS_TRACEABILITY.md) (415
  rows), with the per-section roll-up in
  [`FEATURE_COVERAGE.md`](FEATURE_COVERAGE.md);
- the checks run for this report (last section).

Nothing here is claimed beyond what those records show. Agent reports
that were not re-run are marked as such.

## Verdict

**Not ready for a production launch.** The product is built and verified
locally on all three surfaces (Go API and worker, web, Android), against
a local PostgreSQL and test doubles for every provider. Nothing has run on
hosted infrastructure yet:

- no staging environment exists;
- iOS has never been built;
- no real provider has been contacted;
- the launch gates (staging load test, DAST, restore drill, legal review,
  store accounts) are all open.

Each is an owner action, listed below.

## What is verified (with evidence)

### Requirements

Status counts in `REQUIREMENTS_TRACEABILITY.md` on 2026-11-13; they
match the round-8 test-log entry:

| Status | Rows | Meaning (matrix legend) |
|---|---|---|
| VERIFIED | 116 | suite passed, assertions read, every clause covered |
| TESTED | 228 | tests exist and pass; the unasserted clauses are named in the row |
| IMPLEMENTED | 47 | code exists, no test evidence |
| IN_PROGRESS | 16 | partly done; the gap is named in the row |
| BLOCKED | 6 | needs an owner decision or credentials (SUB-008, MOD-004, INT-009, MOB-005, PRIV-005, PRIV-006) |
| NOT_STARTED | 2 | AUTH-014 (optional OAuth/passkeys), PA-001 (product analytics) |
| **Total** | **415** | 344 (83 %) TESTED or VERIFIED |

Nine of the ten documentation and guardrail rows this pass addressed
have moved in the round-8 re-check: ARCH-003, DEP-003, DEP-004 and
TEST-005 to IMPLEMENTED; ARCH-004, ARCH-013, DATA-003, DB-002 and DB-005
to TESTED. DOC-002 (this report) stays IN_PROGRESS until the hosted checks
exist.

### Tests (latest recorded runs)

| Area | Evidence | Date |
|---|---|---|
| Backend | `go test ./... -count=1` passed, all packages: unit tests, `tests/api`, `tests/rls` and `tests/seed` against local PostgreSQL 18.3 `montra_test`, 31 migrations applied from empty. The 2026-11-06 count was 139 top-level integration tests; rounds 6 to 8 added more (round 8: 31 coverage tests, so every one of the 424 operations has a Go test). golangci-lint 0 issues (depguard included), contract and docs checks clean. | 2026-11-13 (round 8) |
| RLS | `backend/tests/rls`: 12 tests (every table has RLS and no PUBLIC access, owner isolation, no identity sees nothing, group and household boundaries, append-only tables, discovery helpers, guard triggers, webhook inbox, masked hints) | round 8 |
| Web | Vitest 143 files / 1,353 tests. tsc, ESLint (module boundaries included), Prettier, `check:api`, `check:i18n` and `pnpm build` clean, no chunk over 500 kB. Playwright full run: 123 passed, 0 failed, 0 flaky (41 tests each on desktop, phone and tablet) against the live local API. | 2026-11-13 (round 8) |
| Mobile (Android) | `flutter test` 2,147 passed, `flutter analyze` clean, generated models current, import check ok, debug APK built. On-device `integration_test` journey on the Android emulator against the live local API: 3 of 3 runs passed in round 8 (7 of 8 in round 7, with one unreproduced 422 on `POST /transactions`). | 2026-11-13 (round 8) |
| Accessibility | axe WCAG A/AA (light and dark), reduced motion and no horizontal scroll in Playwright; jest-axe; Flutter accessibility guideline and large-text tests | 2026-11-12/13 |
| Load (local only) | `cmd/loadtest`, 10 users for 60 s: 1,190 requests, read p95 13 ms, write p95 12 ms, 0 errors. ADR-025 targets are read p95 < 500 ms and write p95 < 800 ms. This is a laptop baseline, not a capacity result. | 2026-11-04 |
| CI | `ci.yml` (validate only, never deploys). The `e2e.yml` workflow was added and its steps reproduced locally on a throwaway database. Neither has **run on GitHub** yet. | 2026-11-13 |

Every provider was replaced by a test double: local disk instead of
Appwrite, the dev mailbox instead of SMTP, a scripted fake model instead
of Anthropic, `httptest` stand-ins for Web Push, FCM and ECB, and a
sandbox bank adapter.

### Checked in this pass (2026-11-13)

- **Schema matches the migrations.** `docs/DATA_DICTIONARY.md` is now
  generated from `supabase/migrations` (`scripts/docs/gen_data_dictionary.py`,
  in `make docs`, `make docs-check` and CI). A read-only comparison with
  the live `montra_dev` catalog (applied migrations at the time: 001–028)
  found **0 differences**:

  | Compared | Count |
  |---|---|
  | Tables | 113 |
  | Columns (type, nullability, presence of a default) | 1,418 |
  | Constraints | 896 |
  | Indexes | 314 |
  | Policies (name, command, roles) | 331 |
  | Runtime-role privilege sets | 226 |
  | Triggers | 56 |

  Re-run after migrations 029 and 030 were applied (30 migrations): still
  **0 differences**, with 1,419 columns, 897 constraints and 315 indexes
  (the other counts unchanged).
- **Dependency boundaries are enforced.** The checks fail on a new
  violation, and each was proven with temporary violations that were then
  removed:
  - backend: depguard rules for domain, platform, apitypes, store, every
    feature and the composition root;
  - web: the `montra/module-boundaries` ESLint rule;
  - mobile: `tool/check_imports.dart`, in CI and `make check`.

  Today's deliberate cross-module imports are allowlisted explicitly:
  backend, 23 features with edges; web, 16 features (47 modules); mobile, 192
  feature-to-feature file imports and 11 core-to-feature imports.
- **Database role hygiene, read-only on `montra_dev`.**
  - The three `montra_*` roles have no superuser, BYPASSRLS, CREATEROLE
    or CREATEDB.
  - No table privilege exists for any other role.
  - PUBLIC has no USAGE on schema `montra`.
  - The only security-definer functions PUBLIC could execute are five
    trigger functions. They cannot be called directly and the schema is
    unreachable for PUBLIC, so this is noted, not a finding.
- **Query plans** for the high-volume reads were reviewed
  ([`QUERY_PLAN_REVIEW.md`](QUERY_PLAN_REVIEW.md)) as `montra_app` under
  RLS, first on the existing development data and then on the demo seed
  users; the findings were the same both times. Most are user- or
  group-bounded index scans. The review recommends:
  - a missing index for the group-expense list (`transactions.group_expense_id`)
    and the settlement links (`transactions.settlement_id`);
  - rewrites for global search and the budget list, which scan more rows
    than they return;
  - re-checks at staging volume.

  Applied on 2026-11-13 (QUERY_PLAN_REVIEW.md, "Applied"): indexes
  R1–R3 in migration `20261113000031`, the search rewrite R-A, the
  budget-list union R-B and the split first-page/cursor queries R-F, with
  new cursor-paging tests; R-E was not done. The staging re-check is
  still open.
- **Documentation** added:
  - `backend/`, `supabase/` and `contracts/` READMEs;
  - in DEPLOYMENT.md: hosted RLS verification (§1.2), TLS and
    `sslmode=verify-full` guidance (§1.1), and the Flutter store
    build/sign/release checklist (§5.1);
  - the per-feature release gate (TESTING.md).

## What is not verified

| Area | State | Why |
|---|---|---|
| Hosted database (Supabase) | Never provisioned. Role creation, the `extensions` schema grants and the Data API exposure are documented but not rehearsed. Hosted RLS verification has a written procedure (DEPLOYMENT §1.2) that has not been executed. | no hosted project |
| TLS to the database | Documented (`verify-full`) and enforced at start-up: in staging and production the backend configuration refuses a `DATABASE_URL` or `DATABASE_MIGRATION_URL` weaker than `verify-full` (config test, round 8). Never exercised against a hosted database. | no hosted project |
| iOS | Never built or run. No `PrivacyInfo.xcprivacy` in the Runner target, and the Associated Domains placeholder is `montra.example`. | Xcode and CocoaPods not installed (B-1) |
| Android release build | Only debug APKs were built. Release signing is not set up (no `key.properties`; the build would fall back to the debug key). | owner keystore |
| Providers | Appwrite storage, SMTP, Web Push (VAPID), FCM, Anthropic (live model) and the ECB feed have only been tested against fakes | credentials (B-3 to B-5) |
| Mobile push | Not built (MOB-005, BLOCKED): no Firebase SDK and no permission screen | owner Firebase project |
| Bank and account-aggregator integrations | Disabled. Only a sandbox adapter exists. | legal and compliance review (INT-009, PRIV-006, B-6) |
| e2e CI | `e2e.yml` has never run on GitHub. The mobile on-device journey passed 7 of 8 local runs. | needs a push to GitHub |
| Scale | Plans reviewed on development data only (a few hundred to a few thousand rows per table, demo seed). The only load figures are a local 10-user baseline. | no staging |
| Security testing | No DAST, no penetration test, no pentest plan (SEC-008). SAST and dependency scans run in CI (gosec, govulncheck, `pnpm audit`, gitleaks). | needs a hosted environment |
| Disaster recovery | Restore drill not done. PITR and backups are documented only. | needs a hosted environment |
| Legal | Privacy policy, terms, AI disclosure, cookie consent, age policy and cross-border transfer need legal review (PRIV-005). The subprocessor list waits for hosting choices (PRIV-004). Moderation response targets and escalation are owner decisions (MOD-004). | owner and counsel |
| Remaining product gaps | 16 IN_PROGRESS and 47 IMPLEMENTED rows. Examples: AI live-model evaluation (AI-016); seasonal anomaly patterns (ANOM-005); PDF statement imports and provider adapters (IMP-001); a community-media file purpose (STOR-010); tracing (OPS-004); a forecast domain package (BE-008); the help status link, which needs the owner's `STATUS_PAGE_URL` (HELP-001). | see the matrix rows |
| Working tree | The round-8 changes (demo seed, operator job views, coverage tests, provider circuit breakers, query-plan fixes, client features, migrations 029–031) are uncommitted. The round-8 checks ran on that working tree. The release commit must pass CI as committed. | in progress |

## Owner actions

Ordered by what unblocks the most.

1. **Accounts and environments.** Create a staging and a production
   Supabase project, Appwrite project and Go host in one region
   (DEPLOYMENT.md, Topology). Create the `montra_*` roles and the
   `extensions` grants (supabase/README.md), turn on "Enforce SSL",
   download the CA certificate and set `sslmode=verify-full` URLs in the
   secret store.
2. **Secrets.** Generate `DATA_ENCRYPTION_KEYS`, `URL_SIGNING_KEY`,
   `METRICS_TOKEN`, the VAPID keys and the role passwords in the host's
   secret manager. Provide SMTP, Appwrite and (optionally) Anthropic
   credentials. Never commit any of them, and never use the Supabase
   `postgres`/`service_role` credentials at runtime.
3. **Staging bring-up.** Apply the migrations (`migrate up -yes`). Run the
   hosted RLS procedure: `tests/rls` against a throwaway `_test` database,
   then the read-only catalog comparison (DEPLOYMENT §1.2). Deploy the
   API, worker and web, then run the smoke test and the per-feature
   release gate items H1–H2 (TESTING.md).
4. **Mobile.** Install Xcode and CocoaPods (B-1) and the Android
   cmdline-tools and licenses (B-2). Open the Google Play Console and
   Apple Developer accounts. Confirm `app.montra.mobile`. Create the
   upload keystore and Apple signing in the owner's keychain. Follow
   DEPLOYMENT §5.1 through internal testing and TestFlight.
5. **Domains and links.** Set the production web and API domains. Update
   the CSP `connect-src` in `web/vercel.json`, `-Pmontra.linkHost`, the
   iOS entitlements, `assetlinks.json` and the Apple app site association
   file.
6. **Legal.** Get the privacy policy, terms, AI disclosure, cookie and
   age policy, cross-border transfer and subprocessor list reviewed and
   published (PRIV-004, PRIV-005). Decide moderation response targets
   (MOD-004). Keep bank and aggregator integrations off until their legal
   review (INT-009, PRIV-006).
7. **Review the remaining query-plan items.** R1–R3 and the search,
   budget-list and cursor rewrites are applied (migration 000031,
   `docs/QUERY_PLAN_REVIEW.md` "Applied"); R4, R5, R-D and R-E wait for the
   staging load test.
8. **Push CI.** Run the `ci` and `e2e` workflows on GitHub and fix
   anything that differs from the local runs.

## Risks and what must happen before launch

| # | Risk | If ignored | Must happen before launch |
|---|---|---|---|
| R1 | Unknown performance at real volume | Slow lists and dashboards and pool exhaustion: the group-expense list scans `transactions` per row; global search and the budget list scan more than they return | The plan-review indexes and rewrites are applied (R1–R3, R-A, R-B, R-F); run a **staging load test** at the expected launch volume with seeded data. Meet ADR-025 targets and record the results. Re-run `EXPLAIN (ANALYZE, BUFFERS)` there. |
| R2 | Hosted RLS or grants differ from local | Cross-tenant data exposure | **Hosted RLS verification** (DEPLOYMENT §1.2, both parts) on staging. Repeat part B on production after every migration. |
| R3 | Plaintext or unverified database connections | Credential and data interception | `sslmode=verify-full` on every hosted URL, Supabase "Enforce SSL" on, the `pg_stat_ssl` check. The API and worker refuse to start in staging and production unless every database URL resolves to `verify-full` (`config.CheckDatabaseTLS`). |
| R4 | Untested security surface on the hosted stack | Exploitable issues found by users first | **DAST** against staging (authenticated and unauthenticated) and a penetration-test plan (SEC-008). Fix high and critical findings before launch. |
| R5 | Backups never restored | Unrecoverable data loss | **Restore drill**: PITR restore of staging into a new project, migrate status check, application smoke test. Record the RTO/RPO achieved (DISASTER_RECOVERY.md). |
| R6 | Legal and compliance exposure (personal finance data, India) | Regulatory action, store rejection | **Legal review** of the published policies, AI disclosure and age policy. Subprocessor list. Integrations stay off until reviewed. |
| R7 | Leaked or mishandled credentials | Account or data compromise | **Credentials** only in the host secret managers and the owner's keychain. Rotation procedure (DEPLOYMENT §7) rehearsed once. gitleaks stays in CI. No production credentials on developer machines. |
| R8 | Store rejection or a debug-signed build | Delayed launch, an un-updatable app | **Store accounts** opened. Release builds signed with the owner's upload key (verified with `keytool -printcert`). Data safety and App Privacy forms. iOS built and tested at least once on a device. |
| R9 | Provider behavior differs from the fakes | Lost emails, failed uploads, push not delivered | Owner-run provider checks (release gate H1) for Appwrite, SMTP and Web Push, and for FCM and AI if enabled. |
| R10 | CI never exercised on GitHub | A regression merges unnoticed | `ci` and `e2e` green on GitHub for the release commit (DEPLOYMENT §6, step 1). |
| R11 | iOS-specific defects | Crashes or broken flows for iOS users | iOS build, TestFlight and the smoke test. Accessibility checks with VoiceOver. |

Launch is a go only when R1–R8 and R10 have recorded evidence, R9 is done
for every enabled provider and R11 is done if iOS ships at launch. The
per-feature release gate in [`TESTING.md`](TESTING.md#per-feature-release-gate-test-005)
applies to every feature in the release.

## Checks run for this report (2026-11-13)

Recorded in the final verification of this pass:

- `make docs-check`;
- `golangci-lint run ./...` in `backend/`;
- `pnpm exec eslint . --max-warnings=0` in `web/`;
- `dart run tool/check_imports.dart` in `mobile/`;
- `python3 -B -m unittest scripts/docs/test_gen_data_dictionary.py`;
- the read-only data-dictionary comparison against `montra_dev`.

Results:

- docs check, data-dictionary unit tests (11), ESLint and the mobile
  import check: clean;
- golangci-lint: 0 issues, depguard included (an earlier run that day
  had 4 findings in the parallel agents' in-progress files; they were
  fixed before the final run);
- live comparison at migration `20261113000030`: 0 differences.

Round-8 refresh (2026-11-13), recorded by the main session after the last
code change (details in the IMPLEMENTATION_STATUS.md test log):

- backend `go test ./... -count=1`, golangci-lint, `make contract-check`
  and `make docs-check`: passed, 0 issues, ok, ok. The generated data
  dictionary now covers 31 migrations; the live comparison was not re-run
  after migration 000031;
- web Vitest, type checks, lint, `check:api`, `check:i18n`, build and the
  full Playwright run: passed (123 of 123);
- mobile format, generated-code and import checks, analyze, `flutter
  test`, debug build and the emulator journey: passed (journey 3 of 3);
- live: `GET /admin/jobs` paged real jobs, and a retry of a succeeded job
  returned 422 `job_not_retryable`.
