package finance

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/ledger"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// AccountTypes supported (spec §4.3).
var AccountTypes = []string{"cash", "bank", "savings", "credit_card", "debit_card", "prepaid_card", "digital_wallet", "upi",
	"loan", "investment", "household_ledger", "custom"}

// AccountDTO is an account with its ledger-derived balance.
type AccountDTO struct {
	ID                    uuid.UUID       `json:"id"`
	Name                  string          `json:"name"`
	AccountType           string          `json:"account_type" enum:"cash,bank,savings,credit_card,debit_card,prepaid_card,digital_wallet,upi,loan,investment,household_ledger,custom"`
	IsLiability           bool            `json:"is_liability" doc:"Credit cards and loans: a negative balance is an amount owed"`
	Currency              string          `json:"currency"`
	InstitutionLabel      *string         `json:"institution_label,omitempty"`
	Icon                  *string         `json:"icon,omitempty"`
	Color                 *string         `json:"color,omitempty"`
	Notes                 *string         `json:"notes,omitempty"`
	MaskedNumber          *string         `json:"masked_number,omitempty" doc:"Last 2-4 digits only"`
	IncludeInOverview     bool            `json:"include_in_overview"`
	CreditLimit           *apitypes.Money `json:"credit_limit,omitempty"`
	AvailableCredit       *apitypes.Money `json:"available_credit,omitempty"`
	StatementDay          *int16          `json:"statement_day,omitempty"`
	PaymentDueDay         *int16          `json:"payment_due_day,omitempty"`
	OpeningDate           string          `json:"opening_date"`
	Balance               apitypes.Money  `json:"balance" doc:"Tracked balance derived from the ledger (not a verified bank balance)"`
	BalanceSource         string          `json:"balance_source" enum:"manual,calculated,imported,provider"`
	Status                string          `json:"status" enum:"active,archived,closed"`
	DisplayOrder          int32           `json:"display_order"`
	LastReconciledAt      *time.Time      `json:"last_reconciled_at,omitempty"`
	LastReconciledBalance *apitypes.Money `json:"last_reconciled_balance,omitempty"`
	LastImportAt          *time.Time      `json:"last_import_at,omitempty"`
	GroupID               *uuid.UUID      `json:"group_id,omitempty"`
	SharedWithGroup       bool            `json:"shared_with_group"`
	Owned                 bool            `json:"owned" doc:"False for household accounts shared with you (read-only)"`
	Version               int32           `json:"version"`
	CreatedAt             time.Time       `json:"created_at"`
	UpdatedAt             time.Time       `json:"updated_at"`
}

const accountSelect = `select a.id, a.name, a.account_type, a.is_liability, a.currency, a.institution_label, a.icon, a.color, a.notes,
	a.masked_number, a.include_in_overview, a.credit_limit_minor, a.statement_day, a.payment_due_day, a.opening_date,
	coalesce((select sum(l.amount_minor) from account_ledger_entries l where l.account_id = a.id), 0)::bigint,
	a.balance_source, a.status, a.display_order, a.last_reconciled_at, a.last_reconciled_balance_minor, a.last_import_at,
	a.group_id, a.shared_with_group, a.user_id, a.version, a.created_at, a.updated_at
	from financial_accounts a`

func scanAccount(r pgx.Row, me uuid.UUID) (*AccountDTO, error) {
	var a AccountDTO
	var limit, recBal *int64
	var opening time.Time
	var balance int64
	var owner uuid.UUID
	if err := r.Scan(&a.ID, &a.Name, &a.AccountType, &a.IsLiability, &a.Currency, &a.InstitutionLabel, &a.Icon, &a.Color, &a.Notes,
		&a.MaskedNumber, &a.IncludeInOverview, &limit, &a.StatementDay, &a.PaymentDueDay, &opening, &balance, &a.BalanceSource,
		&a.Status, &a.DisplayOrder, &a.LastReconciledAt, &recBal, &a.LastImportAt, &a.GroupID, &a.SharedWithGroup, &owner,
		&a.Version, &a.CreatedAt, &a.UpdatedAt); err != nil {
		return nil, err
	}
	a.OpeningDate = LocalDateString(opening)
	a.Balance = m(balance, a.Currency)
	a.CreditLimit = apitypes.MP(limit, a.Currency)
	a.LastReconciledBalance = apitypes.MP(recBal, a.Currency)
	a.Owned = owner == me
	if a.IsLiability && limit != nil {
		avail := *limit + balance // balance is negative when money is owed
		if avail < 0 {
			avail = 0
		}
		a.AvailableCredit = apitypes.MP(&avail, a.Currency)
	}
	return &a, nil
}

// ListAccounts returns accounts (own + household-shared) with balances.
func (s *Service) ListAccounts(ctx context.Context, includeArchived bool) ([]AccountDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []AccountDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, accountSelect+` where ($1::boolean or a.status = 'active') order by a.user_id <> $2, a.display_order, a.created_at`, includeArchived, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			a, err := scanAccount(rows, uid)
			if err != nil {
				return err
			}
			out = append(out, *a)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

func getAccount(ctx context.Context, tx pgx.Tx, id, uid uuid.UUID) (*AccountDTO, error) {
	a, err := scanAccount(tx.QueryRow(ctx, accountSelect+` where a.id = $1`, id), uid)
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("account")
	}
	return a, err
}

// GetAccount returns one account.
func (s *Service) GetAccount(ctx context.Context, id uuid.UUID) (*AccountDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var a *AccountDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		a, err = getAccount(ctx, tx, id, uid)
		return err
	})
	return a, database.MapError(err)
}

// lockOwnedAccount locks an account owned by the caller for writes.
func lockOwnedAccount(ctx context.Context, tx pgx.Tx, id, uid uuid.UUID) (cur, status string, version int32, err error) {
	err = tx.QueryRow(ctx, `select currency, status, version from financial_accounts where id = $1 and user_id = $2 for update`, id, uid).Scan(&cur, &status, &version)
	if database.IsNoRows(err) {
		err = apperr.NotFound("account")
	}
	return
}

// AccountInput creates an account.
type AccountInput struct {
	Name              string  `json:"name" minLength:"1" maxLength:"80"`
	AccountType       string  `json:"account_type" enum:"cash,bank,savings,credit_card,debit_card,prepaid_card,digital_wallet,upi,loan,investment,household_ledger,custom"`
	Currency          string  `json:"currency" pattern:"^[A-Z]{3}$"`
	OpeningBalance    string  `json:"opening_balance,omitempty" doc:"Signed decimal; for credit cards and loans enter the amount owed as negative"`
	OpeningDate       string  `json:"opening_date,omitempty" doc:"YYYY-MM-DD; defaults to today"`
	InstitutionLabel  *string `json:"institution_label,omitempty" maxLength:"80"`
	Icon              *string `json:"icon,omitempty" maxLength:"40"`
	Color             *string `json:"color,omitempty" pattern:"^#[0-9A-Fa-f]{6}$"`
	Notes             *string `json:"notes,omitempty" maxLength:"1000"`
	MaskedNumber      *string `json:"masked_number,omitempty" pattern:"^[0-9]{2,4}$" doc:"Last 2-4 digits only; never the full number"`
	IncludeInOverview *bool   `json:"include_in_overview,omitempty"`
	CreditLimit       string  `json:"credit_limit,omitempty"`
	StatementDay      *int16  `json:"statement_day,omitempty" minimum:"1" maximum:"31"`
	PaymentDueDay     *int16  `json:"payment_due_day,omitempty" minimum:"1" maximum:"31"`
	DisplayOrder      *int32  `json:"display_order,omitempty"`
}

// CreateAccount creates an account and its opening-balance ledger event.
func (s *Service) CreateAccount(ctx context.Context, key string, in AccountInput) (*AccountDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	if !currency.Selectable(in.Currency) {
		return nil, false, apperr.FieldError("body.currency", "Unsupported currency.")
	}
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, false, apperr.FieldError("body.name", "Name is required.")
	}
	var opening int64
	if in.OpeningBalance != "" {
		if opening, err = ParseSignedAmount("body.opening_balance", in.OpeningBalance, in.Currency); err != nil {
			return nil, false, err
		}
	}
	var limit *int64
	if in.CreditLimit != "" {
		v, err := ParseSignedAmount("body.credit_limit", in.CreditLimit, in.Currency)
		if err != nil || v < 0 {
			return nil, false, apperr.FieldError("body.credit_limit", "Credit limit must be zero or positive.")
		}
		limit = &v
	}
	include := true
	if in.IncludeInOverview != nil {
		include = *in.IncludeInOverview
	}
	order := int32(0)
	if in.DisplayOrder != nil {
		order = *in.DisplayOrder
	}
	var out *AccountDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		openDate := todayIn(s.now(), u.Loc)
		if in.OpeningDate != "" {
			if openDate, err = ParseDate("body.opening_date", in.OpeningDate, u.Loc); err != nil {
				return err
			}
		}
		res, rep, err := idempotency.Run(ctx, tx, uid, key, "account.create", in, func() (AccountDTO, error) {
			id := uuid.New()
			if _, err := tx.Exec(ctx, `insert into financial_accounts (id, user_id, name, account_type, currency, institution_label, icon, color, notes,
				masked_number, include_in_overview, credit_limit_minor, statement_day, payment_due_day, opening_date, display_order)
				values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`, id, uid, name, in.AccountType, in.Currency,
				trimPtr(in.InstitutionLabel, 80), trimPtr(in.Icon, 40), in.Color, trimPtr(in.Notes, 1000), in.MaskedNumber, include, limit,
				in.StatementDay, in.PaymentDueDay, openDate, order); err != nil {
				return AccountDTO{}, err
			}
			if opening != 0 {
				dir := ledger.Inflow
				amt := opening
				if opening < 0 {
					dir, amt = ledger.Outflow, -opening
				}
				desc := "Opening balance"
				txID, err := insertSystemTransaction(ctx, tx, uid, id, ledger.TypeOpeningBalance, dir, amt, in.Currency, openDate, u, &desc, nil, "manual")
				if err != nil {
					return AccountDTO{}, err
				}
				if _, err := tx.Exec(ctx, `update financial_accounts set opening_transaction_id = $2 where id = $1`, id, txID); err != nil {
					return AccountDTO{}, err
				}
			}
			if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "account", EntityID: &id, Action: "created",
				Changes: map[string]any{"account_type": in.AccountType, "currency": in.Currency}}); err != nil {
				return AccountDTO{}, err
			}
			a, err := getAccount(ctx, tx, id, uid)
			if err != nil {
				return AccountDTO{}, err
			}
			return *a, nil
		})
		out, replayed = &res, rep
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return out, replayed, nil
}

func todayIn(now time.Time, loc *time.Location) time.Time {
	l := now.In(loc)
	return time.Date(l.Year(), l.Month(), l.Day(), 0, 0, 0, 0, loc)
}

// insertSystemTransaction writes a posted transaction (opening balance,
// adjustment) and its ledger entry.
func insertSystemTransaction(ctx context.Context, tx pgx.Tx, uid, accountID uuid.UUID, typ, dir string, amount int64, cur string,
	date time.Time, u UserContext, desc, notes *string, source string) (uuid.UUID, error) {
	id := uuid.New()
	occurred := time.Date(date.Year(), date.Month(), date.Day(), 12, 0, 0, 0, u.Loc)
	if _, err := tx.Exec(ctx, `insert into transactions (id, user_id, account_id, type, direction, status, amount_minor, currency,
		occurred_at, local_date, timezone, posted_at, description, notes, source)
		values ($1,$2,$3,$4,$5,'posted',$6,$7,$8,$9,$10,now(),$11,$12,$13)`, id, uid, accountID, typ, dir, amount, cur, occurred, date,
		u.Timezone, desc, notes, source); err != nil {
		return uuid.Nil, err
	}
	if err := postLedger(ctx, tx, uid, id, accountID, 1, dir, amount, cur, date); err != nil {
		return uuid.Nil, err
	}
	if err := txAudit(ctx, tx, uid, id, "user", "created", 1, map[string]any{"type": typ}); err != nil {
		return uuid.Nil, err
	}
	return id, outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.created", AggregateType: "transaction", AggregateID: id, UserID: &uid,
		Payload: map[string]any{"account_id": accountID, "type": typ, "local_date": LocalDateString(date)}})
}

// AccountPatch updates account fields.
type AccountPatch struct {
	Version           int32      `json:"version" doc:"Current version (optimistic concurrency)"`
	Name              *string    `json:"name,omitempty" minLength:"1" maxLength:"80"`
	Currency          *string    `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Only allowed before any transaction exists"`
	InstitutionLabel  *string    `json:"institution_label,omitempty" maxLength:"80"`
	Icon              *string    `json:"icon,omitempty" maxLength:"40"`
	Color             *string    `json:"color,omitempty" pattern:"^#[0-9A-Fa-f]{6}$"`
	Notes             *string    `json:"notes,omitempty" maxLength:"1000"`
	MaskedNumber      *string    `json:"masked_number,omitempty" pattern:"^([0-9]{2,4})?$"`
	IncludeInOverview *bool      `json:"include_in_overview,omitempty"`
	CreditLimit       *string    `json:"credit_limit,omitempty" doc:"Decimal; empty string clears"`
	StatementDay      *int16     `json:"statement_day,omitempty" minimum:"0" maximum:"31" doc:"1-31; 0 clears it"`
	PaymentDueDay     *int16     `json:"payment_due_day,omitempty" minimum:"0" maximum:"31" doc:"1-31; 0 clears it"`
	DisplayOrder      *int32     `json:"display_order,omitempty"`
	ShareWithGroupID  *uuid.UUID `json:"share_with_group_id,omitempty" doc:"Share read-only with a household you belong to"`
	StopSharing       bool       `json:"stop_sharing,omitempty"`
}

// UpdateAccount applies a patch with optimistic concurrency.
func (s *Service) UpdateAccount(ctx context.Context, id uuid.UUID, p AccountPatch) (*AccountDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *AccountDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		cur, _, version, err := lockOwnedAccount(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		if version != p.Version {
			return apperr.VersionConflict()
		}
		newCur := cur
		if p.Currency != nil && *p.Currency != cur {
			if !currency.Selectable(*p.Currency) {
				return apperr.FieldError("body.currency", "Unsupported currency.")
			}
			var n int
			if err := tx.QueryRow(ctx, `select count(*) from transactions where account_id = $1`, id).Scan(&n); err != nil {
				return err
			}
			if n > 0 {
				return apperr.Rule("currency_locked", "The currency cannot change after transactions exist. Create a new account instead.", nil)
			}
			newCur = *p.Currency
		}
		var limit *int64
		setLimit := false
		if p.CreditLimit != nil {
			setLimit = true
			if *p.CreditLimit != "" {
				v, err := ParseSignedAmount("body.credit_limit", *p.CreditLimit, newCur)
				if err != nil || v < 0 {
					return apperr.FieldError("body.credit_limit", "Credit limit must be zero or positive.")
				}
				limit = &v
			}
		}
		var groupID *uuid.UUID
		setShare := false
		if p.StopSharing {
			setShare = true
		} else if p.ShareWithGroupID != nil {
			var gtype string
			var member bool
			err := tx.QueryRow(ctx, `select g.group_type, montra.is_group_member(g.id) from groups g where g.id = $1 and g.status = 'active'`, *p.ShareWithGroupID).Scan(&gtype, &member)
			if database.IsNoRows(err) || (err == nil && !member) {
				return apperr.NotFound("group")
			}
			if err != nil {
				return err
			}
			if gtype != "household" {
				return apperr.Rule("share_household_only", "Accounts can only be shared with a household.", nil)
			}
			setShare, groupID = true, p.ShareWithGroupID
		}
		var masked *string
		setMasked := p.MaskedNumber != nil
		if setMasked && *p.MaskedNumber != "" {
			masked = p.MaskedNumber
		}
		if _, err := tx.Exec(ctx, `update financial_accounts set
			name = coalesce($3, name), currency = $4,
			institution_label = case when $5::text is null then institution_label else nullif($5, '') end,
			icon = coalesce($6, icon), color = coalesce($7, color),
			notes = case when $8::text is null then notes else nullif($8, '') end,
			masked_number = case when $9 then $10 else masked_number end,
			include_in_overview = coalesce($11, include_in_overview),
			credit_limit_minor = case when $12 then $13 else credit_limit_minor end,
			statement_day = case when $14::smallint is null then statement_day else nullif($14::smallint, 0) end,
			payment_due_day = case when $15::smallint is null then payment_due_day else nullif($15::smallint, 0) end,
			display_order = coalesce($16, display_order),
			group_id = case when $17 then $18 else group_id end,
			shared_with_group = case when $17 then $18::uuid is not null else shared_with_group end,
			version = version + 1
			where id = $1 and user_id = $2`, id, uid, trimPtr(p.Name, 80), newCur, p.InstitutionLabel, p.Icon, p.Color, p.Notes,
			setMasked, masked, p.IncludeInOverview, setLimit, limit, p.StatementDay, p.PaymentDueDay, p.DisplayOrder, setShare, groupID); err != nil {
			return err
		}
		if setShare {
			// Household visibility of this account's transactions follows the account.
			if _, err := tx.Exec(ctx, `update transactions set group_id = $2 where account_id = $1`, id, groupID); err != nil {
				return err
			}
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "account", EntityID: &id, Action: "updated"}); err != nil {
			return err
		}
		out, err = getAccount(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(err)
}

// SetAccountStatus archives, restores or closes an account.
func (s *Service) SetAccountStatus(ctx context.Context, id uuid.UUID, action string, expectVersion int32) (*AccountDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *AccountDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, status, version, err := lockOwnedAccount(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		if expectVersion != 0 && expectVersion != version {
			return apperr.VersionConflict()
		}
		var target string
		switch action {
		case "archive":
			if status != "active" {
				return apperr.Conflict("Only active accounts can be archived.")
			}
			target = "archived"
		case "restore":
			if status == "active" {
				return apperr.Conflict("The account is already active.")
			}
			target = "active"
		case "close":
			var bal int64
			if err := tx.QueryRow(ctx, `select coalesce(sum(amount_minor), 0)::bigint from account_ledger_entries where account_id = $1`, id).Scan(&bal); err != nil {
				return err
			}
			if bal != 0 {
				return apperr.Rule("balance_not_zero", "Transfer or adjust the remaining balance to zero before closing this account.", nil)
			}
			target = "closed"
		default:
			return apperr.BadRequest("Unknown action.")
		}
		if _, err := tx.Exec(ctx, `update financial_accounts set status = $2, version = version + 1,
			archived_at = case when $2 = 'archived' then now() when $2 = 'active' then null else archived_at end,
			closed_at = case when $2 = 'closed' then now() when $2 = 'active' then null else closed_at end
			where id = $1`, id, target); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "account", EntityID: &id, Action: action}); err != nil {
			return err
		}
		out, err = getAccount(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(err)
}

// AdjustmentInput corrects a balance with an auditable adjustment.
type AdjustmentInput struct {
	TargetBalance string `json:"target_balance,omitempty" doc:"Desired balance (signed decimal); or use delta"`
	Delta         string `json:"delta,omitempty" doc:"Signed change"`
	Reason        string `json:"reason" minLength:"3" maxLength:"500"`
	EffectiveDate string `json:"effective_date,omitempty" doc:"YYYY-MM-DD; defaults to today"`
}

// AdjustBalance records a manual balance correction (never overwrites the
// derived balance; spec §20B.4).
func (s *Service) AdjustBalance(ctx context.Context, id uuid.UUID, key string, in AdjustmentInput) (*AccountDTO, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	if (in.TargetBalance == "") == (in.Delta == "") {
		return nil, false, apperr.Validation("Provide either target_balance or delta.")
	}
	var out AccountDTO
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		cur, status, _, err := lockOwnedAccount(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		if status != "active" {
			return apperr.Rule("account_inactive", "Restore the account before adjusting its balance.", nil)
		}
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		date := todayIn(s.now(), u.Loc)
		if in.EffectiveDate != "" {
			if date, err = ParseDate("body.effective_date", in.EffectiveDate, u.Loc); err != nil {
				return err
			}
		}
		out, replayed, err = idempotency.Run(ctx, tx, uid, key, "account.adjust:"+id.String(), in, func() (AccountDTO, error) {
			var delta int64
			if in.Delta != "" {
				if delta, err = ParseSignedAmount("body.delta", in.Delta, cur); err != nil {
					return AccountDTO{}, err
				}
			} else {
				target, err := ParseSignedAmount("body.target_balance", in.TargetBalance, cur)
				if err != nil {
					return AccountDTO{}, err
				}
				var bal int64
				if err := tx.QueryRow(ctx, `select coalesce(sum(amount_minor), 0)::bigint from account_ledger_entries where account_id = $1 and effective_date <= $2`,
					id, date).Scan(&bal); err != nil {
					return AccountDTO{}, err
				}
				delta = target - bal
			}
			if delta == 0 {
				return AccountDTO{}, apperr.Rule("balance_already_matches", "The balance already matches; no adjustment is needed.", nil)
			}
			dir, amt := ledger.Inflow, delta
			if delta < 0 {
				dir, amt = ledger.Outflow, -delta
			}
			desc := "Balance adjustment"
			reason := strings.TrimSpace(in.Reason)
			if _, err := insertSystemTransaction(ctx, tx, uid, id, ledger.TypeAdjustment, dir, amt, cur, date, u, &desc, &reason, "correction"); err != nil {
				return AccountDTO{}, err
			}
			if _, err := tx.Exec(ctx, `update financial_accounts set balance_source = 'manual', version = version + 1 where id = $1`, id); err != nil {
				return AccountDTO{}, err
			}
			if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "account", EntityID: &id, Action: "balance_adjusted",
				Changes: map[string]any{"delta_minor": delta, "reason": reason}}); err != nil {
				return AccountDTO{}, err
			}
			a, err := getAccount(ctx, tx, id, uid)
			if err != nil {
				return AccountDTO{}, err
			}
			return *a, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &out, replayed, nil
}

// BalancePoint is a daily balance.
type BalancePoint struct {
	Date    string         `json:"date"`
	Balance apitypes.Money `json:"balance"`
}

// BalanceReport is an account balance with optional history.
type BalanceReport struct {
	AccountID     uuid.UUID      `json:"account_id"`
	AsOf          string         `json:"as_of"`
	Balance       apitypes.Money `json:"balance"`
	BalanceSource string         `json:"balance_source"`
	Verified      bool           `json:"verified" doc:"True only for provider-synchronized balances; tracked balances are user-maintained"`
	History       []BalancePoint `json:"history"`
}

// Balance returns the balance as of a date and an optional daily history.
func (s *Service) Balance(ctx context.Context, id uuid.UUID, asOf, from, to string) (*BalanceReport, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out BalanceReport
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		a, err := getAccount(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		at := todayIn(s.now(), u.Loc)
		if asOf != "" {
			if at, err = ParseDate("query.as_of", asOf, u.Loc); err != nil {
				return err
			}
		}
		var bal int64
		if err := tx.QueryRow(ctx, `select coalesce(sum(amount_minor), 0)::bigint from account_ledger_entries where account_id = $1 and effective_date <= $2`,
			id, at).Scan(&bal); err != nil {
			return err
		}
		out = BalanceReport{AccountID: id, AsOf: LocalDateString(at), Balance: m(bal, a.Currency), BalanceSource: a.BalanceSource,
			Verified: a.BalanceSource == "provider", History: []BalancePoint{}}
		if from == "" {
			return nil
		}
		f, err := ParseDate("query.from", from, u.Loc)
		if err != nil {
			return err
		}
		t := at
		if to != "" {
			if t, err = ParseDate("query.to", to, u.Loc); err != nil {
				return err
			}
		}
		if t.Before(f) || t.Sub(f) > 731*24*time.Hour {
			return apperr.FieldError("query.from", "History range must be between 1 day and 2 years.")
		}
		rows, err := tx.Query(ctx, `with days as (select d::date as day from generate_series($2::date, $3::date, interval '1 day') d),
			opening as (select coalesce(sum(amount_minor), 0)::bigint as v from account_ledger_entries where account_id = $1 and effective_date < $2),
			daily as (select effective_date, sum(amount_minor)::bigint as s from account_ledger_entries
			          where account_id = $1 and effective_date between $2 and $3 group by effective_date)
			select days.day, ((select v from opening) + coalesce(sum(daily.s) over (order by days.day), 0))::bigint
			from days left join daily on daily.effective_date = days.day order by days.day`, id, f, t)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var d time.Time
			var b int64
			if err := rows.Scan(&d, &b); err != nil {
				return err
			}
			out.History = append(out.History, BalancePoint{Date: LocalDateString(d), Balance: m(b, a.Currency)})
		}
		return rows.Err()
	})
	return &out, database.MapError(err)
}
