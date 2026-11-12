# Montra — Architecture Decision Records

This file is the decision log required by spec §22 (`DECISIONS/`) and §23
(open decisions). Each record lists the selected option, alternatives,
rationale, security/privacy implications, cost, reversibility, owner and
date. Decisions marked **OWNER** need confirmation or action by the product
owner; the selected option is the implementation default until changed.

Date format: ISO-8601. Author of initial records: implementation agent.

| ID | Title | Status |
|---|---|---|
| ADR-001 | Monorepo layout | Accepted |
| ADR-002 | Identity authority and session model | Accepted |
| ADR-003 | Database access, schema and RLS identity propagation | Accepted |
| ADR-004 | Forward-only SQL migrations and runner | Accepted |
| ADR-005 | Code-first OpenAPI 3.1 contract via Huma | Accepted |
| ADR-006 | Money representation and rounding | Accepted |
| ADR-007 | Append-only ledger balance model | Accepted |
| ADR-008 | PostgreSQL-backed durable job queue, outbox and scheduler | Accepted |
| ADR-009 | Appwrite storage via official Go SDK, backend-proxied transfer | Accepted |
| ADR-010 | Development-only local-disk storage adapter | Accepted (flagged to owner) |
| ADR-011 | Split runtime deployment topology | Accepted, OWNER picks host |
| ADR-012 | AI provider: Anthropic Claude, consent-gated, provider-off fallback | Accepted |
| ADR-013 | Receipt OCR approach | Accepted |
| ADR-014 | Email and push providers | Accepted, OWNER configures |
| ADR-015 | FX rate source | Accepted |
| ADR-016 | Bank / Account Aggregator integrations | Accepted (framework only) |
| ADR-017 | Web client stack | Accepted |
| ADR-018 | Mobile client stack | Accepted |
| ADR-019 | Supported statement import formats | Accepted |
| ADR-020 | Launch country, age policy, data residency | Proposed, OWNER |
| ADR-021 | Retention periods | Proposed, OWNER |
| ADR-022 | Group data after member deletion | Accepted |
| ADR-023 | Personal vs group spending attribution | Accepted |
| ADR-024 | Support/security contacts, brand, moderation ownership | Proposed, OWNER |
| ADR-025 | SLOs and capacity assumptions | Proposed, OWNER |
| ADR-026 | Recurring schedules, occurrences and bills | Accepted |
| ADR-027 | Subscriptions and explainable detection | Accepted |
| ADR-028 | Goal contributions and cross-user notifications | Accepted |
| ADR-029 | Statement imports | Accepted |
| ADR-030 | Receipt extraction and review | Accepted |
| ADR-031 | Reconciliation effects | Accepted |
| ADR-032 | Contract conventions (from client feedback) | Accepted |
| ADR-033 | Exchange rates and conversion policy | Accepted |
| ADR-034 | Report generation and user-scoped worker reads | Accepted |
| ADR-035 | Group balances and the settlement lifecycle | Accepted |
| ADR-036 | Linked personal records for group activity | Accepted |
| ADR-037 | Social discovery and minimal profiles | Accepted |
| ADR-038 | Invitation tokens never appear in URLs | Accepted |
| ADR-039 | Group activity notifications | Accepted |
| ADR-040 | Recurring shared bills | Accepted |
| ADR-041 | Community content safety and spam controls | Accepted |
| ADR-042 | Moderation model, sanctions and appeals | Accepted |
| ADR-043 | Challenge privacy and leaderboards | Accepted |
| ADR-044 | Guard triggers behind permissive update policies | Accepted |
| ADR-045 | AI integration design | Accepted |
| ADR-046 | Insight rules and thresholds | Accepted |
| ADR-047 | Notification channel delivery, digests and unsubscribe | Accepted |
| ADR-048 | Integration framework mechanics | Accepted |
| ADR-049 | Development-only email verification bypass | Accepted |
| ADR-050 | Fair-use limits, storage allowance and operator dashboard | Accepted |

---

## ADR-001 Monorepo layout

- **Decision:** single Git repository with top-level areas:
  `backend/` (Go API, worker, migrator, domain packages), `web/` (React +
  TypeScript portal), `mobile/` (Flutter app), `contracts/` (generated
  OpenAPI contract + generated client artifacts), `supabase/` (SQL
  migrations, RLS, seeds, database tests), `storage/` (Appwrite bucket and
  permission definitions), `infra/` (container build, deployment templates),
  `scripts/` (bootstrap, dev, test), `docs/`, `.github/workflows/` (CI).
- **Alternatives:** `apps/*` + `packages/*` workspace layout; separate repos.
- **Rationale:** mirrors spec §1.2 and §7/§8 suggested structures with clear
  ownership per toolchain; each area keeps its native tooling (Go modules,
  pnpm, pub) without a polyglot build system.
- **Boundaries:** web and mobile depend only on `contracts/`; backend domain
  packages never import transport/UI code (enforced by package layout and
  `depguard` lint rules).
- **Reversibility:** high. **Owner:** engineering. **Date:** 2026-11-04.

## ADR-002 Identity authority and session model

- **Decision:** the **Go backend is the single identity authority**. It
  owns registration, credential verification (Argon2id), email
  verification, password reset, TOTP MFA with recovery codes, session
  issuance, refresh-token rotation with reuse detection, and revocation.
  - Access tokens: opaque 256-bit random tokens, stored only as SHA-256
    hashes in `user_sessions`, 15-minute lifetime. Every request validates
    the session row, so revocation is immediate.
  - Refresh tokens: opaque 256-bit, rotated on every refresh, 30-day
    sliding / 90-day absolute lifetime; presenting a superseded refresh
    token revokes the whole session (theft detection).
  - **Web:** tokens are delivered only as `HttpOnly; Secure; SameSite=Lax`
    cookies (`montra_at` scoped to `/api`, `montra_rt` scoped to the refresh
    path). Unsafe methods authenticated by cookie require a double-submit
    CSRF token (`montra_csrf` cookie + `X-CSRF-Token` header). Tokens are
    never placed in `localStorage`.
  - **Mobile:** tokens returned in the response body; the refresh token is
    stored in Keychain/Keystore via `flutter_secure_storage`; the access
    token lives in memory only.
  - **Supabase RLS identity propagation:** the backend sets the
    transaction-local setting `montra.user_id` (see ADR-003). Clients never
    talk to Supabase directly, so no Supabase Auth JWTs are minted.
  - **Appwrite mapping:** no Appwrite end-user identities are created. All
    objects are owned by the backend's server key; access is mediated by
    the backend (ADR-009).
  - **Account deletion:** revokes all sessions, consents, integration
    tokens and file access tokens before the durable deletion job runs.
- **Alternatives:** Supabase Auth (GoTrue) as authority — rejected because
  local development may not run a Supabase stack (spec §1.3A.1) and two
  identity code paths would diverge; Appwrite Auth — rejected for the same
  reason plus dual-identity risk.
- **Security:** single place for brute-force controls and audit; opaque
  tokens avoid JWT key-management and algorithm-confusion classes of bugs.
- **Optional OAuth/passkeys (§4.1):** not provided by a third-party IdP
  under this decision; may be added later as backend features
  (WebAuthn via `go-webauthn`). Tracked as REQ-AUTH-014 (optional).
- **Reversibility:** medium (migrating identities later is possible via the
  stable internal `users.id`). **Owner:** engineering. **Date:** 2026-11-04.

## ADR-003 Database access, schema and RLS identity propagation

- **Decision:** `pgx/v5` + `pgxpool`, hand-written parameterized SQL in
  repository packages. All tables live in schema **`montra`** (not `public`),
  so Supabase's PostgREST does not expose them by default.
- **Roles:** `montra_owner` (migrations; owns objects), `montra_app` (API
  runtime, DML only, RLS enforced), `montra_worker` (background worker, DML
  only; RLS policies grant it system scope because jobs span users — worker
  code still performs explicit authorization). No runtime role is a
  superuser or has `BYPASSRLS`.
- **RLS identity:** every API database transaction starts with
  `select set_config('montra.user_id', $1, true)` (transaction-local, safe
  with transaction-mode poolers). Policies call `montra.current_user_id()`.
  Group/community policies use `SECURITY DEFINER` helper functions
  (`montra.is_group_member(...)`) with a pinned `search_path`.
- **Query layer (revised 2026-11-04 after owner asked about Drizzle):**
  Drizzle ORM was evaluated and rejected because it runs only in
  TypeScript and the backend is fixed to Go; the owner asked for the best
  Go-native option instead. Selected: **sqlc** (type-safe Go generated from
  plain SQL, checked against the migration schema at generate time) for
  static queries, plus hand-written parameterized pgx for dynamic filters
  (search, reports). No ORM: financial queries need explicit SQL, locking
  (`FOR UPDATE`) and RLS context control. Integration tests against real
  PostgreSQL verify every query.
- **Supabase notes:** use the session-mode pooler or direct connection for
  the long-lived Go service; if the transaction pooler is used, configure
  pgx `QueryExecModeExec`/simple protocol. Avoid PostgreSQL ≥16-only
  features; migrations target PostgreSQL 15+ (local server is 18.3).
- **Reversibility:** medium. **Owner:** engineering. **Date:** 2026-11-04.

## ADR-004 Forward-only SQL migrations and runner

- **Decision:** plain SQL files in `supabase/migrations/` named
  `YYYYMMDDHHMMSS_description.sql` (Supabase CLI convention). Applied by
  `backend/cmd/migrate`, which: prints target host/database first, takes a
  PostgreSQL advisory lock, applies each pending file in its own
  transaction, records version + SHA-256 checksum in
  `montra.schema_migrations`, and refuses to run if an applied file's
  checksum changed. No down migrations (forward-only, spec §20B.24).
- **Reset safety:** `migrate reset` only works on databases whose name ends
  in `_test` or `_dev` **and** requires `--confirm <dbname>`.
- **Alternatives:** goose/golang-migrate (down sections risk being executed
  by Supabase CLI), Supabase CLI (not installed; requires Docker for local).
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-005 Code-first OpenAPI 3.1 contract via Huma

- **Decision:** HTTP handlers use **Huma v2** on a **chi** router. Huma
  derives OpenAPI 3.1 from typed Go input/output structs and validates every
  request against that schema before the handler runs. The generated
  contract is exported by `backend/cmd/openapi` to
  `contracts/openapi/montra.v1.json`, committed, and CI fails on drift.
  Web types are generated with `openapi-typescript` (`web`: `pnpm gen:api`,
  drift check `pnpm check:api`); Dart models are generated by the pure-Dart
  generator `mobile/tool/gen_api.dart` (`--check` fails on drift) from the
  same file. (Corrected 2026-11-04: an earlier draft named a non-existent
  `backend/cmd/contractgen`.)
- **Schema names:** Huma registers every Go type by its bare name, so
  types exposed in the contract must be unique across packages (for
  example `RecurringRuleDTO`, `SubscriptionDTO`, `GoalDTO`); a collision
  fails at startup and in tests.
- **Envelope:** success `{"data": …, "meta": {"request_id", "timestamp",
  "next_cursor?"}}`; error `{"error": {"code", "message", "details",
  "request_id"}}` (spec §6). Error codes are a closed enum documented in
  `docs/API.md`.
- **Compatibility:** `/api/v1` is stable; breaking changes require
  `/api/v2` or additive evolution; CI runs a breaking-change diff against
  the last release tag of the contract.
- **Alternatives:** hand-written YAML + kin-openapi validation (high drift
  and duplication), swaggo (OpenAPI 2.0).
- **Date:** 2026-11-04.

## ADR-006 Money representation and rounding

- **Decision:** money is `int64` minor units plus ISO 4217 code. The
  currency registry stores exponent (0, 2, 3 — e.g. JPY, INR, KWD). API
  responses carry `amount_minor` (integer), `amount` (exact decimal string)
  and `currency`; requests carry `amount` as a decimal string that the
  server parses exactly, rejecting excess precision, NaN/Inf, signs where
  not allowed and values above 10^15 minor units.
- **Rounding:** currency conversion rounds half away from zero at the
  target exponent; the rounding delta is stored. Split allocation uses
  deterministic largest-remainder distribution ordered by participant
  position, then user ID.
- **Never** `float32/float64` for money in Go, TypeScript or Dart.
- **Date:** 2026-11-04.

## ADR-007 Append-only ledger balance model

- **Decision:** `account_ledger_entries` is the authoritative balance
  source. Every posted transaction writes signed entries (expense −,
  income +, transfer −source/+destination, fee −, refund +, adjustment ±,
  opening balance ±). Edits never update entries: they append reversing
  entries and new entries in the same database transaction. Balance =
  `SUM(amount_minor)` per account; balance history = running sum by
  effective date. Credit-card and loan accounts carry liabilities as
  negative balances; card payments are transfers, so expenses are counted
  once at purchase.
- **Derived aggregates** (rollups/caches) are disposable and never
  override ledger truth.
- **Date:** 2026-11-04.

## ADR-008 PostgreSQL-backed durable job queue, outbox and scheduler

- **Decision:** `jobs` / `job_attempts` tables with
  `FOR UPDATE SKIP LOCKED` claiming, lease expiry (visibility timeout),
  exponential backoff with full jitter, max attempts → `dead` status,
  manual retry, priorities, per-type concurrency limits, unique
  `dedupe_key` for idempotent enqueue, cancellation. Domain writes insert
  `outbox_events` in the same transaction; the worker relays them to jobs.
  The scheduler runs in the worker under a PostgreSQL advisory-lock leader
  election and enqueues periodic jobs with time-bucketed dedupe keys, so a
  restart or duplicate scheduler never double-runs and missed runs are
  recovered on start.
- **Alternatives:** Redis/asynq, SQS, Cloud Tasks — extra infrastructure,
  cost and failure modes; can be swapped behind the `jobs` interface later.
- **Date:** 2026-11-04.

## ADR-009 Appwrite storage via official Go SDK, backend-proxied transfer

- **Decision:** production adapter uses `github.com/appwrite/sdk-for-go`
  v1.0.0 (Appwrite response format 1.8.0) with a server API key held only
  by the backend. Buckets: `private-user-docs`, `group-docs`,
  `public-media`, `temp-processing`, `exports` (see
  `docs/DEPLOYMENT.md` §2; names in `backend/internal/platform/config/config.go`). All buckets: file security on, no
  client permissions, encryption on, antivirus on where available.
- **Upload:** client requests an upload intent → backend authorizes and
  returns a single-use upload URL on the **backend** → backend validates
  size, magic bytes, extension, checksum and image limits, then writes to
  Appwrite → metadata committed → processing job enqueued.
- **Download:** `GET /files/{id}/access` re-authorizes and returns a
  short-lived (≤5 min) backend-signed URL that streams the object; no
  permanent public links. Appwrite file tokens (`Tokens.CreateFileToken`)
  are supported by the adapter for direct short-lived access where the
  owner enables it.
- **Local development:** the adapter is never called locally (ADR-010);
  its logic is unit-tested with a deterministic HTTP test double. Live
  verification is an owner-controlled hosted activity.
- **Date:** 2026-11-04.

## ADR-010 Development-only local-disk storage adapter

- **Context:** spec §1.3A.8 requires local development without Appwrite,
  and forbids presenting an in-memory fake as Appwrite. Receipt, import and
  export workflows still need bytes to exist locally to be developed and
  end-to-end tested.
- **Decision:** `STORAGE_PROVIDER=local_disk` stores objects under an
  ignored directory (`.data/storage`). The server **refuses to start** with
  this provider unless `APP_ENV` is `development` or `test`. `/health/ready`
  and the integrations status page label it "Local development disk — not
  Appwrite". It is not in-memory, not used in hosted environments, and
  never reported as Appwrite connectivity.
- **Flag for owner:** if you prefer storage features to be disabled
  locally instead, set `STORAGE_PROVIDER=disabled` (uploads return
  `STORAGE_UNAVAILABLE`).
- **Date:** 2026-11-04.

## ADR-011 Split runtime deployment topology

- **Decision:** React portal on **Vercel** (static build + SPA rewrites).
  Go API and Go worker as two processes from one container image on a
  Go-compatible always-on runtime (candidates documented in
  `docs/DEPLOYMENT.md`: Fly.io, Render, Google Cloud Run + always-on worker
  instance, AWS ECS/Fargate). Supabase and Appwrite remain managed
  services. Vercel serverless is not used for workers or schedulers.
- **OWNER:** choose the Go host and region (recommend the same region as
  the Supabase project, e.g. `ap-south-1` Mumbai for India launch).
- **Date:** 2026-11-04.

## ADR-012 AI provider

- **Decision:** Anthropic Claude via the Messages API, model configurable
  (`AI_MODEL`, default `claude-opus-5-5` — changed from Sonnet on
  2026-11-04; the owner may set a cheaper model). AI is off until the
  user grants `ai_processing` consent; the provider can also be disabled
  globally (`AI_PROVIDER=disabled`). Deterministic services compute every
  number; the model only phrases explanations over a minimal, aggregated,
  redacted context and returns schema-validated JSON. Provider-off mode
  returns deterministic summaries with `source: "deterministic"`. The
  provider is never silently switched; changing it requires a new consent
  version.
- **Date:** 2026-11-04.

## ADR-013 Receipt OCR approach

- **Decision:** layered extraction: (1) deterministic local parser for
  text-layer PDFs and plain text (no external call); (2) Claude vision
  extraction for images/scanned PDFs **only** with explicit
  `ai_receipt_processing` consent; (3) manual entry fallback always
  available. All candidates are stored separately with per-field confidence
  and require user review before any transaction is created.
- **Date:** 2026-11-04.

## ADR-014 Email and push providers

- **Decision:** email via a generic SMTP adapter (works with SES, Postmark,
  Resend, SendGrid SMTP relays; STARTTLS required). In development,
  `EMAIL_PROVIDER=dev_mailbox` writes `.eml` files to `.data/mail/` (never to
  logs). Web push via VAPID (RFC 8030/8292). Native push via FCM HTTP v1
  adapter. **OWNER** supplies SMTP credentials, VAPID keys and Firebase
  project configuration; until then those channels report `not_configured`
  and in-app notifications remain fully functional.
- **Date:** 2026-11-04.

## ADR-015 FX rate source

- **Decision:** manual rates (user-entered, with provenance) are always
  available. Optional ECB euro reference-rate adapter (`FX_PROVIDER=ecb`)
  fetches daily rates via the durable scheduler. Every conversion stores
  rate, source, timestamp and direction; historical rates are never
  rewritten.
- **Date:** 2026-11-04.

## ADR-016 Bank / Account Aggregator integrations

- **Decision:** implement the provider-agnostic integration framework
  (registry, consent records, encrypted token storage, refresh/revoke,
  webhook HMAC signature + timestamp + replay verification, dedupe, sync
  cursors, normalization, health). **No bank, UPI or Account Aggregator
  provider is enabled**: each requires legal/compliance review, provider
  agreements and credentials (spec §4.18, §20B.19). The registry lists
  candidate providers with status `unavailable` and the reason (amended
  2026-11-04, ADR-048; the earlier `requires_review` label was never
  implemented).
- **Never** collect bank passwords, UPI PINs, OTPs or CVVs; no SMS reading;
  no payment initiation.
- **Date:** 2026-11-04.

## ADR-017 Web client stack

- Vite, React, strict TypeScript, React Router, TanStack Query,
  React Hook Form + Zod, Tailwind CSS, Radix primitives for accessible
  dialogs/menus, Recharts (with data-table equivalents), `openapi-fetch`
  with types generated by `openapi-typescript`, Vitest + Testing Library,
  Playwright for E2E, ESLint (typescript-eslint, jsx-a11y) + Prettier.
- **Date:** 2026-11-04.

## ADR-018 Mobile client stack

- Flutter with Riverpod (state), go_router (navigation/deep links), dio
  (HTTP, auth refresh interceptor, upload progress, cancellation),
  flutter_secure_storage (refresh token), intl + ARB (localization),
  fl_chart (charts with semantic summaries), image_picker/file_picker
  (receipts), Dart models generated from the OpenAPI contract.
- **Date:** 2026-11-04.

## ADR-019 Supported statement import formats

- **Decision:** CSV (UTF-8/UTF-8 BOM/UTF-16/Windows-1252), XLSX (cached
  values only — formulas and macros are never executed; `.xlsm` rejected),
  OFX/QFX 1.x (SGML) and 2.x (XML), text-layer PDF statements with
  mandatory row review. Parser versions are recorded per batch.
- **Date:** 2026-11-04.

## ADR-020 Launch country, age policy, data residency (OWNER)

- **Proposed:** India-first launch, multi-currency from day one (INR
  default for IN locale, never assumed). Minimum age **18**, because
  India's DPDP Act 2023 requires verifiable parental consent for minors'
  data and the product processes financial data. Data residency: Supabase
  and Appwrite projects in an India region where available; document
  cross-border transfer for the AI provider (consent-gated).
- **OWNER:** confirm launch countries, age policy and residency.

## ADR-021 Retention periods (OWNER)

- **Proposed defaults:** deleted-account data purged within 30 days
  (grace period 7 days, cancellable); soft-deleted transactions purged
  after 90 days; temporary processing files 24 h; export files 7 days;
  import raw rows 180 days; security events 1 year; audit events 7 years
  for financial records (anonymized after deletion); AI conversation
  history 90 days or until the user clears it. Configurable via env.
- **Amendment (2026-11-04, P12):**
  - Enforced by `platform.retention_cleanup` and `files.cleanup`, and
    tested (`TestRetentionCleanupEnforcesConfiguredWindows`):
    - AI history (`RETENTION_AI_HISTORY`, conversations deleted);
    - raw statement cells of finished imports (`RETENTION_IMPORT_RAW_ROWS`,
      cells cleared; parsed values, links and fingerprints kept);
    - abandoned uploads (`RETENTION_TEMP_FILES`);
    - security events;
    - export/report files (`RETENTION_EXPORT_FILES`);
    - the deletion grace period.
  - **Soft-deleted transactions are not purged after 90 days.** Purging
    would also delete their audit trail (which cascades), contradicting
    the 7-year financial audit default above, and would break restore.
    Voided transactions carry no balance effect and are removed with the
    account. The unused `RETENTION_SOFT_DELETED_TX` setting was removed.
    **OWNER** decides whether a purge with a separately retained,
    anonymized audit record is wanted.

## ADR-022 Group data after member deletion

- **Decision:** a deleted user's group expense shares and settlements are
  retained so other members' balances stay correct, but the identity is
  replaced by an anonymized "Deleted member" placeholder. Deletion is
  blocked (with explanation) only for sole owners of groups with other
  members until ownership is transferred or the group is archived; the
  deletion workflow offers automatic transfer to the longest-standing
  admin/member.

## ADR-023 Personal vs group spending attribution

- **Decision:** a personal `group_expense` reference transaction moves the
  full paid amount through the payer's ledger but counts only the payer's
  own share as personal spending; the remainder is a group receivable.
  `settlement` transactions move money but are excluded from income and
  expense. Analytics scope `personal` uses personal transactions; scope
  `group` uses group shares; scope `all` adds group shares not already
  linked to a personal transaction, so nothing is double counted.
  Documented in `docs/METRICS.md`.

## ADR-024 Support/security contacts, brand, moderation ownership (OWNER)

- Contacts are configuration (`SUPPORT_EMAIL`, `SECURITY_EMAIL`) with
  placeholder example values. Domain/trademark clearance and community
  moderation staffing/response targets require owner decisions before
  public communities open.

## ADR-025 SLOs and capacity (OWNER)

- Planning targets from spec §13: 99.5 % monthly API availability, read p95
  < 500 ms, write p95 < 800 ms; job classes documented in
  `docs/BACKGROUND_JOBS.md`. Capacity assumption for initial sizing: 10k
  monthly active users, 2M transactions.

## ADR-026 Recurring schedules, occurrences and bills

- **Decision:** a rule stores the recurrence (domain `recurrence`, derived
  from the start date so month ends never drift); the scheduler
  (`recurring.generate`, every 15 min, advisory-lock elected) materializes
  occurrences **35 days ahead**, unique per (rule, date). Creating, resuming
  or editing ("this and future") a rule generates from the later of the
  start date and today, so the past is never back-posted; open future
  occurrences are regenerated, while posted, paid, skipped and linked ones
  are history.
- **Posting:** auto-post rules (fixed amount + account; expense, income or
  same-currency transfer) post when due. The occurrence row is locked
  (`FOR UPDATE SKIP LOCKED`) and stores the transaction ID, and a
  transaction can satisfy one occurrence (unique index), so retries,
  repeated deliveries and concurrent schedulers never duplicate. A missed
  run is recovered by the next run regardless of age. A domain failure
  (e.g. archived account) is recorded on the occurrence, the owner is told
  once, and posting is retried for 7 days before the occurrence becomes
  overdue for the user.
- **Bills** are a bill row plus a rule of kind `bill`. Bills are never
  auto-posted and never marked paid because a date passed: the user links
  the recorded payment (suggested candidates) or records a new one; an
  unpaid occurrence becomes overdue after its due day. Reminders and
  overdue notices are sent once per occurrence (dedupe keys).
- **Alternatives:** generating transactions directly from the rule (no
  occurrence rows) loses skip/postpone/edit-this and duplicate protection;
  an RRULE library adds DST ambiguity the domain package handles
  explicitly.
- **Reversibility:** medium. **Date:** 2026-11-04.

## ADR-027 Subscriptions and explainable detection

- **Decision:** subscriptions are their own records (not recurring rules)
  so they work with no bank data. Renewal dates are expectations, advanced
  by `subscriptions.renewals` (anchored at the next renewal date, keeping
  the original month-end billing day). Costs are normalized exactly
  (`money.MulRatio`, rounding half away from zero).
- **Detection** (`domain/subdetect`): per merchant (or normalized
  description) and currency over 400 days; median interval must fall in a
  cadence band (weekly 6–8, monthly 27–33, quarterly 84–98, semiannual
  174–190, yearly 352–378 days); ≥ 3 charges (yearly ≥ 2); ≥ 75 % of
  intervals in band; ≥ 60 % of amounts within 5 % of the median; last
  charge within 1.5 cycles. Confidence = 0.45·interval + 0.35·amount +
  0.20·count scores, reported when ≥ 0.6, with human-readable reasons and
  the evidence transaction IDs. A stable fingerprint (merchant, currency,
  cadence) means dismissed and confirmed candidates are never suggested
  again. Confirming creates the subscription and records the evidence as
  payment history; detection never edits transactions.
- **Cancellation:** recorded only with explicit `confirm=true`; Montra
  never claims to cancel. "Unused" hints are BLOCKED until an authorized
  integration provides usage evidence.
- **Reversibility:** high (thresholds are constants). **Date:** 2026-11-04.

## ADR-028 Goal contributions and cross-user notifications

- **Decision:** goal progress = starting amount + recorded and verified
  contributions − withdrawals, computed exactly from contribution events.
  A contribution is `verified` only when it links the caller's ledger
  transaction, and a transaction can back one active contribution (no
  double counting). Planned contributions are not counted. Targets can
  change without touching contributions; withdrawals cannot exceed the
  saved amount (serialized per goal with an advisory transaction lock).
- **Sharing:** owners add friends or group co-members as contributor or
  viewer; each member chooses how others see their contributions (amounts,
  percent only, hidden — always counted in totals); others never see a
  member's ledger references; leaving keeps past contributions.
- **Notifications to other users** are written only by the worker:
  `notifications` has owner-only RLS, so API transactions emit outbox
  events (`goal.changed`, `goal.member_added`) and worker jobs notify the
  owner and members once per milestone. The same rule applies to every
  module (budget alerts, reminders).
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-029 Statement imports

- **Decision:** parsing is a worker job over a pure package
  (`domain/statement`): CSV (UTF-8/BOM/UTF-16/Windows-1252 detection,
  delimiter sniffing), XLSX (first sheet, cached cell values only — formulas
  are never evaluated — 64 MiB expansion cap against zip bombs), OFX/QFX
  (SGML and XML). Limits: 20 000 rows, 64 columns, 1 000 characters per cell,
  10 MiB files. PDF statements are refused until a reviewed extraction path
  exists (P9).
- **Rows:** every source row is stored with its original line number and
  status (`skipped` header/preamble, `invalid` with a reason, `ready`,
  `duplicate`, `imported`, `failed`); nothing is dropped silently. Rows are
  re-derived when the mapping changes (decisions reset).
- **Duplicates:** fingerprint = SHA-256 of account, date, direction,
  amount, bank ID / reference / normalized description and an occurrence
  index within the file (identical genuine rows stay distinct; re-importing
  the same file reproduces the same fingerprints). A unique
  `(account_id, source_fingerprint)` index makes double import impossible
  even across concurrent batches. Exact matches (fingerprint or bank
  transaction ID) cannot be forced; possible duplicates (same amount and
  direction, close date, similar text) default to skip and can be imported
  explicitly.
- **Processing:** confirmation is idempotent (Idempotency-Key); each row is
  imported in its own transaction with the row locked; failures are
  recorded per row and retried on request; cancellation is checked between
  rows; rollback voids only transactions unchanged since import.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-030 Receipt extraction and review

- **Decision:** extraction runs behind an `Extractor` interface (method,
  provider, model, version recorded on every extraction). Until a provider
  is configured (P9: AI vision with consent), receipts go straight to manual
  review and `process` returns `FEATURE_NOT_CONFIGURED` — no fake values.
- Candidates (with per-field confidence, line items and warnings) are never
  used as financial data. The user's review is stored as a new extraction
  version (`manual`), so the machine reading is preserved; only reviewed
  values can create a transaction. Long digit runs in payment hints are
  masked to the last four digits. Duplicates (same file checksum, or same
  date/total/currency/merchant) are flagged, never merged.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-031 Reconciliation effects

- **Decision:** matches are always user-confirmed. Each match item records
  its effect (`none`, `voided`, `row_skipped`) and the previous row and
  reconciliation states, so unmatching restores exactly what was there
  (voided pending/duplicate transactions are restored through the ledger).
  Partial unique indexes keep a transaction or statement row in at most one
  active match. One-to-many and many-to-one matches require exactly equal
  sums. Balance reconciliation compares a statement balance (or amount owed
  for liabilities) with the ledger as of the date and marks transactions
  reconciled only when balanced.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-032 Contract conventions (from client feedback)

- List `data` is never null (`httpx.OK` normalizes nil slices); error
  `code` is a closed enum; every operation declares its error statuses
  (including 503) and references shared header components
  (`X-Montra-Client`, `X-Client-Version`, `X-CSRF-Token`, `X-Request-ID`,
  `Retry-After`). Schema names are unique across packages. Breaking
  changes to these conventions require a contract version bump.
- **Date:** 2026-11-04.

## ADR-033 Exchange rates and conversion policy

- **Decision:** `fx_rates` stores observations; nothing is updated in
  place except a user re-entering a manual rate for the same timestamp.
  Lookup order: the user's manual rate, then provider rates (ECB reference
  rates, EUR base, fetched by `fx.refresh` only when `FX_PROVIDER=ecb`),
  then the inverse pair. Policies: `historical` (latest rate on or before the
  amount's date) and `current` (latest rate). Analytics converted views use
  the latest rate on or before the window end and disclose every rate.
  Conversions use exact rationals with half-away-from-zero rounding and
  report the rounding delta. No cross rates through a third currency yet.
- **Alternatives:** storing converted amounts on transactions (rewrites
  history when rates change); paid FX APIs (cost).
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-034 Report generation and user-scoped worker reads

- **Decision:** reports store a filter snapshot and are generated by the
  `reports.generate` job from the same analytics layer as the dashboard.
  Because the worker role bypasses RLS, the worker opens a second, small
  pool with the application role (`DATABASE_URL`) and reads report data as
  the report owner (`identity.With` + `WithUserReadTx`), exactly like the
  API. Without that pool the worker refuses to generate reports (fail
  closed). Files are private (`exports` area), downloaded through 5-minute
  signed links, and expire after `RETENTION_EXPORT_FILES` (7 days);
  `retention.cleanup` marks them expired and file cleanup removes the
  objects. Limits: 100 000 transaction rows; PDF up to 5 000 rows (larger:
  CSV/XLSX). PDF uses the standard Helvetica font (characters outside
  Latin-1 are replaced; ₹ becomes "Rs") until a Unicode font is embedded.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-035 Group balances and the settlement lifecycle

- **Decision:** balances are recomputed on every read from expense payers
  and shares (all non-deleted expenses, including disputed ones, which stay
  counted until resolved, edited or deleted) plus **confirmed** settlements
  only. Payments reported by the payer (`user_reported_paid`) are shown as
  `pending_in`/`pending_out` and count once the payee confirms; a payee who
  records a receipt confirms it in the same step. Lifecycle: `proposed` →
  `mark_paid` (payer) → `user_reported_paid` → `confirm` (payee) →
  `confirmed`; either party disputes a reported or confirmed settlement
  (`disputed`, not counted; the payee's confirmation resolves it); either
  party or an admin voids with a mandatory reason; a correction voids the
  original (reason "Corrected") and links the new record through
  `corrects_settlement_id`. Partial amounts and overpayments are allowed
  (user-reported records). `verification` is always `user_reported`; no
  payment is ever initiated. Suggestions (`/settlement-suggestions`) are
  read-only: simplified (greedy, deterministic) when the group simplifies
  debts, otherwise pairwise original debts; `/balances` returns both.
  Former members keep their shares, appear by snapshot name and can be
  settled with; leaving requires a zero balance and deleting a group
  requires all balances settled.
- **Amendment (2026-11-05, removed members):** an admin may remove a member
  with an open balance. The removed member's records stay, so their
  balance stays in balances, both debt views, suggestions and reports
  (`member_status: removed`), and any member can record a settlement with
  them; because they can no longer confirm, a payment to them is confirmed
  by an admin on their behalf (`confirmed_by` the admin, still
  `user_reported`). Pairwise original debts round each proportional part
  with a controlled rounding (rows add up to shares, columns to what each
  payer paid), so the original and simplified views add up to the same
  totals as the net balances.
- **Reversibility:** medium (counting rule is a product decision).
  **Date:** 2026-11-04.

## ADR-036 Linked personal records for group activity

- **Decision:** a payer may record their payment of a group expense in one
  of their own accounts (`payer_account_id` on create, or
  `POST /groups/{id}/expenses/{expenseId}/my-record` later). The record is a
  `group_expense` transaction: the full paid amount moves through the
  ledger, `personal_share` is the payer's own share (ADR-023). Settlement
  parties may record theirs (`settlement` type; payer outflow once paid,
  payee inflow once confirmed). These records can only be changed through
  the group workflows. When another member edits or deletes the expense,
  or voids the settlement, the worker (`groups.sync_expense`,
  `groups.sync_settlement`) updates the record in place (reversing and
  re-posting ledger entries, version + 1, audit actor `system`, reason in
  the change set) or voids it, and notifies the owner; the transaction
  keeps its ID so attachments and reconciliation links survive. The caller's
  own record is voided inside the request; other members' records are
  invisible to the caller (RLS), which is why the worker does it. Other
  members never see anyone's linked record (`my_transaction_id` is the
  caller's only).
- **Reversibility:** medium. **Date:** 2026-11-04.

## ADR-037 Social discovery and minimal profiles

- **Decision:** RLS keeps other users' `users` rows invisible and hides
  profiles by visibility, so discovery uses narrow SECURITY DEFINER helpers
  that require an identity and honour blocks in both directions:
  `search_discoverable` (prefix search on usernames with LIKE wildcards
  escaped; opted-in, active users only), `discoverable_user_id` (exact
  username for friend requests and group invitations), `user_is_active`,
  `friend_request_allowed` (the addressee's everyone / friends of friends /
  nobody control) and `minimal_profile` (display name, username and avatar
  only — never bio, finance data or balances — for friends, pending
  requests, current or former co-members, join requesters seen by the
  group's admins, pending invitations, or opted-in users). The full profile
  row (bio) stays governed by `can_view_profile`. Blocks look like a missing
  user (404) to both sides; muting suppresses that person's notifications.
  Social endpoints use the `social` rate-limit policy (burst 15, ~30/min).
- **Amendment (2026-11-05, migration 000022):**
  - `search_discoverable` matches the exact username only
    (case-insensitive, a leading `@` ignored), never a prefix, for both
    `GET /users/search` and the users section of `GET /search`.
  - Discovery is opt-in: `profiles.discoverable_by_username` defaults to
    false for new accounts; existing settings are unchanged.
  - `blocked_user_profile` lets a blocker see the display name and username
    (only) of the people they blocked, for `GET /blocks`; everything else
    stays hidden both ways and the blocked person learns nothing.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-038 Invitation tokens never appear in URLs

- **Decision:** group invitation link tokens are secrets (stored hashed,
  shown once), so clients send them in request bodies:
  `POST /group-invitations/preview` and `POST /group-invitations/accept`
  with `{token}`. Username invitations are addressed by ID
  (`/group-invitations/{invitationId}/accept|decline`). This deviates from
  the spec's suggested `/group-invitations/{token}/accept` path to keep
  tokens out of access logs and proxies; shareable links should carry the
  token in the URL fragment (`#token=…`), which browsers do not send to
  servers. `POST /groups/{id}/members` adds by username by creating an
  invitation (membership always needs the person's acceptance).
- **Amendment (2026-11-05, join approval and friends):**
  `require_join_approval` (default now false; migration 000023 sets
  existing groups to false because it was never enforced) applies to
  invitation links: accepting one creates a join request for the admins
  (202) instead of joining, and the request remembers its
  `invitation_id`. Username invitations name the person and always join
  directly. People are invited by username only when they opted into
  username discovery, or by `user_id` when they are the inviter's friend
  (discovery off or not); anyone else answers 404. The link preview shows
  the group (ID, name, type, member count), who created the link and
  whether approval is needed; a link between people who blocked each other
  is invalid (410).
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-039 Group activity notifications

- **Decision:** every group change appends to the append-only activity log
  and emits `group.activity`; the worker fans each event out by audience
  (all members, admins, the affected member, people involved in the
  expense, or the settlement's parties), never to the actor, honouring each
  member's level (`all`, `important` = settlements, disputes, role and
  membership changes, `none`). Removal reaches the removed member and
  invitations reach the invitee regardless of level. Titles name the group
  and people but never amounts or descriptions. Join requests from
  non-members are logged by the worker (the requester cannot write to the
  group), and a member's departure is logged before their membership ends.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-040 Recurring shared bills

- **Decision:** household bills reuse the recurring engine: a
  `group_expense` rule with `group_id` stores the schedule and amount, and
  its `group_split` holds the split template (equal, exact, percentage or
  shares; itemized is refused because items change every time). Rules are
  managed only through `/groups/{id}/recurring-expenses` (creator or admins
  change, pause, resume, stop or skip; any member adds a due occurrence);
  the personal `/recurring-rules` and occurrence endpoints never return or
  act on them. With `auto_add`, the scheduler (`recurring.generate`, step
  2b through `recurring.Service.GroupPoster`) adds each due occurrence once,
  as the rule's creator, under a row lock (`skip locked`) with the
  occurrence → expense link recorded; missed runs are recovered. A domain
  failure (e.g. a participant left) is recorded once
  (`first_failed_at`), the creator is notified, and the occurrence becomes
  overdue for a member to fix and add. Without `payers` in the template,
  whoever adds the expense pays (the creator when added automatically).
  Group occurrences appear on members' calendars and are excluded from the
  creator's personal recurring commitments.
- **Reversibility:** medium. **Date:** 2026-11-04.

## ADR-041 Community content safety and spam controls

- **Decision:** community text is plain text, never HTML. `domain/textsafe`
  normalizes it (line endings; control, bidi-override, zero-width and soft
  hyphen characters removed; blank-line runs capped), enforces rune
  limits, refuses payment secrets (Luhn-valid card numbers; labelled CVV,
  PIN, OTP; assigned passwords) and accepts resource links only as https
  URLs with public DNS host names (no IP literals, localhost, `.local`,
  credentials, or non-ASCII hosts — punycode only). Clients must render
  community text escaped. Spam controls: the `social` rate-limit policy;
  20 posts / 300 comments per day (3 / 30 and no links for accounts younger
  than a day); duplicate post titles per community per day and identical
  comments within 10 minutes are refused; at most 3 links per text;
  3 communities and 10 challenges created per day; content from blocked
  users is hidden both ways. Verified-guidance labels are moderator-only.
- **Reversibility:** high (limits are constants). **Date:** 2026-11-04.

## ADR-042 Moderation model, sanctions and appeals

- **Decision:** reports (post, comment, profile, group, community) are
  deduplicated per reporter and target (20 per day). Post/comment reports
  go to the community's moderators; profile, group and community reports,
  and escalations, go to Montra staff (`platform_role` support/admin). Once
  three different people report published content it is hidden pending
  review (automatic action, author notified). Every decision is a
  `moderation_actions` row plus an audit event: hide/remove/restore,
  pin/lock, warn, timed restriction, ban/unban, dismiss, escalate. Only the
  owner (or staff) acts on moderators; nobody bans the owner; reasons are
  required for anything that affects a person and are shown to them, the
  moderator's identity is not. Account-wide sanctions are staff actions with
  no community (`montra.my_community_sanction`). Actions are reversible
  (record kept with `reversed_at`); the affected person may appeal within
  30 days once per action; another moderator or staff decides, and
  overturning reverses the action. Restoring content dismisses its reports.
  Moderators only ever act on community content and membership.
  Response-time targets and staffing remain owner decisions (ADR-024).
- **Reversibility:** medium. **Date:** 2026-11-04.

## ADR-043 Challenge privacy and leaderboards

- **Decision:** challenges measure days, streaks, milestone counts or a
  self-reported percentage — never money. Scopes: private, group,
  community (members join) and public (curated by staff only). Progress is
  private by default; `share_progress` lets other participants see it and
  `show_on_leaderboard` (which requires sharing) adds the person to the
  leaderboard, which ranks by percentage of the target and shows only name,
  percentage, current streak and completion. Check-in notes stay private.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-044 Guard triggers behind permissive update policies

- **Decision:** several P8 update policies allow a user to update their own
  row (`with check (true)` or own-row checks). BEFORE UPDATE triggers
  (SECURITY DEFINER) now restrict what non-moderators/non-admins may
  change: community and group memberships (no self-promotion, no
  self-unbanning, no clearing restrictions, rejoining only with approval or
  a validated invitation), community posts and comments (only deleting
  one's own; no re-publishing, pinning, locking or verified labels) and
  invitations (only status/use progress; never the target group,
  community, invitee or token). The worker (no identity), moderators,
  admins and staff are governed by the policies. A wrong column reference
  in the original community membership insert policy was fixed in
  migration 000014. Tests: `tests/rls` TestCommunityAndGroupGuards.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-045 AI integration design

- **Decision:** a small `llm.Provider` boundary with one implementation on
  the official Anthropic Go SDK (`anthropic-sdk-go/v2`, v2.5.0). Calls use
  the Messages API beta surface so every request carries the default
  server-side refusal fallback (`server-side-fallback-2026-07-01`,
  `fallbacks: "default"`); the answering model is recorded. Thinking is
  left at the model default (adaptive on Claude Opus 5.5) and depth is set
  with `output_config.effort` per feature (medium for questions, low for
  classification, receipts, statements and narratives). Final answers use
  structured outputs (strict object schemas with sorted required keys so
  request bytes and schema caches stay stable); grounding tools are strict,
  read-only functions over deterministic services executed as the caller;
  the tool loop is append-only (assistant turns replayed unchanged, all
  tool results in one user turn, at most 4 rounds). Conversations are
  replayed as quoted text, never as raw model turns, so no thinking blocks
  are carried across requests. The stable system prompt is cached; per-user
  data is in the user turn, with untrusted text fenced. Answers are
  verified: facts must match the named tool's output, significant numbers
  in prose must occur in tool output, and product/credit/tax advice or
  promises are removed; failures fall back to deterministic answers.
  `metadata.user_id` is an HMAC of the user ID. Usage (tokens, estimated
  cost from list prices, latency, outcome) is recorded without payloads.
  AI operations complete within the request (45 s timeout); there is no
  `/ai/jobs` endpoint — long-running AI work (receipts, PDF statements)
  is tracked on its own resource. Tests use a scripted fake model and an
  `httptest` fake of the API; no network call is made in tests.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-046 Insight rules and thresholds

- **Decision:** insights are deterministic rules over the user's own
  history, recorded once per fingerprint and suppressible: unusual amount
  (≥ 3× the category median and above its 95th percentile, ≥ 8 prior
  transactions in 180 days), category spike (this month so far above the
  average of the previous 3 months, with 3 months of history), first
  purchase at a merchant ≥ 2× the median expense (≥ 10 prior expenses),
  possible duplicate (same account and amount within 2 days, same merchant
  or text), subscription price increase (recorded change), missing
  recurring payment (overdue occurrence), cash-flow change (early in the
  month: spending +25 % or income −20 % vs the previous 3 months) and
  subscription cost visibility (≥ 3 subscriptions, normalized monthly and
  yearly). Rules compare within one currency, net refunds out of spending,
  and never call anything fraud or act on it. Budget pace is covered by
  budget alerts. A daily job runs the rules and notifies up to three new
  notable insights per user.
- **Added (2026-11-05):**
  - **Unusual frequency:** at least 4 purchases at one merchant in 7 days,
    and at least 3× that merchant's weekly average over the previous 12
    weeks, with at least 6 prior purchases. Fires at most once per merchant
    per ISO week.
  - **Recurring amount change:** the latest payment of a fixed-amount
    recurring rule differs by 10 % or more from the median of up to 6
    earlier payments (at least 2). Subscriptions are excluded because they
    have their own price-change insight.
  - **Repeated budget overspend (savings):** spending above the limit in
    at least 2 of the last 3 closed periods. Spend is computed by the
    canonical budget calculation (`budgets.RecentOutcomes`). The insight
    shows average spend and overspend, two options with their trade-offs,
    and the assumption "past periods only".
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-047 Notification channel delivery, digests and unsubscribe

- **Context:** spec §4.17 and §20B.18 need in-app, web push, email and
  native push with preferences, digests, unsubscribe, durable delivery and
  no sensitive previews, using only free standards-based channels.
- **Decision:**
  - **Web Push** follows RFC 8291 (aes128gcm, a fresh ECDH key and salt
    per message) and RFC 8292 (ES256 VAPID JWT, 12 h expiry, `aud` = push
    service origin). TTL is 24 h; `Urgency` is `high` for high/critical
    notifications. Endpoints must be HTTPS on an allowlist of browser push
    services (FCM, Mozilla, Apple, Windows), so Montra never posts to an
    arbitrary URL (SSRF). Subscriptions are encrypted at rest. 404/410
    disable the endpoint (`endpoint_gone`); 429/5xx retry through the job;
    other 4xx count failures and disable the endpoint after 5.
  - **FCM** uses the HTTP v1 API with a service-account JWT bearer grant
    (cached access token, refreshed on 401). `UNREGISTERED` disables the
    token.
  - **Payloads** carry only the title, body, app path, notification ID and
    category. Emitters write titles and bodies as safe summaries without
    amounts, merchants or descriptions.
  - **Email digest:** optional categories wait for the digest when the
    user chose a daily/weekly digest (or the category digest is set) and
    the notification is not high/critical. An hourly scan sends at 08:00
    local time (weekly: Mondays), once per user-hour (dedupe key), listing
    titles only (15 shown).
  - **Unsubscribe:** optional emails carry a link whose HMAC-signed token
    (user, category, 60-day expiry) travels in the URL fragment, so it
    never reaches servers or logs. `POST /notifications/unsubscribe` needs
    no sign-in. Security/account categories cannot be turned off, and
    invalid or expired tokens get 410.
  - **Security alerts** (password and two-step changes) keep their
    dedicated email and also appear in the notification center as
    in-app-only notifications, so they are not emailed twice.
  - Channels without owner credentials report `skipped/not_configured`;
    in-app always works.
- **Consequences:** live delivery needs owner-provided SMTP, VAPID and
  Firebase credentials. Locally, channels are tested against local
  stand-ins (an `httptest` TLS push service that decrypts payloads as a
  browser would).
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-048 Integration framework mechanics

- **Context:** ADR-016 requires a provider-agnostic framework with no
  provider enabled. This records how it behaves.
- **Decision:**
  - **Adapters** implement `Info`, `AuthorizeURL`, `Exchange`, `Refresh`,
    `Revoke`, `Fetch` (cursor pages) and `VerifyWebhook`. An adapter is
    registered only with real credentials. Known providers without one
    are listed `unavailable` with the reason.
  - **Connect** needs explicit consent (purpose, scope, duration), recorded
    in `user_consents` (`integration`, scope `<provider>:<connection>`),
    and creates a pending connection bound to a one-time OAuth state. Only
    the state's hash is stored, it is valid for 30 minutes, and it is
    bound to the signed-in user. The callback claims the state atomically
    before the code exchange, so it is single-use even under replay or
    concurrency.
  - **Tokens** are sealed with the keyring (AES-GCM, AAD
    `integration:<connection>`) and never returned.
  - **Sync**
    - Runs as durable jobs, one at a time per connection, up to 20 pages
      per run with a stored cursor.
    - Items are keyed `<provider>:<connection>:<provider id>`, unique per
      account among live rows. Voided rows count as seen, so a
      transaction the user deleted is never re-created.
    - Pending→posted keeps the ledger as it is (pending already counts)
      and is audited with actor `integration`. Reversed items are voided,
      except linked transfers and items with refunds. Unseen reversals and
      currency mismatches are skipped.
    - Provider errors end a run as `partial` or `failed` with counts.
    - Connections are synced every 6 h. Lapsed consent stops syncing and
      notifies the owner once. Runs abandoned for more than 2 h are failed
      so they stop blocking.
  - **Webhooks**
    - `POST /webhooks/{provider}` (public, ≤ 256 KiB, rate limited).
      Signature and timestamp checks belong to the adapter;
      `VerifyHMAC` implements `t=<unix>,v1=<hex>` over `<t>.<body>` with
      a ±5 min window.
    - Events go into an inbox (encrypted payload, SHA-256), deduplicated
      on (provider, event ID). Invalid ones are quarantined and answered
      401.
    - The API role can insert into the inbox but not read it, and queues
      processing only through `montra.enqueue_webhook_event`, which
      accepts verified, waiting events only (the API role cannot queue
      jobs without a user).
    - The worker routes events by the stored provider connection
      reference. Events for revoked or unknown connections are `ignored`.
      Events still waiting after 5 minutes are re-queued.
  - **Disconnect** needs `confirm=true`. It revokes at the provider (best
    effort), deletes tokens and the cursor, revokes the consent and, with
    `delete_data=true`, voids the transactions the connection imported.
- **Consequences:** a real provider needs an adapter, credentials, legal
  and security review (ADR-016) and a webhook secret in the secret store.
  Until then every flow is exercised by a test-only sandbox adapter.
- **Reversibility:** high. **Date:** 2026-11-04.

## ADR-049 Development-only email verification bypass

- **Context:** local development has no real email. Verification emails
  land in the dev mailbox (`backend/.data/mail`), which slows down manual
  testing of sign-up and sign-in.
- **Decision:**
  - `AUTH_DEV_AUTO_VERIFY_EMAIL=true` marks a new account verified at
    sign-up (no email is sent) and verifies an existing unverified account
    at sign-in.
  - Each use records an `email_verified` security event with
    `method: development_bypass`, and the API logs a warning at start-up.
  - Configuration refuses the setting unless `APP_ENV=development`, and
    refuses `AUTH_REQUIRE_EMAIL_VERIFIED=false` outside development and
    test, so neither can reach staging or production.
  - Local setups enable it by default (`scripts/db/bootstrap.sh`
    template); `backend/.env.example` documents it as `false`.
- **Consequences:** sign-up responses are unchanged (still
  enumeration-safe). Verification flows stay covered by tests that run
  with the bypass off (`APP_ENV=test`).
- **Evidence:** `TestDevelopmentEmailVerificationBypass` and
  `TestEmailVerificationBypassIsDevelopmentOnly`.
- **Reversibility:** high. **Date:** 2026-11-05.

## ADR-050 Fair-use limits, storage allowance and operator dashboard

- **Context:** spec §17 requires every feature to be free, with
  transparent fair-use controls and an operator cost dashboard.
- **Decision:**
  - The same limits apply to everyone, with no tiers or upgrade paths.
    `GET /limits` shows them alongside the caller's usage.
  - Storage cost is bounded by a per-user allowance
    (`STORAGE_USER_QUOTA_BYTES`, default 2 GiB). It counts uploads in
    flight at their declared size; exceeding it returns
    `storage_quota_exceeded` with the used and allowed bytes.
  - Operators see aggregate usage through `GET /admin/usage`, for platform
    admins only. It runs as a SECURITY DEFINER function that returns
    counts only, never rows, identifiers or personal values.
  - Spend alerts live in `ops/prometheus/alerts.yml`.
- **Consequences:** the default allowance is an owner decision (OWNER may
  raise or remove it; `0` disables the cap).
- **Reversibility:** high. **Date:** 2026-11-05.
