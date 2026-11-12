package reports

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"slices"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/analytics"
	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/storage"
	"montra/backend/internal/reports/render"
)

func pct(bp int64) string { return money.FormatExp(bp, 2) }

const currenciesNote = "Unlike currencies are never summed without a disclosed conversion."

// flowMetric is one cash-flow total shown in a report.
type flowMetric struct {
	title string
	total func(analytics.CashFlowTotals) apitypes.Money
	conv  func(*analytics.ConvertedTotals) apitypes.Money
}

var (
	mIncome = flowMetric{"Income", func(t analytics.CashFlowTotals) apitypes.Money { return t.Income },
		func(c *analytics.ConvertedTotals) apitypes.Money { return c.Income }}
	mGross = flowMetric{"Gross expense", func(t analytics.CashFlowTotals) apitypes.Money { return t.GrossExpense },
		func(c *analytics.ConvertedTotals) apitypes.Money { return c.GrossExpense }}
	mRefunds = flowMetric{"Refunds", func(t analytics.CashFlowTotals) apitypes.Money { return t.Refunds },
		func(c *analytics.ConvertedTotals) apitypes.Money { return c.Refunds }}
	mNet = flowMetric{"Net expense", func(t analytics.CashFlowTotals) apitypes.Money { return t.NetExpense },
		func(c *analytics.ConvertedTotals) apitypes.Money { return c.NetExpense }}
	mFlow = flowMetric{"Net cash flow", func(t analytics.CashFlowTotals) apitypes.Money { return t.NetCashFlow },
		func(c *analytics.ConvertedTotals) apitypes.Money { return c.NetCashFlow }}
)

// seriesMetric is one series column.
type seriesMetric struct {
	title string
	get   func(analytics.SeriesPoint) apitypes.Money
}

// flowView is what a cash-flow style report shows. Income and expense
// reports show only their own side: an income report has no expense
// figures at all, an expense report no income.
type flowView struct {
	metrics     []flowMetric
	savingsRate bool
	series      []seriesMetric
	notes       []string
}

var (
	sIncome = seriesMetric{"Income", func(p analytics.SeriesPoint) apitypes.Money { return p.Income }}
	sNetExp = seriesMetric{"Net expense", func(p analytics.SeriesPoint) apitypes.Money { return p.NetExpense }}
	sNet    = seriesMetric{"Net", func(p analytics.SeriesPoint) apitypes.Money { return p.Net }}
)

func viewFor(reportType string) flowView {
	switch reportType {
	case "income":
		return flowView{metrics: []flowMetric{mIncome}, series: []seriesMetric{sIncome},
			notes: []string{"Only income transactions are included: transfers, refunds, reimbursements, adjustments, opening balances and settlements are not income.",
				currenciesNote}}
	case "expense":
		return flowView{metrics: []flowMetric{mGross, mRefunds, mNet}, series: []seriesMetric{sNetExp},
			notes: []string{"Expenses and your share of group expenses are included; refunds and reimbursements reduce spending. Income, transfers, adjustments, opening balances and settlements are excluded.",
				currenciesNote}}
	}
	return flowView{metrics: []flowMetric{mIncome, mGross, mRefunds, mNet, mFlow}, savingsRate: true, series: []seriesMetric{sIncome, sNetExp, sNet},
		notes: []string{"Transfers, adjustments, opening balances and settlements are excluded; refunds and reimbursements reduce spending.", currenciesNote}}
}

func cashFlowSections(r *analytics.CashFlowReport, reportType string) []render.Section {
	v := viewFor(reportType)
	cols := []render.Column{{Title: "Currency", Kind: render.Text}}
	for _, m := range v.metrics {
		cols = append(cols, render.Column{Title: m.title, Kind: render.Money})
	}
	if v.savingsRate {
		cols = append(cols, render.Column{Title: "Savings rate %", Kind: render.Percent})
	}
	cols = append(cols, render.Column{Title: "Transactions", Kind: render.Number})
	rows := func(list []analytics.CashFlowTotals) [][]string {
		var out [][]string
		for _, t := range list {
			row := []string{t.Currency}
			for _, m := range v.metrics {
				row = append(row, m.total(t).Amount)
			}
			if v.savingsRate {
				rate := ""
				if t.SavingsRateBP != nil {
					rate = pct(*t.SavingsRateBP)
				}
				row = append(row, rate)
			}
			out = append(out, append(row, fmt.Sprint(t.TransactionCount)))
		}
		return out
	}
	totals := render.Section{Title: "Totals", Columns: cols, Rows: rows(r.Totals), Notes: v.notes}
	prev := render.Section{Title: "Previous period", Columns: cols, Rows: rows(r.Previous)}
	if w := r.PreviousWindow; w.From != "" {
		prev.Notes = []string{fmt.Sprintf("The %d days before the report period: %s to %s.", w.Days, w.From, w.To)}
	}
	out := []render.Section{totals, prev}
	if c := r.Converted; c != nil {
		conv := render.Section{Title: "Converted to " + c.Currency, Columns: []render.Column{{Title: "Metric", Kind: render.Text},
			{Title: "Amount", Kind: render.Money}, {Title: "Currency", Kind: render.Text}}, Notes: []string{c.RatePolicy}}
		for _, m := range v.metrics {
			conv.Rows = append(conv.Rows, []string{m.title, m.conv(c).Amount, c.Currency})
		}
		for _, rt := range c.Rates {
			conv.Notes = append(conv.Notes, fmt.Sprintf("Rate %s→%s %s (%s, %s)", rt.Base, rt.Quote, rt.Rate, rt.Source, rt.AsOf.UTC().Format(time.RFC3339)))
		}
		if len(c.Unconverted) > 0 {
			conv.Notes = append(conv.Notes, "Not included (no rate): "+strings.Join(c.Unconverted, ", "))
		}
		out = append(out, conv)
	}
	sec := render.Section{Title: "Series", Columns: []render.Column{{Title: "Period start", Kind: render.Date}, {Title: "Currency", Kind: render.Text}}}
	for _, m := range v.series {
		sec.Columns = append(sec.Columns, render.Column{Title: m.title, Kind: render.Money})
	}
	for _, p := range r.Series {
		row := []string{p.Bucket, p.Currency}
		for _, m := range v.series {
			row = append(row, m.get(p).Amount)
		}
		sec.Rows = append(sec.Rows, row)
	}
	return append(out, sec)
}

func categorySection(r *analytics.CategoryReport) render.Section {
	title, measure := "Spending by category", "Net expense"
	if r.Kind == analytics.KindIncome {
		title, measure = "Income by category", "Income"
	}
	sec := render.Section{Title: title, Columns: []render.Column{{Title: "Category", Kind: render.Text}, {Title: "Currency", Kind: render.Text},
		{Title: measure, Kind: render.Money}, {Title: "Share %", Kind: render.Percent}, {Title: "Transactions", Kind: render.Number}}}
	for _, c := range r.Categories {
		sec.Rows = append(sec.Rows, []string{c.Name, c.Currency, c.Amount.Amount, pct(c.ShareBP), fmt.Sprint(c.Count)})
	}
	return sec
}

func merchantSection(r *analytics.MerchantReport) render.Section {
	sec := render.Section{Title: "Spending by merchant", Columns: []render.Column{{Title: "Merchant", Kind: render.Text}, {Title: "Currency", Kind: render.Text},
		{Title: "Net expense", Kind: render.Money}, {Title: "Transactions", Kind: render.Number}},
		Notes: []string{"Merchants are ranked separately in each currency."}}
	for _, m := range r.Merchants {
		sec.Rows = append(sec.Rows, []string{m.Name, m.Currency, m.NetExpense.Amount, fmt.Sprint(m.Count)})
	}
	return sec
}

func (s *Service) budgetSection(ctx context.Context) (render.Section, error) {
	list, err := s.Readers.Budgets.List(ctx, false)
	if err != nil {
		return render.Section{}, err
	}
	sec := render.Section{Title: "Budgets", Columns: []render.Column{{Title: "Budget", Kind: render.Text}, {Title: "Period", Kind: render.Text},
		{Title: "Currency", Kind: render.Text}, {Title: "Limit", Kind: render.Money}, {Title: "Spent", Kind: render.Money},
		{Title: "Remaining", Kind: render.Money}, {Title: "Used %", Kind: render.Percent}, {Title: "Pace", Kind: render.Text}}}
	for _, b := range list {
		if b.Progress == nil {
			continue
		}
		p := b.Progress
		sec.Rows = append(sec.Rows, []string{b.Name, p.PeriodStart + " – " + p.PeriodEnd, b.Currency, p.Limit.Amount, p.Spent.Amount,
			p.Remaining.Amount, pct(p.PercentBP), p.Pace})
	}
	return sec, nil
}

func (s *Service) subscriptionSection(ctx context.Context) (render.Section, error) {
	list, err := s.Readers.Subs.List(ctx, "all")
	if err != nil {
		return render.Section{}, err
	}
	sec := render.Section{Title: "Subscriptions", Columns: []render.Column{{Title: "Name", Kind: render.Text}, {Title: "Status", Kind: render.Text},
		{Title: "Currency", Kind: render.Text}, {Title: "Price", Kind: render.Money}, {Title: "Billing", Kind: render.Text},
		{Title: "Monthly cost", Kind: render.Money}, {Title: "Annual cost", Kind: render.Money}, {Title: "Next renewal", Kind: render.Date}}}
	for _, x := range list {
		next := ""
		if x.NextRenewalDate != nil {
			next = *x.NextRenewalDate
		}
		sec.Rows = append(sec.Rows, []string{x.Name, x.Status, x.Amount.Currency, x.Amount.Amount, x.BillingFrequency, x.MonthlyCost.Amount,
			x.AnnualCost.Amount, next})
	}
	return sec, nil
}

func (s *Service) goalSection(ctx context.Context) (render.Section, error) {
	list, err := s.Readers.Goals.List(ctx, "all")
	if err != nil {
		return render.Section{}, err
	}
	sec := render.Section{Title: "Goals", Columns: []render.Column{{Title: "Goal", Kind: render.Text}, {Title: "Status", Kind: render.Text},
		{Title: "Currency", Kind: render.Text}, {Title: "Target", Kind: render.Money}, {Title: "Saved", Kind: render.Money},
		{Title: "Progress %", Kind: render.Percent}, {Title: "Target date", Kind: render.Date}}}
	for _, g := range list {
		td := ""
		if g.TargetDate != nil {
			td = *g.TargetDate
		}
		sec.Rows = append(sec.Rows, []string{g.Name, g.Status, g.Target.Currency, g.Target.Amount, g.Progress.Saved.Amount, pct(g.Progress.PercentBP), td})
	}
	sec.Notes = []string{"Goal contributions are tracking records; verified ones link the ledger transaction that moved the money."}
	return sec, nil
}

// filter is the analytics filter a report is built with: the dates stored
// when it was requested (so a named range keeps its period) and, for income
// and expense reports, their type set (narrowed by the types chosen).
func (r *ReportDTO) filter() analytics.Filter {
	f := r.Filters.analytics()
	if r.Window != nil {
		f.Range, f.From, f.To = "", r.Window.From, r.Window.To
	}
	if set := typeSet(r.ReportType); set != nil {
		var keep []string
		for _, t := range f.Types {
			if slices.Contains(set, t) {
				keep = append(keep, t)
			}
		}
		if len(keep) == 0 {
			keep = set
		}
		f.Types = keep
	}
	return f
}

// build produces the document for a report (identity = report owner).
func (s *Service) build(ctx context.Context, r *ReportDTO) (render.Document, int, error) {
	a := s.Readers.Analytics
	f := r.filter()
	doc := render.Document{Title: r.Title}
	var win analytics.Window
	rows := 0
	var err error
	switch r.ReportType {
	case "transactions":
		sec := render.Section{Title: "Transactions", Columns: []render.Column{{Title: "Date", Kind: render.Date}, {Title: "Account", Kind: render.Text},
			{Title: "Type", Kind: render.Text}, {Title: "Direction", Kind: render.Text}, {Title: "Amount", Kind: render.Money},
			{Title: "Signed amount", Kind: render.Money}, {Title: "Currency", Kind: render.Text}, {Title: "Category", Kind: render.Text},
			{Title: "Merchant", Kind: render.Text}, {Title: "Description", Kind: render.Text}, {Title: "Tags", Kind: render.Text},
			{Title: "Status", Kind: render.Text}, {Title: "Source", Kind: render.Text}, {Title: "Original amount", Kind: render.Money},
			{Title: "Original currency", Kind: render.Text}, {Title: "FX rate", Kind: render.Number}}}
		win, rows, err = a.TransactionRows(ctx, f, MaxTransactionRows, func(t analytics.TxRow) error {
			sec.Rows = append(sec.Rows, []string{t.Date, t.Account, t.Type, t.Direction, t.Amount, t.SignedAmount, t.Currency, t.Category, t.Merchant,
				t.Description, t.Tags, t.Status, t.Source, t.OriginalAmount, t.OriginalCurrency, t.FXRate})
			return nil
		})
		if err != nil {
			return doc, 0, err
		}
		doc.Sections = append(doc.Sections, sec)
	case "cash_flow", "income", "expense", "monthly_summary", "yearly_summary":
		gran := "month"
		switch r.ReportType {
		case "monthly_summary":
			gran = "week"
		case "cash_flow", "income", "expense":
			gran = ""
		}
		cf, err := a.CashFlow(ctx, f, gran)
		if err != nil {
			return doc, 0, err
		}
		win = cf.Window
		doc.Sections = append(doc.Sections, cashFlowSections(cf, r.ReportType)...)
		var cr *analytics.CategoryReport
		switch r.ReportType {
		case "income":
			cr, err = a.CategoryBreakdown(ctx, f, analytics.CategoryOptions{Rollup: true, Kind: analytics.KindIncome})
		case "expense", "monthly_summary", "yearly_summary":
			cr, err = a.Categories(ctx, f, true)
		}
		if err != nil {
			return doc, 0, err
		}
		if cr != nil {
			doc.Sections = append(doc.Sections, categorySection(cr))
		}
		if r.ReportType == "monthly_summary" || r.ReportType == "yearly_summary" {
			mr, err := a.Merchants(ctx, f, 20)
			if err != nil {
				return doc, 0, err
			}
			doc.Sections = append(doc.Sections, merchantSection(mr))
			for _, fn := range []func(context.Context) (render.Section, error){s.budgetSection, s.subscriptionSection, s.goalSection} {
				sec, err := fn(ctx)
				if err != nil {
					return doc, 0, err
				}
				doc.Sections = append(doc.Sections, sec)
			}
		}
	case "category":
		cr, err := a.Categories(ctx, f, true)
		if err != nil {
			return doc, 0, err
		}
		win = cr.Window
		doc.Sections = append(doc.Sections, categorySection(cr))
	case "merchant":
		mr, err := a.Merchants(ctx, f, 100)
		if err != nil {
			return doc, 0, err
		}
		win = mr.Window
		doc.Sections = append(doc.Sections, merchantSection(mr))
	case "account":
		ar, err := a.Accounts(ctx, false)
		if err != nil {
			return doc, 0, err
		}
		sec := render.Section{Title: "Balances by currency", Columns: []render.Column{{Title: "Currency", Kind: render.Text},
			{Title: "Assets", Kind: render.Money}, {Title: "Liabilities", Kind: render.Money}, {Title: "Net worth", Kind: render.Money},
			{Title: "Accounts", Kind: render.Number}}, Notes: []string{"Tracked balances from your entries and imports; not verified by a bank."}}
		for _, t := range ar.Totals {
			sec.Rows = append(sec.Rows, []string{t.Currency, t.Assets.Amount, t.Liabilities.Amount, t.NetWorth.Amount, fmt.Sprint(t.AccountCount)})
		}
		doc.Sections = append(doc.Sections, sec)
	case "budget", "subscription", "goal":
		fn := map[string]func(context.Context) (render.Section, error){"budget": s.budgetSection, "subscription": s.subscriptionSection,
			"goal": s.goalSection}[r.ReportType]
		sec, err := fn(ctx)
		if err != nil {
			return doc, 0, err
		}
		doc.Sections = append(doc.Sections, sec)
	case "recurring":
		rr, err := a.Recurring(ctx)
		if err != nil {
			return doc, 0, err
		}
		sec := render.Section{Title: "Recurring commitments", Columns: []render.Column{{Title: "Kind", Kind: render.Text}, {Title: "Currency", Kind: render.Text},
			{Title: "Monthly equivalent", Kind: render.Money}, {Title: "Next 30 days", Kind: render.Money}, {Title: "Rules", Kind: render.Number},
			{Title: "Variable rules", Kind: render.Number}}, Notes: []string{rr.Note}}
		for _, c := range rr.Commitments {
			sec.Rows = append(sec.Rows, []string{c.Kind, c.Currency, c.MonthlyEquivalent.Amount, c.Next30Days.Amount, fmt.Sprint(c.RuleCount),
				fmt.Sprint(c.VariableCount)})
		}
		doc.Sections = append(doc.Sections, sec)
	default:
		return doc, 0, apperr.FieldError("report_type", "Unsupported report type.")
	}
	if rows == 0 {
		rows = doc.Rows()
	}
	doc.Meta = []render.KV{{Key: "Generated at", Value: s.now().UTC().Format(time.RFC3339)}, {Key: "Timezone", Value: r.Timezone}}
	if win.From != "" {
		doc.Meta = append(doc.Meta, render.KV{Key: "Period", Value: win.From + " to " + win.To})
	}
	cur := "Amounts are shown per currency (no conversion)"
	if r.Filters.DisplayCurrency != "" {
		cur = "Per-currency amounts plus a conversion to " + r.Filters.DisplayCurrency + " with disclosed rates"
	}
	doc.Meta = append(doc.Meta, render.KV{Key: "Currency", Value: cur}, render.KV{Key: "Scope", Value: "Personal"},
		render.KV{Key: "Filters", Value: describe(r.Filters)}, render.KV{Key: "Rows", Value: fmt.Sprint(rows)})
	return doc, rows, nil
}

func describe(f Filters) string {
	var parts []string
	if f.Range != "" {
		parts = append(parts, "range="+f.Range)
	}
	if f.From != "" {
		parts = append(parts, "from="+f.From, "to="+f.To)
	}
	if len(f.AccountIDs) > 0 {
		parts = append(parts, fmt.Sprintf("accounts=%d", len(f.AccountIDs)))
	}
	if len(f.CategoryIDs) > 0 {
		parts = append(parts, fmt.Sprintf("categories=%d", len(f.CategoryIDs)))
	}
	if len(f.MerchantIDs) > 0 {
		parts = append(parts, fmt.Sprintf("merchants=%d", len(f.MerchantIDs)))
	}
	if len(f.Tags) > 0 {
		parts = append(parts, "tags="+strings.Join(f.Tags, "|"))
	}
	if f.Currency != "" {
		parts = append(parts, "currency="+f.Currency)
	}
	if len(f.Types) > 0 {
		parts = append(parts, "types="+strings.Join(f.Types, "|"))
	}
	if f.IncludePending {
		parts = append(parts, "include_pending")
	}
	if len(parts) == 0 {
		return "none"
	}
	return strings.Join(parts, "; ")
}

var mimeOf = map[string]string{"csv": "text/csv", "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
	"pdf": "application/pdf", "json": "application/json"}

// failure is a generation error carrying the error_code to record when no
// retry is left.
type failure struct {
	code string
	err  error
}

func (f *failure) Error() string { return f.code + ": " + f.err.Error() }
func (f *failure) Unwrap() error { return f.err }

// failureCode is the error_code of a generation that failed for good.
func failureCode(err error) string {
	var f *failure
	if errors.As(err, &f) {
		return f.code
	}
	return ErrCodeGenerationFailed
}

// RegisterJobs registers report jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobGenerate, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			ReportID uuid.UUID `json:"report_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		err := s.generate(ctx, p.ReportID)
		if err != nil && (jobs.IsPermanent(err) || j.Attempt >= j.MaxAttempts) {
			// No retry is left (the job is dead-lettered): the report must
			// not stay running.
			s.giveUp(ctx, p.ReportID, failureCode(err))
		}
		return err
	}, jobs.WithTimeout(10*time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobSchedules, func(ctx context.Context, _ jobs.Job) error {
		if err := s.failAbandoned(ctx); err != nil {
			return err
		}
		return s.runSchedules(ctx)
	}, jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(1))
}

func (s *Service) setStatus(ctx context.Context, id uuid.UUID, status string, code *string) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `update reports set status = $2, error_code = $3 where id = $1`, id, status, code)
		return err
	})
}

// giveUp marks a report failed after its last attempt. The handler's
// deadline may have passed already, so it gets a fresh, short one.
func (s *Service) giveUp(ctx context.Context, id uuid.UUID, code string) {
	fctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 30*time.Second)
	defer cancel()
	if err := s.DB.WithSystemTx(fctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(fctx, `update reports set status = 'failed', error_code = $2 where id = $1 and status in ('queued','running')`, id, code)
		return err
	}); err != nil {
		slog.ErrorContext(ctx, "could not mark the report failed", slog.String("report_id", id.String()), slog.Any("error", err))
	}
}

// failAbandoned fails reports whose generation job ended without a result
// (dead-lettered after a crash or an expired lease on its last attempt, or
// cancelled by an operator). Usual final failures are marked by the
// handler itself.
func (s *Service) failAbandoned(ctx context.Context) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `update reports r set status = 'failed', error_code = $1
			from jobs j where j.id = r.job_id and r.status in ('queued','running') and j.status in ('dead','failed','cancelled')`, ErrCodeGenerationFailed)
		return err
	})
}

// generate builds, renders and stores a report.
func (s *Service) generate(ctx context.Context, id uuid.UUID) error {
	var r *ReportDTO
	var owner uuid.UUID
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var err error
		if err = tx.QueryRow(ctx, `select user_id from reports where id = $1`, id).Scan(&owner); err != nil {
			return err
		}
		r, err = scanReport(tx.QueryRow(ctx, `select `+reportCols+` from reports where id = $1 for update`, id))
		if err != nil {
			return err
		}
		if r.Status != "queued" && r.Status != "running" {
			r = nil
			return nil
		}
		_, err = tx.Exec(ctx, `update reports set status = 'running' where id = $1`, id)
		return err
	}); err != nil {
		if database.IsNoRows(err) {
			return nil
		}
		return err
	}
	if r == nil {
		return nil
	}
	if s.Readers == nil {
		code := ErrCodeUnavailable
		return s.setStatus(ctx, id, "failed", &code)
	}
	// Data is read as the owner through the RLS-enforcing app role.
	uctx := identity.With(ctx, identity.Principal{UserID: owner, ClientKind: "worker", EmailVerified: true})
	doc, rows, err := s.build(uctx, r)
	if err != nil {
		var ae *apperr.Error
		if errors.As(err, &ae) && ae.Status < 500 {
			code := ErrCodeInvalid
			if errors.Is(err, analytics.ErrTooManyRows) {
				code = ErrCodeTooManyRows
			}
			return s.setStatus(ctx, id, "failed", &code)
		}
		return err
	}
	var buf bytes.Buffer
	switch r.Format {
	case "csv":
		err = render.CSV(&buf, doc)
	case "xlsx":
		err = render.XLSX(&buf, doc)
	case "json":
		err = render.JSON(&buf, doc)
	case "pdf":
		if doc.Rows() > render.MaxPDFRows {
			code := ErrCodePDFTooLarge
			return s.setStatus(ctx, id, "failed", &code)
		}
		err = render.PDF(&buf, doc)
	}
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp("", "montra-report-*")
	if err != nil {
		return err
	}
	defer func() { _ = os.Remove(tmp.Name()) }()
	if _, err := tmp.Write(buf.Bytes()); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	key := storage.NewKey()
	if err := s.Store.Put(ctx, storage.AreaExports, key, tmp.Name(), mimeOf[r.Format]); err != nil {
		return jobs.WithCode(ErrCodeStorage, &failure{code: ErrCodeStorage, err: err})
	}
	expires := s.now().Add(s.Cfg.Product.Retention.ExportFiles)
	name := slug(r.Title) + "-" + s.now().UTC().Format("20060102") + "." + r.Format
	gone := false
	err = s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		// The owner may have deleted the report while it was generated.
		var status string
		err := tx.QueryRow(ctx, `select status from reports where id = $1 for update`, id).Scan(&status)
		if database.IsNoRows(err) || (err == nil && status != "running") {
			gone = true
			return nil
		}
		if err != nil {
			return err
		}
		var fileID uuid.UUID
		if err := tx.QueryRow(ctx, `insert into files (owner_user_id, storage_area, provider, bucket, object_key, purpose, original_filename,
			detected_mime, extension, size_bytes, status, retention_until, scan_status)
			values ($1,'exports',$2,$3,$4,'report_export',$5,$6,$7,$8,'ready',$9,'skipped') returning id`,
			owner, s.Store.Provider(), s.Store.Bucket(storage.AreaExports), key, name, mimeOf[r.Format], r.Format, buf.Len(), expires).Scan(&fileID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update reports set status = 'completed', file_id = $2, row_count = $3, completed_at = now(), expires_at = $4,
			error_code = null where id = $1`, id, fileID, rows, expires); err != nil {
			return err
		}
		// The deep link is a web route (the reports page); the report is
		// identified by entity_type/entity_id.
		_, _, err = notifications.Create(ctx, tx, notifications.Notification{UserID: owner, Category: "export", EventType: "report_ready",
			Title: "Your report is ready", Body: r.Title + " can be downloaded until " + expires.UTC().Format("2 Jan 2006") + ".",
			DeepLink: "/reports", EntityType: "report", EntityID: &id, DedupeKey: "report_ready:" + id.String()})
		return err
	})
	if err == nil && gone {
		if derr := s.Store.Delete(ctx, storage.AreaExports, key); derr != nil && !errors.Is(derr, storage.ErrNotFound) {
			slog.WarnContext(ctx, "could not remove the file of a deleted report", slog.String("report_id", id.String()), slog.Any("error", derr))
		}
	}
	return err
}

func slug(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == ' ' || r == '-' || r == '_':
			b.WriteRune('-')
		}
	}
	out := strings.Trim(b.String(), "-")
	if out == "" {
		return "report"
	}
	if len(out) > 50 {
		out = out[:50]
	}
	return out
}

// runSchedules creates due scheduled reports for the previous full period.
func (s *Service) runSchedules(ctx context.Context) error {
	type due struct {
		id, user uuid.UUID
		in       ReportInput
		cadence  string
		tz       string
	}
	var list []due
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select s.id, s.user_id, s.report_type, s.title, s.filters, s.format, s.cadence, p.timezone
			from scheduled_reports s join users u on u.id = s.user_id join user_preferences p on p.user_id = s.user_id
			where s.enabled and s.next_run_at <= $1 and u.status = 'active' order by s.next_run_at limit 200`, s.now())
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var d due
			var raw []byte
			if err := rows.Scan(&d.id, &d.user, &d.in.ReportType, &d.in.Title, &raw, &d.in.Format, &d.cadence, &d.tz); err != nil {
				return err
			}
			if err := json.Unmarshal(raw, &d.in.Filters); err != nil {
				return err
			}
			list = append(list, d)
		}
		return rows.Err()
	}); err != nil {
		return err
	}
	for _, d := range list {
		d.in.Filters.Range = map[string]string{"weekly": "last_week", "monthly": "last_month"}[d.cadence]
		d.in.Filters.From, d.in.Filters.To = "", ""
		loc, err := time.LoadLocation(d.tz)
		if err != nil {
			loc = time.UTC
		}
		advance := func(tx pgx.Tx) error {
			_, err := tx.Exec(ctx, `update scheduled_reports set next_run_at = $2 where id = $1`, d.id, nextRun(s.now(), loc, d.cadence))
			return err
		}
		err = s.DB.WithUserTx(ctx, d.user, func(tx pgx.Tx) error {
			if _, err := s.createTx(ctx, tx, d.user, d.in, "schedule"); err != nil {
				return err
			}
			return advance(tx)
		})
		var ae *apperr.Error
		if errors.As(err, &ae) && ae.Status < 500 {
			// A stored request that no longer validates skips this period
			// instead of blocking every other schedule behind it.
			slog.WarnContext(ctx, "scheduled report skipped", slog.String("schedule_id", d.id.String()), slog.String("code", string(ae.Code)))
			err = s.DB.WithUserTx(ctx, d.user, advance)
		}
		if err != nil {
			return err
		}
	}
	return nil
}
