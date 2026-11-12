# Montra — API Conventions

The contract is generated from the Go handlers (ADR-005) and committed at
`contracts/openapi/montra.v1.json`. Regenerate with
`cd backend && go run ./cmd/openapi -out ../contracts/openapi/montra.v1.json`;
CI and `go run ./cmd/openapi -check` fail on drift. Web types
(`web: pnpm gen:api`) and Dart models (`mobile: dart run tool/gen_api.dart`)
are generated from that file and have their own drift checks.

## Base path, versioning, clients

- Base path `/api/v1`. Breaking changes require `/api/v2`; v1 evolves only
  additively.
- Every request should send `X-Montra-Client: web | android | ios` and
  `X-Client-Version`. Web sessions use HttpOnly cookies; mobile clients
  receive tokens in the response body and send `Authorization: Bearer`.
- Cookie-authenticated unsafe requests (POST/PUT/PATCH/DELETE) must send
  `X-CSRF-Token` (value from `csrf_token` in auth responses or the readable
  `montra_csrf` cookie).
- Every response carries `X-Request-ID`; the same value appears in
  `meta.request_id` or `error.request_id`.

## Envelopes

Success: `{"data": …, "meta": {"request_id", "timestamp", "next_cursor?"}}`.
Lists that paginate return `meta.next_cursor`; pass it back as `cursor`.

Error: `{"error": {"code", "message", "details": [{"field", "message"}], "request_id"}}`.
`message` is safe to show; `details[].field` uses `body.<field>`,
`query.<field>` or `path.<field>`. Clients branch on `code`, never on
`message` text or on the status alone.

## Money, dates, numbers

- Amounts in requests are exact decimal strings (`"1234.50"`) in the
  currency's minor-unit precision; responses return
  `{"amount_minor": 123450, "amount": "1234.50", "currency": "INR"}`.
  Floats are never accepted or returned for money.
- `GET /currencies` lists supported ISO 4217 codes with their exponent.
  Retired currencies (e.g. BGN, replaced by EUR on 2026-01-01) stay valid
  for history but have `selectable: false` and are rejected for new
  accounts, budgets, goals, subscriptions, recurring rules and preferences.
- Calendar dates are `YYYY-MM-DD` in the user's (or the record's) IANA time
  zone; instants are RFC 3339 UTC.
- Percentages are basis points (`percent_bp`, 10000 = 100 %).

## Idempotency and concurrency

- Financial writes require `Idempotency-Key` (8–128 chars, client
  generated). Retrying with the same key and body returns the original
  result with `Idempotent-Replayed: true`; the same key with a different
  body returns `IDEMPOTENCY_CONFLICT`; a retry while the first request is
  still running returns `IDEMPOTENCY_IN_PROGRESS`.
- Creates that a retry could duplicate take the key too: accounts,
  transactions (including transfers, refunds, duplicates and balance
  adjustments), bills, recurring rules, group expenses and settlements,
  receipts, statement imports, and payment-style actions (bill
  mark-paid, recurring occurrence actions, subscription payments, goal
  contributions, import confirm, receipt to transaction). The contract
  marks each of these with a required `Idempotency-Key` header parameter.
- Editable records carry `version`; updates must send it and get
  `VERSION_CONFLICT` when it is stale (reload and reapply).
- `PATCH` changes only the fields sent (budgets, bills, recurring rules,
  subscriptions, goals). A list sent replaces the whole list (`[]` empties
  it). Text fields are cleared with an empty string; other optional
  fields (references, numbers) are removed by naming them in `clear`
  (for example `"clear": ["payment_account_id"]`). Sending a value and
  clearing the same field is rejected.
- Lifecycle changes use explicit actions (`POST /bills/{id}/pause`,
  `resume`, `archive`, `restore`; the same for budgets, with `DELETE`
  archiving). An action that does not apply to the current status returns
  `DOMAIN_RULE_VIOLATION` with code `invalid_status_transition` and
  params `from` / `to`.

## Rate limits

`RATE_LIMITED` (429) and `LOGIN_THROTTLED` (429) include `Retry-After`
(seconds). Limits are fair-use protections, never paid tiers.

## Error codes

The `code` field is a closed enum in the contract (`ErrorObject.code`).

| Code | HTTP | Meaning / client action |
|---|---|---|
| `VALIDATION_ERROR` | 422 | Input invalid; show `details` per field |
| `BAD_REQUEST` | 400 | Malformed request |
| `UNAUTHENTICATED` | 401 | Access token missing/expired: refresh once (single shared refresh), retry once; if refresh fails, sign in |
| `MFA_REQUIRED` | 401 | Sign-in needs the second step (`mfa_token`), or re-auth needs a code / recovery code. Do not refresh |
| `MFA_CODE_INVALID` | 401 | Wrong code for a still-valid sign-in attempt; let the user retry |
| `MFA_CHALLENGE_EXPIRED` | 401 | Sign-in attempt expired or used up; start sign-in again |
| `REAUTH_REQUIRED` | 401 | Sensitive action needs recent re-authentication (`POST /auth/reauthenticate`), then retry. Do not refresh |
| `EMAIL_NOT_VERIFIED` | 403 | Offer to resend verification |
| `ACCOUNT_LOCKED` | 403 | Account locked; contact support / reset password |
| `FORBIDDEN` | 403 | Authenticated but not allowed |
| `CSRF_FAILED` | 403 | Missing/invalid CSRF token; re-read it from the session and retry once |
| `CONSENT_REQUIRED` | 403 | Feature needs a consent (e.g. location, AI) |
| `NOT_FOUND` | 404 | Missing or not visible to the caller (no existence leaks) |
| `CONFLICT` | 409 | State conflict (e.g. occurrence already handled) |
| `VERSION_CONFLICT` | 409 | Stale `version` |
| `IDEMPOTENCY_CONFLICT` | 409 | Key reused with a different request |
| `IDEMPOTENCY_IN_PROGRESS` | 409 | Same key still processing; retry later |
| `DUPLICATE` | 409 | Would duplicate a record or double-count a payment/contribution |
| `GONE` | 410 | Link/token expired or already used |
| `PAYLOAD_TOO_LARGE` | 413 | Body or file too large |
| `UNSUPPORTED_MEDIA_TYPE` | 415 / 422 | File type not allowed (422 when detected content differs from the declared type) |
| `DOMAIN_RULE_VIOLATION` | 422 | Business rule (e.g. refund above original, withdrawal above saved) |
| `RATE_LIMITED` | 429 | Wait `Retry-After` seconds |
| `LOGIN_THROTTLED` | 429 | Too many failed sign-ins; wait `Retry-After` or reset the password |
| `TIMEOUT` | 504 (499 if the client cancelled) | Retry later |
| `INTERNAL_ERROR` | 500 | Unexpected; report `request_id` |
| `SERVICE_UNAVAILABLE` | 503 | Dependency down; retry later |
| `STORAGE_UNAVAILABLE` | 503 | File storage not configured/unavailable |
| `PROVIDER_UNAVAILABLE` | 503 | External provider (captcha, AI, FX) unavailable |
| `FEATURE_NOT_CONFIGURED` | 503 | Optional integration not configured in this environment |

Three different codes share HTTP 401 on purpose (`UNAUTHENTICATED`,
`MFA_*`, `REAUTH_REQUIRED`): only `UNAUTHENTICATED` triggers a token
refresh.

## Auth endpoints notes

- Passwords: 10–128 characters (servers may be configured stricter), not a
  common password, not containing the email's local part, at least four
  distinct characters. Policy errors name the submitted field
  (`body.password` on register, `body.new_password` on reset/change).
- `POST /auth/refresh` accepts an empty body for web (cookie) sessions;
  mobile sends `{"refresh_token": …}`.
- `POST /auth/reauthenticate` accepts `password` plus `code` or a single-use
  `recovery_code` when two-step verification is on.
- A fresh sign-in counts as a re-authentication for the re-auth window.
- Captcha (`TURNSTILE_SECRET_KEY`) must stay disabled until the clients
  ship the widget.

## Social and groups notes

- **Discovery:** `GET /users/search?q=` finds a person only by their exact
  username (case-insensitive, a leading `@` ignored, 3+ characters);
  partial usernames find nobody. Only people who opted into username
  discovery are found: `discoverable_by_username` is off for new accounts
  (existing accounts keep their setting). The users section of
  `GET /search` follows the same rule. Results carry only display name,
  username, avatar and the caller's relationship. Blocked users look
  absent (404) to both sides. `PATCH /me {"username"}` also ignores a
  leading `@`. Social actions share the `social` rate limit (burst 15,
  ~30/min per user).
- **Friend requests:** `POST /friend-requests` answers 409 `CONFLICT` with
  `already_friends` or `request_pending` (you already asked them). If they
  already asked you, their request is accepted instead (201, `status:
  accepted`). The addressee's `allow_friend_requests` applies
  (`requests_closed`). The notification opens `/friends?tab=requests`.
- **Blocks and mutes:** `GET /blocks` and `GET /mutes` list your own
  blocks and mutes, newest first, with `created_at` and a cursor
  (`cursor`, `limit` ≤ 200, `meta.next_cursor`/`has_more`). People you
  blocked show their display name and username only. Profiles returned
  for a person (search, friends, requests, these lists) carry `muted` and
  `blocked_by_me` (your own actions; being blocked is never disclosed).
  Muting an unknown user answers 404.
- **Invitation links:** the token is returned once on creation and must be
  sent in a body (`POST /group-invitations/preview` / `accept` with
  `{"token": …}`), never in a URL path or query. Put it in the link's
  fragment (`https://…/join#token=…`). The preview returns `group_id`,
  `group_name`, `group_type`, `member_count`, `invited_by` (display name;
  username only when that person is discoverable or connected to you),
  `already_member` and `requires_approval`. Accepting a link answers 200
  with the group, or 202 with a pending join request when the group has
  `require_join_approval` (off by default; the admins approve it, and the
  request carries `invitation_id`). Username invitations are addressed to
  one person and always join directly; they are accepted or declined by
  ID. `POST /groups/{id}/members` and `kind: username` invitations take a
  `username` (people who opted into username discovery) or a `user_id`
  (your friends, even with discovery off); anyone else answers 404.
  Invitations carry `invitee` and `invited_by` minimal profiles. Links
  between people who blocked each other answer 410.
- **Group settings:** `PATCH /groups/{id}` changes only the fields sent
  (`""` clears text and dates); `version` is required. Every group in
  `GET /groups` carries `my_net`, the caller's balance (the same value as
  `my_net` in `GET /groups/{id}/balances`).
- **Non-members** get `404` for every group resource (existence is not
  disclosed).
- **Expenses:** `POST /groups/{id}/expenses` is idempotent. `split_method`
  values: `equal`, `exact` (participant `value` = amount), `percentage`
  (`value` = percent, up to 2 decimals, total exactly 100), `shares`
  (`value` = whole-number weight), `itemized` (`items[].shared_by`; total −
  item sum is shared in proportion to item subtotals). Payers default to the
  caller paying everything and must sum to the amount. Omitted members are
  excluded. Updates (`PATCH`) send the full expense with `version`; history
  is kept (`revisions`). Splits are exact in minor units with deterministic
  remainders. `GET /groups/{id}/expenses` pages newest first (`cursor`,
  `limit` ≤ 200, `meta.next_cursor` / `has_more`) with the filters
  `status`, `from` / `to`, `payer_user_id` and `category_key`
  (`uncategorized` for none).
- **Foreign currency:** send `original_amount`, `original_currency` and
  either `fx_rate` (`fx_rate_source: manual`, the default) or
  `fx_rate_source: lookup` (Montra's rate for the expense date, as
  `GET /fx/convert?policy=historical`; 422 `fx_rate_unavailable` without
  one). `amount` may be left out: it is original × rate rounded half away
  from zero and returned. Expenses carry the rate's real `fx_rate_source`
  (`manual`, `ecb`, `provider`) and `fx_rate_at`.
- **Balances:** `GET /groups/{id}/balances` returns per-member paid, share,
  confirmed settlements, `net` (positive = is owed), pending reported
  payments, `original_debts` and `simplified`. Only confirmed settlements
  count. Both debt views add up to the same totals as the balances.
- **Removed members:** an admin may remove a member with an open balance
  (leaving needs a zero balance, `balance_open`). Their records stay: the
  balance remains in balances, debts, suggestions and reports
  (`member_status: removed`), anyone can record a settlement with them,
  and a payment to them is confirmed by an admin on their behalf.
- **Settlements:** `POST /groups/{id}/settlements` (idempotent; `state`
  `paid` by default or `proposed`) and the actions `mark-paid` (payer),
  `confirm` (payee), `dispute`, `void` (reason required), `record` /
  `unlink` (your own account record) and `correct` (idempotent; voids the
  original and links the new one). Every action sends the settlement's
  `version`. Montra never initiates payments; `verification` is
  `user_reported`.
- **Coded conflicts (409 `CONFLICT`):** `already_member`,
  `join_request_pending`, `invitation_used`, `group_archived`,
  `group_not_archived`, `expense_deleted`, `expense_already_recorded`,
  `settlement_voided`, `settlement_not_proposed`,
  `settlement_not_confirmable`, `settlement_not_disputable`
  (`params.status`), `settlement_already_recorded` and
  `occurrence_already_handled` (`params.status`).
- **Personal records:** `payer_account_id` (create) or
  `POST …/expenses/{expenseId}/my-record` records your payment in your own
  account; only your share counts as your spending. Linked records change
  only through the group and follow later edits automatically.
- **Recurring shared bills:** `/groups/{id}/recurring-expenses` (create
  with `Idempotency-Key`, a schedule, amount, split template and
  `auto_add`; edit name/amount/split with `version`; `pause`/`resume`/
  `stop`; per occurrence `add` (any active member; idempotent) and `skip`
  (creator or admins)). Calendar items for them have `kind: group_expense`
  and `group_id`.
- **Activity:** `GET /groups/{id}/activity` events have an enumerated
  `kind` and a `summary` of parameters (codes, IDs and names members
  typed; never amounts or sentences).
- **Export:** `GET /groups/{id}/export` returns `text/csv` named
  `<group>-expenses-YYYY-MM-DD.csv`.
- **Notification links:** group notifications open `/groups`,
  `/groups/{id}`, `/groups/{id}/settings` (join requests),
  `/groups/{id}/recurring`, `/groups/{id}/expenses/{expenseId}` or
  `/groups/{id}/settlements/{settlementId}` (IDs only).
- **Destructive actions:** `DELETE /groups/{id}` requires `confirm=true` and
  settled balances; it also revokes open invitations.
- **Payers:** a single payer may leave `amount` out; the server makes it
  the whole amount (for a foreign-currency expense, the derived
  `original_amount × fx_rate`), so clients never convert money. Several
  payers each send an amount. A rate that converts to less than the group
  currency's smallest unit is 422 `converted_too_small` on
  `body.original_amount` with `params.currency`.
- **Dispute activity:** `dispute_resolved` / `dispute_withdrawn` summaries
  carry `target` and `target_type` (`expense` | `settlement`; absent on
  older events, which were always expenses).

## Communities, moderation and challenges notes

- Community text is plain text (render escaped). Fields are cleaned of
  control and invisible formatting characters; card numbers, CVVs, PINs,
  OTPs and passwords are refused (`VALIDATION_ERROR`). Resource links must
  be public `https` URLs.
- **Field detail codes (422 `VALIDATION_ERROR`):** every `details[]` item
  carries a stable `code` next to its English `message`, so clients can
  localize by code and fall back to the message. Text fields: `required`,
  `too_short` (`params.min`), `too_long` (`params.max`),
  `invalid_characters`, `contains_secret`; links: `too_many_links`
  (`params.max`), `insecure_link`, `link_required`; posts: `moderators_only`
  (verified guidance), `poll_mismatch`, `duplicate_option`, `too_few`
  (`params.min`), `must_be_future`, `invalid_parent`, `invalid_option`,
  `too_many`; communities: `invalid_topic` (`params.index`),
  `invalid_choice`, `self_not_allowed`; moderation: `reason_required`;
  challenges: `share_required`. Request-schema failures (the framework's
  "expected length >= 3", "expected required property version to be
  present", …) carry the same codes: `too_short`, `too_long`, `too_few`,
  `too_many`, `too_small`, `too_large`, `required` (`params.property`),
  `invalid_choice` (`params.allowed`), `invalid_format`, `invalid_type`,
  `unexpected_property`. The taken-URL-name conflict (409 `CONFLICT` on
  `body.slug`) carries `slug_taken`.
- `GET /communities/{ref}` accepts the ID or the URL name (slug).
  Invite-only communities are invisible to non-members (404).
  `CommunityDTO` carries `can_moderate` (the owner, moderators and Montra
  staff, who moderate everywhere while `my_role` stays `none`) and
  `version`.
- **Editing a community:** `PATCH /communities/{id}` changes only the
  fields sent (`name`, `description`, `rules`, `topics`, `visibility`
  (owner)) and must send the current `version` (409 `VERSION_CONFLICT`
  when stale). `description` and `rules` are cleared with `""`; `topics`
  replaces the list (`[]` empties it). Archiving, restoring and staff
  suspension also move the version.
- **Invitations:** link tokens are sent in bodies, never in URLs:
  `POST /community-invitations/preview` `{"token"}` shows the community
  (`community_id`, `community_name`, `slug`, `member_count`), who created
  the link (`invited_by`, minimal profile), the link's `status` (`active`,
  `used`, `declined`, `revoked`, `expired`), `expires_at`,
  `already_member` and `requires_approval` (always false: an invitation
  admits directly); `POST /community-invitations/accept` joins. Unknown,
  revoked, used or expired links answer 410 `GONE`; accepting as a member
  answers 409 `already_member` (also for a link that is already used or
  expired). Username invitations are accepted or
  declined by ID (`POST /community-invitations/{id}/{accept,decline}`;
  declining twice answers 409 `invitation_used`). Moderators list them
  (`GET /communities/{id}/invitations`, active ones unless
  `include_inactive=true`; tokens are never shown again) and revoke them
  (`DELETE /communities/{id}/invitations/{invitationId}`; 409
  `invitation_inactive` once used, declined, revoked or expired). Inviting
  a member answers 409 `already_member`. Invitation DTOs carry `kind`
  (`link` / `username`), `status`, `invitee`, `invited_by` and
  `created_at`.
- Posts: `POST /communities/{id}/posts` (kind `discussion`, `question`,
  `resource` with `link_url`, `poll` with `poll`). The feed
  (`GET /communities/{id}/posts`) sorts `new` / `top` / `active` with `q`
  and pages with a cursor: `limit` (≤ 50, default 20), `cursor`
  (`meta.next_cursor` of the previous page, for the same sort and query;
  another sort rejects it) and `meta.has_more`; `offset` (≤ 1000) is kept
  for older clients and ignored with a cursor. Poll votes
  (`POST /posts/{id}/poll/votes`) replace your previous vote; results are
  aggregate only. Posts and comments carry `my_reactions`; reacting
  (`POST /{posts,comments}/{id}/reactions`, `DELETE …/reactions/{kind}`)
  answers the counts plus `my_reactions`.
- **Hidden content:** moderators and staff see the text of hidden
  comments in `GET /posts/{id}` (as its author does); other members never
  receive hidden comments. Removed and deleted content has no text for
  anyone.
- **Daily caps** (posts 20, or 3 in an account's first day; comments 300 /
  30; reports 20; communities 3; challenges 10; rolling 24 hours) answer
  429 `RATE_LIMITED` with `Retry-After` (seconds until the oldest counted
  action leaves the window) and `details[0].code` `daily_cap` with
  `params.resource`, `params.limit` and `params.retry_at` (RFC 3339).
  Duplicates answer `CONFLICT`.
- Reports: `POST /posts/{id}/reports` or `POST /content-reports` (any
  target; `/reports` is the report-export API); your reports:
  `GET /content-reports`. Moderators and staff also get `preview`,
  `open_reports`, `post_id` (comment reports) and `target_user_id` (the
  author of reported content, or the reported profile); reporters do not.
  Moderators: `/communities/{id}/moderation/{reports,actions,appeals}`;
  staff: `/moderation/{reports,appeals}` and `POST /moderation/actions`.
- **Staff action list:** `GET /moderation/actions` (support/admin) pages
  platform actions (those with no community: account sanctions, community
  suspensions, report dismissals) newest first with `cursor`, `limit`
  (≤ 200, default 50), `meta.next_cursor` / `has_more`, and filters
  `status` (`active`, `reversed`, `expired`), `action`, `target_type`,
  `target_id` and `target_user_id`.
- **Group reports** are resolved by staff with
  `POST /moderation/actions` `{"action": "dismiss_report", "target_type":
  "group", "target_id": …, "report_id": …}`; `dismiss_report` is the only
  action a group takes and the report is required.
- **Actions, appeals and outcomes:** action DTOs carry `appealable`,
  `appeal_until` (30 days after the action; absent when the action cannot
  be appealed or was reversed) and `appeal` (`{id, status, decision_note,
  decided_at, created_at}` of the latest appeal the caller may see).
  Reverse with `POST /moderation/actions/{id}/reverse`; appeal with
  `POST /moderation/actions/{id}/appeals`; decide with
  `POST /moderation/appeals/{id}/decide`. Appeal DTOs embed the action
  appealed against (`action`: `id`, `action`, `target_type`, `target_id`,
  `target_user_id`, `reason`, `expires_at`, `reversed_at`, `created_at`;
  `moderator_id` only in the moderator and staff views, never to the
  appellant). A second open appeal answers 409 `appeal_pending`; deciding
  a decided appeal answers 409 `appeal_already_decided`.
  What affected you: `GET /me/moderation` (with your appeal's state) and
  `GET /me/moderation/appeals`; the appellant is notified when an appeal
  is decided (`moderation_appeal_upheld` / `moderation_appeal_overturned`;
  `upheld` means the action stands, `overturned` that it was reversed).
- Challenges: `POST /challenges` (scope private / group / community),
  `join` with `share_progress` / `show_on_leaderboard`, daily
  `POST /challenges/{id}/progress` (re-sending a date corrects it).
  `ChallengeDTO` carries `group {id, name}` / `community {id, name}` (the
  name shows only to people who may see that group or community) and
  `version`. `GET /challenges` pages with `cursor`, `limit` (≤ 200,
  default 50) and `meta.next_cursor` / `has_more`, active challenges
  first, then by end date and title. `PATCH /challenges/{id}` (creator)
  changes only the fields sent (`title`, `description`, `rules`,
  `ends_on`, `leaderboard_enabled`; `""` clears a text) and must send the
  current `version` (409 `VERSION_CONFLICT`).
  `GET /challenges/{id}/leaderboard` (opted-in participants, percentages
  only) is mutual: a participant who has not chosen to appear on it
  answers 422 `leaderboard_opt_in_required`.

## AI and insights notes

- AI is optional. With the provider off, AI consent missing, AI turned off
  or the fair-use cap reached, `/ai/ask` and `/ai/report-summary` answer
  deterministically (`source: "deterministic"` with a `notice`).
- `PATCH /ai/preferences {"enabled": true}` needs the `ai_processing`
  consent (`POST /me/consents`); otherwise `CONSENT_REQUIRED` (403).
  Revoking the consent turns AI off.
- `/ai/ask` answers carry `facts` (value, source report, period),
  `estimates` (with basis), `suggestions` (always `requires_confirmation`
  unless the action is `none`), `limitations` and `safety_flags`
  (`unverified_fact_removed`, `unverified_number`, `advice_boundary`,
  `advice_removed`).
- Category suggestions are never applied; apply one with the normal
  transaction update. Duplicate checks never merge.
- Receipts are read by AI only when the client asks
  (`read_automatically: true` on create, or `POST /receipts/{id}/process`)
  and only with AI on plus `ai_processing` and `ai_receipt_processing`
  consents; PDF statements only with AI on, the consent and
  `allow_ai_extraction: true` on the import.
- There is no `/ai/jobs` endpoint (ADR-045). Insights:
  `GET /insights`, `POST /ai/insights/generate`,
  `POST /insights/{id}/actions`, `POST /insights/{id}/feedback`,
  `GET /insights/mutes`, `DELETE /insights/mutes`.
- **`GET /insights`** is a cursor page (`limit` 1–200, default 50;
  `meta.next_cursor` / `meta.has_more`): warnings first, then newest
  first. `all=true` includes dismissed, expected, resolved and muted.
- **Localization:** every insight carries `message_code` (the subtype, or
  a variant: `cash_flow_change_spending`, `cash_flow_change_income`,
  `cash_flow_change_both`, `recurring_amount_change_higher`,
  `recurring_amount_change_lower`), `message_params` (amounts as Money
  objects `{amount_minor, amount, currency}`; counts and `percent_bp` as
  numbers; names, dates `YYYY-MM-DD`, months `YYYY-MM` and IDs as strings)
  and `rule_code` for `evidence.rule`: `unusual_amount` →
  `amount_3x_median_above_p95`, `category_spike` →
  `month_to_date_above_3_month_average`, `new_merchant_large` →
  `first_at_merchant_2x_median_expense`, `possible_duplicate` →
  `same_account_amount_within_2_days`, `subscription_price_increase` →
  `recorded_price_change`, `missing_recurring_payment` →
  `overdue_recurring_occurrence`, `cash_flow_change` →
  `spending_up_25_or_income_down_20_vs_3_months`, `subscription_costs` →
  `active_subscriptions_normalized_monthly`, `unusual_frequency` →
  `4_in_7_days_and_3x_weekly_average`, `recurring_amount_change` →
  `latest_differs_10_from_median_of_6`, `repeated_budget_overspend` →
  `over_limit_2_of_last_3_periods`. `title` and `body` stay English.
  Insights recorded before codes existed have no `message_code`.
- **Evidence amounts:** `evidence.amounts` holds every amount as a Money
  object under its evidence key (list entries such as `periods` carry
  their own `amounts`). The top-level `"1100.00 INR"` strings are
  deprecated and kept for compatibility.
- **Feedback** is one answer per person per insight: sending
  `POST /insights/{id}/feedback` again updates it (and its `note`; an
  empty note clears it). The response is the insight, whose
  `my_feedback {feedback, note?, updated_at}` shows the current answer.
  The `expected` action records `expected` feedback the same way.
- **Mutes:** `GET /insights/mutes` lists `[{subtype, scope, created_at}]`
  (`scope` is the record ID the rule applies to, or `*`).
  `DELETE /insights/mutes?subtype=…[&scope=…]` requires `subtype` (422
  `query.subtype` when missing; 404 when no such rule), removes the rule
  and reopens the muted insights of that subtype that no remaining rule
  covers, returning `{subtype, scope, reopened, insights}`. The `reopen`
  action on a muted insight does the same for the rules that match it
  (its subtype with its scope or `*`), so that kind is detected again.

## Notifications and integrations notes

- **`GET /notifications/push-config`** → `{web_push: {available,
  vapid_public_key?}}`. `available` is false when the server has no VAPID
  keys (do not offer browser notifications); the key is the
  `applicationServerKey` to subscribe with. Only the public key is ever
  served.
- Push registration: `POST /me/push-endpoints` with `kind: "webpush"` and
  the browser's subscription JSON (HTTPS endpoint on a known push service,
  `p256dh` 65-byte point, 16-byte `auth`) or `kind: "fcm"` with a token.
  Other hosts get 422. `DELETE /me/push-endpoints/{id}` removes one.
  `GET /me/push-endpoints` lists `[{id, kind, device_label?, created_at,
  last_used_at?, disabled_at?, current_session}]`, never the endpoint URL
  or keys.
- **Push endpoints belong to the session that registered them.** Signing
  out (`POST /auth/logout`), signing out everywhere, revoking a session
  (`DELETE /me/sessions/{id}`), a password change, refresh-token reuse
  and account deletion delete that session's endpoints, and expired
  sessions stop receiving. A shared browser therefore never keeps getting
  the previous person's notifications; after signing in again the client
  registers the browser again.
- **`PATCH /notifications/preferences`** changes only the fields an item
  sends: `enabled` and `digest` are both optional (an item with neither is
  422 detail code `required` on `body.items[i]`); a new group override starts from the
  category's saved preference. `digest` applies to the email channel.
- Digests: `PATCH /me/preferences {"email_digest": "daily" | "weekly" |
  "off"}` sets the account cadence; a per-category `digest` of `daily` or
  `weekly` overrides it for that category (`immediate` follows the
  account). Digests go out at 08:00 local time: daily ones every day,
  weekly ones on Mondays (a Monday digest carries both). High/critical and
  security/account emails are never held for a digest.
- `GET /notifications/unread-count` → `{unread}` (typed `UnreadCount`;
  the JSON is unchanged).
- **Deep links** (`deep_link`) are web routes carrying IDs only:
  `/planning/bills/{id}`, `/planning/recurring/{id}`,
  `/groups/{id}/recurring`, `/insights/{id}`, `/settings/moderation`,
  `/communities/{id}/settings` (join requests),
  `/communities/{id}/moderation` (reports), `/posts/{id}`,
  `/settings/privacy?export={id}` (export ready), `/help/requests/{id}`
  (support replies). The web keeps redirects for the old paths.
- `account/support_reply` is sent when Montra support replies on a request
  (title carries the reference only, never the message).
- Unsubscribe: optional emails link to `<web>/unsubscribe#token=...`. The
  page posts the token to `POST /notifications/unsubscribe` (no sign-in)
  and gets `{category, channel}`, or 410 for an invalid or expired link.
- Integrations (no provider is enabled; ADR-016/048):
  - `GET /integrations` returns providers with honest `status`
    (`available` / `not_configured` / `unavailable` + reason) and your
    connections.
  - `POST /integrations/{provider}/connect {"account_id", "consent_confirm":
    true}` returns `authorize_url`. Open it so the user approves at the
    provider; Montra never asks for bank credentials.
  - The provider redirects to `<web>/integrations/{provider}/callback`. The
    web page then calls `GET /integrations/{provider}/callback?state&code`
    signed in as the same user. 410 means the state is wrong, expired or
    already used.
  - `POST /integrations/{id}/sync` returns 202, or 409 while a sync runs
    and 422 when consent expired or the connection is revoked.
  - `GET /integrations/{id}/status` returns the connection plus its last 20
    runs (fetched/created/updated/skipped counts, error codes).
  - `DELETE /integrations/{id}?confirm=true[&delete_data=true]` revokes the
    connection; with `delete_data=true` it also voids imported
    transactions.
- Webhooks: `POST /webhooks/{provider}` takes the provider's signed raw
  body (≤ 256 KiB). It returns `202 {"status": "accepted" | "duplicate"}`,
  401 for an invalid/stale signature (the event is quarantined), and 404
  for an unknown provider.

## Search and support notes

- **`GET /search`**
  - Parameters: `q` (2–100 characters), `scope` (`all` or one section),
    `limit` (1–20 per section), `save` (default `false`: send
    `save=true` when the person submits the search, never while typing)
    and `sort` (`relevance`, default: names starting with the query
    first, then by name, transactions and posts newest first; `name`:
    alphabetical; `recent`: newest first).
  - Returns `transactions`, `merchants`, `accounts`, `groups`, `posts`,
    `users`, `goals`, `categories` (active), `bills` (not archived; name
    or provider), `subscriptions` (not cancelled; name or plan),
    `recurring_rules` (income, expenses and transfers that have not
    ended) and `budgets` (not archived). The planning sections are the
    caller's own records; every section contains only records the caller
    may see. Named hits are `{id, name, kind}` (`kind`: account type,
    group type, goal status, category kind, bill/subscription status,
    recurring rule kind or budget type).
  - `%` and `_` match literally.
  - Recent searches: `GET /search/recent` (last 20) and
    `DELETE /search/recent`.
- **`POST /support/requests`** (signed in)
  - Body: `kind` (`support`, `bug`, `security`, `privacy` or `feedback`),
    `subject` and `body`.
  - Returns an 8-character `reference`, plus `message_count` and
    `last_message_at` for the thread.
  - Text that contains card numbers, PINs, OTPs or passwords is refused:
    422 `VALIDATION_ERROR` with `details[0]` `{field: "body.body", code:
    "contains_secret"}`. The limit is 10 requests per day: beyond it, 429
    `RATE_LIMITED` with `details[0].code: "daily_cap"`, `params` `{limit,
    window_hours, kind}` and a `Retry-After` header (seconds until the
    oldest counted request leaves the 24-hour window).
  - `GET /support/requests` lists your requests; `GET /support/requests/{id}`
    returns one.
- **Message thread:** `GET /support/requests/{id}/messages` lists
  `[{id, request_id, author_role: requester | staff, mine, body,
  created_at}]` oldest first; `POST /support/requests/{id}/messages
  {"body"}` adds one (201). The requester and Montra staff can read and
  post; anyone else gets 404. The same `contains_secret` refusal applies;
  requesters get 10 messages a day (`daily_cap`, `kind: "support
  messages"`); a closed request answers 422 `request_closed`. Staff
  replies notify the requester (`account/support_reply`, deep link
  `/help/requests/{id}`) without the text; every post is audited
  (`support_request` / `message_posted`) without the text.
- **`POST /support/contact`** (signed out) takes the same fields plus
  `contact_email` and an optional `captcha_token`. It uses the auth rate
  limit, refuses secrets with the same `contains_secret` code, caps each
  contact address at 10 requests a day (`daily_cap` with `Retry-After`)
  and returns `202 {reference}`.
- **Staff (`support` role):** `GET /support/queue` (security and privacy
  first) and `PATCH /support/queue/{id} {"status"}` (audited).

## Fair use, admin and comparison notes

- **`GET /limits`:** the fair-use limits, which are the same for everyone,
  plus your usage: storage allowance and used bytes, max upload size,
  import rows, support requests per day, rate limits per policy, deletion
  grace and download window. `note` is English; `note_code`
  (`fair_use_same_for_everyone`) localizes it. Uploads beyond the
  allowance return 422 `storage_quota_exceeded` with `params.used_bytes`
  and `params.quota_bytes`.
- **Privacy and legal:**
  - `GET /legal` (public) returns `terms_version`, `privacy_version` and
    `consents: [{type, version, required}]`, the current wording version
    of every consent type `POST /me/consents` accepts (`terms` and
    `privacy_policy` are `required`: accepted at sign-up, not revocable).
    Sending another version is 422 `consent_version_outdated` on
    `body.version` with `params.version` (the current one).
  - `GET /me/exports` lists your data exports newest first (`status`
    `queued | running | completed | failed | expired`, `file_id`,
    `expires_at`); a completed export whose download window passed reads
    as `expired` here and in `GET /me/export/{id}`.
  - `GET /me/deletion-request` keeps its English `consequences`,
    `retained` and `group_impact` and adds `consequence_codes` and
    `retained_codes` (same order) plus `group_impact_details:
    [{code: ownership_transfer | group_deleted, params: {group_id,
    group_name, outcome: ownership_transfer | deleted}, text}]`.
- **`GET /admin/usage?days=30`:** platform admins only. Aggregate counts
  and a daily series, never personal data.
- **`GET /analytics/compare`:** takes `from`, `to`, `compare_from`,
  `compare_to` and the usual analytics filters. It returns per-currency
  totals for both periods, the change of each total (`change`), and
  category changes with the largest change first. See "Reports,
  analytics and exchange rates notes" for `change_bp` and `note_codes`.
- **New notification event types:**
  - `community/mention`;
  - `trip/trip_starting` and `trip/trip_ended_unsettled` (local daytime
    only);
  - `challenge/challenge_milestone` (sent once at halfway).
- **Coded domain rules:** every `DOMAIN_RULE_VIOLATION` carries
  `error.details[0].code`, plus `params` where values matter. The table
  below lists the codes.

## Reports, analytics and exchange rates notes

- **Reports:**
  - `DELETE /reports/{id}` deletes one of your reports in any status
    (others get 404). A queued or running generation is cancelled; the
    stored file is deleted durably, so earlier download links stop
    working. Both deletions are audited.
  - `window` `{from, to, days, timezone}` holds the dates a report covers,
    resolved in your time zone when you requested it: `last_month` stays
    the month it meant then, however late the report is generated.
    `filters` keeps the request as sent. To generate a report again, post
    the same `report_type`, `format`, `title` and `filters`: a named range
    is resolved from the new request date (send `window.from`/`to` as
    `filters.from`/`to` to get the same dates). Reports of current state
    (`account`, `budget`, `subscription`, `goal`, `recurring`) have no
    `window`.
  - `income` and `expense` reports use the type sets of
    `/analytics/income` (`income`) and `/analytics/expenses` (`expense`,
    `group_expense`, `refund`, `reimbursement`) and show only their own
    figures: an income report has no expense columns and an expense
    report no income. `filters.types` may narrow them inside the set;
    other types answer 422 on `body.filters.types` (also for schedules).
    An income report adds "Income by category".
  - `status` is `expired` as soon as `expires_at` has passed (list, get
    and download agree; the download answers 410 `GONE`).
  - A failed report has `error_code`: `reports_unavailable`,
    `report_invalid`, `too_many_rows`, `pdf_too_large`,
    `storage_unavailable` or `generation_failed` (every attempt failed).
    A report never stays `running` after its last attempt.
  - Invalid custom ranges are rejected when you request the report (422
    on `body.filters.from` / `body.filters.to`), not when it is generated.
  - The `report_ready` notification opens `/reports`; the report is in
    `entity_id`.
- **Scheduled reports:** `PATCH /reports/schedules/{id}` changes only the
  fields sent: `title` (empty restores the default), `format`, `cadence`,
  `filters` (replaced as a whole; the cadence sets the dates) and
  `enabled`. `enabled: false` pauses a schedule; `enabled: true` resumes
  it from the next start of a week or month (missed periods are not
  back-filled), as does a new cadence. Send `version`: a concurrent change
  answers 409 `VERSION_CONFLICT`. Schedules now return `filters` and
  `version`; `format` and `report_type` are enums.
- **`GET /analytics/compare`:** each currency has `change` with `income`,
  `gross_expense`, `refunds`, `net_expense` and `net_cash_flow` (each
  `{change, change_bp?}`) and `transaction_count`. Currencies are never
  combined. `change_bp` is the change in basis points of the comparison
  amount's magnitude, so it is positive for an increase even from a
  negative base (category changes follow the same rule); it is absent
  when the comparison amount is zero. `notes` (English) come with
  `note_codes` in the same order: `same_filters_and_rules`,
  `compared_as_totals`, `currencies_separate`.
- **`GET /analytics/cash-flow`** (and `/analytics/income`,
  `/analytics/expenses`):
  - `previous_window` gives the dates of `previous_period` (as many days
    as `window`, ending the day before it).
  - `converted` has `rate_policy_code` (`latest_on_or_before`) and
    `rate_policy_params` (`date`, the last day of the window) next to the
    English `rate_policy`.
  - `coverage.pending_count` counts all your pending transactions of any
    date and account; it is not limited to the window or filters.
- **`GET /analytics/merchants`** ranks merchants separately in each
  currency: `limit` (default 10, at most 100) applies per currency, and
  the list is grouped by currency (alphabetical), largest first.
  Categories (and the dashboard's top merchants and categories) are
  ranked per currency the same way.
- **`GET /analytics/categories?kind=income`** gives income per category
  with the `/analytics/income` types (`kind=expense`, the default, is net
  spending). Each category has `amount` (net expense or income, by
  `kind`) and `share_bp` of its currency's total; `net_expense` is `0`
  for `kind=income`. The response repeats `kind`.
- **Exchange rates:**
  - `POST /fx/rates` takes `as_of` as an RFC 3339 instant, or a
    `YYYY-MM-DD` date meaning the start of that day in your time zone:
    the rate applies to conversions dated that day. A date after your
    today, or an instant more than an hour ahead, answers 422 on
    `body.as_of`.
  - `rate` is a plain decimal without padding zeros (`83.1234`, `83`,
    `0.5`) in rate lists and responses. The FX rate column of
    transaction exports is written the same way.
  - Historical conversions use the latest rate on or before the end of
    the date in your time zone, also on 23- and 25-hour days.

## Planning and organizing notes

- **Bills and recurring rules:**
  - Lifecycle uses `POST /bills/{id}/pause|resume|archive|restore`
    (pause from active, resume from paused, archive from active or
    paused, restore from archived) and the existing rule actions.
  - Editing keeps postponed or own-amount occurrences when the dates do
    not change. Changing the dates regenerates open future occurrences
    from today; a new frequency starts from the anchors sent with it.
  - A moved occurrence keeps its status and has `postponed_to`.
  - `GET /bills/{id}/payment-candidates` returns existing transactions
    with `reason_codes` (`same_provider`, `same_amount`, `amount_close`,
    `on_due_date`, `near_due_date`) and `days_from_due`. It returns an
    empty list when nothing is unpaid.
  - Rules carry `merchant {id,name}` and, for bills, `bill_id`.
- **Budgets:**
  - `GET /budgets/{id}/transactions` pages through exactly the
    transactions the total counts. Only the owner can call it;
    collaborators see totals only.
  - Group budgets count all of the group's expenses. They can be split
    between current members, with no account, category or merchant
    filters (`group_budget_*` codes).
  - Editors may save budgets that reference the owner's categories,
    merchants and accounts.
  - `alert_thresholds` uses the published values; `[]` turns threshold
    alerts off.
  - `progress.explanation_items` explains the figures with codes and
    params.
- **Merges:**
  - Category and merchant merges move every reference: transactions,
    rules, allocations, budget filters, recurring rules, bills,
    subscriptions and pending detections.
  - The preview returns typed counts (`budget_filters` counts budgets
    whose filter will follow).
  - Transaction filters that name a merged category or merchant find the
    moved transactions.
  - `GET /merchants` lists active merchants unless `status` says
    otherwise.
- **Category rules:** amount bounds carry their `currency` and match
  only transactions in that currency.
- **Subscriptions:**
  - A transaction backs at most one subscription payment
    (`payment_linked_elsewhere`).
  - `GET /subscriptions/{id}/payment-candidates` suggests recorded
    charges; `DELETE /subscriptions/{id}/payments/{transactionId}`
    unlinks one and records the change in the history.
  - Detections expose `confidence_bp` (0–10000) and evidence
    `reason_codes`.
- **Goals:**
  - The owner is listed in `members` with role `owner`.
  - A planned contribution is recorded with
    `POST /goals/{id}/contributions/{contributionId}/record`
    (Idempotency-Key; optionally linked to a transaction, which verifies
    it).
  - `GET /goals/{id}/export` returns `text/csv`.
- **Fair-use caps** (the same for everyone, in `GET /limits`): 500 open
  recurring rules, 200 open bills, 500 open subscriptions and 200 open
  goals. Creating or reopening beyond a cap answers `record_limit_reached`
  {resource, limit}. Goal contributions, budget transactions, budget
  alerts and merchants page with a cursor instead (`meta.next_cursor`,
  `meta.has_more`); exports are always complete.

## Receipts notes

- **Create:** `POST /receipts` needs `Idempotency-Key`; a retry returns
  the first receipt with `Idempotent-Replayed: true`. Receipts are entered
  manually by default (`status: needs_review`, no reading and no failed
  reading stored). `read_automatically: true` reads in the background
  (`status: processing`) when reading is configured and allowed (see AI
  notes); otherwise the receipt also starts in `needs_review`.
  `skip_extraction` is deprecated and ignored, and cannot be combined
  with `read_automatically: true` (422).
- **Pages:** a file is a page of only one receipt that is not discarded:
  409 `file_in_use` {`file_id`, `receipt_id`}. A page whose upload is not
  finished answers 409 `page_not_ready` {`file_id`, `status`}.
- **Inbox:** `GET /receipts` pages newest first with `cursor` and `limit`
  (default and maximum 200), `meta.next_cursor` and `meta.has_more`;
  `status` filters every page (default: all but discarded).
- **State conflicts** answer 409 `CONFLICT` with the same code whatever the
  action: `receipt_linked` {`transaction_id`} (unlink first),
  `receipt_discarded` (restore first; also for discarding twice),
  `receipt_processing` (reading under way), `receipt_not_linked`
  (unlink), `receipt_not_discarded` {`status`} (restore). Linking a
  transaction that has another receipt answers 409 `DUPLICATE` with code
  `transaction_has_receipt`. `create-transaction` keeps 422
  `receipt_not_reviewed` for receipts not reviewed yet.
- **Discard and restore:** `POST /receipts/{id}/discard` unlinks a linked
  transaction and drops reading under way. `POST /receipts/{id}/restore`
  returns a discarded receipt to `reviewed` when its current values are
  your reviewed version, otherwise to `needs_review` (also after unlink or
  a failed reading). Both take an optional `?version=`
  (`VERSION_CONFLICT` when stale), bump `version` and are audited.
- **Codes next to English:** extraction and review `warnings` come with
  `warning_codes` and `warning_params` in the same order
  (`totals_mismatch`, `line_items_mismatch` {`line_items_total`,
  `subtotal`, `currency`}, `amount_unreadable` {`value`},
  `date_unreadable`, `currency_unrecognized`, `reader_note`, and a failed
  reading's error code). Match candidates carry `reason_codes`
  (`same_amount` or `amount_close`, `same_date` or `near_date`,
  `same_merchant`).
- **Payment hints:** digits joined by spaces, dashes or dots form one
  number; a number with five or more digits is stored and returned as its
  last four (`•••• 1111`).

## Imports and reconciliation notes

- **Create:** `POST /imports` needs `Idempotency-Key`; a retry returns the
  first batch with `Idempotent-Replayed: true` and parses nothing again.
- **Pages:** `GET /imports` (newest first, default 100),
  `GET /reconciliation/matches` (newest first, default 200),
  `GET /accounts/{id}/reconciliations` (latest statement first, default
  100) and `GET /accounts/{id}/statement-lines` (oldest first, default 100)
  take `cursor` and `limit` (at most 200) and return `meta.next_cursor` and
  `meta.has_more`. Without a cursor the first page is what the list
  returned before.
- **Batches:**
  - `to_import_rows` counts the rows confirm (or retry-failed) would
    import now: ready rows the user did not skip, plus duplicates marked
    `import`. While processing it is the rows still to import.
  - `totals` amounts are Money: `inflow`, `outflow`, `net`,
    `opening_balance`, `closing_balance`. The `*_minor` fields are
    deprecated.
  - `mapping_note_codes` follow `mapping_notes` in order:
    `no_header_row`, `ambiguous_date_order`, `unknown_date_format`,
    `decimal_comma`, `mapping_incomplete`, `check_sign_convention`,
    `pdf_read_by_ai`. `mapping_note_params` has `assumed_date_format` and
    `alternative_date_format` for `ambiguous_date_order`.
  - `error_params` holds the values of `error_code`:
    - `currency_mismatch`: `statement_currency`, `account_currency`;
    - `rolled_back`: `voided`, `kept`.
    - Other batch codes: `unsupported_format`, `pdf_needs_ai`,
      `pdf_unreadable`, `file_unavailable`, `empty`, `malformed`,
      `too_large`, `too_many_rows`, `too_many_columns`.
- **Rows:** a row that is not imported as is has an `error_code`.
  `error_message` is the specific English reason. `error_field` names the
  value to correct with `PATCH /imports/{id}/rows/{rowId}` (`posted_date`,
  `amount`, `category_id`, `description`). `error_params` holds the values:
  - reading: `preamble`, `header`, `missing_date`, `bad_date` {`format`},
    `bad_amount` {`currency`}, `zero_amount`, `both_debit_credit`,
    `currency_mismatch` {`currency`, `account_currency`};
  - duplicates: `already_imported` {`matched_by`: `fingerprint` or
    `external_id`}, `possible_duplicate` {`days_apart`} with
    `duplicate_reason_codes` (the reason codes below);
  - processing (status `failed`): `invalid_date` (for example "Date is too
    far in the future."), `invalid_amount`, `invalid_category`,
    `invalid_description`, `invalid_reference`, `invalid_row`, `rejected`,
    or a domain-rule code such as `account_inactive` with its params;
  - after processing: `reconciled`, `rolled_back`.
- **Reasons:** candidates and matches carry `reason_codes` in the order of
  the English `reasons`, plus `reason_params`:
  - matcher codes: `same_amount_direction`, `same_date`, `one_day_apart`,
    `within_3_days`, `within_a_week`, `same_reference`,
    `similar_description`, `amounts_add_up`, `all_within_a_week`;
  - match-only codes: `dates_far_apart` (matched by hand),
    `pending_replaced_by_posted`, `pending_amount_differs`
    {`pending_amount`, `posted_amount`, `currency`},
    `entered_manually_and_imported`;
  - `days_apart` is the largest date distance between the two sides.
- **Items:**
  - Candidate and match items have `record_status` (the row's or the
    transaction's status) and `source` (the transaction's source). The
    packed candidate `status` (`"posted/manual"`) is deprecated.
  - Match items also have `date`, `direction` and `description`.
  - Matches have `total`: the ledger amount kept.
- **Matching by hand:**
  - `GET /accounts/{id}/statement-lines` lists the lines that were
    neither imported nor matched, including lines with no suggestion.
    It takes `status=unmatched` (default) or `matched` (with `match_id`)
    and `batch_id`.
  - Send a line with transactions of the account to
    `POST /reconciliation/matches` (`statement_to_ledger`); the amounts
    must add up. Find the ledger side with
    `GET /transactions?account_id=…&reconciliation_state=unreconciled`.
  - A pair more than a week apart gets `dates_far_apart` and no
    `confidence`. Owner only; audited.
  - Unmatch restores each line's status, reason and decision.
- **History and accounts:**
  - A reconciliation stores `reconciled_count`,
    `unmatched_statement_rows` (the import's unmatched lines) and
    `unreconciled_transactions`. The last two read 0 for reconciliations
    recorded before they were stored.
  - A balanced reconciliation sets the account's `last_reconciled_at`
    and `last_reconciled_balance`, unless a later statement date is
    already reconciled.
  - An import that finishes with imported rows sets `last_import_at`.
  - These system fields do not change the account's `version`.

## Dashboard, profile and shared-link notes

- **`GET /dashboard/planning`** (the planning side of the dashboard): `today`
  and `upcoming_through` (today + 14 days, your time zone); `budgets`
  (active, fullest first, up to 5) with `budget_count` and
  `over_budget_count`; `upcoming` (overdue items oldest first, then items
  due through `upcoming_through`, up to 8: bills, recurring transactions,
  shared recurring expenses, subscription renewals, trial ends, goal target
  dates) with `upcoming_count` and `overdue_count`; `goals` (active, nearest
  target date first, up to 4) with `goal_count`; `group_balances` (active
  groups where you are owed or owe, largest first per currency, up to 5)
  with `group_count`. `GET /dashboard/widgets` offers `budgets`,
  `upcoming`, `goals` and `group_balances` next to the earlier widgets; a
  saved layout gets new widgets at the end, visible.
- **Avatar:** `PATCH /me {"avatar_file_id"}` takes a ready file you uploaded
  with purpose `avatar` (anything else: 422 `avatar_file_invalid`); `""`
  removes it (the file itself is kept). Read it with
  `GET /files/{id}/access`.
- **Single reads:** `GET /insights/{id}` (any status, your own) and
  `GET /reports/schedules/{id}`.
- **Transactions** linked to a group expense or settlement carry `group_id`
  while you can still see that group.
- **Invitation links:** creating a group or community link returns
  `share_url` (the web join link with the token in the URL fragment) next
  to `token`, once.
- **Group budgets:** a member who can only view a members-visible group
  budget sees it in `GET /budgets` and `GET /budgets/{id}` with the
  owner's figures; viewers never write the budget's cached snapshots.
- **Community invitations by username** notify the invitee
  (`community_invitation`, category `community`, link `/communities`), and
  while the invitation is open, inviter and invitee see each other's
  minimal profile (name, username, avatar).
- **Local end-to-end runs:** `AUTH_DEV_RATE_PER_MINUTE` relaxes the per-IP
  sign-in/sign-up limit (default about 10 per minute); the API refuses to
  start with it outside development and test.
- **Codes added:** `required` on a blank `body.display_name`; `too_long`
  {max: 40} on `body.interests[i]` (characters, not bytes); `username_invalid`, `username_reserved` (422) and
  `username_taken` (409) on `body.username`; `query_too_short` {min} on
  `query.q`; `username_or_user_id` on group invitations;
  `confirm_word_mismatch` {word}, 409 `deletion_already_scheduled` /
  `no_deletion_scheduled`; `duplicate_item` and 409
  `transaction_already_matched` in reconciliation; 409 `sync_running`;
  409 `already_reported`. Pausing a paused (or resuming an active) shared
  recurring expense is 422 `invalid_status_transition` {from, to}, as for
  personal rules.

## Domain rule codes

Localize `DOMAIN_RULE_VIOLATION` by `error.details[0].code`. When the code
has values, they are in `error.details[0].params` as strings (amounts are
decimal strings with a `currency`). The English message shown here is the
fallback.

<!-- BEGIN GENERATED: error codes (scripts/docs/gen_error_codes.py) -->

### 422 `DOMAIN_RULE_VIOLATION` (106 codes)

| Code | Example message |
|---|---|
| `account_inactive` | Restore the account before adjusting its balance. |
| `account_restricted` | Your account cannot take part in communities right now. |
| `accounts_inactive` | Both accounts must be active. |
| `already_deleted` | The author already deleted this. |
| `always_on_category` | Security and account emails cannot be turned off. |
| `amount_below_refunds` | The amount cannot be lower than the refunds already recorded … |
| `appeal_needs_other_moderator` | Another moderator must review an appeal against your action. |
| `appeal_window_passed` | Appeals must be made within 30 days. |
| `auto_post_needs_amount_and_account` | Auto-posting needs a fixed amount and an account. |
| `balance_already_matches` | The balance already matches; no adjustment is needed. |
| `balance_not_zero` | Transfer or adjust the remaining balance to zero before closing this account. |
| `balance_open` | Settle your balance before leaving the group. |
| `balances_open` | Settle all balances before deleting the group. |
| `bill_inactive` | Restore the bill before recording payments. |
| `bills_not_auto_posted` | Bills are confirmed by linking or recording the actual payment, not auto-posted. |
| `cannot_duplicate` | Only your own expenses and income can be duplicated. |
| `cannot_move_transaction` | Transfers and system transactions cannot be moved between accounts. |
| `category_already_merged` | A source category was already merged. |
| `category_depth` | Categories support one level of subcategories. |
| `category_merged` | This category was merged and can no longer be edited. |
| `challenge_cancelled` | This challenge was cancelled. |
| `challenge_inactive` | This challenge is no longer active. |
| `challenge_not_open` | This challenge is not open. |
| `comment_locked` | This comment can no longer be changed. |
| `comments_closed` | Comments are closed on this post. |
| `community_suspended` | A suspended community can only be restored by Montra staff. |
| `consent_expired` | Your consent for this connection expired. Connect again to renew it. |
| `content_unavailable` | This content is not available. |
| `cross_currency_transfer_not_auto_posted` | Cross-currency transfers need the received amount each time, so they cannot be auto-posted. |
| `currency_locked` | The currency cannot change after transactions exist. Create a new account instead. |
| `currency_mismatch` | The refund must be in the same currency as the original transaction. |
| `direction_mismatch` | Statement rows and transactions must have the same direction. |
| `file_not_attachable` | This file cannot be attached to a transaction. |
| `file_not_ready` | Finish uploading the file before attaching it. |
| `fx_rate_unavailable` | Montra has no … |
| `goal_inactive` | Contributions can be added to active goals only. |
| `group_budget` | Group budgets track group expenses; open the group to see them. |
| `group_budget_allocation_unsupported` | Group budgets are split between members, not categories, merchants or accounts. |
| `group_budget_filter_unsupported` | Group budgets count all of the group's expenses; account, category and merchant filters do not apply. |
| `group_budget_type_unsupported` | Group budgets track all of the group's expenses: use a total budget, or split it between members. |
| `group_linked` | This transaction is linked to a group record; update it from the group. |
| `has_linked_refunds` | This transaction has linked refunds; review it manually. |
| `invalid_match_shape` | Match one statement row to several transactions, or several rows to one transaction. |
| `invalid_pair` | Choose one pending and one posted transaction in the same direction. |
| `invalid_status_transition` | A budget cannot move from … |
| `invitation_only` | This community is invitation only. |
| `items_exceed_total` | Items add up to more than the total. |
| `items_need_amount` | At least one item needs an amount. |
| `join_challenge_first` | Join the challenge first. |
| `join_community_first` | Join the community to take part. |
| `leaderboard_opt_in_required` | Join the challenge and choose to appear on the leaderboard to see it. |
| `limited_edit` | Only the description, notes, merchant and tags of this transaction can be edited here. |
| `linked_not_reversible` | Linked transactions are not changed by a provider reversal. |
| `member_controls_visibility` | Members choose their own contribution visibility. |
| `merge_target_inactive` | Merge into an active category. |
| `merge_target_must_be_top_level` | A category with subcategories can only be merged into a top-level category. |
| `new_account_links` | New accounts can share links after their first day. |
| `no_leaderboard` | This challenge has no leaderboard. |
| `no_rows` | There are no rows to import. |
| `not_accepting_members` | This community is not accepting members. |
| `not_accepting_posts` | This community is not accepting new posts. |
| `not_appealable` | This action cannot be appealed. |
| `not_group_record` | Not a group-linked transaction. |
| `original_not_refundable` | Only active expenses can be refunded or reimbursed. |
| `original_voided` | Restore the original transaction first. |
| `own_content` | Ask another moderator to act on your own content or account. |
| `owner_cannot_leave` | The owner cannot leave or be removed; archive the goal instead. |
| `owner_protected` | The owner cannot be banned from their own community. |
| `owner_role_fixed` | The owner's role cannot change. |
| `parent_category_archived` | The parent category is archived. |
| `payer_only` | Only a payer can record this expense in an account. |
| `payers_total_mismatch` | The payers' amounts must add up to the total. |
| `poll_closed` | This poll is closed. |
| `post_locked` | This post can no longer be edited. |
| `posting_restricted` | A moderator limited your posting here until … |
| `postpone_needs_later_open_occurrence` | Postpone an open occurrence to a later date. |
| `receipt_incomplete` | The reviewed receipt needs a date and a total. |
| `receipt_not_reviewed` | Review the receipt values before recording the purchase. |
| `reconnect_required` | Connect again before syncing. |
| `record_limit_reached` | You can keep up to … of these. End, archive or delete ones you no longer need. |
| `recurring_member_inactive` | Someone who shares or pays this recurring expense is no longer a member. Edit who shares it, then add it. |
| `recurring_template_invalid` | This recurring expense cannot be added as it is set up: … |
| `refund_exceeds_remaining` | Refunds and reimbursements cannot exceed the original amount … |
| `report_too_large` | The report has too many transactions; narrow the date range or filters. |
| `request_closed` | This request is closed. |
| `requests_closed` | This person is not accepting friend requests. |
| `required_consent` | Terms and privacy consent are required to use Montra. To withdraw, request account deletion. |
| `restore_exceeds_original` | Restoring would exceed the original amount. |
| `row_invalid` | Correct the row (date, amount, direction) before importing it. |
| `rule_category_unavailable` | This rule's category is archived or no longer fits the rule. Restore the category or choose another one for the rule. |
| `settlement_dispute` | Settlement disputes end when the payee confirms the payment or someone voids it. |
| `settlement_not_confirmed` | Confirm the payment before recording it in your account. |
| `settlement_not_paid` | Mark it paid before recording it in your account. |
| `share_household_only` | Accounts can only be shared with a household. |
| `split_mismatch` | The split does not add up: … |
| `storage_quota_exceeded` | This upload would exceed your … MB storage allowance. Delete files you no longer need first. |
| `subscription_inactive` | Reactivate the subscription before recording new payments. |
| `subscription_not_cancelled` | Only a cancelled subscription has a cancellation date. |
| `sums_differ` | The statement side … |
| `transaction_voided` | Restore this transaction before editing it. |
| `transfer_missing_destination` | This transfer has no destination account. |
| `transfer_needs_two_accounts` | Recurring transfers need two different accounts. |
| `transfer_ownership_first` | Transfer ownership before leaving. |
| `use_bill_screen` | Edit bills from the bill screen. |
| `withdrawal_exceeds_saved` | A withdrawal cannot exceed the amount saved … |
| `zero_based_unallocated` | Zero-based budgets must allocate exactly the full limit. |

### 409 `CONFLICT` (41 codes)

Conflicts that depend on a record's current state carry a code too
(`VERSION_CONFLICT` and the idempotency conflicts have their own
top-level codes and no detail code).

| Code | Example message |
|---|---|
| `already_friends` | You are already friends. |
| `already_member` | This person is already a member. |
| `already_reported` | You already reported this; moderators will review it. |
| `appeal_already_decided` | This appeal was already decided. |
| `appeal_pending` | You already appealed this action. |
| `category_in_use` | This category is used by existing records. Merge it into another category or archive it instead. |
| `contribution_not_planned` | This contribution is already … |
| `contribution_voided` | This contribution was voided. |
| `deletion_already_scheduled` | A deletion request is already scheduled. |
| `detection_already_decided` | This detection was already … |
| `detection_evidence_missing` | The supporting transactions no longer exist; dismiss this detection. |
| `expense_already_recorded` | This expense is already recorded in your account. |
| `expense_deleted` | This expense was deleted. |
| `file_in_use` | This file is already a page of another receipt. |
| `group_archived` | This group is archived; restore it to make changes. |
| `group_not_archived` | The group is not archived. |
| `invitation_inactive` | This invitation is no longer active. |
| `invitation_used` | This invitation was already … |
| `join_request_pending` | Your request to join is already waiting for the admins. |
| `name_taken` | A category with this name already exists at this level. |
| `no_deletion_scheduled` | There is no scheduled deletion to cancel. |
| `no_open_occurrence` | There is no unpaid occurrence. |
| `occurrence_already_handled` | This occurrence was already added or skipped. |
| `occurrence_not_open` | That occurrence is already paid, skipped or not part of this bill. |
| `occurrence_not_skipped` | Only skipped occurrences can be reopened. |
| `page_not_ready` | A receipt page upload is not complete yet. |
| `receipt_discarded` | Restore the receipt before reading it again. |
| `receipt_linked` | Unlink the transaction before reading the receipt again. |
| `receipt_not_discarded` | Only a discarded receipt can be restored. |
| `receipt_not_linked` | This receipt is not linked to a transaction. |
| `receipt_processing` | This receipt is already being read. |
| `request_pending` | You already sent this person a friend request. |
| `rule_in_use` | This rule could not be deleted; stop it instead. |
| `schedule_ended` | This schedule has ended; edit it to set new dates. |
| `settlement_already_recorded` | This settlement is already recorded in your account. |
| `settlement_not_confirmable` | Only a proposed, reported or disputed settlement can be confirmed. |
| `settlement_not_disputable` | Only a reported or confirmed settlement can be disputed. |
| `settlement_not_proposed` | Only a proposed settlement can be marked paid. |
| `settlement_voided` | This settlement was voided. |
| `sync_running` | A sync is already running. |
| `transaction_already_matched` | A transaction is already matched or reconciled. |

<!-- END GENERATED: error codes -->
