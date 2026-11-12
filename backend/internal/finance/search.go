package finance

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/period"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
)

// ListFilter selects transactions (spec §4.4 search fields).
type ListFilter struct {
	Range           string      `query:"range" enum:"today,yesterday,this_week,last_week,this_month,last_month,this_year,last_year,last_7_days,last_30_days,last_90_days," doc:"Named range in your timezone"`
	From            string      `query:"from" doc:"YYYY-MM-DD"`
	To              string      `query:"to" doc:"YYYY-MM-DD"`
	Types           []string    `query:"type" doc:"Comma-separated, e.g. expense,income"`
	AccountIDs      []uuid.UUID `query:"account_id" doc:"Comma-separated"`
	CategoryIDs     []uuid.UUID `query:"category_id" doc:"Comma-separated; includes subcategories"`
	MerchantID      string      `query:"merchant_id"`
	PaymentMethodID string      `query:"payment_method_id"`
	TagIDs          []uuid.UUID `query:"tag_id" doc:"Comma-separated (any)"`
	Currency        string      `query:"currency" doc:"Required when filtering by amount"`
	MinAmount       string      `query:"min_amount"`
	MaxAmount       string      `query:"max_amount"`
	Q               string      `query:"q" maxLength:"100" doc:"Searches description, notes and merchant"`
	Source          string      `query:"source" enum:"manual,import,receipt,recurring,integration,correction,group,system,"`
	Status          string      `query:"status" enum:"active,posted,pending,draft,voided,all," doc:"Default active (excludes deleted)"`
	Reconciliation  string      `query:"reconciliation_state" enum:"unreconciled,matched,reconciled,excluded,"`
	Direction       string      `query:"direction" enum:"inflow,outflow,"`
	HasAttachment   string      `query:"has_attachment" enum:"true,false,"`
	Uncategorized   bool        `query:"uncategorized" doc:"Only transactions without a category"`
	Recurring       string      `query:"recurring" enum:"true,false,"`
	IncludeShared   bool        `query:"include_shared" doc:"Include household accounts shared with you"`
	Sort            string      `query:"sort" enum:"date_desc,date_asc,amount_desc,amount_asc," default:"date_desc"`
	Cursor          string      `query:"cursor" maxLength:"512"`
	Limit           int         `query:"limit" minimum:"1" maximum:"200" default:"50"`
	// OnlyIDs is internal (not a request parameter): when non-nil, only
	// these transactions match (an empty list matches none). Used by
	// drill-downs that select exactly the records an aggregate counted.
	OnlyIDs []uuid.UUID `json:"-"`
}

type txCursor struct {
	D  string    `json:"d,omitempty"`
	A  int64     `json:"a,omitempty"`
	C  time.Time `json:"c"`
	ID uuid.UUID `json:"i"`
}

type qb struct {
	where []string
	args  []any
}

func (b *qb) arg(v any) string {
	b.args = append(b.args, v)
	return fmt.Sprintf("$%d", len(b.args))
}

func (b *qb) add(cond string) { b.where = append(b.where, cond) }

func likeEscape(s string) string {
	return "%" + strings.NewReplacer(`\`, `\\`, "%", `\%`, "_", `\_`).Replace(s) + "%"
}

// ListTransactions searches transactions with cursor pagination.
func (s *Service) ListTransactions(ctx context.Context, f ListFilter) ([]TransactionDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if f.Limit <= 0 || f.Limit > 200 {
		f.Limit = 50
	}
	var out []TransactionDTO
	next := ""
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		b := &qb{}
		if f.IncludeShared {
			b.add("(t.user_id = " + b.arg(uid) + " or " + sharedTxVisible + ")")
		} else {
			b.add("t.user_id = " + b.arg(uid))
		}
		if err := s.applyFilter(ctx, tx, b, f, u); err != nil {
			return err
		}
		var cur txCursor
		if err := httpx.DecodeCursor(f.Cursor, &cur); err != nil {
			return err
		}
		order := "t.local_date desc, t.created_at desc, t.id desc"
		switch f.Sort {
		case "date_asc":
			order = "t.local_date asc, t.created_at asc, t.id asc"
			if f.Cursor != "" {
				b.add(fmt.Sprintf("(t.local_date, t.created_at, t.id) > (%s::date, %s, %s)", b.arg(cur.D), b.arg(cur.C), b.arg(cur.ID)))
			}
		case "amount_desc":
			order = "t.amount_minor desc, t.created_at desc, t.id desc"
			if f.Cursor != "" {
				b.add(fmt.Sprintf("(t.amount_minor, t.created_at, t.id) < (%s, %s, %s)", b.arg(cur.A), b.arg(cur.C), b.arg(cur.ID)))
			}
		case "amount_asc":
			order = "t.amount_minor asc, t.created_at asc, t.id asc"
			if f.Cursor != "" {
				b.add(fmt.Sprintf("(t.amount_minor, t.created_at, t.id) > (%s, %s, %s)", b.arg(cur.A), b.arg(cur.C), b.arg(cur.ID)))
			}
		default:
			if f.Cursor != "" {
				b.add(fmt.Sprintf("(t.local_date, t.created_at, t.id) < (%s::date, %s, %s)", b.arg(cur.D), b.arg(cur.C), b.arg(cur.ID)))
			}
		}
		q := txSelect + " where " + strings.Join(b.where, " and ") + " order by " + order + " limit " + b.arg(f.Limit+1)
		rows, err := tx.Query(ctx, q, b.args...)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			t, err := scanTx(rows, uid)
			if err != nil {
				return err
			}
			out = append(out, *t)
		}
		if err := rows.Err(); err != nil {
			return err
		}
		if len(out) > f.Limit {
			last := out[f.Limit-1]
			next, _ = httpx.EncodeCursor(txCursor{D: last.LocalDate, A: last.Amount.AmountMinor, C: last.CreatedAt, ID: last.ID})
			out = out[:f.Limit]
		}
		return nil
	})
	if out == nil {
		out = []TransactionDTO{}
	}
	return out, next, database.MapError(err)
}

// applyFilter translates a ListFilter into SQL conditions.
func (s *Service) applyFilter(ctx context.Context, tx pgx.Tx, b *qb, f ListFilter, u UserContext) error {
	switch {
	case f.Range != "":
		r, err := period.Named(f.Range, s.now(), u.Period())
		if err != nil {
			return apperr.FieldError("query.range", "Unknown range.")
		}
		b.add("t.local_date between " + b.arg(LocalDateString(r.Start)) + "::date and " + b.arg(LocalDateString(r.End)) + "::date")
	default:
		if f.From != "" {
			d, err := ParseDate("query.from", f.From, u.Loc)
			if err != nil {
				return err
			}
			b.add("t.local_date >= " + b.arg(LocalDateString(d)) + "::date")
		}
		if f.To != "" {
			d, err := ParseDate("query.to", f.To, u.Loc)
			if err != nil {
				return err
			}
			b.add("t.local_date <= " + b.arg(LocalDateString(d)) + "::date")
		}
	}
	switch f.Status {
	case "", "active":
		b.add("t.deleted_at is null")
	case "all":
	default:
		b.add("t.status = " + b.arg(f.Status))
	}
	if f.OnlyIDs != nil {
		b.add("t.id = any(" + b.arg(f.OnlyIDs) + ")")
	}
	if len(f.Types) > 0 {
		b.add("t.type = any(" + b.arg(f.Types) + ")")
	}
	if len(f.AccountIDs) > 0 {
		b.add("t.account_id = any(" + b.arg(f.AccountIDs) + ")")
	}
	if len(f.CategoryIDs) > 0 && f.Uncategorized {
		return apperr.FieldError("query.uncategorized", "Choose categories or uncategorized, not both.")
	}
	if len(f.CategoryIDs) > 0 {
		// A merged category (saved filter, bookmark) stands for its target.
		p := b.arg(f.CategoryIDs)
		ids := "(select unnest(" + p + "::uuid[]) union select merged_into_id from categories where id = any(" + p +
			") and status = 'merged' and merged_into_id is not null)"
		b.add("(t.category_id in " + ids + " or t.category_id in (select id from categories where parent_id in " + ids + "))")
	}
	if f.Uncategorized {
		b.add("t.category_id is null")
	}
	if f.MerchantID != "" {
		id, err := uuid.Parse(f.MerchantID)
		if err != nil {
			return apperr.FieldError("query.merchant_id", "Invalid merchant.")
		}
		// A merged merchant (saved filter, bookmark) stands for its target.
		m := b.arg(id)
		b.add("(t.merchant_id = " + m + " or t.merchant_id = (select merged_into_id from merchants where id = " + m + " and status = 'merged'))")
	}
	if f.PaymentMethodID != "" {
		id, err := uuid.Parse(f.PaymentMethodID)
		if err != nil {
			return apperr.FieldError("query.payment_method_id", "Invalid payment method.")
		}
		b.add("t.payment_method_id = " + b.arg(id))
	}
	if len(f.TagIDs) > 0 {
		b.add("exists (select 1 from transaction_tags tt where tt.transaction_id = t.id and tt.tag_id = any(" + b.arg(f.TagIDs) + "))")
	}
	if f.MinAmount != "" || f.MaxAmount != "" || f.Currency != "" {
		cur := f.Currency
		if cur == "" {
			cur = u.BaseCurrency
		}
		if !currency.Valid(cur) {
			return apperr.FieldError("query.currency", "Unsupported currency.")
		}
		b.add("t.currency = " + b.arg(cur))
		if f.MinAmount != "" {
			v, err := ParseSignedAmount("query.min_amount", f.MinAmount, cur)
			if err != nil {
				return err
			}
			b.add("t.amount_minor >= " + b.arg(v))
		}
		if f.MaxAmount != "" {
			v, err := ParseSignedAmount("query.max_amount", f.MaxAmount, cur)
			if err != nil {
				return err
			}
			b.add("t.amount_minor <= " + b.arg(v))
		}
	}
	if q := strings.TrimSpace(f.Q); q != "" {
		p := b.arg(likeEscape(q))
		b.add("(t.description ilike " + p + " or t.notes ilike " + p + " or mer.name ilike " + p + ")")
	}
	if f.Source != "" {
		b.add("t.source = " + b.arg(f.Source))
	}
	if f.Reconciliation != "" {
		b.add("t.reconciliation_state = " + b.arg(f.Reconciliation))
	}
	if f.Direction != "" {
		b.add("t.direction = " + b.arg(f.Direction))
	}
	switch f.HasAttachment {
	case "true":
		b.add("exists (select 1 from transaction_attachments ta where ta.transaction_id = t.id)")
	case "false":
		b.add("not exists (select 1 from transaction_attachments ta where ta.transaction_id = t.id)")
	}
	switch f.Recurring {
	case "true":
		b.add("t.recurring_rule_id is not null")
	case "false":
		b.add("t.recurring_rule_id is null")
	}
	return nil
}

// SavedFilterDTO is a named filter.
type SavedFilterDTO struct {
	ID        uuid.UUID       `json:"id"`
	Scope     string          `json:"scope" enum:"transactions,reports,search"`
	Name      string          `json:"name"`
	Filter    json.RawMessage `json:"filter"`
	CreatedAt time.Time       `json:"created_at"`
}

// ListSavedFilters returns saved filters for a scope.
func (s *Service) ListSavedFilters(ctx context.Context, scope string) ([]SavedFilterDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []SavedFilterDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id, scope, name, filter, created_at from saved_filters where user_id = $1 and ($2 = '' or scope = $2) order by name`, uid, scope)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var f SavedFilterDTO
			if err := rows.Scan(&f.ID, &f.Scope, &f.Name, &f.Filter, &f.CreatedAt); err != nil {
				return err
			}
			out = append(out, f)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// SaveFilter stores a named filter.
func (s *Service) SaveFilter(ctx context.Context, scope, name string, filter json.RawMessage) (*SavedFilterDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if len(filter) > 4096 || !json.Valid(filter) {
		return nil, apperr.FieldError("body.filter", "Filter must be a JSON object under 4 KB.")
	}
	var out SavedFilterDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `insert into saved_filters (user_id, scope, name, filter) values ($1,$2,$3,$4)
			returning id, scope, name, filter, created_at`, uid, scope, strings.TrimSpace(name), filter).
			Scan(&out.ID, &out.Scope, &out.Name, &out.Filter, &out.CreatedAt)
	})
	if database.IsUniqueViolation(err, "saved_filters_name_key") {
		return nil, apperr.Conflict("A saved filter with this name already exists.")
	}
	return &out, database.MapError(err)
}

// DeleteSavedFilter removes a saved filter.
func (s *Service) DeleteSavedFilter(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from saved_filters where id = $1 and user_id = $2`, id, uid)
		if err == nil && tag.RowsAffected() == 0 {
			return apperr.NotFound("saved filter")
		}
		return err
	}))
}
