// Package search is global search across the caller's authorized data
// (spec §4.20, §20B.21): transactions, merchants, accounts, groups,
// community posts, people who opted into discovery, goals, categories,
// bills, subscriptions, recurring rules and budgets. Every section is
// scoped by explicit ownership/membership rules inside an RLS-enforced
// transaction, so results, counts and snippets never come from records
// the caller may not see. Recent searches can be listed and cleared.
package search

import (
	"context"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
)

// Service implements search.
type Service struct {
	DB *database.DB
}

// Scopes lists the searchable sections.
var Scopes = []string{"transactions", "merchants", "accounts", "groups", "posts", "users", "goals", "categories", "bills", "subscriptions",
	"recurring_rules", "budgets"}

// historyKeep is how many recent searches are kept per user.
const historyKeep = 20

// TransactionHit is a matching transaction.
type TransactionHit struct {
	ID          uuid.UUID      `json:"id"`
	Description *string        `json:"description,omitempty"`
	Merchant    *string        `json:"merchant,omitempty"`
	Amount      apitypes.Money `json:"amount"`
	Type        string         `json:"type"`
	LocalDate   string         `json:"local_date"`
	AccountID   uuid.UUID      `json:"account_id"`
	Shared      bool           `json:"shared" doc:"In a household account shared with you"`
}

// NamedHit is a merchant, account, group, goal, category, bill,
// subscription, recurring rule or budget.
type NamedHit struct {
	ID   uuid.UUID `json:"id"`
	Name string    `json:"name"`
	Kind string    `json:"kind,omitempty" doc:"Account type, group type, goal status, category kind (expense/income/both), bill or subscription status, recurring rule kind (expense/income/transfer) or budget type"`
}

// PostHit is a community post the caller may read.
type PostHit struct {
	ID            uuid.UUID `json:"id"`
	CommunityID   uuid.UUID `json:"community_id"`
	CommunityName string    `json:"community_name"`
	Title         string    `json:"title"`
	CreatedAt     time.Time `json:"created_at"`
}

// UserHit is a person who opted into discovery (minimal profile).
type UserHit struct {
	UserID       uuid.UUID  `json:"user_id"`
	DisplayName  string     `json:"display_name"`
	Username     *string    `json:"username,omitempty"`
	AvatarFileID *uuid.UUID `json:"avatar_file_id,omitempty"`
}

// Results groups hits by section; sections outside the requested scope
// are empty.
type Results struct {
	Query          string           `json:"query"`
	Scope          string           `json:"scope"`
	Sort           string           `json:"sort" enum:"relevance,name,recent"`
	Transactions   []TransactionHit `json:"transactions"`
	Merchants      []NamedHit       `json:"merchants"`
	Accounts       []NamedHit       `json:"accounts"`
	Groups         []NamedHit       `json:"groups"`
	Posts          []PostHit        `json:"posts"`
	Users          []UserHit        `json:"users"`
	Goals          []NamedHit       `json:"goals"`
	Categories     []NamedHit       `json:"categories" doc:"Your active categories"`
	Bills          []NamedHit       `json:"bills" doc:"Your bills that are not archived (name or provider)"`
	Subscriptions  []NamedHit       `json:"subscriptions" doc:"Your subscriptions that are not cancelled (name or plan)"`
	RecurringRules []NamedHit       `json:"recurring_rules" doc:"Your recurring income, expenses and transfers that have not ended"`
	Budgets        []NamedHit       `json:"budgets" doc:"Your budgets that are not archived"`
}

// Input is a search request.
type Input struct {
	Q     string `query:"q" minLength:"2" maxLength:"100" doc:"At least 2 characters"`
	Scope string `query:"scope" enum:"all,transactions,merchants,accounts,groups,posts,users,goals,categories,bills,subscriptions,recurring_rules,budgets," doc:"Default all"`
	Limit int    `query:"limit" minimum:"1" maximum:"20" default:"5" doc:"Results per section"`
	Save  bool   `query:"save" doc:"Remember in recent searches (default false: send save=true when the person submits the search, not while typing)"`
	Sort  string `query:"sort" enum:"relevance,name,recent," doc:"relevance (default): names starting with the query first, then by name; transactions and posts newest first. name: alphabetical everywhere. recent: newest first everywhere (names by creation)"`
}

// order returns the ORDER BY for a named section: col is the name column,
// created the creation timestamp column and prefixParam the placeholder of
// the prefix pattern, which only relevance uses (see args).
func order(sort, col, created, prefixParam string) string {
	switch sort {
	case "name":
		return col
	case "recent":
		return created + " desc, " + col
	}
	return "(" + col + " ilike " + prefixParam + " escape '\\') desc, " + col
}

// args appends the prefix pattern when the sort references it.
func args(sort, prefix string, base ...any) []any {
	if sort == "relevance" {
		return append(base, prefix)
	}
	return base
}

// likePattern escapes LIKE wildcards so user input matches literally.
func likePattern(q string) string {
	r := strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`)
	return "%" + r.Replace(q) + "%"
}

// Search runs the query across the requested sections.
func (s *Service) Search(ctx context.Context, in Input) (*Results, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	q := strings.Join(strings.Fields(in.Q), " ")
	if utf8.RuneCountInString(q) < 2 {
		return nil, apperr.FieldError("query.q", "Enter at least 2 characters.")
	}
	scope := in.Scope
	if scope == "" {
		scope = "all"
	}
	limit := in.Limit
	if limit <= 0 {
		limit = 5
	}
	sort := in.Sort
	if sort == "" {
		sort = "relevance"
	}
	want := func(sec string) bool { return scope == "all" || scope == sec }
	pat := likePattern(q)
	prefix := strings.TrimPrefix(pat, "%") // names starting with the query rank first
	out := &Results{Query: q, Scope: scope, Sort: sort, Transactions: []TransactionHit{}, Merchants: []NamedHit{}, Accounts: []NamedHit{},
		Groups: []NamedHit{}, Posts: []PostHit{}, Users: []UserHit{}, Goals: []NamedHit{}, Categories: []NamedHit{}, Bills: []NamedHit{},
		Subscriptions: []NamedHit{}, RecurringRules: []NamedHit{}, Budgets: []NamedHit{}}
	txOrder, postOrder := "t.local_date desc, t.created_at desc", "p.created_at desc"
	if sort == "name" {
		txOrder, postOrder = "coalesce(m.name, t.description, ''), t.local_date desc", "p.title, p.created_at desc"
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if want("transactions") {
			rows, err := tx.Query(ctx, `select t.id, t.description, m.name, t.amount_minor, t.currency, t.type, t.local_date, t.account_id, t.user_id <> $1
				from transactions t left join merchants m on m.id = t.merchant_id
				where t.deleted_at is null
				  and (t.user_id = $1 or exists (select 1 from financial_accounts sa where sa.id = t.account_id and sa.shared_with_group
				       and sa.group_id is not null and montra.is_group_member(sa.group_id)))
				  and (t.description ilike $2 escape '\' or t.notes ilike $2 escape '\' or m.name ilike $2 escape '\')
				order by `+txOrder+` limit $3`, uid, pat, limit)
			if err != nil {
				return err
			}
			for rows.Next() {
				var h TransactionHit
				var minor int64
				var cur string
				var d time.Time
				if err := rows.Scan(&h.ID, &h.Description, &h.Merchant, &minor, &cur, &h.Type, &d, &h.AccountID, &h.Shared); err != nil {
					rows.Close()
					return err
				}
				h.Amount, h.LocalDate = apitypes.M(minor, cur), d.Format("2006-01-02")
				out.Transactions = append(out.Transactions, h)
			}
			rows.Close()
			if err := rows.Err(); err != nil {
				return err
			}
		}
		named := func(dst *[]NamedHit, sql string, args ...any) error {
			rows, err := tx.Query(ctx, sql, args...)
			if err != nil {
				return err
			}
			defer rows.Close()
			for rows.Next() {
				var h NamedHit
				if err := rows.Scan(&h.ID, &h.Name, &h.Kind); err != nil {
					return err
				}
				*dst = append(*dst, h)
			}
			return rows.Err()
		}
		// Named sections take ($1 user, $2 pattern, $3 limit, $4 prefix pattern); groups need no user.
		if want("merchants") {
			if err := named(&out.Merchants, `select id, name, '' from merchants where user_id = $1 and status = 'active' and name ilike $2 escape '\'
				order by `+order(sort, "name", "created_at", "$4")+` limit $3`, args(sort, prefix, uid, pat, limit)...); err != nil {
				return err
			}
		}
		if want("accounts") {
			if err := named(&out.Accounts, `select id, name, account_type from financial_accounts
				where (user_id = $1 or (shared_with_group and group_id is not null and montra.is_group_member(group_id)))
				and status <> 'closed' and name ilike $2 escape '\' order by `+order(sort, "name", "created_at", "$4")+` limit $3`,
				args(sort, prefix, uid, pat, limit)...); err != nil {
				return err
			}
		}
		if want("groups") {
			if err := named(&out.Groups, `select g.id, g.name, g.group_type from groups g
				where montra.is_group_member(g.id) and g.status <> 'deleted' and g.name ilike $1 escape '\'
				order by `+order(sort, "g.name", "g.created_at", "$3")+` limit $2`, args(sort, prefix, pat, limit)...); err != nil {
				return err
			}
		}
		if want("goals") {
			if err := named(&out.Goals, `select g.id, g.name, g.status from goals g
				where (g.owner_user_id = $1 or montra.goal_access(g.id) is not null) and g.name ilike $2 escape '\'
				order by `+order(sort, "g.name", "g.created_at", "$4")+` limit $3`, args(sort, prefix, uid, pat, limit)...); err != nil {
				return err
			}
		}
		// The planning sections are the caller's own records (RLS enforces
		// ownership; shared group records have their own pages).
		if want("categories") {
			if err := named(&out.Categories, `select id, name, kind from categories where user_id = $1 and status = 'active' and name ilike $2 escape '\'
				order by `+order(sort, "name", "created_at", "$4")+` limit $3`, args(sort, prefix, uid, pat, limit)...); err != nil {
				return err
			}
		}
		if want("bills") {
			if err := named(&out.Bills, `select id, name, status from bills where user_id = $1 and group_id is null and status <> 'archived'
				and (name ilike $2 escape '\' or provider_name ilike $2 escape '\')
				order by `+order(sort, "name", "created_at", "$4")+` limit $3`, args(sort, prefix, uid, pat, limit)...); err != nil {
				return err
			}
		}
		if want("subscriptions") {
			if err := named(&out.Subscriptions, `select id, name, status from subscriptions where user_id = $1 and group_id is null and status <> 'cancelled'
				and (name ilike $2 escape '\' or plan_name ilike $2 escape '\')
				order by `+order(sort, "name", "created_at", "$4")+` limit $3`, args(sort, prefix, uid, pat, limit)...); err != nil {
				return err
			}
		}
		if want("recurring_rules") {
			if err := named(&out.RecurringRules, `select id, name, kind from recurring_rules where user_id = $1 and group_id is null
				and kind in ('expense','income','transfer') and status <> 'ended' and name ilike $2 escape '\'
				order by `+order(sort, "name", "created_at", "$4")+` limit $3`, args(sort, prefix, uid, pat, limit)...); err != nil {
				return err
			}
		}
		if want("budgets") {
			if err := named(&out.Budgets, `select id, name, budget_type from budgets where owner_user_id = $1 and status <> 'archived' and name ilike $2 escape '\'
				order by `+order(sort, "name", "created_at", "$4")+` limit $3`, args(sort, prefix, uid, pat, limit)...); err != nil {
				return err
			}
		}
		if want("posts") {
			rows, err := tx.Query(ctx, `select p.id, p.community_id, c.name, p.title, p.created_at from community_posts p join communities c on c.id = p.community_id
				where p.status = 'published' and montra.can_view_community_content(p.community_id)
				and (p.author_id is null or not montra.is_blocked_between($1, p.author_id))
				and (p.title ilike $2 escape '\' or p.body ilike $2 escape '\') order by `+postOrder+` limit $3`, uid, pat, limit)
			if err != nil {
				return err
			}
			for rows.Next() {
				var h PostHit
				if err := rows.Scan(&h.ID, &h.CommunityID, &h.CommunityName, &h.Title, &h.CreatedAt); err != nil {
					rows.Close()
					return err
				}
				out.Posts = append(out.Posts, h)
			}
			rows.Close()
			if err := rows.Err(); err != nil {
				return err
			}
		}
		if want("users") {
			rows, err := tx.Query(ctx, `select user_id, display_name, username, avatar_file_id from montra.search_discoverable($1, $2)`, q, limit)
			if err != nil {
				return err
			}
			for rows.Next() {
				var h UserHit
				if err := rows.Scan(&h.UserID, &h.DisplayName, &h.Username, &h.AvatarFileID); err != nil {
					rows.Close()
					return err
				}
				if h.UserID != uid {
					out.Users = append(out.Users, h)
				}
			}
			rows.Close()
			if err := rows.Err(); err != nil {
				return err
			}
		}
		if in.Save {
			if _, err := tx.Exec(ctx, `delete from search_history where user_id = $1 and lower(query) = lower($2) and scope = $3`, uid, q, scope); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `insert into search_history (user_id, query, scope) values ($1,$2,$3)`, uid, q, scope); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `delete from search_history where user_id = $1 and id not in
				(select id from search_history where user_id = $1 order by created_at desc limit $2)`, uid, historyKeep); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return out, nil
}

// RecentDTO is a remembered search.
type RecentDTO struct {
	Query     string    `json:"query"`
	Scope     string    `json:"scope"`
	CreatedAt time.Time `json:"created_at"`
}

// Recent lists the caller's recent searches, newest first.
func (s *Service) Recent(ctx context.Context) ([]RecentDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []RecentDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select query, scope, created_at from search_history where user_id = $1 order by created_at desc limit $2`, uid, historyKeep)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (RecentDTO, error) {
			var d RecentDTO
			err := r.Scan(&d.Query, &d.Scope, &d.CreatedAt)
			return d, err
		})
		return err
	})
	return out, database.MapError(err)
}

// ClearRecent deletes the caller's search history.
func (s *Service) ClearRecent(ctx context.Context) (int64, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return 0, err
	}
	var n int64
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from search_history where user_id = $1`, uid)
		n = tag.RowsAffected()
		return err
	})
	return n, database.MapError(err)
}
