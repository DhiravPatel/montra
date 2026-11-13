// Package seed loads deterministic demo data into a development or test
// database (ARCH-010, ARCH-014) through the real services, so every record
// passes the same validation, ledger, audit, idempotency and RLS rules as
// one made in the app.
//
// The data is fixed: the same users, accounts, amounts and descriptions on
// every run, with dates relative to today in the demo users' time zone
// (Asia/Kolkata). Running it again adds nothing: every record is looked up
// by its fixed name or description before it is created, and creates use
// fixed idempotency keys. It only ever touches the demo accounts
// (demo.*@example.com), which it signs in to with the demo password; an
// existing account with another password is left alone and the run stops.
package seed

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/app"
	"montra/backend/internal/auth"
	"montra/backend/internal/budgets"
	"montra/backend/internal/communities"
	"montra/backend/internal/finance"
	"montra/backend/internal/goals"
	"montra/backend/internal/groups"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/recurring"
	"montra/backend/internal/subscriptions"
)

// DemoPassword signs in every demo account (development and test only).
const DemoPassword = "Montra-Demo-Seed-2026!" //nolint:gosec // documented demo password for development/test seed accounts only (CheckEnv refuses other environments)

// Timezone and Currency of the demo accounts.
const (
	Timezone = "Asia/Kolkata"
	Currency = "INR"
)

// Demo people. Emails use the reserved example.com domain.
var (
	Asha  = Person{Key: "asha", Email: "demo.asha@example.com", Name: "Asha (demo)"}
	Ravi  = Person{Key: "ravi", Email: "demo.ravi@example.com", Name: "Ravi (demo)"}
	Meera = Person{Key: "meera", Email: "demo.meera@example.com", Name: "Meera (demo)"}
)

// Person is a demo account.
type Person struct {
	Key, Email, Name string
}

// CheckEnv refuses every environment except development and test.
func CheckEnv(env string) error {
	if env != config.EnvDevelopment && env != config.EnvTest {
		return fmt.Errorf("refusing to seed: APP_ENV is %q; demo data is only for development or test", env)
	}
	return nil
}

// Seeder loads the demo data.
type Seeder struct {
	// App are the API-process services (RLS-enforcing app role).
	App *app.Services
	// Worker are worker-process services, used to evaluate the demo
	// budgets so their alert exists right away. Optional: without it the
	// running worker raises the alert after the outbox relays the events.
	Worker *app.Services
	// Env is APP_ENV; Run refuses anything but development and test.
	Env string
	// Now is the clock (tests); time.Now by default.
	Now func() time.Time
	// Log receives one line per record ("created" or "exists").
	Log io.Writer
}

// Summary counts what a run created and what already existed.
type Summary struct {
	Created  map[string]int
	Existing map[string]int
}

func (s *Summary) add(kind string, created bool) {
	if created {
		s.Created[kind]++
	} else {
		s.Existing[kind]++
	}
}

// CreatedTotal is the number of records a run created.
func (s *Summary) CreatedTotal() int {
	n := 0
	for _, v := range s.Created {
		n += v
	}
	return n
}

type run struct {
	sd    *Seeder
	ctx   context.Context
	today time.Time // midnight in Timezone
	sum   *Summary
}

type actor struct {
	Person
	id  uuid.UUID
	ctx context.Context
}

// Run loads (or completes) the demo data and reports what it did.
func (sd *Seeder) Run(ctx context.Context) (*Summary, error) {
	if err := CheckEnv(sd.Env); err != nil {
		return nil, err
	}
	if sd.App == nil {
		return nil, errors.New("seed: services are required")
	}
	if sd.Log == nil {
		sd.Log = io.Discard
	}
	now := time.Now
	if sd.Now != nil {
		now = sd.Now
	}
	loc, err := time.LoadLocation(Timezone)
	if err != nil {
		return nil, err
	}
	n := now().In(loc)
	r := &run{sd: sd, ctx: ctx, today: time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, loc),
		sum: &Summary{Created: map[string]int{}, Existing: map[string]int{}}}

	asha, err := r.person(Asha)
	if err != nil {
		return nil, err
	}
	ravi, err := r.person(Ravi)
	if err != nil {
		return nil, err
	}
	meera, err := r.person(Meera)
	if err != nil {
		return nil, err
	}
	steps := []struct {
		name string
		fn   func() error
	}{
		{"finances for " + asha.Email, func() error { return r.finances(asha, ashaPlan) }},
		{"finances for " + ravi.Email, func() error { return r.finances(ravi, raviPlan) }},
		{"finances for " + meera.Email, func() error { return r.finances(meera, meeraPlan) }},
		{"planning for " + asha.Email, func() error { return r.planning(asha) }},
		{"group", func() error { return r.group(asha, ravi, meera) }},
		{"community", func() error { return r.community(asha, ravi) }},
	}
	for _, st := range steps {
		if err := st.fn(); err != nil {
			return r.sum, fmt.Errorf("seed %s: %w%s", st.name, err, details(err))
		}
	}
	return r.sum, nil
}

// details lists an API error's field problems (validation errors say
// little without them).
func details(err error) string {
	var ae *apperr.Error
	if !errors.As(err, &ae) || len(ae.Details) == 0 {
		return ""
	}
	out := ""
	for _, d := range ae.Details {
		out += fmt.Sprintf(" [%s %s: %s]", d.Field, d.Code, d.Message)
	}
	return out
}

func (r *run) logf(created bool, kind, name string) {
	r.sum.add(kind, created)
	state := "exists "
	if created {
		state = "created"
	}
	_, _ = fmt.Fprintf(r.sd.Log, "%s %-14s %s\n", state, kind, name)
}

// day returns the date offset days from today (negative = past).
func (r *run) day(offset int) string { return r.today.AddDate(0, 0, offset).Format(time.DateOnly) }

// idemKey is a fixed idempotency key for one seed record (record names
// may hold spaces and symbols, so they are hashed).
func idemKey(parts ...string) string {
	h := sha256.Sum256([]byte(strings.Join(parts, "\x00")))
	return "seed-v1:" + hex.EncodeToString(h[:20])
}

// person signs in to a demo account, registering it first when it does not
// exist. An existing account with another password is never touched.
func (r *run) person(p Person) (*actor, error) {
	a := r.sd.App.Auth
	login := func() (*auth.AuthResult, error) {
		res, _, err := a.Login(r.ctx, auth.LoginInput{Email: p.Email, Password: DemoPassword, DeviceName: "Montra seed"})
		return res, err
	}
	res, err := login()
	created := false
	if err != nil {
		var ae *apperr.Error
		if !errors.As(err, &ae) || ae.Code != apperr.CodeUnauthenticated {
			return nil, fmt.Errorf("sign in to %s: %w", p.Email, err)
		}
		if err := a.RegisterUser(r.ctx, auth.RegisterInput{Email: p.Email, Password: DemoPassword, DisplayName: p.Name, AcceptTerms: true,
			ConfirmAdult: true, TermsVersion: auth.TermsVersion, PrivacyVersion: auth.PrivacyVersion, Locale: "en-IN", Timezone: Timezone,
			Currency: Currency, Country: "IN"}); err != nil {
			return nil, fmt.Errorf("register %s: %w", p.Email, err)
		}
		if res, err = login(); err != nil {
			return nil, fmt.Errorf("%s exists with another password or is not usable; it was left unchanged: %w", p.Email, err)
		}
		created = true
	}
	if res.Status != "authenticated" || res.User == nil || res.Session == nil {
		return nil, fmt.Errorf("%s needs two-step verification; it was left unchanged", p.Email)
	}
	r.logf(created, "user", p.Email)
	ctx := identity.With(r.ctx, identity.Principal{UserID: res.User.ID, SessionID: res.Session.ID, ClientKind: "unknown", EmailVerified: true})
	// The seed's own session is not needed after this run.
	if err := a.Logout(ctx); err != nil {
		return nil, err
	}
	return &actor{Person: p, id: res.User.ID, ctx: ctx}, nil
}

// ---------------------------------------------------------------- finances

type accountSpec struct {
	Name, Type, Opening string
}

type methodSpec struct {
	Label, Kind, Network, Hint, Account string
}

// txSpec is one fixed transaction. Offset is days before today.
type txSpec struct {
	Desc, Type, Account, Amount, Category, Merchant, Method string
	Offset                                                  int
	Pending                                                 bool
}

type refundSpec struct {
	Desc, Of, Amount string
	Offset           int
}

type transferSpec struct {
	Desc, From, To, Amount string
	Offset                 int
}

type plan struct {
	Accounts  []accountSpec
	Methods   []methodSpec
	Txs       []txSpec
	Refunds   []refundSpec
	Transfers []transferSpec
}

func (r *run) finances(u *actor, p plan) error {
	f := r.sd.App.Finance
	accts, err := f.ListAccounts(u.ctx, true)
	if err != nil {
		return err
	}
	acctID := map[string]uuid.UUID{}
	for _, a := range accts {
		acctID[a.Name] = a.ID
	}
	for _, s := range p.Accounts {
		if _, ok := acctID[s.Name]; ok {
			r.logf(false, "account", s.Name)
			continue
		}
		a, _, err := f.CreateAccount(u.ctx, idemKey(u.Key, "account", s.Name), finance.AccountInput{Name: s.Name, AccountType: s.Type,
			Currency: Currency, OpeningBalance: s.Opening, OpeningDate: r.day(-120)})
		if err != nil {
			return fmt.Errorf("account %s: %w", s.Name, err)
		}
		acctID[s.Name] = a.ID
		r.logf(true, "account", s.Name)
	}

	pms, err := f.ListPaymentMethods(u.ctx, true)
	if err != nil {
		return err
	}
	pmID := map[string]uuid.UUID{}
	for _, m := range pms {
		pmID[m.Label] = m.ID
	}
	for _, s := range p.Methods {
		if _, ok := pmID[s.Label]; ok {
			r.logf(false, "payment method", s.Label)
			continue
		}
		in := finance.PaymentMethodInput{Kind: s.Kind, Label: s.Label}
		if s.Network != "" {
			in.Network = &s.Network
		}
		if s.Hint != "" {
			in.MaskedHint = &s.Hint
		}
		if s.Account != "" {
			id := acctID[s.Account]
			in.AccountID = &id
		}
		m, err := f.SavePaymentMethod(u.ctx, nil, in)
		if err != nil {
			return fmt.Errorf("payment method %s: %w", s.Label, err)
		}
		pmID[s.Label] = m.ID
		r.logf(true, "payment method", s.Label)
	}

	cats, err := f.ListCategories(u.ctx, false)
	if err != nil {
		return err
	}
	catID := map[string]uuid.UUID{}
	for _, c := range cats {
		if c.SystemKey != nil {
			catID[*c.SystemKey] = c.ID
		}
	}

	// Existing transactions by description: the seed never adds one twice.
	have := map[string]uuid.UUID{}
	cursor := ""
	for {
		l, next, err := f.ListTransactions(u.ctx, finance.ListFilter{Status: "all", Cursor: cursor, Limit: 200})
		if err != nil {
			return err
		}
		for _, t := range l {
			if t.Description != nil {
				have[*t.Description] = t.ID
			}
		}
		if next == "" {
			break
		}
		cursor = next
	}

	for _, s := range p.Txs {
		if _, ok := have[s.Desc]; ok {
			r.logf(false, "transaction", s.Desc)
			continue
		}
		in := finance.TransactionInput{Type: s.Type, AccountID: acctID[s.Account], Amount: s.Amount, LocalDate: r.day(-s.Offset),
			Timezone: Timezone, Description: s.Desc, MerchantName: s.Merchant}
		if s.Category != "" {
			id, ok := catID[s.Category]
			if !ok {
				return fmt.Errorf("transaction %s: no starter category %s", s.Desc, s.Category)
			}
			in.CategoryID = &id
		}
		if s.Method != "" {
			id := pmID[s.Method]
			in.PaymentMethodID = &id
		}
		if s.Pending {
			in.Status = "pending"
		}
		res, _, err := f.CreateTransaction(u.ctx, idemKey(u.Key, "tx", s.Desc), in)
		if err != nil {
			return fmt.Errorf("transaction %s: %w", s.Desc, err)
		}
		have[s.Desc] = res.Transaction.ID
		r.logf(true, "transaction", s.Desc)
	}
	for _, s := range p.Refunds {
		if _, ok := have[s.Desc]; ok {
			r.logf(false, "refund", s.Desc)
			continue
		}
		orig, ok := have[s.Of]
		if !ok {
			return fmt.Errorf("refund %s: original %s missing", s.Desc, s.Of)
		}
		if _, _, err := f.CreateRefund(u.ctx, orig, idemKey(u.Key, "refund", s.Desc), finance.RefundInput{Amount: s.Amount,
			LocalDate: r.day(-s.Offset), Description: s.Desc}); err != nil {
			return fmt.Errorf("refund %s: %w", s.Desc, err)
		}
		r.logf(true, "refund", s.Desc)
	}
	for _, s := range p.Transfers {
		if _, ok := have[s.Desc]; ok {
			r.logf(false, "transfer", s.Desc)
			continue
		}
		if _, _, err := f.CreateTransfer(u.ctx, idemKey(u.Key, "transfer", s.Desc), finance.TransferInput{FromAccountID: acctID[s.From],
			ToAccountID: acctID[s.To], Amount: s.Amount, LocalDate: r.day(-s.Offset), Description: s.Desc}); err != nil {
			return fmt.Errorf("transfer %s: %w", s.Desc, err)
		}
		r.logf(true, "transfer", s.Desc)
	}
	return nil
}

// ---------------------------------------------------------------- planning

const (
	budgetName = "Groceries this month"
	goalName   = "Emergency fund"
)

func (r *run) planning(u *actor) error {
	cats, err := r.sd.App.Finance.ListCategories(u.ctx, false)
	if err != nil {
		return err
	}
	var groceries uuid.UUID
	var utilities, entertainment *uuid.UUID
	for _, c := range cats {
		if c.SystemKey == nil {
			continue
		}
		id := c.ID
		switch *c.SystemKey {
		case "groceries":
			groceries = id
		case "utilities":
			utilities = &id
		case "entertainment":
			entertainment = &id
		}
	}
	accts, err := r.sd.App.Finance.ListAccounts(u.ctx, false)
	if err != nil {
		return err
	}
	var bank *uuid.UUID
	for _, a := range accts {
		if a.Name == "Demo Bank" {
			id := a.ID
			bank = &id
		}
	}

	// Budget: the groceries bought today alone pass 75 % of the limit, so
	// a threshold alert exists whatever day of the month the seed runs.
	bs, err := r.sd.App.Budgets.List(u.ctx, true)
	if err != nil {
		return err
	}
	found := false
	for _, b := range bs {
		found = found || b.Name == budgetName
	}
	if !found {
		off := false
		if _, err := r.sd.App.Budgets.Save(u.ctx, nil, budgets.BudgetInput{Name: budgetName, BudgetType: "category", Period: "monthly",
			Currency: Currency, Limit: "3000", Timezone: Timezone, AlertForecast: &off,
			Allocations: []budgets.AllocInput{{CategoryID: &groceries, Limit: "3000"}}}); err != nil {
			return fmt.Errorf("budget: %w", err)
		}
	}
	r.logf(!found, "budget", budgetName)
	if r.sd.Worker != nil {
		uid := u.id
		if err := r.sd.Worker.Budgets.Evaluate(r.ctx, &uid, nil); err != nil {
			return fmt.Errorf("budget alerts: %w", err)
		}
	}

	// Bills due soon.
	bills, err := r.sd.App.Recurring.ListBills(u.ctx, "all")
	if err != nil {
		return err
	}
	haveBill := map[string]bool{}
	for _, b := range bills {
		haveBill[b.Name] = true
	}
	for _, b := range []struct {
		name, provider, amount string
		due                    int
		cat                    *uuid.UUID
	}{
		{"Electricity", "Demo Power Co", "1650.00", 5, utilities},
		{"Home internet", "Demo Fiber", "999.00", 12, utilities},
	} {
		if !haveBill[b.name] {
			if _, _, err := r.sd.App.Recurring.CreateBill(u.ctx, idemKey(u.Key, "bill", b.name), recurring.BillInput{Name: b.name,
				ProviderName: b.provider, ExpectedAmount: b.amount, Currency: Currency, PaymentAccountID: bank, CategoryID: b.cat,
				Schedule: recurring.Schedule{Frequency: "monthly", StartDate: r.day(b.due), Timezone: Timezone}}); err != nil {
				return fmt.Errorf("bill %s: %w", b.name, err)
			}
		}
		r.logf(!haveBill[b.name], "bill", b.name)
	}

	// Subscriptions.
	subs, err := r.sd.App.Subs.List(u.ctx, "all")
	if err != nil {
		return err
	}
	haveSub := map[string]bool{}
	for _, s := range subs {
		haveSub[s.Name] = true
	}
	for _, s := range []struct {
		name, merchant, amount, freq string
		started                      int
	}{
		{"StreamMax Premium", "StreamMax", "649.00", "monthly", 75},
		{"CloudBox 200 GB", "CloudBox", "1300.00", "yearly", 200},
	} {
		if !haveSub[s.name] {
			if _, _, err := r.sd.App.Subs.Create(u.ctx, idemKey(u.Key, "subscription", s.name), subscriptions.SubscriptionInput{Name: s.name,
				MerchantName: s.merchant, Amount: s.amount, Currency: Currency, BillingFrequency: s.freq, StartDate: r.day(-s.started),
				PaymentAccountID: bank, CategoryID: entertainment}); err != nil {
				return fmt.Errorf("subscription %s: %w", s.name, err)
			}
		}
		r.logf(!haveSub[s.name], "subscription", s.name)
	}

	// Goal with one recorded contribution.
	gs, err := r.sd.App.Goals.List(u.ctx, "all")
	if err != nil {
		return err
	}
	var goalID uuid.UUID
	for _, g := range gs {
		if g.Name == goalName {
			goalID = g.ID
		}
	}
	created := goalID == uuid.Nil
	if created {
		g, _, err := r.sd.App.Goals.Create(u.ctx, idemKey(u.Key, "goal", goalName), goals.GoalInput{Name: goalName, GoalType: "emergency_fund",
			TargetAmount: "150000.00", Currency: Currency, StartingAmount: "20000.00", StartDate: r.day(-60),
			TargetDate: r.today.AddDate(1, 0, 0).Format(time.DateOnly), Priority: 1, ContributionSchedule: "monthly",
			PlannedContribution: "5000.00", LinkedAccountID: bank})
		if err != nil {
			return fmt.Errorf("goal: %w", err)
		}
		goalID = g.ID
	}
	r.logf(created, "goal", goalName)
	contribs, _, err := r.sd.App.Goals.ListContributions(u.ctx, goalID, "", 50)
	if err != nil {
		return err
	}
	if len(contribs) == 0 {
		if _, _, err := r.sd.App.Goals.AddContribution(u.ctx, idemKey(u.Key, "goal-contribution"), goalID, goals.GoalContributionInput{
			Amount: "5000.00", ContributedOn: r.day(-15), Status: "recorded", Note: "Monthly top-up"}); err != nil {
			return fmt.Errorf("goal contribution: %w", err)
		}
	}
	r.logf(len(contribs) == 0, "contribution", goalName)
	return nil
}

// ------------------------------------------------------------------ groups

const groupName = "Demo Flat"

func (r *run) group(owner, a, b *actor) error {
	g := r.sd.App.Groups
	list, err := g.List(owner.ctx, true)
	if err != nil {
		return err
	}
	var gid uuid.UUID
	for _, x := range list {
		if x.Name == groupName && x.MyRole == "owner" {
			gid = x.ID
		}
	}
	created := gid == uuid.Nil
	if created {
		d, err := g.Create(owner.ctx, groups.GroupInput{Name: groupName, GroupType: "roommates", BaseCurrency: Currency, Timezone: Timezone,
			Description: "Shared flat costs (demo data)"})
		if err != nil {
			return err
		}
		gid = d.ID
	}
	r.logf(created, "group", groupName)

	detail, err := g.Get(owner.ctx, gid)
	if err != nil {
		return err
	}
	member := map[uuid.UUID]bool{}
	for _, m := range detail.Members {
		member[m.UserID] = m.Status == "active"
	}
	for _, p := range []*actor{a, b} {
		if !member[p.id] {
			inv, err := g.Invite(owner.ctx, gid, groups.GroupInvitationInput{Kind: "link", ExpiresInDays: 1})
			if err != nil {
				return err
			}
			if inv.Token == nil {
				return errors.New("invitation link without a token")
			}
			if _, _, err := g.AcceptLink(p.ctx, *inv.Token); err != nil {
				return fmt.Errorf("%s joins: %w", p.Email, err)
			}
		}
		r.logf(!member[p.id], "group member", p.Email)
	}

	exps, _, err := g.ListExpenses(owner.ctx, gid, groups.ExpenseFilter{IncludeDeleted: true}, "", 200)
	if err != nil {
		return err
	}
	haveExp := map[string]bool{}
	for _, e := range exps {
		haveExp[e.Description] = true
	}
	everyone := []groups.ExpenseParticipantInput{{UserID: owner.id}, {UserID: a.id}, {UserID: b.id}}
	for _, e := range []struct {
		payer                  *actor
		desc, amount, category string
		offset                 int
	}{
		{owner, "Flat groceries", "2400.00", "groceries", 20},
		{a, "Broadband for the flat", "1199.00", "utilities", 14},
		{b, "Cleaning supplies", "650.00", "shopping", 6},
	} {
		if !haveExp[e.desc] {
			if _, _, err := g.CreateExpense(e.payer.ctx, idemKey(e.payer.Key, "group-expense", e.desc), gid, groups.GroupExpenseInput{
				Description: e.desc, Amount: e.amount, ExpenseDate: r.day(-e.offset), CategoryKey: e.category, SplitMethod: "equal",
				Participants: everyone}); err != nil {
				return fmt.Errorf("group expense %s: %w", e.desc, err)
			}
		}
		r.logf(!haveExp[e.desc], "group expense", e.desc)
	}

	// Settlement: Ravi pays Asha back and Asha confirms it.
	sts, err := g.ListSettlements(owner.ctx, gid, true)
	if err != nil {
		return err
	}
	var st *groups.SettlementDTO
	for i := range sts {
		if sts[i].PayerUserID == a.id && sts[i].PayeeUserID == owner.id {
			st = &sts[i]
		}
	}
	created = st == nil
	if created {
		if st, _, err = g.CreateSettlement(a.ctx, idemKey(a.Key, "settlement"), gid, groups.SettlementInput{PayerUserID: a.id,
			PayeeUserID: owner.id, Amount: "400.00", Method: "upi", SettledOn: r.day(-2), Note: "Groceries share"}); err != nil {
			return fmt.Errorf("settlement: %w", err)
		}
	}
	if st.Status == "user_reported_paid" {
		if _, err := g.ActOnSettlement(owner.ctx, gid, st.ID, groups.SettlementActionInput{Action: "confirm", Version: st.Version}); err != nil {
			return fmt.Errorf("confirm settlement: %w", err)
		}
	}
	r.logf(created, "settlement", "Ravi → Asha")
	return nil
}

// ------------------------------------------------------------- communities

const (
	communitySlug = "montra-demo-savers"
	postTitle     = "How I keep groceries under budget"
)

func (r *run) community(owner, member *actor) error {
	c := r.sd.App.Communities
	com, err := c.Get(owner.ctx, communitySlug)
	created := false
	if err != nil {
		var ae *apperr.Error
		if !errors.As(err, &ae) || ae.Code != apperr.CodeNotFound {
			return err
		}
		if com, err = c.Create(owner.ctx, communities.CommunityInput{Name: "Montra Demo Savers", Slug: communitySlug,
			Description: "Demo community for saving tips (seed data).", Topics: []string{"saving", "budgeting"}, Visibility: "public"}); err != nil {
			return err
		}
		created = true
	}
	r.logf(created, "community", communitySlug)
	if com.MyStatus != "active" {
		return fmt.Errorf("community %s exists and %s is not a member; left unchanged", communitySlug, owner.Email)
	}
	m, err := c.Get(member.ctx, communitySlug)
	if err != nil {
		return err
	}
	if m.MyStatus == "none" || m.MyStatus == "left" {
		if _, err := c.Join(member.ctx, com.ID); err != nil {
			return err
		}
	}
	r.logf(m.MyStatus == "none" || m.MyStatus == "left", "member", member.Email)

	posts, _, err := c.Feed(owner.ctx, com.ID, "new", "", "", 100, 0)
	if err != nil {
		return err
	}
	have := false
	for _, p := range posts {
		have = have || p.Title == postTitle
	}
	if !have {
		if _, err := c.CreatePost(owner.ctx, com.ID, communities.CommunityPostInput{Kind: "discussion", Title: postTitle,
			Body: "I set a monthly groceries budget with an alert at 75 %, plan meals on Sunday and split flat groceries in a group. " +
				"What works for you?"}); err != nil {
			return err
		}
	}
	r.logf(!have, "post", postTitle)
	return nil
}
