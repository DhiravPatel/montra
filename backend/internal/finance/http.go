package finance

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/domain/currency"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// CurrencyDTO is a supported ISO 4217 currency.
type CurrencyDTO struct {
	Code       string  `json:"code" pattern:"^[A-Z]{3}$"`
	Name       string  `json:"name"`
	Exponent   int     `json:"exponent" minimum:"0" maximum:"4" doc:"Minor-unit digits (0, 2 or 3)"`
	Symbol     *string `json:"symbol,omitempty"`
	Selectable bool    `json:"selectable" doc:"false for retired currencies kept only for historical records"`
	ReplacedBy *string `json:"replaced_by,omitempty" pattern:"^[A-Z]{3}$"`
	RetiredOn  *string `json:"retired_on,omitempty" format:"date"`
}

func currencies() []CurrencyDTO {
	all := currency.All()
	out := make([]CurrencyDTO, 0, len(all))
	for _, c := range all {
		d := CurrencyDTO{Code: c.Code, Name: c.Name, Exponent: c.Exponent, Selectable: c.ReplacedBy == ""}
		if c.Symbol != "" {
			sym := c.Symbol
			d.Symbol = &sym
		}
		if c.ReplacedBy != "" {
			r, on := c.ReplacedBy, c.RetiredOn
			d.ReplacedBy, d.RetiredOn = &r, &on
		}
		out = append(out, d)
	}
	return out
}

// IdemHeader is embedded in inputs of financial writes (spec §6).
type IdemHeader = httpx.IdemHeader

type IDPath struct {
	ID uuid.UUID `path:"id"`
}

// Routes mounts the personal-finance endpoints.
func (s *Service) Routes(api huma.API) {
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }

	httpx.Public(api, httpx.Op("currencies-list", http.MethodGet, "/currencies", "Supported currencies (ISO 4217) with minor-unit exponents", "Reference"),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]CurrencyDTO], error) {
			return httpx.OK(ctx, currencies()), nil
		})

	// ------------------------------------------------------------ accounts
	const at = "Accounts"
	httpx.Protected(api, httpx.Op("accounts-list", http.MethodGet, "/accounts", "List accounts with ledger balances", at),
		func(ctx context.Context, in *struct {
			IncludeArchived bool `query:"include_archived"`
		}) (*httpx.Response[[]AccountDTO], error) {
			l, err := s.ListAccounts(ctx, in.IncludeArchived)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("accounts-create", http.MethodPost, "/accounts", "Create an account (opening balance is a ledger event)", at))),
		func(ctx context.Context, in *struct {
			IdemHeader
			Body AccountInput
		}) (*httpx.ReplayOutput[AccountDTO], error) {
			a, rep, err := s.CreateAccount(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *a, rep), nil
		})
	httpx.Protected(api, httpx.Op("accounts-get", http.MethodGet, "/accounts/{id}", "Get an account", at),
		func(ctx context.Context, in *IDPath) (*httpx.Response[AccountDTO], error) {
			a, err := s.GetAccount(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
	httpx.Protected(api, write(httpx.Op("accounts-update", http.MethodPatch, "/accounts/{id}", "Update an account", at)),
		func(ctx context.Context, in *struct {
			IDPath
			Body AccountPatch
		}) (*httpx.Response[AccountDTO], error) {
			a, err := s.UpdateAccount(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
	for _, action := range []string{"archive", "restore", "close"} {
		action := action
		httpx.Protected(api, write(httpx.Op("accounts-"+action, http.MethodPost, "/accounts/{id}/"+action, action+" an account", at)),
			func(ctx context.Context, in *struct {
				IDPath
				Version int32 `query:"version" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
			}) (*httpx.Response[AccountDTO], error) {
				a, err := s.SetAccountStatus(ctx, in.ID, action, in.Version)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *a), nil
			})
	}
	httpx.Protected(api, httpx.Created(write(httpx.Op("accounts-adjust", http.MethodPost, "/accounts/{id}/adjustments",
		"Correct a balance with an auditable adjustment (reason required)", at))),
		func(ctx context.Context, in *struct {
			IDPath
			IdemHeader
			Body AdjustmentInput
		}) (*httpx.ReplayOutput[AccountDTO], error) {
			a, rep, err := s.AdjustBalance(ctx, in.ID, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *a, rep), nil
		})
	httpx.Protected(api, httpx.Op("accounts-balance", http.MethodGet, "/accounts/{id}/balance", "Balance as of a date, with optional daily history", at),
		func(ctx context.Context, in *struct {
			IDPath
			AsOf string `query:"as_of" doc:"YYYY-MM-DD"`
			From string `query:"from" doc:"Start of daily history (YYYY-MM-DD)"`
			To   string `query:"to"`
		}) (*httpx.Response[BalanceReport], error) {
			b, err := s.Balance(ctx, in.ID, in.AsOf, in.From, in.To)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, httpx.Op("accounts-transactions", http.MethodGet, "/accounts/{id}/transactions", "Account transaction history", at),
		func(ctx context.Context, in *struct {
			IDPath
			ListFilter
		}) (*httpx.Response[[]TransactionDTO], error) {
			f := in.ListFilter
			f.AccountIDs = []uuid.UUID{in.ID}
			f.IncludeShared = true
			l, next, err := s.ListTransactions(ctx, f)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})

	// ------------------------------------------------------ payment methods
	const pt = "Payment methods"
	httpx.Protected(api, httpx.Op("payment-methods-list", http.MethodGet, "/payment-methods", "List payment methods", pt),
		func(ctx context.Context, in *struct {
			IncludeArchived bool `query:"include_archived"`
		}) (*httpx.Response[[]PaymentMethodDTO], error) {
			l, err := s.ListPaymentMethods(ctx, in.IncludeArchived)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("payment-methods-create", http.MethodPost, "/payment-methods", "Create a payment method", pt))),
		func(ctx context.Context, in *struct{ Body PaymentMethodInput }) (*httpx.Response[PaymentMethodDTO], error) {
			p, err := s.SavePaymentMethod(ctx, nil, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, httpx.Op("payment-methods-get", http.MethodGet, "/payment-methods/{id}", "Get a payment method", pt),
		func(ctx context.Context, in *IDPath) (*httpx.Response[PaymentMethodDTO], error) {
			p, err := s.GetPaymentMethod(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, write(httpx.Op("payment-methods-update", http.MethodPatch, "/payment-methods/{id}",
		"Update a payment method (only the fields sent change; send version to detect concurrent edits)", pt)),
		func(ctx context.Context, in *struct {
			IDPath
			Body PaymentMethodPatch
		}) (*httpx.Response[PaymentMethodDTO], error) {
			p, err := s.PatchPaymentMethod(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, write(httpx.Op("payment-methods-restore", http.MethodPost, "/payment-methods/{id}/restore", "Restore an archived payment method", pt)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[PaymentMethodDTO], error) {
			p, err := s.RestorePaymentMethod(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, write(httpx.Op("payment-methods-delete", http.MethodDelete, "/payment-methods/{id}",
		"Delete an unused payment method, or archive one that transactions use", pt)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[PaymentMethodDeleteResult], error) {
			r, err := s.DeletePaymentMethod(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})

	// ---------------------------------------------------------- transactions
	const tt = "Transactions"
	httpx.Protected(api, httpx.Op("transactions-list", http.MethodGet, "/transactions", "List and filter transactions", tt),
		func(ctx context.Context, in *ListFilter) (*httpx.Response[[]TransactionDTO], error) {
			l, next, err := s.ListTransactions(ctx, *in)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Op("transactions-search", http.MethodGet, "/transactions/search", "Search transactions (same filters as list)", tt),
		func(ctx context.Context, in *ListFilter) (*httpx.Response[[]TransactionDTO], error) {
			l, next, err := s.ListTransactions(ctx, *in)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("transactions-create", http.MethodPost, "/transactions", "Create an expense, income, refund or reimbursement", tt))),
		func(ctx context.Context, in *struct {
			IdemHeader
			Body TransactionInput
		}) (*httpx.ReplayOutput[CreateResult], error) {
			r, rep, err := s.CreateTransaction(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *r, rep), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("transactions-transfer", http.MethodPost, "/transactions/transfers",
		"Transfer between your accounts (paired legs, optional fee and FX)", tt))),
		func(ctx context.Context, in *struct {
			IdemHeader
			Body TransferInput
		}) (*httpx.ReplayOutput[TransferDTO], error) {
			t, rep, err := s.CreateTransfer(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *t, rep), nil
		})
	httpx.Protected(api, httpx.Op("transfers-get", http.MethodGet, "/transactions/transfers/{id}", "Get a transfer", tt),
		func(ctx context.Context, in *IDPath) (*httpx.Response[TransferDTO], error) {
			t, err := s.GetTransfer(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("transfers-delete", http.MethodDelete, "/transactions/transfers/{id}",
		"Delete (void) a transfer: both legs and the fee together; restorable", tt)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[TransferDTO], error) {
			t, err := s.VoidTransfer(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("transfers-restore", http.MethodPost, "/transactions/transfers/{id}/restore",
		"Restore a deleted transfer (all legs together)", tt)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[TransferDTO], error) {
			t, err := s.RestoreTransfer(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("transactions-bulk-update", http.MethodPost, "/transactions/bulk-update", "Bulk category/tag/account update", tt)),
		func(ctx context.Context, in *struct{ Body BulkUpdateInput }) (*httpx.Response[BulkResult], error) {
			r, err := s.BulkUpdate(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("transactions-bulk-delete", http.MethodPost, "/transactions/bulk-delete", "Bulk delete (restorable) with confirmation", tt)),
		func(ctx context.Context, in *struct {
			Body struct {
				TransactionIDs []uuid.UUID `json:"transaction_ids" minItems:"1" maxItems:"500"`
				Confirm        bool        `json:"confirm"`
			}
		}) (*httpx.Response[BulkResult], error) {
			r, err := s.BulkDelete(ctx, in.Body.TransactionIDs, in.Body.Confirm)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("transactions-get", http.MethodGet, "/transactions/{id}", "Get a transaction", tt),
		func(ctx context.Context, in *IDPath) (*httpx.Response[TransactionDTO], error) {
			t, err := s.GetTransaction(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("transactions-update", http.MethodPatch, "/transactions/{id}", "Edit a transaction (version required)", tt)),
		func(ctx context.Context, in *struct {
			IDPath
			Body TransactionPatch
		}) (*httpx.Response[TransactionDTO], error) {
			t, err := s.UpdateTransaction(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("transactions-delete", http.MethodDelete, "/transactions/{id}", "Delete (void) a transaction; restorable", tt)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[TransactionDTO], error) {
			t, err := s.VoidTransaction(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("transactions-restore", http.MethodPost, "/transactions/{id}/restore", "Restore a deleted transaction", tt)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[TransactionDTO], error) {
			t, err := s.RestoreTransaction(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("transactions-duplicate", http.MethodPost, "/transactions/{id}/duplicate", "Duplicate a transaction", tt))),
		func(ctx context.Context, in *struct {
			IDPath
			IdemHeader
			Body struct {
				LocalDate string `json:"local_date,omitempty" doc:"Defaults to today"`
			}
		}) (*httpx.ReplayOutput[CreateResult], error) {
			r, rep, err := s.DuplicateTransaction(ctx, in.ID, in.Key, in.Body.LocalDate)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *r, rep), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("transactions-refund", http.MethodPost, "/transactions/{id}/refunds",
		"Record a partial or full refund/reimbursement (capped at the original)", tt))),
		func(ctx context.Context, in *struct {
			IDPath
			IdemHeader
			Body RefundInput
		}) (*httpx.ReplayOutput[CreateResult], error) {
			r, rep, err := s.CreateRefund(ctx, in.ID, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *r, rep), nil
		})
	httpx.Protected(api, httpx.Op("transactions-audit", http.MethodGet, "/transactions/{id}/audit", "Transaction audit history", tt),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]AuditEventDTO], error) {
			l, err := s.TransactionAudit(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("transactions-attachments-list", http.MethodGet, "/transactions/{id}/attachments", "List attachments", tt),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]AttachmentDTO], error) {
			l, err := s.ListAttachments(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, write(httpx.Op("transactions-attachments-add", http.MethodPost, "/transactions/{id}/attachments", "Attach an uploaded file", tt)),
		func(ctx context.Context, in *struct {
			IDPath
			Body struct {
				FileID uuid.UUID `json:"file_id"`
			}
		}) (*httpx.Response[TransactionDTO], error) {
			t, err := s.AttachFile(ctx, in.ID, in.Body.FileID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("transactions-attachments-remove", http.MethodDelete, "/transactions/{id}/attachments/{fileId}", "Detach a file", tt)),
		func(ctx context.Context, in *struct {
			IDPath
			FileID uuid.UUID `path:"fileId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.DetachFile(ctx, in.ID, in.FileID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Op("saved-filters-list", http.MethodGet, "/saved-filters", "List saved filters", tt),
		func(ctx context.Context, in *struct {
			Scope string `query:"scope" enum:"transactions,reports,search,"`
		}) (*httpx.Response[[]SavedFilterDTO], error) {
			l, err := s.ListSavedFilters(ctx, in.Scope)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(httpx.Op("saved-filters-create", http.MethodPost, "/saved-filters", "Save a filter", tt)),
		func(ctx context.Context, in *struct {
			Body struct {
				Scope  string          `json:"scope" enum:"transactions,reports,search"`
				Name   string          `json:"name" minLength:"1" maxLength:"80"`
				Filter json.RawMessage `json:"filter"`
			}
		}) (*httpx.Response[SavedFilterDTO], error) {
			f, err := s.SaveFilter(ctx, in.Body.Scope, in.Body.Name, in.Body.Filter)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *f), nil
		})
	httpx.Protected(api, httpx.Op("saved-filters-delete", http.MethodDelete, "/saved-filters/{id}", "Delete a saved filter", tt),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeleteSavedFilter(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	s.labelRoutes(api, write)
}

func (s *Service) labelRoutes(api huma.API, write func(huma.Operation) huma.Operation) {
	const ct = "Categories"
	httpx.Protected(api, httpx.Op("categories-list", http.MethodGet, "/categories", "List categories", ct),
		func(ctx context.Context, in *struct {
			IncludeArchived bool `query:"include_archived"`
		}) (*httpx.Response[[]CategoryDTO], error) {
			l, err := s.ListCategories(ctx, in.IncludeArchived)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("categories-create", http.MethodPost, "/categories", "Create a category or subcategory", ct))),
		func(ctx context.Context, in *struct{ Body CategoryInput }) (*httpx.Response[CategoryDTO], error) {
			c, err := s.CreateCategory(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Op("categories-get", http.MethodGet, "/categories/{id}",
		"Get a category in any status (follow merged_into_id after a merge)", ct),
		func(ctx context.Context, in *IDPath) (*httpx.Response[CategoryDTO], error) {
			c, err := s.GetCategory(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, write(httpx.Op("categories-update", http.MethodPatch, "/categories/{id}", "Update a category", ct)),
		func(ctx context.Context, in *struct {
			IDPath
			Body CategoryPatch
		}) (*httpx.Response[CategoryDTO], error) {
			c, err := s.UpdateCategory(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, write(httpx.Op("categories-archive", http.MethodPost, "/categories/{id}/archive", "Archive a category", ct)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[CategoryDTO], error) {
			c, err := s.SetCategoryArchived(ctx, in.ID, true)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, write(httpx.Op("categories-restore", http.MethodPost, "/categories/{id}/restore", "Restore an archived category", ct)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[CategoryDTO], error) {
			c, err := s.SetCategoryArchived(ctx, in.ID, false)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, write(httpx.Op("categories-delete", http.MethodDelete, "/categories/{id}",
		"Delete an unused category (409 category_in_use with the reference counts otherwise)", ct)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeleteCategory(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, write(httpx.Op("categories-merge", http.MethodPost, "/categories/merge", "Merge categories (preview supported)", ct)),
		func(ctx context.Context, in *struct{ Body MergeInput }) (*httpx.Response[MergeResult], error) {
			r, err := s.MergeCategories(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("category-rules-list", http.MethodGet, "/category-rules", "List categorization rules", ct),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]RuleDTO], error) {
			l, err := s.ListRules(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("category-rules-get", http.MethodGet, "/category-rules/{id}", "Get a categorization rule", ct),
		func(ctx context.Context, in *IDPath) (*httpx.Response[RuleDTO], error) {
			r, err := s.GetRule(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("category-rules-create", http.MethodPost, "/category-rules", "Create a rule", ct))),
		func(ctx context.Context, in *struct{ Body RuleInput }) (*httpx.Response[RuleDTO], error) {
			r, err := s.SaveRule(ctx, nil, in.Body, 0)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("category-rules-update", http.MethodPut, "/category-rules/{id}",
		"Replace a rule (send version to detect concurrent edits)", ct)),
		func(ctx context.Context, in *struct {
			IDPath
			Body RuleUpdate
		}) (*httpx.Response[RuleDTO], error) {
			r, err := s.SaveRule(ctx, &in.ID, in.Body.RuleInput, in.Body.Version)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("category-rules-apply-saved", http.MethodPost, "/category-rules/{id}/apply",
		"Apply a saved rule to existing transactions (audited; same result as /category-rules/apply)", ct)),
		func(ctx context.Context, in *struct {
			IDPath
			Body RuleApplyInput
		}) (*httpx.Response[RulePreview], error) {
			r, err := s.ApplySavedRule(ctx, in.ID, in.Body.OnlyUncategorized)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("category-rules-delete", http.MethodDelete, "/category-rules/{id}", "Delete a rule", ct)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeleteRule(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	for _, mode := range []string{"preview", "apply"} {
		mode := mode
		httpx.Protected(api, write(httpx.Op("category-rules-"+mode, http.MethodPost, "/category-rules/"+mode,
			map[string]string{"preview": "Preview which transactions a rule matches", "apply": "Apply a rule to existing transactions (audited)"}[mode], ct)),
			func(ctx context.Context, in *struct {
				Body struct {
					Rule              RuleInput `json:"rule"`
					OnlyUncategorized bool      `json:"only_uncategorized"`
				}
			}) (*httpx.Response[RulePreview], error) {
				var r *RulePreview
				var err error
				if mode == "apply" {
					r, err = s.ApplyRule(ctx, in.Body.Rule, in.Body.OnlyUncategorized)
				} else {
					r, err = s.PreviewRule(ctx, in.Body.Rule, in.Body.OnlyUncategorized)
				}
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *r), nil
			})
	}

	const tg = "Tags"
	httpx.Protected(api, httpx.Op("tags-list", http.MethodGet, "/tags", "List tags with usage", tg),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]TagDTO], error) {
			l, err := s.ListTags(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("tags-get", http.MethodGet, "/tags/{id}", "Get a tag with usage", tg),
		func(ctx context.Context, in *IDPath) (*httpx.Response[TagDTO], error) {
			t, err := s.GetTag(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	type tagBody struct {
		Name     *string `json:"name,omitempty" minLength:"1" maxLength:"40"`
		Color    *string `json:"color,omitempty" pattern:"^#[0-9A-Fa-f]{6}$"`
		Archived *bool   `json:"archived,omitempty"`
	}
	httpx.Protected(api, httpx.Created(write(httpx.Op("tags-create", http.MethodPost, "/tags", "Create a tag", tg))),
		func(ctx context.Context, in *struct{ Body tagBody }) (*httpx.Response[TagDTO], error) {
			t, err := s.CreateTag(ctx, in.Body.Name, in.Body.Color)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("tags-update", http.MethodPatch, "/tags/{id}",
		"Rename, recolor or archive a tag (only the fields sent change; send version to detect concurrent edits)", tg)),
		func(ctx context.Context, in *struct {
			IDPath
			Body TagPatch
		}) (*httpx.Response[TagDTO], error) {
			t, err := s.PatchTag(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *t), nil
		})
	httpx.Protected(api, write(httpx.Op("tags-delete", http.MethodDelete, "/tags/{id}", "Delete a tag", tg)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeleteTag(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})

	const mt = "Merchants"
	httpx.Protected(api, httpx.Op("merchants-list", http.MethodGet, "/merchants",
		"List and search merchants by status (cursor paginated; meta.next_cursor)", mt),
		func(ctx context.Context, in *MerchantFilter) (*httpx.Response[[]MerchantDTO], error) {
			l, next, err := s.ListMerchants(ctx, *in)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Op("merchants-get", http.MethodGet, "/merchants/{id}", "Merchant with spending history", mt),
		func(ctx context.Context, in *IDPath) (*httpx.Response[MerchantDetail], error) {
			d, err := s.GetMerchant(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, write(httpx.Op("merchants-update", http.MethodPatch, "/merchants/{id}",
		"Correct a merchant (send version to detect concurrent edits)", mt)),
		func(ctx context.Context, in *struct {
			IDPath
			Body MerchantPatch
		}) (*httpx.Response[MerchantDetail], error) {
			d, err := s.UpdateMerchant(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	// Alias bodies stay unnamed types so each operation keeps its generated
	// schema name (Merchants-aliasesRequest is in use by clients).
	type merchantAliasBody = struct {
		MerchantID uuid.UUID `json:"merchant_id"`
		Alias      string    `json:"alias" minLength:"1" maxLength:"200"`
	}
	httpx.Protected(api, write(httpx.Op("merchants-aliases", http.MethodPost, "/merchants/aliases", "Map an alias to a merchant", mt)),
		func(ctx context.Context, in *struct{ Body merchantAliasBody }) (*httpx.Response[MerchantDetail], error) {
			d, err := s.AddAlias(ctx, in.Body.MerchantID, in.Body.Alias)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, write(httpx.Op("merchants-aliases-remove", http.MethodPost, "/merchants/aliases/remove",
		"Remove an alias from a merchant (matched like names: case and spacing are ignored)", mt)),
		func(ctx context.Context, in *struct{ Body merchantAliasBody }) (*httpx.Response[MerchantDetail], error) {
			d, err := s.RemoveAlias(ctx, in.Body.MerchantID, in.Body.Alias)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	// The merge body stays an unnamed type so each operation keeps its
	// generated schema name (Merchants-mergeRequest is in use by clients).
	type merchantMergeBody = struct {
		SourceIDs []uuid.UUID `json:"source_ids" minItems:"1" maxItems:"20"`
		TargetID  uuid.UUID   `json:"target_id"`
	}
	httpx.Protected(api, write(httpx.Op("merchants-merge", http.MethodPost, "/merchants/merge",
		"Merge merchants (preview first with /merchants/merge/preview)", mt)),
		func(ctx context.Context, in *struct{ Body merchantMergeBody }) (*httpx.Response[MerchantDetail], error) {
			d, err := s.MergeMerchants(ctx, in.Body.SourceIDs, in.Body.TargetID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, write(httpx.Op("merchants-merge-preview", http.MethodPost, "/merchants/merge/preview",
		"Preview a merchant merge: counts of what would move to the target; nothing changes", mt)),
		func(ctx context.Context, in *struct{ Body merchantMergeBody }) (*httpx.Response[MerchantMergeResult], error) {
			r, err := s.PreviewMerchantMerge(ctx, in.Body.SourceIDs, in.Body.TargetID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}
