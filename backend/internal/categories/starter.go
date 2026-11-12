package categories

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// Starter is a default category copied to every new user (spec §4.5).
type Starter struct {
	Key   string
	Name  string
	Kind  string // expense | income | both
	Icon  string
	Color string
}

// StarterCategories is the default hierarchy (top level; users add
// subcategories). Names are localized by clients via the system key.
var StarterCategories = []Starter{
	{"food_dining", "Food & dining", "expense", "restaurant", "#E07A5F"},
	{"groceries", "Groceries", "expense", "shopping_cart", "#81B29A"},
	{"transport", "Transport", "expense", "directions_bus", "#3D5A80"},
	{"fuel", "Fuel", "expense", "local_gas_station", "#98C1D9"},
	{"housing_rent", "Housing & rent", "expense", "home", "#6D597A"},
	{"utilities", "Utilities", "expense", "bolt", "#F2CC8F"},
	{"shopping", "Shopping", "expense", "shopping_bag", "#B56576"},
	{"healthcare", "Healthcare", "expense", "medical_services", "#2A9D8F"},
	{"education", "Education", "expense", "school", "#264653"},
	{"entertainment", "Entertainment", "expense", "movie", "#E76F51"},
	{"travel", "Travel", "expense", "flight", "#457B9D"},
	{"personal_care", "Personal care", "expense", "spa", "#CDB4DB"},
	{"insurance", "Insurance", "expense", "verified_user", "#577590"},
	{"taxes_fees", "Taxes & fees", "expense", "receipt_long", "#8D99AE"},
	{"gifts_donations", "Gifts & donations", "expense", "redeem", "#F4A261"},
	{"family", "Family", "expense", "family_restroom", "#BC6C25"},
	{"work_expenses", "Work expenses", "expense", "work", "#606C38"},
	{"salary", "Salary", "income", "payments", "#2D6A4F"},
	{"freelance_income", "Freelance income", "income", "laptop", "#40916C"},
	{"interest", "Interest", "income", "savings", "#52B788"},
	{"refunds", "Refunds", "both", "undo", "#74C69D"},
	{"other", "Other", "both", "category", "#ADB5BD"},
}

// SeedStarter inserts the starter categories for a new user. It is
// idempotent (unique system_key per user).
func SeedStarter(ctx context.Context, tx pgx.Tx, userID uuid.UUID, _ string) error {
	b := &pgx.Batch{}
	for i, c := range StarterCategories {
		b.Queue(`insert into categories (user_id, name, kind, icon, color, system_key, sort_order)
			values ($1,$2,$3,$4,$5,$6,$7) on conflict do nothing`, userID, c.Name, c.Kind, c.Icon, c.Color, c.Key, i*10)
	}
	return tx.SendBatch(ctx, b).Close()
}
