// Package finance implements personal finance: accounts, payment methods,
// categories, tags, merchants, transactions, transfers, refunds, search and
// the append-only ledger (spec §4.3–§4.5, §20B.4–§20B.6, ADR-007).
//
// All money is integer minor units validated against the currency
// exponent; every multi-record change runs in one database transaction with
// RLS scoped to the caller, writes audit events and emits outbox events.
package finance

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/ledger"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/domain/period"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/logging"
)

// Service is the finance application service.
type Service struct {
	DB  *database.DB
	Now func() time.Time
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// UserContext holds calendar/currency preferences used in calculations.
type UserContext struct {
	ID            uuid.UUID
	Timezone      string
	Loc           *time.Location
	BaseCurrency  string
	WeekStart     time.Weekday
	MonthStartDay int
}

// Period returns calendar settings for range resolution.
func (u UserContext) Period() period.Settings {
	return period.Settings{Location: u.Loc, WeekStart: u.WeekStart, MonthStartDay: u.MonthStartDay}
}

// LoadUser reads the caller's preferences inside tx.
func LoadUser(ctx context.Context, tx pgx.Tx, uid uuid.UUID) (UserContext, error) {
	u := UserContext{ID: uid}
	var ws, md int16
	if err := tx.QueryRow(ctx, `select timezone, base_currency, week_start, month_start_day from user_preferences where user_id = $1`, uid).
		Scan(&u.Timezone, &u.BaseCurrency, &ws, &md); err != nil {
		return u, database.MapError(err)
	}
	loc, err := time.LoadLocation(u.Timezone)
	if err != nil {
		loc = time.UTC
	}
	u.Loc, u.WeekStart, u.MonthStartDay = loc, time.Weekday(ws), int(md)
	return u, nil
}

// ParseAmount parses a positive decimal amount for a currency.
func ParseAmount(field, s, cur string) (int64, error) {
	v, err := money.Parse(s, cur, money.ParseOptions{})
	if err != nil {
		return 0, amountError(field, err, cur)
	}
	return v, nil
}

// ParseSignedAmount parses an amount that may be negative or zero.
func ParseSignedAmount(field, s, cur string) (int64, error) {
	v, err := money.Parse(s, cur, money.ParseOptions{AllowNegative: true, AllowZero: true})
	if err != nil {
		return 0, amountError(field, err, cur)
	}
	return v, nil
}

func amountError(field string, err error, cur string) error {
	switch {
	case errors.Is(err, money.ErrTooPrecise):
		return apperr.FieldError(field, fmt.Sprintf("%s supports %d decimal places.", cur, currency.Exponent(cur)))
	case errors.Is(err, money.ErrOutOfRange):
		return apperr.FieldError(field, "Amount is too large.")
	case errors.Is(err, money.ErrNegative):
		return apperr.FieldError(field, "Amount must be positive.")
	case errors.Is(err, money.ErrUnknownCurrency):
		return apperr.FieldError(field, "Unsupported currency.")
	}
	return apperr.FieldError(field, "Enter an amount like 1234.50 (digits and an optional decimal point).")
}

// ParseDate parses YYYY-MM-DD as a local date in loc.
func ParseDate(field, s string, loc *time.Location) (time.Time, error) {
	t, err := time.ParseInLocation("2006-01-02", s, loc)
	if err != nil {
		return time.Time{}, apperr.FieldError(field, "Use the date format YYYY-MM-DD.")
	}
	if t.Year() < 1970 || t.Year() > 2200 {
		return time.Time{}, apperr.FieldError(field, "Date is out of range.")
	}
	return t, nil
}

// LocalDateString formats a date for the API.
func LocalDateString(t time.Time) string { return t.Format("2006-01-02") }

// NormalizeName lower-cases and collapses whitespace (merchant/tag keys).
func NormalizeName(s string) string {
	var b strings.Builder
	space := false
	for _, r := range strings.TrimSpace(s) {
		if unicode.IsSpace(r) {
			if !space {
				b.WriteRune(' ')
			}
			space = true
			continue
		}
		space = false
		b.WriteRune(unicode.ToLower(r))
	}
	return b.String()
}

func trimPtr(s *string, max int) *string {
	if s == nil {
		return nil
	}
	v := strings.TrimSpace(*s)
	if v == "" {
		return nil
	}
	if r := []rune(v); len(r) > max {
		v = string(r[:max])
	}
	return &v
}

// m is a shorthand for API money.
func m(minor int64, cur string) apitypes.Money { return apitypes.M(minor, cur) }

// postLedger appends the ledger entry for a transaction version.
func postLedger(ctx context.Context, tx pgx.Tx, uid, txID, accountID uuid.UUID, version int32, dir string, amount int64, cur string, date time.Time) error {
	_, err := tx.Exec(ctx, `insert into account_ledger_entries (user_id, account_id, transaction_id, transaction_version, entry_kind, amount_minor, currency, effective_date)
		values ($1,$2,$3,$4,'post',$5,$6,$7)`, uid, accountID, txID, version, ledger.SignedAmount(dir, amount), cur, date)
	return err
}

// reverseLedger appends the reversing entry for a previous version.
func reverseLedger(ctx context.Context, tx pgx.Tx, uid, txID, accountID uuid.UUID, version int32, dir string, amount int64, cur string, date time.Time) error {
	_, err := tx.Exec(ctx, `insert into account_ledger_entries (user_id, account_id, transaction_id, transaction_version, entry_kind, amount_minor, currency, effective_date)
		values ($1,$2,$3,$4,'reverse',$5,$6,$7)`, uid, accountID, txID, version, -ledger.SignedAmount(dir, amount), cur, date)
	return err
}

// txAudit appends a transaction audit event.
func txAudit(ctx context.Context, tx pgx.Tx, uid, txID uuid.UUID, actorKind, action string, version int32, changes any) error {
	b := []byte("{}")
	if changes != nil {
		var err error
		if b, err = json.Marshal(changes); err != nil {
			return err
		}
	}
	var actor *uuid.UUID
	if actorKind == "user" {
		actor = &uid
	}
	_, err := tx.Exec(ctx, `insert into transaction_audit_events (user_id, transaction_id, actor_user_id, actor_kind, action, version, changes, request_id)
		values ($1,$2,$3,$4,$5,$6,$7,nullif($8,''))`, uid, txID, actor, actorKind, action, version, b, logging.RequestID(ctx))
	return err
}

// diff records {field: {from, to}} for changed values.
type diff map[string]map[string]any

func (d diff) add(field string, from, to any) {
	if fmt.Sprint(from) != fmt.Sprint(to) {
		d[field] = map[string]any{"from": from, "to": to}
	}
}

func deref[T any](p *T) any {
	if p == nil {
		return nil
	}
	return *p
}
