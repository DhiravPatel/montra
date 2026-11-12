# Montra — Security

Scope: controls implemented in code and the policies they enforce. The
threat model lives in `docs/THREAT_MODEL.md`; incident handling in
`docs/INCIDENT_RESPONSE.md`.

## Reporting a vulnerability

Email the address configured as `SECURITY_EMAIL` (placeholder
`security@montra.example` until the owner sets a real contact). Do not open
public issues for vulnerabilities.

## Identity and sessions (ADR-002)

- Passwords: Argon2id (m=64 MiB, t=3, p=2, 16-byte salt, 32-byte key);
  minimum 10 characters, maximum 128; checked against a small embedded
  list of common passwords; never logged.
- Access tokens: 256-bit opaque, SHA-256 hashed at rest, 15-minute TTL.
- Refresh tokens: 256-bit opaque, rotated on every use; reuse of a
  superseded token revokes the session and records a security event.
- Web: `HttpOnly; Secure; SameSite=Lax` cookies + double-submit CSRF token
  for unsafe methods. Mobile: bearer access token in memory; refresh token
  in Keychain/Keystore.
- MFA: TOTP (RFC 6238, SHA-1, 6 digits, 30 s, ±1 step) with secrets
  encrypted using AES-256-GCM under `DATA_ENCRYPTION_KEY`; 10 single-use
  recovery codes stored hashed.
- Login throttling: per-email-hash and per-IP failure counters in
  PostgreSQL (durable across instances); progressive delay and temporary
  lockout; generic error messages that never reveal whether an email
  exists.
- Email verification and password-reset tokens: 256-bit, hashed, single
  use, 24 h / 1 h expiry; reset revokes all sessions.

## Authorization

- Every handler resolves the authenticated user from the session; client
  supplied owner IDs are ignored.
- Services check resource ownership/role explicitly; PostgreSQL RLS
  policies (transaction-local `montra.user_id`) provide defense in depth.
- Group membership never grants access to personal records.
- Support/admin roles have no default access to private financial data.
- Shared budgets expose only aggregate snapshots to members; shared goals
  hide other members' ledger references and honor each member's
  contribution visibility (amounts, percent only, hidden).
- Rows addressed to another user (notifications, deliveries) are written
  only by the worker: the API role's RLS on `notifications` is owner-only,
  so a request can never plant a notification in someone else's inbox
  (ADR-028).
- Recurring occurrences can be deleted by the API role only while they are
  open and unlinked (`app_ro_delete`); posted, paid, skipped and linked
  occurrences are history. Bills, subscriptions and goals cannot be deleted
  by the API role (archive/cancel instead).
- Groups: non-members get 404 for every group resource; members read and
  write group rows through RLS (`is_group_member`), admins administer
  (`is_group_admin`); settlements, expense comments, revisions, disputes and
  activity cannot be deleted by the API role. Personal records linked to
  group activity are visible only to their owner, and other members' linked
  records are changed only by the worker (ADR-036).
- Social privacy (ADR-037): other users' `users` rows are never visible to
  the API role; discovery and relationship lookups go through SECURITY
  DEFINER helpers that require an identity, honour blocks both ways and
  return only the minimal profile (name, username, avatar). Blocks are not
  disclosed (missing-user 404). Invitation link tokens are stored hashed,
  shown once and accepted only from request bodies (ADR-038).
- Communities (ADR-041/042/044): content is plain text cleaned of
  invisible/bidi characters, payment secrets are refused, links are public
  https only; moderators act only on community content and membership;
  staff-only platform sanctions; guard triggers stop self-promotion,
  self-unbanning and undoing moderator decisions at the database level;
  challenge progress is private unless shared and never monetary.
- AI (ADR-012/045): off unless configured and consented; read-only tools
  executed as the caller (RLS), minimal redacted context, untrusted text
  fenced, structured outputs validated, numbers verified against tool
  output, no write tools; receipts and PDF statements need explicit
  consent and per-import opt-in; the provider key lives only in backend
  configuration and is never sent to clients.
- Notifications (ADR-047): Web Push posts only to HTTPS endpoints on an
  allowlist of browser push services (no arbitrary outbound URLs). Push
  payloads are end-to-end encrypted (RFC 8291) and carry no financial
  details. Subscriptions and tokens are encrypted at rest. Unsubscribe
  tokens are HMAC-signed, expire, travel in the URL fragment and cannot
  turn off security/account email.
- Integrations (ADR-016/048):
  - No provider is enabled, and Montra never collects bank passwords, UPI
    PINs, OTPs or CVVs.
  - The OAuth state is random, stored hashed, bound to the user and
    single-use. Provider tokens are encrypted with per-connection AAD and
    never returned.
  - Webhooks are verified by the adapter (HMAC and timestamp window),
    deduplicated, quarantined when invalid (401) and size and rate
    limited.
  - The API role can only insert into the webhook inbox. It queues work
    through a SECURITY DEFINER helper that accepts only verified, waiting
    events.
  - Disconnect revokes consent and tokens and can delete imported data.
- Matrix: `docs/AUTHORIZATION_MATRIX.md`; RLS: `docs/RLS_POLICY_MATRIX.md`.

## Transport and HTTP hardening

- HTTPS terminated by the hosting platform; HSTS header in production.
- Security headers on every response: `Content-Security-Policy` (API:
  `default-src 'none'`), `X-Content-Type-Options: nosniff`,
  `Referrer-Policy: no-referrer`, `X-Frame-Options: DENY`,
  `Permissions-Policy`, `Cache-Control: no-store` for API responses.
- Strict CORS allow-list from `CORS_ALLOWED_ORIGINS`; credentials only for
  listed origins.
- Request body limit (default 1 MiB JSON; uploads limited per file kind),
  read/write/idle timeouts, per-request context timeout.
- Rate limiting: per-IP and per-user token buckets; stricter limits on
  auth, AI, OCR, import and export endpoints.

## Data protection

- Money stored as integers; no secrets or financial payloads in logs
  (slog redaction of known sensitive keys).
- Provider tokens and MFA secrets encrypted with AES-256-GCM; key rotation
  supported via key IDs (`DATA_ENCRYPTION_KEYS` keyring).
- Never collected: bank passwords, UPI PINs, OTPs, card CVVs/PINs, full
  card numbers (validation rejects card-number-like and CVV fields).
  Receipt payment hints keep at most the last four digits of any number
  (spaces, dashes and dots between digits ignored), in the API and in a
  database trigger (migration 000022).
- Files: content-sniffed type allow-list, size limits, checksum
  verification, randomized internal names, no user-controlled paths,
  `Content-Disposition: attachment` downloads, short-lived signed URLs.
- CSV/XLSX exports escape formula-leading characters (`= + - @ \t \r`).
- Subscription cancellation links must be `https://` URLs without
  whitespace or markup; Montra never follows them server-side.
- Imports never evaluate formulas or macros: XLSX cells are read from
  cached values only; statement files are parsed only by the worker under
  row/column/cell/size and zip-expansion limits; raw rows are never logged.
- Receipt payment hints keep at most the last four digits of any long digit
  run; extraction candidates never become financial data without review.

## Secrets management

- No secrets in source control. `.env*` files are git-ignored except
  `*.example` templates containing placeholders only.
- Production secrets are injected by the hosting platform; the backend
  validates presence and format at startup and refuses to start in
  `production` with development adapters (`local_disk`, `dev_mailbox`).

## Supply chain

- Go modules pinned via `go.sum`; `govulncheck` in CI; npm lockfile with
  `pnpm audit`; pub lockfile; secret scanning (gitleaks) in CI.

## Status

See `docs/REQUIREMENTS_TRACEABILITY.md` (SEC-*, PRIV-*) for implementation
and verification status of each control.
