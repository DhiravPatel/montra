# Montra --- Full Product & Production Implementation Specification

**Status:** Master requirements and implementation blueprint\
**Product:** Montra (working name)\
**Product promise:** Understand your money, manage money together, and
make better financial decisions.\
**Commercial rule:** Every feature in this specification is free to
every user. No paid tiers, premium flags, feature paywalls, or paid-only
exports/AI/groups/receipts/reports.

## 0. Product-wide non-negotiable rules

1.  All product features are free. Do not build subscription plans,
    billing, upgrade prompts, premium entitlements, or feature locks.
2.  Free access does not mean infrastructure has zero operating cost.
    Hosting, storage, AI, OCR, email, push, and financial-data providers
    may have quotas or costs. Make operational limits transparent and
    apply fair-use controls without creating paid tiers.
3.  Financial data is private by default. No selling financial data,
    undisclosed advertising, or public exposure of transactions, account
    balances, receipts, or group debts.
4.  The user must be able to use the entire core expense tracker without
    linking a bank.
5.  All money calculations use integer minor units or exact decimal
    arithmetic. Never use floating point for money.
6.  AI is advisory, explainable, and grounded in authorized data. AI
    never initiates payments, changes financial records, or settles
    balances without explicit confirmation.
7.  Do not claim a bank integration, payment verification, subscription
    cancellation, or financial connection exists until a real authorized
    provider workflow has been implemented and tested.
8.  Every important write is validated, authorized, auditable,
    idempotent where retryable, and covered by tests.
9.  Every feature must include loading, empty, error, success, and
    permission-denied states.
10. Do not ship mock data, fake charts, placeholder buttons, or
    simulated integrations as production functionality.

## 1. Required technology stack and architecture

The following choices are fixed product constraints. Do not replace them
without explicit approval.

| Layer | Required choice |
|---|---|
| Mobile application | Flutter |
| Web portal | React + TypeScript |
| Backend and APIs | Go |
| Database | Supabase PostgreSQL |
| File and object storage | Appwrite Storage |
| Web deployment | Vercel |
| Repository strategy | Monorepo |

### 1.1 Product clients and backend ownership

Montra has two first-class client applications:

- **Flutter mobile app:** the primary mobile experience for Android and
  iOS. It must support responsive layouts, platform conventions,
  secure local session handling, offline-aware states, deep links,
  push notifications, camera/gallery receipt capture, and accessible
  interactions.
- **React + TypeScript web portal:** the browser experience for desktop
  and mobile web. It must provide the complete supported finance,
  collaboration, reporting, settings, and account-management workflows;
  it is not merely a marketing website or a reduced admin dashboard.
- **Go backend:** the sole owner of business rules, authorization,
  financial calculations, validation, integrations, audit events,
  background job orchestration, and API contracts. Both clients use
  the same documented backend contracts. Do not duplicate critical
  financial logic in Flutter and React.

Both clients must offer consistent permissions, terminology, validation,
and core workflows. Platform-specific capabilities may differ only where
the operating system requires it, and those differences must be
documented.

### 1.2 Monorepo requirements

Keep the mobile app, web portal, Go backend, database assets, contracts,
and project documentation in one monorepo. Organize it by clear product
and service boundaries rather than placing everything in one
unstructured application directory.

The monorepo must include, at minimum, dedicated areas for:

- Flutter mobile application and its tests.
- React web portal and its tests.
- Go API/backend services and domain packages.
- Go background workers and scheduled-job handlers.
- Shared API specifications and generated/client contract assets.
- Supabase SQL migrations, RLS policies, seeds for local development,
  and database tests.
- Appwrite storage setup, bucket definitions, permission conventions,
  and integration tests/documentation.
- Infrastructure, deployment configuration, CI workflows, and
  environment templates.
- Product, architecture, security, privacy, API, operations, and
  implementation documentation.

Create and maintain a root-level README with setup instructions,
architecture overview, prerequisites, common commands, environment
configuration, test commands, and links to deeper documentation.
Provide clear per-application and per-service READMEs where workflows
differ.

Enforce dependency boundaries: the Flutter app must not depend on web
application internals; the React app must not depend on Go implementation
packages; backend domain logic must not depend on UI code. Shared
contracts are the integration boundary. Avoid copying business logic
between clients.

The repository must provide reproducible local development, consistent
formatting/linting, automated tests, dependency and secret scanning,
change-aware CI where practical, and a documented release/versioning
strategy for the mobile app, web portal, and backend.

### 1.3 Required development environment and tools

The developer already has these tools available:

- **Visual Studio Code:** primary editor for the monorepo, Go, React,
  TypeScript, documentation, and repository workflows.
- **Android Studio:** Flutter/Android SDK management, Android emulator,
  device debugging, profiling, and mobile build validation.
- **Postman:** API collections, environment configuration, auth flows,
  regression checks, and backend contract testing.
- **Claude:** AI-assisted development, repository exploration,
  implementation planning, code review, test generation, and debugging.

Do not waste implementation time reinstalling tools the developer
already has. At project bootstrap, verify versions, required SDKs,
PATH configuration, formatters, linters, emulators, and CLI availability.
Document exact setup steps for any missing prerequisites.

The developer already has a local PostgreSQL installation. Use that
existing local server for database development; first inspect the
installed PostgreSQL version, service status, host, port, and available
roles/databases without changing or deleting existing data. Create a
dedicated Montra development database and least-privilege role only
after confirming the intended names and avoiding collisions. Never
reuse a production database for local development. Do not install
Docker/PostgreSQL/Supabase locally as a replacement unless the developer
explicitly requests it.

The developer may also use additional tools already installed. Discover
and document the actual available environment rather than assuming a
specific paid product or requiring unnecessary new subscriptions.
Recommended tool categories to account for include:

- Git and source-control hosting.
- Go toolchain, formatter, linter, debugger, and test runner.
- Flutter SDK, Dart tooling, Android SDK, emulator, and device tools.
- Node.js package manager, TypeScript tooling, React build/test tooling.
- Supabase CLI and local development workflow.
- Appwrite CLI or supported administration workflow.
- API schema/contract validation and Postman collection execution.
- Container/local-service tooling where required.
- CI/CD, dependency scanning, secret scanning, and static analysis.
- Crash reporting, logs, metrics, tracing, and release monitoring.

Tool selection beyond the explicitly required stack is an implementation
decision. Do not introduce a tool merely because it is fashionable.
Record its purpose, alternatives, operational cost, security impact,
and maintenance responsibility.

### 1.3A Local development rules (mandatory)

1. Use the PostgreSQL server already installed on the developer's
   machine. Do not start a second PostgreSQL server, install another
   database, or make Docker a prerequisite.
2. Inspect the local PostgreSQL version and connection settings first.
   Do not assume the default port, username, or database name.
3. Create a dedicated Montra development database and a non-superuser
   application role. Keep owner/migration privileges separate from the
   runtime role where practical.
4. Store local secrets only in ignored environment files. Provide a
   safe `.env.example` with placeholders, never real credentials.
5. Migrations must be repeatable from an empty Montra database and
   upgrade an existing Montra development database without data loss.
   Never run destructive reset commands against an unverified database.
6. Provide seed data only for local development and automated tests.
   Seeds must be deterministic, clearly synthetic, and never resemble
   real users' financial records.
7. Run Go API, Flutter app, and React portal locally against the same
   local Go API and local PostgreSQL database. Document ports and
   startup order.
8. Local development must work without Appwrite credentials or a live
   Appwrite project. Implement the production Appwrite adapter and
   configuration, but do not make local startup, local tests, or local
   feature development depend on Appwrite.
9. Do not silently substitute an in-memory fake storage provider and
   claim that Appwrite works. The storage interface may be exercised
   with deterministic unit-level test doubles for business logic, but
   no local Appwrite upload/download integration test is required or
   permitted by this project's local workflow.
10. Keep Supabase-targeted migrations and RLS policies in the repository.
    Document how the local PostgreSQL setup validates schema and how
    Supabase-specific identity/RLS behavior is verified in a separately
    configured hosted test environment. Do not claim local PostgreSQL
    is identical to Supabase Auth or every Supabase service.
11. Appwrite integration credentials, buckets, and endpoints are
    configured only in the relevant hosted environment by the owner.
    Do not ask Claude or another agent to create cloud resources.
12. Provide one-command or clearly documented scripts for local
    bootstrap, migration, seed, API startup, web startup, Flutter
    startup, and test execution. Scripts must print the target database
    host/database before any potentially destructive action.

### 1.4 Data and service boundaries

- **Flutter client:** presentation, platform integrations, local
  non-authoritative cache, secure session storage, and typed API calls.
  Never contains privileged service credentials.
- **React client:** browser presentation, form interaction,
  client-side validation, accessible navigation, and typed API calls.
  Never contains privileged service credentials.
- **Go backend:** authentication verification, authorization, domain
  rules, exact financial calculations, integrations, file authorization,
  reports, jobs, audit, and API versioning.
- **Local PostgreSQL during development:** use the PostgreSQL server
  already installed and running on the developer's machine. Connect
  directly to that local instance. Do not require Docker or a local
  Supabase stack just to run the database. Keep local connection values
  in an ignored environment file and provide a documented database
  creation, migration, seed, reset, and backup/restore workflow.
- **Supabase PostgreSQL for the hosted environment:** the target
  relational database remains Supabase PostgreSQL. Keep schema,
  constraints, SQL migrations, indexes, transaction semantics, and RLS
  policies compatible with the target. Do not introduce local-only
  schema behavior. Validate migration compatibility and RLS behavior
  before a hosted release.
- **Appwrite Storage:** implement the complete production storage
  integration in code, including private objects, permission mapping,
  upload/download authorization, metadata, deletion, and error
  handling. Do not configure or test Appwrite file storage as part of
  ordinary local development. Local feature development must use the
  storage service boundary and compile/test the surrounding business
  logic without attempting real Appwrite network calls. Perform actual
  provider integration verification only in a separately configured
  non-local environment when the owner chooses to do so.
- **Vercel:** the React web portal's target hosting platform. Prepare
  deployment configuration and instructions, but never deploy it
  automatically or manually on the user's behalf.
- **Go runtime and worker infrastructure:** durable API execution and
  asynchronous processing where Vercel's supported runtime is not
  suitable. Choose and document a Go-compatible hosting target.
- **Queue and scheduler:** durable asynchronous processing, retries,
  recurring schedules, and dead-letter handling.

Choose one primary identity authority. Explicitly document token
issuance/validation, Flutter secure session handling, browser session
handling, Supabase RLS identity propagation, Appwrite permission
mapping, session revocation, and account deletion. Do not create
unrelated Supabase and Appwrite identities without a deliberate mapping.

### 1.5 Deployment architecture constraints

Vercel is the required deployment platform for the React web portal.
Do not assume that Vercel is automatically the right place to run the
entire Go backend, persistent workers, schedulers, or long-lived
connections.

Montra requires durable background work for OCR, statement imports,
reports, recurring transactions, reminders, notifications, AI jobs,
integrations, exports, deletion, and cleanup. Select and document one
of these topologies before coding:

- **Split runtime (recommended starting point):** React web portal on
  Vercel; Go API and workers on a Go-compatible runtime; Supabase and
  Appwrite remain the data/storage services.
- **Hybrid:** React web portal on Vercel; selected stateless Go endpoints
  on a compatible serverless runtime; durable Go workers and APIs on a
  separate Go-compatible runtime.
- **Vercel-centric:** only if current Vercel Go runtime support and
  execution constraints demonstrably meet the exact API workload. Use
  an external durable queue/scheduler and worker runtime regardless.

Preserve Vercel as the web deployment platform. Do not compromise job
durability to force workers into serverless functions. Verify current
runtime limits and document regions, execution limits, secrets, queue,
scheduler, mobile API base URL, and costs. Flutter distribution must
use the appropriate Android/iOS build and store-release processes; Vercel
does not deploy the native mobile application.

### 1.6 API and contract strategy

Publish a versioned, machine-readable API contract used by both clients.
Define request/response schemas, authentication, authorization,
pagination, filtering, sorting, idempotency, error codes, rate limits,
and deprecation policy.

Generate or validate typed client models from the contract where
practical. Contract changes must be reviewed for compatibility with
both the released Flutter app and the web portal. Backend changes must
not silently break older supported mobile app versions.

## 2. Product vision and audience

Montra is a free, privacy-first personal finance and social money
management platform for: - Individuals. - Students and young
professionals. - Couples and families. - Roommates and households. -
Friends splitting trips, meals, rent, and events. - Communities
participating in savings challenges. - Manual-entry users and
statement-import users.

Core outcome: a user can understand income, spending, budgets, recurring
commitments, goals, shared balances, and financial trends without
requiring a bank connection.

### 2.1 Main navigation

1.  **Home:** dashboard, cash flow, budgets, upcoming bills,
    subscriptions, goals, alerts.
2.  **Transactions:** income, expenses, transfers, recurring items,
    receipts, imports, reconciliation.
3.  **Insights:** analytics, reports, forecasts, anomaly detection,
    subscriptions, AI assistant.
4.  **Community:** groups, friends, shared expenses, settlements,
    household, challenges, posts.
5.  **Profile:** accounts, preferences, security, privacy, integrations,
    exports, support.

## 3. Roles, permissions, and privacy

Roles: - Visitor. - Registered user. - Group owner. - Group
administrator. - Group member. - Community moderator. - Platform
administrator. - Support operator.

Authorization rules: - A personal transaction belongs to one user. - A
group expense belongs to a group and has explicit payer and participant
allocations. - Group membership never grants access to personal accounts
or private transactions. - Group admins cannot read personal budgets
unless explicitly shared. - Public profiles never expose balances or
transaction histories by default. - Public challenge progress is opt-in
and must not disclose absolute wealth or spending by default. -
Support/admin access to private finance data is not a default
permission. - Every resource read/write must be authorized on the
server. - Hiding a button is not authorization. - Enable and test
Supabase RLS on all user-accessible tables. - Never expose Supabase
service-role or Appwrite privileged credentials in the browser. -
Privileged backend database operations must still perform explicit
authorization and audit logging.

Create an authorization matrix covering every endpoint and resource.
Test User A attempting to read, update, delete, export, or attach files
to User B's data.

## 4. Complete functional feature catalogue

### 4.1 Authentication, onboarding, and account lifecycle

-   Email registration, verification, sign-in, sign-out, password reset
    and update.
-   Optional OAuth and passkeys if supported by the chosen identity
    provider.
-   Session refresh, expiry, revoke current device, revoke all sessions,
    device/session list.
-   Optional MFA and recovery workflow.
-   Rate limits, bot protection, generic errors that do not disclose
    whether an email exists.
-   Profile: display name, username, avatar, bio, locale, timezone, base
    currency.
-   Onboarding: welcome, privacy explanation, country, currency,
    timezone, optional income range, optional goals, optional accounts,
    starter categories.
-   Every nonessential onboarding step can be skipped. Bank linking is
    never required.
-   Account export, deletion request, deletion status, credential
    revocation, file deletion, data deletion/anonymization, disclosed
    legal retention exceptions.
-   Group ownership transfer and shared-record handling during account
    deletion must be explicitly defined.

Acceptance: a user can register and manage personal finance without bank
linking; session revocation works; deletion propagates to Supabase,
Appwrite, and connected providers.

### 4.2 Personal finance dashboard

Cards: - Total tracked balance. - Income, expenses, net cash flow. -
Savings amount/rate where data is sufficient. - Budget utilization. -
Upcoming bills and subscriptions. - Active goals. - Recent
transactions. - Unsettled group balances. - Alerts and insights.

Widgets: - Income vs expense chart. - Cash-flow trend. - Expense
category breakdown. - Budget progress. - Top merchants. - Recurring
expenses. - Subscription renewal calendar. - Goal progress. - Group
balances. - AI insight summary. - Recent activity.

Filters: today, yesterday, week, month, year, last 7/30/90 days, custom
range, account, currency, category, type, personal/group context.

Allow hide/reorder/reset widgets. Every metric must be traceable to
underlying records. Exclude transfers from income/expense totals.
Distinguish tracked balance from verified bank balance. Display
import/provider freshness. Charts need accessible text equivalents.

### 4.3 Accounts, wallets, and payment methods

Account types: - Cash wallet. - Bank/current/checking account. - Savings
account. - Credit card. - Debit card. - Prepaid card. - Digital
wallet. - UPI/payment wallet reference. - Loan tracking account. -
Investment tracking account. - Shared household ledger account. - Custom
account.

Features: - Create, edit, archive, restore, close. - Opening balance and
effective date. - Manual balance correction with reason. - Currency,
institution label, icon/color, notes. - Include/exclude from overview. -
Account transaction history and balance history. - Statement import and
reconciliation. - Balance source label: manual, calculated, imported,
provider-synchronized. - Handle negative balances and credit card
liability correctly. - Payment methods: cash, UPI, debit, credit,
transfer, wallet, cheque, other. - Never store card CVV, PIN, OTP, bank
password, or full sensitive payment credentials. Optional masked display
metadata only.

Define one authoritative balance model: ledger-derived or deterministic
transaction-derived. Do not mix ad hoc balance mutations.

### 4.4 Transactions: expenses, income, transfers, refunds

Types: - Expense. - Income. - Transfer. - Refund. - Reimbursement. -
Adjustment. - Group expense reference. - Settlement reference.

Fields: - ID, owner, account, type, amount minor units, currency,
transaction time, posting time, timezone, category, subcategory,
merchant, payment method, description, notes, tags, receipt references,
optional consented location, recurring rule, import source, external ID,
status, reconciliation state, version, created/updated/deleted
timestamps, audit actor. - Link refunds/reversals to original
transactions. - Group expense references must not double-count in
personal spending.

Operations: - Manual create/edit/delete/archive/restore. - Quick add
expense/income/transfer. - Duplicate transaction. - Bulk
category/tag/account update and bulk delete with confirmation. - Search
by text, date, amount, type, category, merchant, account, payment
method, tag, source, recurrence, receipt, reconciliation status. - Sort
and paginate. - Saved filters. - Attach receipts. - Create from
recurring template or receipt. - Partial refunds. - Multiple
reimbursements. - Prevent refund total from exceeding original unless an
explicit correction path is used. - Transfer between owned accounts with
paired ledger effects, fees, FX rate metadata, atomic write, reversal
path. - Transfers are excluded from income/expense totals. - Idempotent
writes, optimistic concurrency/version checks, audit history, duplicate
suggestions, no silent deletion.

### 4.5 Categories, tags, merchants

Starter categories: - Food/dining, groceries, transport, fuel,
housing/rent, utilities, shopping, healthcare, education, entertainment,
travel, personal care, insurance, taxes/fees, gifts/donations, family,
work expenses, salary, freelance income, interest, refunds, other.

Features: - Custom categories/subcategories. - Rename, archive, merge
with preview, icon/color, budget inclusion. - Category mapping for
imports. - Default categorization rules. - Prevent deletion when
historical records depend on a category without migration. - Custom
tags, multi-tag, tag reports, bulk tagging. - Merchant canonical names,
aliases, category, user corrections, spending history. - Never expose
one user's private merchant notes to another.

### 4.6 Budgets and spending controls

Budget types: - Weekly, monthly, annual, custom range. - Total,
category, subcategory, merchant, account. - Household, group,
trip/event. - Zero-based and envelope-style.

Fields: - Name, period/timezone, currency, total limit, category
allocations, rollover/carry-forward policy, included accounts, excluded
categories, visibility, members, permissions, alert thresholds, owner,
notes, status.

Features: - Actual spend, remaining, percentage, pace, projected spend,
over-budget amount. - Category and merchant breakdown. - Compare
periods. - Refund and transfer rules. - Alerts at configurable
thresholds (e.g. 50/75/90/100%), forecast overspend and unusual spend. -
Dismiss/snooze, quiet hours, deduplication. - Shared budgets with member
allocation and aggregate visibility. - Private transactions remain
private unless explicitly shared.

### 4.7 Recurring transactions and bills

Patterns: - Daily, weekly, biweekly, monthly, every two months,
quarterly, half-yearly, yearly, custom interval, day-of-month, last day
of month, weekday-based, end date or occurrence count.

Features: - Income, expense, transfer, bill, subscription, group
recurring expense templates. - Expected/variable amount. - Account,
category, merchant, notes. - Pause/resume, skip one occurrence, edit
future occurrences, stop. - Occurrence history and generated transaction
link. - Bills with due date, expected amount, provider, frequency,
payment account, paid/unpaid/overdue, document, reminder. - Mark paid by
linking an existing transaction to avoid duplicates. - Timezone and
daylight-saving correctness. - Durable scheduling, idempotent
generation, missed-run recovery, retry, no duplicate reminders.

### 4.8 Subscription manager

-   Manual subscription creation.
-   Name, merchant, category, amount/currency, frequency, renewal date,
    start date, trial expiry, payment account, shared members,
    cancellation instructions/official URL, notes, invoice, status,
    source, last verified date.
-   Detect possible recurring merchant/amount patterns.
-   Show evidence and confidence.
-   Confirm, edit, dismiss detection.
-   Renewal calendar.
-   Monthly/annualized cost.
-   Price increase history.
-   Trial-expiry reminders.
-   Duplicate warnings.
-   Shared subscription tracking.
-   Payment history.
-   Cancellation checklist and verified official instructions.
-   Mark cancelled only after user confirmation.
-   Unused subscription hints only with evidence.
-   Never claim automatic cancellation without an authorized
    integration.

### 4.9 Receipt scanner and Appwrite document storage

Intake: - Camera capture where supported, image/PDF upload, multiple
pages/files, receipt inbox, retry, progress, manual fallback, file
validation, duplicate detection.

Extraction candidates: - Merchant, date/time, currency, subtotal, tax,
tip, discount, total, payment hints, receipt number, line items,
quantities, unit prices, line taxes, confidence per field.

Review: - Show candidates before saving. - Highlight uncertainty. -
Correct fields and category. - Match existing transaction or create
new. - Confirm who reviewed. - Preserve original file and extraction
version. - Reprocess on request.

Appwrite requirements: - Private storage for receipts, bills, group
attachments, exports. - Separate logical storage areas for private user
documents, group documents, public community media, temporary
processing, and exports. - Supabase stores Appwrite object IDs and
metadata. - Backend verifies owner/group permissions before issuing
access. - Use short-lived authorized access where supported. - No
permanent public receipt links. - Delete objects on retention/deletion
workflow. - Revoke access after group membership changes. - Validate
MIME by file content, size, extension, checksum. - Safe internal
filenames; path traversal prevention. - Scan untrusted files where
feasible. - Protect image/PDF parsers from resource exhaustion. - Strip
unnecessary EXIF from previews. - Do not log document contents.

### 4.10 Statement imports and reconciliation

Formats: - CSV, XLSX, documented OFX/QFX where supported, PDF statement
extraction with mandatory review, provider export formats via adapters.

Workflow: 1. Select/create account. 2. Upload. 3. Validate format/size.
4. Detect encoding and format. 5. Preview rows. 6. Map date, amount,
debit/credit, currency, description, reference, balance. 7. Configure
date/number formats and sign convention. 8. Preview parsed data. 9.
Detect duplicates. 10. Validate totals and row counts. 11. Confirm. 12.
Process idempotently. 13. Show imported/skipped/failed/duplicate counts.
14. Review/correct. 15. Retry failed rows safely.

Reconciliation: - Match manual and imported records. - Match pending to
posted. - Candidate matching by
amount/date/account/merchant/reference. - Confidence and user
confirmation for ambiguous matches. - Support one-to-one and defined
one-to-many cases. - Unmatch/correct. - Opening/closing balance
differences. - Never silently discard rows. - Preserve import audit
history.

Security: - Parse in resource-limited workers. - Never execute
spreadsheet formulas/macros. - Protect exports against CSV formula
injection. - No raw statement rows in logs. - Idempotency and source
fingerprints. - Safe cancellation/retry.

### 4.11 Analytics, reports, exports

Analytics: - Daily/weekly/monthly/yearly expenses and income. - Net cash
flow. - Savings amount/rate. -
Category/subcategory/merchant/account/payment method distribution. -
Recurring spend and subscription cost. - Budget performance. - Group,
trip, household spending. - Refund/reimbursement trends. - Period
comparisons and spending changes. - Data coverage/missing sources.

Reports: - Monthly/yearly summary. - Income, expense, cash flow. -
Category, merchant, account. - Budget, subscription, recurring. - Group
settlement, trip, household. - Goal progress. - Custom report builder.

Filters: - Date, currency, account, category, merchant, type, tags,
personal/group scope, member where authorized, include/exclude
transfers/refunds/pending.

Exports: - CSV, XLSX, PDF, JSON, print view, scheduled reports if
supported. - Include currency, timezone, date range, generation
timestamp. - Authorize export scope. - Temporary links expire. - Protect
spreadsheet formula injection. - Async generation for large reports.

Calculation rules: - No unlike-currency aggregation without disclosed
rate and timestamp. - Distinguish cash flow, income, expense, assets,
liabilities, and verified balances. - Define pending, refund,
reimbursement, reversal and transfer treatment. - Avoid credit-card
double counting. - Document every metric.

### 4.12 AI financial assistant and intelligence

Features: - Natural-language questions over user's authorized data. -
Monthly summaries. - Explain spending changes. - Budget explanations. -
Category suggestions. - Merchant normalization. - Duplicate
suggestions. - Recurring/subscription detection. - Anomaly detection. -
End-of-period forecasts with uncertainty. - Savings opportunities. -
Goal progress explanation. - Plain-language report generation. - Group
balance explanations where authorized. - Explain calculation and source
period.

Grounding and safety: - Only access current user's authorized scope. -
Query deterministic financial services first. - Send minimal, aggregated
context. - Redact unnecessary identifiers. - Disclose external AI
processing. - Allow AI disablement. - Never send receipts/full account
identifiers externally without explicit consent and necessity. -
Validate structured output. - Model output is never SQL, authorization,
or executable command. - No financial action without confirmation. - No
investment/tax/credit/legal advice claims. - No guaranteed savings. - No
shame/coercion. - No sensitive-attribute inference. - No public sharing
without explicit action. - Keep manual workflows. - Provider outage
fallback. - Track cost/latency internally. - Never silently switch to a
provider with different privacy terms. - AI features are free; fair-use
controls only for abuse/stability.

Evaluation: - Synthetic datasets. - Arithmetic correctness against
deterministic results. - Prompt injection in descriptions, receipts and
imports. - Cross-user leakage. - Hallucination and unsupported
recommendations. - Malformed output. - Provider/model regression. -
Latency and cost.

### 4.13 Anomaly detection and savings intelligence

Detect: - Unusually high transaction. - Category increase. - New
merchant/large amount. - Duplicate-looking transaction. - Recurring
amount change. - Subscription price increase. - Budget pace anomaly. -
Unusual frequency. - Cash-flow change. - Possible missing recurring
payment.

Start with explainable rules/statistics. Show evidence and baseline.
Label as "unusual" or "possible anomaly", never assert fraud. Allow
dismiss, correct, mark expected, snooze. No automatic blocking/reversal.

Savings suggestions: - Recurring cost visibility. - Compare
user-selected periods. - Repeated budget overspend. - Unused budget only
where coverage supports it. - User-defined savings targets. - Explain
assumptions and trade-offs.

### 4.14 Goals and savings plans

Goal types: emergency fund, travel, education, device, vehicle, home,
event, debt payoff tracking, large purchase, custom.

Fields: name, description, target amount/currency, current
contributions, target date, start date, priority, optional linked
account, schedule, visibility, members, reminders, milestones, notes,
status.

Features: - Create/edit/archive. - Manual contribution. - Link
contribution to transaction without double counting. - Progress and
required pace. - Forecast completion with assumptions. - Adjust
target/date. - Milestone notifications. - Shared goals and
contributors. - Contribution history. - Export. -
Achieved/paused/cancelled states. - No automatic transfer of money.

### 4.15 Social finance, friends, groups, household

Social principles: - Private by default. - Joining a group never exposes
private transactions. - No forced contacts upload. -
Block/mute/report/leave controls. - No leaderboard of absolute
wealth/spending.

Profiles: - Display name, username, avatar, bio, optional
interests/coarse location, opt-in achievements/challenge participation,
privacy settings. - No public balances or transaction history.

Friends: - Search username, invite link, accept/decline, remove, block,
mute, report, request controls. - Contact discovery only after explicit
consent.

Groups: - Household, roommates, trip, event, friends, custom. - Create,
invite by link/username, expiry/revocation, join request,
approve/decline. - Owner/admin/member roles. - Group
currency/timezone/rules. - Remove/leave, ownership transfer,
archive/delete. - Activity history and notification settings.

Shared expenses: - Payer, amount, currency, date, description, category,
receipt, participants. - Equal, exact, percentage, weighted/share,
itemized splits. - Exclude participant. - Multiple payers where
supported. - Comments, attachments, edit history, disputes,
resolution. - Partial/full settlements. - Balances and reports. - Split
totals must equal total in minor units. - Deterministic remainder
allocation. - Preserve original split inputs and audit. - Define removed
member historical balance handling. - Currency conversion requires rate
provenance. - Personal and group records must not double count.

Balance simplification: - Derive net balances from auditable expense
shares and settlement records. - Suggestions never mutate source
expenses. - Show original debts and simplified option. - Partial
settlement, reversal, dispute and correction supported. - Suggestions
are not payments.

Settlements: - Off-app cash/bank/UPI settlement reported by user. -
Proposal, counterparty confirmation, partial amount, receipt, dispute,
void with reason. - Mark "user reported" unless provider evidence
verifies payment. - No payment initiation in initial scope.

Trips/events: - Dates, destination optional, participants, shared
ledger, category budgets, timeline, notes, attachments, multi-currency
metadata, final report and settlement summary.

Households: - Household space, members, shared bills, budget, goals,
recurring expenses, contributions, combined dashboard,
individual/private separation, per-data permissions, join/leave,
ownership transfer, export and deletion rules.

### 4.16 Public communities and challenges

Communities: - Discover/create. - Public/private/invite-only. -
Description, rules, topics/tags. - Join/leave. - Posts, comments,
replies, reactions, polls, resource links. - Challenges, moderators,
reports, pinned posts, search, sorting. - Spam controls, content
removal, appeals. - Distinguish personal experience from verified
guidance.

Challenges: - No-spend, savings streak, grocery budget, meal planning,
travel savings, custom. - Individual/group participation. - Rules,
dates, milestones, progress, opt-in sharing, private mode. -
Leaderboards only with consent; never reveal absolute financial data by
default. - No wealth/income ranking or shame-based scoring.

Moderation: - Report content/profile/group. - Moderator queue. -
Remove/hide, warn, temporary restriction, ban, appeal. -
Spam/abuse/scam/impersonation escalation. - Audit every moderation
action. - Moderators do not gain access to private financial records.

### 4.17 Notifications

Channels: in-app, web push with permission, email with consent, future
native push. Do not assume unrestricted SMS sending or reading.

Events: - Budget thresholds/forecast. - Bills and overdue items. -
Subscription renewal/trial. - Recurring transactions. - Goal
milestones. - Group invitations/join requests. - Shared expense
changes. - Balance and settlement requests/confirmation/dispute. - Trip
events. - Community replies/mentions. - Challenge milestones. - Security
alerts. - Import/receipt completion or failure. - Export ready. -
Deletion status.

Controls: - Per-category and per-group preferences. - Quiet
hours/timezone. - Digest/frequency. - Read/unread. - Mute. - Deep links
re-authorize. - Unsubscribe optional email. - Security-critical alerts
remain enabled where required. - Durable outbox, retries, dedupe,
delivery state. - Avoid sensitive transaction details in push/email
previews.

### 4.18 Financial integrations and India considerations

Manual-first requirements: - Manual entry. - CSV/XLSX import. -
Supported statement imports. - Receipt capture. - User-entered
balances. - Reconciliation.

Bank data: - Integration adapter framework. - Research provider
availability and target-country law. - For India, assess Account
Aggregator ecosystem and consent/data-flow obligations with qualified
compliance review. - Use authorized providers/documented APIs only. - No
bank login password collection. - Consent purpose, scope, provider,
grant, expiry, revocation. - Show last sync and provider status. -
Handle delayed, missing, duplicate, reversed and corrected
transactions. - Revoke and delete provider data. - Do not launch bank
integrations before legal/security review.

UPI/payment: - Do not assume all UPI transactions or notifications are
readable. - Do not request Android SMS access by default. - Do not claim
iOS can read financial SMS/notifications. - Use official exports,
authorized integrations, user uploads, or manual capture. - Never store
UPI PIN or OTP. - No UPI payment initiation in initial scope.

Integration framework: - Provider registry. - OAuth/consent. - Encrypted
token storage. - Refresh/revoke. - Webhook signature and replay
verification. - Dedupe. - Sync cursor/backfill. - Normalization
adapters. - Rate-limit and outage handling. - Health status and
disconnect.

### 4.19 Multi-currency

-   ISO 4217 codes and minor-unit precision.
-   Account and transaction currency.
-   Group base currency.
-   Display currency.
-   Rate source and timestamp.
-   Manual override.
-   Original and converted amounts.
-   FX fee.
-   Historical rate preservation.
-   Rounding policy.
-   Never sum unlike currencies without disclosed conversion.
-   Test zero- and three-decimal currencies.

### 4.20 Search and personalization

Search transactions, merchants, accounts, groups, community posts,
users, and authorized goals. Support filters, sorting, recent searches,
clear history, saved searches. Search indexes/autocomplete/counts must
respect access control.

Settings: - Profile, currency, timezone, locale, date/number format. -
Theme, dashboard layout, default range/account. - Category
preferences. - Notification preferences. - Privacy and AI settings. -
Integration consent. - Export/deletion. - Accessibility. -
Sessions/devices. - Community preferences and blocked/muted lists.

### 4.21 Help and trust

Help center, getting-started guides, calculation explanations, import
troubleshooting, integration status, support contact, bug report,
security report, privacy policy, terms, community rules, AI disclosure,
status page, security contact, incident response.

## 5. Data model --- required logical entities

Use UUID primary keys unless justified otherwise. Use `timestamptz`,
IANA timezone identifiers, ISO currency codes, exact money, foreign
keys, check constraints, unique constraints, indexes, and migration
tests. Never use float/double for money.

Required tables/entities:

### Identity

-   `profiles`
-   `user_preferences`
-   `user_consents`
-   `user_sessions` or provider session references

### Accounts and transactions

-   `financial_accounts`
-   `payment_methods`
-   `categories`
-   `tags`
-   `merchants`
-   `merchant_aliases`
-   `transactions`
-   `transaction_tags`
-   `transaction_attachments`
-   `transaction_audit_events`
-   `account_ledger_entries` if ledger balance model is selected

### Budgets and recurrence

-   `budgets`
-   `budget_allocations`
-   `budget_members`
-   `budget_alerts`
-   `recurring_rules`
-   `recurring_occurrences`
-   `bills`

### Subscriptions

-   `subscriptions`
-   `subscription_events`
-   `subscription_detection_candidates`

### Files, receipts, imports

-   `files`
-   `receipt_extractions`
-   `receipt_line_items`
-   `import_batches`
-   `import_rows`
-   `reconciliation_matches`

### Goals

-   `goals`
-   `goal_members`
-   `goal_contributions`
-   `goal_milestones`

### Groups and settlements

-   `groups`
-   `group_members`
-   `group_invitations`
-   `group_expenses`
-   `group_expense_shares`
-   `group_expense_items`
-   `group_expense_item_shares`
-   `settlements`
-   `group_activity_events`
-   `group_expense_comments`

### Social/community

-   `friend_requests`
-   `user_connections`
-   `user_blocks`
-   `communities`
-   `community_members`
-   `community_posts`
-   `community_comments`
-   `community_reactions`
-   `community_polls`
-   `community_poll_options`
-   `community_poll_votes`
-   `community_reports`
-   `moderation_actions`
-   `challenges`
-   `challenge_participants`
-   `challenge_progress_events`

### Notifications and integrations

-   `notifications`
-   `notification_preferences`
-   `notification_deliveries`
-   `integration_connections`
-   `integration_sync_runs`
-   `integration_webhook_events`

### Operations

-   `jobs`
-   `job_attempts`
-   `audit_events`
-   `security_events`
-   `idempotency_keys`
-   `outbox_events`

For each table define columns, nullability, constraints, ownership,
indexes, RLS policy, retention, audit rules, and migration. Avoid one
giant JSON table. Derived aggregates must never override ledger truth.

## 6. API contract

Base path: `/api/v1`. JSON over HTTPS. Standard error codes, request ID,
cursor pagination, idempotency keys for financial writes, server-side
validation and authorization, OpenAPI documentation, rate limits,
request size limits, timeouts, concurrency/version checks. Never return
SQL, stack traces, secrets, or privileged file URLs.

Standard success:

``` json
{"data": {}, "meta": {"request_id": "uuid", "timestamp": "ISO-8601"}}
```

Standard error:

``` json
{"error": {"code": "VALIDATION_ERROR", "message": "The request could not be processed.", "details": [], "request_id": "uuid"}}
```

Required endpoint families:

### Auth/profile

-   `POST /auth/register`
-   `POST /auth/login`
-   `POST /auth/logout`
-   `POST /auth/logout-all`
-   `POST /auth/refresh` if applicable
-   `POST /auth/password/forgot`
-   `POST /auth/password/reset`
-   `POST /auth/email/verify`
-   `GET/PATCH /me`
-   `GET/PATCH /me/preferences`
-   `GET /me/sessions`
-   `DELETE /me/sessions/{sessionId}`
-   `GET/POST/DELETE /me/consents`
-   `POST /me/export`
-   `GET /me/export/{exportId}`
-   `POST /me/deletion-request`
-   `GET /me/deletion-request`

### Dashboard/analytics/reports

-   `GET /dashboard/summary`
-   `GET/PATCH /dashboard/widgets`
-   `GET /analytics/{cash-flow,income,expenses,categories,merchants,accounts,budgets,recurring,subscriptions,groups,goals}`
-   `POST /reports`
-   `GET /reports/{reportId}`
-   `GET /reports/{reportId}/download`

### Accounts/transactions

-   `GET/POST /accounts`
-   `GET/PATCH /accounts/{accountId}`
-   `POST /accounts/{accountId}/{archive,restore,close,reconcile}`
-   `GET /accounts/{accountId}/transactions`
-   `GET /accounts/{accountId}/balance`
-   `GET/POST /payment-methods`
-   `PATCH/DELETE /payment-methods/{id}`
-   `GET/POST /transactions`
-   `GET/PATCH/DELETE /transactions/{transactionId}`
-   `POST /transactions/{id}/{restore,duplicate}`
-   `POST /transactions/bulk-update`
-   `POST /transactions/bulk-delete`
-   `POST /transactions/{id}/refunds`
-   `POST /transactions/transfers`
-   `GET /transactions/{id}/audit`
-   `GET /transactions/search`
-   `POST /transactions/{id}/attachments`

### Categories/merchants

-   `GET/POST /categories`
-   `PATCH /categories/{id}`
-   `POST /categories/{id}/archive`
-   `POST /categories/merge`
-   `GET/POST /tags`
-   `PATCH/DELETE /tags/{id}`
-   `GET /merchants`
-   `GET /merchants/{id}`
-   `PATCH /merchants/{id}`
-   `POST /merchants/aliases`

### Budgets/bills/recurring/subscriptions

-   `GET/POST /budgets`
-   `GET/PATCH/DELETE /budgets/{id}`
-   `GET /budgets/{id}/progress`
-   `GET /budgets/{id}/transactions`
-   `POST/PATCH/DELETE /budgets/{id}/members`
-   `GET/POST /bills`
-   `PATCH /bills/{id}`
-   `POST /bills/{id}/{mark-paid,skip}`
-   `GET/POST /recurring-rules`
-   `GET/PATCH/DELETE /recurring-rules/{id}`
-   `POST /recurring-rules/{id}/{pause,resume,skip-next}`
-   `GET/POST /subscriptions`
-   `GET/PATCH /subscriptions/{id}`
-   `POST /subscriptions/{id}/cancelled`
-   `POST /subscriptions/detections/{id}/{confirm,dismiss}`

### Files/receipts/imports

-   `POST /files/upload-intent`
-   `POST /files/{id}/complete`
-   `GET /files/{id}/access`
-   `DELETE /files/{id}`
-   `GET/POST /receipts`
-   `GET /receipts/{id}`
-   `POST /receipts/{id}/process`
-   `PATCH /receipts/{id}/review`
-   `POST /receipts/{id}/{match-transaction,create-transaction}`
-   `POST /imports`
-   `GET /imports`
-   `GET /imports/{batchId}`
-   `POST /imports/{id}/{preview,confirm,cancel,retry-failed}`
-   `PATCH /imports/{id}/mapping`
-   `GET /imports/{id}/rows`
-   `GET /reconciliation/candidates`
-   `POST /reconciliation/matches`
-   `DELETE /reconciliation/matches/{id}`

### Goals

-   `GET/POST /goals`
-   `GET/PATCH/DELETE /goals/{id}`
-   `POST /goals/{id}/contributions`
-   `GET /goals/{id}/contributions`
-   `POST /goals/{id}/members`
-   `DELETE /goals/{id}/members/{userId}`
-   `GET /goals/{id}/forecast`

### Groups/shared expenses/settlements

-   `GET/POST /groups`
-   `GET/PATCH/DELETE /groups/{id}`
-   `POST /groups/{id}/invitations`
-   `POST /group-invitations/{token}/accept`
-   `POST /groups/{id}/join-requests`
-   `POST /groups/{id}/members`
-   `PATCH/DELETE /groups/{id}/members/{userId}`
-   `POST /groups/{id}/transfer-ownership`
-   `GET/POST /groups/{id}/expenses`
-   `GET/PATCH/DELETE /groups/{id}/expenses/{expenseId}`
-   `POST /groups/{id}/expenses/{expenseId}/comments`
-   `GET /groups/{id}/balances`
-   `GET /groups/{id}/settlement-suggestions`
-   `POST /groups/{id}/settlements`
-   `POST /groups/{id}/settlements/{settlementId}/{confirm,void}`
-   `GET /groups/{id}/activity`
-   `GET /groups/{id}/reports`

### Social/community/challenges

-   `GET /users/search`
-   `POST /friend-requests`
-   `POST /friend-requests/{id}/{accept,decline}`
-   `DELETE /connections/{userId}`
-   `POST/DELETE /users/{id}/block`
-   `POST /users/{id}/mute`
-   `GET/POST /communities`
-   `GET/PATCH /communities/{id}`
-   `POST /communities/{id}/{join,leave}`
-   `GET/POST /communities/{id}/posts`
-   `GET/PATCH/DELETE /posts/{id}`
-   `POST /posts/{id}/{comments,reactions,reports}`
-   `POST /communities/{id}/moderation/actions`
-   `GET/POST /challenges`
-   `POST /challenges/{id}/{join,progress}`
-   `GET /challenges/{id}/leaderboard`

### AI/integrations/notifications

-   `POST /ai/{ask,insights/generate,transactions/categorize,transactions/duplicate-check,subscriptions/detect,forecast,report-summary}`
-   `GET /ai/jobs/{jobId}`
-   `GET/PATCH /ai/preferences`
-   `GET /integrations`
-   `POST /integrations/{provider}/connect`
-   `GET /integrations/{provider}/callback`
-   `POST /integrations/{connectionId}/sync`
-   `DELETE /integrations/{connectionId}`
-   `GET /integrations/{connectionId}/status`
-   `POST /webhooks/{provider}`
-   `GET /notifications`
-   `PATCH /notifications/{id}`
-   `PATCH /notifications/preferences`

All endpoint families require request/response schemas, validation, auth
matrix, rate limits, error codes, pagination rules, idempotency and
tests. Webhooks verify signatures, replay protection and deduplication.

## 7. Frontend implementation

Suggested domain-oriented structure:

``` text
frontend/src/
  app/{providers,router,layouts,guards,error-boundaries}
  shared/{components,hooks,api,auth,forms,validation,formatting,accessibility}
  features/
    {onboarding,dashboard,accounts,transactions,categories,budgets,recurring,
     bills,subscriptions,receipts,imports,reconciliation,analytics,reports,
     goals,groups,shared-expenses,settlements,households,friends,communities,
     challenges,notifications,ai-assistant,integrations,settings,privacy,support}
  styles/
  tests/
```

Frontend requirements: - Strict TypeScript; avoid `any`. - Typed API
client and centralized session/error handling. - Schema-based form
validation. - Shared design system and reusable components. -
Loading/empty/error/success/permission states. - No duplicate financial
calculations in components. - Never trust client totals for writes. -
Safe optimistic updates only. - Prevent duplicate submission. - Handle
stale data and concurrent edits. - No secrets in browser bundles. -
Keyboard and screen-reader accessibility. - Responsive
desktop/tablet/mobile. - Localization-ready strings. - Reduced-motion
support. - Confirmation for destructive operations. - No sensitive
values in console logs or page titles.

Required screens: - Landing, product/security/privacy,
signup/login/verification/recovery. - Onboarding. - Dashboard and widget
settings. - Transaction list/detail/create/edit/bulk/search/audit. -
Account list/create/detail/balance/payment methods/reconciliation. -
Budget list/create/detail/allocation/progress/collaborators. - Recurring
rules, bills calendar, subscriptions and detection review. - Receipt
inbox/upload/review. - Import
wizard/mapping/preview/status/reconciliation. - Analytics and custom
reports/export. - Goals/list/detail/contribution/members. -
Groups/list/create/overview/members. - Shared expense
create/edit/split/detail. - Balances/settlements/disputes. -
Trips/events and household. - Profile/friends/requests. - Community
discovery/page/post/composer/comments/challenges. - Moderation/report
queue. - Notifications. -
Settings/privacy/security/integrations/export/deletion/support.

Design: calm, trustworthy, accessible financial product. Avoid
shame-based gamification. Positive/negative states must not rely on
color alone. Provide accessible chart descriptions and data tables.

## 8. Go backend architecture

Suggested structure:

``` text
backend/
  cmd/{api,worker,migrate}/
  internal/
    {config,http/auth,authorization,users,accounts,transactions,categories,
     budgets,recurring,bills,subscriptions,receipts,files,imports,
     reconciliation,analytics,reports,goals,groups,sharedexpenses,
     settlements,households,friends,communities,challenges,notifications,
     integrations,ai,jobs,audit,security,database,storage,observability}/
  migrations/
  api/openapi/
  tests/
  scripts/
```

Layers: 1. Transport/HTTP. 2. Authentication middleware. 3.
Authorization. 4. Application services. 5. Domain logic. 6. Repository.
7. Integration adapters. 8. Durable jobs. 9. Observability.

Go requirements: - Context propagation/cancellation. - Request body
limits and timeouts. - Graceful shutdown. - Connection pooling. -
Prepared/parameterized SQL. - Transactions. - Structured logs and
correlation IDs. - Health/readiness. - Panic recovery. - Rate
limiting. - Validation. - Safe error classification. - No
secrets/sensitive financial data in logs. - Dependency
pinning/scanning. - Race tests where practical. - Fuzz parsers and
money/split functions. - Provider outage handling. - Idempotent job
handlers.

Create independently tested domain packages for money, currency, split
allocation, transfer pairing, refunds, balance calculation, budget
aggregation, recurrence, exchange rates, settlements, forecasts, and
reconciliation. These packages must not depend on HTTP/UI frameworks.

## 9. Supabase PostgreSQL

-   Separate local/dev/staging/prod projects.
-   Migrations versioned and tested.
-   TLS and least-privilege roles.
-   Connection pooling suited to runtime.
-   Backups and point-in-time recovery where available.
-   Region/data residency assessment.
-   Monitor connections, latency, locks, storage, growth.
-   Foreign keys, check/unique constraints.
-   Index owner/date, account/date, group/date, merchant/category,
    recurrence next-run, notification unread, import batch/status, jobs
    status/run-after.
-   Avoid N+1 and unbounded queries.
-   Paginate.
-   Query-plan review for high-volume endpoints.
-   Cache derived aggregates only with clear invalidation.

RLS: - Enable on every user-facing table. - Test ownership, group
membership, public/private content, removed member access, exports and
file metadata. - Service-role key never in frontend. - Backend
privileged operations still authorize and audit. - Run multi-user RLS
tests in CI.

Realtime only for group updates, settlements, notifications,
import/receipt progress and collaborative budgets where useful.
Authenticate channels, restrict payloads, handle reconnect/missed
events, and re-fetch authoritative state. Realtime is not a durable
queue.

## 10. Appwrite Storage

Use for avatars, receipts, bills, group attachments, trip documents,
report exports, user exports, and moderated community media.

-   Separate private user, group-shared, public media, temporary
    processing, and export storage.
-   Private by default.
-   Backend authorization before access.
-   Short-lived access where supported.
-   Object ID and metadata stored in Supabase.
-   Verify owner, MIME, size, checksum and upload completion.
-   No privileged Appwrite key in frontend.
-   Revocation after group membership changes.
-   Account deletion removes associated objects.
-   Define retention, backup and recovery.
-   Document exact Appwrite version/API/permission semantics; do not
    guess.

Upload workflow: 1. User requests upload intent. 2. Go authenticates and
authorizes. 3. Backend creates scoped upload instruction. 4. Browser
uploads only through a scoped mechanism or backend proxy. 5. Backend
verifies completion/metadata/checksum. 6. Supabase metadata is
committed. 7. Processing job is enqueued. 8. Access is checked on every
read. 9. Deletion revokes access and removes object per policy.

## 11. Background jobs and scheduling

Job types: - OCR and preview generation. - File scanning. - Statement
parsing/import. - Reconciliation candidates. - Reports and exports. -
Account deletion. - Recurring transaction generation. -
Bill/subscription reminders. - Budget evaluation. - Anomaly detection. -
AI insights. - Provider sync/webhooks. - Notification dispatch. -
Moderation assistance. - Retention cleanup. - Search indexing. -
Analytics rollups.

Requirements: - Durable persistence. - At-least-once delivery with
idempotent handlers. - Retry with exponential backoff and jitter. - Max
attempts and dead-letter queue. - Manual retry. - Lease/visibility
timeout. - Concurrency limits and provider throttling. - Priority and
safe cancellation. - Progress and correlation IDs. - Safe error
categories. - No sensitive job payloads in logs. - Durable scheduler;
never rely on in-memory timers in serverless functions. - UTC instants
plus IANA timezone. - DST tests. - Recovery after downtime. - Idempotent
occurrence generation and notifications.

## 12. Security, privacy, compliance

Baseline: - HTTPS/TLS. - Secure headers. - Strict CORS. - CSRF
protection for cookie auth. - HttpOnly/Secure/SameSite cookies where
appropriate. - Short-lived access tokens and safe refresh rotation. -
MFA option. - Rate limits and brute-force defense. - Input
validation/output encoding. - Parameterized SQL. - XSS/CSRF/SSRF
defenses. - File upload hardening. - Webhook signatures/replay
protection. - Secrets management and rotation. - Dependency scanning,
SAST, DAST, penetration testing. - Incident response.

Threat model: - Account takeover/session theft. - Broken object-level
authorization. - Cross-user leakage. - Group membership abuse. -
Malicious files/PDFs. - CSV/XLSX formula injection. - SQL
injection/XSS/CSRF/SSRF. - Webhook spoof/replay. - Token leakage. -
Appwrite permission errors. - Supabase RLS bypass. - AI prompt
injection/cross-user context. - Cost exhaustion via OCR/import/AI. -
Community scams/harassment/impersonation. - Insider misuse. - Backup
exposure. - Incomplete deletion. - Dependency compromise.

Privacy: - Data inventory and flow map. - Purpose limitation and
minimization. - Consent records and revocation. - Retention schedule. -
Deletion process. - Vendor/subprocessor list. - Breach response. - Data
subject request workflow. - Privacy policy and AI disclosure. -
Cookie/analytics consent where required. - Age policy. - Cross-border
transfer assessment. - Qualified legal/compliance review before
financial integrations.

## 13. Reliability, performance, operations

Set measurable SLOs before launch. Initial planning targets, not
guarantees: - API availability 99.5% monthly early launch. - Core read
p95 \<500 ms under normal load. - Core write p95 \<800 ms under normal
load. - Document job and notification objectives defined by class. -
RPO/RTO documented and restore-tested.

Performance: - Paginate transactions/feeds. - Lazy load and virtualize
large lists. - Optimize previews. - Async large reports. - Bounded
workers. - Protect database connection pool. - Load test dashboard,
imports, groups, transaction endpoints. - Cache only safe derived data.

Resilience: - Timeouts. - Retry only safe/idempotent operations. -
Backoff/jitter. - Circuit breakers where useful. - Durable queue. -
Graceful degradation. - Backup verification and restore drills. -
Disaster recovery and rollback. - Status communication.

Observability: - Structured logs with request/job IDs. - Metrics:
request rate, errors, latency, DB pool/query, queue depth, retries,
import/receipt success, AI latency/cost, provider sync, notification
delivery, storage growth, auth/RLS failures, deletion backlog. - Traces
across API, jobs, database, providers. - Redact transaction
descriptions, receipt contents, tokens, account identifiers. - Alerts
for API errors, DB exhaustion, queue backlog, provider outage, webhook
failures, processing failures, backup failures, deletion backlog, cost
spikes.

Runbooks: - API/database outage. - Supabase connection exhaustion. -
Appwrite outage. - Queue backlog/worker crash. - AI provider outage. -
Bank integration outage. - Webhook incident. - Data corruption. -
Account takeover. - Privacy incident/breach. - Failed deletion. - Backup
restore. - Deployment rollback. - Secret rotation.

## 14. Testing and release gates

Unit tests: - Money/currency precision. -
Transfers/refunds/reimbursements. - Budget calculations. -
Recurrence/timezones/DST. - Subscription detection. - Split allocation
and remainder. - Group balances/settlements. - FX. - Forecasts. - Import
parsing/reconciliation. - Authorization helpers. - Notification dedupe.

Integration: - Go + Supabase. - RLS. - Appwrite upload/download
permissions. - Token validation. - Queue retry. - Webhook processing. -
Imports, receipts, reports, export/deletion. - Provider adapters.

E2E journeys: 1. Register/verify. 2. Onboard without bank. 3. Create
account. 4. Add income/expense. 5. Edit/delete transaction. 6. Transfer.
7. Refund. 8. Budget and threshold alert. 9. Recurring bill. 10.
Subscription reminder. 11. Upload/review receipt. 12. Import/reconcile
statement. 13. Create goal/contribution. 14. Create group/invite. 15.
Equal/exact/itemized splits. 16. Settlement suggestion and partial
settlement. 17. Confirm settlement. 18. Household budget. 19.
Public/private community. 20. Post/comment. 21. Join challenge with
opt-in progress. 22. Ask grounded AI question. 23. Export data. 24.
Request deletion. 25. Verify cross-user denial. 26. Verify removed group
member denial.

Use synthetic test data only. Include multiple currencies, negative
balances, refunds, partial settlements, duplicate imports, leap years,
DST, large amounts, zero/three-decimal currencies, malformed files,
malicious filenames, empty/large histories, and cross-tenant records.

Release gate per feature: - Requirement and UX complete. -
API/schema/migration complete. - Auth/RLS tested. - Validation and
failure handling complete. - Audit/observability complete. -
Unit/integration/E2E tests pass. - Accessibility/privacy/security
review. - Documentation updated. - No placeholder behavior. - Available
without payment.

## 15. Deployment preparation and CI/CD (manual deployment only)

The developer explicitly performs deployments manually. The coding agent
must not deploy Montra, publish builds, connect cloud projects, create
cloud resources, change DNS, configure production secrets, or execute
production release commands.

The agent's responsibility is to prepare deployment-ready code and
documentation:

- Provide Vercel-compatible web build configuration and a step-by-step
  manual deployment guide for the React portal.
- Provide Go backend build artifacts/configuration and a manual
  deployment guide for the selected Go-compatible runtime.
- Provide Flutter Android/iOS build instructions, signing prerequisites,
  release checklists, and store-submission guidance. Do not sign,
  upload, or publish an app unless the owner explicitly asks.
- Document Supabase hosted database configuration, migration order,
  connection pooling, RLS verification, backups, and rollback.
- Document Appwrite project/bucket setup, private permissions, API
  credentials, allowed origins where applicable, and safe secret
  injection. Do not create or modify the project.
- Provide environment variable inventories and safe `.env.example`
  files. Never place real secrets in source control or generated docs.
- Provide CI workflows that run formatting, linting, unit tests,
  contract tests, database tests, builds, and security checks. CI may
  build and validate artifacts, but must not automatically deploy.
- Use separate development, staging, and production configuration
  inventories. Never commit environment-specific secrets.
- Include release tags, version compatibility rules, migration
  preflight, backup verification, release notes, rollback steps, and
  post-release smoke-test checklists.

Forbidden unless the owner explicitly authorizes a particular action:

- `vercel deploy`, `vercel --prod`, or equivalent deployment commands.
- Production Go service deployment or restart.
- Production database migration execution.
- Supabase project creation/configuration or production data changes.
- Appwrite project/bucket creation or production permission changes.
- Mobile app signing, store upload, or publication.
- DNS/domain changes, production secret updates, or billing changes.

The implementation is considered deployment-ready when all required
configuration, scripts, build outputs, documentation, and manual
checklists exist and have been validated without deploying. Clearly
distinguish a successful local build from a deployed production release.

## 16. Accessibility, localization, analytics

Accessibility: - Keyboard navigation and visible focus. - Screen reader
labels. - Accessible chart summaries/tables. - Contrast and non-color
statuses. - Scalable text and reduced motion. - Field-associated
errors. - Accessible dialogs/menus. - Touch target sizing. -
Date/currency accessibility. - Assistive technology review.

Localization: - Translation keys. - Locale date/number/currency. -
Pluralization. - Timezone. - RTL readiness. - Localized
email/notifications/legal text. - INR and Indian number grouping
supported without assuming all users use INR. - Preserve original
transaction currency.

Product analytics: - Aggregate and minimize. - Never send transaction
amount, description, merchant, account ID, receipt text, or group
balance to generic analytics. - Track onboarding and feature
reliability/adoption. - Consent and opt-out where required. - Do not
optimize for compulsive use.

## 17. Free-access and cost management

All features are free. Do not implement: - Subscription checkout or
billing portal. - Premium entitlement service. - Plan-based feature
flags. - Upgrade banners/modals. - Paid-only exports, AI, groups,
receipt scanning, reports, or integrations.

Operator cost controls: - Efficient queries and indexes. - Image
compression. - Retention. - Async reports. - AI context minimization. -
Deterministic logic before AI. - Batch processing. - Abuse rate
limits. - Transparent fair-use controls. - Admin cost dashboard and
spend alerts. - Provider fallbacks that do not silently change privacy
terms.

## 18. Critical business workflows

### Add expense

Select owned account; enter amount/currency/date/category/merchant;
optionally add notes/tags/receipt; backend validates; transaction and
ledger effects commit atomically; outbox event triggers analytics/budget
work; idempotent retry returns original result; no partial writes.

### Transfer

Select owned source/destination; validate currencies; record paired
entries atomically; store FX/fee metadata; exclude principal from
income/expense; reversal path; reconcile sides independently.

### Group expense

Verify membership; select payer/participants; select split; allocate
exact minor units; validate sum; persist expense/shares atomically;
audit; notify by preference; recalculate balances.

### Settlement

Create proposal; validate parties and membership; notify counterparty;
confirm/dispute; record status/audit; recalculate; identify
user-reported vs provider-verified; support partial/void/correction.

### Statement import

Create batch; upload; parse in isolated worker; preview/map; validate;
dedupe; confirm; process idempotently; reconcile; expose failures; retry
without duplicating successes.

### Receipt

Private upload; verify; enqueue scan/extraction; extract
candidates/confidence; review/correct; match or create transaction; link
file; audit confirmation.

### Budget alert

Committed transaction emits event; durable evaluation; compute with
documented rules; dedupe threshold; check preferences; dispatch; record
status.

### AI question

Authenticate; determine allowed scope; query deterministic services;
build minimal provenance-rich context; call model only if consented;
validate output; explain uncertainty; no action without confirmation.

### Account deletion

Re-authenticate; disclose consequences/retention; revoke
sessions/integrations; block access; enqueue durable deletion; remove
Appwrite objects; delete/anonymize Supabase records per policy; handle
shared/group records; report completion and exceptions.

## 19. Complete feature coverage checklist

### Core finance

-   [ ] Auth, verification, recovery, sessions, MFA option.
-   [ ] Onboarding/profile/preferences.
-   [ ] Accounts/wallets/payment methods.
-   [ ] Income/expenses/transfers/refunds/reimbursements.
-   [ ] Categories/subcategories/tags/merchants.
-   [ ] Search/filter/sort/bulk actions/audit.
-   [ ] Balance model and reconciliation.

### Budgets and recurring

-   [ ] Weekly/monthly/custom/category/merchant/account budgets.
-   [ ] Household/group/trip budgets.
-   [ ] Rollover, forecasts, thresholds, alerts.
-   [ ] Recurring templates and occurrences.
-   [ ] Bills, reminders, skip/pause/resume.
-   [ ] Subscription manager/detection/price/trial alerts.

### Documents and imports

-   [ ] Receipt upload, extraction, review, matching.
-   [ ] Appwrite private storage and permissions.
-   [ ] CSV/XLSX and supported statement formats.
-   [ ] Mapping, preview, duplicate detection, retry.
-   [ ] Reconciliation and file retention/deletion.

### Analytics and intelligence

-   [ ] Dashboard and all widgets.
-   [ ] Cash flow/income/expense/category/merchant/account analytics.
-   [ ] Budget/subscription/recurring/group/goal analytics.
-   [ ] Custom reports and CSV/XLSX/PDF/JSON exports.
-   [ ] AI assistant/categorization/duplicate suggestions.
-   [ ] Anomaly detection/savings opportunities/forecast.
-   [ ] Explainability and evaluation.

### Goals and collaboration

-   [ ] Personal/shared goals, contributions, milestones, forecast.
-   [ ] Friends, requests, block/mute.
-   [ ] Groups, roles, invitations, ownership transfer.
-   [ ] Equal/exact/percentage/weighted/itemized splits.
-   [ ] Balances, settlement suggestions, partial/confirmed/voided
    settlements.
-   [ ] Trips/events.
-   [ ] Household space, shared bills/budgets/goals, privacy separation.

### Community

-   [ ] Profiles and opt-in sharing.
-   [ ] Public/private/invite-only communities.
-   [ ] Posts/comments/replies/reactions/polls.
-   [ ] Challenges and opt-in progress.
-   [ ] Moderation/report/block/mute/appeals/spam controls.

### Platform

-   [ ] Notifications and preferences.
-   [ ] Integrations framework, consent, revocation, webhooks.
-   [ ] Multi-currency and FX provenance.
-   [ ] Search and settings.
-   [ ] Export/deletion.
-   [ ] Accessibility/localization.
-   [ ] Help/support/security reporting.
-   [ ] Observability, backup/restore, incident response.
-   [ ] CI/CD, security/load tests, runbooks.
-   [ ] No paid feature gates.


## 20B. Detailed feature implementation playbooks (mandatory)

This section converts the feature catalogue into implementation
instructions. The coding agent must use these playbooks together with
the data model, API contract, privacy rules, workflows, and coverage
checklist. A feature is not complete merely because its screen exists
or its endpoint returns a successful response.

### 20B.1 Shared implementation contract for every feature

For every feature and every sub-feature, the agent must produce and
maintain the following implementation artifacts:

1. **Requirement breakdown:** list user stories, user roles, permissions,
   preconditions, business rules, edge cases, exclusions, and acceptance
   criteria. Split large features into independently testable stories.
2. **User experience:** identify every screen, route, dialog, bottom
   sheet, form, field, validation rule, loading state, empty state,
   success state, retry state, offline state, permission-denied state,
   and destructive-action confirmation for both Flutter and React.
3. **Domain model:** define entities, ownership, lifecycle, state
   transitions, invariants, unique constraints, foreign keys, indexes,
   audit requirements, and retention/deletion behavior.
4. **API contract:** define method, path, authentication, authorization,
   request schema, response schema, pagination, sorting/filtering,
   validation errors, domain errors, idempotency, rate limits, and
   version compatibility. Keep the OpenAPI contract current.
5. **Backend implementation:** implement transport handler, request
   validation, application service/use case, domain logic, repository,
   transaction boundaries, authorization, audit events, and structured
   observability. Keep handlers thin and domain logic independent of
   HTTP.
6. **Database implementation:** write forward migrations, constraints,
   indexes, RLS policies for hosted Supabase, local PostgreSQL-compatible
   schema, and deterministic test fixtures. Never edit an already
   applied migration; add a new migration.
7. **Client implementation:** implement the Flutter and React workflows
   against the shared API. Do not hardcode business rules separately in
   the clients. Handle loading, cancellation, stale responses,
   duplicate taps, validation, retries, pagination, and accessibility.
8. **Security:** verify object-level authorization on every read and
   write, prevent IDOR, validate ownership server-side, sanitize
   untrusted input, protect secrets, rate-limit abuse, and record
   security-relevant audit events.
9. **Reliability:** use database transactions for multi-record changes,
   idempotency for retryable commands, bounded retries for transient
   errors, explicit timeout behavior, and durable jobs for work that
   must survive process restarts.
10. **Tests:** add domain unit tests, repository/database integration
    tests against the developer's local PostgreSQL, API tests, contract
    tests, authorization tests, client tests, and end-to-end workflow
    tests. Appwrite provider calls are excluded from local tests as
    specified in the local development contract.
11. **Documentation:** update feature docs, API docs, schema/ERD,
    authorization matrix, event/job inventory, troubleshooting, and
    feature coverage status.
12. **Evidence:** record commands run, results, known limitations, and
    screenshots/logs where useful. Never mark a feature `TESTED` or
    `RELEASED` without evidence.

For each feature, use these states:
`NOT_STARTED`, `DESIGNED`, `IN_PROGRESS`, `IMPLEMENTED`,
`TESTED`, `RELEASED`, `BLOCKED`.

A feature may be marked `IMPLEMENTED` only when the full UI/API/domain/
database path exists. Mark `TESTED` only after required tests pass.
Mark `RELEASED` only after the owner performs the relevant release.

### 20B.2 Authentication, onboarding, profile, and account lifecycle

Implement registration, sign-in, sign-out, email/phone verification
where selected, password reset, session refresh, session revocation,
optional MFA, device/session listing, profile editing, preferences,
account closure, and account deletion.

- Define one identity authority and a documented identity-to-user-ID
  mapping. All finance records reference the stable internal user ID.
- Validate credentials and verification tokens on the Go backend or
  through the selected identity provider's supported secure flow.
- Use secure platform storage for mobile refresh credentials and secure,
  HTTP-only cookie/session patterns for the web portal where applicable.
  Never store privileged API keys in either client.
- Add brute-force protection, credential-stuffing controls, rate limits,
  generic authentication errors where needed, verification expiry,
  replay prevention, and session revocation.
- Onboarding collects only required profile information, locale,
  timezone, base currency, week/month preferences, notification
  preferences, and optional starter setup. Explain why each sensitive
  permission is requested.
- Allow users to skip optional steps and begin manual transaction entry
  without connecting a bank or uploading a document.
- Profile edits must validate supported locale/currency/timezone and
  must not silently rewrite historical transaction amounts.
- Account deletion requires re-authentication, clear consequence
  disclosure, session/integration revocation, durable deletion workflow,
  Appwrite object deletion in the hosted environment, policy-based
  handling of shared records, and completion/failure reporting.
- Acceptance: a new user can register, verify, sign in on both clients,
  create a profile, refresh/revoke sessions, recover access, and request
  deletion without exposing another user's records.

### 20B.3 Personal finance dashboard

The dashboard is a computed view over authoritative finance data, not a
separate manually maintained source of truth.

- Define exact formulas for total balance, net cash flow, income,
  expenses, budget progress, upcoming bills, subscription commitments,
  goal progress, and recent activity. Document inclusion/exclusion
  rules for transfers, refunds, pending items, archived accounts, and
  currencies.
- Support selectable date ranges and comparison periods. Use the user's
  timezone and configured week/month start.
- Each widget must expose its calculation period, currency, last-updated
  time, and a drill-down route to the underlying transactions or records.
- Users can customize widget visibility/order without changing finance
  records. Persist preferences per user.
- Use server-side aggregation and indexed queries; do not download every
  transaction to calculate dashboard totals in the client.
- Provide skeleton/loading, first-use empty state, no-activity state,
  partial-data/error state, and retry behavior.
- Cache only with explicit user scoping and invalidation after relevant
  writes. Never show stale balances as current without a timestamp.
- Acceptance: dashboard totals reconcile with transaction/account
  ledgers for every supported date range and currency; transfers are
  not double-counted as income or expense.

### 20B.4 Accounts, wallets, and payment methods

Implement user-owned financial containers such as cash, bank accounts,
savings accounts, credit cards, prepaid wallets, and other supported
account types.

- Define account type, display name, institution/label, currency,
  opening balance, current calculated balance, archived/closed state,
  display order, optional notes, and visibility.
- Treat opening balance as an explicit ledger event or documented
  opening-balance record; do not silently mutate balances.
- Distinguish account balance from available credit, credit limit,
  outstanding liability, and statement balance where supported.
- Prevent invalid currency changes after transactions exist unless a
  deliberate migration/revaluation workflow is implemented.
- Account archive must preserve history and prevent accidental new
  transactions while retaining reporting access.
- Support manual balance adjustment as an auditable transaction with
  reason, timestamp, and actor. Never silently overwrite derived balance.
- Ensure account ownership checks on every API route and group members
  cannot inspect personal account details.
- Acceptance: creating, editing, archiving, adjusting, and viewing
  accounts produces balances that reconcile against ledger entries.

### 20B.5 Transactions: expenses, income, transfers, refunds, reimbursements

Transactions are the core financial ledger. Treat posted transaction
records as auditable financial facts.

- Support transaction types and explicit states such as draft,
  pending, posted, voided, and reversed where required. Define allowed
  transitions and prohibit invalid transitions.
- Required fields include owner, type, amount in integer minor units
  or exact decimal representation, currency, account, transaction
  date/time, timezone context, category, and description/merchant where
  available. Optional fields include tags, notes, location text,
  attachment references, and source/import provenance.
- Validate amount precision against currency exponent; reject NaN,
  infinity, negative values where not permitted, overflow, and
  unsupported currency codes.
- Expense and income affect balances according to explicit ledger
  rules. A transfer creates linked debit and credit legs atomically and
  is excluded from income/expense totals. Refunds link to original
  transactions where possible and follow documented reporting rules.
- Support create, view, edit, duplicate, delete/void, search, filter,
  sort, bulk categorize, and export. Destructive operations require
  confirmation and audit records.
- Use optimistic concurrency/version checks so two edits do not
  silently overwrite each other. Add idempotency keys to create/import
  commands where retries can duplicate a record.
- Detect likely duplicates using explainable attributes; never delete
  or merge automatically without user confirmation.
- Maintain provenance: manual entry, import batch, receipt extraction,
  integration, or correction. Keep original source values when useful
  for audit/reconciliation.
- Acceptance: all transaction operations preserve ledger invariants,
  exact arithmetic, audit history, and correct dashboard/report totals.

### 20B.6 Categories, tags, and merchants

- Provide a default category hierarchy plus user-created categories,
  subcategories, icons/colors, sort order, and active/archive state.
- Prevent cycles and invalid parent relationships. Define behavior when
  a category is archived or deleted while historical transactions use it.
- Support tags as many-to-many labels with normalized names and
  per-user ownership. Prevent duplicate tag names under the selected
  normalization policy.
- Merchant records support normalized display name, aliases, optional
  website/contact metadata, and user corrections. Do not infer or expose
  private merchant data across users without a deliberate public source.
- Provide categorization rules with explicit priority, match conditions,
  scope, enable/disable, and preview. Rules must be deterministic,
  explainable, and reversible.
- Bulk recategorization must be transactional or chunked with progress,
  cancellation policy, and audit trail.
- Acceptance: category/tag/merchant changes update analytics
  consistently without destroying historical records.

### 20B.7 Budgets and spending controls

- Support overall, category, subcategory, merchant, account, household,
  group, and custom-period budgets as appropriate to the product model.
- Define budget period, timezone, currency, rollover policy, included
  transaction states/types, exclusions, and whether refunds restore
  available budget.
- Calculate spent, remaining, projected spend, percentage used, and
  overspend using exact arithmetic. Document how split/group expenses
  count for each participant.
- Support thresholds and notification preferences with deduplication
  so one transaction does not repeatedly trigger the same threshold.
- Budget edits must define whether changes apply retroactively to the
  current period or only future periods.
- Provide budget creation wizard, progress details, transaction drill
  down, history, pause/archive, and forecast explanations.
- Acceptance: boundary tests cover period rollover, timezone changes,
  refunds, edits, transfers, excluded categories, and threshold crossing.

### 20B.8 Recurring transactions, bills, and reminders

- Define recurrence frequency, interval, start/end, timezone, day-of-
  month behavior, month-end behavior, next due date, pause state, and
  exception dates.
- Generate occurrences idempotently. A worker restart or repeated
  scheduler delivery must not create duplicate transactions.
- Distinguish a scheduled reminder/expected transaction from a posted
  financial transaction. Never mark a bill paid just because its due
  date passed.
- Support confirm-paid, skip, postpone, edit-this-occurrence, edit-this-
  and-future, pause, resume, and cancel.
- Notify according to user preferences and quiet hours. Deduplicate
  notifications by occurrence and channel.
- Handle timezone and daylight-saving changes without shifting the
  user's intended local due time unexpectedly.
- Acceptance: tests cover monthly dates 28–31, leap years, missed
  scheduler runs, retries, pause/resume, and duplicate prevention.

### 20B.9 Subscription manager

- Allow manual subscription creation and management independently of
  automatic detection.
- Track merchant, plan, amount, currency, billing cadence, next charge,
  trial end, renewal state, payment account, notes, and cancellation
  instructions supplied by the user.
- Detect possible recurring charges using explainable matching of
  merchant, amount tolerance, and cadence. Present confidence and
  supporting transactions.
- Require user confirmation before creating/updating a subscription
  from detected transactions.
- Provide upcoming renewals, trial-ending alerts, price-change history,
  yearly cost projection, and active/paused/cancelled status.
- Do not claim to cancel subscriptions unless an authorized provider
  integration actually performs and verifies cancellation.
- Acceptance: manual subscription lifecycle works with no bank
  connection and detection never silently alters ledger records.

### 20B.10 Receipt capture and Appwrite document storage

Implement the production Appwrite adapter and all surrounding Go
business logic, but do not connect to or test Appwrite during local
development.

- Flutter supports camera/gallery selection and capture; web supports
  permitted file selection and upload flow.
- Validate file size, MIME type, extension, content signature, image
  dimensions, and allowed formats on the backend. Treat client MIME
  declarations as untrusted.
- Authorize the user before issuing upload/download capability. Use
  private buckets/objects and short-lived access mechanisms supported by
  Appwrite. Never expose an Appwrite API key to clients.
- Store object ID, owner, file type, checksum, size, upload state,
  retention state, and linked transaction metadata in PostgreSQL.
- Implement upload intent, completion, metadata persistence, secure
  retrieval authorization, replacement/version policy, unlinking,
  deletion, and orphan cleanup.
- OCR/extraction is asynchronous. Store extracted candidates and
  confidence separately from confirmed transaction data. User reviews
  and confirms all extracted financial values.
- Handle partial upload, retry, timeout, provider outage, deleted
  object, mismatched metadata, and duplicate upload.
- Local tests cover validation, authorization, metadata lifecycle,
  adapter error mapping, and business logic using a test double. Do not
  run real Appwrite storage calls locally. Hosted provider verification
  is a separate owner-controlled activity.
- Acceptance: code path is complete and production-configurable; no
  claim of live Appwrite connectivity is made until the owner configures
  and verifies the hosted provider.

### 20B.11 Statement import and reconciliation

- Support explicitly documented formats first (for example CSV and
  selected spreadsheet/bank statement formats). Maintain per-format
  parser versions and sample fixtures that contain synthetic data.
- Upload and parsing are separate steps. Create an import batch with
  owner, source, file metadata, parser version, status, and counts.
- Parse in an isolated worker with size/time/resource limits. Reject
  malformed or unsupported files with actionable row-level errors.
- Provide column mapping, date/amount/description normalization,
  currency/account selection, preview, duplicate detection, and
  user-confirmed import.
- Keep raw parsed rows and normalized candidates separate from posted
  transactions. Store row-level processing status and error reasons.
- Use deterministic idempotency keys so retrying a batch does not
  duplicate already imported rows.
- Reconciliation compares statement rows with existing transactions
  using explainable matching and lets users confirm, ignore, or create
  missing entries.
- Support cancellation, retry of failed rows, batch rollback where
  safe, and audit history.
- Acceptance: repeated imports, partial failures, parser upgrades, and
  user corrections do not create duplicate or silently altered ledger
  entries.

### 20B.12 Analytics, reports, and exports

- Define a canonical calculation layer shared by dashboard, charts,
  reports, and AI context. Document formulas and filters once.
- Support date range, currency, account, category, merchant, tag,
  transaction type, and comparison-period filters.
- Provide cash flow, income/expense trends, category breakdown,
  merchant analysis, account balance history, budget performance,
  recurring commitments, group spending, and goal progress.
- All charts require accessible labels, data tables or equivalent
  summaries, empty states, and clear currency/period labels.
- Reports must be reproducible for a selected filter snapshot. Large
  reports/exports run as durable jobs and expose queued/running/
  completed/failed/expired states.
- Exports must respect authorization and privacy. CSV/XLSX/PDF/JSON
  formats must escape untrusted cell content, avoid spreadsheet formula
  injection, use correct encoding, and have documented size limits.
- Acceptance: report totals reconcile with the ledger and equivalent
  filters produce consistent results across web, mobile, and export.

### 20B.13 AI financial assistant and AI-powered suggestions

- AI is optional and advisory. The app must remain fully usable if no
  AI provider is configured or a provider is unavailable.
- Define user consent, data scope, retention, provider disclosure,
  opt-out, and deletion of AI conversation history.
- Use deterministic backend queries for financial facts and arithmetic.
  Send only the minimum authorized context required to answer a
  question. Never trust a model to calculate balances or authorize access.
- Clearly distinguish sourced facts, derived calculations, estimates,
  and model-generated suggestions. Show the relevant period and data
  coverage.
- Protect against prompt injection in imported descriptions, receipts,
  merchant names, and community content. Treat all user content and
  retrieved text as untrusted data, never as system instructions.
- Validate structured model output against schemas and domain limits.
  Apply content safety and financial-advice boundaries.
- AI must never initiate payments, settle group debts, modify budgets,
  delete records, or make irreversible changes without a separate
  explicit user confirmation and normal authorization flow.
- Log provider/model/version, latency, token/cost estimates, outcome,
  and safety decisions without logging unnecessary sensitive financial
  payloads.
- Acceptance: provider-off mode works, unauthorized data never enters
  context, arithmetic is deterministic, and suggested actions require
  confirmation.

### 20B.14 Anomaly detection and savings intelligence

- Start with deterministic, explainable rules and statistical baselines
  using the user's own authorized history.
- Detect unusual amount, frequency, merchant, duplicate candidate,
  category spike, unexpected recurring charge, and budget deviation.
- Define minimum history/data thresholds, confidence, false-positive
  controls, and suppression/dismissal behavior.
- Explain why an alert appeared and which transactions/time period
  contributed. Never label a transaction fraudulent as a fact based
  solely on a heuristic.
- Savings suggestions must show the calculation, assumptions, time
  horizon, and trade-offs. Do not promise guaranteed savings.
- Provide feedback actions such as helpful/not helpful, dismiss, mute,
  and correction; use feedback only under disclosed policy.
- Acceptance: tests cover sparse history, changed income, seasonal
  spending, refunds, currency changes, and false-positive suppression.

### 20B.15 Goals and savings plans

- Support personal and explicitly shared goals with target amount,
  currency, target date, starting amount, contribution schedule,
  visibility, and status.
- Track contributions as auditable events; distinguish planned,
  recorded, and externally verified contributions.
- Calculate progress and forecast using exact arithmetic and clearly
  labeled assumptions. Do not treat a goal contribution as a bank
  transfer unless the ledger records the actual movement.
- Support edit, pause, complete, archive, and cancel with history.
- Shared goals require explicit membership, contribution visibility,
  and exit/deletion rules.
- Acceptance: goal progress reconciles with contribution events and
  changing a target never rewrites past contributions.

### 20B.16 Friends, groups, households, shared expenses, and settlements

- Implement friend requests, acceptance/rejection, block, mute, remove,
  group creation, invitations, role changes, member removal, and
  ownership transfer.
- Group roles and capabilities must be explicit. Every group resource
  has group ownership; personal account records remain private unless
  the user explicitly shares a particular item.
- Support equal, exact, percentage, weighted, and itemized splits.
  Validate that allocations sum exactly to the source amount in minor
  units; define deterministic remainder distribution.
- Record payer, participants, allocation amounts, currency, expense
  description, attachments, comments, and edit history.
- Maintain per-member balances from immutable expense/allocation/
  settlement events. Do not rely on a mutable cached balance as the
  only source of truth.
- Settlement proposals are not verified payments. Support proposed,
  accepted, disputed, user-reported-paid, partially settled, voided,
  and corrected states. Provider-verified status is allowed only when
  a real authorized provider confirms it.
- Handle partial settlements, reversals, member departure, group
  deletion, expense edits, currency differences, and disputes.
- Household shared bills/budgets/goals must remain separate from
  personal financial accounts and transactions.
- Acceptance: split math is exact, membership is enforced on every
  request, and one member cannot inspect another member's private
  finance records.

### 20B.17 Communities, posts, challenges, and moderation

- Define public/private community visibility, membership approval,
  roles, post types, comments, reactions, polls, challenge rules,
  reporting, moderation queues, and appeal workflows.
- Public profiles and posts must never expose private balances,
  transaction lists, receipts, or absolute spending by default.
- Challenge participation and progress sharing are opt-in. Prefer
  normalized milestones/percentages over revealing wealth or income.
- Add rate limits, spam controls, abuse reporting, block/mute,
  content removal, moderator audit, and account sanctions.
- Sanitize rendered content and attachments. Protect against XSS,
  malicious links, harassment, impersonation, and data leakage.
- Define moderation response targets, escalation, evidence retention,
  and appeal ownership before opening public communities.
- Acceptance: users can participate without sharing personal finance
  data; moderation actions are auditable and reversible where policy
  allows.

### 20B.18 Notifications and preferences

- Centralize notification event creation and channel dispatch. Support
  in-app notifications and selected email/push channels when configured.
- Define event types, priority, templates, localization, quiet hours,
  user preferences, deduplication keys, retry policy, expiry, and
  delivery status.
- Persist notification intent before dispatch. Use durable jobs and
  idempotent delivery handling to survive restarts and provider errors.
- Deep links must authenticate and authorize the destination resource
  after opening; notification payloads must not contain sensitive
  financial details on lock screens by default.
- Provide unread/read, mark all read, archive, mute category, and
  notification history.
- Acceptance: disabling a channel prevents future dispatch on that
  channel and retries do not create duplicate in-app notifications.

### 20B.19 Financial integrations and India-specific safeguards

- Manual-first entry and statement import must work without any bank,
  UPI, payment, or Account Aggregator integration.
- Maintain a provider registry with provider status, country,
  capabilities, consent requirements, credentials status, rate limits,
  webhook verification, data mapping, and disconnect behavior.
- Never collect bank passwords, UPI PINs, OTPs, card CVVs, or other
  authentication secrets. Do not scrape private banking sessions.
- Do not assume mobile apps can read arbitrary UPI/SMS notifications.
  Respect Android/iOS platform permissions and policies.
- Account Aggregator or other regulated financial-data connectivity
  requires legal/compliance review, approved provider relationships,
  explicit consent, and documented revocation/deletion workflows.
- Verify webhook signatures, timestamps, replay protection, and
  idempotency. Quarantine malformed or suspicious events.
- Clearly label connected, disconnected, consent-expired, syncing,
  partial, and failed states. Never imply a provider connection is live
  when it is not.
- Acceptance: provider-free core workflows work; integrations are
  enabled only after real credentials, approvals, and verification.

### 20B.20 Multi-currency and foreign exchange

- Store every monetary value with currency code and exact minor-unit
  amount. Define currency exponent and rounding policy.
- Preserve transaction currency and original amount. Any converted
  reporting amount must store rate, rate source, timestamp, and
  conversion direction.
- Never silently rewrite historical FX rates when the rate provider
  changes. Provide an explicit historical/current conversion policy.
- Define how transfers between currencies are represented, including
  source amount, destination amount, rate, fees, and rounding delta.
- Aggregate multi-currency dashboards only with a clearly selected
  display currency and disclosed rate timestamp/source.
- Acceptance: no floating-point arithmetic is used and conversion
  rounding/reconciliation tests cover edge cases.

### 20B.21 Search, personalization, help, and trust

- Search must be scoped to the authenticated user's authorized data
  and the groups/communities they may access. Enforce authorization
  before returning results, not merely in the UI.
- Support filters, sorting, recent searches, clear history, and
  accessible empty/error states. Avoid leaking result counts or
  snippets from inaccessible records.
- Personalization includes theme, locale, timezone, currency display,
  date/number formats, dashboard layout, privacy defaults, and
  notification settings.
- Help includes searchable guidance, contact/support workflow,
  bug reporting, export/deletion instructions, and security reporting.
- Trust surfaces explain data collection, storage, AI processing,
  integration consent, retention, account deletion, and incident
  communication.
- Acceptance: preferences apply consistently across clients and
  search cannot reveal records outside the user's authorization scope.

### 20B.22 Backend, API, database, and shared platform capabilities

These are cross-cutting product capabilities, not optional engineering
cleanup:

- Go services use explicit domain/application/infrastructure
  boundaries, structured errors, request IDs, context cancellation,
  timeouts, graceful shutdown, and configuration validation.
- API endpoints implement authentication, object-level authorization,
  schema validation, pagination limits, rate limits, idempotency,
  versioning, audit, and OpenAPI documentation.
- PostgreSQL uses foreign keys, check constraints, unique constraints,
  appropriate indexes, transactions, migration discipline, and
  query-plan review for critical paths.
- Use an outbox or equivalent reliable event publication pattern when
  database commits must reliably trigger jobs/events.
- Background jobs have durable state, attempt counts, bounded retries,
  backoff, lease/lock strategy, idempotent handlers, dead-letter
  handling, cancellation policy, and operator visibility.
- Observability includes structured logs, metrics, traces, health/readiness
  checks, dependency health, and privacy-safe audit records.
- All data export, account deletion, retention cleanup, and user
  consent revocation must be durable, resumable, and auditable.

### 20B.23 Client parity and platform-specific implementation

For every feature, maintain a parity table with columns for Flutter,
React web, Go API, database, permissions, and tests.

Flutter-specific requirements:
- Android and iOS navigation conventions, responsive layouts,
  accessibility semantics, secure session storage, lifecycle handling,
  deep links, notification permissions, camera/gallery permission
  explanations, and offline/reconnect states.
- Handle app backgrounding, interrupted uploads, token expiry, app
  upgrades, and stale cached views safely.
- Do not persist sensitive finance data in unencrypted local storage.

React-specific requirements:
- Responsive desktop/mobile web layouts, keyboard navigation, screen
  reader labels, route guards, secure session handling, refresh/error
  boundaries, and safe browser storage practices.
- Avoid placing secrets or sensitive full transaction data in URLs,
  browser logs, analytics payloads, or local storage.

Shared requirements:
- Both clients call the same Go API and obey the same authorization
  decisions and financial calculations.
- Generate/validate typed models from the API contract where practical.
- Keep supported mobile app versions compatible with backend changes.
- Never mark a feature complete on one client while the other required
  client remains unfinished; report platform-specific blockers
  explicitly.

### 20B.24 Feature execution sequence and agent workflow

For each feature, the coding agent must work in this order:

1. Read the product specification and existing repository state.
2. Search for existing implementations before creating new files.
3. Write a feature design note and acceptance checklist.
4. Update the API contract and data model before implementation.
5. Add forward-only database migrations and RLS policies.
6. Implement domain logic and unit tests.
7. Implement repositories and local PostgreSQL integration tests.
8. Implement Go handlers, authorization, audit, and API tests.
9. Implement Flutter screens/state/data integration and tests.
10. Implement React routes/components/data integration and tests.
11. Add jobs, notifications, and integrations only where required.
12. Run formatting, linting, static analysis, tests, and builds.
13. Review security, privacy, accessibility, and performance.
14. Update documentation, feature matrix, and release notes.
15. Report exact completed work, commands/results, remaining tasks,
    blocked provider dependencies, and known limitations.

Do not attempt to implement the entire product in one unreviewed code
generation pass. Deliver vertical slices that work end to end, preserve
the full feature inventory, and keep the repository buildable after
each milestone.

### 20B.25 Explicitly prohibited shortcuts

- Fake buttons, static charts presented as live data, placeholder
  endpoints, mock integrations represented as connected, or hardcoded
  success responses.
- In-memory storage as a substitute for PostgreSQL persistence.
- Local Appwrite calls or local Appwrite integration testing.
- Deploying to Vercel or any other environment without the owner's
  explicit request.
- Running destructive database commands without verifying the target.
- Floating-point financial arithmetic.
- Client-side-only authorization or trusting user-supplied owner IDs.
- AI-generated financial calculations treated as authoritative.
- Claiming a feature is production-ready without tests, security review,
  operational behavior, and documented external dependencies.
- Silently removing or deferring any feature from the agreed catalogue.


## 20. Implementation roadmap

### Phase 0 --- Architecture foundation

Product glossary, scope, threat model, data-flow/deployment diagrams,
auth decision, Vercel/Go topology, ERD, RLS matrix, Appwrite
permissions, job design, API conventions, environments, CI.

### Phase 1 --- Personal finance core

Auth, onboarding, profile, accounts, categories, transactions,
income/expense/transfer, dashboard basics, search, audit, export
foundation.

### Phase 2 --- Budgets and recurring

Budgets, allocations, progress, alerts, recurrence, bills, scheduler,
notification center.

### Phase 3 --- Documents/imports

Appwrite, receipt workflow, OCR, CSV/XLSX/statement import, mapping,
duplicate detection, reconciliation, deletion.

### Phase 4 --- Reports/subscriptions

Analytics, custom reports, exports, recurring detection, subscriptions,
renewals, trial/price alerts.

### Phase 5 --- Goals/multi-currency

Goals, contributions, milestones, forecasts, FX metadata and
multi-currency reporting.

### Phase 6 --- Groups/household

Groups, invitations, roles, shared expenses, split methods, balances,
settlements, trips, household budgets/goals.

### Phase 7 --- Communities/challenges

Profiles, connections, public/private communities, posts, comments,
polls, challenges, moderation and safety.

### Phase 8 --- AI intelligence

AI assistant, categorization, anomaly, subscription detection,
forecasts, savings suggestions, explainability and evaluations.

### Phase 9 --- Financial integrations

Provider adapters, consent, revocation, authorized providers, sync,
webhooks, reconciliation; only after legal/security review.

### Phase 10 --- Production hardening

Load/security/accessibility tests, backup restore, deletion drill,
runbooks, monitoring, legal/privacy review, user documentation, smoke
tests.

Do not implement all features in one uncontrolled code-generation pass.
Keep the application buildable, deliver vertical slices, and track every
requirement.

## 21. Definition of done

A feature is complete only when: 1. Requirement documented. 2. UX flow
implemented. 3. Frontend responsive and accessible. 4. Go use case/API
implemented. 5. Schema/migration/constraints/indexes implemented. 6.
Authorization and RLS tested. 7. Validation and failure/retry behavior
implemented. 8. Audit and observability added. 9. Unit/integration/E2E
tests pass. 10. Privacy/security review completed. 11. API/user docs
updated. 12. No placeholder/mock behavior remains. 13. Feature works
without a paid plan. 14. Known limitations are disclosed.

## 22. Master instructions for Claude Code or another coding agent

Act as a principal product engineer, staff Go engineer, senior
React/TypeScript engineer, database engineer, security engineer, QA
engineer, and SRE. Build the actual product, not a UI prototype.

Before coding: - Read this entire specification. - Use the PostgreSQL
server already installed on the developer's machine for local database
development. - Do not use Docker as a database prerequisite. - Do not
connect to Appwrite or test Appwrite storage locally; implement its
production code behind an adapter. - Do not deploy to Vercel or any
other platform; the owner performs deployments manually. - Produce requirements
inventory and traceability matrix. - Produce architecture decision
records. - Produce system context, deployment and data-flow diagrams. -
Produce threat model. - Produce ERD and RLS policy matrix. - Produce
authorization matrix. - Produce OpenAPI contract. - Produce
job/integration inventory. - Produce test strategy, milestones and risk
register. - Resolve open decisions explicitly; do not invent hidden
assumptions.

For each feature: 1. Map requirement to UI/API/schema/auth/tests. 2.
Design migration and constraints. 3. Define API contract. 4. Implement
domain logic. 5. Implement repository and service. 6. Implement
authorization. 7. Implement handler. 8. Implement frontend. 9. Add
validation and error states. 10. Add audit/observability. 11. Add unit,
integration and E2E tests. 12. Run tests and inspect failures. 13.
Update docs and feature matrix. 14. Mark complete only with evidence.

Never: - Omit a feature silently. - Replace real functionality with mock
data. - Add paid tiers. - Change stack without approval. - Expose
secrets. - Bypass auth/RLS. - Use float for money. - Let AI be source of
truth for arithmetic. - Treat user-reported settlement as verified
payment. - Claim integrations work without real provider
configuration. - Claim persistent workers run on Vercel without
verifying runtime support. - Claim production readiness without tests
and operational evidence.

Feature status values: `NOT_STARTED`, `DESIGNED`, `IN_PROGRESS`,
`IMPLEMENTED`, `TESTED`, `RELEASED`, `BLOCKED`.

Maintain project docs: - `README.md` - `PRODUCT_SPEC.md` -
`ARCHITECTURE.md` - `DEPLOYMENT.md` - `SECURITY.md` - `PRIVACY.md` -
`THREAT_MODEL.md` - `DATA_MODEL.md` - `API.md` - `OPENAPI.yaml` -
`RLS_POLICY_MATRIX.md` - `AUTHORIZATION_MATRIX.md` -
`BACKGROUND_JOBS.md` - `INTEGRATIONS.md` - `TESTING.md` -
`OPERATIONS.md` - `INCIDENT_RESPONSE.md` - `DISASTER_RECOVERY.md` -
`FEATURE_COVERAGE.md` - `CHANGELOG.md` - `DECISIONS/`

Before production readiness claim, report implemented/incomplete/blocked
features, external dependencies, test results, security scan, RLS
results, load test, accessibility review, backup/restore evidence,
deployment topology, cost assumptions, known limitations, runbooks,
rollback, and confirmation that no paid feature gates exist.

## 23. Open decisions

Resolve and record: 1. Domain/trademark and final brand clearance
(Montra is the selected product name). 2. Launch countries and age
policy. 3. Identity provider/session model. 4. Go API/worker hosting
runtime (Vercel web deployment is manual and owner-controlled). 5.
Durable queue and scheduler. 6. Email and web push
provider. 7. AI provider, privacy terms, fallback. 8. OCR
provider/approach. 9. FX rate source. 10. Bank data provider and
compliance. 11. Supported statement formats. 12. Appwrite
bucket/permission design. 13. Supabase region, pooling and backup. 14.
Community moderation ownership. 15. Retention periods. 16. Group data
behavior after member deletion. 17. Data residency/cross-border
processing. 18. Support/security contact. 19. SLO and capacity
assumptions.

For each decision record selected option, alternatives, rationale,
security/privacy implications, cost, reversibility, owner and date.

## 24. Final product standard

Montra is complete only when a user can manage personal finances;
accounts, income, expenses, transfers and refunds; budgets; recurring
bills and subscriptions; receipts; statement imports and reconciliation;
analytics and exports; goals; groups, household expenses and
settlements; privacy-respecting communities and challenges; AI-assisted
insights; integrations where authorized; notifications; privacy
controls; export and deletion.

Every listed capability must be implemented, tested, documented, and
available without payment. Provider-dependent features must identify
their legal, approval, credential, quota, and operating-cost
dependencies. Their absence must not break manual-first finance
functionality.

**The goal is not to ship the largest number of screens. The goal is to
ship every promised workflow correctly, securely, and end to end.**


## 26. Local development and owner-controlled operations summary

The following decisions are fixed and must not be reinterpreted by an
implementation agent:

- Product name: **Montra**.
- Mobile: **Flutter**.
- Web portal: **React + TypeScript**.
- Backend: **Go**.
- Hosted relational database target: **Supabase PostgreSQL**.
- Local development database: the PostgreSQL installation already
  present on the developer's system.
- File storage: **Appwrite Storage**, with complete production code
  implemented but no Appwrite connection or file-storage integration
  testing in local development.
- Web hosting target: **Vercel**, with manual deployment performed by
  the owner.
- Repository: **monorepo**.
- Existing development tools include VS Code, Android Studio, Postman,
  and Claude. Verify the actual environment and do not reinstall these
  without need.
- All product features remain free to every user.

The coding agent may prepare build scripts, CI validation, deployment
configuration, migration instructions, release notes, and operational
runbooks. It must stop before any cloud deployment, production
configuration change, production migration, cloud resource creation,
store publication, or DNS/secret modification. Those actions belong to
the owner unless separately and explicitly authorized.

A local build passing does not mean a hosted integration is verified.
A generated deployment guide does not mean a deployment has occurred.
An Appwrite adapter compiling does not mean the Appwrite project is
configured. Report these distinctions accurately in every milestone
summary.
