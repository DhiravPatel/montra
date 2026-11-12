# Montra — Threat Model

STRIDE review of the system in docs/ARCHITECTURE.md (2026-11-04, after
P10). Each threat lists its mitigations, with the code and tests that
show them, and any residual risk. The owner should revisit this before
launch and after any provider is enabled.

## Assets and trust boundaries

- **Assets:**
  - users' financial records and documents;
  - credentials and sessions;
  - group balances and settlements;
  - community content;
  - provider tokens;
  - encryption, signing and VAPID keys;
  - the audit trail.
- **Boundaries:**
  1. Browsers and mobile apps → API (untrusted clients).
  2. API and worker → PostgreSQL (RLS-enforced app role; worker role).
  3. API and worker → storage (Appwrite hosted; local disk in development).
  4. Worker → outbound providers (SMTP, Web Push services, FCM, the AI
     provider, the ECB feed, integration providers).
  5. Providers → webhook endpoint (untrusted, signed).
  6. Operators → hosting consoles and secret stores (owner-controlled).

## Spoofing

| Threat | Mitigations | Evidence |
|---|---|---|
| Credential stuffing / brute force | Argon2id; per-IP and per-account login throttling with `Retry-After`; account lock after repeated failures; optional Turnstile captcha | `TestAuthRateLimit`, login throttling tests |
| Session theft | Short-lived access tokens; refresh tokens hashed and rotated with reuse detection that revokes the family; HttpOnly, Secure, SameSite cookies on web; secure storage on mobile; sign out everywhere | auth suites |
| Second-factor bypass or TOTP replay | TOTP with used-step tracking; single-use recovery codes; recent re-authentication for sensitive operations | `TestMFAEnrollmentLoginReplayAndRecovery` |
| Account enumeration | Registration and forgot-password answer identically; existing accounts get an "account exists" email | auth suites |
| OAuth callback forgery (integrations) | Random state stored hashed, bound to the user, 30-minute window, claimed atomically (single use) | `TestIntegrationConsentOAuthSyncWebhooksAndDisconnect`, `TestIntegrationFailedExchangeAndAbandonedRuns` |
| Forged provider webhooks | Adapter signature verification (HMAC, ±5 min), dedupe on event ID, quarantine + 401 | same suite; `TestWebhookInboxIsWriteOnlyAndQueuingIsNarrow` |

## Tampering

| Threat | Mitigations | Evidence |
|---|---|---|
| Changing another user's records (IDOR) | Ownership checked in services, plus RLS on every table; invisible objects answer 404 | `tests/rls`, cross-user 404 assertions in each API suite |
| Group or community privilege escalation | Role checks in services; guard triggers on members, invitations and community tables | `TestCommunityAndGroupGuards` |
| Concurrent edits / lost updates | `version` checks (`VERSION_CONFLICT`); row locks on financial writes | finance suites |
| Duplicate financial writes | Idempotency keys (24 h, request hash); natural unique keys (occurrences, external IDs, webhook events, job dedupe) | finance, planning and integration suites |
| CSRF on cookie sessions | Double-submit CSRF token on unsafe methods; SameSite cookies; strict CORS allowlist | auth suites |
| Ledger manipulation | Append-only ledger and audit tables for the API role; balances derived from entries | `TestAppendOnlyTables` |
| Spreadsheet formula injection in exports | Formula-safe CSV/XLSX writers | `internal/reports/render` tests |

## Repudiation

| Threat | Mitigations |
|---|---|
| Disputed financial or moderation actions | Append-only `transaction_audit_events`, `audit_events`, `group_activity_events`, `group_expense_revisions` and moderation actions (with reversal records); request IDs on every entry; security events for sign-ins and credential changes |

## Information disclosure

| Threat | Mitigations | Evidence |
|---|---|---|
| Cross-user data leaks | RLS everywhere; owner-only defaults; shared reads only for explicitly shared household accounts. In P12 the group-read policy was narrowed so linked personal records stay owner-only (000016), with matching explicit checks in services | `TestHouseholdSharedAccountIsReadOnlyForMembers`, `TestGroupLinkedPersonalRecordsStayInSync` |
| Profile scraping through discovery | Opt-in discovery (off for new accounts); exact-username search only, no partial matches; definer helpers return minimal profiles; blocks hide both ways; rate limits | `TestDiscoveryHelpersExposeOnlyMinimalProfiles`, `TestSocialExactSearchOptInListsAndCodes` |
| Document exposure | Private storage; signed, expiring, user-bound URLs; `nosniff`; type sniffing on upload; no public receipt links | files suites |
| Secrets in logs | Structured logs without bodies or personal values; sensitive keys redacted by the logging handler; hashed IPs; mobile safe-log interceptor | `TestLogsNeverContainPersonalValues` (production logger at debug level across auth, finance, groups, AI, webhooks and worker jobs) |
| Sensitive notification previews | Safe-summary titles and bodies; encrypted Web Push payloads; titles-only digests | notification suites; the apitest notification text guard runs in every API test |
| AI data leakage or prompt injection | AI off by default; consent; minimal redacted context; untrusted text fenced; read-only tools run as the caller; output verification; no prompt logging | `tests/api/ai_test.go` (injection, redaction, cross-user isolation) |
| SSRF through user-supplied URLs | Push endpoints only on an allowlist of push-service hosts over HTTPS; links in community content are displayed, never fetched; provider URLs come from configuration | `TestWebPushEncryptedDeliveryRetriesAndGoneEndpoints` |
| Provider tokens at rest | AES-256-GCM with per-row AAD; never returned by the API | integration suite asserts the ciphertext has no token text |

## Denial of service

| Threat | Mitigations |
|---|---|
| Request floods | Token-bucket rate limits per policy (default, auth, write, upload, AI, export, social); body limits (webhooks 256 KiB); request timeouts |
| Expensive parsing | Import limits: rows, cell sizes, XLSX zip-bomb guard, fuzzed parsers; background processing with timeouts |
| Job queue exhaustion | Per-type concurrency and timeouts; dedupe keys; bounded fan-out; dead-lettering |
| AI cost abuse | Per-user daily request cap; deterministic fallback |
| Webhook floods | Rate limit plus quarantine. Invalid bodies dedupe by digest; the inbox is cleaned after 30 days |

## Elevation of privilege

| Threat | Mitigations | Evidence |
|---|---|---|
| Unintended public endpoints | Explicit public allowlist enforced by a test | `TestAuthorizationInventory` |
| Staff-only actions | `httpx.Staff` role check; platform sanctions only by staff | moderation suite |
| API role escaping RLS | App role has no DDL, no BYPASSRLS, no PUBLIC grants; SECURITY DEFINER helpers have fixed `search_path`, narrow inputs and outputs, and require an identity | `TestEveryTableHasRLSAndNoPublicAccess` |
| Worker misuse | The worker processes only queued work; user-scoped report reads go through the RLS-enforcing app pool | reports suite |

## Residual risks and owner actions

- **Before launch:** load tests against a staging environment, a
  DAST/pentest pass and a backup/restore drill (P12 tasks still open).
  Secret and dependency scanning already run in CI.
- **Provider credentials** (SMTP, VAPID, FCM, AI key, integration
  secrets) must live only in the hosting secret stores and be rotated per
  docs/OPERATIONS.md.
- **Integrations:** enabling any provider requires legal and security
  review (ADR-016) and an adapter-specific threat review (token scopes,
  webhook scheme).
- **Turnstile:** captcha is off until configured; until then
  registration relies on rate limits and email verification.
- **Notification copy:** every API test now checks every notification it
  causes for amounts and currency. User-entered names (budget, goal and
  group names) can still appear by design.
- **Abuse moderation** depends on staffing response targets (MOD-004,
  owner).
