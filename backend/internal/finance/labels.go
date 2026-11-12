package finance

import (
	"context"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
)

// ---------------------------------------------------------------- tags

// TagDTO is a tag with usage.
type TagDTO struct {
	ID         uuid.UUID  `json:"id"`
	Name       string     `json:"name"`
	Color      *string    `json:"color,omitempty"`
	UsageCount int64      `json:"usage_count"`
	ArchivedAt *time.Time `json:"archived_at,omitempty"`
	Version    int32      `json:"version" doc:"Send it with PATCH to detect concurrent edits"`
}

// TagPatch changes only the fields sent.
type TagPatch struct {
	Name       *string `json:"name,omitempty" minLength:"1" maxLength:"40"`
	Color      *string `json:"color,omitempty" pattern:"^(#[0-9A-Fa-f]{6})?$" doc:"#RRGGBB; an empty string clears it"`
	ClearColor bool    `json:"clear_color,omitempty" doc:"Remove the color (same as an empty color); cannot be combined with a new color"`
	Archived   *bool   `json:"archived,omitempty"`
	Version    int32   `json:"version,omitempty" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

const tagSelect = `select t.id, t.name, t.color, (select count(*) from transaction_tags tt join transactions x on x.id = tt.transaction_id
	where tt.tag_id = t.id and x.deleted_at is null), t.archived_at, t.version from tags t`

func scanTag(r pgx.Row) (*TagDTO, error) {
	var t TagDTO
	err := r.Scan(&t.ID, &t.Name, &t.Color, &t.UsageCount, &t.ArchivedAt, &t.Version)
	return &t, err
}

func getTag(ctx context.Context, tx pgx.Tx, id, uid uuid.UUID) (*TagDTO, error) {
	t, err := scanTag(tx.QueryRow(ctx, tagSelect+` where t.id = $1 and t.user_id = $2`, id, uid))
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("tag")
	}
	return t, err
}

// mapTagErr maps a duplicate name (name is the clashing name, "" when
// unknown).
func mapTagErr(err error, name string) error {
	if database.IsUniqueViolation(err, "tags_user_name_key") {
		return apperr.ConflictCode("name_taken", "A tag with this name already exists.", nameParams(name))
	}
	return database.MapError(err)
}

// ListTags returns tags.
// GetTag returns one of the caller's tags.
func (s *Service) GetTag(ctx context.Context, id uuid.UUID) (*TagDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *TagDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		out, err = scanTag(tx.QueryRow(ctx, tagSelect+` where t.user_id = $1 and t.id = $2`, uid, id))
		if database.IsNoRows(err) {
			return apperr.NotFound("tag")
		}
		return err
	})
	return out, database.MapError(err)
}

func (s *Service) ListTags(ctx context.Context) ([]TagDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []TagDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, tagSelect+` where t.user_id = $1 order by t.name`, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			t, err := scanTag(rows)
			if err != nil {
				return err
			}
			out = append(out, *t)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// CreateTag creates a tag.
func (s *Service) CreateTag(ctx context.Context, name, color *string) (*TagDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if name == nil || NormalizeName(*name) == "" {
		return nil, apperr.FieldError("body.name", "Name is required.")
	}
	var out *TagDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var id uuid.UUID
		if err := tx.QueryRow(ctx, `insert into tags (user_id, name, name_normalized, color) values ($1,$2,$3,$4) returning id`,
			uid, strings.TrimSpace(*name), NormalizeName(*name), color).Scan(&id); err != nil {
			return err
		}
		var err error
		out, err = getTag(ctx, tx, id, uid)
		return err
	})
	return out, mapTagErr(err, strings.TrimSpace(*name))
}

// PatchTag renames, recolors, archives or restores a tag (version-checked
// when the client sends its version).
func (s *Service) PatchTag(ctx context.Context, id uuid.UUID, p TagPatch) (*TagDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var norm *string
	name := ""
	if p.Name != nil {
		n := NormalizeName(*p.Name)
		if n == "" {
			return nil, apperr.FieldError("body.name", "Name cannot be blank.")
		}
		norm, name = &n, strings.TrimSpace(*p.Name)
	}
	color, clearColor, err := colorChange(p.Color, p.ClearColor)
	if err != nil {
		return nil, err
	}
	var out *TagDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var version int32
		if err := tx.QueryRow(ctx, `select version from tags where id = $1 and user_id = $2 for update`, id, uid).Scan(&version); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("tag")
			}
			return err
		}
		if p.Version != 0 && p.Version != version {
			return apperr.VersionConflict()
		}
		if _, err := tx.Exec(ctx, `update tags set name = coalesce($3, name), name_normalized = coalesce($4, name_normalized),
			color = case when $6::boolean then null else coalesce($5, color) end,
			archived_at = case when $7::boolean is null then archived_at when $7 then coalesce(archived_at, now()) else null end,
			version = version + 1 where id = $1 and user_id = $2`, id, uid, trimPtr(p.Name, 40), norm, color, clearColor, p.Archived); err != nil {
			return err
		}
		var err error
		out, err = getTag(ctx, tx, id, uid)
		return err
	})
	return out, mapTagErr(err, name)
}

// DeleteTag removes a tag and its associations (transactions remain).
func (s *Service) DeleteTag(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from tags where id = $1 and user_id = $2`, id, uid)
		if err == nil && tag.RowsAffected() == 0 {
			return apperr.NotFound("tag")
		}
		if err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "tag", EntityID: &id, Action: "deleted"})
	}))
}

// ---------------------------------------------------------------- merchants

// MerchantDTO is a merchant (private to its owner).
type MerchantDTO struct {
	ID                uuid.UUID  `json:"id"`
	Name              string     `json:"name"`
	DefaultCategoryID *uuid.UUID `json:"default_category_id,omitempty"`
	Website           *string    `json:"website,omitempty"`
	Notes             *string    `json:"notes,omitempty"`
	Status            string     `json:"status" enum:"active,archived,merged"`
	MergedIntoID      *uuid.UUID `json:"merged_into_id,omitempty" doc:"The merchant this one was merged into (status merged)"`
	Aliases           []string   `json:"aliases"`
	TransactionCount  int64      `json:"transaction_count"`
	LastUsedOn        *string    `json:"last_used_on,omitempty"`
	Version           int32      `json:"version" doc:"Send it with PATCH to detect concurrent edits"`
}

// MerchantSpend summarizes spending at a merchant per currency.
type MerchantSpend struct {
	Month string         `json:"month" doc:"YYYY-MM"`
	Total apitypes.Money `json:"total"`
	Count int64          `json:"count"`
}

// MerchantDetail adds spending history.
type MerchantDetail struct {
	MerchantDTO
	Spending []MerchantSpend `json:"spending" doc:"Last 12 months of expenses (net of refunds), per currency"`
}

const merchantCols = `m.id, m.name, m.default_category_id, m.website, m.notes, m.status, m.merged_into_id,
	coalesce((select array_agg(a.alias order by a.alias) from merchant_aliases a where a.merchant_id = m.id), '{}'),
	(select count(*) from transactions t where t.merchant_id = m.id and t.deleted_at is null),
	(select max(t.local_date)::text from transactions t where t.merchant_id = m.id and t.deleted_at is null), m.version`

const merchantSelect = `select ` + merchantCols + ` from merchants m`

// merchantDest returns the scan destinations for merchantCols.
func merchantDest(d *MerchantDTO) []any {
	return []any{&d.ID, &d.Name, &d.DefaultCategoryID, &d.Website, &d.Notes, &d.Status, &d.MergedIntoID, &d.Aliases, &d.TransactionCount,
		&d.LastUsedOn, &d.Version}
}

func scanMerchant(r pgx.Row) (*MerchantDTO, error) {
	var d MerchantDTO
	err := r.Scan(merchantDest(&d)...)
	return &d, err
}

// MerchantFilter selects merchants for GET /merchants.
type MerchantFilter struct {
	Q      string `query:"q" maxLength:"100" doc:"Matches names and aliases; names starting with it come first"`
	Status string `query:"status" enum:"active,archived,merged,all" default:"active" doc:"active (default), archived, merged or all"`
	Cursor string `query:"cursor" maxLength:"1024" doc:"meta.next_cursor of the previous page"`
	Limit  int    `query:"limit" minimum:"1" maximum:"100" default:"50"`
}

// merchantCursor is the position after the last merchant of a page:
// R ranks names starting with the search first, then name and ID.
type merchantCursor struct {
	R  int       `json:"r"`
	N  string    `json:"n"`
	ID uuid.UUID `json:"i"`
}

// ListMerchants lists merchants by status, optionally searching names and
// aliases (prefix matches first), with cursor pagination.
func (s *Service) ListMerchants(ctx context.Context, f MerchantFilter) ([]MerchantDTO, string, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, "", err
	}
	if f.Limit <= 0 || f.Limit > 100 {
		f.Limit = 50
	}
	if f.Status == "" {
		f.Status = "active"
	}
	var cur merchantCursor
	if err := httpx.DecodeCursor(f.Cursor, &cur); err != nil {
		return nil, "", err
	}
	q := NormalizeName(f.Q)
	contains := likeEscape(q)
	prefix := strings.TrimPrefix(contains, "%")
	var out []MerchantDTO
	var ranks []int
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+merchantCols+`, r.rnk from merchants m
			cross join lateral (select case when $2 <> '' and m.name_normalized like $4 then 0 else 1 end as rnk) r
			where m.user_id = $1 and ($5 = 'all' or m.status = $5)
			and ($2 = '' or m.name_normalized like $3 or exists (select 1 from merchant_aliases a where a.merchant_id = m.id and a.alias_normalized like $3))
			and (not $6::boolean or (r.rnk, m.name, m.id) > ($7::integer, $8::text, $9::uuid))
			order by r.rnk, m.name, m.id limit $10`, uid, q, contains, prefix, f.Status, f.Cursor != "", cur.R, cur.N, cur.ID, f.Limit+1)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var d MerchantDTO
			var rnk int
			if err := rows.Scan(append(merchantDest(&d), &rnk)...); err != nil {
				return err
			}
			out = append(out, d)
			ranks = append(ranks, rnk)
		}
		return rows.Err()
	})
	if err != nil {
		return nil, "", database.MapError(err)
	}
	next := ""
	if len(out) > f.Limit {
		last := out[f.Limit-1]
		if next, err = httpx.EncodeCursor(merchantCursor{R: ranks[f.Limit-1], N: last.Name, ID: last.ID}); err != nil {
			return nil, "", err
		}
		out = out[:f.Limit]
	}
	if out == nil {
		out = []MerchantDTO{}
	}
	return out, next, nil
}

// GetMerchant returns a merchant with 12 months of spending history.
func (s *Service) GetMerchant(ctx context.Context, id uuid.UUID) (*MerchantDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out MerchantDetail
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		d, err := scanMerchant(tx.QueryRow(ctx, merchantSelect+` where m.id = $1 and m.user_id = $2`, id, uid))
		if database.IsNoRows(err) {
			return apperr.NotFound("merchant")
		}
		if err != nil {
			return err
		}
		out.MerchantDTO = *d
		out.Spending = []MerchantSpend{}
		rows, err := tx.Query(ctx, `select to_char(date_trunc('month', local_date), 'YYYY-MM'), currency,
			sum(case when type = 'expense' then amount_minor when type = 'group_expense' then coalesce(personal_share_minor, amount_minor)
			         when type in ('refund','reimbursement') then -amount_minor else 0 end)::bigint, count(*)
			from transactions where merchant_id = $1 and user_id = $2 and deleted_at is null and status = 'posted'
			and local_date >= date_trunc('month', current_date) - interval '11 months'
			group by 1, 2 order by 1, 2`, id, uid)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var month, cur string
			var total, n int64
			if err := rows.Scan(&month, &cur, &total, &n); err != nil {
				return err
			}
			out.Spending = append(out.Spending, MerchantSpend{Month: month, Total: m(total, cur), Count: n})
		}
		return rows.Err()
	})
	return &out, database.MapError(err)
}

// MerchantPatch edits a merchant (user corrections).
type MerchantPatch struct {
	Name              *string    `json:"name,omitempty" minLength:"1" maxLength:"120"`
	DefaultCategoryID *uuid.UUID `json:"default_category_id,omitempty"`
	ClearCategory     bool       `json:"clear_default_category,omitempty"`
	Website           *string    `json:"website,omitempty" maxLength:"200"`
	Notes             *string    `json:"notes,omitempty" maxLength:"1000"`
	Archived          *bool      `json:"archived,omitempty"`
	Version           int32      `json:"version,omitempty" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

// errMerchantNameTaken refuses a rename to another merchant's name; params
// carry the name and, when known, that merchant's ID so clients can offer
// to merge.
func errMerchantNameTaken(name string, other *uuid.UUID) error {
	params := nameParams(name)
	if other != nil {
		if params == nil {
			params = map[string]string{}
		}
		params["merchant_id"] = other.String()
	}
	return apperr.ConflictCode("name_taken", "Another merchant already has this name; merge them instead.", params)
}

// UpdateMerchant applies a correction. Renaming keeps the old name as an
// alias so future imports still match.
func (s *Service) UpdateMerchant(ctx context.Context, id uuid.UUID, p MerchantPatch) (*MerchantDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var oldName, oldNorm string
		var version int32
		if err := tx.QueryRow(ctx, `select name, name_normalized, version from merchants where id = $1 and user_id = $2 and status <> 'merged' for update`, id, uid).
			Scan(&oldName, &oldNorm, &version); err != nil {
			if database.IsNoRows(err) {
				return apperr.NotFound("merchant")
			}
			return err
		}
		if p.Version != 0 && p.Version != version {
			return apperr.VersionConflict()
		}
		if p.DefaultCategoryID != nil {
			if err := validateCategoryAt(ctx, tx, uid, *p.DefaultCategoryID, "", "body.default_category_id"); err != nil {
				return err
			}
		}
		var newNorm *string
		newName := trimPtr(p.Name, 120)
		if p.Name != nil {
			n := NormalizeName(*p.Name)
			if n == "" {
				return apperr.FieldError("body.name", "Name cannot be blank.")
			}
			newNorm = &n
			if n != oldNorm {
				var other uuid.UUID
				err := tx.QueryRow(ctx, `select id from merchants where user_id = $1 and name_normalized = $2 and status <> 'merged' and id <> $3`,
					uid, n, id).Scan(&other)
				if err == nil {
					return errMerchantNameTaken(strOr(newName), &other)
				}
				if !database.IsNoRows(err) {
					return err
				}
				if _, err := tx.Exec(ctx, `insert into merchant_aliases (user_id, merchant_id, alias, alias_normalized, source)
					values ($1,$2,$3,$4,'user') on conflict (user_id, alias_normalized) do nothing`, uid, id, oldName, oldNorm); err != nil {
					return err
				}
			}
		}
		website := p.Website
		if website != nil && *website != "" && !strings.HasPrefix(*website, "https://") && !strings.HasPrefix(*website, "http://") {
			return apperr.FieldError("body.website", "Use a full http(s) URL.")
		}
		status := (*string)(nil)
		if p.Archived != nil {
			st := map[bool]string{true: "archived", false: "active"}[*p.Archived]
			status = &st
		}
		_, err := tx.Exec(ctx, `update merchants set name = coalesce($3, name), name_normalized = coalesce($4, name_normalized),
			default_category_id = case when $5 then null when $6::uuid is not null then $6 else default_category_id end,
			website = case when $7::text is null then website else nullif($7, '') end,
			notes = case when $8::text is null then notes else nullif($8, '') end, status = coalesce($9, status), version = version + 1
			where id = $1 and user_id = $2`, id, uid, newName, newNorm, p.ClearCategory, p.DefaultCategoryID, website, p.Notes, status)
		if database.IsUniqueViolation(err, "merchants_user_name_key") {
			return errMerchantNameTaken(strOr(newName), nil)
		}
		if err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "merchant", EntityID: &id, Action: "updated"})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.GetMerchant(ctx, id)
}

// AddAlias maps an alias (e.g. a statement descriptor) to a merchant.
func (s *Service) AddAlias(ctx context.Context, merchantID uuid.UUID, alias string) (*MerchantDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	norm := NormalizeName(alias)
	if norm == "" || len([]rune(norm)) > 200 {
		return nil, apperr.FieldError("body.alias", "Alias must be 1-200 characters.")
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from merchants where id = $1 and user_id = $2 and status <> 'merged')`, merchantID, uid).Scan(&ok); err != nil {
			return err
		}
		if !ok {
			return apperr.NotFound("merchant")
		}
		// An alias that belonged to another merchant moves here: both change.
		var previous *uuid.UUID
		if err := tx.QueryRow(ctx, `select merchant_id from merchant_aliases where user_id = $1 and alias_normalized = $2`, uid, norm).
			Scan(&previous); err != nil && !database.IsNoRows(err) {
			return err
		}
		if _, err := tx.Exec(ctx, `insert into merchant_aliases (user_id, merchant_id, alias, alias_normalized, source) values ($1,$2,$3,$4,'user')
			on conflict (user_id, alias_normalized) do update set merchant_id = excluded.merchant_id`, uid, merchantID, strings.TrimSpace(alias), norm); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `update merchants set version = version + 1 where id = $1 or id = $2`, merchantID, previous)
		return err
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.GetMerchant(ctx, merchantID)
}

// RemoveAlias unmaps an alias from a merchant, so imports with that
// descriptor no longer resolve to it.
func (s *Service) RemoveAlias(ctx context.Context, merchantID uuid.UUID, alias string) (*MerchantDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	norm := NormalizeName(alias)
	if norm == "" {
		return nil, apperr.FieldError("body.alias", "Alias must be 1-200 characters.")
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var ok bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from merchants where id = $1 and user_id = $2 and status <> 'merged')`, merchantID, uid).Scan(&ok); err != nil {
			return err
		}
		if !ok {
			return apperr.NotFound("merchant")
		}
		tag, err := tx.Exec(ctx, `delete from merchant_aliases where user_id = $1 and merchant_id = $2 and alias_normalized = $3`, uid, merchantID, norm)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("alias")
		}
		if _, err := tx.Exec(ctx, `update merchants set version = version + 1 where id = $1`, merchantID); err != nil {
			return err
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "merchant", EntityID: &merchantID, Action: "alias_removed"})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.GetMerchant(ctx, merchantID)
}

// MerchantMergeAffected counts what a merchant merge moves to the target.
type MerchantMergeAffected struct {
	Transactions      int64 `json:"transactions" doc:"Transactions, including deleted (restorable) ones"`
	Aliases           int64 `json:"aliases" doc:"Aliases the target gains: the sources' aliases and names"`
	Rules             int64 `json:"rules" doc:"Categorization rules that set a source merchant"`
	RecurringRules    int64 `json:"recurring_rules"`
	Subscriptions     int64 `json:"subscriptions"`
	BudgetAllocations int64 `json:"budget_allocations"`
	BudgetFilters     int64 `json:"budget_filters" doc:"Merchant budgets that track a source merchant; after a merge they track the target"`
}

// MerchantMergeResult reports what a merchant merge moves.
type MerchantMergeResult struct {
	Preview  bool                  `json:"preview"`
	Affected MerchantMergeAffected `json:"affected"`
}

// checkMerchantMerge validates a merge of sources (deduplicated) into
// target and counts what it moves.
func checkMerchantMerge(ctx context.Context, tx pgx.Tx, uid uuid.UUID, sources []uuid.UUID, target uuid.UUID) (MerchantMergeAffected, error) {
	var a MerchantMergeAffected
	for _, sid := range sources {
		if sid == target {
			return a, apperr.FieldError("body.source_ids", "The target cannot be one of the sources.")
		}
	}
	var n int
	if err := tx.QueryRow(ctx, `select count(*) from merchants where user_id = $1 and status <> 'merged' and id = any($2)`, uid,
		append(append([]uuid.UUID{}, sources...), target)).Scan(&n); err != nil {
		return a, err
	}
	if n != len(sources)+1 {
		return a, apperr.NotFound("merchant")
	}
	err := tx.QueryRow(ctx, `select
		(select count(*) from transactions where merchant_id = any($1)),
		(select count(distinct k) from (select alias_normalized k from merchant_aliases where merchant_id = any($1)
			union all select name_normalized from merchants where id = any($1)) x
			where k not in (select alias_normalized from merchant_aliases where merchant_id = $2)),
		(select count(*) from category_rules where set_merchant_id = any($1)),
		(select count(*) from recurring_rules where merchant_id = any($1)),
		(select count(*) from subscriptions where merchant_id = any($1)),
		(select count(*) from budget_allocations where merchant_id = any($1)),
		(select count(*) from budgets where merchant_ids && $1)`, sources, target).
		Scan(&a.Transactions, &a.Aliases, &a.Rules, &a.RecurringRules, &a.Subscriptions, &a.BudgetAllocations, &a.BudgetFilters)
	return a, err
}

// PreviewMerchantMerge reports what merging sources into target would move,
// without changing anything.
func (s *Service) PreviewMerchantMerge(ctx context.Context, sources []uuid.UUID, target uuid.UUID) (*MerchantMergeResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	sources = dedupeIDs(sources)
	out := &MerchantMergeResult{Preview: true}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out.Affected, err = checkMerchantMerge(ctx, tx, uid, sources, target)
		return err
	})
	return out, database.MapError(err)
}

// MergeMerchants folds source merchants into a target (transactions,
// aliases and names are preserved as aliases). Sources keep merged_into_id.
func (s *Service) MergeMerchants(ctx context.Context, sources []uuid.UUID, target uuid.UUID) (*MerchantDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	sources = dedupeIDs(sources)
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		affected, err := checkMerchantMerge(ctx, tx, uid, sources, target)
		if err != nil {
			return err
		}
		for _, q := range []string{
			`insert into merchant_aliases (user_id, merchant_id, alias, alias_normalized, source)
			 select user_id, $2, name, name_normalized, 'user' from merchants where id = any($1) on conflict (user_id, alias_normalized) do update set merchant_id = $2`,
			`update merchant_aliases set merchant_id = $2 where merchant_id = any($1)`,
			`update transactions set merchant_id = $2, version = version + 1 where merchant_id = any($1)`,
			`update category_rules set set_merchant_id = $2, version = version + 1 where set_merchant_id = any($1)`,
			`update recurring_rules set merchant_id = $2 where merchant_id = any($1)`,
			`update subscriptions set merchant_id = $2 where merchant_id = any($1)`,
			`update budget_allocations set merchant_id = $2 where merchant_id = any($1)`,
			// Budget filters and pending detections follow the merged transactions.
			`update budgets set merchant_ids = array(select distinct case when x = any($1) then $2 else x end
				from unnest(merchant_ids) x), version = version + 1 where merchant_ids && $1`,
			`update subscription_detection_candidates set merchant_id = $2 where merchant_id = any($1)`,
			// Keep merge chains one hop long.
			`update merchants set merged_into_id = $2 where merged_into_id = any($1)`,
			`update merchants set status = 'merged', merged_into_id = $2, version = version + 1 where id = any($1)`,
			`update merchants set version = version + 1 where id = $2 and $1::uuid[] is not null`, // the target gained aliases and records
		} {
			if _, err := tx.Exec(ctx, q, sources, target); err != nil {
				return err
			}
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "merchant", EntityID: &target, Action: "merged",
			Changes: map[string]any{"source_ids": sources, "affected": affected}})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.GetMerchant(ctx, target)
}

// ---------------------------------------------------------------- payment methods

// PaymentMethodDTO is a payment method with masked metadata only.
type PaymentMethodDTO struct {
	ID         uuid.UUID  `json:"id"`
	Kind       string     `json:"kind" enum:"cash,upi,debit_card,credit_card,bank_transfer,wallet,cheque,other"`
	Label      string     `json:"label"`
	AccountID  *uuid.UUID `json:"account_id,omitempty"`
	MaskedHint *string    `json:"masked_hint,omitempty" doc:"e.g. •••• 4821 — never a full number"`
	Network    *string    `json:"network,omitempty" enum:"visa,mastercard,rupay,amex,discover,diners,jcb,upi,other"`
	IsDefault  bool       `json:"is_default"`
	ArchivedAt *time.Time `json:"archived_at,omitempty"`
	Version    int32      `json:"version"`
}

// PaymentMethodPatch changes only the fields sent.
type PaymentMethodPatch struct {
	Kind         *string    `json:"kind,omitempty" enum:"cash,upi,debit_card,credit_card,bank_transfer,wallet,cheque,other"`
	Label        *string    `json:"label,omitempty" minLength:"1" maxLength:"60"`
	AccountID    *uuid.UUID `json:"account_id,omitempty"`
	ClearAccount bool       `json:"clear_account,omitempty" doc:"Unlink the account"`
	MaskedHint   *string    `json:"masked_hint,omitempty" maxLength:"24" doc:"Empty string clears it"`
	Network      *string    `json:"network,omitempty" enum:"visa,mastercard,rupay,amex,discover,diners,jcb,upi,other," doc:"Empty string clears it"`
	IsDefault    *bool      `json:"is_default,omitempty"`
	Version      int32      `json:"version,omitempty" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

// PaymentMethodDeleteResult says whether the method was deleted or kept
// archived because transactions use it.
type PaymentMethodDeleteResult struct {
	Deleted  bool `json:"deleted"`
	Archived bool `json:"archived" doc:"Kept (archived) because transactions reference it; restorable"`
}

// PaymentMethodInput creates or updates a payment method.
type PaymentMethodInput struct {
	Kind       string     `json:"kind" enum:"cash,upi,debit_card,credit_card,bank_transfer,wallet,cheque,other"`
	Label      string     `json:"label" minLength:"1" maxLength:"60"`
	AccountID  *uuid.UUID `json:"account_id,omitempty"`
	MaskedHint *string    `json:"masked_hint,omitempty" maxLength:"24" doc:"Last digits or a masked UPI handle only"`
	Network    *string    `json:"network,omitempty" enum:"visa,mastercard,rupay,amex,discover,diners,jcb,upi,other"`
	IsDefault  bool       `json:"is_default,omitempty"`
}

var digits = regexp.MustCompile(`\d`)

func validateMaskedHint(h *string) error {
	if h == nil || *h == "" {
		return nil
	}
	if len(digits.FindAllString(*h, -1)) > 4 {
		return apperr.FieldError("body.masked_hint", "Store at most the last 4 digits. Never enter full card or account numbers, CVVs or PINs.")
	}
	return nil
}

const pmCols = `id, kind, label, account_id, masked_hint, network, is_default, archived_at, version`

const pmSelect = `select ` + pmCols + ` from payment_methods`

func scanPM(r pgx.Row) (*PaymentMethodDTO, error) {
	var p PaymentMethodDTO
	err := r.Scan(&p.ID, &p.Kind, &p.Label, &p.AccountID, &p.MaskedHint, &p.Network, &p.IsDefault, &p.ArchivedAt, &p.Version)
	return &p, err
}

// ListPaymentMethods returns payment methods.
func (s *Service) ListPaymentMethods(ctx context.Context, includeArchived bool) ([]PaymentMethodDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []PaymentMethodDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, pmSelect+` where user_id = $1 and ($2 or archived_at is null) order by is_default desc, label`, uid, includeArchived)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			p, err := scanPM(rows)
			if err != nil {
				return err
			}
			out = append(out, *p)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// SavePaymentMethod creates (id nil) or updates a payment method.
func (s *Service) SavePaymentMethod(ctx context.Context, id *uuid.UUID, in PaymentMethodInput) (*PaymentMethodDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if err := validateMaskedHint(in.MaskedHint); err != nil {
		return nil, err
	}
	var out *PaymentMethodDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if in.AccountID != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from financial_accounts where id = $1 and user_id = $2)`, *in.AccountID, uid).Scan(&ok); err != nil {
				return err
			}
			if !ok {
				return apperr.FieldError("body.account_id", "Account not found.")
			}
		}
		if in.IsDefault {
			if _, err := tx.Exec(ctx, `update payment_methods set is_default = false where user_id = $1`, uid); err != nil {
				return err
			}
		}
		var err error
		if id == nil {
			out, err = scanPM(tx.QueryRow(ctx, `insert into payment_methods (user_id, kind, label, account_id, masked_hint, network, is_default)
				values ($1,$2,$3,$4,$5,$6,$7) returning `+pmCols,
				uid, in.Kind, strings.TrimSpace(in.Label), in.AccountID, trimPtr(in.MaskedHint, 24), in.Network, in.IsDefault))
		} else {
			out, err = scanPM(tx.QueryRow(ctx, `update payment_methods set kind = $3, label = $4, account_id = $5, masked_hint = $6, network = $7,
				is_default = $8, version = version + 1 where id = $1 and user_id = $2 returning `+pmCols,
				*id, uid, in.Kind, strings.TrimSpace(in.Label), in.AccountID, trimPtr(in.MaskedHint, 24), in.Network, in.IsDefault))
			if database.IsNoRows(err) {
				return apperr.NotFound("payment method")
			}
		}
		return err
	})
	return out, database.MapError(err)
}

// GetPaymentMethod returns one payment method.
func (s *Service) GetPaymentMethod(ctx context.Context, id uuid.UUID) (*PaymentMethodDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *PaymentMethodDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out, err = scanPM(tx.QueryRow(ctx, pmSelect+` where id = $1 and user_id = $2`, id, uid))
		return err
	})
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("payment method")
	}
	return out, database.MapError(err)
}

// PatchPaymentMethod changes only the fields sent (version-checked when
// the client sends its version).
func (s *Service) PatchPaymentMethod(ctx context.Context, id uuid.UUID, p PaymentMethodPatch) (*PaymentMethodDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *PaymentMethodDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		cur, err := scanPM(tx.QueryRow(ctx, pmSelect+` where id = $1 and user_id = $2 for update`, id, uid))
		if database.IsNoRows(err) {
			return apperr.NotFound("payment method")
		}
		if err != nil {
			return err
		}
		if p.Version != 0 && p.Version != cur.Version {
			return apperr.VersionConflict()
		}
		in := PaymentMethodInput{Kind: cur.Kind, Label: cur.Label, AccountID: cur.AccountID, MaskedHint: cur.MaskedHint, Network: cur.Network,
			IsDefault: cur.IsDefault}
		if p.Kind != nil {
			in.Kind = *p.Kind
		}
		if p.Label != nil {
			in.Label = *p.Label
		}
		if p.ClearAccount {
			in.AccountID = nil
		} else if p.AccountID != nil {
			in.AccountID = p.AccountID
		}
		if p.MaskedHint != nil {
			in.MaskedHint = nil
			if *p.MaskedHint != "" {
				in.MaskedHint = p.MaskedHint
			}
		}
		if p.Network != nil {
			in.Network = nil
			if *p.Network != "" {
				in.Network = p.Network
			}
		}
		if p.IsDefault != nil {
			in.IsDefault = *p.IsDefault
		}
		if err := validateMaskedHint(in.MaskedHint); err != nil {
			return err
		}
		if in.AccountID != nil {
			var ok bool
			if err := tx.QueryRow(ctx, `select exists (select 1 from financial_accounts where id = $1 and user_id = $2)`, *in.AccountID, uid).Scan(&ok); err != nil {
				return err
			}
			if !ok {
				return apperr.FieldError("body.account_id", "Account not found.")
			}
		}
		if in.IsDefault && !cur.IsDefault {
			if _, err := tx.Exec(ctx, `update payment_methods set is_default = false where user_id = $1`, uid); err != nil {
				return err
			}
		}
		out, err = scanPM(tx.QueryRow(ctx, `update payment_methods set kind = $3, label = $4, account_id = $5, masked_hint = $6, network = $7,
			is_default = $8, version = version + 1 where id = $1 and user_id = $2 returning `+pmCols,
			id, uid, in.Kind, strings.TrimSpace(in.Label), in.AccountID, trimPtr(in.MaskedHint, 24), in.Network, in.IsDefault))
		return err
	})
	return out, database.MapError(err)
}

// RestorePaymentMethod un-archives a payment method.
func (s *Service) RestorePaymentMethod(ctx context.Context, id uuid.UUID) (*PaymentMethodDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *PaymentMethodDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out, err = scanPM(tx.QueryRow(ctx, `update payment_methods set archived_at = null, version = version + 1 where id = $1 and user_id = $2
			returning `+pmCols, id, uid))
		return err
	})
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("payment method")
	}
	return out, database.MapError(err)
}

// DeletePaymentMethod archives a used payment method or deletes an unused one.
func (s *Service) DeletePaymentMethod(ctx context.Context, id uuid.UUID) (*PaymentMethodDeleteResult, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &PaymentMethodDeleteResult{}
	return out, database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var used bool
		if err := tx.QueryRow(ctx, `select exists (select 1 from transactions where payment_method_id = $1)`, id).Scan(&used); err != nil {
			return err
		}
		var tag interface{ RowsAffected() int64 }
		var err error
		if used {
			tag, err = tx.Exec(ctx, `update payment_methods set archived_at = coalesce(archived_at, now()), is_default = false, version = version + 1
				where id = $1 and user_id = $2`, id, uid)
		} else {
			tag, err = tx.Exec(ctx, `delete from payment_methods where id = $1 and user_id = $2`, id, uid)
		}
		out.Archived, out.Deleted = used, !used
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("payment method")
		}
		return nil
	}))
}
