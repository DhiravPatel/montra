# Montra — Metric Definitions

These definitions are the single source for the dashboard, analytics,
reports and (later) AI context. They are implemented once in
`backend/internal/analytics` (SQL classification mirrors
`domain/ledger.Classify`) and in the planning services. All amounts are exact
integers in minor units; nothing uses floating point.

## Scope and dates

- **Window:** inclusive local dates `from`–`to` in the user's time zone
  (`user_preferences.timezone`). Named ranges (`this_month`, `last_week`, …)
  follow the user's week start and month start day.
- **Included transactions:** the caller's own, not deleted, status `posted`
  (plus `pending` only when `include_pending=true`). Voided transactions never
  count.
- **Filters:** accounts, categories (a parent includes its subcategories),
  merchants, tags (any), currency, transaction types, overview-only accounts.
- **Currencies:** every figure is per currency. Different currencies are
  combined only in an explicit converted view (see Conversion).

## Cash flow

| Metric | Definition |
|---|---|
| Income | Sum of `income` transactions |
| Gross expense | Sum of `expense` + the personal share of `group_expense` (the whole amount when no share is recorded) |
| Refunds | Sum of `refund` and `reimbursement` transactions (contra-expense; capped at the original by the ledger) |
| Net expense | Gross expense − refunds |
| Net cash flow | Income − net expense |
| Savings rate | Net cash flow ÷ income, in basis points (omitted when income is 0) |
| Previous period | The same metrics for the same-length window immediately before |
| Series | The metrics bucketed by day/week/month/year (bucket = start date) |

Excluded from income and expense: `transfer` (both legs), `adjustment`,
`opening_balance` and `settlement`. A transfer fee is a separate expense.
Credit-card payments are transfers, so purchases are counted once (when made
on the card), never again when the card is paid.

## Breakdowns

- **Category spend** (`kind=expense`, the default): net expense per
  category with the expense types (`expense`, `group_expense`, `refund`,
  `reimbursement`); subcategories roll up to their parent by default;
  **share** = category net expense ÷ total net expense in that currency
  (basis points). Uncategorized is its own bucket.
- **Category income** (`kind=income`): income per category with the
  income type (`income`), the same set as the income view; **share** =
  category income ÷ total income in that currency.
- **Merchant spend:** net expense per merchant with a positive total.
- **Ranking:** categories and merchants are ranked by amount separately in
  each currency and every limit applies per currency (amounts in different
  currencies are not comparable, so one currency never crowds out
  another); lists are grouped by currency, largest first.
- **Coverage:** transaction count, earliest/latest date and uncategorized
  count for the window and filters; pending count = all the user's pending
  transactions of any date and account (not limited to the window or
  filters; figures leave pending transactions out unless
  `include_pending=true`); last import time; and whether balances are
  provider-synced (always false today: balances are tracked, not
  bank-verified).

## Comparisons

- **Period comparison** (`/analytics/compare`): both windows use the same
  filters and rules and are compared as totals (not per day), per
  currency. For every total and category: change = current − comparison;
  change in basis points = change ÷ |comparison|, so an increase is
  positive even from a negative base (for example a net cash flow below
  zero); omitted when the comparison is zero.
- **Previous period** (cash flow): the same number of days immediately
  before the window, disclosed as `previous_window`.

## Balances

- **Account balance:** sum of the account's ledger entries up to a date.
- **Assets:** sum of non-liability account balances per currency.
- **Liabilities:** amount owed on credit cards and loans (the negated
  balance), per currency.
- **Net worth:** assets − liabilities (tracked, not verified).

## Budgets

- **Spent:** net expense counted by the budget's type and allocations within
  the period (transfers and income never count; refunds reduce spending;
  group expenses count the personal share).
- **Limit:** base limit + rollover in; **remaining** = limit − spent;
  **percent** = spent ÷ limit (basis points).
- **Pace:** expected-by-now = limit × elapsed days ÷ total days; projected =
  spent × total days ÷ elapsed days; pace is `under_pace`, `on_track`,
  `ahead_of_pace` or `over_budget`.

## Planning

- **Recurring monthly equivalent:** fixed rule amount × cycles per year ÷ 12
  (daily 365, weekly 52, biweekly 26, monthly 12, bimonthly 6, quarterly 4,
  semiannual 2, yearly 1, custom by unit), rounded half away from zero.
  Variable-amount rules are counted but not summed. Next 30 days = open
  occurrences due in the next 30 days.
- **Subscription cost:** monthly = price × cycles per year ÷ 12; annual =
  price × cycles per year. Paused subscriptions are excluded from totals.
- **Goal saved:** starting amount + recorded and verified contributions −
  withdrawals; planned contributions are not counted. **Progress** = saved ÷
  target (basis points). **Required per month/week** = remaining ÷ whole
  months/weeks left (rounded up). **Recent pace** = net counted contributions
  in the last 90 days ÷ 3.

## Conversion

- Rates are observations (base, quote, rate, source, timestamp). A converted
  view uses the latest rate on or before the end of the window's last day in
  the user's time zone (a day may last 23 or 25 hours) — the user's manual
  rate first, then provider rates, then the inverse pair (policy code
  `latest_on_or_before` with the date as a parameter).
- A manual rate entered for a date (no time) is dated the start of that day
  in the user's time zone, so it applies to conversions of that day.
- Each component (income, gross expense, refunds) is converted and rounded
  half away from zero; net figures are derived from the converted
  components. Every rate used is disclosed, and currencies without a rate are
  listed as not included.
- Historical rates are never rewritten; a new observation only affects
  conversions dated after it.

## Rounding

Half away from zero at the target currency's minor unit (ISO 4217 exponent:
0 for JPY, 2 for INR/USD/EUR, 3 for BHD/KWD). The exact rounding delta is
reported where a conversion is shown.
