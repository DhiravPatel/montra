# Montra — Financial Integrations

Montra is manual-first. Every feature works with manual entry, statement
imports and receipts. The integration framework exists so that an
authorized provider can be added safely later (ADR-016, ADR-048). **No
provider is enabled.**

## Rules that never change

- Never collect bank passwords, UPI PINs, OTPs or CVVs. Authorization
  happens at the provider (OAuth or consent flows).
- No SMS reading, no notification scraping, no screen scraping.
- No payment initiation (UPI or otherwise).
- Use authorized providers through their documented APIs only, and only
  after legal, compliance and security review.

## India

- **Account Aggregator (RBI NBFC-AA framework):** Montra would need to
  operate as, or through, a registered Financial Information User (FIU),
  with consent artefacts (purpose, data types, frequency, duration) and
  data-retention obligations. This requires qualified compliance review
  before any build-out of the provider adapter. The registry shows the AA
  option as `unavailable` with this reason.
- **UPI:** only official statement exports or user uploads are used.
  Android SMS permissions are not requested. iOS cannot read SMS or
  notifications, and Montra does not claim otherwise.

## Adding a provider (owner and engineering checklist)

1. Get legal and compliance sign-off for the provider and the countries,
   and a data processing agreement.
2. Write a security review: token scopes (read-only), storage, webhook
   scheme, the provider's incident contacts.
3. Implement `integrations.Adapter` in `backend/internal/integrations`:
   `Info`, `AuthorizeURL`, `Exchange`, `Refresh`, `Revoke`, `Fetch`
   (cursor pages, signed amounts, stable IDs, posted/pending/reversed
   status) and `VerifyWebhook` (use `VerifyHMAC` where the provider's
   scheme fits).
4. Register the adapter at start-up **only** when its credentials are
   present. Put secrets in the secret store and the webhook secret in
   `WEBHOOK_SECRETS`.
5. Tests: adapter unit tests against a local fake of the provider API,
   plus an API test like
   `tests/api/integrations_test.go::TestIntegrationConsentOAuthSyncWebhooksAndDisconnect`.
6. Set the provider redirect URI to
   `<WEB_APP_URL>/integrations/<provider>/callback`. The web callback page
   forwards `state` and `code` to the API.
7. Update the consent text (purpose, scope, duration), PRIVACY.md
   (subprocessor), THREAT_MODEL.md and the user-facing provider status.
8. Roll out to a small group first and watch the sync-run failure rate
   and the quarantined webhook count.

## What the framework guarantees

- Explicit, recorded consent with an expiry. Syncing stops and the user
  is notified when consent lapses.
- A single-use OAuth state bound to the user, and encrypted tokens that
  are never returned.
- Idempotent syncs:
  - stable external IDs;
  - pending→posted updates;
  - reversals voided;
  - user deletions never re-created;
  - currency mismatches skipped.
- Signed, replay-protected and deduplicated webhooks with quarantine.
- One sync at a time per connection, scheduled syncs every 6 h and
  recovery of abandoned runs.
- Disconnect revokes at the provider, deletes tokens and can void the
  imported data. Account deletion revokes at the provider too.
