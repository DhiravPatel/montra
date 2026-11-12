# Montra — Privacy

How Montra handles personal data (spec §3, §12, §20B). This is an
engineering description for the owner and reviewers, not the user-facing
privacy policy (the owner publishes that; `GET /legal` serves its
version). Retention periods are owner decisions (ADR-021).

## Principles

- **Free and minimal.** Every feature is free, and Montra collects only
  what a feature needs. There is no advertising, data sale or third-party
  tracking.
- **Owner-only by default.** Financial records are visible only to their
  owner. Sharing is explicit: household-shared accounts, group expenses
  and goal/budget collaborators. Enforcement is server-side plus RLS
  (docs/AUTHORIZATION_MATRIX.md, docs/RLS_POLICY_MATRIX.md).
- **No credential collection.** Montra never asks for bank passwords, UPI
  PINs, OTPs or CVVs, never reads SMS or notifications and never initiates
  payments. User content containing payment secrets is refused.
- **Consent before optional processing.** Consents are versioned rows in
  `user_consents` with grant and revocation times.

## Consents

| Consent | Enables | Default | Revocation effect |
|---|---|---|---|
| `terms`, `privacy_policy` | using the service (versioned) | required at sign-up | — (account deletion instead) |
| `ai_processing` | AI assistant, summaries, suggestions | off | AI turns off; history can be cleared |
| `ai_receipt_processing` | AI reading of receipt images | off | receipts stay manual |
| `marketing_email` | product news email | off | recorded only: Montra sends no marketing email today |
| `product_analytics` | aggregate product analytics | off | recorded only: no product analytics events are collected today (docs/METRICS.md defines financial metrics, not tracking) |
| `location` | storing a location text on transactions | off | location can no longer be saved |
| `contacts_discovery` | being found by contacts | off | recorded only: there is no contact upload or matching feature |
| `push_notifications` | push delivery | off | recorded only: push needs the OS/browser permission and a registered endpoint, which the user removes in settings |
| `integration` | one provider connection (purpose, scope, expiry) | per connection | sync stops; tokens deleted; optional data deletion |

Discovery by username is a separate profile setting (off by default).
Blocks hide people both ways.

## Data inventory

| Category | Examples | Where | Purpose | Retention |
|---|---|---|---|---|
| Identity | email, password hash (Argon2id), display name, username | `users`, `user_credentials`, `profiles` | sign-in, profile | until account deletion |
| Security | sessions (user agent, hashed IP), login attempts, security events, MFA factors (encrypted) | identity tables | account protection | sessions 90 d after end; login attempts 2 d; security events 1 y (configurable) |
| Financial records | accounts, transactions, budgets, goals, bills, subscriptions | finance and planning tables | the product | until the user deletes them or the account; voided transactions kept for audit until account deletion (ADR-021 amendment) |
| Documents | receipts, statements, attachments | storage (Appwrite hosted, local disk in development); `files` metadata | evidence, imports | until deleted; abandoned uploads rejected after 24 h; raw statement cells cleared 180 d after an import finishes |
| Social | group expenses, settlements, comments, friend links, community posts | social tables | shared features | while the group/community exists; anonymized after the author's deletion |
| AI | conversations, messages, usage counts (no prompts in `ai_usage`) | AI tables | assistant | 90 d (configurable) or until cleared |
| Notifications | in-app items, delivery state, push subscriptions (encrypted) | notification tables | alerts | until deleted; push endpoints removed when gone or on deletion |
| Integrations | consent, encrypted tokens, sync runs, webhook inbox (encrypted payloads) | integration tables | provider sync | tokens until disconnect; sync runs 180 d; webhook events 30 d |
| Exports and reports | generated files | storage + `data_exports`, `reports` | user downloads | 7 d (configurable) |
| Operations | request logs without bodies or personal values; metrics | logs, Prometheus | reliability | per hosting log retention (owner) |

## User rights

- **Access and export.** `POST /me/export` requires recent
  re-authentication. It builds a ZIP of JSON sections covering every
  personal table: profile, preferences, consents, sessions, security
  events, finance, files metadata, receipts, imports, reconciliation,
  planning, groups (own shares and payments), social, communities,
  challenges, notifications, AI history, insights, reports, search history,
  audit events and integration connections. It is downloadable through a
  signed, expiring link.
- **Correction.** Every record is editable by its owner. Edits are
  versioned and audited.
- **Deletion.** `POST /me/deletion-request` requires confirmation and
  recent re-authentication, and discloses consequences and retained
  records before it is accepted. It can be cancelled during the 7-day
  grace period. The worker then:
  1. asks integration providers to revoke access;
  2. revokes sessions, push endpoints and integration tokens;
  3. purges stored files;
  4. transfers or archives groups (ADR-022);
  5. deletes personal records;
  6. anonymizes community content, group shares and settlements
     ("Deleted member"), security records and audit records;
  7. notifies the original address.
- **Objection and restriction.** Optional processing can be revoked at any
  time through consents and preferences. Security and account emails are
  the only notifications that cannot be turned off.

## Processing safeguards

- **Encryption.**
  - TLS in transit (HSTS in production).
  - Application-level AES-256-GCM, with key IDs for rotation, for MFA
    secrets, push subscriptions, integration tokens and webhook payloads.
  - Database and storage encryption at rest are provided by the hosts.
- **Logs** never contain request bodies, amounts, merchants, descriptions,
  tokens or email addresses. IPs are hashed with a salt. Client logging
  follows the same rule.
- **AI**
  - Off unless the owner configures a provider and the user consents.
  - Requests carry the minimum context, redacted.
  - The model's tools are read-only and run as the user.
  - Prompts and answers are not logged; usage is counted (ADR-012, ADR-045).
  - The provider is disclosed in the consent text.
- **Notifications** carry safe summaries only, without amounts or
  merchants. Web Push payloads are end-to-end encrypted, and unsubscribe
  links carry signed tokens in the URL fragment.
- **Files.**
  - Private by default, served only through signed, expiring URLs after
    an ownership check.
  - Uploads are checked for size and content type.
  - No public links to receipts.
- **Integrations.** No provider is enabled until legal and security review
  (ADR-016). The India Account Aggregator flow needs FIU registration and
  compliance review first.

## Owner decisions still open

- Final retention periods (ADR-021), including whether voided
  transactions should be purged with a separately kept anonymized audit
  record.
- The hosting region and the subprocessors list (Supabase, Appwrite, email
  and push providers, an AI provider if enabled) for the published policy.
- Age limits and regional requirements (DPDP Act 2023 for India, and
  GDPR if EU users are targeted) — needs legal review.
