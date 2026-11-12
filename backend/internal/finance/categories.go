package finance

import (
	"context"
	"errors"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
)

// CategoryDTO is a category (flat list; parent_id builds the tree).
type CategoryDTO struct {
	ID               uuid.UUID  `json:"id"`
	ParentID         *uuid.UUID `json:"parent_id,omitempty"`
	Name             string     `json:"name"`
	Kind             string     `json:"kind" enum:"expense,income,both"`
	Icon             *string    `json:"icon,omitempty"`
	Color            *string    `json:"color,omitempty"`
	SystemKey        *string    `json:"system_key,omitempty" doc:"Starter category key for localization"`
	IncludeInBudgets bool       `json:"include_in_budgets"`
	SortOrder        int32      `json:"sort_order"`
	Status           string     `json:"status" enum:"active,archived,merged"`
	MergedIntoID     *uuid.UUID `json:"merged_into_id,omitempty"`
	TransactionCount int64      `json:"transaction_count"`
	Version          int32      `json:"version"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

const catSelect = `select c.id, c.parent_id, c.name, c.kind, c.icon, c.color, c.system_key, c.include_in_budgets, c.sort_order, c.status,
	c.merged_into_id, (select count(*) from transactions t where t.category_id = c.id and t.deleted_at is null), c.version, c.updated_at
	from categories c`

func scanCat(r pgx.Row) (*CategoryDTO, error) {
	var c CategoryDTO
	err := r.Scan(&c.ID, &c.ParentID, &c.Name, &c.Kind, &c.Icon, &c.Color, &c.SystemKey, &c.IncludeInBudgets, &c.SortOrder, &c.Status,
		&c.MergedIntoID, &c.TransactionCount, &c.Version, &c.UpdatedAt)
	return &c, err
}

// ListCategories returns the caller's categories.
func (s *Service) ListCategories(ctx context.Context, includeArchived bool) ([]CategoryDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []CategoryDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, catSelect+` where c.user_id = $1 and (c.status = 'active' or ($2 and c.status = 'archived'))
			order by coalesce(c.parent_id, c.id), c.parent_id nulls first, c.sort_order, c.name`, uid, includeArchived)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			c, err := scanCat(rows)
			if err != nil {
				return err
			}
			out = append(out, *c)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

func getCat(ctx context.Context, tx pgx.Tx, id, uid uuid.UUID) (*CategoryDTO, error) {
	c, err := scanCat(tx.QueryRow(ctx, catSelect+` where c.id = $1 and c.user_id = $2`, id, uid))
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("category")
	}
	return c, err
}

// GetCategory returns one of the caller's categories in any status (so a
// merged category's merged_into_id can be followed).
func (s *Service) GetCategory(ctx context.Context, id uuid.UUID) (*CategoryDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *CategoryDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out, err = getCat(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(err)
}

// CategoryInput creates a category or subcategory.
type CategoryInput struct {
	Name             string     `json:"name" minLength:"1" maxLength:"60"`
	Kind             string     `json:"kind" enum:"expense,income,both"`
	ParentID         *uuid.UUID `json:"parent_id,omitempty"`
	Icon             *string    `json:"icon,omitempty" maxLength:"40" doc:"Icon name (up to 40 characters; not checked against a list). The starter categories use these Material Symbols names: restaurant, shopping_cart, directions_bus, local_gas_station, home, bolt, shopping_bag, medical_services, school, movie, flight, spa, verified_user, receipt_long, redeem, family_restroom, work, payments, laptop, savings, undo, category"`
	Color            *string    `json:"color,omitempty" pattern:"^#[0-9A-Fa-f]{6}$"`
	IncludeInBudgets *bool      `json:"include_in_budgets,omitempty"`
	SortOrder        *int32     `json:"sort_order,omitempty"`
}

// errCategoryInUse refuses deleting a category that records still use;
// params carries the non-zero reference counts.
func errCategoryInUse(params map[string]string) error {
	return apperr.ConflictCode("category_in_use",
		"This category is used by existing records. Merge it into another category or archive it instead.", params)
}

// nameParams names the conflicting name in a name_taken error (none when
// unknown).
func nameParams(name string) map[string]string {
	if name == "" {
		return nil
	}
	return map[string]string{"name": name}
}

// colorChange resolves a color patch: a new color, or removal through an
// empty color or clearColor. A new color together with clearColor is
// refused (partial-PATCH convention).
func colorChange(color *string, clearColor bool) (*string, bool, error) {
	switch {
	case color == nil:
		return nil, clearColor, nil
	case *color == "":
		return nil, true, nil
	case clearColor:
		return nil, false, apperr.FieldError("body.clear_color", "Send a new color or clear it, not both.")
	}
	return color, false, nil
}

// mapCategoryErr maps constraint violations; name is the name a unique
// violation is about ("" when unknown).
func mapCategoryErr(err error, name string) error {
	switch {
	case database.IsUniqueViolation(err, "categories_unique_name"):
		return apperr.ConflictCode("name_taken", "A category with this name already exists at this level.", nameParams(name))
	case database.IsCheckViolation(err, "categories_max_depth"):
		return apperr.Rule("category_depth", "Categories support one level of subcategories.", nil)
	case database.IsCheckViolation(err, "categories_parent_owner"), database.IsForeignKeyViolation(err):
		return apperr.FieldError("body.parent_id", "Parent category not found.")
	}
	return err
}

// CreateCategory creates a category.
func (s *Service) CreateCategory(ctx context.Context, in CategoryInput) (*CategoryDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	name := strings.TrimSpace(in.Name)
	if name == "" {
		return nil, apperr.FieldError("body.name", "Name is required.")
	}
	inc := true
	if in.IncludeInBudgets != nil {
		inc = *in.IncludeInBudgets
	}
	var order int32
	if in.SortOrder != nil {
		order = *in.SortOrder
	}
	var out *CategoryDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if in.ParentID != nil {
			var pkind, pstatus string
			if err := tx.QueryRow(ctx, `select kind, status from categories where id = $1 and user_id = $2`, *in.ParentID, uid).Scan(&pkind, &pstatus); err != nil {
				if database.IsNoRows(err) {
					return apperr.FieldError("body.parent_id", "Parent category not found.")
				}
				return err
			}
			if pstatus != "active" {
				return apperr.Rule("parent_category_archived", "The parent category is archived.", nil)
			}
		}
		var id uuid.UUID
		if err := tx.QueryRow(ctx, `insert into categories (user_id, parent_id, name, kind, icon, color, include_in_budgets, sort_order)
			values ($1,$2,$3,$4,$5,$6,$7,$8) returning id`, uid, in.ParentID, name, in.Kind, trimPtr(in.Icon, 40), in.Color, inc, order).Scan(&id); err != nil {
			return mapCategoryErr(err, name)
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "category", EntityID: &id, Action: "created"}); err != nil {
			return err
		}
		out, err = getCat(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(mapCategoryErr(err, name))
}

// CategoryPatch edits a category.
type CategoryPatch struct {
	Version          int32      `json:"version"`
	Name             *string    `json:"name,omitempty" minLength:"1" maxLength:"60"`
	Kind             *string    `json:"kind,omitempty" enum:"expense,income,both"`
	ParentID         *uuid.UUID `json:"parent_id,omitempty"`
	ClearParent      bool       `json:"clear_parent,omitempty"`
	Icon             *string    `json:"icon,omitempty" maxLength:"40" doc:"Icon name (up to 40 characters; not checked against a list); an empty string clears it. The starter categories use these Material Symbols names: restaurant, shopping_cart, directions_bus, local_gas_station, home, bolt, shopping_bag, medical_services, school, movie, flight, spa, verified_user, receipt_long, redeem, family_restroom, work, payments, laptop, savings, undo, category"`
	Color            *string    `json:"color,omitempty" pattern:"^(#[0-9A-Fa-f]{6})?$" doc:"#RRGGBB; an empty string clears it"`
	ClearColor       bool       `json:"clear_color,omitempty" doc:"Remove the color (same as an empty color); cannot be combined with a new color"`
	IncludeInBudgets *bool      `json:"include_in_budgets,omitempty"`
	SortOrder        *int32     `json:"sort_order,omitempty"`
}

// UpdateCategory edits a category (historical transactions keep the link).
func (s *Service) UpdateCategory(ctx context.Context, id uuid.UUID, p CategoryPatch) (*CategoryDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	color, clearColor, err := colorChange(p.Color, p.ClearColor)
	if err != nil {
		return nil, err
	}
	var icon *string // "" clears the icon
	if p.Icon != nil {
		v := strings.TrimSpace(*p.Icon)
		icon = &v
	}
	name := "" // the name a unique violation is about
	var out *CategoryDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := getCat(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		if c.Version != p.Version {
			return apperr.VersionConflict()
		}
		if c.Status == "merged" {
			return apperr.Rule("category_merged", "This category was merged and can no longer be edited.", nil)
		}
		parent := c.ParentID
		if p.ClearParent {
			parent = nil
		} else if p.ParentID != nil {
			if *p.ParentID == id {
				return apperr.FieldError("body.parent_id", "A category cannot be its own parent.")
			}
			parent = p.ParentID
		}
		name = c.Name
		newName := trimPtr(p.Name, 60)
		if newName != nil {
			name = *newName
		}
		// The version condition closes the race with a concurrent edit
		// between the check above and this update.
		tag, err := tx.Exec(ctx, `update categories set name = coalesce($3, name), kind = coalesce($4, kind), parent_id = $5,
			icon = case when $6::text is null then icon else nullif($6, '') end,
			color = case when $10::boolean then null else coalesce($7, color) end,
			include_in_budgets = coalesce($8, include_in_budgets), sort_order = coalesce($9, sort_order), version = version + 1
			where id = $1 and user_id = $2 and version = $11`,
			id, uid, newName, p.Kind, parent, icon, color, p.IncludeInBudgets, p.SortOrder, clearColor, p.Version)
		if err != nil {
			return mapCategoryErr(err, name)
		}
		if tag.RowsAffected() == 0 {
			return apperr.VersionConflict()
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "category", EntityID: &id, Action: "updated"}); err != nil {
			return err
		}
		out, err = getCat(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(mapCategoryErr(err, name))
}

// SetCategoryArchived archives or restores a category. Archived categories
// stay on historical transactions but cannot be chosen for new ones.
func (s *Service) SetCategoryArchived(ctx context.Context, id uuid.UUID, archived bool) (*CategoryDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	name := "" // restoring can clash with an active category's name
	var out *CategoryDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := getCat(ctx, tx, id, uid)
		if err != nil {
			return err
		}
		if c.Status == "merged" {
			return apperr.Rule("category_merged", "This category was merged.", nil)
		}
		name = c.Name
		status := "active"
		if archived {
			status = "archived"
		}
		if _, err := tx.Exec(ctx, `update categories set status = $3, archived_at = case when $3 = 'archived' then now() else null end,
			version = version + 1 where id = $1 and user_id = $2`, id, uid, status); err != nil {
			return mapCategoryErr(err, name)
		}
		if archived { // archive subcategories with their parent
			if _, err := tx.Exec(ctx, `update categories set status = 'archived', archived_at = now(), version = version + 1
				where parent_id = $1 and status = 'active'`, id); err != nil {
				return err
			}
		}
		action := map[bool]string{true: "archived", false: "restored"}[archived]
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "category", EntityID: &id, Action: action}); err != nil {
			return err
		}
		out, err = getCat(ctx, tx, id, uid)
		return err
	})
	return out, database.MapError(mapCategoryErr(err, name))
}

// MergeAffected counts the records a category merge moves to the target
// (the same counts explain why a category cannot be deleted).
type MergeAffected struct {
	Transactions      int64 `json:"transactions" doc:"Transactions, including deleted (restorable) ones"`
	Subcategories     int64 `json:"subcategories" doc:"Subcategories that move under the target"`
	Rules             int64 `json:"rules" doc:"Categorization rules that set a source category"`
	BudgetAllocations int64 `json:"budget_allocations"`
	RecurringRules    int64 `json:"recurring_rules"`
	Bills             int64 `json:"bills"`
	Subscriptions     int64 `json:"subscriptions"`
	Merchants         int64 `json:"merchants" doc:"Merchants whose default category is a source"`
	BudgetFilters     int64 `json:"budget_filters" doc:"Budgets that exclude a source category; after a merge they exclude the target"`
}

// Total is the number of referencing records.
func (a MergeAffected) Total() int64 {
	return a.Transactions + a.Subcategories + a.Rules + a.BudgetAllocations + a.RecurringRules + a.Bills + a.Subscriptions + a.Merchants +
		a.BudgetFilters
}

// params lists the non-zero counts by JSON name as decimal strings
// (error params).
func (a MergeAffected) params() map[string]string {
	p := map[string]string{}
	for k, n := range map[string]int64{"transactions": a.Transactions, "subcategories": a.Subcategories, "rules": a.Rules,
		"budget_allocations": a.BudgetAllocations, "recurring_rules": a.RecurringRules, "bills": a.Bills,
		"subscriptions": a.Subscriptions, "merchants": a.Merchants, "budget_filters": a.BudgetFilters} {
		if n > 0 {
			p[k] = strconv.FormatInt(n, 10)
		}
	}
	return p
}

// categoryRefs counts records that depend on a set of categories.
func categoryRefs(ctx context.Context, tx pgx.Tx, ids []uuid.UUID) (MergeAffected, error) {
	var a MergeAffected
	err := tx.QueryRow(ctx, `select
		(select count(*) from transactions where category_id = any($1)),
		(select count(*) from categories where parent_id = any($1) and status <> 'merged'),
		(select count(*) from category_rules where set_category_id = any($1)),
		(select count(*) from budget_allocations where category_id = any($1)),
		(select count(*) from recurring_rules where category_id = any($1)),
		(select count(*) from bills where category_id = any($1)),
		(select count(*) from subscriptions where category_id = any($1)),
		(select count(*) from merchants where default_category_id = any($1)),
		(select count(*) from budgets where excluded_category_ids && $1)`, ids).
		Scan(&a.Transactions, &a.Subcategories, &a.Rules, &a.BudgetAllocations, &a.RecurringRules, &a.Bills, &a.Subscriptions, &a.Merchants,
			&a.BudgetFilters)
	return a, err
}

// DeleteCategory removes an unused category; used categories must be merged
// or archived so history is never destroyed (spec §4.5).
func (s *Service) DeleteCategory(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if _, err := getCat(ctx, tx, id, uid); err != nil {
			return err
		}
		refs, err := categoryRefs(ctx, tx, []uuid.UUID{id})
		if err != nil {
			return err
		}
		if refs.Total() > 0 {
			return errCategoryInUse(refs.params())
		}
		if _, err := tx.Exec(ctx, `delete from categories where id = $1 and user_id = $2`, id, uid); err != nil {
			if database.IsForeignKeyViolation(err) { // e.g. a merged subcategory still points at it
				return errCategoryInUse(nil)
			}
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "category", EntityID: &id, Action: "deleted"})
	}))
}

// MergeInput merges categories into a target.
type MergeInput struct {
	SourceIDs []uuid.UUID `json:"source_ids" minItems:"1" maxItems:"20"`
	TargetID  uuid.UUID   `json:"target_id"`
	Preview   bool        `json:"preview,omitempty" doc:"Return affected counts without changing anything"`
}

// MergeResult reports affected records.
type MergeResult struct {
	Preview  bool          `json:"preview"`
	Affected MergeAffected `json:"affected"`
}

// MergeCategories re-points all references from sources to the target
// atomically, with per-transaction audit (spec §4.5 "merge with preview").
func (s *Service) MergeCategories(ctx context.Context, in MergeInput) (*MergeResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	sources := dedupeIDs(in.SourceIDs)
	for _, sid := range sources {
		if sid == in.TargetID {
			return nil, apperr.FieldError("body.source_ids", "The target cannot be one of the sources.")
		}
	}
	out := &MergeResult{Preview: in.Preview}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		target, err := getCat(ctx, tx, in.TargetID, uid)
		if err != nil {
			return err
		}
		if target.Status != "active" {
			return apperr.Rule("merge_target_inactive", "Merge into an active category.", nil)
		}
		for _, sid := range sources {
			c, err := getCat(ctx, tx, sid, uid)
			if err != nil {
				return err
			}
			if c.Status == "merged" {
				return apperr.Rule("category_already_merged", "A source category was already merged.", nil)
			}
			if target.ParentID != nil {
				var kids int
				if err := tx.QueryRow(ctx, `select count(*) from categories where parent_id = $1 and status = 'active'`, sid).Scan(&kids); err != nil {
					return err
				}
				if kids > 0 {
					return apperr.Rule("merge_target_must_be_top_level", "A category with subcategories can only be merged into a top-level category.", nil)
				}
			}
		}
		if out.Affected, err = categoryRefs(ctx, tx, sources); err != nil {
			return err
		}
		if in.Preview {
			return nil
		}
		if _, err := tx.Exec(ctx, `insert into transaction_audit_events (user_id, transaction_id, actor_user_id, actor_kind, action, version, changes)
			select user_id, id, $3, 'user', 'bulk_updated', version, jsonb_build_object('category_id', jsonb_build_object('from', category_id, 'to', $2::uuid), 'reason', 'category_merge')
			from transactions where category_id = any($1)`, sources, in.TargetID, uid); err != nil {
			return err
		}
		for _, q := range []string{
			`update transactions set category_id = $2, version = version + 1 where category_id = any($1)`,
			`update budget_allocations set category_id = $2 where category_id = any($1)`,
			`update category_rules set set_category_id = $2, version = version + 1 where set_category_id = any($1)`,
			`update merchants set default_category_id = $2, version = version + 1 where default_category_id = any($1)`,
			`update recurring_rules set category_id = $2 where category_id = any($1)`,
			`update bills set category_id = $2 where category_id = any($1)`,
			`update subscriptions set category_id = $2 where category_id = any($1)`,
			`update import_rows set category_id = $2 where category_id = any($1)`,
			// Budget filters follow the merged transactions (arrays have no foreign keys).
			`update budgets set excluded_category_ids = array(select distinct case when x = any($1) then $2 else x end
				from unnest(excluded_category_ids) x), version = version + 1 where excluded_category_ids && $1`,
			// Keep merge chains one hop long: categories merged into a source now point at the target.
			`update categories set merged_into_id = $2 where merged_into_id = any($1)`,
			`update categories set parent_id = $2, version = version + 1 where parent_id = any($1) and status <> 'merged'`,
			`update categories set status = 'merged', merged_into_id = $2, archived_at = now(), version = version + 1 where id = any($1)`,
		} {
			if _, err := tx.Exec(ctx, q, sources, in.TargetID); err != nil {
				return mapCategoryErr(err, "")
			}
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "category", EntityID: &in.TargetID, Action: "merged",
			Changes: map[string]any{"source_ids": sources, "affected": out.Affected}})
	})
	return out, database.MapError(mapCategoryErr(err, ""))
}

// RuleDTO is a categorization rule.
type RuleDTO struct {
	ID              uuid.UUID  `json:"id"`
	Name            string     `json:"name"`
	Priority        int32      `json:"priority" doc:"Lower runs first; the first match wins"`
	Enabled         bool       `json:"enabled"`
	MatchField      string     `json:"match_field" enum:"description,merchant,any"`
	MatchType       string     `json:"match_type" enum:"contains,equals,starts_with,regex"`
	Pattern         string     `json:"pattern"`
	AmountMin       *string    `json:"amount_min,omitempty" doc:"Decimal amount in currency"`
	AmountMax       *string    `json:"amount_max,omitempty" doc:"Decimal amount in currency"`
	Currency        *string    `json:"currency" doc:"Currency of amount_min and amount_max; null when the rule has no amount condition"`
	AccountID       *uuid.UUID `json:"account_id,omitempty"`
	TransactionType *string    `json:"transaction_type,omitempty" enum:"expense,income"`
	SetCategoryID   uuid.UUID  `json:"set_category_id"`
	ApplyTo         string     `json:"apply_to" enum:"manual,imports,all"`
	Version         int32      `json:"version" doc:"Send it with PUT to detect concurrent edits"`
	CreatedAt       time.Time  `json:"created_at"`
}

// RuleInput creates or replaces a rule.
type RuleInput struct {
	Name            string     `json:"name" minLength:"1" maxLength:"80"`
	Priority        *int32     `json:"priority,omitempty" minimum:"0" maximum:"10000" doc:"Lower runs first; 100 when omitted"`
	Enabled         *bool      `json:"enabled,omitempty"`
	MatchField      string     `json:"match_field" enum:"description,merchant,any"`
	MatchType       string     `json:"match_type" enum:"contains,equals,starts_with,regex"`
	Pattern         string     `json:"pattern" minLength:"1" maxLength:"200"`
	AmountMin       string     `json:"amount_min,omitempty" doc:"Decimal amount in currency, e.g. 500.00"`
	AmountMax       string     `json:"amount_max,omitempty" doc:"Decimal amount in currency"`
	Currency        string     `json:"currency,omitempty" pattern:"^[A-Z]{3}$" doc:"Currency of amount_min and amount_max; defaults to your base currency"`
	AccountID       *uuid.UUID `json:"account_id,omitempty"`
	TransactionType *string    `json:"transaction_type,omitempty" enum:"expense,income"`
	SetCategoryID   uuid.UUID  `json:"set_category_id"`
	ApplyTo         string     `json:"apply_to,omitempty" enum:"manual,imports,all" doc:"all when omitted"`
}

// RuleUpdate replaces a rule (PUT /category-rules/{id}).
type RuleUpdate struct {
	RuleInput
	Version int32 `json:"version,omitempty" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

// RuleApplyInput applies a saved rule to existing transactions.
type RuleApplyInput struct {
	OnlyUncategorized bool `json:"only_uncategorized" doc:"Only change transactions that have no category"`
}

// ruleBounds are a rule's amount bounds in minor units of currency (set
// when either bound is).
type ruleBounds struct {
	min, max *int64
	currency *string
}

// ruleParams validates a rule and converts its amount bounds; at is where
// the rule sits in the request ("body." or "body.rule."), for field paths.
func (s *Service) ruleParams(ctx context.Context, tx pgx.Tx, uid uuid.UUID, in RuleInput, at string) (ruleBounds, error) {
	var b ruleBounds
	if in.MatchType == "regex" {
		if _, err := regexp.Compile(in.Pattern); err != nil {
			return b, apperr.FieldError(at+"pattern", "Invalid regular expression.")
		}
	}
	if err := validateCategoryAt(ctx, tx, uid, in.SetCategoryID, strOr(in.TransactionType), at+"set_category_id"); err != nil {
		return b, err
	}
	if in.AccountID != nil {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from financial_accounts where id = $1 and user_id = $2)`, *in.AccountID, uid).Scan(&ok); err != nil {
			return b, err
		}
		if !ok {
			return b, apperr.FieldError(at+"account_id", "Account not found.")
		}
	}
	if in.AmountMin == "" && in.AmountMax == "" {
		return b, nil
	}
	cur := in.Currency
	if cur == "" {
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return b, err
		}
		cur = u.BaseCurrency
	}
	if in.AmountMin != "" {
		v, err := ParseSignedAmount(at+"amount_min", in.AmountMin, cur)
		if err != nil {
			return b, err
		}
		b.min = &v
	}
	if in.AmountMax != "" {
		v, err := ParseSignedAmount(at+"amount_max", in.AmountMax, cur)
		if err != nil {
			return b, err
		}
		b.max = &v
	}
	if b.min != nil && b.max != nil && *b.min > *b.max {
		return b, apperr.FieldError(at+"amount_max", "Maximum must be at least the minimum.")
	}
	b.currency = &cur
	return b, nil
}

const ruleCols = `id, name, priority, enabled, match_field, match_type, pattern, amount_min_minor, amount_max_minor, amount_currency, account_id,
	transaction_type, set_category_id, apply_to, version, created_at`

const ruleSelect = `select ` + ruleCols + ` from category_rules`

// scanRule reads a rule; baseCur formats bounds stored before rules
// recorded their currency.
func scanRule(r pgx.Row, baseCur string) (*RuleDTO, error) {
	var d RuleDTO
	var lo, hi *int64
	var cur *string
	if err := r.Scan(&d.ID, &d.Name, &d.Priority, &d.Enabled, &d.MatchField, &d.MatchType, &d.Pattern, &lo, &hi, &cur, &d.AccountID,
		&d.TransactionType, &d.SetCategoryID, &d.ApplyTo, &d.Version, &d.CreatedAt); err != nil {
		return nil, err
	}
	if lo == nil && hi == nil {
		return &d, nil
	}
	c := baseCur
	if cur != nil {
		c = *cur
	}
	d.Currency = &c
	if lo != nil {
		v := m(*lo, c).Amount
		d.AmountMin = &v
	}
	if hi != nil {
		v := m(*hi, c).Amount
		d.AmountMax = &v
	}
	return &d, nil
}

// ListRules returns rules in evaluation order.
// GetRule returns one of the caller's categorization rules.
func (s *Service) GetRule(ctx context.Context, id uuid.UUID) (*RuleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *RuleDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		out, err = scanRule(tx.QueryRow(ctx, ruleSelect+` where user_id = $1 and id = $2`, uid, id), u.BaseCurrency)
		if database.IsNoRows(err) {
			return apperr.NotFound("rule")
		}
		return err
	})
	return out, database.MapError(err)
}

func (s *Service) ListRules(ctx context.Context) ([]RuleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []RuleDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		rows, err := tx.Query(ctx, ruleSelect+` where user_id = $1 order by priority, created_at`, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			r, err := scanRule(rows, u.BaseCurrency)
			if err != nil {
				return err
			}
			out = append(out, *r)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// SaveRule creates (id nil) or replaces a rule. When replacing, a non-zero
// version must match the stored one (409 VERSION_CONFLICT otherwise).
func (s *Service) SaveRule(ctx context.Context, id *uuid.UUID, in RuleInput, version int32) (*RuleDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	enabled := true
	if in.Enabled != nil {
		enabled = *in.Enabled
	}
	priority := int32(100)
	if in.Priority != nil {
		priority = *in.Priority
	}
	if in.ApplyTo == "" {
		in.ApplyTo = "all"
	}
	var out *RuleDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if id != nil {
			var cur int32
			if err := tx.QueryRow(ctx, `select version from category_rules where id = $1 and user_id = $2 for update`, *id, uid).Scan(&cur); err != nil {
				if database.IsNoRows(err) {
					return apperr.NotFound("rule")
				}
				return err
			}
			if version != 0 && version != cur {
				return apperr.VersionConflict()
			}
		}
		b, err := s.ruleParams(ctx, tx, uid, in, "body.")
		if err != nil {
			return err
		}
		u, err := LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		if id == nil {
			out, err = scanRule(tx.QueryRow(ctx, `insert into category_rules (user_id, name, priority, enabled, match_field, match_type, pattern,
				amount_min_minor, amount_max_minor, amount_currency, account_id, transaction_type, set_category_id, apply_to)
				values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) returning `+ruleCols,
				uid, strings.TrimSpace(in.Name), priority, enabled, in.MatchField, in.MatchType, in.Pattern, b.min, b.max, b.currency,
				in.AccountID, in.TransactionType, in.SetCategoryID, in.ApplyTo), u.BaseCurrency)
			return err
		}
		out, err = scanRule(tx.QueryRow(ctx, `update category_rules set name = $3, priority = $4, enabled = $5, match_field = $6, match_type = $7,
			pattern = $8, amount_min_minor = $9, amount_max_minor = $10, amount_currency = $11, account_id = $12, transaction_type = $13,
			set_category_id = $14, apply_to = $15, version = version + 1
			where id = $1 and user_id = $2 returning `+ruleCols,
			*id, uid, strings.TrimSpace(in.Name), priority, enabled, in.MatchField, in.MatchType, in.Pattern, b.min, b.max, b.currency,
			in.AccountID, in.TransactionType, in.SetCategoryID, in.ApplyTo), u.BaseCurrency)
		return err
	})
	return out, database.MapError(err)
}

// DeleteRule removes a rule (past categorizations remain, audited).
func (s *Service) DeleteRule(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from category_rules where id = $1 and user_id = $2`, id, uid)
		if err == nil && tag.RowsAffected() == 0 {
			return apperr.NotFound("rule")
		}
		return err
	}))
}

// RulePreview lists existing transactions a rule would match.
type RulePreview struct {
	MatchCount int64            `json:"match_count"`
	Sample     []TransactionDTO `json:"sample"`
}

// PreviewRule evaluates a rule against the last 365 days without changes.
func (s *Service) PreviewRule(ctx context.Context, in RuleInput, onlyUncategorized bool) (*RulePreview, error) {
	return s.ruleMatches(ctx, in, onlyUncategorized, false)
}

// ApplyRule categorizes matching existing transactions (audited).
func (s *Service) ApplyRule(ctx context.Context, in RuleInput, onlyUncategorized bool) (*RulePreview, error) {
	return s.ruleMatches(ctx, in, onlyUncategorized, true)
}

// ApplySavedRule categorizes existing transactions with a saved rule's
// conditions, exactly like ApplyRule (audited, same result).
func (s *Service) ApplySavedRule(ctx context.Context, id uuid.UUID, onlyUncategorized bool) (*RulePreview, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &RulePreview{Sample: []TransactionDTO{}}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var rule Rule
		var name string
		err := tx.QueryRow(ctx, `select id, name, match_field, match_type, pattern, amount_min_minor, amount_max_minor, amount_currency,
			account_id, transaction_type, set_category_id from category_rules where id = $1 and user_id = $2`, id, uid).
			Scan(&rule.ID, &name, &rule.MatchField, &rule.MatchType, &rule.Pattern, &rule.AmountMin, &rule.AmountMax, &rule.Currency,
				&rule.AccountID, &rule.TransactionType, &rule.SetCategoryID)
		if database.IsNoRows(err) {
			return apperr.NotFound("rule")
		}
		if err != nil {
			return err
		}
		// The category may have been archived (or changed kind) since the
		// rule was saved.
		var ae *apperr.Error
		if err := validateCategoryAt(ctx, tx, uid, rule.SetCategoryID, strOr(rule.TransactionType), "set_category_id"); errors.As(err, &ae) &&
			ae.Code == apperr.CodeValidation {
			return apperr.Rule("rule_category_unavailable",
				"This rule's category is archived or no longer fits the rule. Restore the category or choose another one for the rule.", nil)
		} else if err != nil {
			return err
		}
		return runRule(ctx, tx, uid, rule, map[string]any{"rule": name, "rule_id": id}, onlyUncategorized, true, out)
	})
	return out, database.MapError(err)
}

func (s *Service) ruleMatches(ctx context.Context, in RuleInput, onlyUncategorized, apply bool) (*RulePreview, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &RulePreview{Sample: []TransactionDTO{}}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		b, err := s.ruleParams(ctx, tx, uid, in, "body.rule.")
		if err != nil {
			return err
		}
		rule := Rule{MatchField: in.MatchField, MatchType: in.MatchType, Pattern: in.Pattern, AmountMin: b.min, AmountMax: b.max,
			Currency: b.currency, AccountID: in.AccountID, TransactionType: in.TransactionType, SetCategoryID: in.SetCategoryID}
		return runRule(ctx, tx, uid, rule, map[string]any{"rule": in.Name}, onlyUncategorized, apply, out)
	})
	return out, database.MapError(err)
}

// runRule evaluates rule against the caller's expenses and income of the
// last 365 days. With apply it sets the rule's category on every match and
// audits each change (auditInfo is added to the audit changes). The sample
// holds the first 20 matches.
func runRule(ctx context.Context, tx pgx.Tx, uid uuid.UUID, rule Rule, auditInfo map[string]any, onlyUncategorized, apply bool, out *RulePreview) error {
	rows, err := tx.Query(ctx, `select t.id, coalesce(t.description, ''), coalesce(m.name, ''), t.amount_minor, t.currency, t.account_id, t.type,
		t.version from transactions t left join merchants m on m.id = t.merchant_id
		where t.user_id = $1 and t.deleted_at is null and t.type in ('expense','income') and t.local_date > current_date - 365
		and ($2::boolean = false or t.category_id is null) order by t.local_date desc limit 5000`, uid, onlyUncategorized)
	if err != nil {
		return err
	}
	type hit struct {
		id      uuid.UUID
		version int32
	}
	var hits []hit
	for rows.Next() {
		var id, acct uuid.UUID
		var desc, mer, cur, typ string
		var amt int64
		var ver int32
		if err := rows.Scan(&id, &desc, &mer, &amt, &cur, &acct, &typ, &ver); err != nil {
			rows.Close()
			return err
		}
		if rule.Matches(desc, mer, amt, cur, acct, typ) {
			hits = append(hits, hit{id, ver})
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	out.MatchCount = int64(len(hits))
	for i, h := range hits {
		if apply {
			if _, err := tx.Exec(ctx, `update transactions set category_id = $2, version = version + 1 where id = $1`, h.id, rule.SetCategoryID); err != nil {
				return err
			}
			changes := map[string]any{"category_id": rule.SetCategoryID}
			for k, v := range auditInfo {
				changes[k] = v
			}
			if err := txAudit(ctx, tx, uid, h.id, "user", "rule_categorized", h.version+1, changes); err != nil {
				return err
			}
		}
		if i < 20 {
			t, err := getTx(ctx, tx, h.id, uid)
			if err != nil {
				return err
			}
			out.Sample = append(out.Sample, *t)
		}
	}
	return nil
}
