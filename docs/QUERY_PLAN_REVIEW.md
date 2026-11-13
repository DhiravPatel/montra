# Montra — Query Plan Review

Requirement **DB-005** ("No N+1/unbounded queries; pagination; plan review"). This is a read-only review of the
plans for the high-volume read endpoints, run on 2026-11-13 against the local dev database after the demo seed
(`backend/cmd/seed`). Nothing was created, changed or analyzed: every statement ran inside `begin read only; … rollback;`,
and only SELECTs were explained. The fixes R1–R3, R-A, R-B and R-F were applied the same day; see [Applied](#applied-2026-11-13)
for the before and after measurements.

## Summary

| # | Query | Verdict |
|---|-------|---------|
| 1a | Transaction list (`finance.ListTransactions`) | **OK at dev volume.** Cursor pages already use an Incremental Sort. Re-check the full sort on page 1 at staging (R4) |
| 1b | Global search, transactions section (`search.Search`) | **Fixed (R-A).** It scanned the whole `transactions_user_category_idx` across all users; now 188 instead of 1,077 buffers |
| 2 | Dashboard summary (`analytics.Summary`) | **OK** |
| 2 | Dashboard planning (`analytics.Planning`) | **Mostly OK.** Its budgets part inherits the 6a problem, and it runs many statements per request (N+1, R-E) |
| 3 | Analytics distributions (categories, merchants, accounts) | **OK** |
| 4 | Notifications list and unread count | **OK.** The generic-plan cursor caveat is fixed (R-F) |
| 5a | Group expenses list (`groups.ListExpenses`) | **Fixed (R1).** It ran a full seq scan of `transactions` for every expense row; now an index lookup |
| 5b | Group balances (`groups.Balances`) | **OK** |
| 6a | Budget list (`budgets.List`, the id query) | **Fixed (R-B, R3).** It seq scanned all budgets and called `budget_access()` per row; now 11 instead of 1,222 buffers |
| 6b | Budget progress (load, spend, snapshots, alerts) | **OK per budget.** It is N+1 across budgets (R-E) |

## Method

- **Postgres:** 18.3 (Homebrew, aarch64). The database is `montra_dev`, the schema is `montra`, and the review date is 2026-11-13.
  Migrations are applied through `20261113000030`. Migrations 029 (`jobs` index) and 030 (`goals.achieved_by`) touch none of the reviewed tables.
- **Role and RLS:** I connected as `montra_app` (via `DATABASE_URL` in `backend/.env.local`; `rolbypassrls = f`, `rolsuper = f`).
  Each run reproduces `database.withTx` (`backend/internal/platform/database/database.go`):
  `select set_config('montra.user_id', '<uuid>', true), set_config('search_path', 'montra, extensions', true)`
  inside a read-only transaction. It also sets `set local timezone = 'UTC'`, the pool's runtime parameter. RLS therefore applies
  exactly as in production, and the plans show the policy quals (`user_id = current_user_id()`, `is_group_member(...)`, `budget_access(...)`).
- **Parameters:** The SQL was copied from the Go code and run with `PREPARE …; EXPLAIN (ANALYZE, BUFFERS) EXECUTE …`.
  pgx uses cached prepared statements by default (`DATABASE_SIMPLE_PROTOCOL=false`), so the first executions get custom plans.
  Where it matters, the generic plan was also captured with `set local plan_cache_mode = force_generic_plan`.
- **Diagnostics:** Runs with `set local enable_seqscan/enable_sort/enable_bitmapscan = off` are labeled **diagnostic**.
  They show which index the planner *can* use and are not the real plans.
- **Demo seed data:**
  - `demo.asha@example.com` (`61de2640…`): 64 transactions over 2026-07-16..2026-11-13 in 3 accounts (55 with a merchant, 55 with a category),
    9 notifications, and the budget "Groceries this month" (`706d258e…`, category, monthly, INR, 1 allocation `f7a29158…`) with an alert.
    Asha is used for every section except group expenses.
  - Asha is also a member of the demo group "Demo Flat" (`36c0d5e6…`: 3 expenses, 1 settlement), used for 5a and 5b.
  - `demo.ravi` and `demo.meera` have 10 transactions each and were not needed separately.
- **Earlier non-demo results kept where heavier:** group `b00e16f8…` (18 expenses, the most per group) for 5a, and the group budget on `b2ac55e4…` for 6b.
- **Stale statistics:** the demo rows were inserted after the last autoanalyze (`n_mod_since_analyze`: transactions 108, notifications 188,
  budgets 54), and this review may not run ANALYZE. Row estimates for demo rows are therefore 1–2 against 7–64 actual.

### Data volume (`pg_stat_user_tables.n_live_tup`, after the seed)

| Table | Rows | Size | | Table | Rows | Size |
|---|---:|---:|---|---|---:|---:|
| categories | 29,930 | 12 MB | | group_expense_payers | 401 | 208 kB |
| account_ledger_entries | 2,371 | 800 kB | | group_expenses | 398 | 512 kB |
| transactions | 1,994 | 1.5 MB | | group_members | 393 | 264 kB |
| notifications | 1,628 | 1.2 MB | | groups | 206 | 112 kB |
| users | 1,359 | 824 kB | | budgets | 197 | 160 kB |
| group_expense_shares | 787 | 312 kB | | settlements | 46 | 80 kB |
| financial_accounts | 667 | 488 kB | | transaction_attachments | 78 | 56 kB |
| merchants | 534 | 416 kB | | budget_allocations / transaction_tags | 4 / 14 | – |

**Caveat:** these volumes are tiny. The heaviest user has 64 transactions, so the planner sorts everything in memory and sometimes prefers
seq scans that would flip at scale. The verdicts below separate **what the plans show now** from **what to re-check at staging volume**.
A sequential scan matters here only when it is over rows outside the caller's scope, which is what makes findings 1b, 5a and 6a grow with the size of the whole table.

## 1. Transactions

### 1a. Transaction list (cursor-paginated)
- **Source:** `backend/internal/finance/search.go: ListTransactions` with `applyFilter`. The select list is `txSelect` in `finance/transactions.go`.
- **SQL shape:** `txSelect` (join `financial_accounts`, left join `categories` and `merchants`, plus 5 correlated subqueries per row: refunded total,
  attachment count, tags jsonb, group id)
  `where t.user_id = $1 and t.deleted_at is null [and (t.local_date, t.created_at, t.id) < ($d,$c,$id)] order by t.local_date desc, t.created_at desc, t.id desc limit $n+1`
- **Params:** Asha, limit 51. Page 2 uses the cursor from row 50 `(2026-09-01, …, cbf16317…)`. Variants: `q=%dinner%` over last_90_days and `include_shared=true`.

| Variant | Plan | Buffers | Exec |
|---|---|---:|---:|
| page 1 | Asha's 3 accounts (RLS BitmapOr) → per account BitmapAnd `transactions_user_category_idx` and `transactions_account_date_idx` (loops=3) → **Sort of all 64 rows** → LIMIT 51 | 526 | 1.6 ms |
| page 1, generic plan | same shape, `user_id = $1` | 514 | 1.1 ms |
| page 2 (cursor) | **Index Scan `transactions_user_date_idx`, Index Cond `user_id AND local_date <= '2026-09-01'`**; the ROW comparison stays in the Filter → **Incremental Sort (presorted `local_date`)** | 182 | 0.6 ms |
| `q=%dinner%`, 90 days | Bitmap `transactions_user_category_idx` (`user_id` plus the `local_date` range; the middle `category_id` column is skipped) → 61 rows → ilike filter keeps 13 → Sort | 624 | 1.0 ms |
| `include_shared` | same as page 1 | 508 | 1.0 ms |

- **Per-row subqueries:** they run only for emitted rows (`transactions_original_idx`, `transaction_tags_pkey`, `group_expenses_pkey`, `settlements_pkey`).
  `transaction_attachments` (78 rows) is seq scanned per row; the diagnostic switches to `transaction_attachments_key`.
- **Diagnostic (sort and bitmap off):** Index Scan on `transactions_user_date_idx (user_id, local_date desc, id desc)` followed by an Incremental Sort.
  No existing index yields the full `(local_date, created_at, id)` order (646 buffers).
- **Verdict:** OK now. Page 1 sorts *all* of a user's matching rows before the LIMIT, and the cursor bounds only `local_date`. See R4.

### 1b. Global search, transactions section
- **Source:** `backend/internal/search/search.go: Search` (the `want("transactions")` block).
- **SQL shape:** `from transactions t left join merchants m … where t.deleted_at is null and (t.user_id = $1 or exists (shared-account check))
  and (t.description ilike $2 or t.notes ilike $2 or m.name ilike $2) order by t.local_date desc, t.created_at desc limit $3`
- **Params:** Asha, `%dinner%`, limit 5.
- **Plan:** It does an **Index Scan on `transactions_user_category_idx` with no Index Cond**, which walks the entire partial index (every user's
  non-deleted rows). The user and RLS conditions are only a Filter, so **Rows Removed by Filter: 1,846** for 64 kept (cost estimate 31,566).
  It adds a **Seq Scan on `merchants`** (522 rows removed, 12 kept, materialized; join filter removed 439) and a top-N heapsort.
  Total: **1,073 buffers**, 1.9 ms. The `OR exists(...)` keeps the `user_id` equality from becoming an index condition.
  The diagnostic with seqscan off is no better (1,522 buffers).
  The earlier non-demo run had the same shape (1,799 rows removed, 1,057 buffers).
- **Verdict:** **Needs a change.** The cost grows with the total size of `transactions` across all users, not with the caller's data. See R-A.
  The `transactions_description_trgm` index cannot help either, because the match is ORed with `notes` and `m.name` (`idx_scan = 0`).

## 2. Dashboard

### Summary
- **Source:** `backend/internal/analytics/dashboard.go: Summary`. It calls `balances`, `cashFlow`, `series`, `categories(rollup, 8)`,
  `merchants(5)` and `coverage`, then `cashFlow` for the previous window, all from `analytics.go`. After that it calls `ListTransactions(limit 8)` (1a) separately.
- **Shared scope:** `t.user_id = $1 and t.deleted_at is null and t.local_date between $2 and $3 and t.status = 'posted' and a.include_in_overview`.
- **Params:** Asha, this_month = 2026-11-01..2026-11-30 (8 rows in range, 7 posted), overview_only.

| Query | Access path | Buffers | Exec |
|---|---|---:|---:|
| cashFlow (group by currency) | `transactions_user_category_idx` (`user_id` plus the `local_date` range) → join to the user's accounts → GroupAggregate | 41 | 0.21 ms |
| series (CTE + generate_series day buckets) | same scan; CTE materialized (used twice), Hash Left Join to 30 buckets | 38 | 6.5 ms first / 0.2 ms second execution |
| categories rollup top 8 | same scan → `categories_pkey` lookups → GroupAggregate → WindowAgg | 74 | 0.36 ms |
| merchants top 5 | `transactions_user_merchant_idx` (`user_id` plus the `local_date` range) → `merchants_pkey` | 59 | 0.24 ms |
| balances | `financial_accounts_user_idx` → per account sum via `ledger_account_date_idx`/`ledger_user_idx` | 24 | 0.18 ms |
| coverage | same scan plus the pending count on `transactions_user_category_idx (user_id)` | 49 | 0.22 ms |

- **Series timing:** the first-execution time of `series` is the startup of the bucket Hash Left Join, not the transaction scan (0.1 ms).
  A second execution in the same session took 0.2 ms.
- **Diagnostic (cashFlow with seqscan and bitmap off):** Index Scan on `transactions_user_category_idx` with the same Index Cond (31 buffers).
- **Verdict:** OK. Each part is an index range scan bounded by user and date.

### Planning
- **Source:** `backend/internal/analytics/dashboard_planning.go: Planning`. It is a composite: `budgets.List` (6a and 6b), `recurring.Calendar`,
  `goals.List`, `groups.List`, `budgets.ListAlerts` and `analytics.Recurring`, each in its own transaction.
- **groups.List** (`groups/groups.go: List`, `groupCols` with `my_net` subquery), run for Asha: `group_members_user_idx` → `groups_pkey`.
  Per group: member count via `group_members_key`, and `my_net` via `group_expense_payers_user_idx` / `group_expense_shares_user_idx`
  `(group_id, user_id)` plus `settlements_group_idx`. 77 buffers, 0.47 ms. **OK.**
- **budgets.ListAlerts** (`budgets/alerts.go`): `budget_alerts_user_idx (user_id, status, triggered_at desc)` → Incremental Sort on `id`.
  4 alerts, 16 buffers, 0.06 ms. **OK.**
- **Verdict:** The planning endpoint inherits finding 6a, and it issues many statements per request (R-E). `recurring.Calendar` and `goals.List` were not explained.

## 3. Analytics distributions

- **Source:** `backend/internal/analytics/analytics.go: categories`, `merchants` and `balances` (the `/analytics/categories`, `/merchants` and `/accounts` endpoints).
- **Run:** categories with no rollup over **this_year** (2026-01-01..12-31), limit 1000, plus the merchants and balances queries from section 2.
- **Plan:** `transactions_user_category_idx` with the year range (64 matched, 51 kept by type) → `categories_pkey` → GroupAggregate → WindowAgg →
  Incremental Sort. 233 buffers, 0.58 ms.
- **Verdict:** OK. Every distribution is bounded by `user_id` and the date window, and the per-currency `row_number()` LIMIT runs after aggregation.

## 4. Notifications

- **Source:** `backend/internal/notifications/service.go: List` and `UnreadCount`.
- **SQL shape:** `where user_id = $1 and ($2::boolean = false or read_at is null) and (case when $3 then archived_at is not null else archived_at is null end)
  and ($4 = '' or category = $4) and (expires_at is null or expires_at > now()) and ($5::timestamptz is null or (created_at, id) < ($5, $6))
  order by created_at desc, id desc limit $7`
- **Params:** Asha (9 notifications), limit 31. Variants: inbox, cursor page 2 (from row 5), and unread-only.

| Variant | Plan | Buffers | Exec |
|---|---|---:|---:|
| inbox, page 1 | **ordered Index Scan `notifications_user_idx (user_id, created_at desc)` → Incremental Sort** (presorted `created_at`, `id` is the tie-breaker) | 17 | 0.24 ms |
| page 2 (custom plan) | `notifications_user_idx` with `Index Cond: user_id AND created_at <= $cursor` | 4 | 0.10 ms |
| unread only | `notifications_user_idx`; the planner did not pick `notifications_unread_idx` with stale stats (it did for the non-demo user) | 8 | 0.08 ms |
| **generic plan**, page 1 | Bitmap `notifications_user_idx (user_id = $1)`; the whole `($5 IS NULL OR ROW(...) < ROW($5,$6))` stays in the **Filter** | 7 | 0.13 ms |
| unread count | `notifications_user_idx` → Aggregate | 8 | 0.06 ms |

- **Verdict:** OK. Caveat: the generic plan, which pgx's statement cache can settle on after 5 executions, cannot use the cursor as an index bound.
  At scale, deep pages would then read from the newest row. See R-F and R5.

## 5. Groups

### 5a. Group expenses list
- **Source:** `backend/internal/groups/expenses.go: ListExpenses`, which calls `expenses`.
- **SQL shape:** `from group_expenses e where e.group_id = $1 and e.status <> 'deleted' [and (e.expense_date, e.created_at, e.id) < (…)]
  order by e.expense_date desc, e.created_at desc, e.id desc limit 51`. It has 3 correlated subqueries per row, including
  `(select t.id from transactions t where t.group_expense_id = e.id and t.user_id = montra.current_user_id() and t.status <> 'voided' limit 1)`.
- **Plan:** The outer scan is good: an ordered **Index Scan on `group_expenses_group_page_idx`** with no Sort, and on page 2 the cursor `ROW(...) < ROW(...)`
  is an Index Cond. But the `my_transaction_id` subplan is a **Seq Scan on `transactions` per expense row**:

| Group | Rows | Seq-scan loops × rows removed | Seq-scan buffers / total | Exec |
|---|---:|---|---:|---:|
| Demo Flat `36c0d5e6…` (as Asha), page 1 | 3 | 3 × 1,997 | 204 / 385 | 3.1 ms |
| Demo Flat, page 2 (cursor) | 1 | 1 × 1,997 | – / 92 | 0.6 ms |
| `b00e16f8…` (18 expenses; earlier run) | 18 | 18 × 1,910 | 1,224 / 1,671 | 8.6 ms |

  With `enable_seqscan = off` it is still a Seq Scan, because **no index on `transactions` can serve `group_expense_id`**. The `user_id` indexes are
  all partial (`deleted_at is null` or `merchant_id is not null`) and this predicate does not imply them.
  Payers and shares use `group_expense_payers_pkey` / `group_expense_shares_pkey (expense_id, …)`.
- **Verdict:** **Needs an index.** The cost is (page size) × (total `transactions` rows). See R1.
  The same pattern appears in `groups/settlements.go:78` (`t.settlement_id = s.id`), `settlements.go:343/362`, `jobs.go:418/478` and
  `expenses.go:1162`. Those were not explained separately, but the same indexes are missing (R1, R2).

### 5b. Group balances
- **Source:** `backend/internal/groups/balances.go: balances`, which runs the payers/shares `union all`, the settlements query and the disputed count.
- **Plan (Demo Flat):** the union scans `group_expenses_group_page_idx (group_id)`, then a nested loop into the payers and shares pkeys, then a Sort.
  86 buffers, 0.25 ms. Settlements: `settlements_group_idx`, 11 buffers. Disputed count: 3 buffers.
  The 18-expense group took 397 buffers and 0.79 ms, mostly per-row `is_group_member()` RLS checks.
- **Verdict:** OK. It reads every non-deleted expense of the group by design, because balances are derived. That is bounded by group size, not by the table.

## 6. Budgets

### 6a. Budget list, id query
- **Source:** `backend/internal/budgets/budgets.go: List`. It runs `select id from budgets where ($1 or status <> 'archived') order by status, created_at`,
  with **no user predicate** and relies on RLS (`owner_user_id = current_user_id() OR budget_access(id) IS NOT NULL`).
- **Plan (Asha, includeArchived = false):** **Seq Scan on `budgets`, all 197 rows.** For every row the filter calls `budget_access(id)`, a SECURITY DEFINER
  SQL function that cannot be inlined and does its own lookups. Rows Removed by Filter: 196, **1,464 buffers**, 9.5 ms.
  With seqscan off it is still a Seq Scan (1,222 buffers), because no index applies.
- **Verdict:** **Needs a rewrite.** Cost is O(all budgets in the system) × the per-row function calls.
  Adding the same membership conditions as one OR to the WHERE clause did **not** help (earlier diagnostic: still a Seq Scan, 1,237 buffers).
  A UNION of the three access paths did (R-B).

### 6b. Budget progress (per budget)
- **Source:** `budgets.go: load` (`budgetSelect` by id, allocations, members), `progress`, `spend` and `personalFilter`, `rolloverIn`, plus the group branch of `spend`.
- **Params:** "Groceries this month" `706d258e…` (refunds_restore, count_group_shares), period 2026-11-01..30, allocation category `f7a29158…`.

| Query | Plan | Buffers | Exec |
|---|---|---:|---:|
| budgetSelect by id | `budgets_pkey`, `user_preferences_pkey` | 7 | 0.08 ms |
| spend, whole budget (category type) | `transactions_user_category_idx` (`user_id` plus the period) → Semi Join on `budget_allocations_budget_idx`; `categories_pkey` for the include_in_budgets/parent checks | 71 | 0.36 ms |
| spend, allocation | same range scan; `categories_parent_idx` | 17 | 0.08 ms |
| snapshot lookup | `budget_period_snapshots_pkey` | 2 | 0.03 ms |
| allocations / members | `budget_allocations_budget_idx` / `budget_members_pkey` | 4 / 1 | <0.07 ms |
| group budget spend (earlier run, group `b2ac55e4…`) | `group_expenses_group_page_idx (group_id, expense_date range)`; `is_group_member()` filter | 149 | 0.89 ms |

- **Verdict:** Each statement is OK. The endpoint is N+1: `List` loads each budget with at least 6 statements (select, allocations, owner name, members,
  spend, plus one spend per allocation, and snapshot and rollover reads when rollover is on). Each load also **upserts `budget_period_snapshots`**,
  a write on a read path. `List` runs in `WithUserTx`, not a read-only transaction. See R-E. The upsert was not explained, because this review explains SELECTs only.

## Cross-cutting observations

1. **RLS helpers are SECURITY DEFINER SQL functions** (`is_group_member`, `budget_access`, `group_role`, `goal_access`; `STABLE`, not leakproof).
   They cannot be inlined, so every row they filter costs a function call with its own index lookups. They are cheap when an index narrows the rows
   first (5b, 6b) and expensive when it does not (6a).
2. **The shared-account policy arm** (`financial_accounts.app_accounts_group_read`, `transactions.app_transactions_group_read`) appears in every
   transaction plan as `BitmapOr … financial_accounts_group_idx (group_id IS NOT NULL)` plus a hashed SubPlan over all group-linked accounts,
   calling `is_group_member()` per account. Dev still has **0** accounts with `group_id` set (the demo seed creates none), so the cost here is nil.
   At staging it is O(all shared accounts in the system) per query. See R-D and R6.
3. **Row estimates on `transactions` are low** (est 1 vs 64 actual) wherever RLS quals are ORed with user quals. That is made worse here by the stale stats.
   At scale it can push the planner into nested loops. Watch for it at staging.
4. **Unused indexes in dev:** `transactions_description_trgm`, `transactions_group_idx` and `transactions_transfer_idx` have `idx_scan = 0`.
   `group_expenses_group_date_idx` is a prefix-equivalent of `group_expenses_group_page_idx` for most lookups. Do not drop anything based on dev stats.

## Recommendations

**Status (2026-11-13):** R1–R3 (migration `20261113000031_query_plan_indexes`), R-A, R-B and R-F are **done**, and R-C needed nothing
beyond R1. R4, R5 and R6 wait for staging volume, R-D is a policy change that waits for R6, and R-E is open (see [Applied](#applied-2026-11-13)).
Use `create index concurrently` outside a transaction on populated databases (the migration's header gives the production rollout).

### Indexes

| # | Priority | Statement | Evidence |
|---|---|---|---|
| R1 | **Done** (was High) | `create index concurrently transactions_group_expense_idx on montra.transactions (group_expense_id) where group_expense_id is not null;` | 5a: a seq scan per expense row (demo: 204 of 385 buffers; 18-expense group: 1,224 of 1,671). It also serves the `ON DELETE SET NULL` FK action from `group_expenses`. |
| R2 | **Done** (was High) | `create index concurrently transactions_settlement_idx on montra.transactions (settlement_id) where settlement_id is not null;` | Same correlated pattern in the settlements list (`settlements.go:78`) and jobs. No index exists. The same FK reasoning applies. Inferred, not explained. |
| R3 | **Done** (was Medium, with R-B) | `create index concurrently budget_members_user_idx on montra.budget_members (user_id);` | The R-B rewrite looks up memberships by `user_id`. Today that lookup relies on a PG18 skip scan of `budget_members_pkey (budget_id, user_id)`. |
| R4 | Re-check at staging | `create index concurrently transactions_user_page_idx on montra.transactions (user_id, local_date desc, created_at desc, id desc) where deleted_at is null;` (would replace `transactions_user_date_idx`) | 1a: page 1 sorts all of the user's rows, and page 2 already shows Incremental Sort with only `local_date` bounding the cursor. Mirrors the existing `group_expenses_group_page_idx`. |
| R5 | Re-check at staging | `create index concurrently notifications_user_page_idx on montra.notifications (user_id, created_at desc, id desc);` (would replace `notifications_user_idx`) | 4: the real plan is an ordered `notifications_user_idx` scan plus Incremental Sort on `id`, and the cursor bounds only `created_at`. Low priority. |

Already present, so not recommended: `(user_id, local_date)` and `(user_id, category_id, local_date)` on transactions, `(account_id, local_date)`,
`(user_id, merchant_id, local_date)`, `(group_id, expense_date, created_at, id)`, `notifications (user_id, created_at)` and its unread partial index,
`budget_alerts (user_id, status, triggered_at)`, and `(group_id, user_id)` on payers and shares.

### Query rewrites

- **R-A, global search (1b). Done.** Join the visible accounts the same way `ListTransactions` does (`join financial_accounts a on a.id = t.account_id`,
  with the shared check on `a`), instead of `t.user_id = $1 OR exists(...)`. **Diagnostic run for Asha:** the scan drives from her accounts, and
  `merchants` is read via `merchants_pkey`: **188 buffers, 0.42 ms vs 1,073 buffers, 1.9 ms**.
  Confirm the semantics: the inner join requires the account to be visible, which `ListTransactions` already assumes.
- **R-B, budget list (6a). Done.** Select candidate ids explicitly and let RLS still filter them:
  `select … from budgets where owner_user_id = current_user_id() and status <> 'archived' union select … from budget_members bm join budgets b …
  where bm.user_id = current_user_id() … union select … from group_members gm join budgets b on b.group_id = gm.group_id where gm.user_id = current_user_id() and gm.status = 'active' …`.
  **Diagnostic run for Asha:** `budgets_owner_idx` plus `budget_members_pkey` plus `group_members_user_idx` → `budgets_group_idx`: **24 buffers, 0.57 ms vs 1,464 buffers, 9.5 ms**.
  Access is unchanged, because RLS still applies and the union is a superset of what RLS admits.
- **R-C, group expenses list (5a). Done by R1:** no SQL change was needed.
- **R-D, shared-account policies:** Consider expressing the group arm as
  `group_id in (select group_id from group_members where user_id = current_user_id() and status = 'active')`, a single hashed subplan,
  instead of calling `is_group_member(group_id)` per group-linked account. This is a policy change: it needs a migration and the RLS test suite. Decide after R6.
- **R-E, N+1 on dashboard planning and budgets (open):** `budgets.List` issues at least 6 statements per budget plus a snapshot upsert. `Planning` chains six
  service calls, each in its own transaction. Options: batch the per-budget reads (`where budget_id = any($ids)`), skip the snapshot upsert
  when nothing changed, and run `List` read-only when no snapshot is due. Measure statements per request at staging before choosing.
- **R-F, generic plans and optional cursors. Done.** `notifications.List` (`$5 IS NULL OR (created_at, id) < ($5, $6)`) and `budgets.ListAlerts`
  (`alerts.go:231`, same pattern) use one SQL text for the first page and later pages. The generic plan keeps the cursor in the Filter (shown in 4).
  Build two SQL strings, with and without the cursor, as `ListTransactions` and `ListExpenses` already do.

### Re-check at staging volume

- **R6:** Re-run 1a, 1b, 2 and 5a with a realistic distribution (≥10k transactions per heavy user, ≥100k total, and households with shared accounts,
  which the demo seed does not create). Confirm whether page 1 of the list becomes a Sort over all of a user's rows (R4) and how the shared-account
  BitmapOr arm scales (R-D).
- Run after ANALYZE, so that estimates reflect the data; dev stats predate the seed.
- Compare generic and custom plans for paginated endpoints after warm-up (`pg_stat_statements` plus `auto_explain` with `log_min_duration`).
- Check `idx_scan` for the unused or overlapping indexes before dropping any. Track statements per request for `/dashboard/planning` and `/budgets` (R-E).

## Applied (2026-11-13)

**What changed**

| # | Change | Where |
|---|---|---|
| R1, R2, R3 | `transactions_group_expense_idx (group_expense_id) where not null`, `transactions_settlement_idx (settlement_id) where not null`, `budget_members_user_idx (user_id)` | `supabase/migrations/20261113000031_query_plan_indexes.sql` |
| R-A | The transactions section joins `financial_accounts a` and checks the shared arm on `a` (`t.user_id = $1 or (a.shared_with_group and a.group_id is not null and is_group_member(a.group_id))`) | `backend/internal/search/search.go` |
| R-B | The id query is a `union` of owner (`budgets_owner_idx`), budget member (`budget_members_user_idx`) and active group member (`group_members_user_idx` → `budgets_group_idx`) candidates; RLS still filters every row | `backend/internal/budgets/budgets.go: List` |
| R-F | Two SQL texts each, with and without the cursor | `backend/internal/notifications/service.go: List`, `backend/internal/budgets/alerts.go: ListAlerts` |

- **The migration is not `concurrently`.** `cmd/migrate` does support the `-- montra:no-transaction` marker
  (`internal/platform/migrate/migrate.go`), but it sends the whole file as one simple-protocol query. PostgreSQL runs a multi-statement
  query as an implicit transaction block, so `create index concurrently` fails there ("cannot run inside a transaction block";
  verified on dev with a temp table). The file therefore uses plain `create index if not exists`, and its header gives the production
  rollout: build each index with `create index concurrently if not exists` from psql first, check `pg_index.indisvalid`, then run the
  migration, which finds the indexes and only records itself. On dev it took 491 ms.
- **R-A semantics.** The inner join needs the transaction's account to be visible. Transactions are only ever written to their owner's own
  accounts (every create path checks `financial_accounts where id = $1 and user_id = $2`), and a shared transaction is visible only through
  its shared account, so the join drops nothing RLS would show. `TestGlobalSearchIsScopedToAuthorizedData` and
  `TestSearchPlanningSectionsAndSort` pass unchanged. Keeping the old `exists(...)` with the join gave the same 188 buffers but adds a second
  hashed subplan, so the check moved onto `a`.
- **R-B access.** The union is a superset of `app_budgets_select` (owner, any `budget_members` row, active member of the budget's group,
  which covers the group-admin arm). The archived filter and the `order by status, created_at` are unchanged and are pushed into each arm.
  The RLS suite and the budget tests, including `TestGroupBudgetVisibleToViewerMember`, pass.
- **R-F coverage.** No test paged either list with a cursor, so `TestNotificationCursorPagingMatchesUnpagedList` and
  `TestBudgetAlertCursorPagingMatchesUnpagedList` were added (pages of 1, 2 or 3 must equal the unpaged list, with and without the
  category or budget filter). Both pass against the old and the new SQL.
- **R-E was not done.** Skipping the snapshot upsert when nothing changed would also stop `computed_at = now()` from advancing.
  `computed_at` is shown to collaborators as `as_of` ("when the owner's totals were last computed"), and `rolloverIn` compares it with the
  latest `transactions.updated_at` to decide whether a closed period's snapshot is still fresh. A conditional upsert would change the
  `as_of` users see and make that freshness check recompute every time, so it is not a performance-only change.
  Batching the per-budget reads is still open; measure statements per request at staging first.

**Method.** The same as above: `montra_app` under RLS, `begin read only; … rollback;`, `PREPARE` the SQL from the Go code (after the change
for "after") and `EXPLAIN (ANALYZE, BUFFERS) EXECUTE` after one warm-up execution. Buffers are the top node's `shared hit`
(deterministic). Each variant ran 9 times and the table gives the median and the minimum execution time. The host was busy (another agent
was running builds; load average 14–115), so the first timing pass was discarded and only buffers should be compared across days.
Statistics are still stale (no ANALYZE was run; `create index` does not analyze the table). For 1b, 4 and 6a the old SQL was explained in the
same session as the new; for 5a, "before" is the pass taken just before the migration was applied.

| # | Query (user) | Before: buffers, median / min | After: buffers, median / min | Plan change |
|---|---|---:|---:|---|
| 1b | Global search, `%dinner%`, limit 5 (Asha) | 1,077 · 2.09 / 1.97 ms | **188** · 0.39 / 0.23 ms | Full `transactions_user_category_idx` walk with 1,850 rows removed by filter, plus a seq scan of `merchants` → her 3 accounts (`financial_accounts_user_idx`), `transactions_account_date_idx` per account, `merchants_pkey` |
| 4 | Notifications, page 1 (Asha) | 8 · 0.05 / 0.03 ms | 8 · 0.06 / 0.03 ms | Unchanged: ordered `notifications_user_idx` |
| 4 | Notifications, page 2, custom plan | 4 · 0.05 / 0.03 ms | 4 · 0.03 / 0.03 ms | Unchanged: `Index Cond: user_id AND created_at <= cursor` |
| 4 | Notifications, page 2, **generic plan** | 7 · 0.03 / 0.03 ms | **4** · 0.03 / 0.03 ms | Bitmap on `user_id = $1` with `($5 IS NULL OR ROW(...) < ROW($5,$6))` in the Filter → `Index Cond: (user_id = $1) AND (created_at <= $5)` plus Incremental Sort |
| 5a | Group expenses, Demo Flat, 3 rows (Asha) | 270 · 1.90 ms | **69** · 0.27 / 0.21 ms | `my_transaction_id`: seq scan of `transactions` per row → `transactions_group_expense_idx` (3 buffers for 3 loops) |
| 5a | Group expenses, `b00e16f8…`, 18 rows (a member) | 1,513 · 9.31 ms | **352** · 1.15 / 0.85 ms | Same; the subplan is now 21 buffers for 18 loops (was 1,224 in the review). The rest is the payers and shares aggregates |
| 6a | Budget list id query (Asha, not archived) | 1,222 · 5.30 / 4.92 ms | **11** · 0.18 / 0.14 ms | Seq scan of all 197 budgets with `budget_access(id)` per row → `budgets_owner_idx`, `budget_members_user_idx`, `group_members_user_idx` → `budgets_group_idx` |

- 5a "before" times are a median of 5 from the pre-migration pass. The review's own figures were 385 buffers / 3.1 ms and 1,671 / 8.6 ms.
- 6a with R-B alone (before R3) was 10 buffers: the members arm used a skip scan of `budget_members_pkey`. Asha has no budget memberships, so
  R3 shows no gain here; it bounds that arm by `user_id` at scale.
- 4 is OK either way at dev volume. The fix matters for deep pages once pgx settles on the generic plan (R5 is still open).

## How to re-run

```bash
# From the repo root. Read-only: every run is wrapped in a read-only transaction and rolled back.
set -a; . backend/.env.local; set +a          # DATABASE_URL for montra_app (never print it)
uid=$(psql -h localhost -U montra_owner -d montra_dev -XAtc \
      "select id from montra.users where email = 'demo.asha@example.com'")   # demo user to explain as
{
  echo "begin read only;"
  echo "set local timezone = 'UTC';"
  echo "select set_config('montra.user_id', '$uid', true), set_config('search_path', 'montra, extensions', true);"
  cat my_query.sql                            # PREPARE q(...) AS <SQL from Go>; EXPLAIN (ANALYZE, BUFFERS) EXECUTE q(...);
  echo "rollback;"
} | psql "$DATABASE_URL" -X -q -P pager=off
# Fallback without the app password: psql -h localhost -U montra_owner -d montra_dev, then add `set local role montra_app;`
# after `begin`. Generic plan: `set local plan_cache_mode = force_generic_plan;` before EXECUTE.
```
