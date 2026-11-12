package finance

import (
	"context"
	"encoding/json"
	"math/big"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/ledger"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/idempotency"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/outbox"
)

// CategoryRef is a compact category reference.
type CategoryRef struct {
	ID        uuid.UUID  `json:"id"`
	Name      string     `json:"name"`
	Icon      *string    `json:"icon,omitempty"`
	Color     *string    `json:"color,omitempty"`
	ParentID  *uuid.UUID `json:"parent_id,omitempty"`
	SystemKey *string    `json:"system_key,omitempty" doc:"Starter category key (localize the name by it unless the user renamed it)"`
}

// MerchantRef is a compact merchant reference.
type MerchantRef struct {
	ID   uuid.UUID `json:"id"`
	Name string    `json:"name"`
}

// TagRef is a compact tag reference.
type TagRef struct {
	ID    uuid.UUID `json:"id"`
	Name  string    `json:"name"`
	Color *string   `json:"color,omitempty"`
}

// TransactionDTO is a transaction as returned by the API.
type TransactionDTO struct {
	ID                    uuid.UUID       `json:"id"`
	AccountID             uuid.UUID       `json:"account_id"`
	AccountName           string          `json:"account_name"`
	Type                  string          `json:"type" enum:"expense,income,transfer,refund,reimbursement,adjustment,opening_balance,group_expense,settlement"`
	Direction             string          `json:"direction" enum:"inflow,outflow"`
	Status                string          `json:"status" enum:"draft,pending,posted,voided,reversed"`
	Amount                apitypes.Money  `json:"amount"`
	OriginalAmount        *apitypes.Money `json:"original_amount,omitempty" doc:"Foreign-currency amount when the account was charged in another currency"`
	FXRate                *string         `json:"fx_rate,omitempty" doc:"Account-currency units per original-currency unit"`
	FXRateSource          *string         `json:"fx_rate_source,omitempty"`
	FXRateAt              *time.Time      `json:"fx_rate_at,omitempty"`
	OccurredAt            time.Time       `json:"occurred_at"`
	LocalDate             string          `json:"local_date"`
	Timezone              string          `json:"timezone"`
	PostedAt              *time.Time      `json:"posted_at,omitempty"`
	Category              *CategoryRef    `json:"category,omitempty"`
	Merchant              *MerchantRef    `json:"merchant,omitempty"`
	PaymentMethodID       *uuid.UUID      `json:"payment_method_id,omitempty"`
	Description           *string         `json:"description,omitempty"`
	Notes                 *string         `json:"notes,omitempty"`
	LocationText          *string         `json:"location_text,omitempty"`
	Tags                  []TagRef        `json:"tags"`
	OriginalTransactionID *uuid.UUID      `json:"original_transaction_id,omitempty"`
	TransferID            *uuid.UUID      `json:"transfer_id,omitempty"`
	RecurringRuleID       *uuid.UUID      `json:"recurring_rule_id,omitempty"`
	GroupExpenseID        *uuid.UUID      `json:"group_expense_id,omitempty"`
	SettlementID          *uuid.UUID      `json:"settlement_id,omitempty"`
	ReceiptID             *uuid.UUID      `json:"receipt_id,omitempty"`
	PersonalShare         *apitypes.Money `json:"personal_share,omitempty" doc:"For group expenses: the share counted as your spending"`
	RefundedTotal         apitypes.Money  `json:"refunded_total" doc:"Sum of active refunds/reimbursements linked to this transaction"`
	Source                string          `json:"source"`
	ExternalID            *string         `json:"external_id,omitempty"`
	ReconciliationState   string          `json:"reconciliation_state" enum:"unreconciled,matched,reconciled,excluded"`
	IsCorrection          bool            `json:"is_correction"`
	AttachmentCount       int32           `json:"attachment_count"`
	Owned                 bool            `json:"owned"`
	Version               int32           `json:"version"`
	CreatedAt             time.Time       `json:"created_at"`
	UpdatedAt             time.Time       `json:"updated_at"`
	DeletedAt             *time.Time      `json:"deleted_at,omitempty"`
}

const txSelect = `select t.id, t.account_id, a.name, t.type, t.direction, t.status, t.amount_minor, t.currency,
	t.original_amount_minor, t.original_currency, t.fx_rate::text, t.fx_rate_source, t.fx_rate_at,
	t.occurred_at, t.local_date, t.timezone, t.posted_at,
	t.category_id, c.name, c.icon, c.color, c.parent_id, c.system_key, t.merchant_id, mer.name,
	t.payment_method_id, t.description, t.notes, t.location_text,
	t.original_transaction_id, t.transfer_id, t.recurring_rule_id, t.group_expense_id, t.settlement_id, t.receipt_id,
	t.personal_share_minor, t.source, t.external_id, t.reconciliation_state, t.is_correction,
	(select coalesce(sum(r.amount_minor), 0) from transactions r where r.original_transaction_id = t.id and r.deleted_at is null
	   and r.type in ('refund','reimbursement'))::bigint,
	(select count(*) from transaction_attachments ta where ta.transaction_id = t.id)::int,
	coalesce((select jsonb_agg(jsonb_build_object('id', tg.id, 'name', tg.name, 'color', tg.color) order by tg.name)
	   from transaction_tags tt join tags tg on tg.id = tt.tag_id where tt.transaction_id = t.id), '[]'::jsonb),
	t.version, t.created_at, t.updated_at, t.deleted_at, t.user_id
	from transactions t join financial_accounts a on a.id = t.account_id
	left join categories c on c.id = t.category_id left join merchants mer on mer.id = t.merchant_id`

func scanTx(r pgx.Row, me uuid.UUID) (*TransactionDTO, error) {
	var t TransactionDTO
	var amount, refunded int64
	var cur string
	var origAmt *int64
	var origCur *string
	var localDate time.Time
	var catID, catParent, merID *uuid.UUID
	var catName, catIcon, catColor, catKey, merName *string
	var share *int64
	var tagsJSON []byte
	var owner uuid.UUID
	if err := r.Scan(&t.ID, &t.AccountID, &t.AccountName, &t.Type, &t.Direction, &t.Status, &amount, &cur,
		&origAmt, &origCur, &t.FXRate, &t.FXRateSource, &t.FXRateAt, &t.OccurredAt, &localDate, &t.Timezone, &t.PostedAt,
		&catID, &catName, &catIcon, &catColor, &catParent, &catKey, &merID, &merName, &t.PaymentMethodID, &t.Description, &t.Notes, &t.LocationText,
		&t.OriginalTransactionID, &t.TransferID, &t.RecurringRuleID, &t.GroupExpenseID, &t.SettlementID, &t.ReceiptID,
		&share, &t.Source, &t.ExternalID, &t.ReconciliationState, &t.IsCorrection, &refunded, &t.AttachmentCount, &tagsJSON,
		&t.Version, &t.CreatedAt, &t.UpdatedAt, &t.DeletedAt, &owner); err != nil {
		return nil, err
	}
	t.Amount = m(amount, cur)
	t.RefundedTotal = m(refunded, cur)
	t.LocalDate = LocalDateString(localDate)
	t.Owned = owner == me
	if origAmt != nil && origCur != nil {
		om := m(*origAmt, *origCur)
		t.OriginalAmount = &om
	}
	if catID != nil && catName != nil {
		t.Category = &CategoryRef{ID: *catID, Name: *catName, Icon: catIcon, Color: catColor, ParentID: catParent, SystemKey: catKey}
	}
	if merID != nil && merName != nil {
		t.Merchant = &MerchantRef{ID: *merID, Name: *merName}
	}
	t.PersonalShare = apitypes.MP(share, cur)
	t.Tags = []TagRef{}
	_ = json.Unmarshal(tagsJSON, &t.Tags)
	if t.FXRate != nil {
		v := strings.TrimRight(strings.TrimRight(*t.FXRate, "0"), ".")
		t.FXRate = &v
	}
	return &t, nil
}

// sharedTxVisible matches the RLS rule for other people's transactions:
// only those in an account shared with a group the caller belongs to.
const sharedTxVisible = `exists (select 1 from financial_accounts sa where sa.id = t.account_id and sa.shared_with_group
	and sa.group_id is not null and montra.is_group_member(sa.group_id))`

func getTx(ctx context.Context, q pgx.Tx, id, me uuid.UUID) (*TransactionDTO, error) {
	t, err := scanTx(q.QueryRow(ctx, txSelect+` where t.id = $1 and (t.user_id = $2 or `+sharedTxVisible+`)`, id, me), me)
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("transaction")
	}
	return t, err
}

// GetTransaction returns one transaction visible to the caller.
func (s *Service) GetTransaction(ctx context.Context, id uuid.UUID) (*TransactionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var t *TransactionDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		t, err = getTx(ctx, tx, id, uid)
		return err
	})
	return t, database.MapError(err)
}

// TransactionInput creates an expense, income, refund or reimbursement.
type TransactionInput struct {
	Type                  string      `json:"type" enum:"expense,income,refund,reimbursement"`
	AccountID             uuid.UUID   `json:"account_id"`
	Amount                string      `json:"amount" doc:"Decimal in the account currency, e.g. 1234.50"`
	Currency              string      `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Optional; must equal the account currency"`
	OriginalAmount        string      `json:"original_amount,omitempty" doc:"Foreign amount actually charged (with original_currency)"`
	OriginalCurrency      string      `json:"original_currency,omitempty" pattern:"^[A-Z]{3}$"`
	FXFee                 string      `json:"fx_fee,omitempty" doc:"Foreign-exchange fee included in amount (informational)"`
	OccurredAt            *time.Time  `json:"occurred_at,omitempty"`
	LocalDate             string      `json:"local_date,omitempty" doc:"YYYY-MM-DD (used when occurred_at is omitted)"`
	Timezone              string      `json:"timezone,omitempty" maxLength:"64"`
	Status                string      `json:"status,omitempty" enum:"posted,pending,draft"`
	CategoryID            *uuid.UUID  `json:"category_id,omitempty"`
	MerchantID            *uuid.UUID  `json:"merchant_id,omitempty"`
	MerchantName          string      `json:"merchant_name,omitempty" maxLength:"120" doc:"Resolved to an existing merchant/alias or created"`
	PaymentMethodID       *uuid.UUID  `json:"payment_method_id,omitempty"`
	Description           string      `json:"description,omitempty" maxLength:"500"`
	Notes                 string      `json:"notes,omitempty" maxLength:"4000"`
	LocationText          string      `json:"location_text,omitempty" maxLength:"200" doc:"Requires location consent"`
	TagIDs                []uuid.UUID `json:"tag_ids,omitempty" maxItems:"20"`
	TagNames              []string    `json:"tag_names,omitempty" maxItems:"20" doc:"Created when missing"`
	OriginalTransactionID *uuid.UUID  `json:"original_transaction_id,omitempty" doc:"Required for reimbursements; optional link for refunds"`
	IsCorrection          bool        `json:"is_correction,omitempty" doc:"Explicit correction allowing refunds above the original"`
}

// DuplicateHint explains a possible duplicate (never auto-merged).
type DuplicateHint struct {
	TransactionID uuid.UUID `json:"transaction_id"`
	LocalDate     string    `json:"local_date"`
	Reasons       []string  `json:"reasons" doc:"English; localize by reason_codes"`
	ReasonCodes   []string  `json:"reason_codes" doc:"same_account_amount, same_date, within_days, same_description"`
	DaysApart     int       `json:"days_apart"`
}

// CreateResult wraps a created transaction with non-blocking warnings.
type CreateResult struct {
	Transaction        TransactionDTO  `json:"transaction"`
	PossibleDuplicates []DuplicateHint `json:"possible_duplicates"`
}

// CreateTransaction creates a transaction idempotently.
func (s *Service) CreateTransaction(ctx context.Context, key string, in TransactionInput) (*CreateResult, bool, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, false, err
	}
	var res CreateResult
	var replayed bool
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		res, replayed, err = idempotency.Run(ctx, tx, uid, key, "transaction.create", in, func() (CreateResult, error) {
			id, err := s.createTx(ctx, tx, uid, in, "manual", nil)
			if err != nil {
				return CreateResult{}, err
			}
			t, err := getTx(ctx, tx, id, uid)
			if err != nil {
				return CreateResult{}, err
			}
			dups, err := findDuplicates(ctx, tx, t)
			if err != nil {
				return CreateResult{}, err
			}
			return CreateResult{Transaction: *t, PossibleDuplicates: dups}, nil
		})
		return err
	})
	if err != nil {
		return nil, false, database.MapError(err)
	}
	return &res, replayed, nil
}

// Provenance carries source details for system-created transactions
// (imports, receipts, recurring generation).
type Provenance struct {
	ImportRowID   *uuid.UUID
	ReceiptID     *uuid.UUID
	RecurringRule *uuid.UUID
	Occurrence    *uuid.UUID
	ExternalID    *string
	Fingerprint   *string
	ActorKind     string
}

// CreateInTx creates a transaction inside an existing transaction (used by
// imports, receipts and recurring generation).
func (s *Service) CreateInTx(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in TransactionInput, source string, prov *Provenance) (uuid.UUID, error) {
	return s.createTx(ctx, tx, uid, in, source, prov)
}

func (s *Service) createTx(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in TransactionInput, source string, prov *Provenance) (uuid.UUID, error) {
	switch in.Type {
	case ledger.TypeExpense, ledger.TypeIncome, ledger.TypeRefund, ledger.TypeReimbursement:
	default:
		return uuid.Nil, apperr.FieldError("body.type", "Use the transfer, adjustment, group or settlement endpoints for this type.")
	}
	u, err := LoadUser(ctx, tx, uid)
	if err != nil {
		return uuid.Nil, err
	}
	var acctCur, acctStatus string
	var acctGroup *uuid.UUID
	var shared bool
	err = tx.QueryRow(ctx, `select currency, status, group_id, shared_with_group from financial_accounts where id = $1 and user_id = $2`,
		in.AccountID, uid).Scan(&acctCur, &acctStatus, &acctGroup, &shared)
	if database.IsNoRows(err) {
		return uuid.Nil, apperr.FieldError("body.account_id", "Choose one of your accounts.")
	}
	if err != nil {
		return uuid.Nil, err
	}
	if acctStatus != "active" {
		return uuid.Nil, apperr.Rule("account_inactive", "This account is archived or closed. Restore it to add transactions.", nil)
	}
	if in.Currency != "" && in.Currency != acctCur {
		return uuid.Nil, apperr.FieldError("body.currency", "Enter the amount in the account currency ("+acctCur+"); use original_amount for foreign currency.")
	}
	amount, err := ParseAmount("body.amount", in.Amount, acctCur)
	if err != nil {
		return uuid.Nil, err
	}
	var origAmt *int64
	var origCur, fxRate, fxSource *string
	var fxAt *time.Time
	if in.OriginalAmount != "" || in.OriginalCurrency != "" {
		if !currency.Valid(in.OriginalCurrency) || in.OriginalCurrency == acctCur {
			return uuid.Nil, apperr.FieldError("body.original_currency", "Provide a different, supported original currency.")
		}
		oa, err := ParseAmount("body.original_amount", in.OriginalAmount, in.OriginalCurrency)
		if err != nil {
			return uuid.Nil, err
		}
		rate := ratePerUnit(amount, acctCur, oa, in.OriginalCurrency)
		src := "manual"
		now := s.now()
		origAmt, origCur, fxRate, fxSource, fxAt = &oa, &in.OriginalCurrency, &rate, &src, &now
	}
	var fxFee *int64
	if in.FXFee != "" {
		f, err := ParseSignedAmount("body.fx_fee", in.FXFee, acctCur)
		if err != nil || f < 0 || f > amount {
			return uuid.Nil, apperr.FieldError("body.fx_fee", "FX fee must be between zero and the amount.")
		}
		fxFee = &f
	}
	tzName := u.Timezone
	loc := u.Loc
	if in.Timezone != "" {
		l, err := time.LoadLocation(in.Timezone)
		if err != nil || in.Timezone == "Local" {
			return uuid.Nil, apperr.FieldError("body.timezone", "Unknown time zone.")
		}
		tzName, loc = in.Timezone, l
	}
	occurred := s.now()
	var localDate time.Time
	switch {
	case in.OccurredAt != nil:
		occurred = *in.OccurredAt
		l := occurred.In(loc)
		localDate = time.Date(l.Year(), l.Month(), l.Day(), 0, 0, 0, 0, loc)
	case in.LocalDate != "":
		if localDate, err = ParseDate("body.local_date", in.LocalDate, loc); err != nil {
			return uuid.Nil, err
		}
		occurred = time.Date(localDate.Year(), localDate.Month(), localDate.Day(), 12, 0, 0, 0, loc)
	default:
		localDate = todayIn(occurred, loc)
	}
	if occurred.After(s.now().Add(400 * 24 * time.Hour)) {
		return uuid.Nil, apperr.FieldError("body.occurred_at", "Date is too far in the future.")
	}
	status := in.Status
	if status == "" {
		status = ledger.StatusPosted
	}
	dir := ledger.DirectionFor(in.Type)

	var origTxID *uuid.UUID
	var origCategory, origMerchant *uuid.UUID
	if in.OriginalTransactionID != nil {
		var oType, oCur, oStatus string
		var oAmt int64
		err := tx.QueryRow(ctx, `select type, currency, amount_minor, status, category_id, merchant_id from transactions
			where id = $1 and user_id = $2 for update`, *in.OriginalTransactionID, uid).Scan(&oType, &oCur, &oAmt, &oStatus, &origCategory, &origMerchant)
		if database.IsNoRows(err) {
			return uuid.Nil, apperr.FieldError("body.original_transaction_id", "Original transaction not found.")
		}
		if err != nil {
			return uuid.Nil, err
		}
		if in.Type != ledger.TypeRefund && in.Type != ledger.TypeReimbursement {
			return uuid.Nil, apperr.FieldError("body.original_transaction_id", "Only refunds and reimbursements link to an original.")
		}
		if !ledger.RefundableTypes(oType) || oStatus == ledger.StatusVoided {
			return uuid.Nil, apperr.Rule("original_not_refundable", "Only active expenses can be refunded or reimbursed.", nil)
		}
		if oCur != acctCur {
			return uuid.Nil, apperr.Rule("currency_mismatch", "The refund must be in the same currency as the original transaction.",
				map[string]string{"currency": oCur})
		}
		var already int64
		if err := tx.QueryRow(ctx, `select coalesce(sum(amount_minor), 0)::bigint from transactions where original_transaction_id = $1
			and deleted_at is null and type in ('refund','reimbursement')`, *in.OriginalTransactionID).Scan(&already); err != nil {
			return uuid.Nil, err
		}
		if err := ledger.CheckRefundCap(oAmt, already, amount, in.IsCorrection); err != nil {
			return uuid.Nil, apperr.Rule("refund_exceeds_remaining", "Refunds and reimbursements cannot exceed the original amount ("+
				money.Format(oAmt-already, oCur)+" remaining). Mark it as a correction if this is intentional.",
				map[string]string{"remaining": money.Format(oAmt-already, oCur), "currency": oCur})
		}
		origTxID = in.OriginalTransactionID
	} else if in.Type == ledger.TypeReimbursement {
		return uuid.Nil, apperr.FieldError("body.original_transaction_id", "A reimbursement must reference the original expense.")
	}

	merchantID, err := s.resolveMerchant(ctx, tx, uid, in.MerchantID, in.MerchantName)
	if err != nil {
		return uuid.Nil, err
	}
	if merchantID == nil && origMerchant != nil {
		merchantID = origMerchant // refunds net out of the original merchant's totals, as they do for its category
	}
	categoryID, ruleApplied, err := s.resolveCategory(ctx, tx, uid, in, merchantID, origCategory, source, amount, acctCur)
	if err != nil {
		return uuid.Nil, err
	}
	if in.PaymentMethodID != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from payment_methods where id = $1 and user_id = $2 and archived_at is null)`,
			*in.PaymentMethodID, uid).Scan(&ok); err != nil {
			return uuid.Nil, err
		}
		if !ok {
			return uuid.Nil, apperr.FieldError("body.payment_method_id", "Payment method not found.")
		}
	}
	var location *string
	if strings.TrimSpace(in.LocationText) != "" {
		var consent bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from user_consents where user_id = $1 and consent_type = 'location' and revoked_at is null)`,
			uid).Scan(&consent); err != nil {
			return uuid.Nil, err
		}
		if !consent {
			return uuid.Nil, apperr.New(apperr.CodeConsentRequired, 403, "Enable location consent in Privacy settings to save a location.")
		}
		location = trimPtr(&in.LocationText, 200)
	}
	if source == "manual" {
		if err := rejectSensitiveText(in.Description, in.Notes); err != nil {
			return uuid.Nil, err
		}
	}
	var groupID *uuid.UUID
	if shared {
		groupID = acctGroup
	}
	id := uuid.New()
	var postedAt *time.Time
	if status == ledger.StatusPosted {
		n := s.now()
		postedAt = &n
	}
	var importRow, receiptID, recRule, occ *uuid.UUID
	var extID, fp *string
	actor := "user"
	if prov != nil {
		importRow, receiptID, recRule, occ, extID, fp = prov.ImportRowID, prov.ReceiptID, prov.RecurringRule, prov.Occurrence, prov.ExternalID, prov.Fingerprint
		if prov.ActorKind != "" {
			actor = prov.ActorKind
		}
	}
	if _, err := tx.Exec(ctx, `insert into transactions (id, user_id, account_id, group_id, type, direction, status, amount_minor, currency,
		original_amount_minor, original_currency, fx_rate, fx_rate_source, fx_rate_at, fx_fee_minor, occurred_at, local_date, timezone, posted_at,
		category_id, merchant_id, payment_method_id, description, notes, location_text, original_transaction_id, is_correction, source,
		import_row_id, receipt_id, recurring_rule_id, recurring_occurrence_id, external_id, source_fingerprint)
		values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::numeric,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33,$34)`,
		id, uid, in.AccountID, groupID, in.Type, dir, status, amount, acctCur, origAmt, origCur, fxRate, fxSource, fxAt, fxFee,
		occurred, localDate, tzName, postedAt, categoryID, merchantID, in.PaymentMethodID, trimPtr(&in.Description, 500), trimPtr(&in.Notes, 4000),
		location, origTxID, in.IsCorrection, source, importRow, receiptID, recRule, occ, extID, fp); err != nil {
		if database.IsUniqueViolation(err, "transactions_external_id_key") {
			return uuid.Nil, apperr.New(apperr.CodeDuplicate, 409, "A transaction with this external reference already exists in the account.")
		}
		return uuid.Nil, err
	}
	if ledger.AffectsBalance(status) {
		if err := postLedger(ctx, tx, uid, id, in.AccountID, 1, dir, amount, acctCur, localDate); err != nil {
			return uuid.Nil, err
		}
	}
	if err := s.setTags(ctx, tx, uid, id, in.TagIDs, in.TagNames, false); err != nil {
		return uuid.Nil, err
	}
	if err := txAudit(ctx, tx, uid, id, actor, "created", 1, map[string]any{"type": in.Type, "source": source}); err != nil {
		return uuid.Nil, err
	}
	if ruleApplied != nil {
		if err := txAudit(ctx, tx, uid, id, "system", "rule_categorized", 1, map[string]any{"rule_id": *ruleApplied}); err != nil {
			return uuid.Nil, err
		}
	}
	if origTxID != nil {
		if err := txAudit(ctx, tx, uid, *origTxID, actor, in.Type+"_added", 0, map[string]any{"linked_transaction_id": id, "amount_minor": amount}); err != nil {
			return uuid.Nil, err
		}
	}
	return id, outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.created", AggregateType: "transaction", AggregateID: id, UserID: &uid,
		Payload: map[string]any{"account_id": in.AccountID, "type": in.Type, "local_date": LocalDateString(localDate), "category_id": categoryID}})
}

// ratePerUnit derives the exact conversion rate (account units per one
// original unit) from the two amounts, at 12 decimal places.
func ratePerUnit(amount int64, cur string, orig int64, origCur string) string {
	r := new(big.Rat).SetFrac64(amount, orig)
	r.Mul(r, new(big.Rat).SetFrac(pow10(currency.Exponent(origCur)), pow10(currency.Exponent(cur))))
	return money.FormatRate(r)
}

func pow10(n int) *big.Int { return new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(n)), nil) }

var digitRun = regexp.MustCompile(`(?:\d[ -]?){13,19}`)
var secretWords = regexp.MustCompile(`(?i)\b(cvv|cvc|upi pin|otp|one[- ]time password|netbanking password)\b\s*[:=]?\s*\d{3,8}`)

// rejectSensitiveText blocks card numbers (Luhn-valid 13-19 digits), CVVs,
// OTPs and PINs in manually entered free text (spec §4.3).
func rejectSensitiveText(texts ...string) error {
	for _, t := range texts {
		if secretWords.MatchString(t) {
			return apperr.FieldError("body.notes", "Do not store card numbers, CVVs, PINs or OTPs in Montra.")
		}
		for _, run := range digitRun.FindAllString(t, -1) {
			if luhn(strings.NewReplacer(" ", "", "-", "").Replace(run)) {
				return apperr.FieldError("body.notes", "Do not store card numbers, CVVs, PINs or OTPs in Montra.")
			}
		}
	}
	return nil
}

func luhn(d string) bool {
	if len(d) < 13 || len(d) > 19 {
		return false
	}
	sum, alt := 0, false
	for i := len(d) - 1; i >= 0; i-- {
		n := int(d[i] - '0')
		if alt {
			if n *= 2; n > 9 {
				n -= 9
			}
		}
		sum += n
		alt = !alt
	}
	return sum%10 == 0
}

func strOr(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

// ResolveMerchantName resolves a merchant by name or alias, creating it when
// missing (used by recurring rules, bills and subscriptions).
func (s *Service) ResolveMerchantName(ctx context.Context, tx pgx.Tx, uid uuid.UUID, name string) (*uuid.UUID, error) {
	return s.resolveMerchant(ctx, tx, uid, nil, name)
}

// resolveMerchant returns a merchant ID from an explicit ID or a name
// (matching aliases and canonical names before creating a new merchant).
func (s *Service) resolveMerchant(ctx context.Context, tx pgx.Tx, uid uuid.UUID, id *uuid.UUID, name string) (*uuid.UUID, error) {
	if id != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from merchants where id = $1 and user_id = $2 and status <> 'merged')`, *id, uid).Scan(&ok); err != nil {
			return nil, err
		}
		if !ok {
			return nil, apperr.FieldError("body.merchant_id", "Merchant not found.")
		}
		return id, nil
	}
	n := NormalizeName(name)
	if n == "" {
		return nil, nil
	}
	if len([]rune(n)) > 120 {
		n = string([]rune(n)[:120])
	}
	var mid uuid.UUID
	err := tx.QueryRow(ctx, `select merchant_id from merchant_aliases where user_id = $1 and alias_normalized = $2`, uid, n).Scan(&mid)
	if err == nil {
		return &mid, nil
	}
	if !database.IsNoRows(err) {
		return nil, err
	}
	display := strings.Join(strings.Fields(name), " ")
	if len([]rune(display)) > 120 {
		display = string([]rune(display)[:120])
	}
	err = tx.QueryRow(ctx, `insert into merchants (user_id, name, name_normalized) values ($1,$2,$3)
		on conflict (user_id, name_normalized) where status <> 'merged' do update set updated_at = merchants.updated_at
		returning id`, uid, display, n).Scan(&mid)
	if err != nil {
		return nil, err
	}
	return &mid, nil
}

// resolveCategory validates an explicit category, or derives one from the
// merchant default, the original (refunds) or categorization rules.
func (s *Service) resolveCategory(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in TransactionInput, merchantID, origCategory *uuid.UUID,
	source string, amount int64, currency string) (*uuid.UUID, *uuid.UUID, error) {
	if in.CategoryID != nil {
		if err := validateCategoryFor(ctx, tx, uid, *in.CategoryID, in.Type); err != nil {
			return nil, nil, err
		}
		return in.CategoryID, nil, nil
	}
	if (in.Type == ledger.TypeRefund || in.Type == ledger.TypeReimbursement) && origCategory != nil {
		return origCategory, nil, nil
	}
	if merchantID != nil {
		var def *uuid.UUID
		if err := tx.QueryRow(ctx, `select m.default_category_id from merchants m join categories c on c.id = m.default_category_id
			where m.id = $1 and c.status = 'active'`, *merchantID).Scan(&def); err == nil && def != nil {
			return def, nil, nil
		} else if err != nil && !database.IsNoRows(err) {
			return nil, nil, err
		}
	}
	return s.applyRules(ctx, tx, uid, in, merchantID, source, amount, currency)
}

func validateCategoryFor(ctx context.Context, tx pgx.Tx, uid, catID uuid.UUID, typ string) error {
	return validateCategoryAt(ctx, tx, uid, catID, typ, "body.category_id")
}

// validateCategoryAt checks that catID is one of the caller's active
// categories and fits the transaction type, reporting problems on field.
func validateCategoryAt(ctx context.Context, tx pgx.Tx, uid, catID uuid.UUID, typ, field string) error {
	var kind, status string
	err := tx.QueryRow(ctx, `select kind, status from categories where id = $1 and user_id = $2`, catID, uid).Scan(&kind, &status)
	if database.IsNoRows(err) {
		return apperr.FieldError(field, "Category not found.")
	}
	if err != nil {
		return err
	}
	if status != "active" {
		return apperr.FieldError(field, "This category is archived.")
	}
	if (typ == ledger.TypeExpense && kind == "income") || (typ == ledger.TypeIncome && kind == "expense") {
		return apperr.FieldError(field, "Choose a category that matches the transaction type.")
	}
	return nil
}

// applyRules evaluates enabled categorization rules in priority order;
// the first match wins (deterministic and explainable, spec §20B.6).
func (s *Service) applyRules(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in TransactionInput, merchantID *uuid.UUID,
	source string, amount int64, currency string) (*uuid.UUID, *uuid.UUID, error) {
	scope := "manual"
	if source == "import" {
		scope = "imports"
	}
	var merchantName string
	if merchantID != nil {
		_ = tx.QueryRow(ctx, `select name from merchants where id = $1`, *merchantID).Scan(&merchantName)
	}
	rows, err := tx.Query(ctx, `select r.id, r.match_field, r.match_type, r.pattern, r.amount_min_minor, r.amount_max_minor, r.amount_currency,
		r.account_id, r.transaction_type, r.set_category_id from category_rules r join categories c on c.id = r.set_category_id
		where r.user_id = $1 and r.enabled and r.apply_to in ($2, 'all') and c.status = 'active' order by r.priority, r.created_at`, uid, scope)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var rule Rule
		if err := rows.Scan(&rule.ID, &rule.MatchField, &rule.MatchType, &rule.Pattern, &rule.AmountMin, &rule.AmountMax, &rule.Currency,
			&rule.AccountID, &rule.TransactionType, &rule.SetCategoryID); err != nil {
			return nil, nil, err
		}
		if rule.Matches(in.Description, merchantName, amount, currency, in.AccountID, in.Type) {
			cid, rid := rule.SetCategoryID, rule.ID
			return &cid, &rid, nil
		}
	}
	return nil, nil, rows.Err()
}

// Rule is a categorization rule.
type Rule struct {
	ID              uuid.UUID
	MatchField      string
	MatchType       string
	Pattern         string
	AmountMin       *int64
	AmountMax       *int64
	Currency        *string // currency of AmountMin/AmountMax
	AccountID       *uuid.UUID
	TransactionType *string
	SetCategoryID   uuid.UUID
}

// Matches evaluates the rule (case-insensitive; regex uses RE2, linear time).
// Amount bounds apply only to transactions in the bounds' currency: a rule
// for 100–500 INR never matches 300 USD.
func (r Rule) Matches(description, merchant string, amount int64, currency string, account uuid.UUID, typ string) bool {
	if r.AccountID != nil && *r.AccountID != account {
		return false
	}
	if (r.AmountMin != nil || r.AmountMax != nil) && r.Currency != nil && *r.Currency != currency {
		return false
	}
	if r.TransactionType != nil && *r.TransactionType != typ {
		return false
	}
	if (r.AmountMin != nil && amount < *r.AmountMin) || (r.AmountMax != nil && amount > *r.AmountMax) {
		return false
	}
	var subjects []string
	switch r.MatchField {
	case "description":
		subjects = []string{description}
	case "merchant":
		subjects = []string{merchant}
	default:
		subjects = []string{description, merchant}
	}
	p := strings.ToLower(r.Pattern)
	for _, sub := range subjects {
		sub = strings.ToLower(sub)
		if sub == "" {
			continue
		}
		switch r.MatchType {
		case "contains":
			if strings.Contains(sub, p) {
				return true
			}
		case "equals":
			if strings.TrimSpace(sub) == strings.TrimSpace(p) {
				return true
			}
		case "starts_with":
			if strings.HasPrefix(strings.TrimSpace(sub), p) {
				return true
			}
		case "regex":
			if re, err := regexp.Compile("(?i)" + r.Pattern); err == nil && re.MatchString(sub) {
				return true
			}
		}
	}
	return false
}

// setTags attaches tags (by ID or by name, creating missing names).
func (s *Service) setTags(ctx context.Context, tx pgx.Tx, uid, txID uuid.UUID, ids []uuid.UUID, names []string, replace bool) error {
	if replace {
		if _, err := tx.Exec(ctx, `delete from transaction_tags where transaction_id = $1`, txID); err != nil {
			return err
		}
	}
	for _, n := range names {
		display := strings.TrimSpace(n)
		norm := NormalizeName(n)
		if norm == "" || len([]rune(norm)) > 40 {
			return apperr.FieldError("body.tag_names", "Tag names must be 1-40 characters.")
		}
		var tid uuid.UUID
		// Using an archived tag's name restores the tag (a new version).
		if err := tx.QueryRow(ctx, `insert into tags (user_id, name, name_normalized) values ($1,$2,$3)
			on conflict (user_id, name_normalized) do update set archived_at = null,
			version = tags.version + case when tags.archived_at is null then 0 else 1 end returning id`, uid, display, norm).Scan(&tid); err != nil {
			return err
		}
		ids = append(ids, tid)
	}
	for _, tid := range ids {
		tag, err := tx.Exec(ctx, `insert into transaction_tags (transaction_id, tag_id, user_id)
			select $1, id, $3 from tags where id = $2 and user_id = $3 on conflict do nothing`, txID, tid, uid)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			var exists bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from tags where id = $1 and user_id = $2)`, tid, uid).Scan(&exists); err != nil {
				return err
			}
			if !exists {
				return apperr.FieldError("body.tag_ids", "Tag not found.")
			}
		}
	}
	return nil
}

// DuplicateCandidates explains possible duplicates of one of the caller's
// transactions (same account and amount within 3 days); never merges.
func (s *Service) DuplicateCandidates(ctx context.Context, id uuid.UUID) ([]DuplicateHint, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out []DuplicateHint
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		t, err := getTx(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		out, err = findDuplicates(ctx, tx, t)
		return err
	})
	return out, database.MapError(err)
}

// findDuplicates suggests possible duplicates with explainable reasons.
func findDuplicates(ctx context.Context, tx pgx.Tx, t *TransactionDTO) ([]DuplicateHint, error) {
	rows, err := tx.Query(ctx, `select id, local_date, coalesce(description, ''), abs(local_date - $3::date)
		from transactions where account_id = $1 and amount_minor = $2 and id <> $4 and deleted_at is null
		and type = $5 and local_date between $3::date - 3 and $3::date + 3 order by abs(local_date - $3::date) limit 5`,
		t.AccountID, t.Amount.AmountMinor, t.LocalDate, t.ID, t.Type)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []DuplicateHint{}
	desc := NormalizeName(strOr(t.Description))
	for rows.Next() {
		var id uuid.UUID
		var d time.Time
		var other string
		var days int
		if err := rows.Scan(&id, &d, &other, &days); err != nil {
			return nil, err
		}
		reasons, codes := []string{"same account and amount"}, []string{"same_account_amount"}
		if days == 0 {
			reasons, codes = append(reasons, "same date"), append(codes, "same_date")
		} else {
			reasons, codes = append(reasons, "within "+itoa(days)+" day(s)"), append(codes, "within_days")
		}
		if desc != "" && NormalizeName(other) == desc {
			reasons, codes = append(reasons, "same description"), append(codes, "same_description")
		}
		out = append(out, DuplicateHint{TransactionID: id, LocalDate: LocalDateString(d), Reasons: reasons, ReasonCodes: codes, DaysApart: days})
	}
	return out, rows.Err()
}

func itoa(n int) string {
	return strings.TrimSpace(strings.ReplaceAll(big.NewInt(int64(n)).String(), " ", ""))
}
