package recurring

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
)

// BillInput creates or replaces a bill (spec §4.7: due date, expected
// amount, provider, frequency, payment account, document, reminder).
type BillInput struct {
	Name             string     `json:"name" minLength:"1" maxLength:"120"`
	ProviderName     string     `json:"provider_name,omitempty" maxLength:"120"`
	CategoryID       *uuid.UUID `json:"category_id,omitempty"`
	ExpectedAmount   string     `json:"expected_amount,omitempty" doc:"Decimal; omit for variable bills"`
	AmountIsVariable bool       `json:"amount_is_variable,omitempty"`
	Currency         string     `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Defaults to the payment account's currency, then your base currency"`
	PaymentAccountID *uuid.UUID `json:"payment_account_id,omitempty"`
	DocumentFileID   *uuid.UUID `json:"document_file_id,omitempty" doc:"An uploaded bill_document file you own"`
	Notes            string     `json:"notes,omitempty" maxLength:"2000"`
	Schedule
	Status  string `json:"status,omitempty" enum:"active,paused,archived" doc:"Updates only"`
	Version int32  `json:"version,omitempty" doc:"Required for updates"`
}

func (in BillInput) spec() ruleSpec {
	variable := in.AmountIsVariable || strings.TrimSpace(in.ExpectedAmount) == ""
	return ruleSpec{Kind: "bill", Name: in.Name, Schedule: in.Schedule, Amount: in.ExpectedAmount, Currency: in.Currency,
		AmountIsVariable: variable, AccountID: in.PaymentAccountID, CategoryID: in.CategoryID, MerchantName: in.ProviderName, Notes: in.Notes}
}

// BillDTO is a bill with its schedule and current payment state.
type BillDTO struct {
	ID               uuid.UUID        `json:"id"`
	Name             string           `json:"name"`
	ProviderName     *string          `json:"provider_name,omitempty"`
	CategoryID       *uuid.UUID       `json:"category_id,omitempty"`
	ExpectedAmount   *apitypes.Money  `json:"expected_amount,omitempty"`
	AmountIsVariable bool             `json:"amount_is_variable"`
	Currency         string           `json:"currency"`
	PaymentAccountID *uuid.UUID       `json:"payment_account_id,omitempty"`
	DocumentFileID   *uuid.UUID       `json:"document_file_id,omitempty"`
	Notes            *string          `json:"notes,omitempty"`
	Status           string           `json:"status" enum:"active,paused,archived"`
	State            string           `json:"state" enum:"overdue,due_today,due_soon,paid,upcoming,paused,archived,ended" doc:"Payment state of the current cycle; never paid merely because a date passed"`
	NextDue          *OccurrenceDTO   `json:"next_due,omitempty" doc:"Oldest unpaid occurrence"`
	LastPaid         *OccurrenceDTO   `json:"last_paid,omitempty"`
	Schedule         RecurringRuleDTO `json:"schedule"`
	Owned            bool             `json:"owned"`
	Version          int32            `json:"version"`
	CreatedAt        time.Time        `json:"created_at"`
}

// BillDetail adds the occurrence history.
type BillDetail struct {
	BillDTO
	Occurrences []OccurrenceDTO `json:"occurrences" doc:"Newest first, with linked payment transactions"`
}

const billCols = `id, name, provider_name, category_id, expected_amount_minor, amount_is_variable, currency, payment_account_id,
	document_file_id, notes, status, version, created_at, user_id, recurring_rule_id`

func (s *Service) loadBill(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (*BillDTO, error) {
	var b BillDTO
	var expected *int64
	var owner, ruleID uuid.UUID
	err := tx.QueryRow(ctx, `select `+billCols+` from bills where id = $1`, id).Scan(&b.ID, &b.Name, &b.ProviderName, &b.CategoryID, &expected,
		&b.AmountIsVariable, &b.Currency, &b.PaymentAccountID, &b.DocumentFileID, &b.Notes, &b.Status, &b.Version, &b.CreatedAt, &owner, &ruleID)
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("bill")
	}
	if err != nil {
		return nil, err
	}
	b.Owned = owner == me
	b.ExpectedAmount = apitypes.MP(expected, b.Currency)
	r, err := s.getRule(ctx, tx, me, ruleID)
	if err != nil {
		return nil, err
	}
	b.Schedule = *r
	loc, err := time.LoadLocation(r.Timezone)
	if err != nil {
		loc = time.UTC
	}
	today := localToday(s.now(), loc)
	open, err := queryOccs(ctx, tx, `o.rule_id = $1 and o.status in ('scheduled','overdue') order by coalesce(o.postponed_to, o.occurrence_date) limit 1`, ruleID)
	if err != nil {
		return nil, err
	}
	paid, err := queryOccs(ctx, tx, `o.rule_id = $1 and o.status in ('paid','posted') order by coalesce(o.postponed_to, o.occurrence_date) desc limit 1`, ruleID)
	if err != nil {
		return nil, err
	}
	if len(open) > 0 {
		b.NextDue = &open[0]
	}
	if len(paid) > 0 {
		b.LastPaid = &paid[0]
	}
	// The current cycle is the latest occurrence due by the end of the
	// reminder window (so paying an upcoming bill early shows as paid).
	window := reminderWindow(b.Schedule.ReminderDaysBefore)
	var currentStatus *string
	if err := tx.QueryRow(ctx, `select status from recurring_occurrences where rule_id = $1 and status <> 'skipped'
		and coalesce(postponed_to, occurrence_date) <= $2 order by coalesce(postponed_to, occurrence_date) desc limit 1`,
		ruleID, today.AddDate(0, 0, window)).Scan(&currentStatus); err != nil && !database.IsNoRows(err) {
		return nil, err
	}
	b.State = billState(&b, today, window, currentStatus)
	return &b, nil
}

func reminderWindow(days []int16) int {
	window := 3
	for _, d := range days {
		window = max(window, int(d))
	}
	return window
}

func billState(b *BillDTO, today time.Time, window int, current *string) string {
	switch b.Status {
	case "archived", "paused":
		return b.Status
	}
	if b.NextDue != nil {
		due, _ := time.Parse("2006-01-02", b.NextDue.EffectiveDate)
		switch {
		case b.NextDue.Status == "overdue" || due.Before(today):
			return "overdue"
		case due.Equal(today):
			return "due_today"
		case !due.After(today.AddDate(0, 0, window)):
			return "due_soon"
		}
	}
	if current != nil && (*current == "paid" || *current == "posted") {
		return "paid"
	}
	if b.Schedule.Status == "ended" && b.NextDue == nil {
		return "ended"
	}
	return "upcoming"
}

func (s *Service) checkBillDocument(ctx context.Context, tx pgx.Tx, uid uuid.UUID, fileID *uuid.UUID) error {
	if fileID == nil {
		return nil
	}
	var ok bool
	if err := tx.QueryRow(ctx, `select exists (select 1 from files where id = $1 and owner_user_id = $2 and purpose = 'bill_document'
		and status = 'ready')`, *fileID, uid).Scan(&ok); err != nil {
		return err
	}
	if !ok {
		return apperr.FieldError("body.document_file_id", "Upload the bill document first (purpose bill_document).")
	}
	return nil
}

// CreateBill creates a bill with its schedule. A retry with the same
// Idempotency-Key returns the bill created first.
func (s *Service) CreateBill(ctx context.Context, key string, in BillInput) (*BillDetail, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var out BillDetail
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "bill.create", in, func() (BillDetail, error) {
			if err := caps.Check(ctx, tx, uid, "bills", openBillsQ, caps.OpenBills); err != nil {
				return BillDetail{}, err
			}
			if err := caps.Check(ctx, tx, uid, "recurring_rules", openRulesQ, caps.OpenRecurringRules); err != nil {
				return BillDetail{}, err
			}
			x, err := s.validate(ctx, tx, uid, in.spec())
			if err != nil {
				return BillDetail{}, billFieldNames(err)
			}
			if err := s.checkBillDocument(ctx, tx, uid, in.DocumentFileID); err != nil {
				return BillDetail{}, err
			}
			ruleID, err := s.insertRule(ctx, tx, uid, x)
			if err != nil {
				return BillDetail{}, err
			}
			id := uuid.New()
			if _, err := tx.Exec(ctx, `insert into bills (id, user_id, name, provider_name, category_id, expected_amount_minor, amount_is_variable,
				currency, payment_account_id, recurring_rule_id, document_file_id, notes) values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
				id, uid, x.Name, trim(in.ProviderName, 120), x.CategoryID, x.amount, x.AmountIsVariable, *x.Currency, x.AccountID, ruleID,
				in.DocumentFileID, x.Notes); err != nil {
				return BillDetail{}, err
			}
			if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "bill", EntityID: &id, Action: "created"}); err != nil {
				return BillDetail{}, err
			}
			d, err := s.billDetail(ctx, tx, uid, id)
			if err != nil {
				return BillDetail{}, err
			}
			return *d, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

func (s *Service) billDetail(ctx context.Context, tx pgx.Tx, me, id uuid.UUID) (*BillDetail, error) {
	b, err := s.loadBill(ctx, tx, me, id)
	if err != nil {
		return nil, err
	}
	occ, err := queryOccs(ctx, tx, `o.rule_id = $1 order by o.occurrence_date desc limit 60`, b.Schedule.ID)
	if err != nil {
		return nil, err
	}
	return &BillDetail{BillDTO: *b, Occurrences: occ}, nil
}

// ListBills lists bills (active and paused by default).
func (s *Service) ListBills(ctx context.Context, status string) ([]BillDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []BillDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id from bills where ($1 = 'all' or ($1 = '' and status <> 'archived') or status = $1) order by name`, status)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, id := range ids {
			b, err := s.loadBill(ctx, tx, uid, id)
			if err != nil {
				return err
			}
			out = append(out, *b)
		}
		return nil
	})
	return out, database.MapError(err)
}

// GetBill returns a bill with history.
func (s *Service) GetBill(ctx context.Context, id uuid.UUID) (*BillDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *BillDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		out, err = s.billDetail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// lockOwnBill locks a bill the caller owns.
func lockOwnBill(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (ruleID uuid.UUID, status string, version int32, err error) {
	var owner uuid.UUID
	if err := tx.QueryRow(ctx, `select user_id, recurring_rule_id, status, version from bills where id = $1`, id).
		Scan(&owner, &ruleID, &status, &version); err != nil {
		if database.IsNoRows(err) {
			return uuid.Nil, "", 0, apperr.NotFound("bill")
		}
		return uuid.Nil, "", 0, err
	}
	if owner != uid {
		return uuid.Nil, "", 0, apperr.Forbidden()
	}
	if _, err := tx.Exec(ctx, `select 1 from bills where id = $1 for update`, id); err != nil {
		return uuid.Nil, "", 0, err
	}
	if _, err := tx.Exec(ctx, `select 1 from recurring_rules where id = $1 for update`, ruleID); err != nil {
		return uuid.Nil, "", 0, err
	}
	return ruleID, status, version, nil
}

// UpdateBill replaces a bill's details and future schedule, and applies an
// optional status change.
func (s *Service) UpdateBill(ctx context.Context, id uuid.UUID, in BillInput) (*BillDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *BillDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		ruleID, status, version, err := lockOwnBill(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if version != in.Version {
			return apperr.VersionConflict()
		}
		spec := in.spec()
		if spec.kept, err = storedRefs(ctx, tx, `select payment_account_id, category_id, null::uuid from bills where id = $1`, id); err != nil {
			return err
		}
		x, err := s.validate(ctx, tx, uid, spec)
		if err != nil {
			return billFieldNames(err)
		}
		if err := s.checkBillDocument(ctx, tx, uid, in.DocumentFileID); err != nil {
			return err
		}
		if err := s.replaceSchedule(ctx, tx, ruleID, x); err != nil {
			return err
		}
		newStatus := status
		if in.Status != "" {
			newStatus = in.Status
		}
		// replaceSchedule reactivates an ended rule; re-apply the bill state.
		switch newStatus {
		case "archived":
			err = s.setStatus(ctx, tx, ruleID, "stop")
		case "paused":
			err = s.setStatus(ctx, tx, ruleID, "pause")
		case "active":
			var rs string
			if err = tx.QueryRow(ctx, `select status from recurring_rules where id = $1`, ruleID).Scan(&rs); err == nil && rs == "paused" {
				err = s.setStatus(ctx, tx, ruleID, "resume")
			}
		}
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update bills set name = $2, provider_name = $3, category_id = $4, expected_amount_minor = $5,
			amount_is_variable = $6, currency = $7, payment_account_id = $8, document_file_id = $9, notes = $10, status = $11,
			version = version + 1 where id = $1`, id, x.Name, trim(in.ProviderName, 120), x.CategoryID, x.amount, x.AmountIsVariable,
			*x.Currency, x.AccountID, in.DocumentFileID, x.Notes, newStatus); err != nil {
			return err
		}
		action := "updated"
		if newStatus != status {
			action = newStatus
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "bill", EntityID: &id, Action: action}); err != nil {
			return err
		}
		out, err = s.billDetail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// billFields maps the shared rule validation's request fields to the
// names bills use, so errors point at the right form field.
var billFields = map[string]string{"body.amount": "body.expected_amount", "body.account_id": "body.payment_account_id",
	"body.merchant_name": "body.provider_name"}

func billFieldNames(err error) error {
	var e *apperr.Error
	if errors.As(err, &e) {
		for i, d := range e.Details {
			if f, ok := billFields[d.Field]; ok {
				e.Details[i].Field = f
			}
		}
	}
	return err
}

// MarkPaidInput marks an occurrence paid by linking the payment that was
// already recorded (no duplicate) or by recording a new payment.
type MarkPaidInput struct {
	OccurrenceID      *uuid.UUID `json:"occurrence_id,omitempty" doc:"Defaults to the oldest unpaid occurrence"`
	TransactionID     *uuid.UUID `json:"transaction_id,omitempty" doc:"Link the payment you already recorded; no new transaction is created"`
	CreateTransaction bool       `json:"create_transaction,omitempty" doc:"Record a new expense for this payment"`
	AccountID         *uuid.UUID `json:"account_id,omitempty" doc:"With create_transaction; defaults to the bill's payment account"`
	Amount            string     `json:"amount,omitempty" doc:"With create_transaction; defaults to the expected amount"`
	PaidOn            string     `json:"paid_on,omitempty" doc:"With create_transaction; YYYY-MM-DD, default today"`
}

// MarkPaid marks a bill occurrence paid (idempotent per key; a payment
// transaction can satisfy only one occurrence).
func (s *Service) MarkPaid(ctx context.Context, key string, id uuid.UUID, in MarkPaidInput) (*BillDetail, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	if (in.TransactionID == nil) == !in.CreateTransaction {
		return nil, false, apperr.Validation("Choose the transaction that paid the bill, or ask to record a new payment.")
	}
	var out BillDetail
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "bill.mark_paid", struct {
			ID uuid.UUID
			In MarkPaidInput
		}{id, in}, func() (BillDetail, error) {
			ruleID, status, _, err := lockOwnBill(ctx, tx, uid, id)
			if err != nil {
				return BillDetail{}, err
			}
			if status == "archived" {
				return BillDetail{}, apperr.Rule("bill_inactive", "Restore the bill before recording payments.", nil)
			}
			occID, err := openOccurrence(ctx, tx, ruleID, in.OccurrenceID)
			if err != nil {
				return BillDetail{}, err
			}
			a := OccurrenceAction{Action: "link_transaction", TransactionID: in.TransactionID}
			if in.CreateTransaction {
				var tz string
				if err := tx.QueryRow(ctx, `select timezone from recurring_rules where id = $1`, ruleID).Scan(&tz); err != nil {
					return BillDetail{}, err
				}
				loc, lerr := time.LoadLocation(tz)
				if lerr != nil {
					loc = time.UTC
				}
				date := in.PaidOn
				if date == "" {
					date = finance.LocalDateString(localToday(s.now(), loc))
				}
				a = OccurrenceAction{Action: "confirm", Amount: in.Amount, AccountID: in.AccountID, Date: date}
			}
			if err := s.actOnOccurrence(ctx, tx, uid, occID, a); err != nil {
				return BillDetail{}, err
			}
			if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "bill", EntityID: &id, Action: "mark_paid",
				Changes: map[string]any{"occurrence_id": occID, "linked_existing": in.TransactionID != nil}}); err != nil {
				return BillDetail{}, err
			}
			d, err := s.billDetail(ctx, tx, uid, id)
			if err != nil {
				return BillDetail{}, err
			}
			return *d, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// openOccurrence returns the requested open occurrence or the oldest one.
func openOccurrence(ctx context.Context, tx pgx.Tx, ruleID uuid.UUID, occID *uuid.UUID) (uuid.UUID, error) {
	var id uuid.UUID
	err := tx.QueryRow(ctx, `select id from recurring_occurrences where rule_id = $1 and status in ('scheduled','overdue')
		and transaction_id is null and ($2::uuid is null or id = $2) order by coalesce(postponed_to, occurrence_date) limit 1`, ruleID, occID).Scan(&id)
	if database.IsNoRows(err) {
		if occID != nil {
			return uuid.Nil, apperr.ConflictCode("occurrence_not_open", "That occurrence is already paid, skipped or not part of this bill.", nil)
		}
		return uuid.Nil, apperr.ConflictCode("no_open_occurrence", "There is no unpaid occurrence.", nil)
	}
	return id, err
}

// SkipBill skips an occurrence (default: the oldest unpaid one).
func (s *Service) SkipBill(ctx context.Context, id uuid.UUID, occID *uuid.UUID) (*BillDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *BillDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		ruleID, _, _, err := lockOwnBill(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if err := s.skipOpen(ctx, tx, ruleID, occID); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "bill", EntityID: &id, Action: "skip"}); err != nil {
			return err
		}
		out, err = s.billDetail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

// BillPaymentCandidate is a recorded transaction that may be this bill's payment.
type BillPaymentCandidate struct {
	TransactionID uuid.UUID      `json:"transaction_id"`
	LocalDate     string         `json:"local_date"`
	Amount        apitypes.Money `json:"amount"`
	AccountName   string         `json:"account_name"`
	Merchant      *string        `json:"merchant,omitempty"`
	Description   *string        `json:"description,omitempty"`
	Reasons       []string       `json:"reasons" doc:"Why it was suggested (English; localize by reason_codes)"`
	ReasonCodes   []string       `json:"reason_codes" enum:"same_provider,same_amount,amount_close,on_due_date,near_due_date" doc:"Stable reasons, in the order of reasons"`
	DaysFromDue   int            `json:"days_from_due" doc:"Payment date minus the due date, in days (negative = before)"`
}

// PaymentCandidates suggests existing transactions to link (avoids
// recording a bill payment twice).
func (s *Service) PaymentCandidates(ctx context.Context, id uuid.UUID, occID *uuid.UUID) ([]BillPaymentCandidate, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []BillPaymentCandidate{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var ruleID uuid.UUID
		var owner uuid.UUID
		if err := tx.QueryRow(ctx, `select recurring_rule_id, user_id from bills where id = $1`, id).Scan(&ruleID, &owner); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("bill")
			}
			return err
		}
		if owner != uid {
			return apperr.Forbidden()
		}
		oid, err := openOccurrence(ctx, tx, ruleID, occID)
		if occID == nil && apperr.HasDetail(err, "no_open_occurrence") {
			return nil // nothing is due, so nothing to suggest
		}
		if err != nil {
			return err
		}
		var date time.Time
		var expected *int64
		var cur string
		var merchant *uuid.UUID
		if err := tx.QueryRow(ctx, `select coalesce(o.postponed_to, o.occurrence_date), coalesce(o.amount_minor, r.amount_minor), r.currency,
			r.merchant_id from recurring_occurrences o join recurring_rules r on r.id = o.rule_id where o.id = $1`, oid).
			Scan(&date, &expected, &cur, &merchant); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select t.id, t.local_date, t.amount_minor, a.name, m.name, t.description, t.merchant_id = $5 as merchant_match
			from transactions t join financial_accounts a on a.id = t.account_id left join merchants m on m.id = t.merchant_id
			where t.user_id = $1 and t.deleted_at is null and t.status <> 'voided' and t.type in ('expense','group_expense')
			and t.currency = $2 and t.local_date between $3::date - 10 and $3::date + 10
			and t.recurring_occurrence_id is null
			and not exists (select 1 from recurring_occurrences o where o.transaction_id = t.id)
			and ($4::bigint is null or t.amount_minor between $4 * 3 / 4 and $4 * 5 / 4)
			order by (t.merchant_id = $5) desc nulls last, abs(t.amount_minor - coalesce($4, t.amount_minor)), abs(t.local_date - $3::date)
			limit 10`, uid, cur, date, expected, merchant)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var c BillPaymentCandidate
			var d time.Time
			var amt int64
			var mm *bool
			if err := rows.Scan(&c.TransactionID, &d, &amt, &c.AccountName, &c.Merchant, &c.Description, &mm); err != nil {
				return err
			}
			c.LocalDate, c.Amount = finance.LocalDateString(d), apitypes.M(amt, cur)
			c.Reasons, c.ReasonCodes = []string{}, []string{}
			reason := func(code, text string) {
				c.ReasonCodes, c.Reasons = append(c.ReasonCodes, code), append(c.Reasons, text)
			}
			if mm != nil && *mm {
				reason("same_provider", "Same provider")
			}
			if expected != nil && amt == *expected {
				reason("same_amount", "Same amount as expected")
			} else if expected != nil {
				reason("amount_close", "Amount within 25% of expected")
			}
			c.DaysFromDue = int(dateOnly(d).Sub(dateOnly(date)).Hours() / 24)
			if c.DaysFromDue == 0 {
				reason("on_due_date", "On the due date")
			} else {
				reason("near_due_date", "Within 10 days of the due date")
			}
			out = append(out, c)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}
