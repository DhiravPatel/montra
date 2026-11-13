package seed

import "fmt"

// The demo data. Amounts are exact decimal strings in INR; offsets are days
// before today. Descriptions are unique per person: they identify a record
// on later runs, so changing one adds a new record instead of editing it.

var ashaPlan = func() plan {
	p := plan{
		Accounts: []accountSpec{
			{Name: "Demo Bank", Type: "bank", Opening: "120000.00"},
			{Name: "Demo Credit Card", Type: "credit_card", Opening: "-12000.00"},
			{Name: "Demo Cash", Type: "cash", Opening: "3000.00"},
		},
		Methods: []methodSpec{
			{Label: "Demo UPI", Kind: "upi", Network: "upi"},
			{Label: "Demo Rewards Card", Kind: "credit_card", Network: "visa", Hint: "4321", Account: "Demo Credit Card"},
			{Label: "Demo Bank Transfer", Kind: "bank_transfer", Account: "Demo Bank"},
			{Label: "Demo Cash Wallet", Kind: "cash", Account: "Demo Cash"},
		},
	}
	add := func(t txSpec) { p.Txs = append(p.Txs, t) }
	// Monthly salary, rent and electricity (three months).
	for i, off := range []int{84, 54, 24} {
		n := i + 1
		add(txSpec{Desc: fmt.Sprintf("Salary %d", n), Type: "income", Account: "Demo Bank", Amount: "85000.00", Category: "salary",
			Merchant: "Acme Analytics Pvt Ltd", Offset: off})
		add(txSpec{Desc: fmt.Sprintf("Rent %d", n), Type: "expense", Account: "Demo Bank", Amount: "22000.00", Category: "housing_rent",
			Merchant: "Demo Landlord", Method: "Demo Bank Transfer", Offset: off - 1})
		add(txSpec{Desc: fmt.Sprintf("Electricity %d", n), Type: "expense", Account: "Demo Bank", Amount: "1650.00", Category: "utilities",
			Merchant: "Demo Power Co", Method: "Demo UPI", Offset: off - 4})
		add(txSpec{Desc: fmt.Sprintf("Movie night %d", n), Type: "expense", Account: "Demo Cash", Amount: "750.00", Category: "entertainment",
			Merchant: "Demo Cinemas", Method: "Demo Cash Wallet", Offset: off - 12})
		add(txSpec{Desc: fmt.Sprintf("Online order %d", n), Type: "expense", Account: "Demo Credit Card", Amount: "2999.00", Category: "shopping",
			Merchant: "Demo Shop", Offset: off - 7}) // no payment method: the "unspecified" bucket
	}
	// Groceries every 6 days, dining weekly, fuel every 10 days.
	for i, off := 1, 4; off <= 88; i, off = i+1, off+6 {
		add(txSpec{Desc: fmt.Sprintf("Groceries %02d", i), Type: "expense", Account: "Demo Bank", Amount: fmt.Sprintf("%d.%02d", 600+(i*137)%500, (i*29)%100),
			Category: "groceries", Merchant: "FreshMart", Method: "Demo UPI", Offset: off})
	}
	for i, off := 1, 3; off <= 87; i, off = i+1, off+7 {
		add(txSpec{Desc: fmt.Sprintf("Dinner out %02d", i), Type: "expense", Account: "Demo Credit Card", Amount: fmt.Sprintf("%d.00", 450+(i*91)%400),
			Category: "food_dining", Merchant: "Spice Route", Method: "Demo Rewards Card", Offset: off})
	}
	for i, off := 1, 5; off <= 85; i, off = i+1, off+10 {
		add(txSpec{Desc: fmt.Sprintf("Fuel %02d", i), Type: "expense", Account: "Demo Credit Card", Amount: "1800.00", Category: "fuel",
			Merchant: "Demo Fuels", Method: "Demo Rewards Card", Offset: off})
	}
	// Today's big grocery run: on its own above 75 % of the groceries budget.
	add(txSpec{Desc: "Groceries monthly stock-up", Type: "expense", Account: "Demo Bank", Amount: "2400.00", Category: "groceries",
		Merchant: "FreshMart", Method: "Demo UPI", Offset: 0})
	add(txSpec{Desc: "Pharmacy (pending)", Type: "expense", Account: "Demo Credit Card", Amount: "340.00", Category: "healthcare",
		Merchant: "Demo Pharmacy", Method: "Demo Rewards Card", Offset: 0, Pending: true})
	p.Refunds = []refundSpec{{Desc: "Refund: online order 2", Of: "Online order 2", Amount: "999.00", Offset: 40}}
	p.Transfers = []transferSpec{
		{Desc: "Card bill payment 1", From: "Demo Bank", To: "Demo Credit Card", Amount: "15000.00", Offset: 60},
		{Desc: "Card bill payment 2", From: "Demo Bank", To: "Demo Credit Card", Amount: "15000.00", Offset: 30},
		{Desc: "Cash withdrawal", From: "Demo Bank", To: "Demo Cash", Amount: "2000.00", Offset: 45},
	}
	return p
}()

func smallPlan(bank string, salary string, rent string) plan {
	p := plan{
		Accounts: []accountSpec{{Name: bank, Type: "bank", Opening: "40000.00"}},
		Methods:  []methodSpec{{Label: "Demo UPI", Kind: "upi", Network: "upi"}},
	}
	for i, off := range []int{80, 50, 20} {
		p.Txs = append(p.Txs,
			txSpec{Desc: fmt.Sprintf("Salary %d", i+1), Type: "income", Account: bank, Amount: salary, Category: "salary", Offset: off},
			txSpec{Desc: fmt.Sprintf("Rent share %d", i+1), Type: "expense", Account: bank, Amount: rent, Category: "housing_rent",
				Method: "Demo UPI", Offset: off - 2},
			txSpec{Desc: fmt.Sprintf("Commute %d", i+1), Type: "expense", Account: bank, Amount: fmt.Sprintf("%d.00", 900+i*120),
				Category: "transport", Merchant: "Metro Card", Method: "Demo UPI", Offset: off - 9})
	}
	return p
}

var (
	raviPlan  = smallPlan("Ravi Demo Bank", "62000.00", "11000.00")
	meeraPlan = smallPlan("Meera Demo Bank", "71000.00", "11000.00")
)
