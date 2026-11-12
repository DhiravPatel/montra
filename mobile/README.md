# Montra mobile (Flutter, Android + iOS)

The Flutter client for Montra. It covers the account and security surface
(welcome, sign-up, email verification, sign-in with two-step verification,
password reset, Settings → Security) and, since P11 round 1, personal
finance: skippable onboarding, the Home dashboard with a customizable layout,
accounts, payment methods, transactions (search, filters, infinite scroll,
detail with audit history and attachments, create/edit, refunds and
reimbursements, delete/restore, duplicate, bulk changes) and transfers
between the user's own accounts. Round 2 added planning and organizing
(categories, rules, tags, merchants, budgets, recurring payments, bills, the
planning calendar, subscriptions and goals); round 3 added receipts,
transaction attachments, statement imports, reconciliation, analytics,
reports and exchange rates; rounds 4–5 added friends, groups and shared
money, communities, challenges, moderation, notifications, search,
insights, connected services, help & support, privacy & data and the
fair-use limits. Round 6 added the Home planning cards, profile editing
with a photo, preferences with accessibility settings that apply app wide,
multi-page receipts and returning to a protected screen after sign-in.
Nothing in the app shows sample or placeholder data, and no AI feature is
built.

> **Owner action:** the application ID / bundle ID is `app.montra.mobile`.
> Confirm the final identifier before the first store upload — it cannot be
> changed afterwards.

## Requirements

| Tool | Version used | Notes |
|---|---|---|
| Flutter | 3.47.4 (stable) | `/Users/dhiravpatel/Documents/flutter/bin/flutter` |
| Dart | 3.13.3 | bundled with Flutter |
| Android SDK | API 36 | `sdkmanager` (cmdline-tools) and accepted licenses are needed for Gradle builds: `flutter doctor --android-licenses` |
| Xcode | — | not installed on the build machine, so iOS builds are **unverified** (see Limitations) |

## Quick start

```sh
cd mobile
flutter pub get            # also runs gen-l10n
flutter analyze            # must report "No issues found!"
flutter test               # unit + widget tests (no network)
```

Run against the local Go API (`backend/`, listening on `:8080`):

```sh
# Android emulator (10.0.2.2 is the host machine; this is also the debug default)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# iOS simulator (debug default is http://localhost:8080)
flutter run --dart-define=API_BASE_URL=http://localhost:8080

# Physical device on the same Wi-Fi: use the computer's LAN address
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
```

### Build-time configuration (`--dart-define`)

| Key | Required | Purpose |
|---|---|---|
| `API_BASE_URL` | release: yes | Origin of the Go API, without `/api/v1`. Debug builds default to the emulator/simulator host. **Release builds refuse to start unless it is `https://`.** |
| `TERMS_URL` | no | Hosted Terms of Service. When set, sign-up shows a link. |
| `WEB_APP_URL` | no | The web portal's https origin, used for shared group and community invitation links (`/groups/join#token=…`). Without it group links use the API origin and community invitations share the code. |
| `PRIVACY_URL` | no | Hosted Privacy Policy. When set, sign-up shows a link. |

Nothing secret is ever passed to or stored in the app (spec §1.4).

### Development email links

With `EMAIL_PROVIDER=dev_mailbox`, the backend writes emails as `.eml` files to
`backend/.data/mail/`. Links look like
`http://localhost:5173/verify-email#token=…` and
`http://localhost:5173/reset-password#token=…` (the token is in the URL
fragment so it never reaches a web server log). To use one in the app:

* **Paste it:** "I have the link" on the check-email, verify-email, forgot- and
  reset-password screens accepts the whole link (whitespace from wrapped email
  lines is ignored) and has a "paste from clipboard" button; or
* **Deep link it (Android debug builds):**
  ```sh
  adb shell am start -W -a android.intent.action.VIEW \
    -d "http://localhost:5173/verify-email#token=TOKEN" app.montra.mobile
  ```
  Remember that quoted-printable `.eml` bodies encode `=` as `=3D`; copy the
  link from the decoded text part.

Registration always answers `202` and the account must be verified before
sign-in. Signing in with an unverified email shows a "resend email" action.

## Generated API models

`lib/core/api/generated/models.dart` is generated from
`../contracts/openapi/montra.v1.json` (the code-first OpenAPI 3.1 contract
exported by the Go backend, ADR-005):

```sh
dart run tool/gen_api.dart          # regenerate (then runs dart format)
dart run tool/gen_api.dart --check  # exit 1 when the committed file is stale
dart run tool/gen_api.dart --spec <spec.json> --out <file.dart> [--check]  # other specs
```

* One immutable class per `components.schemas` object with `fromJson`/`toJson`,
  `==`/`hashCode`, and constants for contract `minLength`/`maxLength`/`pattern`.
* Optional (not `required`) or `null`-typed members are nullable; absent
  optional members are omitted from request bodies.
* `format: date-time` → `DateTime`; `$ref` → class; arrays → `List`;
  `additionalProperties` → typed `Map<String, T>`; `format: int32/int64` → `int`.
* String enums → Dart enums with an `unrecognized` fallback, so a newer server
  can add values without breaking older apps.
* Names are collision-safe and deterministic. Enum constants and fields that
  would clash with a Dart keyword (reserved word, built-in identifier or
  contextual keyword), an `Object` member, `Enum` members (`index`,
  `values`, `name`) or members the generator emits (`json`, `value`,
  `fromJson`, `toJson`, `unrecognized`) get a `Value` suffix, e.g.
  `ReportDtoFormat.jsonValue` for the wire value `json`. Digit-leading values
  get a `v` prefix (`v25k50k`), and later duplicates get extra `Value`
  suffixes. The fallback is always `unrecognized`. An enum whose type name is
  taken by a schema gets an `Enum` suffix, a schema named like a `dart:core`
  type gets a `Model` suffix, and two schemas mapping to the same class name
  fail loudly. `Envelope<T>` is emitted only when envelope schemas exist, and
  uses their `meta` `$ref`.
* `Envelope*` schemas are typedefs over a generic `Envelope<T>` plus a
  `decodeEnvelope…()` function.
* `toString()` prints no field values, so tokens and personal data cannot leak
  into logs; decode errors name the JSON path, never the value.
* Unsupported schema features (`oneOf`, inline objects, …) make the generator
  fail loudly instead of producing wrong models.
* Only `components.schemas` is read. Operation parameters, response headers
  and their `$ref`s (`components.parameters` / `components.headers`) are
  ignored by the generator; the client sends the declared headers itself.
* `ErrorObject.code` is a closed enum (`ErrorObjectCode`, 30 codes; see
  `docs/API.md` for the status and client action of each). `ApiException.code`
  uses it directly, and keeps the raw wire value in `rawCode` for codes a newer
  server might add.

`test/core/api/generated_models_test.dart` fails when the file is stale (and
checks the generator ignores parameter/header `$ref`s).
`test/core/api/gen_api_collisions_test.dart` covers the naming rules against
`test/fixtures/gen_api_collisions.g.dart`, generated by the same CLI from
`test/fixtures/gen_api_collisions.json`, so `flutter analyze` compile-checks
the escaped output. Regenerate the fixture with
`dart run tool/gen_api.dart --spec test/fixtures/gen_api_collisions.json --out test/fixtures/gen_api_collisions.g.dart --enforced-by test/core/api/gen_api_collisions_test.dart`.
Finally,
`test/core/api/endpoints_contract_test.dart` checks every endpoint the app
calls against the contract: method, path, auth requirement, the declared
`X-Montra-Client` / `X-Client-Version` parameters (and that the Dio client
sends them), `X-Request-ID` / `Retry-After` response headers, and the error
statuses each screen handles.

## Project layout

```text
lib/
  main.dart                    bootstrap + session restore + runApp
  app/
    app.dart                   MaterialApp.router (theme, l10n, offline banner)
    bootstrap.dart             config, app version, device model, preferences
    router/                    routes, auth redirect guard, navigation shell
    theme/                     Material 3 theme, status colors, theme mode
    l10n/                      ARB sources (en complete, hi scaffold) + generated
  core/
    api/                       Dio client, interceptors, errors, endpoints,
                               connectivity, generated models
    auth/                      credentials, token manager, auth API, controller
    config/                    AppConfig (dart-defines, client headers)
    formatting/                exact money formatting, currencies, dates
    storage/                   secure storage + non-sensitive preferences
    widgets/                   state views, banners, fields, buttons, dialogs,
                               charts, localized error codes
    files/                     upload policies, SHA-256, file picking, uploads,
                               signed downloads, share/save
  core/finance/                finance revision signal (refresh after writes),
                               number locale (en-IN grouping)
  features/
    auth/                      welcome, sign-in (+MFA), sign-up, verify, reset
    settings/                  profile, security, sessions, password, two-step
                               verification, re-auth sheet, preferences API
    onboarding/                post-sign-up setup (all steps skippable)
    dashboard/                 Home summary widgets, layout settings
    accounts/                  list, detail, create/edit, balance adjustment,
                               account picker
    payment_methods/           list, create/edit, remove/archive, picker
    transactions/              list/search/filters, detail, form, refund,
                               transfer form/detail, bulk sheet
    labels/                    categories, rules, tags, merchants and pickers
    budgets/ goals/            budgets and alerts; goals and contributions
    recurring/ bills/          recurring rules, occurrences and bills
    calendar/ subscriptions/   planning calendar; subscriptions and detections
    people/                    friend and group pickers
    receipts/                  receipt inbox, review, matching, recording
    imports/                   statement import wizard, rows, history
    reconciliation/            statement balances and matches per account
    analytics/ reports/ fx/    analytics, reports and schedules, exchange rates
    social/ groups/            friends, blocks/mutes, privacy for friends, the
                               Together tab; groups, invitations, activity
    group_money/               group expenses, balances, settlements,
                               recurring shared expenses, group reports
    communities/ challenges/   communities, posts and comments; challenges
    moderation/                decisions about the user, appeals, reports filed
    notifications/ search/     notification center and settings; global search
    insights/ integrations/    deterministic insights; connected services
    support/ privacy/          help & support, contact form; consents, data
                               export, deactivation, deletion, limits
test/                          unit, widget and app-flow tests
tool/gen_api.dart              contract → Dart model generator
tool/currency_snapshot.dart    GET /currencies → offline snapshot (+ --check)
```

### Adding a feature / tab

1. Add `lib/features/<name>/{data,application,presentation}`.
2. Add endpoints to `ApiEndpoints` (the contract test validates them) and
   regenerate models if the contract changed.
3. For a top-level tab, append an `AppDestination` in
   `app/router/app_shell.dart` and a matching `StatefulShellBranch` in
   `app/router/app_router.dart`. The bottom navigation bar appears
   automatically once there are two destinations. Point
   `AppRoutes.signedInHome` at the new Home tab when it exists.
4. Use `AsyncValueView` / `ErrorStateView` so loading, empty, error (with
   request reference and retry), offline and permission-denied states are
   consistent, and `SubmitButton` for duplicate-tap-safe actions.

## Finance screens (P11 round 1)

| Route | Screen |
|---|---|
| `/onboarding` | Setup: welcome, privacy, currency/time zone/country, income range (monthly, INR), first account, starter categories. New accounts land here; progress is saved after each step (`POST /me/onboarding` merges) and resumed from `GET /me/onboarding`; "Skip setup" finishes with the remaining steps recorded as skipped. |
| `/home` (tab) | Dashboard from `GET /dashboard/summary` in the user's widget order; period picker (named ranges or custom dates); one currency at a time when several exist. |
| `/home/widgets` | Show/hide and move up/down (buttons, no dragging needed); save or reset (`PATCH /dashboard/widgets`). |
| `/transactions` (tab) | List with search (`/transactions/search`), every filter of the API, cursor-paginated infinite scroll (plus a "Load more" button), long-press multi-select with bulk category/tag/account change and bulk delete. The filter lives in the query string, so the dashboard's `drill_down_path` links open as-is. |
| `/transactions/new?type=expense\|income&account_id=` | Create (Idempotency-Key). |
| `/transactions/:id`, `/:id/edit`, `/:id/refund[?type=reimbursement]` | Detail (fields, links to transfer/original, attachments with detach, audit history), edit (`version`), refund/reimbursement (server caps shown verbatim). |
| `/transactions/transfer?from=`, `/transactions/transfers/:id` | Transfer between own accounts (fee, amount received or exact rate for cross-currency); detail with date, description and notes, deleted/restored as a unit (`DELETE`/`POST …/transfers/{id}/restore`). |
| `/accounts`, `/accounts/new`, `/accounts/:id`, `/:id/edit`, `/:id/adjust` | Accounts grouped by type with server totals, archived filter; detail with liability wording, 30-day balance history, recent transactions; create/edit; balance adjustment with reason. |
| `/payment-methods`, `/new`, `/:id/edit` | Payment methods (masked hints only); partial edits with `version`, archived list with restore. |

## Planning and organizing screens (P11 round 2)

| Route | Screen |
|---|---|
| `/categories`, `/categories/new[?parent=]`, `/categories/:id/edit` | Category tree (archived/merged on request); create/edit (name, kind, main category, icon, named color, "count in budgets", order; edits send only changes with `version`); archive/restore; merge into another category after a preview of what moves (`preview: true`); delete only when unused (`category_in_use` explained). |
| `/category-rules`, `/new`, `/:id/edit` | Rules in running order with plain summaries; full rule form; preview matches on past transactions (optionally only uncategorized) and apply after confirming; delete. |
| `/tags` | Tags with usage; add, rename/recolor, archive/unarchive, delete (after confirming how many transactions lose it); "See transactions". |
| `/merchants`, `/merchants/:id`, `/:id/edit` | Searchable directory (names and other names); detail with 12 months of spending per currency (chart + list), other names (add), merge a duplicate into it, archive; edit name, default category, website, notes. |
| `/budgets`, `/budgets/new`, `/budgets/:id`, `/:id/edit`, `/budget-alerts` | Budgets with progress and pace in words; full budget form (types, periods, rollover, thresholds, allocations, filters, group budgets); detail with periods chart, allocations, counted transactions and people; pause/resume/archive; alerts with dismiss and snooze. Active alerts also show on Home. |
| `/recurring`, `/new`, `/:id`, `/:id/edit` | Recurring rules with filters; full schedule editor; occurrences with record, link, change amount, move, skip and undo (Idempotency-Key); pause/resume/skip next/stop/delete. Opened from the Transactions tab. |
| `/bills`, `/new`, `/:id`, `/:id/edit`, `/:id/pay` | Bills with payment state; mark paid by linking a suggested or any transaction, or by recording a payment (Idempotency-Key); skip, pause, archive. |
| `/calendar[?month=]` | Planning calendar by month, grouped by day; items open their bill, rule, subscription or goal. |
| `/subscriptions`, `/new`, `/detections`, `/:id`, `/:id/edit` | Totals per currency, renewals and trials ending; manual entry; detail with normalized cost, duplicates, price history and payments; record payment (Idempotency-Key), verify, pause/resume, cancellation checklist, cancel (confirmed), reactivate; review of possible subscriptions (confirm/dismiss/look again). |
| `/goals`, `/new`, `/:id`, `/:id/edit`, `/:id/contribute`, `/:id/export` | Goals with progress in words; full goal form with milestones; detail with outlook (forecast), contributions (planned/recorded, verified when linked to a transaction; void own), members and visibility, pause/resume/achieve/end/archive; CSV preview with copy. |

Home has a "Plan ahead" row (budgets, goals, bills, subscriptions, recurring,
calendar); Profile has an "Organize" section (categories, rules, tags,
merchants). Routes for each area live in `lib/app/router/routes/`. Shared
pieces: person/group pickers (`features/people`, `GET /connections`,
`/groups`), a searchable transaction picker, `ReminderDaysField`, and
frequency labels (`core/formatting/frequency.dart`). No AI features are
built.

Rules the screens follow:

* **Money:** amounts are typed into `AmountField` and parsed with string
  arithmetic (`core/formatting/amount_input.dart`) to the currency's
  minor-unit precision; displayed amounts are always the server's exact
  `amount` strings (`MoneyText`). Inflows/outflows carry a `+`/`−` sign and
  "received"/"spent" for screen readers. The app never adds up money; totals,
  shares and caps come from the server.
* **Idempotency:** every financial create (account, adjustment, transaction,
  refund, duplicate, transfer) sends an `Idempotency-Key` from
  `IdempotentSubmission`, which keeps the key while the request body is
  unchanged (a retry after a timeout replays) and makes a new one when the
  user edits the form. `IDEMPOTENCY_CONFLICT` resets it.
* **Concurrency:** edits send `version`; `VERSION_CONFLICT` reloads the record
  and shows "This was changed somewhere else, so we loaded the latest
  version…".
* **Freshness:** every finance write bumps `financeRevisionProvider`; lists,
  balances and dashboard figures watch it and re-read from the server. Data
  is scoped to the signed-in user and kept in memory only. Home shows when the
  figures were computed and labels them when a refresh fails.
* **Arrays in queries** are sent comma-separated (the contract declares
  `explode: false`; repeated parameters keep only the first value).
* **Charts** are drawn with core widgets (`core/widgets/charts.dart`): each has
  a visible text summary, the drawing is hidden from screen readers, a
  "Show as a list" toggle gives the same values as rows, series differ by
  shape (filled vs outlined) and nothing animates. fl_chart (ADR-018) was not
  added: its newest release was inside the 14-day window and the previous one
  would have forced a transitive `equatable` downgrade; the chart widgets are
  isolated so swapping in fl_chart later is local.

## Records and insights (P11 round 3)

| Route | Screen |
|---|---|
| `/receipts` | Receipt inbox (status chips, 50 at a time with "Load more"); "Add receipt" takes a photo, a library photo or a file, shows the upload steps (cancellable) and creates the receipt for manual entry with an Idempotency-Key. If creating fails, the uploaded page and the key are kept for "Try again" (no second upload, no duplicate receipt). Nothing is read automatically: neither `read_automatically` nor `skip_extraction` is sent and `POST /receipts/{id}/process` is never called. |
| `/receipts/:id` | Pages (images shown in the app; PDFs and other files open, share or save), status and next step in words, entered values and items, warnings from `warning_codes`, linked transaction, history; unlink, discard (`?version=`, confirmed) and restore (`POST /receipts/{id}/restore?version=`). Coded conflicts reload the receipt. |
| `/receipts/:id/review` | Manual review: date and total required; merchant, time, currency, subtotal, tax, tip, discount, number, how it was paid ("cash, UPI or card"; the form says not to enter card or account numbers, and the server masks them) and items; `version` with conflict reload. |
| `/receipts/:id/match`, `/:id/record` | Suggested expenses with reasons from `reason_codes` (or any expense) → link; or, once the values were entered by hand, record the purchase as a new expense (Idempotency-Key). |
| `/transactions/:id` | Attachments: add (camera, photo or file → `POST /transactions/{id}/attachments`), open/preview, share, save, detach; a link to the receipt when there is one. |
| `/imports[?account_id=]`, `/imports/new[?account_id=]` | Import history; the wizard (account → CSV, XLSX or OFX file → upload → `POST /imports`). PDF statements are not offered: reading them needs AI, which Montra does not use. |
| `/imports/:id`, `/:id/mapping`, `/:id/rows[?status=]` | One import: status in words, polled while it works (2 s, slowing down, stopping after 10 minutes or when the screen closes); column mapping by header name with sample values; rows by status with "Load more", per-row import/skip, category and corrections; confirm (Idempotency-Key and `version`), cancel, retry failed rows and roll back (confirmed); summary with the balance check; "Check against the statement". |
| `/accounts/:id/reconcile`, `/:id/reconcile/new` | Balances (statement vs ledger, the server's difference, "Matches" or "Off by …"), suggested matches (statement↔ledger, pending→posted, entered twice) and confirmed matches with undo; a new statement balance check. Opened from the account detail screen. |
| `/analytics`, `/analytics/:report`, `/analytics/compare` | Period picker and one currency at a time; cash flow, expenses and income (bucket size), categories (drill down to transactions), merchants, accounts, budgets, goals, subscriptions, recurring (`note_code`) and a comparison of two periods (category changes with `change_bp`). |
| `/reports`, `/reports/new`, `/reports/:id`, `/reports/schedules`, `/reports/schedules/new` | Reports (polled while generating), request one (type, format, period), download once and share or save; expired links explained ("Make it again"); weekly/monthly schedules (create, delete). The API has no report delete, so files simply expire. |
| `/exchange-rates`, `/new`, `/convert` | Rates (source and date in words; own manual rates first, deletable), add a manual rate (currencies from `GET /currencies`, exact decimal), convert an amount with the server's rate and rounding. |

Home has a second shortcut row, "Review your money" (receipts, import a
statement, analytics, reports). Profile has "Records and insights"
(receipts, statement imports, analytics, reports, exchange rates, and file
storage use from `GET /limits` with the fair-use limits). The account
detail screen offers "Reconcile" and "Import a statement".

Rules these screens add to the round-2 ones:

* **No AI.** Receipts are entered by hand; imports take CSV, XLSX and OFX;
  no `/ai/*` endpoint is called.
* **Never across currencies.** Analytics, reconciliation and imports show
  the server's per-currency figures; nothing is added up or compared across
  currencies on the device. Every chart has a text summary and a list view.
* **Polling** (imports, reports) stops when the work is done, when the
  screen closes or after a time limit, and pull-to-refresh is always there.

### Files (`core/files`)

* **Uploads** follow the contract's three steps: `POST /files/upload-intent`
  (purpose, name, type, size, SHA-256) → `PUT /files/{fileId}/content` with
  the raw bytes, `X-Upload-Token` from the intent and `X-Upload-Checksum` →
  `POST /files/{fileId}/complete`. The bytes always go to the configured API
  (never to the response's `upload_url`). The checksum is computed in a
  background isolate by `core/files/sha256.dart` (checked against the NIST
  vectors), because `crypto` is not a direct dependency.
* **Limits** mirror `Policies` in `backend/internal/files/files.go` and are
  checked before anything is sent: receipts, bill documents, transaction and
  goal attachments take JPG, PNG, WEBP, HEIC and PDF up to 15 MB; invoices
  PDF, JPG and PNG up to 15 MB; statements CSV, XLSX and OFX up to 10 MB;
  profile photos up to 5 MB.
* **Picking:** camera and photo library through `image_picker` (the system
  camera app, Android's photo picker and iOS's PHPicker: no camera or
  storage permission is requested), documents through `file_picker` (the
  Storage Access Framework / the iOS document picker). Only the chosen file
  is read; camera photos are scaled to 3000 px at JPEG quality 85.
* **Downloads:** `GET /files/{fileId}/access` (or a report's download)
  returns a link valid for a few minutes. The app fetches its path and
  signed query from the configured API origin (servers sign links with
  their public host, which an emulator or phone may not reach), accepts only
  this API's `/files/{id}/content`, sends no bearer token and never stores,
  shows or logs the link. Images are shown in the app; other files open in
  the share sheet (`share_plus`) or are saved where the user chooses
  (`file_picker`'s save dialog).

### Adopting the contract changes made after round 2

* **Partial PATCH** for bills, recurring rules, subscriptions, budgets,
  goals, tags, merchants and categories (`core/api/partial_patch.dart`):
  the loaded form is compared with the edited one; only changed fields are
  sent, emptied text fields as `""`, lists as `[]`, other optional fields
  through `clear` (the schema's values). A new frequency sends the whole
  schedule. Saving without changes sends nothing and says so.
* **Idempotency-Key** on `POST /bills`, `/recurring-rules`,
  `/subscriptions`, `/goals` and on recording a planned goal contribution
  (`IdempotentSubmission`: the key is kept for retries of the same request,
  renewed after success, reset on `IDEMPOTENCY_CONFLICT`).
* **Lifecycle:** bills use `pause|resume|archive|restore`, budgets
  `restore`; every lifecycle action and goal member change sends
  `?version=` of the record on screen; `VERSION_CONFLICT` reloads it; only
  the moves the server allows are offered.
* **Coded errors** are localized once, in `core/widgets/error_messages.dart`:
  `invalid_status_transition` names both statuses in the user's language,
  `record_limit_reached` names bills, recurring payments, subscriptions or
  goals with the limit, and every other code in docs/API.md that the app
  can receive (planning, labels, goals, subscriptions, `DUPLICATE` details,
  files, receipts, imports, reconciliation, reports). Unknown codes fall
  back to the server's message.
* **Bills and recurring:** payment candidates explain their `reason_codes`
  and days from the due date; rules show their `merchant` and link their
  bill; a moved occurrence says "Moved to <date>" (`postponed_to`); the
  calendar's statuses are typed (including goal target dates).
* **Subscriptions:** suggested charges to link, unlink, one checklist step
  at a time, the cancellation date (`cancelled_on`), detection confidence
  and evidence from codes, duplicate warnings from codes, price changes
  when recording a payment.
* **Budgets:** "Shared by …", alert levels from the published list (none
  turns threshold alerts off), overspent allocations, the explanation from
  codes, counted transactions and alerts in pages, and the form only offers
  what a group or personal budget allows.
* **Goals:** the owner is listed with the Owner role, forecast assumptions
  from codes, the CSV export can be shared or saved, planned contributions
  can be recorded, contributions page with "Load more".
* **Labels:** typed merge previews (including budgets whose filters
  follow), merchant merge preview, removing another name, merchants by
  status with "Load more", `version` on tags, merchants and rules, removing
  a colour, the currency of rule amount limits, applying a saved rule, and
  the new error field paths.
* Lists that are no longer nullable lost their `?? []` handling.
* **Live API ahead of the committed contract:** resolved in round 4 — the
  regenerated contract declares `POST /receipts/{id}/restore` and the
  `Idempotency-Key` of `POST /receipts`, so the `pending*` lists are gone.

## Together, help and privacy (P11 rounds 4–5)

The bottom bar now has five tabs: Home, Transactions, **Insights**,
**Together** (friends, groups, communities, challenges) and Profile. Unread
notifications show as a badge on Profile (read by screen readers as "N
unread notifications"); at 200 % text only the selected tab shows its label
so the others do not break inside words. Home's app bar has Search and the
notification bell. Profile has a "You and your data" section
(Notifications, Friends, Connected services, Privacy & data, Moderation
decisions, Help & support); its file-storage row opens the limits screen.
The account detail screen adds "Connect to the bank"; a group's overview
adds "Start a challenge". Route files: `routes/social_routes.dart`,
`group_money_routes.dart`, `community_routes.dart`,
`engagement_routes.dart`, `support_routes.dart`. No AI feature is built and
no `/ai/*` endpoint is called.

| Route | Screen |
|---|---|
| `/together` (tab) | Hub: friends (pending requests), groups, communities, challenges, and "join with a link" for groups and communities. |
| `/friends[?tab=friends\|requests\|find]`, `/friends/blocked`, `/friends/settings` | Friends (remove after confirming), requests (accept, decline, cancel), find by **exact** username (3+ characters, a leading `@` ignored; only people who turned discovery on are found, which the screen explains), send a request (`already_friends`, `request_pending`, `requests_closed` localized; a 201 `accepted` says "You're now friends"). Block/unblock and mute/unmute from a person's row; blocked and muted people (`GET /blocks`, `/mutes`, cursor pages). Privacy for friends (`PATCH /me` with only changed fields): username (the server strips a leading `@`), "Let people find me by username" (`discoverable_by_username`, off for new accounts, explained) and who may send requests. |
| `/groups`, `/groups/new`, `/groups/join#token=`, `/groups/:id`, `/groups/:id/edit`, `/groups/:id/settings`, `/groups/:id/activity` | Groups with `my_net` in words ("You are owed / You owe / Settled up"), archived filter; create (type, base currency, split method, simplify, member invites, join approval off by default and explained, trip dates); join by link: the token is read from the URL fragment or a pasted link, previewed (`POST /group-invitations/preview`), accepted (200 joined → the group; 202 → "waiting for the admins"; 410 explained), never logged or stored, and the screen is replaced afterwards; invitations addressed to me (accept/decline). Overview: balance, members and roles, money links, typed activity (every `GroupActivityDto.kind` becomes a sentence from the typed summary; lines open the expense, payment or recurring expense, disputes their `target`, older events as expenses). Settings by role: details (`GroupPatch` with only changed fields and `version`, conflict reload), members (role, notification level, remove — the dialog explains that a member with an open balance can be removed and keeps their balance — and add by username or friend), link invitations (shown once with Copy/Share, revoke), username invitations, join requests, transfer ownership, archive/restore, delete (`confirm=true`), leave (`balance_open`, `transfer_ownership_first`). |
| `/groups/:id/expenses[/new\|/:expenseId\|/:expenseId/edit]` | Expenses (cursor pages; status, payer, category, dates); create/edit with every split method (equal, exact, percentage, shares, by item; a labelled preview only — the server computes the split), one or several payers (a single payer is sent without an amount: the server makes them the whole amount), another currency with Montra's rate (`lookup`) or the user's (`manual`) — `amount` is left out and derived by the server, which returns the rate, source and time; payer account, a receipt (`group_attachment` upload), notes; create with `Idempotency-Key`, edit with `version`. Detail: shares, payers, FX block, receipt, comments (plain text), disputes (raise, withdraw, resolve), "record my payment" (link/unlink), delete. |
| `/groups/:id/balances`, `/groups/:id/settlements[/new\|/:settlementId\|/:settlementId/correct]` | Balances (paid, share, sent, received, pending; removed members labelled), my net, simplified vs as recorded, suggestions with "Record a payment". Settlements: record (`Idempotency-Key`; paid or planned; method, date, note, proof, own account), lifecycle buttons by status and role (mark paid, confirm — an admin confirms for a former member —, dispute, void with a reason, record/remove in my account, correct with a new key), every action with `version`; Montra never moves money and says so. |
| `/groups/:id/recurring[/new\|/:ruleId\|/:ruleId/edit]`, `/groups/:id/reports` | Recurring shared expenses (create with `Idempotency-Key` and the shared schedule editor; edit name/amount/split with `version`; pause/resume/stop; occurrences add (idempotent) or skip). Reports with accessible charts (text summary + list) and the CSV export (`text/csv`) shared or saved. |
| `/communities[?tab=]`, `/communities/new`, `/communities/join#token=`, `/communities/:ref`, `/communities/:ref/posts/new`, `/communities/:ref/settings`, `/communities/:ref/members`, `/communities/:ref/moderation`, `/posts/:id`, `/posts/:id/edit` | Discover/search, yours, invitations (accept/decline); create (URL name, `slug_taken`); join by link (preview → accept; 410 and `already_member` explained). Community page: join/leave/pending/banned/restricted states, rules, feed New/Top/Active with search and cursor pages (`offset` never sent), composer (discussion, question, https-only resource, poll), report. Post page: plain text, links opened in the browser only when http(s), reactions rendered from the server's `my_reactions`, poll vote, threaded comments (reply, edit/delete own, report), hidden/removed states, moderator actions. Settings (`CommunityPatch` with `version`), members (approve/reject, roles, warn, restrict with a duration, ban), invitations (link shown once, by username, list/revoke), transfer, archive/restore. Moderation: reports queue, actions, appeals (decide), log (reverse). |
| `/challenges`, `/challenges/new[?group_id=\|?community_id=]`, `/challenges/:id`, `/challenges/:id/edit` | List (cursor), create, detail: join with share/leaderboard choices, check-in (same date corrects), progress, streaks, milestones (25/50/75/100 % of `percent_complete`), sharing settings, leave, leaderboard only when the caller shares and opted in (otherwise explained), `ChallengePatch` edit with `version`, cancel. |
| `/moderation[?tab=decisions\|appeals\|reports]` | Decisions about you (reason, duration, appeal window, appeal state and outcome: upheld = stands, overturned = reversed), appeal within the window (`appeal_pending`, `appeal_window_passed`), your appeals, reports you filed. |
| `/notifications`, `/notifications/settings` | Center: Inbox/Unread/Archive, topic filter, cursor pages, read/unread/archive, mark all read; opening one marks it read and follows its deep link (web routes with IDs mapped to app routes in `features/notifications/domain/deep_links.dart`, entity fields as fallback). Settings: topic × channel switches (only the changed field is sent), locked security/account rows explained as always on, per-topic email timing incl. weekly, account digest and quiet hours. **Push on mobile is not configured in this build**: no Firebase or push SDK is included and no device is registered; the screen says so. |
| `/search` | Global search: typing searches with `save=false` after 400 ms; only submitting sends `save=true`; every section incl. categories, bills, subscriptions, recurring rules and budgets; scope and sort; recent searches (re-run, clear). |
| `/insights` (tab), `/insights/:id`, `/insights/mutes` | Deterministic insights (cursor pages, "all, including handled", kind filter), messages localized from `message_code` + `message_params` (Money values formatted exactly; English fallback), rule explanation, actions (expected, resolved, snooze, dismiss, mute, reopen), feedback with `my_feedback`, mutes with unmute (`UnmuteResult`: "N insights came back"). |
| `/integrations[?account_id=]`, `/integrations/connections/:id` | Providers with honest statuses ("Not configured in this environment", "Not available yet" + the server's reason); Connect only for available ones: consent dialog → account → the provider page in the system browser (`url_launcher`, http(s) only). The provider returns to the **web app**, which finishes the connection; the app then shows it on refresh. Status with recent syncs, sync now, disconnect (optionally removing imported transactions). |
| `/help`, `/help/new`, `/help/requests/:id` | Help & support: short answers to common questions (each opens the screen it is about), the user's requests with status and message count, a new request (kind, subject, message; text that looks like a card number, PIN, OTP, CVV or password is refused on the phone before sending, mirroring the API's `contains_secret` check; the daily limit says when it opens again from `Retry-After`), and a request's conversation with Montra support (`GET/POST /support/requests/{id}/messages`; plain text; a closed request takes no replies, `request_closed`). |
| `/contact` (public) | Contact form for people who are signed out (`POST /support/contact`, no token sent): email, kind, subject, message; shows the reference. Linked from the welcome and sign-in screens. |
| `/privacy[?export=]`, `/privacy/deactivate`, `/privacy/delete` | Privacy & data: required consents (accepted version) and optional ones as switches, granted with the wording version from `GET /legal` (no constant in the app); AI consents are shown only when given elsewhere and can only be withdrawn. A copy of all data (`POST /me/export`, re-authentication when the server asks: `REAUTH_REQUIRED` → the existing re-auth sheet → retry), polled every 3 s while queued/running (stops when ready, when the screen closes, or after about two minutes), downloaded through the signed link and shared or saved; failed and expired copies say what to do; `?export=` (notification link) highlights one. Closing the account (`POST /me/deactivate`, confirmed, then the local session ends) and deleting it (`GET/POST/DELETE /me/deletion-request`: consequences, what is kept and group impact localized by code with the English as fallback, typed `DELETE`, re-authentication, cancel until the date). |
| `/limits` | Every fair-use limit from `GET /limits`: storage meter (text + bar, read as "N percent used"), largest upload, open bills/recurring/subscriptions/goals caps, import rows, support requests per day, download days, deletion grace, requests per minute per policy (the AI policy is not shown: the app has no AI), and the `note_code` text. Opened from Profile's storage row, Privacy & data and Help. |

Staff tools (support queue, platform moderation incl. `GET /moderation/actions`,
admin usage) are **web-only**: the spec allows it and the mobile app has no
staff role screens. Community moderators moderate in the app.

Rules these screens add:

* **Coded errors** stay localized in one place: generic field codes
  (`required`, `too_short`, `too_long`, … `contains_secret`, `slug_taken`),
  `daily_cap` (429 with `Retry-After`: "You've reached today's limit (N a
  day). Try again in …"; `ServerFormErrors` shows throttling as a form-level
  message with the wait) and the membership codes shared by groups and
  communities live in `core/widgets/error_messages.dart`; each area adds its
  own codes in `features/<area>/domain/<area>_codes.dart`, registered in the
  `_featureCodes` list.
* **Invitation links** carry the token in the fragment only. Shared links
  use `--dart-define=WEB_APP_URL=https://…` when set; otherwise group links
  use the API origin and community invitations share the code to paste.
  Signed-out users who open `/groups/join` or `/communities/join` are sent to
  sign-in with `?next=` (in-app paths only) and land on the link afterwards
  (`AppRoutes.joinRoutes`). Android declares both paths as App Links.
* **User content** (posts, comments, support messages, group comments) is
  rendered as plain `Text`; links open only when `http(s)`.
* `/contact` is public (`AppRoutes.publicRoutes`), linked from the welcome
  and sign-in screens.

### Adopting the round-4 backend changes (Part A)

* **Receipts:** the raw-JSON readers are gone; `warning_codes` /
  `warning_params` and match `reason_codes` come from the generated models;
  `restoreReceipt` is in `ApiEndpoints.all` and `createReceipt` is
  `idempotent: true` (the pending-contract reminder tests were removed).
* **Imports:** `POST /imports` with `Idempotency-Key` (kept for retries);
  history pages with a cursor; row `error_code` / `error_params` localized and
  the correction sheet shows the problem under `error_field`;
  `duplicate_reason_codes`; `mapping_note_codes` with the assumed/alternative
  date formats; batch `error_params`; `to_import_rows` ("Import N rows");
  Money totals.
* **Reconciliation:** `reason_codes` + `reason_params`, `record_status` and
  `source`, match items with date/direction/description and the kept
  `total`, stored history counts, cursor pages; **match by hand**
  (`/accounts/:id/reconcile/lines`: `GET /accounts/{id}/statement-lines`,
  pick a line and unreconciled transactions going the same way,
  `POST /reconciliation/matches`, unmatch).
* **Reports:** delete (any status, confirmed), schedule edit
  (`/reports/schedules/:id/edit`, `SchedulePatch` with only changes and
  `version`), pause/resume, `window` shown, `expired`, every `error_code`,
  "Make it again" with the same dates.
* **Analytics:** income per category (`kind=income`, `amount`), per-total
  comparison changes (`change`, `change_bp`) with localized `note_codes`,
  the server's `previous_window`, per-currency ranking.
* **FX:** a bare `as_of` date (that day in the user's time zone; today
  allowed); rates shown as served (no padding).
* **Elsewhere:** calendar "Moved from …" (`scheduled_on` / `postponed_to`),
  subscription `payments[]`, budget alerts per budget (`?budget_id=`),
  `GET /tags/{id}` and `/category-rules/{id}` reloads after conflicts, bill
  field names, recurring `invalid_status_transition`, account
  `last_reconciled_at` / balance / `last_import_at`, optional goal member
  names, group expense single payers without an amount,
  `converted_too_small`, `consent_version_outdated`, `appeal_pending`,
  `appeal_already_decided`.

## Planning cards, profile, preferences and receipts (round 6)

**Home planning cards.** `GET /dashboard/planning` feeds four widgets with
one request (`dashboardPlanningProvider`, re-read after finance, budget and
goal writes): *Budgets* (fullest first, "2 active budgets · 1 is over
budget", spent of limit, a bar and the pace in words), *Coming up* (overdue
items first, "Was due …" / "Due today" / "Due …", the occurrence status in
words, "N more in the calendar"), *Goals* (saved of target, target date)
and *Group balances* ("You are owed …" / "You owe …" with an icon). Each
card has its own loading, empty (with the next step: create a budget, add
a bill, create a goal) and error state (with Try again, which re-reads once
for all four), opens its full screen ("See all", rows open the budget,
calendar source, goal or the group's balances) and says when it lists only
the first items. `dashboard_widgets.dart` and the layout screen know all
twelve widgets (`DashboardWidgetKind`); the layout is kept as wire keys
(`DashboardWidget`), so hide, reorder and reset keep working and a widget
from a newer server is skipped on Home but saved back unchanged. Hidden
planning widgets are not requested. On first use (no accounts or
transactions) only planning cards with something in them are shown.

**Profile → Edit profile** (`/profile/edit`, `PATCH /me`): photo, display
name, username, bio, location, interests (up to 10, each up to 40 bytes, as
the server keeps them) and who can see the profile. Only changed fields are
sent; an emptied bio, location or username is sent as `""` and no
interests as `[]`. The photo is picked (camera, photo library or files),
uploaded with purpose `avatar` through the `core/files` upload dialog, then
set with `PATCH /me {avatar_file_id}`; *Remove photo* asks first and sends
`""`. It is shown through `GET /files/{id}/access` (initials otherwise, also
on Profile). `username_invalid`, `username_reserved`, `username_taken` and
`avatar_file_invalid` are shown on their field.

**Profile → Preferences** (`/profile/preferences`, `PATCH /me/preferences`):
base and second currency, default account (or `clear_default_account`),
default period, language and region, time zone (this device's, a
searchable list of common zones, or any typed IANA zone), country, date
and number format (with examples), week start, month start day, theme,
and accessibility: reduce motion, high contrast and text size (80–200 %,
slider with − / + buttons and a preview). Only changed preferences are
sent; leaving with unsaved changes asks first. The screen explains the base
currency (it is the default for new accounts, budgets, goals, bills and
receipts and comes first on Home; changing it converts nothing, as in
`backend/internal/users/users.go`, which only stores the new code).

Saved preferences apply at once (`core/settings/app_preferences.dart`;
`MontraApp` loads them when a user is signed in):

* `reduced_motion`, `high_contrast` and `text_scale_percent` are added to
  the device's settings in `MediaQuery` (either one asking for reduced
  motion or high contrast turns it on; the text size multiplies the
  device's, keeping nonlinear scaling). Reduced motion removes page
  transitions (`ReducedMotionPageTransitionsBuilder`) and theme
  animations; high contrast uses `AppTheme.light/dark(highContrast: true)`
  (Material's highest contrast level, 2 px card borders, darker status
  colors), also for the system setting.
* `locale` sets the app language when it is English or Hindi.
* `number_format` `indian` / `international` sets the amount grouping
  (`numberLocaleOf`); `locale` keeps the language-and-region rule.
* The theme is saved to the account and applied on this device.
* Base currency, time zone and locale are mirrored in the signed-in
  summary, so new forms default to the new currency at once.

**Multi-page receipts.** *Add receipt* opens `/receipts/new` (mirrors the
web's add-receipt dialog): *Take a photo*, *Choose photos* or *Choose
files* (several at once; `FileSource.pickMany`, up to 20) add pages, each
with its position, name, size and state in words (ready, uploading with the
step and percentage, uploaded, adding, added, or why it failed), move up /
down and remove buttons. Several files are *pages of one receipt* (one
`POST /receipts` with `file_ids` in the order shown) or *separate
receipts*; an optional note is sent too. Pages upload one at a time; trying
again uploads only what is missing and reuses the Idempotency-Key of the
same request, so nothing is added twice. *Stop uploading* creates nothing.
Pages that never became part of a receipt are deleted
(`DELETE /files/{id}`) when removed or when leaving (which asks first);
after a lost answer they are kept, since the receipt may exist.

**Also adopted:** `GET /insights/{id}` (the detail no longer searches five
pages of the list; 404 or a malformed ID reads as "not available"),
`GET /reports/schedules/{id}` for the edit screen, `TransactionDTO.group_id`
(a group-linked transaction opens that expense or settlement in its group),
`share_url` on new group and community invitation links (preferred when it
is an http(s) join link with a token; otherwise the `WEB_APP_URL` / API
origin fallback), and localized `query_too_short`, `username_or_user_id`,
`confirm_word_mismatch`, `deletion_already_scheduled`,
`no_deletion_scheduled`, `duplicate_item`, `transaction_already_matched`,
`sync_running`, `already_reported` and `invalid_status_transition` for
shared recurring expenses (which also reloads the rule).

## Sessions and security (ADR-002, mobile variant)

* Every request sends `X-Montra-Client: android|ios` and
  `X-Client-Version: <version>+<build>` (declared in the contract as
  `components.parameters`); for these clients the backend returns tokens in
  the response body instead of web cookies. On platforms the contract does not
  list (tests, desktop) the client header is omitted. `X-CSRF-Token` is never
  sent: it only applies to cookie (web) sessions.
* The **access token lives in memory only**. The **refresh token is the only
  persisted credential**, stored with `flutter_secure_storage` (iOS Keychain
  `first_unlock_this_device`, never synced; Android Keystore-wrapped AES-GCM).
* `AuthInterceptor` adds `Authorization: Bearer …` to protected operations.
  A `401` whose code is `UNAUTHENTICATED` triggers one **single-flight**
  `POST /auth/refresh` shared by all concurrent requests, stores the rotated
  refresh token, and retries each request once. Requests issued during a
  refresh wait for it; tokens about to expire are refreshed proactively.
  `MFA_REQUIRED`, `MFA_CODE_INVALID`, `MFA_CHALLENGE_EXPIRED` and
  `REAUTH_REQUIRED` are also `401` on this API, so the interceptor branches on
  the error **code**, never the status (`ApiErrorCodes.noRefresh401`).
* A rejected refresh clears all credentials and routes to sign-in with an
  explanation; an offline/5xx refresh keeps them and surfaces a retryable
  error. A refresh that finishes after sign-out can never resurrect a session.
* On start, a stored refresh token is rotated and `GET /auth/session` loads
  the account. If Montra is unreachable the splash screen offers a retry
  (automatic on reconnect) or "sign out instead".
* Two-step sign-in: `MFA_CODE_INVALID` shows a field error and the same
  `mfa_token` is retried; `MFA_CHALLENGE_EXPIRED` returns to the password step
  with an explanation (the email stays filled in).
* Sensitive actions that answer `REAUTH_REQUIRED` (TOTP setup/disable,
  recovery-code regeneration) open a re-authentication bottom sheet and retry.
  The sheet asks for the password plus, when two-step verification is on, an
  authenticator code or a single-use recovery code ("Use a recovery code
  instead"), so users who lost their authenticator can still manage it.
* Throttling (`RATE_LIMITED`, `LOGIN_THROTTLED`) honors `Retry-After`: the
  submit button counts down, in minutes for long waits such as the 15-minute
  sign-in window.
* Nothing logs tokens or personal data: debug-only request logging prints the
  method, endpoint template, status and request ID; models and errors have
  redacted `toString()`; the router never logs locations (they can carry
  tokens).
* Android: backups and device-to-device transfer are disabled; cleartext HTTP
  is allowed only in debug builds (`src/debug/res/xml`); screens showing the
  TOTP secret or recovery codes set `FLAG_SECURE` (no screenshots/recents
  thumbnail).
* iOS: Keychain items survive app deletion, so the first launch of a fresh
  install wipes anything a previous install left behind. iOS has no
  `FLAG_SECURE` equivalent; secrets are shown only on the setup screens.

## Deep links

Emailed links use the web portal's URLs, so one link works for both clients:
`/verify-email#token=…` and `/reset-password#token=…`. They open in any auth
state (signed in or out, during session restore). Every other screen needs
an account: a signed-out link to it goes to Welcome (or straight to sign-in
for invitation links and after an involuntary sign-out) with the link kept
as `next`, which Welcome, sign-in, sign-up and check-email pass along;
after sign-in the app opens it, after the (skippable) onboarding first when
that is still due. A cold start on a link while the session is restored
keeps it the same way (`/splash?next=`). `next` is only ever an in-app path:
external URLs, relative paths and auth screens (welcome, sign-in, sign-up,
splash, onboarding, emailed-link screens) are refused, so it cannot leave
the app or loop. A voluntary sign-out starts over without `next`. The App
Links filters (release and debug) list all four emailed and invitation
paths.

**Android App Links.** `android/app/src/main/AndroidManifest.xml` declares a
verified intent filter for `https://${montraLinkHost}/verify-email` and
`/reset-password`. The host defaults to the reserved placeholder
`montra.example`; set the real domain with a Gradle property:

```sh
flutter build apk -Pmontra.linkHost=app.example.com
```

The web domain must serve `/.well-known/assetlinks.json` listing
`app.montra.mobile` and the release signing certificate's SHA-256 fingerprint.
Debug builds additionally accept `http://localhost` / `http://10.0.2.2` links
sent explicitly to the package (see the `adb` example above).

**iOS Universal Links.** `ios/Runner/Runner.entitlements` contains an
`applinks:montra.example` template but is **not wired into the Xcode project**
(personal/free signing teams cannot use Associated Domains, which would break
device builds). To enable: Xcode → Runner target → Signing & Capabilities →
+ Associated Domains, use `applinks:<web domain>`, and host
`/.well-known/apple-app-site-association` on that domain with the app's
`<TeamID>.app.montra.mobile` and paths `/verify-email`, `/reset-password`.

In production the backend's `WEB_APP_URL` must be that https domain so emails
contain links the app can claim. Pasting a link always works as a fallback.

## Accessibility, theming, localization

* Material 3 light/dark themes from the brand teal; System/Light/Dark override
  under Profile → Appearance (stored in non-sensitive preferences).
* 48dp minimum touch targets, unclamped system text scaling with scrollable
  layouts, semantics labels/headers, live regions for errors and the offline
  banner, field-associated error text.
* Status is never conveyed by color alone (icon + text in `StatusLabel`,
  `NoticeBanner`, password checklist).
* "Reduce motion" (the system setting or the account's preference) removes
  Android page transitions and theme animations; iOS keeps the
  user-driven back-swipe. The account's high contrast and text size apply
  on top of the system's (see round 6).
* `test/features/a11y_guidelines_test.dart` runs Flutter's
  `meetsGuideline` checks (Android 48×48 and iOS 44×44 tap targets,
  labelled tap targets, text contrast in the light theme) on Welcome,
  sign-in, sign-up, Home with every widget, Transactions, Insights,
  Together, Profile, Edit profile, Preferences and Add receipt, laid out in
  one tall window so nothing is half-clipped by scrolling.
  `test/app/accessibility_settings_test.dart` and `app_flow_test.dart`
  check that the account's reduced motion, high contrast, text size and
  language take effect.
* Strings come from ARB files (`lib/app/l10n/arb`). `en` and `hi` are both
  complete (`build/l10n_untranslated.json` is empty). Server messages are
  English; the app prefers localized text keyed by error code. Starter
  categories (server `system_key`) are shown in the user's language unless
  the user renamed them; the dashboard's calculation notes are server text
  and stay English.
* Money is formatted with `MoneyFormatter` from the exact `amount` string
  (never a `double`), with locale grouping from `intl` (Indian lakh/crore
  grouping for `en_IN`/`hi`) and 0/2/3-decimal currencies.

### Currencies

* Pickers (sign-up's main currency) load `GET /currencies` (public) through
  `currencyCatalogProvider` and offer only `selectable: true` entries; retired
  currencies such as BGN (replaced by EUR on 2026-01-01) are hidden but stay
  valid for history. A device-region suggestion that turns out to be retired
  is swapped for its `replaced_by` currency.
* `lib/core/formatting/currency_snapshot.dart` is a generated snapshot of that
  endpoint, used only offline (minor-unit exponents for formatting, region
  suggestions). Refresh or verify it against a running API:
  ```sh
  dart run tool/currency_snapshot.dart --api http://localhost:8080          # rewrite
  dart run tool/currency_snapshot.dart --api http://localhost:8080 --check  # verify
  ```

## Platform configuration summary

* **Android:** `INTERNET` permission in all builds (no camera, storage,
  SMS or notification-reading permission); `allowBackup=false` and
  data-extraction rules; HTTPS-only network security config for release and
  profile builds; App Links intent filter; `FLAG_SECURE` method channel in
  `MainActivity.kt`; a `<queries>` entry for `IMAGE_CAPTURE` so the system
  camera app can return receipt photos on Android 11+ (image_picker hands
  the capture to it, so no `CAMERA` permission is declared). Release signing reads `android/key.properties` when
  present (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`); without
  it, `flutter run --release` falls back to the debug key and **such builds
  must not be distributed**. Keystores and `key.properties` are git-ignored.
* **iOS:** display name "Montra"; camera and photo-library purpose strings
  for photographing or choosing a receipt or document (the camera prompt
  appears only when the user takes a photo; photos are chosen with
  PHPicker); `NSAllowsLocalNetworking` for the development API;
  `ITSAppUsesNonExemptEncryption = false` (standard HTTPS only);
  `FlutterDeepLinkingEnabled`.

## Dependencies

Only stable releases that had been public for at least ~14 days at the time of
setup (2026-11-04) are used, including transitive packages: the
`pubspec.lock` pins `crypto 3.0.7`, `cupertino_ui 1.1.4`, `jni 1.1.0`,
`material_ui 1.8.0`, `qr 3.0.2`, `shared_preferences_android 2.4.28` and
`web 1.1.1` instead of releases published days earlier, and `go_router` is
pinned to `18.1.1` in `pubspec.yaml` for the same reason. Run
`flutter pub upgrade` deliberately and re-check release dates when upgrading.

Rounds 4–5 added **no dependency** (links open with the existing
`url_launcher`; no push, analytics or tracking SDK).

Round 3 added three plugins, each from a well-known publisher under a
permissive license, pinned to releases older than 14 days on 2026-11-05:

| Package | Version | License | Why |
|---|---|---|---|
| `file_picker` | `13.1.0` (exact: 13.2.0–13.3.2 were inside the window) | MIT | Choosing statement files (CSV, XLSX, OFX) and documents through the system picker, and the system "save as" dialog for downloads. No storage permission. |
| `image_picker` | `^1.2.4` (flutter.dev) | Apache-2.0 / BSD-3-Clause | Receipt and attachment photos from the system camera app or the photo library (Android photo picker, iOS PHPicker). |
| `share_plus` | `^13.3.1` (fluttercommunity.dev) | BSD-3-Clause | Sharing downloaded reports, receipts, attachments and goal CSV exports through the share sheet. |

Their newest platform packages were published inside the window, so the
lock file pins `android_file_picker 2.1.1`, `file_picker_darwin 2.3.2`,
`file_picker_linux 2.0.2` and `image_picker_ios 0.8.13+12`.
`path_provider` and `open_filex` were not needed. No analytics, tracking,
SMS or notification-reading SDK is used.

go_router 18 targets the decoupled `material_ui` package; this app uses the
SDK's `package:flutter/material.dart`, so every route uses an explicit
`pageBuilder` that builds a Material page (otherwise go_router would fall back
to transition-less pages without the iOS back-swipe).

## Limitations and owner actions

* **iOS is unverified:** Xcode is not installed on the build machine, so no iOS
  build, simulator run or signing was attempted. The project was generated
  with `flutter create --platforms=android,ios` and configured as above.
* **Android builds** need Android cmdline-tools and accepted SDK licenses on
  the build machine (`flutter doctor --android-licenses`).
* Round 3 was smoke-tested on the Android emulator (Pixel 10 Pro image,
  debug build, `http://10.0.2.2:8080`): sign-in, Home's new row, analytics
  (overview and categories), Profile's new section and storage, exchange
  rates, reports, statement imports, reconciliation from an account, and a
  receipt photographed with the emulator camera, uploaded and previewed
  through the rewritten signed link. Everything else is covered by widget
  tests (English and Hindi, 200% text) and live API checks.
* Rounds 4–5 were run on the Android emulator (Pixel 10 Pro, debug build,
  `--dart-define=API_BASE_URL=http://10.0.2.2:8080`) with a throwaway user:
  the five tabs and the unread badge, the contact form signed out, sign-in,
  Together → Groups → a group → expenses → expense detail, adding a group
  expense through the form, Insights, search, the notification center and
  its settings, Help (a reply refused for a PIN on the phone, then sent),
  Privacy & data (a consent, a data export with re-authentication, polling,
  the signed download and the share sheet), the limits screen,
  communities (a post published and liked), challenges, friends, and the
  privacy-for-friends screen and Profile at 200 % system font. Everything
  else is covered by widget tests and live API checks.
* **Owner action — mobile push:** the backend supports FCM but has no
  credentials, and this build includes no push SDK and registers no device.
  Adding push needs a Firebase project (or APNs), its server credentials in
  the backend, a reviewed messaging package and a consent flow; until then
  the in-app notification center is the mobile channel.
* Set `WEB_APP_URL` (and the backend's `WEB_APP_URL`) to the real web
  domain so shared invitation links open the app through App Links.
* Confirm the application/bundle ID, the deep-link domain, release signing,
  and the Apple Team for Associated Domains.
* Hosted Terms/Privacy documents do not exist yet; pass `TERMS_URL` and
  `PRIVACY_URL` once they do (the sign-up checkbox otherwise has no link).
* The mobile app has no CAPTCHA (Turnstile) widget yet; `docs/API.md` keeps
  CAPTCHA disabled until the clients ship it. If it were enabled,
  sign-up/sign-in/forgot-password would show the `body.captcha_token` error.
* Round 6 was run on the Android emulator (Pixel 10 Pro, debug build,
  `--dart-define=API_BASE_URL=http://10.0.2.2:8080`) with a throwaway
  user (the saved-password prompt declined): sign-in, the four planning
  cards with live data (an over-budget budget, a scheduled bill, a goal,
  "You are owed ₹1,000.00" opening the group's balances), Preferences
  (reduce motion, high contrast and 130 % text saved and applied across
  the app at once), Edit profile (a camera photo uploaded as the avatar
  and shown through its signed link) and a two-page receipt from two
  camera photos, reordered and added, opening with both pages. Signed-out
  deep links to other screens cannot be sent to the app on Android (the
  App Links filters cover only the emailed and invitation paths), so
  `next` is covered by widget tests.
* The date format and week start preferences are saved for the server's
  exports, reports and weekly budgets; dates inside the app still follow
  the app language.
* Before store submission: privacy manifest (`PrivacyInfo.xcprivacy`), App
  Privacy / Data safety forms, store listing, and an accessibility review on
  real devices with TalkBack/VoiceOver.

## Contract notes

Checked against `contracts/openapi/montra.v1.json` (330 paths, 420
operations, 589 schemas) and the local API. The app calls 389 of the
operations, all listed in `ApiEndpoints.all` and checked by the contract
test. Not called: `/ai/*` (no AI), receipt processing, staff tools
(support queue, platform moderation, admin usage: web-only), push
registration and push config (no push in this build), webhooks, the OAuth
callback (handled by the web app), unsubscribe (web page) and saved
filters.

**Resolved in the current contract and adopted here:** error codes are a closed
enum (`ErrorObjectCode`) documented in `docs/API.md`; `/auth/mfa/verify`
distinguishes `MFA_CODE_INVALID` from `MFA_CHALLENGE_EXPIRED`;
`/auth/reauthenticate` accepts `recovery_code`; password `minLength` is 10 and
policy errors name the submitted member (`body.password` on register,
`body.new_password` on reset/change — the app still accepts either);
`LOGIN_THROTTLED` sends `Retry-After`; `GET /currencies` exists (with
`selectable`, `replaced_by`, `retired_on`); `GET /auth/session` returns real
session timestamps; client/CSRF request headers and `X-Request-ID` /
`Retry-After` response headers are declared as components; error statuses are
declared per operation; ADR-005 names `tool/gen_api.dart` as the Dart
generator.

**Found in round 6:**

1. `WidgetDTO.key` listed only the first eight widgets while the server
   sends twelve; fixed in the contract during the round. The app keeps
   wire keys anyway, so a newer widget is skipped and saved back.
2. `ProfilePatch.interests` items have no `maxLength`, but the server
   silently drops items longer than 40 *bytes* (fewer Hindi letters) and
   still answers 200. The app refuses them before sending; a coded error
   (or `maxLength`) would be clearer.
3. `GET /insights/{id}` and `GET /reports/schedules/{id}` answer a
   malformed ID with 422 on `path.id` without a code instead of 404; the
   app reads it as "not available".
4. `PreferencesDTO.default_date_range` is a free string while the PATCH
   member is an enum, and `PreferencesDTO.text_scale_percent` has no
   80–200 bounds (the app clamps).
5. A blank `display_name` answers `body.display_name` without a code
   (other profile fields now have codes).

**Still worth a look:**

1. `recovery_code` has `maxLength: 32` in `ReauthBody` but `20` in
   `MfaVerifyBody` and `DisableMFABody` for the same value (codes are 11
   characters, e.g. `abcde-fghjk`).
2. Re-authentication and TOTP disable still answer `MFA_REQUIRED` for a
   *wrong* code (sign-in uses `MFA_CODE_INVALID`), so "code missing" and
   "code wrong" look the same there. The app shows one message for both.
3. Turning two-step off needs a fresh re-authentication (password + code)
   and then a second code; TOTP replay protection rejects reusing the first
   one, so users must wait for the next code (or use a recovery code). The
   app explains this, but accepting the re-authentication's factor would be
   simpler.
4. `LOGIN_THROTTLED`'s `Retry-After` is always the full failure window (15
   minutes by default), an upper bound rather than the remaining time.
5. `CurrencyDTO.retired_on` is a calendar date without `format: date`.
6. Operations declare statuses but not which codes a status can carry (for
   example which 401 codes `/auth/mfa/verify` returns); a per-operation list
   (e.g. an `x-error-codes` extension) would let clients test their branching
   against the contract instead of `docs/API.md`.

**Found while building the finance screens (P11 round 1)** (items 1–8 were
fixed in the contract for round 2 and adopted: comma-joined lists with 422
`repeated_parameter`, typed enums, partial payment-method PATCH with
`version`/GET/restore, transfer endpoints and fields, readable onboarding
progress, monthly INR income ranges, `note_codes`/`system_key`, refunds
inheriting the merchant):

1. Array query parameters (`type`, `account_id`, `category_id`, `tag_id`, …)
   are declared `explode: false` but described as "Repeatable"; a repeated
   parameter (`type=a&type=b`) silently keeps only the first value. The app
   sends comma-separated values.
2. `AccountDTO.account_type`, `PaymentMethodDTO.network` and `WidgetDTO.key`
   are plain strings in responses (the inputs are enums). The app decodes them
   with the input enums and falls back to a generic label.
3. `PATCH /payment-methods/{id}` replaces the whole method (omitted optional
   fields are cleared), has no `version`, there is no single GET or restore,
   and `DELETE` does not say whether it archived or deleted. The app always
   sends the complete method and edits from the list.
4. `TransferDTO` has no date, description or notes, and transfers have no
   void/restore endpoint of their own. The app reads the outgoing leg and
   voids/restores through a leg (the server treats the transfer, fee included,
   as a unit).
5. Onboarding progress cannot be read back (`POST /me/onboarding` replaces the
   lists), so setup restarts from step 1 (prefilled from preferences).
6. `income_range` buckets have no documented period or currency; the app
   labels them as monthly ranges.
7. Dashboard `notes` and audit `changes` are untyped/unkeyed text, so they
   cannot be localized or rendered from a schema; `CategoryRef` lacks
   `system_key`.
8. Refunds created with `POST /transactions/{id}/refunds` do not carry the
   original's merchant, so merchant totals stay gross while category totals
   are net of refunds.

**Found while building the round-2 screens (P11 round 2)** (addressed in
the contract after round 2 and adopted in round 3: partial PATCH with
`clear`, typed enums, `version` on rules, tags, merchants and lifecycle
actions, the field names, codes for candidates, duplicates, detections,
forecasts and budget explanations, `text/csv` goal export, merchant merge
preview and alias removal, checklist update, budget restore, owner fields,
paging for budget transactions, alerts and goal contributions, the
`update_price` fix; lists of subscriptions, bills and rules are capped
rather than paged):

1. Plain strings where inputs have enums: `RecurringRuleDTO.frequency` /
   `interval_unit`, occurrence `kind`, `SubscriptionDTO.billing_frequency` /
   `interval_unit`, `SubscriptionEvent.kind`, `GoalDTO.goal_type`,
   `CalendarItem.status`, `DetectionCandidateDTO.confidence` (a decimal
   string), `DashboardSummary.note_codes`. The app maps known values and
   falls back safely.
2. Replace-style PATCH: `PATCH` on recurring rules, bills, budgets, goals and
   subscriptions replaces the record (omitted fields are cleared or reset, e.g.
   goal milestones go back to 25/50/75/100). The app always sends complete
   records.
3. No `version`/concurrency check on rules (`RuleDTO`), tags, merchants, and
   on lifecycle actions (budget/goal/subscription/recurring pause, resume,
   archive, member changes). `RuleDTO` also lacks the `currency` of its amount
   bounds; the app sends the base currency.
4. Validation field names: an unknown category on `POST /category-rules` is
   reported as `body.category_id` (the field is `set_category_id`); adding a
   budget member reports `body.members`.
5. English-only free text without codes: `BillPaymentCandidate.reasons`,
   `DuplicateWarning.reason`, `DetectionEvidence.reasons`,
   `GoalForecast.assumptions`, `ProgressDTO.explanation`. Undocumented detail
   codes: `use_bill_screen`, `auto_post_needs_amount_and_account`,
   `goal_inactive`, `category_in_use`; undocumented `MergeResult.affected`
   keys.
6. `GET /goals/{id}/export` is declared as a base64 JSON string but returns
   `text/csv`.
7. Missing endpoints: merchant alias removal and merge preview, a
   subscription checklist update, `/budgets/{id}/restore` (archived budgets
   come back via `resume`), owner fields on shared budgets/goals, pagination
   for subscriptions, bills, rules, budget transactions and alerts (capped at
   200), and 409 on `GET /bills/{id}/payment-candidates` is undeclared.
8. Server bug: `POST /subscriptions/{id}/payments` with `update_price: true`
   returns 500 when the charge differs from the price (unique index on the
   event's `transaction_id`).

**Found while building the round-3 screens (P11 round 3)** (endpoint —
problem — suggested fix; what the app does):

1. `POST /files/upload-intent` returns 413 `PAYLOAD_TOO_LARGE` and 415
   `UNSUPPORTED_MEDIA_TYPE`, `PUT /files/{fileId}/content` 410 (expired
   token) and 413, `GET /files/{fileId}/access` 409 and the signed
   `GET /files/{fileId}/content` 410, none of them declared (the download
   also has no response schema) — declare them; the app checks limits
   first and localizes the codes anyway.
2. `Access.url` (and `UploadIntent.upload_url`) use the server's public
   base URL (`http://localhost:8080` in development), which an emulator or
   phone cannot reach — return a path relative to the API, or document the
   host; the app fetches the signed path from its configured API origin and
   always uploads to the configured API.
3. No `DELETE /reports/{id}`; `GET /reports/{id}/download` answers an
   undeclared 409 while a report is not ready; `ReportDTO.error_code`
   values (`too_many_rows`, `pdf_too_large`, `report_invalid`,
   `reports_unavailable`) and `report_type` / `ScheduleDTO.format` are
   plain strings; default titles are stored in English — add the delete,
   declare 409, use enums and leave default titles empty; the app explains
   expiry, offers download only when ready and localizes known values.
4. Reconciliation: `ReconCandidate.reasons` / `ReconMatchDTO.reasons` are
   English without codes, `ReconCandidateItem.status` packs two values
   ("pending/manual"), `ReconMatchDTO.kind`/`cardinality` are plain strings,
   and match create/delete conflicts have no detail codes — add
   `reason_codes`, split the status, use enums, add codes; the app
   translates the known phrases and splits on the slash.
5. Imports: failed rows store the top-level `VALIDATION_ERROR` and a generic
   message (the real reason is lost); `mapping_notes` are English; rollback
   counts exist only inside the English message; suggested mappings use
   `-1` / `""` sentinels; `RowTotals` are minor units instead of `Money`;
   retry/cancel/rollback/row conflicts have no detail codes; `GET /imports`
   is capped at 100 without paging — store detail codes, add codes and
   params, use null and `Money`; the app shows generic text, treats
   sentinels as "not chosen" and converts minor units exactly.
6. `Comparison.notes` are English only (add `note_codes`); `GET /fx/rates`
   returns 12-decimal rates while `/fx/convert` trims them; without
   `currency`, `GET /analytics/merchants` ranks raw amounts across
   currencies (rank per currency or require it) — the app always sends the
   selected currency.
7. `POST /recurring-rules/{id}/pause` on a paused rule answers 200 and bumps
   the version (bills answer 422 `invalid_status_transition`); the app
   offers pause only for active rules.
8. `SubscriptionDetail` does not list the currently linked payments; the app
   derives them from `payment_recorded` / `payment_unlinked` events.
9. Budget member adds report "not a friend or group member" and "already
   yours" as `body.user_id` without codes; `BudgetPatch` has no `clear`
   (unlike the other patches); `PATCH /goals/{id}/members/{userId}` does not
   bump the goal `version`; `GoalOwner.display_name` is optional.
10. Receipts (live API ahead of the committed contract, adopted against the
    dev API): `POST /receipts` now requires `Idempotency-Key`,
    `skip_extraction` is replaced by `read_automatically` (never sent as
    true), `GET /receipts` pages, `POST /receipts/{id}/restore` exists,
    conflicts carry codes, and match candidates / extraction warnings carry
    `reason_codes` / `warning_codes` — regenerate the contract and models;
    until then the app reads the new fields from the raw JSON.

**Found while building rounds 4–5** (endpoint — problem — suggested fix;
what the app does):

1. `TransactionDTO` names `group_expense_id` / `settlement_id` but not the
   group — add `group_id`; the "Linked to a group" row opens the groups list.
2. No `GET /insights/{id}` — add it; insight links search up to 5 pages of
   `GET /insights?all=true` and otherwise say the insight is not available.
3. No `GET /reports/schedules/{id}` — add it; the edit screen reads the list.
4. Uncoded errors (add detail codes; the app shows the server message or
   prevents the case): `POST /me/deletion-request` wrong `confirm` (422
   `body.confirm`) and a second request (409); `PATCH /me` taken or invalid
   username; `GET /users/search` short query; `POST /groups/{id}/members`
   with both `username` and `user_id`; group field errors such as
   `body.participants[i].user_id`, `body.payer_account_id`, void `reason`;
   `POST /reconciliation/matches` duplicate row (422
   `body.statement_row_ids`) and an already matched transaction (409);
   `POST /integrations/{ref}/sync` while running (409); duplicate post/
   content reports (409); `DELETE /insights/mutes` without `subtype`.
5. `POST /group-invitations/accept` answers 200 (group) or 202 (join
   request) with no discriminator in the body — add one; the app reads the
   shape (`members`).
6. Activity summaries of member events carry no target name — add
   `summary.target_name`; the app looks up the member list (former members
   included).
7. Plain strings where enums exist: `ChallengeDTO.challenge_type`,
   `ModerationActionDTO.action`, `ModerationReportDTO.reason`,
   `ExportDTO.format` / `error_code`; English-only `GroupSuggestionsDTO.note`,
   provider `status_reason`, integrations overview `note`, notification
   titles and bodies (no `message_code`) — the app maps known values and
   shows the server text as plain text otherwise.
8. No paging: `GET /communities`, members, invitations, moderation
   reports/log/appeals, `/me/moderation`, `/content-reports`, comments of
   `GET /posts/{id}`, `GET /groups/{id}/settlements` (capped at 500); the app
   shows what the server returns.
9. `GET /communities/{id}/moderation/reports` `status` filter lacks
   `under_review`; `ChallengeDTO` has no milestones (the app shows
   25/50/75/100 % of `percent_complete`); `RowTotals` still requires the
   deprecated `*_minor` fields; `GET /accounts/{id}/statement-lines` lists
   lines of imports still in preview.
10. `POST …/recurring-expenses/{id}/pause` on a paused rule answers 200;
    `DELETE` of a deleted group expense answers 200 (harmless; the app
    offers only valid moves).
11. Neither the contract nor the app configuration provides the web origin
    for invitation links — add a `share_url` (from `WEB_APP_URL`, token in
    the fragment) to invitation DTOs; the app uses `WEB_APP_URL` when built
    with it.

