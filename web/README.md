# Montra web portal

React + TypeScript portal for Montra (spec §1.1, §7; ADR-017). It talks only
to the Go API through the shared OpenAPI contract
(`../contracts/openapi/montra.v1.json`) and holds no secrets.

**What works today:** landing, privacy, security and terms pages; sign up
(with email verification), sign in (with two-step verification), email
verification, password recovery; a signed-in profile page; Security settings
(signed-in devices and sign-out, sign out everywhere, password change,
two-step verification setup / recovery codes / disable, re-authentication).
Money management (P11 round 1): optional onboarding (`/onboarding`), the
dashboard with widget settings (`/dashboard`), accounts with balance history,
corrections and archive/restore/close (`/accounts…`), payment methods
(`/accounts/payment-methods`), transactions with filters, search, cursor
pagination, bulk actions, audit history, attachments, refunds and
reimbursements, delete/restore and duplicate (`/transactions…`), and
transfers with fees and exchange rates (`/transfers/new`). Navigation lists
only these screens.

## Prerequisites

- Node.js ≥ 22.13 (developed on 22.21.1) and pnpm 10 (`packageManager` pins 10.33.2).
- The Go API on `http://localhost:8080` (and its worker, which delivers the
  development mailbox emails). See `../docs/OPERATIONS.md`.

## Setup

```sh
cd web
pnpm install            # uses the committed pnpm-lock.yaml
cp .env.example .env.local   # optional: defaults already target the local API
pnpm dev                # http://localhost:5173, /api proxied to :8080
```

Email links from the local API point to `http://localhost:5173`
(`WEB_APP_URL`); open the newest `.eml` in `../backend/.data/mail/` to verify
an account or reset a password.

## Commands

| Command                             | What it does                                                                                |
| ----------------------------------- | ------------------------------------------------------------------------------------------- |
| `pnpm dev`                          | Vite dev server on :5173, proxying `/api` to `MONTRA_API_PROXY_TARGET`                      |
| `pnpm build`                        | Type-check (`tsc -b`) and build to `dist/`                                                  |
| `pnpm preview`                      | Serve the production build on :4173 (also proxies `/api`)                                   |
| `pnpm typecheck`                    | Strict TypeScript check of app, tests and tooling                                           |
| `pnpm lint`                         | ESLint (typescript-eslint strict type-checked, react-hooks, jsx-a11y strict), zero warnings |
| `pnpm format` / `pnpm format:check` | Prettier write / verify                                                                     |
| `pnpm test` / `pnpm test:watch`     | Vitest + Testing Library + MSW (no network, no running API)                                 |
| `pnpm e2e`                          | Playwright journeys against the local API (see below)                                       |
| `pnpm gen:api`                      | Regenerate `src/shared/api/schema.d.ts` from the contract                                   |
| `pnpm check:api`                    | Fail if the generated types drifted from the contract (for CI)                              |

## Configuration

Only `VITE_*` variables reach the browser; none are secret.

| Variable                  | Default                   | Purpose                                                    |
| ------------------------- | ------------------------- | ---------------------------------------------------------- |
| `VITE_API_BASE_URL`       | `/api/v1`                 | API base URL as the browser sees it (path or absolute URL) |
| `VITE_SUPPORT_EMAIL`      | `support@montra.example`  | Support contact on public pages (placeholder, ADR-024)     |
| `VITE_SECURITY_EMAIL`     | `security@montra.example` | Vulnerability reports (placeholder)                        |
| `MONTRA_API_PROXY_TARGET` | `http://localhost:8080`   | Dev/preview proxy target (not exposed to the browser)      |

## Structure

```text
src/
  app/            providers, router (routes.tsx), layouts (public, app shell,
                  navigation registry), guards (RequireAuth, PublicOnlyRoute),
                  error-boundaries
  shared/
    api/          generated schema, typed openapi-fetch client, CSRF, session
                  recovery middleware, ApiError model
    auth/         session bootstrap (GET /auth/session), AuthProvider, sign-out,
                  cross-tab sync, reauth/ (REAUTH_REQUIRED dialog + retry)
    components/   design system (Button, fields, MoneyField, RadioGroup, Dialog,
                  ConfirmDialog, Menu, toasts, states, MoneyText, ...) and
                  charts/ (dependency-free SVG/HTML charts; every chart has a
                  text summary and a table view)
    finance/      contract types, query keys, reference-data hooks, enum
                  labels, pickers (account, category, tag, merchant, period)
    forms/        server-error mapping, form alerts, password requirements
    validation/   zod schemas, password policy mirror
    formatting/   exact money formatting and exact decimal input parsing
                  (decimal.ts), calendar dates, locale names
    i18n/         catalogs (en, hi scaffold), translator, provider
    accessibility/ skip link, live-region announcer, route announcer
    theme/        light/dark/system preference
    config/ currency/ hooks/ utils/
  features/
    auth/         sign in/up, MFA step, verification, recovery
    account/      profile page
    settings/     security settings
    onboarding/   optional post-sign-up setup (preferences, first account,
                  starter categories, email summaries)
    dashboard/    computed dashboard, widgets, widget settings
    accounts/     accounts list/create/detail/edit, corrections, history
    payment-methods/ payment methods (masked metadata only)
    transactions/ list/filters/search/bulk, create/edit/detail, refunds,
                  duplicates, audit, attachments, transfers
    marketing/    landing, privacy, security, terms, not found
  styles/         Tailwind entry + design tokens
  tests/          setup, MSW server/handlers, fixtures, render helper
e2e/              Playwright journeys (+ dev-mailbox and TOTP helpers)
build/            Vite plugin that checks vercel.json CSP against VITE_API_BASE_URL
```

**Adding a feature:** create `src/features/<name>/` (api.ts with query keys
and calls via `api` + `apiData`, components/, pages/), add its routes under
the AppShell branch in `src/app/router/routes.tsx` (lazy), add a
`primaryNavigation` entry in `src/app/layouts/navigation.ts` only when the
screen works end to end, and add strings under a `<feature>.` prefix in
`src/shared/i18n/locales/en.ts`. Every async view renders loading, empty,
error (with retry), success and permission-denied states (see
`SessionsCard.tsx`).

## How the client talks to the API

- **Typed client:** `pnpm gen:api` generates types with openapi-typescript;
  `shared/api/client.ts` exports an `openapi-fetch` client. Call
  `apiData(api.GET('/me/sessions'))` to get the envelope's `data` or an
  `ApiError` (`status`, `code`, `details[]`, `requestId`, `retryAfterSeconds`).
- **Sessions (ADR-002):** the API sets HttpOnly `montra_at` / `montra_rt`
  cookies and a readable `montra_csrf` cookie. Requests use
  `credentials: 'include'`, send `X-Montra-Client: web` and
  `X-Client-Version`, and unsafe methods send `X-CSRF-Token` (cookie value,
  falling back to the `csrf_token` from the last auth response kept in
  memory). Nothing auth-related is written to localStorage/sessionStorage;
  ESLint forbids direct storage access outside `shared/utils/preferences.ts`
  (theme and language only).
- **Refresh:** a `401 UNAUTHENTICATED` from a protected endpoint triggers one
  shared `POST /auth/refresh` for all concurrent callers, then each request is
  retried once with its original body. Other 401 codes (`REAUTH_REQUIRED`,
  `MFA_REQUIRED`) and public auth endpoints never trigger a refresh. If the
  session cannot be renewed, client state is cleared and guards route to
  sign-in. Offline or rate-limited refreshes do not sign the user out.
- **Re-authentication:** `useReauth().withReauth(action)` prompts for the
  password (plus an authenticator code or a single-use recovery code when MFA
  is on) after `REAUTH_REQUIRED`, calls `POST /auth/reauthenticate`, and
  retries once. A sign-in completed in the same tab counts as recent
  re-authentication, as it does on the API.
- **Two-step sign-in:** `MFA_CODE_INVALID` keeps the challenge (retry the
  code); `MFA_CHALLENGE_EXPIRED` ends it and offers only "Sign in again".
- **Rate limits:** `RATE_LIMITED` and `LOGIN_THROTTLED` show the
  `Retry-After` wait in seconds, minutes or hours and hold back resubmission
  until it passes.
- **Currencies:** `useCurrencies()` caches `GET /currencies`. Pickers offer
  only `selectable` currencies (retired ones such as BGN remain valid for
  history and are labelled as retired where they appear).
- **Errors:** `ApiError.code` is typed by the contract's closed
  `ErrorObject.code` enum (plus client-only `NETWORK_ERROR`, `UNKNOWN_ERROR`,
  `COOKIES_BLOCKED`); a code added by a newer API degrades to
  `UNKNOWN_ERROR` with `rawCode` kept. Compile-time checks fail when the
  regenerated contract adds a code without a list entry or message.
  `describeError()` maps error codes to localized messages;
  `applyServerErrors()` maps `details[].field` (`body.password`) onto form
  fields and returns anything unmatched for the form summary. Messages never
  reveal whether an email has an account.
- **Money (ADR-006):** `formatMoney(amount, currency, locale)` formats the
  API's exact decimal string with `Intl.NumberFormat#formatToParts` and BigInt
  (no floating point, any magnitude, 0/2/3-decimal currencies, en-IN lakh
  grouping). Use `<MoneyText money={...} />` in UI. `parseFloat` is banned by
  ESLint.

## Accessibility and localization

Skip link, focus moved to the page heading on navigation with an announced
title, labelled fields with associated help/errors, accessible Radix dialogs
and menus, visible focus rings, 44px targets, status shown with icon + text
(never color alone), reduced-motion support, light/dark themes that follow
the OS unless overridden. All strings are translation keys (`en` complete;
`hi` covers shared UI and auth and needs native review); plurals use
`Intl.PluralRules`; numbers, dates and currency use `Intl`; layout uses
logical CSS properties and `dir` is set from the language, ready for RTL.

## Tests

- `pnpm test`: unit and component tests with MSW mocking the contract
  (requests without a handler fail the test). Covers money formatting, the API
  client (headers, CSRF, single-flight refresh + retry, error mapping), auth
  forms (client validation, server field errors, rate limits, MFA step),
  email verification, password reset, sessions list states, re-auth, guards.
- `pnpm e2e`: Playwright against the real local API. It starts Vite on port
  **5199** (never reuses another server; override with `E2E_PORT` or point at
  a running app with `E2E_BASE_URL`), creates a throwaway
  `e2e.<timestamp>@example.com` account in the development database, reads
  links from the dev mailbox (`MONTRA_DEV_MAILBOX`, default
  `../backend/.data/mail`) and computes TOTP codes. Use the installed Chrome
  instead of downloading browsers with `PW_CHANNEL=chrome pnpm e2e`. The MFA
  journey waits for fresh 30-second code windows, so it takes ~2 minutes.

## Deployment (Vercel, owner-run only)

`vercel.json` configures SPA rewrites (except `/api/*`) and security headers:
CSP (`default-src 'self'`, `script-src 'self'`, `connect-src 'self'` plus the
API origin, `frame-ancestors 'none'`, ...), `X-Content-Type-Options`,
`Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy`,
HSTS. `style-src` allows `'unsafe-inline'` because Radix's scroll lock
injects a style element. Nothing here deploys automatically.

Before the first deployment the owner must:

1. Choose how the browser reaches the API. Recommended: serve it on the same
   site (for example a Vercel rewrite of `/api/:path*` to the Go host) and keep
   `VITE_API_BASE_URL=/api/v1`, so cookies stay first-party. If the API is on
   another origin, set `VITE_API_BASE_URL` to it, replace the placeholder
   `https://api.montra.example` in the CSP `connect-src` (the build fails if
   they disagree), add the portal origin to the API's `CORS_ALLOWED_ORIGINS`,
   and keep both on the same registrable domain (SameSite cookies).
2. Set `VITE_SUPPORT_EMAIL` / `VITE_SECURITY_EMAIL`.
3. Replace the summary Terms and Privacy pages with reviewed legal text
   (versions must match the API's `TermsVersion` / `PrivacyVersion`).

## Dependencies

Exact versions, all released at least 14 days before install:
`pnpm-workspace.yaml` sets `minimumReleaseAge` (applies to transitive
dependencies too). Deliberate choices:

- **TypeScript 5.9**: typescript-eslint 8.72 supports `< 6.1` and
  openapi-typescript 7.13 requires `^5`; TypeScript 7 is not yet usable here.
- **ESLint 10**: ESLint 9 is end-of-life. eslint-plugin-jsx-a11y 6.10.2 still
  declares `eslint <= 9` but only uses APIs ESLint 10 keeps; the peer range is
  overridden in `pnpm-workspace.yaml` (re-check on upgrade).
- **React Router 7.18 / jsdom 29**: React Router 8 and jsdom 30 require Node
  ≥ 22.22; the documented toolchain is Node 22.21.
- **MSW 3** (tests only): the unhandled-request option is `onUnhandledFrame`.

## Known gaps

- Bot protection: the API supports Cloudflare Turnstile (`captcha_token`), but
  it is off locally and the portal has no widget yet. Enabling
  `TURNSTILE_SECRET_KEY` on the API will block sign-up, sign-in and password
  reset until the widget is added.
- No client error reporting is wired (needs a privacy-reviewed provider).
