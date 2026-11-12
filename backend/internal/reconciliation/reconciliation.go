// Package reconciliation matches statement rows and ledger transactions
// (spec §4.10, §20B.11): explainable candidates, user-confirmed matches
// with recorded side effects (so an unmatch restores the prior state), and
// statement balance reconciliation. Nothing is matched or voided silently.
package reconciliation

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/domain/reconcile"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
)

// Service implements reconciliation.
type Service struct {
	DB      *database.DB
	Finance *finance.Service
}

// Reason codes of user-confirmed matches; the matcher's own codes are in
// domain/reconcile. Reasons stay English for older clients.
const (
	reasonDatesFarApart        = "dates_far_apart"
	reasonPendingReplaced      = "pending_replaced_by_posted"
	reasonPendingAmountDiffers = "pending_amount_differs"
	reasonEnteredTwice         = "entered_manually_and_imported"
)

// ReconCandidateItem is one side of a candidate.
type ReconCandidateItem struct {
	Side          string         `json:"side" enum:"statement,ledger"`
	ImportRowID   *uuid.UUID     `json:"import_row_id,omitempty"`
	TransactionID *uuid.UUID     `json:"transaction_id,omitempty"`
	Date          string         `json:"date"`
	Amount        apitypes.Money `json:"amount"`
	Direction     string         `json:"direction" enum:"inflow,outflow"`
	Description   *string        `json:"description,omitempty"`
	RecordStatus  string         `json:"record_status" enum:"parsed,invalid,duplicate,ready,imported,skipped,failed,draft,pending,posted,voided,reversed" doc:"The statement row's status (side statement) or the transaction's status (side ledger)"`
	Source        *string        `json:"source,omitempty" enum:"manual,import,receipt,recurring,integration,correction,group,system" doc:"Side ledger: how the transaction was recorded"`
	Status        string         `json:"status" deprecated:"true" doc:"Deprecated: use record_status and source. The row status, or the transaction's status and source packed as \"posted/manual\""`
}

// ReconCandidate is a suggested match for the user to confirm.
type ReconCandidate struct {
	Kind         string               `json:"kind" enum:"statement_to_ledger,pending_to_posted,manual_to_imported"`
	Cardinality  string               `json:"cardinality" enum:"one_to_one,one_to_many"`
	Left         ReconCandidateItem   `json:"left"`
	Right        []ReconCandidateItem `json:"right"`
	Confidence   string               `json:"confidence" doc:"0–1"`
	Reasons      []string             `json:"reasons" doc:"English; localize by reason_codes"`
	ReasonCodes  []string             `json:"reason_codes" enum:"same_amount_direction,same_date,one_day_apart,within_3_days,within_a_week,same_reference,similar_description,amounts_add_up,all_within_a_week" doc:"Stable reasons, in the order of reasons"`
	ReasonParams map[string]string    `json:"reason_params" doc:"Values the codes refer to: days_apart (the largest date distance between the two sides, in days)"`
}

type item struct {
	ci  ReconCandidateItem
	rec reconcile.Item
	cur string
}

func confidence(m int) string { return fmt.Sprintf("%d.%03d", m/1000, m%1000) }

func ownAccount(ctx context.Context, tx pgx.Tx, uid, acct uuid.UUID) (cur string, liability bool, err error) {
	return accountOf(ctx, tx, uid, acct, "")
}

// lockOwnAccount is ownAccount for writes that end by updating the account:
// it takes the row lock first, so reconciliations of one account queue up
// and lock in the same order as account edits. FOR NO KEY UPDATE does not
// block transactions being recorded meanwhile.
func lockOwnAccount(ctx context.Context, tx pgx.Tx, uid, acct uuid.UUID) (cur string, liability bool, err error) {
	return accountOf(ctx, tx, uid, acct, " for no key update")
}

func accountOf(ctx context.Context, tx pgx.Tx, uid, acct uuid.UUID, lock string) (cur string, liability bool, err error) {
	if err := tx.QueryRow(ctx, `select currency, is_liability from financial_accounts where id = $1 and user_id = $2`+lock, acct, uid).
		Scan(&cur, &liability); err != nil {
		if database.IsNoRows(err) {
			return "", false, apperr.NotFound("account")
		}
		return "", false, err
	}
	return cur, liability, nil
}

// unmatchedLine is the statement-line rule shared by candidates, the
// statement-lines list and the reconciliation counts: rows with a date and
// an amount that were neither imported nor matched. Header, preamble and
// rolled-back rows are not lines to match.
const unmatchedLine = `r.transaction_id is null and r.posted_date is not null and r.amount_minor is not null
	and r.status in ('duplicate','skipped','ready','failed')
	and coalesce(r.error_code, '') not in ('header','preamble','rolled_back','reconciled')
	and not exists (select 1 from reconciliation_match_items i where i.import_row_id = r.id and i.active)`

// statementRows loads unmatched, non-imported statement rows of the account.
func statementRows(ctx context.Context, tx pgx.Tx, acct uuid.UUID, batch *uuid.UUID, cur string) ([]item, error) {
	rows, err := tx.Query(ctx, `select r.id, r.posted_date, r.amount_minor, r.direction, r.description, r.reference, r.status
		from import_rows r join import_batches b on b.id = r.batch_id
		where b.account_id = $1 and ($2::uuid is null or b.id = $2) and `+unmatchedLine+`
		order by r.posted_date limit 2000`, acct, batch)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []item
	for rows.Next() {
		var id uuid.UUID
		var d time.Time
		var amt int64
		var dir, status string
		var desc, ref *string
		if err := rows.Scan(&id, &d, &amt, &dir, &desc, &ref, &status); err != nil {
			return nil, err
		}
		rid := id
		out = append(out, item{ci: ReconCandidateItem{Side: "statement", ImportRowID: &rid, Date: finance.LocalDateString(d), Amount: apitypes.M(amt, cur),
			Direction: dir, Description: desc, RecordStatus: status, Status: status},
			rec: reconcile.Item{ID: id.String(), Date: d, AmountMinor: amt, Direction: dir, Description: deref(desc), Reference: deref(ref)}, cur: cur})
	}
	return out, rows.Err()
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// ledgerRows loads unreconciled transactions of the account.
func ledgerRows(ctx context.Context, tx pgx.Tx, acct uuid.UUID, cur, where string) ([]item, error) {
	rows, err := tx.Query(ctx, `select t.id, t.local_date, t.amount_minor, t.direction, coalesce(m.name || ' ', '') || coalesce(t.description, ''),
		t.status, t.source from transactions t left join merchants m on m.id = t.merchant_id
		where t.account_id = $1 and t.deleted_at is null and t.reconciliation_state = 'unreconciled'
		and t.type not in ('opening_balance','adjustment')
		and not exists (select 1 from reconciliation_match_items i where i.transaction_id = t.id and i.active) and `+where+`
		order by t.local_date limit 5000`, acct)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []item
	for rows.Next() {
		var id uuid.UUID
		var d time.Time
		var amt int64
		var dir, desc, status, source string
		if err := rows.Scan(&id, &d, &amt, &dir, &desc, &status, &source); err != nil {
			return nil, err
		}
		tid, src := id, source
		desc = strings.TrimSpace(desc)
		var dp *string
		if desc != "" {
			dp = &desc
		}
		out = append(out, item{ci: ReconCandidateItem{Side: "ledger", TransactionID: &tid, Date: finance.LocalDateString(d), Amount: apitypes.M(amt, cur),
			Direction: dir, Description: dp, RecordStatus: status, Source: &src, Status: status + "/" + source},
			rec: reconcile.Item{ID: id.String(), Date: d, AmountMinor: amt, Direction: dir, Description: desc}, cur: cur})
	}
	return out, rows.Err()
}

func recItems(xs []item) []reconcile.Item {
	out := make([]reconcile.Item, len(xs))
	for i, x := range xs {
		out[i] = x.rec
	}
	return out
}

func byID(xs []item) map[string]item {
	m := map[string]item{}
	for _, x := range xs {
		m[x.rec.ID] = x
	}
	return m
}

func toCandidate(kind string, c reconcile.Candidate, left, right map[string]item) ReconCandidate {
	rc := ReconCandidate{Kind: kind, Cardinality: "one_to_one", Left: left[c.Left.ID].ci, Confidence: confidence(c.ConfidenceMilli),
		Reasons: reconcile.Texts(c.Reasons), ReasonCodes: reconcile.Codes(c.Reasons), ReasonParams: map[string]string{"days_apart": strconv.Itoa(c.DaysApart)}}
	for _, r := range c.Right {
		rc.Right = append(rc.Right, right[r.ID].ci)
	}
	if len(c.Right) > 1 {
		rc.Cardinality = "one_to_many"
	}
	return rc
}

// Candidates suggests matches for an account.
func (s *Service) Candidates(ctx context.Context, acct uuid.UUID, kind string, batch *uuid.UUID) ([]ReconCandidate, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []ReconCandidate{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		cur, _, err := ownAccount(ctx, tx, uid, acct)
		if err != nil {
			return err
		}
		if kind == "" || kind == "statement_to_ledger" {
			left, err := statementRows(ctx, tx, acct, batch, cur)
			if err != nil {
				return err
			}
			right, err := ledgerRows(ctx, tx, acct, cur, "t.status <> 'voided'")
			if err != nil {
				return err
			}
			lm, rm := byID(left), byID(right)
			pairs := reconcile.BestOneToOne(recItems(left), recItems(right), reconcile.MinConfidenceMilli)
			used := map[string]bool{}
			for _, p := range pairs {
				used[p.Left.ID], used[p.Right[0].ID] = true, true
				out = append(out, toCandidate("statement_to_ledger", p, lm, rm))
			}
			var free []reconcile.Item
			for _, r := range right {
				if !used[r.rec.ID] {
					free = append(free, r.rec)
				}
			}
			for _, l := range left {
				if used[l.rec.ID] {
					continue
				}
				if c, ok := reconcile.OneToMany(l.rec, free, 3); ok {
					out = append(out, toCandidate("statement_to_ledger", c, lm, rm))
				}
			}
		}
		if kind == "" || kind == "pending_to_posted" {
			pending, err := ledgerRows(ctx, tx, acct, cur, "t.status = 'pending'")
			if err != nil {
				return err
			}
			if len(pending) > 0 {
				posted, err := ledgerRows(ctx, tx, acct, cur, "t.status = 'posted'")
				if err != nil {
					return err
				}
				pm, qm := byID(pending), byID(posted)
				for _, p := range reconcile.BestOneToOne(recItems(pending), recItems(posted), reconcile.MinConfidenceMilli) {
					out = append(out, toCandidate("pending_to_posted", p, pm, qm))
				}
			}
		}
		if kind == "" || kind == "manual_to_imported" {
			manual, err := ledgerRows(ctx, tx, acct, cur, "t.status = 'posted' and t.source <> 'import'")
			if err != nil {
				return err
			}
			imported, err := ledgerRows(ctx, tx, acct, cur, "t.status = 'posted' and t.source = 'import'")
			if err != nil {
				return err
			}
			mm, im := byID(manual), byID(imported)
			for _, p := range reconcile.BestOneToOne(recItems(manual), recItems(imported), 600) {
				out = append(out, toCandidate("manual_to_imported", p, mm, im))
			}
		}
		return nil
	})
	return out, database.MapError(err)
}

// ReconMatchInput confirms a match.
type ReconMatchInput struct {
	Kind              string      `json:"kind" enum:"statement_to_ledger,pending_to_posted,manual_to_imported"`
	AccountID         uuid.UUID   `json:"account_id"`
	StatementRowIDs   []uuid.UUID `json:"statement_row_ids,omitempty" maxItems:"20" doc:"statement_to_ledger: statement rows (any unmatched line of the account, e.g. from GET /accounts/{id}/statement-lines)"`
	TransactionIDs    []uuid.UUID `json:"transaction_ids" minItems:"1" maxItems:"20"`
	KeepTransactionID *uuid.UUID  `json:"keep_transaction_id,omitempty" doc:"manual_to_imported: the record to keep (the other is voided)"`
}

// ReconMatchDTO is a confirmed match.
type ReconMatchDTO struct {
	ID           uuid.UUID           `json:"id"`
	AccountID    uuid.UUID           `json:"account_id"`
	Kind         string              `json:"kind"`
	Cardinality  string              `json:"cardinality"`
	Status       string              `json:"status" enum:"suggested,confirmed,rejected,unmatched"`
	Confidence   *string             `json:"confidence,omitempty" doc:"The matcher's score (0–1); absent when the user matched records the matcher does not pair (dates_far_apart) or for one-to-many matches"`
	Reasons      []string            `json:"reasons" doc:"English; localize by reason_codes"`
	ReasonCodes  []string            `json:"reason_codes" enum:"same_amount_direction,same_date,one_day_apart,within_3_days,within_a_week,same_reference,similar_description,amounts_add_up,all_within_a_week,dates_far_apart,pending_replaced_by_posted,pending_amount_differs,entered_manually_and_imported" doc:"Stable reasons, in the order of reasons (empty only for matches confirmed before codes existed whose reasons were not recognized)"`
	ReasonParams map[string]string   `json:"reason_params" doc:"Values the codes refer to: days_apart (the largest date distance between the matched records); pending_amount_differs → pending_amount, posted_amount, currency. Empty for matches confirmed before codes existed"`
	Items        []ReconMatchItemDTO `json:"items"`
	ConfirmedAt  *time.Time          `json:"confirmed_at,omitempty"`
	UnmatchedAt  *time.Time          `json:"unmatched_at,omitempty"`
	CreatedAt    time.Time           `json:"created_at"`
	Total        *apitypes.Money     `json:"total,omitempty" doc:"The matched amount: the sum of the ledger records kept (effect none), which equals the statement side for statement_to_ledger"`
}

// ReconMatchItemDTO is one matched record, its current values and the
// effect the match applied to it.
type ReconMatchItemDTO struct {
	Side          string         `json:"side" enum:"statement,ledger"`
	ImportRowID   *uuid.UUID     `json:"import_row_id,omitempty"`
	TransactionID *uuid.UUID     `json:"transaction_id,omitempty"`
	Date          string         `json:"date" doc:"The statement row's date or the transaction's date"`
	Amount        apitypes.Money `json:"amount"`
	Direction     string         `json:"direction" enum:"inflow,outflow"`
	Description   *string        `json:"description,omitempty"`
	RecordStatus  string         `json:"record_status" enum:"parsed,invalid,duplicate,ready,imported,skipped,failed,draft,pending,posted,voided,reversed" doc:"Current status of the statement row (side statement) or transaction (side ledger), e.g. voided for the duplicate a match removed"`
	Source        *string        `json:"source,omitempty" enum:"manual,import,receipt,recurring,integration,correction,group,system" doc:"Side ledger: how the transaction was recorded"`
	Effect        string         `json:"effect" enum:"none,voided,row_skipped"`
	Active        bool           `json:"active"`
}

type txInfo struct {
	id                 uuid.UUID
	amount             int64
	dir, status, state string
	source             string
	date               time.Time
	desc               string
}

func loadTx(ctx context.Context, tx pgx.Tx, uid, acct, id uuid.UUID) (*txInfo, error) {
	var t txInfo
	err := tx.QueryRow(ctx, `select id, amount_minor, direction, status, reconciliation_state, source, local_date, coalesce(description, '')
		from transactions where id = $1 and user_id = $2 and account_id = $3 and deleted_at is null for update`, id, uid, acct).
		Scan(&t.id, &t.amount, &t.dir, &t.status, &t.state, &t.source, &t.date, &t.desc)
	if database.IsNoRows(err) {
		return nil, apperr.FieldError("body.transaction_ids", "Choose transactions of this account.")
	}
	return &t, err
}

// rowState is what an unmatch restores on a statement row besides its status.
const rowState = `jsonb_build_object('error_code', r.error_code, 'error_message', r.error_message, 'error_params', r.error_params,
	'duplicate_of_transaction_id', r.duplicate_of_transaction_id, 'duplicate_reason_codes', to_jsonb(r.duplicate_reason_codes),
	'user_decision', r.user_decision)`

// Confirm records a user-confirmed match and applies its effects. Any
// unmatched statement line and transactions of the account can be matched
// by hand; the matcher's suggestions are not required.
func (s *Service) Confirm(ctx context.Context, in ReconMatchInput) (*ReconMatchDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReconMatchDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		cur, _, err := ownAccount(ctx, tx, uid, in.AccountID)
		if err != nil {
			return err
		}
		seen := map[uuid.UUID]bool{}
		var txs []*txInfo
		for _, id := range in.TransactionIDs {
			if seen[id] {
				return apperr.FieldCode("body.transaction_ids", "duplicate_item", "Each transaction can appear once.", nil)
			}
			seen[id] = true
			t, err := loadTx(ctx, tx, uid, in.AccountID, id)
			if err != nil {
				return err
			}
			if t.state != "unreconciled" && in.Kind == "statement_to_ledger" {
				return apperr.ConflictCode("transaction_already_matched", "A transaction is already matched or reconciled.", nil)
			}
			txs = append(txs, t)
		}
		matchID := uuid.New()
		type it struct {
			side      string
			row, txID *uuid.UUID
			amount    int64
			effect    string
			prevRow   *string
			prevState *string
			rowState  []byte
		}
		var items []it
		var reasons []reconcile.Reason
		params := map[string]string{}
		var conf *string
		cardinality := "one_to_one"
		switch in.Kind {
		case "statement_to_ledger":
			if len(in.StatementRowIDs) == 0 {
				return apperr.FieldError("body.statement_row_ids", "Choose the statement rows.")
			}
			if len(in.StatementRowIDs) > 1 && len(txs) > 1 {
				return apperr.Rule("invalid_match_shape", "Match one statement row to several transactions, or several rows to one transaction.", nil)
			}
			var rowSum, txSum int64
			dir := txs[0].dir
			var firstRow reconcile.Item
			var rowDates []time.Time
			rowSeen := map[uuid.UUID]bool{}
			for _, rid := range in.StatementRowIDs {
				if rowSeen[rid] {
					return apperr.FieldCode("body.statement_row_ids", "duplicate_item", "Each statement row can appear once.", nil)
				}
				rowSeen[rid] = true
				var amt int64
				var d time.Time
				var rdir, status string
				var desc *string
				var state []byte
				if err := tx.QueryRow(ctx, `select r.amount_minor, r.posted_date, r.direction, r.status, r.description, `+rowState+`
					from import_rows r join import_batches b on b.id = r.batch_id where r.id = $1 and b.account_id = $2 and b.user_id = $3
					and r.transaction_id is null and r.amount_minor is not null for update of r`, rid, in.AccountID, uid).
					Scan(&amt, &d, &rdir, &status, &desc, &state); err != nil {
					if database.IsNoRows(err) {
						return apperr.FieldError("body.statement_row_ids", "Choose statement rows of this account that were not imported.")
					}
					return err
				}
				if rdir != dir {
					return apperr.Rule("direction_mismatch", "Statement rows and transactions must have the same direction.", nil)
				}
				if rowSum, err = money.Add(rowSum, amt); err != nil {
					return err
				}
				st := status
				r := rid
				items = append(items, it{side: "statement", row: &r, amount: amt, effect: "row_skipped", prevRow: &st, rowState: state})
				rowDates = append(rowDates, d)
				if firstRow.ID == "" {
					firstRow = reconcile.Item{ID: rid.String(), Date: d, AmountMinor: amt, Direction: rdir, Description: deref(desc)}
				}
			}
			far := 0
			for _, t := range txs {
				if t.dir != dir {
					return apperr.Rule("direction_mismatch", "Statement rows and transactions must have the same direction.", nil)
				}
				if txSum, err = money.Add(txSum, t.amount); err != nil {
					return err
				}
				st, id := t.state, t.id
				items = append(items, it{side: "ledger", txID: &id, amount: t.amount, effect: "none", prevState: &st})
				for _, d := range rowDates {
					far = max(far, reconcile.DaysApart(d, t.date))
				}
			}
			if rowSum != txSum {
				return apperr.Rule("sums_differ", "The statement side ("+money.Format(rowSum, cur)+") and ledger side ("+money.Format(txSum, cur)+") must add up to the same amount.",
					map[string]string{"statement": money.Format(rowSum, cur), "ledger": money.Format(txSum, cur), "currency": cur})
			}
			switch {
			case len(in.StatementRowIDs) == 1 && len(txs) > 1:
				cardinality = "one_to_many"
			case len(in.StatementRowIDs) > 1:
				cardinality = "many_to_one"
			}
			params["days_apart"] = strconv.Itoa(far)
			if cardinality == "one_to_one" {
				score, why := reconcile.Score(firstRow, reconcile.Item{ID: txs[0].id.String(), Date: txs[0].date, AmountMinor: txs[0].amount,
					Direction: txs[0].dir, Description: txs[0].desc})
				if score > 0 {
					c := confidence(score)
					conf, reasons = &c, why
				} else {
					// Chosen by hand: the matcher pairs records at most a week apart.
					reasons = []reconcile.Reason{{Code: reconcile.ReasonSameAmountDirection, Text: "Same amount and direction"},
						{Code: reasonDatesFarApart, Text: "More than a week apart (matched by you)"}}
				}
			} else {
				reasons = []reconcile.Reason{{Code: reconcile.ReasonAmountsAddUp, Text: "Amounts add up exactly"}}
			}
		case "pending_to_posted":
			if len(txs) != 2 {
				return apperr.FieldError("body.transaction_ids", "Choose the pending and the posted transaction.")
			}
			pend, post := txs[0], txs[1]
			if pend.status != "pending" {
				pend, post = post, pend
			}
			if pend.status != "pending" || post.status != "posted" || pend.dir != post.dir {
				return apperr.Rule("invalid_pair", "Choose one pending and one posted transaction in the same direction.", nil)
			}
			pid, qid := pend.id, post.id
			ps, qs := pend.state, post.state
			items = append(items, it{side: "ledger", txID: &pid, amount: pend.amount, effect: "voided", prevState: &ps},
				it{side: "ledger", txID: &qid, amount: post.amount, effect: "none", prevState: &qs})
			reasons = []reconcile.Reason{{Code: reasonPendingReplaced, Text: "Pending authorization replaced by the posted transaction"}}
			if pend.amount != post.amount {
				reasons = append(reasons, reconcile.Reason{Code: reasonPendingAmountDiffers,
					Text: "Amounts differ (" + money.Format(pend.amount, cur) + " pending, " + money.Format(post.amount, cur) + " posted)"})
				params["pending_amount"], params["posted_amount"], params["currency"] = money.Format(pend.amount, cur), money.Format(post.amount, cur), cur
			}
			params["days_apart"] = strconv.Itoa(reconcile.DaysApart(pend.date, post.date))
		case "manual_to_imported":
			if len(txs) != 2 || in.KeepTransactionID == nil || (txs[0].id != *in.KeepTransactionID && txs[1].id != *in.KeepTransactionID) {
				return apperr.FieldError("body.keep_transaction_id", "Choose two transactions and which one to keep.")
			}
			if txs[0].amount != txs[1].amount || txs[0].dir != txs[1].dir || (txs[0].source == "import") == (txs[1].source == "import") {
				return apperr.Rule("invalid_pair", "Choose one imported and one manually entered transaction with the same amount and direction.", nil)
			}
			for _, t := range txs {
				id, st := t.id, t.state
				effect := "voided"
				if t.id == *in.KeepTransactionID {
					effect = "none"
				}
				items = append(items, it{side: "ledger", txID: &id, amount: t.amount, effect: effect, prevState: &st})
			}
			reasons = []reconcile.Reason{{Code: reasonEnteredTwice, Text: "The same transaction was entered manually and imported"}}
			params["days_apart"] = strconv.Itoa(reconcile.DaysApart(txs[0].date, txs[1].date))
		default:
			return apperr.BadRequest("Unknown match kind.")
		}
		rj, err := json.Marshal(reconcile.Texts(reasons))
		if err != nil {
			return err
		}
		pj, err := json.Marshal(params)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into reconciliation_matches (id, user_id, account_id, kind, cardinality, status, confidence, reasons,
			reason_codes, reason_params, created_by, confirmed_at) values ($1,$2,$3,$4,$5,'confirmed',$6::numeric,$7::jsonb,$8,$9::jsonb,'user',now())`,
			matchID, uid, in.AccountID, in.Kind, cardinality, conf, rj, reconcile.Codes(reasons), pj); err != nil {
			return err
		}
		for _, x := range items {
			if _, err := tx.Exec(ctx, `insert into reconciliation_match_items (match_id, user_id, side, import_row_id, transaction_id, amount_minor,
				effect, prev_row_status, prev_reconciliation_state, prev_row_state) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb)`,
				matchID, uid, x.side, x.row, x.txID, x.amount, x.effect, x.prevRow, x.prevState, x.rowState); err != nil {
				if database.IsUniqueViolation(err, "reconciliation_items_active_tx_key") || database.IsUniqueViolation(err, "reconciliation_items_active_row_key") {
					return apperr.New(apperr.CodeDuplicate, 409, "A record is already part of another match.")
				}
				return err
			}
			switch {
			case x.effect == "voided":
				if err := s.Finance.VoidInTx(ctx, tx, uid, *x.txID); err != nil {
					return err
				}
			case x.txID != nil:
				if _, err := tx.Exec(ctx, `update transactions set reconciliation_state = 'matched' where id = $1`, *x.txID); err != nil {
					return err
				}
			case x.row != nil:
				var dupOf *uuid.UUID
				for _, y := range items {
					if y.txID != nil {
						dupOf = y.txID
						break
					}
				}
				if _, err := tx.Exec(ctx, `update import_rows set status = 'skipped', user_decision = 'skip', error_code = 'reconciled',
					error_message = 'Matched to an existing transaction.', error_params = null, duplicate_of_transaction_id = $2,
					duplicate_reason_codes = null where id = $1`, *x.row, dupOf); err != nil {
					return err
				}
			}
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "reconciliation_match", EntityID: &matchID,
			Action: "confirmed", Changes: map[string]any{"kind": in.Kind, "cardinality": cardinality, "statement_row_ids": in.StatementRowIDs,
				"transaction_ids": in.TransactionIDs, "reason_codes": reconcile.Codes(reasons)}}); err != nil {
			return err
		}
		ms, err := loadMatches(ctx, tx, []uuid.UUID{matchID}, cur)
		if err != nil {
			return err
		}
		out = &ms[0]
		return nil
	})
	return out, database.MapError(err)
}

const matchCols = `m.id, m.account_id, m.kind, m.cardinality, m.status, m.confidence::text, m.reasons, m.reason_codes, m.reason_params,
	m.confirmed_at, m.unmatched_at, m.created_at`

// loadMatches loads matches with their items, in the order of ids.
func loadMatches(ctx context.Context, tx pgx.Tx, ids []uuid.UUID, cur string) ([]ReconMatchDTO, error) {
	out := make([]ReconMatchDTO, 0, len(ids))
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := tx.Query(ctx, `select `+matchCols+` from reconciliation_matches m where m.id = any($1)`, ids)
	if err != nil {
		return nil, err
	}
	found := map[uuid.UUID]*ReconMatchDTO{}
	list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (ReconMatchDTO, error) {
		var m ReconMatchDTO
		err := r.Scan(&m.ID, &m.AccountID, &m.Kind, &m.Cardinality, &m.Status, &m.Confidence, &m.Reasons, &m.ReasonCodes, &m.ReasonParams,
			&m.ConfirmedAt, &m.UnmatchedAt, &m.CreatedAt)
		return m, err
	})
	if err != nil {
		return nil, err
	}
	for i := range list {
		m := &list[i]
		if m.Reasons == nil {
			m.Reasons = []string{}
		}
		if m.ReasonCodes == nil {
			m.ReasonCodes = []string{}
		}
		if m.ReasonParams == nil {
			m.ReasonParams = map[string]string{}
		}
		m.Items = []ReconMatchItemDTO{}
		found[m.ID] = m
	}
	items, err := tx.Query(ctx, `select i.match_id, i.side, i.import_row_id, i.transaction_id, i.amount_minor, i.effect, i.active,
		coalesce(r.posted_date, t.local_date), coalesce(r.direction, t.direction),
		case when i.import_row_id is not null then r.description
			else nullif(btrim(coalesce(mm.name || ' ', '') || coalesce(t.description, '')), '') end,
		coalesce(r.status, t.status), t.source
		from reconciliation_match_items i
		left join import_rows r on r.id = i.import_row_id
		left join transactions t on t.id = i.transaction_id
		left join merchants mm on mm.id = t.merchant_id
		where i.match_id = any($1) order by i.match_id, i.side desc, i.amount_minor desc, i.id`, ids)
	if err != nil {
		return nil, err
	}
	defer items.Close()
	totals := map[uuid.UUID]int64{}
	for items.Next() {
		var x ReconMatchItemDTO
		var matchID uuid.UUID
		var amt int64
		var d *time.Time
		var dir, status *string
		if err := items.Scan(&matchID, &x.Side, &x.ImportRowID, &x.TransactionID, &amt, &x.Effect, &x.Active, &d, &dir, &x.Description,
			&status, &x.Source); err != nil {
			return nil, err
		}
		m := found[matchID]
		if m == nil {
			continue
		}
		x.Amount, x.Direction, x.RecordStatus = apitypes.M(amt, cur), deref(dir), deref(status)
		if d != nil {
			x.Date = finance.LocalDateString(*d)
		}
		if x.Side == "ledger" && x.Effect == "none" {
			if totals[matchID], err = money.Add(totals[matchID], amt); err != nil {
				return nil, err
			}
		}
		m.Items = append(m.Items, x)
	}
	if err := items.Err(); err != nil {
		return nil, err
	}
	for _, id := range ids {
		m := found[id]
		if m == nil {
			return nil, apperr.NotFound("match")
		}
		total := apitypes.M(totals[id], cur)
		m.Total = &total
		out = append(out, *m)
	}
	return out, nil
}

type matchCursor struct {
	At time.Time `json:"t"`
	ID uuid.UUID `json:"i"`
}

// ListMatches lists an account's matches, newest first, a page at a time.
func (s *Service) ListMatches(ctx context.Context, acct uuid.UUID, cursor string, limit int) ([]ReconMatchDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 200 {
		limit = 200
	}
	var at *time.Time
	var after *uuid.UUID
	if cursor != "" {
		var c matchCursor
		if err := httpx.DecodeCursor(cursor, &c); err != nil {
			return nil, "", err
		}
		at, after = &c.At, &c.ID
	}
	out := []ReconMatchDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		cur, _, err := ownAccount(ctx, tx, uid, acct)
		if err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select m.id from reconciliation_matches m where m.account_id = $1 and m.user_id = $2
			and ($3::timestamptz is null or (m.created_at, m.id) < ($3, $4)) order by m.created_at desc, m.id desc limit $5`,
			acct, uid, at, after, limit+1)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		more := len(ids) > limit
		if more {
			ids = ids[:limit]
		}
		if out, err = loadMatches(ctx, tx, ids, cur); err != nil {
			return err
		}
		if more {
			last := out[len(out)-1]
			next, err = httpx.EncodeCursor(matchCursor{At: last.CreatedAt, ID: last.ID})
		}
		return err
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	return out, next, nil
}

// Unmatch reverts a confirmed match: voided records are restored, skipped
// statement rows return to their previous status, reason and decision, and
// transaction reconciliation states are restored.
func (s *Service) Unmatch(ctx context.Context, id uuid.UUID) (*ReconMatchDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *ReconMatchDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var acct uuid.UUID
		var status string
		if err := tx.QueryRow(ctx, `select account_id, status from reconciliation_matches where id = $1 and user_id = $2 for update`, id, uid).
			Scan(&acct, &status); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("match")
			}
			return err
		}
		if status != "confirmed" {
			return apperr.Conflict("Only confirmed matches can be undone.")
		}
		cur, _, err := ownAccount(ctx, tx, uid, acct)
		if err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select id, import_row_id, transaction_id, effect, prev_row_status, prev_reconciliation_state, prev_row_state
			from reconciliation_match_items where match_id = $1 and active`, id)
		if err != nil {
			return err
		}
		type it struct {
			id              uuid.UUID
			row, txID       *uuid.UUID
			effect          string
			prevRow, prevSt *string
			rowState        []byte
		}
		list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (it, error) {
			var x it
			err := r.Scan(&x.id, &x.row, &x.txID, &x.effect, &x.prevRow, &x.prevSt, &x.rowState)
			return x, err
		})
		if err != nil {
			return err
		}
		for _, x := range list {
			if x.effect == "voided" && x.txID != nil {
				if err := s.Finance.RestoreInTx(ctx, tx, uid, *x.txID); err != nil {
					return err
				}
			}
			if x.txID != nil {
				st := "unreconciled"
				if x.prevSt != nil {
					st = *x.prevSt
				}
				if _, err := tx.Exec(ctx, `update transactions set reconciliation_state = $2 where id = $1`, *x.txID, st); err != nil {
					return err
				}
			}
			if x.row != nil {
				st := "duplicate"
				if x.prevRow != nil {
					st = *x.prevRow
				}
				// The row's reason, values, duplicate link and the user's
				// decision come back as they were. Matches recorded before
				// that state was kept clear the reason and decision, as before.
				if _, err := tx.Exec(ctx, `update import_rows set status = $2, user_decision = $3::jsonb->>'user_decision',
					error_code = $3::jsonb->>'error_code', error_message = $3::jsonb->>'error_message',
					error_params = case when jsonb_typeof($3::jsonb->'error_params') = 'object' then $3::jsonb->'error_params' end,
					duplicate_of_transaction_id = case when $3::jsonb is null then duplicate_of_transaction_id
						else (select t.id from transactions t where t.id = ($3::jsonb->>'duplicate_of_transaction_id')::uuid) end,
					duplicate_reason_codes = case when jsonb_typeof($3::jsonb->'duplicate_reason_codes') = 'array'
						then array(select jsonb_array_elements_text($3::jsonb->'duplicate_reason_codes')) end
					where id = $1`, *x.row, st, x.rowState); err != nil {
					return err
				}
			}
			if _, err := tx.Exec(ctx, `update reconciliation_match_items set active = false where id = $1`, x.id); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `update reconciliation_matches set status = 'unmatched', unmatched_at = now() where id = $1`, id); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "reconciliation_match", EntityID: &id, Action: "unmatched"}); err != nil {
			return err
		}
		ms, err := loadMatches(ctx, tx, []uuid.UUID{id}, cur)
		if err != nil {
			return err
		}
		out = &ms[0]
		return nil
	})
	return out, database.MapError(err)
}

// ReconBalanceInput reconciles an account against a statement balance.
type ReconBalanceInput struct {
	StatementDate    string     `json:"statement_date" doc:"YYYY-MM-DD"`
	StatementBalance string     `json:"statement_balance" doc:"Signed decimal"`
	BalanceKind      string     `json:"balance_kind,omitempty" enum:"balance,amount_owed" doc:"amount_owed for credit cards/loans: a positive amount you owe"`
	ImportBatchID    *uuid.UUID `json:"import_batch_id,omitempty"`
	Notes            string     `json:"notes,omitempty" maxLength:"1000"`
}

// ReconBalanceDTO is one reconciliation result.
type ReconBalanceDTO struct {
	ID                 uuid.UUID      `json:"id"`
	AccountID          uuid.UUID      `json:"account_id"`
	StatementDate      string         `json:"statement_date"`
	StatementBalance   apitypes.Money `json:"statement_balance" doc:"In Montra's sign convention"`
	LedgerBalance      apitypes.Money `json:"ledger_balance"`
	Difference         apitypes.Money `json:"difference" doc:"statement − ledger"`
	Status             string         `json:"status" enum:"balanced,unbalanced"`
	ReconciledCount    int            `json:"reconciled_count" doc:"Transactions marked reconciled (balanced only). Stored with the history"`
	UnmatchedRows      int            `json:"unmatched_statement_rows" doc:"Lines of import_batch_id neither imported nor matched (the statement-lines unmatched set; 0 without import_batch_id). Stored with the history (0 for reconciliations recorded before it was stored)"`
	UnreconciledLedger int            `json:"unreconciled_transactions" doc:"Posted transactions up to the statement date still unreconciled. Stored with the history (0 for reconciliations recorded before it was stored)"`
	ImportBatchID      *uuid.UUID     `json:"import_batch_id,omitempty"`
	Notes              *string        `json:"notes,omitempty"`
	CreatedAt          time.Time      `json:"created_at"`
}

// Reconcile compares the statement balance with the ledger as of the date;
// when balanced, transactions up to that date are marked reconciled and the
// account's last_reconciled_at / last_reconciled_balance follow the latest
// statement date reconciled. What it found is kept with the history.
func (s *Service) Reconcile(ctx context.Context, acct uuid.UUID, in ReconBalanceInput) (*ReconBalanceDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out ReconBalanceDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		cur, liability, err := lockOwnAccount(ctx, tx, uid, acct)
		if err != nil {
			return err
		}
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		d, err := finance.ParseDate("body.statement_date", in.StatementDate, u.Loc)
		if err != nil {
			return err
		}
		stmt, err := money.Parse(in.StatementBalance, cur, money.ParseOptions{AllowNegative: true, AllowZero: true})
		if err != nil {
			return apperr.FieldError("body.statement_balance", "Enter the balance in "+cur+" precision.")
		}
		if in.BalanceKind == "amount_owed" {
			if !liability {
				return apperr.FieldError("body.balance_kind", "amount_owed applies to credit cards and loans.")
			}
			stmt = -stmt
		}
		var ledger int64
		if err := tx.QueryRow(ctx, `select coalesce(sum(amount_minor), 0)::bigint from account_ledger_entries where account_id = $1 and effective_date <= $2`,
			acct, d).Scan(&ledger); err != nil {
			return err
		}
		diff, err := money.Sub(stmt, ledger)
		if err != nil {
			return err
		}
		status := "unbalanced"
		if diff == 0 {
			status = "balanced"
		}
		if in.ImportBatchID != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from import_batches where id = $1 and account_id = $2 and user_id = $3)`,
				*in.ImportBatchID, acct, uid).Scan(&ok); err != nil || !ok {
				return apperr.FieldError("body.import_batch_id", "Choose an import of this account.")
			}
			if err := tx.QueryRow(ctx, `select count(*) from import_rows r where r.batch_id = $1 and `+unmatchedLine,
				*in.ImportBatchID).Scan(&out.UnmatchedRows); err != nil {
				return err
			}
		}
		if status == "balanced" {
			tag, err := tx.Exec(ctx, `update transactions set reconciliation_state = 'reconciled' where account_id = $1 and deleted_at is null
				and status = 'posted' and local_date <= $2 and reconciliation_state in ('unreconciled','matched')`, acct, d)
			if err != nil {
				return err
			}
			out.ReconciledCount = int(tag.RowsAffected())
		}
		if err := tx.QueryRow(ctx, `select count(*) from transactions where account_id = $1 and deleted_at is null and status = 'posted'
			and local_date <= $2 and reconciliation_state = 'unreconciled'`, acct, d).Scan(&out.UnreconciledLedger); err != nil {
			return err
		}
		id := uuid.New()
		notes := strings.TrimSpace(in.Notes)
		var np *string
		if notes != "" {
			np = &notes
		}
		if err := tx.QueryRow(ctx, `insert into account_reconciliations (id, user_id, account_id, statement_date, statement_balance_minor,
			ledger_balance_minor, difference_minor, status, import_batch_id, notes, reconciled_count, unmatched_statement_rows,
			unreconciled_transactions) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) returning created_at`,
			id, uid, acct, d, stmt, ledger, diff, status, in.ImportBatchID, np, out.ReconciledCount, out.UnmatchedRows, out.UnreconciledLedger).
			Scan(&out.CreatedAt); err != nil {
			return err
		}
		if status == "balanced" {
			// The account shows its latest reconciled statement: an older
			// statement reconciled afterwards does not move it back. System
			// bookkeeping (not user-editable), so the version is not bumped
			// and the owner's edits of the account never conflict with it.
			if _, err := tx.Exec(ctx, `update financial_accounts set last_reconciled_at = $3, last_reconciled_balance_minor = $4
				where id = $1 and user_id = $2 and not exists (select 1 from account_reconciliations r where r.account_id = $1
				and r.status = 'balanced' and r.statement_date > $5)`, acct, uid, out.CreatedAt, stmt, d); err != nil {
				return err
			}
		}
		out.ID, out.AccountID, out.StatementDate, out.Status, out.ImportBatchID, out.Notes = id, acct, finance.LocalDateString(d), status, in.ImportBatchID, np
		out.StatementBalance, out.LedgerBalance, out.Difference = apitypes.M(stmt, cur), apitypes.M(ledger, cur), apitypes.M(diff, cur)
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "account_reconciliation", EntityID: &id, Action: status,
			Changes: map[string]any{"account_id": acct, "reconciled": out.ReconciledCount, "unmatched_statement_rows": out.UnmatchedRows,
				"unreconciled_transactions": out.UnreconciledLedger}})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

type balanceCursor struct {
	Date string    `json:"d"`
	At   time.Time `json:"t"`
	ID   uuid.UUID `json:"i"`
}

// ListBalances returns an account's reconciliation history, latest
// statement first, a page at a time.
func (s *Service) ListBalances(ctx context.Context, acct uuid.UUID, cursor string, limit int) ([]ReconBalanceDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	var date *string
	var at *time.Time
	var after *uuid.UUID
	if cursor != "" {
		var c balanceCursor
		if err := httpx.DecodeCursor(cursor, &c); err != nil {
			return nil, "", err
		}
		if _, err := time.Parse("2006-01-02", c.Date); err != nil {
			return nil, "", apperr.FieldError("query.cursor", "Invalid cursor. Start again from the first page.")
		}
		date, at, after = &c.Date, &c.At, &c.ID
	}
	out := []ReconBalanceDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		cur, _, err := ownAccount(ctx, tx, uid, acct)
		if err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select id, statement_date, statement_balance_minor, ledger_balance_minor, difference_minor, status, import_batch_id,
			notes, created_at, coalesce(reconciled_count, 0), coalesce(unmatched_statement_rows, 0), coalesce(unreconciled_transactions, 0)
			from account_reconciliations where account_id = $1 and user_id = $2
			and ($3::date is null or (statement_date, created_at, id) < ($3::date, $4, $5))
			order by statement_date desc, created_at desc, id desc limit $6`, acct, uid, date, at, after, limit+1)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (ReconBalanceDTO, error) {
			var b ReconBalanceDTO
			var d time.Time
			var st, lg, df int64
			if err := r.Scan(&b.ID, &d, &st, &lg, &df, &b.Status, &b.ImportBatchID, &b.Notes, &b.CreatedAt, &b.ReconciledCount, &b.UnmatchedRows,
				&b.UnreconciledLedger); err != nil {
				return b, err
			}
			b.AccountID, b.StatementDate = acct, finance.LocalDateString(d)
			b.StatementBalance, b.LedgerBalance, b.Difference = apitypes.M(st, cur), apitypes.M(lg, cur), apitypes.M(df, cur)
			return b, nil
		})
		if err != nil {
			return err
		}
		if len(out) > limit {
			out = out[:limit]
			last := out[limit-1]
			next, err = httpx.EncodeCursor(balanceCursor{Date: last.StatementDate, At: last.CreatedAt, ID: last.ID})
		}
		return err
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	return out, next, nil
}

// StatementLineDTO is one statement row of an account's imports, for
// matching by hand.
type StatementLineDTO struct {
	ImportRowID              uuid.UUID      `json:"import_row_id"`
	BatchID                  uuid.UUID      `json:"batch_id"`
	RowNumber                int32          `json:"row_number" doc:"Line (CSV), sheet row (XLSX) or record (OFX) in the original file"`
	Date                     string         `json:"date"`
	Amount                   apitypes.Money `json:"amount"`
	Direction                string         `json:"direction" enum:"inflow,outflow"`
	Description              *string        `json:"description,omitempty"`
	Reference                *string        `json:"reference,omitempty"`
	RecordStatus             string         `json:"record_status" enum:"duplicate,skipped,ready,failed" doc:"The row's import status"`
	ErrorCode                *string        `json:"error_code,omitempty" doc:"The row's reason, as on GET /imports/{id}/rows (reconciled while matched)"`
	DuplicateOfTransactionID *uuid.UUID     `json:"duplicate_of_transaction_id,omitempty"`
	MatchID                  *uuid.UUID     `json:"match_id,omitempty" doc:"status=matched: the confirmed match (DELETE /reconciliation/matches/{id} undoes it)"`
}

type lineCursor struct {
	Date string    `json:"d"`
	Row  int32     `json:"n"`
	ID   uuid.UUID `json:"i"`
}

// StatementLines lists an account's statement lines that are unmatched
// (neither imported nor matched: the lines to match by hand) or matched,
// oldest first, a page at a time. Owner only.
func (s *Service) StatementLines(ctx context.Context, acct uuid.UUID, status string, batch *uuid.UUID, cursor string, limit int) ([]StatementLineDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	filter := unmatchedLine
	switch status {
	case "", "unmatched":
	case "matched":
		filter = `exists (select 1 from reconciliation_match_items i where i.import_row_id = r.id and i.active)`
	default:
		return nil, "", apperr.FieldError("query.status", "Use unmatched or matched.")
	}
	var date *string
	var row *int32
	var after *uuid.UUID
	if cursor != "" {
		var c lineCursor
		if err := httpx.DecodeCursor(cursor, &c); err != nil {
			return nil, "", err
		}
		if _, err := time.Parse("2006-01-02", c.Date); err != nil {
			return nil, "", apperr.FieldError("query.cursor", "Invalid cursor. Start again from the first page.")
		}
		date, row, after = &c.Date, &c.Row, &c.ID
	}
	out := []StatementLineDTO{}
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		cur, _, err := ownAccount(ctx, tx, uid, acct)
		if err != nil {
			return err
		}
		if batch != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from import_batches where id = $1 and account_id = $2 and user_id = $3)`,
				*batch, acct, uid).Scan(&ok); err != nil {
				return err
			}
			if !ok {
				return apperr.FieldError("query.batch_id", "Choose an import of this account.")
			}
		}
		rows, err := tx.Query(ctx, `select r.id, r.batch_id, r.row_number, r.posted_date, r.amount_minor, r.direction, r.description, r.reference,
			r.status, r.error_code, r.duplicate_of_transaction_id,
			(select i.match_id from reconciliation_match_items i where i.import_row_id = r.id and i.active)
			from import_rows r join import_batches b on b.id = r.batch_id
			where b.account_id = $1 and b.user_id = $2 and ($3::uuid is null or b.id = $3) and r.posted_date is not null
			and r.amount_minor is not null and `+filter+`
			and ($4::date is null or (r.posted_date, r.row_number, r.id) > ($4::date, $5, $6))
			order by r.posted_date, r.row_number, r.id limit $7`, acct, uid, batch, date, row, after, limit+1)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (StatementLineDTO, error) {
			var l StatementLineDTO
			var d time.Time
			var amt int64
			if err := r.Scan(&l.ImportRowID, &l.BatchID, &l.RowNumber, &d, &amt, &l.Direction, &l.Description, &l.Reference, &l.RecordStatus,
				&l.ErrorCode, &l.DuplicateOfTransactionID, &l.MatchID); err != nil {
				return l, err
			}
			l.Date, l.Amount = finance.LocalDateString(d), apitypes.M(amt, cur)
			return l, nil
		})
		if err != nil {
			return err
		}
		if len(out) > limit {
			out = out[:limit]
			last := out[limit-1]
			next, err = httpx.EncodeCursor(lineCursor{Date: last.Date, Row: last.RowNumber, ID: last.ImportRowID})
		}
		return err
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	return out, next, nil
}
