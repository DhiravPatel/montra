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
- **Supabase PostgreSQL:** authoritative relational data, constraints,
  transactions, indexes, RLS, backups, and database migrations.
- **Appwrite Storage:** private files and objects. Supabase stores object
  identifiers and metadata, not public URLs as the source of truth.
- **Vercel:** React web portal delivery and any supported stateless
  web-specific endpoints only when justified by the deployment design.
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

## 15. Deployment and CI/CD

Environments: local, development, staging, production. Separate
Supabase, Appwrite, secrets, OAuth/webhook/AI keys, domains, and data.
Never use production financial data in development.

Vercel frontend: - Build/output configuration. - Environment
variables. - Preview deployments. - Domain/HTTPS. - SPA deep-link
routing. - Security headers. - Safe cache policy; private financial
responses never public-cache. - Build/runtime monitoring.

Go backend: - Document selected runtime topology. - Pin Go version. -
Reproducible build. - Health/readiness. - Graceful shutdown. - Secrets
injection. - DB connection management. - Timeouts, logs, metrics. -
Smoke tests and rollback.

CI on every PR: 1. Format. 2. Type-check TypeScript. 3. Lint. 4.
Frontend unit tests. 5. Go unit/race tests where applicable. 6.
Integration tests. 7. Migration validation. 8. RLS tests. 9. OpenAPI
validation. 10. Frontend/backend builds. 11. Secret scan. 12. Dependency
scan. 13. Static analysis. 14. License checks. 15. E2E tests. 16.
Coverage artifacts.

Release: - Deploy staging. - Apply controlled migrations. - Smoke
test. - Approval. - Deploy production. - Verify health. - Monitor. -
Roll back if gates fail.

Migrations must be versioned, backward compatible where possible,
expand-and-contract for breaking changes, tested at realistic volume,
backed up for risky operations, and accompanied by rollback/forward-fix
notes. Never silently edit an applied migration.

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

Before coding: - Read this entire specification. - Produce requirements
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

Resolve and record: 1. Final name/domain. 2. Launch countries and age
policy. 3. Identity provider/session model. 4. Vercel/Go topology and
worker runtime. 5. Durable queue and scheduler. 6. Email and web push
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
