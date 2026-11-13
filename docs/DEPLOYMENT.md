# Montra — Deployment Preparation

Everything here is prepared for a **manual, owner-run** deployment
(spec §15). Nothing in this repository deploys automatically: CI builds
and tests only. The steps below are for the owner. The development agent
does not run deployments, create cloud resources, change DNS, touch
production secrets, run production migrations or publish mobile apps.

## Topology (ADR-011)

| Component | Host | Artifact |
|---|---|---|
| Web portal | Vercel (static build + SPA rewrites) | `web/` with `web/vercel.json` |
| API | Go-capable always-on host (Fly.io, Render, Cloud Run, ECS/Fargate) | container image from `backend/Dockerfile`, command `/usr/local/bin/api` |
| Worker (jobs, scheduler, outbox) | same host, separate always-on process | same image, command `/usr/local/bin/worker` |
| Database | Supabase PostgreSQL (same region as the API) | `supabase/migrations` applied by `/usr/local/bin/migrate` |
| File storage | Appwrite (buckets per area) | — |
| Email / push / AI / FX | SMTP provider; Web Push (VAPID); FCM; Anthropic (optional); ECB (optional) | configuration only |

Recommended region for an India launch: the same region for Supabase and
the Go host (for example Mumbai).

## 1. Database (Supabase)

1. Create the project, and use a dedicated role setup mirroring
   `scripts/db/bootstrap.sh`:
   - `montra_owner` owns the schema and runs migrations;
   - `montra_app` is the API role, with RLS enforced and no BYPASSRLS;
   - `montra_worker` is the worker role.

   Give each role a strong password in the secret store. Do not use the
   Supabase `postgres` or `service_role` credentials at runtime.
2. Connections:
   - Prefer direct or session-mode connections.
   - With the transaction-mode pooler, set `DATABASE_SIMPLE_PROTOCOL=true`.
     Montra sets `montra.user_id` per transaction with `set_config(...,
     true)`, which is transaction-scoped and safe with transaction pooling.
   - Set `DATABASE_MAX_CONNS` to fit the plan.
3. Migrations (owner action, after a backup):
   1. Run `migrate status`, then `migrate up -yes`, from the image with
      `DATABASE_MIGRATION_URL` set to the **owner** role. `-yes` is
      required for any database whose name does not end in `_dev` or
      `_test`, and the command prints the target first.
   2. Migrations are forward-only and additive. Roll back by restoring
      the backup or with a new corrective migration, never by editing an
      applied file (checksums are verified).
4. Turn on point-in-time recovery and daily backups. Run a restore drill
   before launch (docs/RUNBOOKS.md).

The schema-level preparation for a hosted project (role attributes, the
`extensions` schema and the Data API) is described in
[`supabase/README.md`](../supabase/README.md#hosted-supabase-notes).

### 1.1 TLS for hosted database connections (DB-002)

Every connection to a hosted database must be encrypted and must verify
the server certificate. Montra's connection strings are standard
PostgreSQL URLs that pgx parses, so TLS is chosen by the URL:

| `sslmode` | Encrypts | Verifies the server | Use |
|---|---|---|---|
| `disable` | no | no | local development and CI only (`bootstrap.sh`, `ci.yml`) |
| `prefer` (the default when `sslmode` is missing) | if the server offers it | no; falls back to plaintext | never for hosted connections |
| `require` | yes | no (open to man-in-the-middle) | not enough on its own |
| `verify-full` | yes | certificate chain **and** host name | **required for staging and production** |

- Download the project's CA certificate from the Supabase dashboard
  (Database settings, SSL configuration) and mount it into the API, worker
  and migrate containers as a secret file. Do not commit it. Then use
  `?sslmode=verify-full&sslrootcert=/run/secrets/supabase-ca.crt` on
  `DATABASE_URL`, `WORKER_DATABASE_URL` and `DATABASE_MIGRATION_URL`
  (and on the read-only URLs in §1.2).
- Turn on Supabase's "Enforce SSL on incoming connections" so plaintext
  connections are refused server-side as well.
- Use the host name exactly as the dashboard shows it for the
  connection type you chose (direct, or the pooler in session or
  transaction mode), so `verify-full` can match it. Prove the CA file
  and host pair with the check below before relying on it; this has not
  been rehearsed against a hosted project yet. Transaction mode also
  needs `DATABASE_SIMPLE_PROTOCOL=true` (§1, step 2).
- Check from a trusted machine that a connection is encrypted:
  `psql "<url with sslmode=verify-full>" -c "select ssl, version, cipher from pg_stat_ssl where pid = pg_backend_pid()"`
  must show `ssl = t` and TLS 1.2 or 1.3. The same URL with a wrong host
  name must fail.
- The API and worker refuse to start when `APP_ENV` is `staging` or
  `production` and `DATABASE_URL`, `DATABASE_MIGRATION_URL` (when set) or,
  in the worker, `WORKER_DATABASE_URL` and the separate application-role
  `DATABASE_URL` would not verify the server certificate and host name
  (`config.CheckDatabaseTLS`, `backend/internal/platform/config`). The check
  reads the TLS settings pgx itself derives from the URL, so a missing
  `sslmode` (pgx then uses `PGSSLMODE`, else `prefer`), `disable`, `allow`,
  `prefer`, `require`, `verify-ca` and the `ssl=true` alias are all refused,
  and every host of a multi-host URL must verify. The error names the
  variable, never its value. There is no override. Development and test are
  not checked. `cmd/migrate` reads `DATABASE_MIGRATION_URL` without the
  application config, so the URLs in the secret store remain the control for
  migrations: review them in the release checklist (§6).

### 1.2 Verifying RLS on a hosted project (ARCH-013, DEP-004)

RLS is verified locally on every CI run (`backend/tests/rls`, 12 tests,
plus the API suites). A hosted project needs its own verification, because
the roles, extensions and the `postgres`/Supabase role set-up there are
created by hand. Do it once on staging before launch, and repeat the
read-only part on staging and production after every migration.

**A. Behavioral tests on a non-production project.** `tests/rls`
uses the integration harness, which **drops and recreates schema
`montra`** in its target and only accepts a database whose name ends in
`_test`. Never point it at a database with data, and never at production.

1. Pick a staging or disposable Supabase project on the same PostgreSQL
   major version as production, with the three `montra_*` roles created as
   in §1.
2. As `postgres`, create an empty database for the run and give it to the
   owner role: `create database montra_rls_test owner montra_owner;`
   (`postgres` must be a member of `montra_owner` to do this). Prepare it
   like the main database: enable `pg_trgm` in its `extensions` schema
   and give `montra_owner` usage on that schema with grant option
   (supabase/README.md). If the plan does not allow extra databases, use
   a disposable project for the run, never the staging data.
3. From a trusted machine, without `backend/.env.local` values in the way
   (exported variables take precedence), run:

   ```sh
   cd backend
   export TEST_DATABASE_MIGRATION_URL='postgres://montra_owner:<pw>@<host>:5432/montra_rls_test?sslmode=verify-full&sslrootcert=<ca.crt>'
   export TEST_DATABASE_APP_URL='postgres://montra_app:<pw>@<host>:5432/montra_rls_test?sslmode=verify-full&sslrootcert=<ca.crt>'
   export TEST_DATABASE_WORKER_URL='postgres://montra_worker:<pw>@<host>:5432/montra_rls_test?sslmode=verify-full&sslrootcert=<ca.crt>'
   go test -count=1 -p 1 -v ./tests/rls/...
   ```

   Every test must pass, none skipped. A skip means the variables were not
   picked up. The run applies all migrations from empty, so it also proves
   that they apply on the hosted platform (extensions and grants included).
4. Optionally run `./tests/api/...` the same way for the full behavioral
   suite (slower; it starts the API in process against that database).
5. Drop `montra_rls_test` afterwards and unset the variables.

**B. Read-only comparison with the committed matrix (staging and
production).** These checks read the catalog only. Connect as
`montra_owner` (needed to see the grants it made) over a direct
connection, in a read-only session:

```sh
export PGOPTIONS='-c default_transaction_read_only=on'
OWNER_RO='postgres://montra_owner:<pw>@<host>:5432/postgres?sslmode=verify-full&sslrootcert=<ca.crt>'
psql "$OWNER_RO" -X -A -F ' | ' -P footer=off -f - <<'SQL'
show default_transaction_read_only;                                   -- must be "on"
select max(version) as migration, count(*) as applied from montra.schema_migrations;
-- 0 rows expected: tables without RLS (schema_migrations has no runtime grants)
select relname from pg_class where relnamespace = 'montra'::regnamespace and relkind = 'r'
  and not relrowsecurity and relname <> 'schema_migrations';
-- all f expected
select rolname, rolsuper, rolbypassrls, rolcreaterole, rolcreatedb from pg_roles
  where rolname in ('montra_owner', 'montra_app', 'montra_worker') order by 1;
-- 0 expected: table/sequence privileges for anyone but the montra roles (PUBLIC, anon, authenticated, ...)
select count(*) as foreign_grants from pg_class c cross join lateral aclexplode(c.relacl) a
  where c.relnamespace = 'montra'::regnamespace and c.relkind in ('r', 'v', 'm', 'S')
    and a.grantee not in ('montra_owner'::regrole, 'montra_app'::regrole, 'montra_worker'::regrole);
-- 0 expected: callable security-definer functions executable by PUBLIC
select count(*) as public_definer_functions from pg_proc p
  cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
  where p.pronamespace = 'montra'::regnamespace and p.prosecdef and a.grantee = 0
    and p.prorettype <> 'trigger'::regtype;
-- f expected: PUBLIC cannot even reach the schema
select has_schema_privilege('public', 'montra', 'USAGE') as public_schema_usage;
-- policy count and fingerprint: compare with a local database at the same migration
select count(*) as policies, md5(string_agg(format('%s|%s|%s|%s|%s|%s', tablename, policyname, cmd,
  roles::text, coalesce(qual, ''), coalesce(with_check, '')), E'\n' order by tablename, policyname)) as fingerprint
  from pg_policies where schemaname = 'montra';
SQL
```

Compare the results with the expected values in the comments and with
`docs/RLS_POLICY_MATRIX.md`. Its header names the migration it was
generated at, and the summary gives the table and policy counts. On
2026-11-13, at migration `20261112000028`, the local fingerprint query
returned 331 policies with md5 `94cd7b5da08d7165f7221263368ad334`. Rerun
the query on a local database migrated to the hosted version to get the
current value. Any difference is a finding: stop and investigate before
going live.

For a line-by-line comparison, regenerate the matrix from the hosted
catalog in a scratch checkout and diff it. The script only reads the
catalog; the read-only session guarantees it.

```sh
git worktree add ../montra-rls-check HEAD && cd ../montra-rls-check
PGOPTIONS='-c default_transaction_read_only=on' scripts/docs/gen_rls_matrix.sh "$OWNER_RO"
git diff --stat docs/RLS_POLICY_MATRIX.md && git diff docs/RLS_POLICY_MATRIX.md
cd - && git worktree remove --force ../montra-rls-check
```

At the same migration version the diff must be empty. Record the date, migration version, fingerprint and result in
`docs/IMPLEMENTATION_STATUS.md` (test results log).

## 2. Storage (Appwrite)

Create the buckets `private-user-docs`, `group-docs`, `public-media`,
`temp-processing` and `exports` (names overridable with
`APPWRITE_BUCKET_*`):

- file security on;
- no public read;
- maximum file size equal to or below `STORAGE_MAX_UPLOAD_BYTES`;
- allowed extensions per ADR-010.

Create an API key scoped to those buckets only. The API reaches Appwrite
server-side; clients never talk to Appwrite directly.

## 3. API and worker

Build from the repository root (CI does this on every change; the image
is never pushed by CI):

```sh
docker build -f backend/Dockerfile -t montra-backend:<version> --build-arg APP_VERSION=<version> .
```

Run two services from the same image:

- `api`: listens on `:8080`.
  - Health: `GET /health/live` (liveness) and `GET /health/ready`
    (database and adapters).
  - Metrics: `GET /metrics`, which requires `METRICS_TOKEN`.
- `worker`: no inbound port. Exactly one scheduler leader is elected
  automatically, so several workers are safe.

### Environment

`APP_ENV=production` refuses development adapters (`local_disk`,
`dev_mailbox`), insecure cookies, `*` CORS, the development
email-verification bypass (`AUTH_DEV_AUTO_VERIFY_EMAIL`) and
`AUTH_REQUIRE_EMAIL_VERIFIED=false`. Missing required secrets fail
start-up.

| Variable | Required | Notes |
|---|---|---|
| `APP_ENV` | yes | `production` (or `staging`) |
| `DATABASE_URL` | yes | `montra_app` role (API; worker for user-scoped reads) |
| `WORKER_DATABASE_URL` | worker | `montra_worker` role |
| `DATABASE_MIGRATION_URL` | migrate only | `montra_owner` role; never given to the API or worker services |
| `DATA_ENCRYPTION_KEYS` | yes | `kid:base64(32 bytes)[,kid2:...]`; the first key encrypts, all keys decrypt |
| `URL_SIGNING_KEY` | yes | base64 of 32 bytes (signed file URLs, unsubscribe tokens) |
| `PUBLIC_API_BASE_URL`, `WEB_APP_URL` | yes | public origins (email links, OAuth redirects) |
| `CORS_ALLOWED_ORIGINS` | yes | the web origin(s) |
| `AUTH_COOKIE_DOMAIN` | if the API and web share a parent domain | cookies stay `Secure`, `HttpOnly`, SameSite |
| `HTTP_TRUST_PROXY_HEADERS` | per host | `true` only behind a trusted proxy that sets `X-Forwarded-For` |
| `STORAGE_PROVIDER=appwrite`, `APPWRITE_ENDPOINT` (https), `APPWRITE_PROJECT_ID`, `APPWRITE_API_KEY` | yes | — |
| `EMAIL_PROVIDER=smtp`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `EMAIL_FROM` | yes | STARTTLS required |
| `SUPPORT_EMAIL`, `SECURITY_EMAIL`, `STATUS_PAGE_URL` | yes | shown to users |
| `METRICS_TOKEN` | yes | protects `/metrics` |
| `TURNSTILE_SECRET_KEY` | recommended | captcha on registration, sign-in and password-reset requests |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` | optional | Web Push (docs/OPERATIONS.md) |
| `FCM_PROJECT_ID`, `FCM_CREDENTIALS_FILE` | optional | native push; mount the service-account JSON as a secret file |
| `AI_PROVIDER=anthropic`, `ANTHROPIC_API_KEY`, `AI_MODEL` | optional | off by default |
| `FX_PROVIDER=ecb` | optional | daily reference rates |
| `WEBHOOK_SECRETS` | when a provider is enabled | per-provider webhook secrets |
| `RETENTION_*` | optional | ADR-021 windows (AI history, raw import rows, temp files, exports, security events, deletion grace) |
| `LOG_LEVEL`, `LOG_FORMAT` | optional | `info`, `json` |

All other settings (timeouts, TTLs, limits, worker concurrency) have safe
defaults in `backend/internal/platform/config/config.go`.

## 4. Web portal (Vercel)

1. Import the repository with root directory `web/`. `vercel.json` sets
   the install and build commands, the SPA rewrites and the security
   headers.
2. **Before the first deploy**, edit the `connect-src` entry of the
   Content-Security-Policy in `web/vercel.json`: replace
   `https://api.montra.example` with the real API origin.
3. Set `VITE_API_BASE_URL` to the API base, for example
   `https://api.<domain>/api/v1`. The default `/api/v1` assumes a
   same-origin proxy.
4. Set `VITE_SUPPORT_EMAIL` and `VITE_SECURITY_EMAIL`.
5. Deploy from the Vercel dashboard or with the owner's own CLI session.
   This repository never runs `vercel deploy`.

## 5. Mobile apps

Montra's Flutter app (`mobile/`, application and bundle ID
`app.montra.mobile`) is built, signed and submitted by the owner, on the
owner's machine and accounts. CI only analyzes and tests it, and never
builds a signed release.

Ground rules:

- **Signing keys stay with the owner.** The Android upload keystore, its
  passwords, Apple certificates, private keys and provisioning profiles
  live in the owner's password manager and keychain, never in the
  repository, CI secrets or a shared drive. `.gitignore` excludes `*.jks`,
  `*.keystore`, `*.p12`, `*.key`, `key.properties`, `google-services.json`
  and `GoogleService-Info.plist`.
- **No production credentials in the app or the repository.** The app
  receives only public build-time settings (`--dart-define`). It never
  holds API keys, database URLs or provider secrets (spec §1.4).
- `API_BASE_URL` is the API **origin** without `/api/v1` (the app appends
  it), for example `https://api.<domain>`. Release builds refuse a missing
  or non-`https` value.

### 5.1 Store build, sign and release checklist (DEP-003)

**Once, before the first release (owner):**

1. Developer accounts: Google Play Console and the Apple Developer
   Program, in the owner's or company's name.
2. Confirm the identifier `app.montra.mobile` (`android/app/build.gradle.kts`,
   iOS `PRODUCT_BUNDLE_IDENTIFIER`). It cannot change after the first
   upload.
3. Publish the privacy policy and terms on the web domain. They feed
   `PRIVACY_URL`/`TERMS_URL` and the store listings.
4. Prepare the store declarations from docs/PRIVACY.md and SECURITY.md:
   - Google Play: Data safety, content rating, target audience (adults;
     the API enforces `AUTH_MINIMUM_AGE_YEARS`) and the financial
     features declaration;
   - Apple: App Privacy.
   Listings must state that Montra does not read SMS or notifications and
   never asks for bank passwords, UPI PINs, OTPs or CVVs.
5. Verified links: replace the `montra.example` placeholders with the
   production web domain (`-Pmontra.linkHost=<domain>` at build time for
   Android; `ios/Runner/Runner.entitlements` and the Associated Domains
   capability for iOS). Serve `/.well-known/assetlinks.json` with the
   SHA-256 fingerprint of the Play **app signing** key, and
   `/.well-known/apple-app-site-association` with the Team ID and bundle
   ID (mobile/README.md, "Deep links").
6. Native push is not in this build (no Firebase SDK; mobile/README.md,
   "Limitations and owner actions"). Adding it later needs the owner's
   Firebase project, `google-services.json` and `GoogleService-Info.plist`
   (git-ignored), and an APNs key uploaded to Firebase.

**Android, every release:**

1. Bump `version: x.y.z+N` in `mobile/pubspec.yaml`. The build number `N`
   must be higher than any build uploaded before.
2. The first time only, create the **upload** key on the owner's
   machine, outside the repository:
   `keytool -genkey -v -keystore ~/secure/montra-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`.
   Enroll in Play App Signing, so Google holds the app signing key and a
   lost upload key can be reset. Back up the keystore and passwords in
   the password manager.
3. Create `mobile/android/key.properties` (git-ignored) with
   `storeFile` (absolute path to the keystore), `storePassword`,
   `keyAlias` and `keyPassword`. Check `git check-ignore -v
   mobile/android/key.properties` before going on. **Without this file
   the release build is silently signed with the debug key** and must
   not be uploaded.
4. Build from `mobile/`:

   ```sh
   flutter build appbundle --release \
     --dart-define=API_BASE_URL=https://api.<domain> \
     --dart-define=WEB_APP_URL=https://<web-domain> \
     --dart-define=PRIVACY_URL=https://<web-domain>/privacy \
     --dart-define=TERMS_URL=https://<web-domain>/terms \
     -Pmontra.linkHost=<web-domain>
   ```

5. Verify the signature before uploading:
   `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
   must show the upload certificate, never `CN=Android Debug`.
6. Upload to the internal testing track. Smoke test on a physical device
   against staging: sign up, verify through the email link, sign in,
   account, transaction, receipt photo, group expense, sign out. Then
   promote through closed testing to production with a staged rollout.

**iOS, every release (needs macOS and Xcode):**

1. Use the same `version` bump. Open `ios/Runner.xcworkspace`, select the
   owner's team under Runner, Signing & Capabilities, and keep automatic
   signing. Certificates and profiles stay in the owner's keychain and
   Apple account. Do not commit the team change if the repository is
   shared.
2. Check `Info.plist`: camera and photo library usage texts, and
   `ITSAppUsesNonExemptEncryption` (set; the app uses standard HTTPS
   only). Add the Associated Domains capability with the production
   domain (step 5 above).
3. Build: `flutter build ipa --release` with the same `--dart-define`
   values as Android. Then upload the archive with Xcode Organizer or
   Transporter.
4. Resolve App Store Connect processing warnings, for example privacy
   manifest notices. The Runner target has no `PrivacyInfo.xcprivacy` of
   its own yet, so add one if Apple asks for it.
5. TestFlight internal testing with the same smoke test, then submit
   for review with a phased release.

**After release:**

- Keep the per-build symbols if the build uses `--split-debug-info`
  (private storage, not the repository).
- To roll back, halt the staged rollout or pause the phased release.
  Fixes ship as a new build number. The API stays backward compatible, so
  older app versions keep working.
- Record the version, build numbers, date and smoke-test result in
  `docs/IMPLEMENTATION_STATUS.md`.

## 6. Release checklist

1. CI green on the release commit: backend (gofmt, vet, lint, sqlc,
   contract drift, unit with `-race`, integration/RLS/API, fuzz,
   govulncheck, binaries, image), web (typecheck, lint, test, build,
   audit) and mobile (analyze, test), plus the `e2e` workflow: Playwright
   journeys (`web-e2e`) and on-emulator Flutter journeys (`mobile-e2e`)
   against a throwaway API, worker and PostgreSQL started inside the job
   (docs/TESTING.md, "End-to-end tests"). These jobs never deploy and use
   no repository secrets.
2. Back up the database, then run `migrate status` and `migrate up -yes`.
   Check that the database URLs in the secret store use
   `sslmode=verify-full` (§1.1), and run the read-only RLS comparison
   (§1.2 B) after the migration.
3. Deploy the worker and API images. Check `/health/ready` and confirm
   the worker log shows scheduler leadership.
4. Deploy the web portal. Smoke test: sign up, verify, sign in, add an
   account and a transaction, export.
5. Roll back by redeploying the previous image or web build. Migrations
   are additive, so the previous version keeps working.

## 7. Secret rotation

- **`DATA_ENCRYPTION_KEYS`:** prepend a new key. New writes use it, and
  old rows decrypt with the old key. Remove the old key only after
  re-encryption, which is planned operations tooling.
- **`URL_SIGNING_KEY`:** rotation invalidates outstanding signed file
  URLs (5 min) and email unsubscribe links (60 days).
- **VAPID keys:** rotation invalidates browser push subscriptions; clients
  re-subscribe.
- **Database role passwords, SMTP, Appwrite, AI and FCM credentials:**
  rotate in the provider, update the secret store, restart the services.
