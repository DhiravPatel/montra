# Changelog

Unreleased development history by phase (docs/IMPLEMENTATION_PLAN.md).
Dates are 2026-11-04 unless noted. Detailed evidence is in
IMPLEMENTATION_STATUS.md.

## P12 — Security, reliability, operations (in progress)

- **RLS:** other people's transactions are visible only in accounts
  explicitly shared with their household (migration 000016). Services
  check the same rule explicitly.
- **Retention:** AI history, raw statement cells and abandoned-upload
  windows are now enforced. Webhook events and integration sync runs are
  cleaned up. The unused soft-deleted-transaction purge setting was
  removed (ADR-021 amendment).
- **Account deletion** asks integration providers to revoke access.
- **Inventory tests:** a job inventory test (every periodic job has a
  handler) and an authorization inventory test (an explicit public
  operation allowlist).
- **Container image** (`backend/Dockerfile`), built by CI and never pushed.
- **Docs added:** DATA_MODEL, RLS_POLICY_MATRIX (generated),
  AUTHORIZATION_MATRIX (generated), BACKGROUND_JOBS (generated),
  THREAT_MODEL, PRIVACY, DEPLOYMENT, RUNBOOKS, INCIDENT_RESPONSE,
  DISASTER_RECOVERY, INTEGRATIONS and the root README.

## P11 — Clients (in progress)

- Web and mobile screens for the personal-finance core are being built
  (round 1).

## P10 — Notifications and integrations

- **Web Push:** RFC 8291/8292, a push-service allowlist, gone-endpoint
  cleanup.
- **Other channels:** FCM HTTP v1; email digests; signed one-click
  unsubscribe; security alerts in the notification center.
- **Integration framework:** consent, single-use OAuth state, encrypted
  tokens, cursor syncs, webhooks with quarantine and a narrow definer
  queue, disconnect with data deletion.

## P9 — AI and insights

- **Claude adapter:** official Go SDK, structured outputs, strict
  read-only tools, refusal fallback.
- **Assistant:** grounded Q&A with verification, consent-gated receipt
  and PDF statement readers.
- **Insights:** deterministic insight rules.

## P8 — Social, groups, communities

- **Social and groups:** friends, groups, shared expenses (five split
  methods), settlements, disputes, linked personal records, recurring
  shared bills.
- **Communities:** communities, moderation and challenges, with guard
  triggers.

## P7 — Analytics and reports

- **FX:** manual and ECB rates.
- **Analytics and reports:** display-currency analytics; reports in
  CSV/XLSX/PDF/JSON with schedules and signed downloads.

## P6 — Receipts, imports, reconciliation

- Statement imports (CSV/XLSX/OFX), receipts pipeline, reconciliation.

## P5 — Budgets and planning

- Budgets, recurring rules and bills, subscriptions with detection,
  goals, planning calendar.

## P4 — Personal finance

- Accounts, payment methods, categories, tags, merchants, transactions,
  transfers, dashboard analytics.

## P3 — Authentication and account lifecycle

- **Sign-in:** registration with verification, sessions with refresh
  rotation, TOTP two-step verification.
- **Account lifecycle:** profile and preferences, consents, export,
  deletion.

## P0–P2 — Foundation

- **Monorepo:** Go API and worker foundation, migrations with RLS on every
  table, web and mobile foundations.
- **Process:** CI, ADRs and the traceability matrix.
