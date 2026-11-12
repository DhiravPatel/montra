package statement

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"
	"time"
	"unicode"

	"montra/backend/internal/domain/money"
)

// Sign conventions for a single amount column.
const (
	SignNegativeIsOutflow = "negative_is_outflow"
	SignPositiveIsOutflow = "positive_is_outflow"
)

// Date formats accepted in mappings.
var DateFormats = []string{"YYYY-MM-DD", "DD/MM/YYYY", "MM/DD/YYYY", "DD-MM-YYYY", "MM-DD-YYYY", "DD.MM.YYYY", "YYYY/MM/DD",
	"DD/MM/YY", "MM/DD/YY", "DD-MM-YY", "DD-MMM-YYYY", "DD MMM YYYY", "DD-MMM-YY", "DD MMM YY", "MMM DD, YYYY", "YYYYMMDD"}

var goLayouts = map[string][]string{
	"YYYY-MM-DD": {"2006-01-02"}, "DD/MM/YYYY": {"02/01/2006", "2/1/2006"}, "MM/DD/YYYY": {"01/02/2006", "1/2/2006"},
	"DD-MM-YYYY": {"02-01-2006", "2-1-2006"}, "MM-DD-YYYY": {"01-02-2006", "1-2-2006"}, "DD.MM.YYYY": {"02.01.2006", "2.1.2006"},
	"YYYY/MM/DD": {"2006/01/02"}, "DD/MM/YY": {"02/01/06", "2/1/06"}, "MM/DD/YY": {"01/02/06", "1/2/06"}, "DD-MM-YY": {"02-01-06", "2-1-06"},
	"DD-MMM-YYYY": {"02-Jan-2006", "2-Jan-2006"}, "DD MMM YYYY": {"02 Jan 2006", "2 Jan 2006"}, "DD-MMM-YY": {"02-Jan-06", "2-Jan-06"},
	"DD MMM YY": {"02 Jan 06", "2 Jan 06"}, "MMM DD, YYYY": {"Jan 02, 2006", "Jan 2, 2006"}, "YYYYMMDD": {"20060102"},
}

// ColumnMapping tells the normalizer which columns hold which values.
type ColumnMapping struct {
	HeaderRow          int    `json:"header_row" doc:"0-based header row index; -1 when the file has no header"`
	DateColumn         int    `json:"date_column"`
	DateFormat         string `json:"date_format" doc:"One of: YYYY-MM-DD, DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY, MM-DD-YYYY, DD.MM.YYYY, YYYY/MM/DD, DD/MM/YY, MM/DD/YY, DD-MM-YY, DD-MMM-YYYY, DD MMM YYYY, DD-MMM-YY, DD MMM YY, MMM DD, YYYY (with comma), YYYYMMDD"`
	AmountColumn       *int   `json:"amount_column,omitempty" doc:"Single signed amount column"`
	SignConvention     string `json:"sign_convention,omitempty" enum:"negative_is_outflow,positive_is_outflow"`
	DebitColumn        *int   `json:"debit_column,omitempty" doc:"Money out (withdrawals)"`
	CreditColumn       *int   `json:"credit_column,omitempty" doc:"Money in (deposits)"`
	IndicatorColumn    *int   `json:"indicator_column,omitempty" doc:"Column holding Dr/Cr (overrides the sign)"`
	DecimalSeparator   string `json:"decimal_separator,omitempty" maxLength:"1" doc:"\".\" (default) or \",\""`
	DescriptionColumns []int  `json:"description_columns,omitempty"`
	ReferenceColumn    *int   `json:"reference_column,omitempty"`
	BalanceColumn      *int   `json:"balance_column,omitempty"`
	CurrencyColumn     *int   `json:"currency_column,omitempty"`
	ExternalIDColumn   *int   `json:"external_id_column,omitempty" doc:"Unique bank transaction ID (e.g. OFX FITID)"`
}

// Validate checks column indexes against a header width.
func (m ColumnMapping) Validate(width int) error {
	inRange := func(p *int) bool { return p == nil || (*p >= 0 && *p < width) }
	if m.DateColumn < 0 || m.DateColumn >= width {
		return fail("mapping", "Choose the date column.")
	}
	if _, ok := goLayouts[m.DateFormat]; !ok {
		return fail("mapping", "Choose a supported date format.")
	}
	if m.AmountColumn == nil && (m.DebitColumn == nil || m.CreditColumn == nil) {
		return fail("mapping", "Choose an amount column, or both debit and credit columns.")
	}
	if m.AmountColumn != nil && m.SignConvention != SignNegativeIsOutflow && m.SignConvention != SignPositiveIsOutflow {
		return fail("mapping", "Choose how the amount sign maps to money in and out.")
	}
	for _, p := range []*int{m.AmountColumn, m.DebitColumn, m.CreditColumn, m.IndicatorColumn, m.ReferenceColumn, m.BalanceColumn,
		m.CurrencyColumn, m.ExternalIDColumn} {
		if !inRange(p) {
			return fail("mapping", "A mapped column does not exist in the file.")
		}
	}
	for _, c := range m.DescriptionColumns {
		if c < 0 || c >= width {
			return fail("mapping", "A description column does not exist in the file.")
		}
	}
	if m.DecimalSeparator != "" && m.DecimalSeparator != "." && m.DecimalSeparator != "," {
		return fail("mapping", "The decimal separator must be . or ,")
	}
	return nil
}

// Row is a normalized statement row.
type Row struct {
	Date        time.Time
	AmountMinor int64
	Direction   string // inflow | outflow
	Description string
	Reference   string
	ExternalID  string
	Balance     *int64
}

// RowError explains why a row cannot be imported: a stable code, its
// English message and the values the code refers to.
type RowError struct {
	Code    string
	Message string
	Params  map[string]string
}

func cell(rec []string, i *int) string {
	if i == nil || *i < 0 || *i >= len(rec) {
		return ""
	}
	return strings.TrimSpace(rec[*i])
}

// ParseDate parses a statement date with a mapping format.
func ParseDate(s, format string) (time.Time, bool) {
	s = strings.TrimSpace(s)
	if i := strings.IndexAny(s, "T "); i == 10 && format == "YYYY-MM-DD" {
		s = s[:10] // datetime with time part
	}
	if len(s) > 10 && (format == "DD/MM/YYYY" || format == "MM/DD/YYYY" || format == "DD-MM-YYYY" || format == "DD.MM.YYYY") {
		if f := strings.Fields(s); len(f) > 1 {
			s = f[0] // drop a trailing time
		}
	}
	for _, l := range goLayouts[format] {
		if t, err := time.Parse(l, titleMonth(s)); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

// titleMonth normalizes "JAN"/"jan" month abbreviations to "Jan".
func titleMonth(s string) string {
	var sb strings.Builder
	run := 0
	for _, r := range s {
		if unicode.IsLetter(r) {
			if run == 0 {
				sb.WriteRune(unicode.ToUpper(r))
			} else {
				sb.WriteRune(unicode.ToLower(r))
			}
			run++
			continue
		}
		run = 0
		sb.WriteRune(r)
	}
	return sb.String()
}

// ParseAmount parses a statement amount: currency symbols, thousands
// separators, parentheses or trailing minus for negatives, and Dr/Cr
// suffixes. It returns the absolute minor amount, the sign (-1/0/+1), and an
// optional direction implied by a Dr/Cr suffix.
func ParseAmount(s, currency, decimalSep string) (minor int64, sign int, implied string, ok bool) {
	v := strings.TrimSpace(s)
	if v == "" || v == "-" {
		return 0, 0, "", true // empty cell
	}
	up := strings.ToUpper(v)
	switch {
	case strings.HasSuffix(up, "DR"):
		implied, v = "outflow", strings.TrimSpace(v[:len(v)-2])
	case strings.HasSuffix(up, "CR"):
		implied, v = "inflow", strings.TrimSpace(v[:len(v)-2])
	}
	neg := false
	if strings.HasPrefix(v, "(") && strings.HasSuffix(v, ")") {
		neg, v = true, strings.TrimSpace(v[1:len(v)-1])
	}
	if strings.HasSuffix(v, "-") {
		neg, v = true, strings.TrimSpace(v[:len(v)-1])
	}
	var sb strings.Builder
	prevLetter := false
	for _, r := range v {
		letter := unicode.IsLetter(r)
		switch {
		case r >= '0' && r <= '9':
			sb.WriteRune(r)
		case r == '.' && sb.Len() == 0 && prevLetter:
			// "Rs.1,234.56": the dot belongs to the currency abbreviation
		case r == '-' || r == '+':
			if sb.Len() == 0 {
				if r == '-' {
					neg = !neg
				}
				continue
			}
			return 0, 0, "", false
		case decimalSep == "," && r == ',':
			sb.WriteRune('.')
		case decimalSep != "," && r == '.':
			sb.WriteRune('.')
		case r == ',' || r == '.' || r == ' ' || r == '\'' || r == '_':
			// thousands separators
		case strings.ContainsRune("₹$€£¥", r), letter:
			// currency symbols and codes ("Rs", "INR")
		default:
			return 0, 0, "", false
		}
		prevLetter = letter
	}
	num := sb.String()
	if num == "" {
		return 0, 0, "", false
	}
	m, err := money.Parse(num, currency, money.ParseOptions{AllowZero: true}) // excess zero decimals (12.500) are accepted
	if err != nil {
		return 0, 0, "", false
	}
	sign = 1
	if m == 0 {
		sign = 0
	}
	if neg {
		sign = -sign
	}
	return m, sign, implied, true
}

// Normalize maps one data row. accountCurrency is the destination account's
// currency; rows in another currency are rejected (one currency per account).
func Normalize(rec []string, m ColumnMapping, accountCurrency string) (Row, *RowError) {
	var r Row
	ds := cell(rec, &m.DateColumn)
	if ds == "" {
		return r, &RowError{Code: "missing_date", Message: "The date is empty."}
	}
	d, ok := ParseDate(ds, m.DateFormat)
	if !ok {
		return r, &RowError{Code: "bad_date", Message: "The date does not match " + m.DateFormat + ".", Params: map[string]string{"format": m.DateFormat}}
	}
	r.Date = d
	if cur := strings.ToUpper(cell(rec, m.CurrencyColumn)); cur != "" && cur != accountCurrency {
		return r, &RowError{Code: "currency_mismatch", Message: "This row is in " + cur + "; import it into an account in that currency.",
			Params: map[string]string{"currency": cur, "account_currency": accountCurrency}}
	}
	sep := m.DecimalSeparator
	if sep == "" {
		sep = "."
	}
	if m.AmountColumn != nil {
		amt, sign, implied, ok := ParseAmount(cell(rec, m.AmountColumn), accountCurrency, sep)
		if !ok {
			return r, &RowError{Code: "bad_amount", Message: "The amount is not a number in " + accountCurrency + " precision.",
				Params: map[string]string{"currency": accountCurrency}}
		}
		if sign == 0 {
			return r, &RowError{Code: "zero_amount", Message: "The amount is empty or zero."}
		}
		r.AmountMinor = amt
		out := sign < 0
		if m.SignConvention == SignPositiveIsOutflow {
			out = sign > 0
		}
		r.Direction = map[bool]string{true: "outflow", false: "inflow"}[out]
		if implied != "" {
			r.Direction = implied
		}
	} else {
		debit, ds2, _, okD := ParseAmount(cell(rec, m.DebitColumn), accountCurrency, sep)
		credit, cs, _, okC := ParseAmount(cell(rec, m.CreditColumn), accountCurrency, sep)
		if !okD || !okC {
			return r, &RowError{Code: "bad_amount", Message: "The debit or credit is not a number in " + accountCurrency + " precision.",
				Params: map[string]string{"currency": accountCurrency}}
		}
		switch {
		case ds2 != 0 && cs != 0:
			return r, &RowError{Code: "both_debit_credit", Message: "Both debit and credit have values."}
		case ds2 != 0:
			r.AmountMinor, r.Direction = debit, "outflow"
		case cs != 0:
			r.AmountMinor, r.Direction = credit, "inflow"
		default:
			return r, &RowError{Code: "zero_amount", Message: "Debit and credit are both empty or zero."}
		}
	}
	if ind := strings.ToUpper(cell(rec, m.IndicatorColumn)); ind != "" {
		switch ind {
		case "DR", "D", "DEBIT", "WITHDRAWAL", "OUT":
			r.Direction = "outflow"
		case "CR", "C", "CREDIT", "DEPOSIT", "IN":
			r.Direction = "inflow"
		}
	}
	var parts []string
	for _, c := range m.DescriptionColumns {
		if v := cell(rec, &c); v != "" && !containsFold(parts, v) {
			parts = append(parts, v)
		}
	}
	r.Description = clip(strings.Join(strings.Fields(strings.Join(parts, " — ")), " "), 500)
	r.Reference = clip(cell(rec, m.ReferenceColumn), 200)
	r.ExternalID = clip(cell(rec, m.ExternalIDColumn), 200)
	if b := cell(rec, m.BalanceColumn); b != "" {
		if bal, sign, implied, ok := ParseAmount(b, accountCurrency, sep); ok {
			if sign < 0 || implied == "outflow" {
				bal = -bal
			}
			r.Balance = &bal
		}
	}
	return r, nil
}

func containsFold(list []string, v string) bool {
	for _, x := range list {
		if strings.EqualFold(x, v) {
			return true
		}
	}
	return false
}

func clip(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n])
	}
	return s
}

// normText keeps lower-case letters and digits (stable across cosmetic
// parser changes).
func normText(s string) string {
	var sb strings.Builder
	for _, r := range strings.ToLower(s) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			sb.WriteRune(r)
		}
	}
	return sb.String()
}

// Fingerprint identifies a statement row deterministically. occurrence
// distinguishes identical rows within one file (two equal coffees on the
// same day), so re-importing the same file reproduces the same
// fingerprints while genuine repeats stay distinct.
func Fingerprint(accountID string, r Row, occurrence int) string {
	key := r.ExternalID
	if key == "" {
		key = normText(r.Reference)
	}
	if key == "" {
		key = normText(r.Description)
	}
	h := sha256.Sum256([]byte(strings.Join([]string{"stmt-v1", accountID, r.Date.Format("2006-01-02"), r.Direction,
		strconv.FormatInt(r.AmountMinor, 10), key, strconv.Itoa(occurrence)}, "|")))
	return hex.EncodeToString(h[:])
}

// Similarity is a token Jaccard score (0–1000) between two descriptions.
func Similarity(a, b string) int {
	ta, tb := tokens(a), tokens(b)
	if len(ta) == 0 || len(tb) == 0 {
		return 0
	}
	inter := 0
	for t := range ta {
		if tb[t] {
			inter++
		}
	}
	union := len(ta) + len(tb) - inter
	return inter * 1000 / union
}

func tokens(s string) map[string]bool {
	out := map[string]bool{}
	for _, f := range strings.FieldsFunc(strings.ToLower(s), func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) }) {
		if len(f) >= 3 && !isAllDigits(f) {
			out[f] = true
		}
	}
	return out
}

func isAllDigits(s string) bool {
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// RowTotals summarizes valid rows and checks running-balance continuity.
type RowTotals struct {
	ValidRows         int    `json:"valid_rows"`
	InflowMinor       int64  `json:"inflow_minor"`
	OutflowMinor      int64  `json:"outflow_minor"`
	NetMinor          int64  `json:"net_minor"`
	BalanceCheck      string `json:"balance_check" enum:"ok,mismatch,not_available"`
	MismatchedRows    []int  `json:"mismatched_rows,omitempty" doc:"Row numbers whose running balance does not follow"`
	OpeningBalance    *int64 `json:"opening_balance_minor,omitempty"`
	ClosingBalance    *int64 `json:"closing_balance_minor,omitempty"`
	FirstDate         string `json:"first_date,omitempty"`
	LastDate          string `json:"last_date,omitempty"`
	ChronologicalHint string `json:"order,omitempty" enum:"ascending,descending,mixed"`
}

// NumberedRow pairs a file row number with its normalized row.
type NumberedRow struct {
	Number int
	Row    Row
}

// ComputeTotals sums rows (in file order) and validates balances.
func ComputeTotals(rows []NumberedRow) (RowTotals, error) {
	t := RowTotals{BalanceCheck: "not_available"}
	if len(rows) == 0 {
		return t, nil
	}
	asc, desc := true, true
	for i, nr := range rows {
		r := nr.Row
		t.ValidRows++
		var err error
		if r.Direction == "inflow" {
			t.InflowMinor, err = money.Add(t.InflowMinor, r.AmountMinor)
		} else {
			t.OutflowMinor, err = money.Add(t.OutflowMinor, r.AmountMinor)
		}
		if err != nil {
			return t, err
		}
		if i > 0 {
			prev := rows[i-1].Row.Date
			if r.Date.Before(prev) {
				asc = false
			}
			if r.Date.After(prev) {
				desc = false
			}
		}
	}
	var err error
	if t.NetMinor, err = money.Sub(t.InflowMinor, t.OutflowMinor); err != nil {
		return t, err
	}
	first, last := rows[0].Row.Date, rows[len(rows)-1].Row.Date
	switch {
	case asc:
		t.ChronologicalHint = "ascending"
	case desc:
		t.ChronologicalHint = "descending"
		first, last = last, first
	default:
		t.ChronologicalHint = "mixed"
	}
	t.FirstDate, t.LastDate = first.Format("2006-01-02"), last.Format("2006-01-02")
	// Running balance: in chronological order, balance_i = balance_{i-1} ± amount_i.
	ordered := rows
	if t.ChronologicalHint == "descending" {
		ordered = make([]NumberedRow, len(rows))
		for i := range rows {
			ordered[i] = rows[len(rows)-1-i]
		}
	}
	have := 0
	for _, nr := range ordered {
		if nr.Row.Balance != nil {
			have++
		}
	}
	if have != len(ordered) || t.ChronologicalHint == "mixed" {
		return t, nil
	}
	signed := func(r Row) int64 {
		if r.Direction == "inflow" {
			return r.AmountMinor
		}
		return -r.AmountMinor
	}
	open := *ordered[0].Row.Balance - signed(ordered[0].Row)
	closing := *ordered[len(ordered)-1].Row.Balance
	t.OpeningBalance, t.ClosingBalance = &open, &closing
	t.BalanceCheck = "ok"
	for i := 1; i < len(ordered); i++ {
		if *ordered[i-1].Row.Balance+signed(ordered[i].Row) != *ordered[i].Row.Balance {
			t.BalanceCheck = "mismatch"
			t.MismatchedRows = append(t.MismatchedRows, ordered[i].Number)
		}
	}
	return t, nil
}

// String renders a row error.
func (e RowError) String() string { return fmt.Sprintf("%s: %s", e.Code, e.Message) }
