package recurring

import (
	"context"
	"slices"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
)

// SchedulePatch changes parts of a schedule. Changing the frequency resets
// the interval and day anchors (interval_count, interval_unit, by_* fields)
// to the ones sent with it, so a new frequency never inherits anchors that
// belonged to the old one.
type SchedulePatch struct {
	Frequency          *string  `json:"frequency,omitempty" enum:"daily,weekly,biweekly,monthly,bimonthly,quarterly,semiannual,yearly,custom"`
	IntervalCount      *int16   `json:"interval_count,omitempty" minimum:"1" maximum:"366" doc:"Custom frequency: every N units"`
	IntervalUnit       *string  `json:"interval_unit,omitempty" enum:"day,week,month,year"`
	ByMonthDay         *int16   `json:"by_month_day,omitempty" minimum:"-1" maximum:"31" doc:"-1 = last day of the month"`
	ByWeekday          *int16   `json:"by_weekday,omitempty" minimum:"0" maximum:"6" doc:"0 = Sunday"`
	ByWeekOfMonth      *int16   `json:"by_week_of_month,omitempty" minimum:"-1" maximum:"5" doc:"With by_weekday: nth weekday (-1 = last)"`
	StartDate          *string  `json:"start_date,omitempty" doc:"YYYY-MM-DD"`
	EndDate            *string  `json:"end_date,omitempty" doc:"YYYY-MM-DD; empty string clears it"`
	MaxOccurrences     *int32   `json:"max_occurrences,omitempty" minimum:"1" maximum:"10000"`
	Timezone           *string  `json:"timezone,omitempty" maxLength:"64" doc:"IANA zone"`
	LocalTime          *string  `json:"local_time,omitempty" pattern:"^([01][0-9]|2[0-3]):[0-5][0-9]$"`
	ReminderDaysBefore *[]int16 `json:"reminder_days_before,omitempty" maxItems:"5" doc:"Replaces the list; [] turns reminders off"`
}

// scheduleOf converts a stored rule back into its editable schedule.
func scheduleOf(r RecurringRuleDTO) Schedule {
	sc := Schedule{Frequency: r.Frequency, IntervalCount: r.IntervalCount, IntervalUnit: r.IntervalUnit, ByMonthDay: r.ByMonthDay,
		ByWeekday: r.ByWeekday, ByWeekOfMonth: r.ByWeekOfMonth, StartDate: r.StartDate, MaxOccurrences: r.MaxOccurrences,
		Timezone: r.Timezone, LocalTime: r.LocalTime, ReminderDaysBefore: r.ReminderDaysBefore}
	if sc.ReminderDaysBefore == nil {
		sc.ReminderDaysBefore = []int16{}
	}
	if r.EndDate != nil {
		sc.EndDate = *r.EndDate
	}
	return sc
}

// apply merges the patch into a schedule; clear names optional fields to
// remove.
func (p SchedulePatch) apply(sc *Schedule, clear map[string]bool) {
	if p.Frequency != nil && *p.Frequency != sc.Frequency {
		sc.Frequency, sc.IntervalCount, sc.IntervalUnit = *p.Frequency, 0, nil
		sc.ByMonthDay, sc.ByWeekday, sc.ByWeekOfMonth = nil, nil, nil
	}
	if p.IntervalCount != nil {
		sc.IntervalCount = *p.IntervalCount
	}
	if p.IntervalUnit != nil {
		sc.IntervalUnit = p.IntervalUnit
	}
	if p.ByMonthDay != nil {
		sc.ByMonthDay = p.ByMonthDay
	}
	if p.ByWeekday != nil {
		sc.ByWeekday = p.ByWeekday
	}
	if p.ByWeekOfMonth != nil {
		sc.ByWeekOfMonth = p.ByWeekOfMonth
	}
	if p.StartDate != nil {
		sc.StartDate = *p.StartDate
	}
	if p.EndDate != nil {
		sc.EndDate = *p.EndDate
	}
	if p.MaxOccurrences != nil {
		sc.MaxOccurrences = p.MaxOccurrences
	}
	if p.Timezone != nil {
		sc.Timezone = *p.Timezone
	}
	if p.LocalTime != nil {
		sc.LocalTime = *p.LocalTime
	}
	if p.ReminderDaysBefore != nil {
		sc.ReminderDaysBefore = *p.ReminderDaysBefore
	}
	if clear["max_occurrences"] {
		sc.MaxOccurrences = nil
	}
	if clear["by_month_day"] {
		sc.ByMonthDay = nil
	}
	if clear["by_weekday"] {
		sc.ByWeekday = nil
	}
	if clear["by_week_of_month"] {
		sc.ByWeekOfMonth = nil
	}
}

// clearSet validates a clear list: a field cannot be both sent and
// cleared.
func clearSet(clear []string, sent map[string]bool) (map[string]bool, error) {
	out := map[string]bool{}
	for _, f := range clear {
		if sent[f] {
			return nil, apperr.FieldError("body.clear", "Send a new value for "+f+" or clear it, not both.")
		}
		out[f] = true
	}
	return out, nil
}

func (p SchedulePatch) sent() map[string]bool {
	return map[string]bool{"max_occurrences": p.MaxOccurrences != nil, "by_month_day": p.ByMonthDay != nil,
		"by_weekday": p.ByWeekday != nil, "by_week_of_month": p.ByWeekOfMonth != nil}
}

// RecurringRulePatch changes only the fields sent ("edit this and future";
// the kind of a rule cannot change). Text fields are cleared with an empty
// string, other optional fields through clear.
type RecurringRulePatch struct {
	Kind *string `json:"kind,omitempty" enum:"expense,income,transfer" doc:"Accepted for compatibility; must match (the kind of a rule cannot change)"`
	Name *string `json:"name,omitempty" minLength:"1" maxLength:"120"`
	SchedulePatch
	Amount           *string    `json:"amount,omitempty" doc:"Decimal; empty string clears it"`
	Currency         *string    `json:"currency,omitempty" pattern:"^[A-Z]{3}$"`
	AmountIsVariable *bool      `json:"amount_is_variable,omitempty"`
	AccountID        *uuid.UUID `json:"account_id,omitempty"`
	ToAccountID      *uuid.UUID `json:"to_account_id,omitempty"`
	CategoryID       *uuid.UUID `json:"category_id,omitempty"`
	MerchantName     *string    `json:"merchant_name,omitempty" maxLength:"120" doc:"Empty string clears it"`
	Description      *string    `json:"description,omitempty" maxLength:"500" doc:"Empty string clears it"`
	Notes            *string    `json:"notes,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	AutoPost         *bool      `json:"auto_post,omitempty"`
	Clear            []string   `json:"clear,omitempty" maxItems:"7" enum:"account_id,to_account_id,category_id,max_occurrences,by_month_day,by_weekday,by_week_of_month" doc:"Optional fields to remove"`
	Version          int32      `json:"version" minimum:"1" doc:"Current version (409 VERSION_CONFLICT when stale)"`
}

// PatchRule applies a partial update through the same validation as a full
// update.
func (s *Service) PatchRule(ctx context.Context, id uuid.UUID, p RecurringRulePatch) (*RecurringRuleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	sent := p.sent()
	sent["account_id"], sent["to_account_id"], sent["category_id"] = p.AccountID != nil, p.ToAccountID != nil, p.CategoryID != nil
	clear, err := clearSet(p.Clear, sent)
	if err != nil {
		return nil, err
	}
	var in RecurringRuleInput
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		cur, err := s.getRule(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if !cur.Owned {
			return apperr.Forbidden()
		}
		in = RecurringRuleInput{Kind: cur.Kind, Name: cur.Name, Schedule: scheduleOf(*cur), Currency: deref(cur.Currency),
			AmountIsVariable: cur.AmountIsVariable, AccountID: cur.AccountID, ToAccountID: cur.ToAccountID, CategoryID: cur.CategoryID,
			Description: deref(cur.Description), Notes: deref(cur.Notes), AutoPost: cur.AutoPost, Version: p.Version}
		if cur.Amount != nil {
			in.Amount = cur.Amount.Amount
		}
		if cur.Merchant != nil {
			in.MerchantName = cur.Merchant.Name
		}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	setStr(&in.Kind, p.Kind)
	setStr(&in.Name, p.Name)
	p.apply(&in.Schedule, clear)
	setStr(&in.Amount, p.Amount)
	setStr(&in.Currency, p.Currency)
	setStr(&in.MerchantName, p.MerchantName)
	setStr(&in.Description, p.Description)
	setStr(&in.Notes, p.Notes)
	if p.AmountIsVariable != nil {
		in.AmountIsVariable = *p.AmountIsVariable
	}
	if p.AutoPost != nil {
		in.AutoPost = *p.AutoPost
	}
	in.AccountID = pick(in.AccountID, p.AccountID, clear["account_id"])
	in.ToAccountID = pick(in.ToAccountID, p.ToAccountID, clear["to_account_id"])
	in.CategoryID = pick(in.CategoryID, p.CategoryID, clear["category_id"])
	return s.UpdateRule(ctx, id, in)
}

// BillPatch changes only the fields sent; the schedule change applies to
// this and future occurrences. Text fields are cleared with an empty string
// (an empty expected_amount makes the bill variable), other optional fields
// through clear.
type BillPatch struct {
	Name             *string    `json:"name,omitempty" minLength:"1" maxLength:"120"`
	ProviderName     *string    `json:"provider_name,omitempty" maxLength:"120" doc:"Empty string clears it"`
	CategoryID       *uuid.UUID `json:"category_id,omitempty"`
	ExpectedAmount   *string    `json:"expected_amount,omitempty" doc:"Decimal; empty string makes the bill variable"`
	AmountIsVariable *bool      `json:"amount_is_variable,omitempty"`
	Currency         *string    `json:"currency,omitempty" pattern:"^[A-Z]{3}$"`
	PaymentAccountID *uuid.UUID `json:"payment_account_id,omitempty"`
	DocumentFileID   *uuid.UUID `json:"document_file_id,omitempty" doc:"An uploaded bill_document file you own"`
	Notes            *string    `json:"notes,omitempty" maxLength:"2000" doc:"Empty string clears it"`
	SchedulePatch
	Status  *string  `json:"status,omitempty" enum:"active,paused,archived" doc:"Prefer the pause, resume, archive and restore actions"`
	Clear   []string `json:"clear,omitempty" maxItems:"7" enum:"category_id,payment_account_id,document_file_id,max_occurrences,by_month_day,by_weekday,by_week_of_month" doc:"Optional fields to remove"`
	Version int32    `json:"version" minimum:"1" doc:"Current version (409 VERSION_CONFLICT when stale)"`
}

// PatchBill applies a partial update through the same validation as a full
// update.
func (s *Service) PatchBill(ctx context.Context, id uuid.UUID, p BillPatch) (*BillDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	sent := p.sent()
	sent["category_id"], sent["payment_account_id"], sent["document_file_id"] = p.CategoryID != nil, p.PaymentAccountID != nil, p.DocumentFileID != nil
	clear, err := clearSet(p.Clear, sent)
	if err != nil {
		return nil, err
	}
	in, _, err := s.billInput(ctx, uid, id)
	if err != nil {
		return nil, err
	}
	in.Version = p.Version
	setStr(&in.Name, p.Name)
	setStr(&in.ProviderName, p.ProviderName)
	setStr(&in.ExpectedAmount, p.ExpectedAmount)
	setStr(&in.Currency, p.Currency)
	setStr(&in.Notes, p.Notes)
	if p.AmountIsVariable != nil {
		in.AmountIsVariable = *p.AmountIsVariable
	}
	if p.ExpectedAmount != nil && *p.ExpectedAmount != "" && p.AmountIsVariable == nil {
		in.AmountIsVariable = false // a new expected amount makes the bill fixed unless told otherwise
	}
	in.CategoryID = pick(in.CategoryID, p.CategoryID, clear["category_id"])
	in.PaymentAccountID = pick(in.PaymentAccountID, p.PaymentAccountID, clear["payment_account_id"])
	in.DocumentFileID = pick(in.DocumentFileID, p.DocumentFileID, clear["document_file_id"])
	p.apply(&in.Schedule, clear)
	if p.Status != nil {
		in.Status = *p.Status
	}
	return s.UpdateBill(ctx, id, *in)
}

// billInput is the bill's current state as a full update request, with
// its current status.
func (s *Service) billInput(ctx context.Context, uid, id uuid.UUID) (*BillInput, string, error) {
	var in BillInput
	var status string
	err := s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		cur, err := s.loadBill(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if !cur.Owned {
			return apperr.Forbidden()
		}
		in = BillInput{Name: cur.Name, ProviderName: deref(cur.ProviderName), CategoryID: cur.CategoryID, AmountIsVariable: cur.AmountIsVariable,
			Currency: cur.Currency, PaymentAccountID: cur.PaymentAccountID, DocumentFileID: cur.DocumentFileID, Notes: deref(cur.Notes),
			Schedule: scheduleOf(cur.Schedule), Version: cur.Version}
		if cur.ExpectedAmount != nil {
			in.ExpectedAmount = cur.ExpectedAmount.Amount
		}
		status = cur.Status
		return nil
	})
	return &in, status, database.MapError(err)
}

// billActions maps lifecycle actions to the bill status they set and the
// statuses they apply to.
var billActions = map[string]struct {
	to   string
	from []string
}{
	"pause":   {"paused", []string{"active"}},
	"resume":  {"active", []string{"paused"}},
	"archive": {"archived", []string{"active", "paused"}},
	"restore": {"active", []string{"archived"}},
}

// SetBillStatus pauses, resumes, archives or restores a bill. Pausing and
// archiving stop reminders and remove open future occurrences; resuming and
// restoring regenerate them from today (the gap is not back-filled). Only
// the status changes, so references that are no longer selectable (an
// archived payment account) never block it.
//
// version, when not 0, must match the bill's current version.
func (s *Service) SetBillStatus(ctx context.Context, id uuid.UUID, action string, version int32) (*BillDetail, error) {
	a, ok := billActions[action]
	if !ok {
		return nil, apperr.BadRequest("Unknown action.")
	}
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *BillDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		ruleID, status, current, err := lockOwnBill(ctx, tx, uid, id)
		if err != nil {
			return err
		}
		if version != 0 && version != current {
			return apperr.VersionConflict()
		}
		if !slices.Contains(a.from, status) {
			return apperr.Rule("invalid_status_transition", "A bill cannot move from "+status+" to "+a.to+".",
				map[string]string{"from": status, "to": a.to})
		}
		if action == "restore" {
			if err := caps.Check(ctx, tx, uid, "bills", openBillsQ, caps.OpenBills); err != nil {
				return err
			}
		}
		switch a.to {
		case "paused":
			err = s.setStatus(ctx, tx, ruleID, "pause")
		case "archived":
			err = s.setStatus(ctx, tx, ruleID, "stop")
		default:
			// A schedule whose dates are over stays ended; the bill shows
			// state "ended" until its dates are edited.
			err = s.resumeRule(ctx, tx, ruleID)
		}
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update bills set status = $2, version = version + 1 where id = $1`, id, a.to); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "bill", EntityID: &id, Action: action}); err != nil {
			return err
		}
		out, err = s.billDetail(ctx, tx, uid, id)
		return err
	})
	return out, database.MapError(err)
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func setStr(dst *string, v *string) {
	if v != nil {
		*dst = *v
	}
}

func pick(cur, sent *uuid.UUID, clear bool) *uuid.UUID {
	switch {
	case clear:
		return nil
	case sent != nil:
		return sent
	default:
		return cur
	}
}
