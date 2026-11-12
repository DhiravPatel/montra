package statement

import (
	"regexp"
	"strings"
)

// Suggestion is a proposed mapping plus notes for the user to check.
type Suggestion struct {
	Mapping  ColumnMapping
	Complete bool   // all required fields were found
	Notes    []Note // e.g. ambiguous day/month order
}

// Mapping note codes (stable; Text is the English fallback).
const (
	NoteNoHeaderRow         = "no_header_row"
	NoteAmbiguousDateOrder  = "ambiguous_date_order" // params: assumed_date_format, alternative_date_format
	NoteUnknownDateFormat   = "unknown_date_format"
	NoteDecimalComma        = "decimal_comma"
	NoteMappingIncomplete   = "mapping_incomplete"
	NoteCheckSignConvention = "check_sign_convention"
)

// Note is something to check in a suggested mapping: a stable code, its
// English text and the values the code refers to.
type Note struct {
	Code   string
	Text   string
	Params map[string]string
}

var (
	commaDecimal = regexp.MustCompile(`\d,\d{1,2}$`)  // 12,50 or 2.500,00
	dotDecimal   = regexp.MustCompile(`\d\.\d{1,2}$`) // 12.50 or 2,500.00
)

func has(name string, words ...string) bool {
	for _, w := range words {
		if name == w || strings.Contains(name, w) {
			return true
		}
	}
	return false
}

// Suggest proposes a mapping from the header names and sample values.
func Suggest(t *Table) Suggestion {
	if t.Format == "ofx" {
		return Suggestion{Mapping: OFXMapping(), Complete: true}
	}
	s := Suggestion{Mapping: ColumnMapping{HeaderRow: t.HeaderRow, DateColumn: -1, SignConvention: SignNegativeIsOutflow, DecimalSeparator: "."}}
	if t.HeaderRow < 0 || t.HeaderRow >= len(t.Rows) {
		s.Notes = append(s.Notes, Note{Code: NoteNoHeaderRow, Text: "No header row was found; map the columns manually."})
		return s
	}
	m := &s.Mapping
	header := t.Rows[t.HeaderRow]
	sample := t.Rows[t.HeaderRow+1 : min(len(t.Rows), t.HeaderRow+201)]
	setOnce := func(p **int, i int) {
		if *p == nil {
			v := i
			*p = &v
		}
	}
	dateScore := -1
	for i, raw := range header {
		n := strings.ToLower(strings.TrimSpace(raw))
		switch {
		case has(n, "date"):
			score := 1
			if has(n, "txn", "transaction", "posting", "posted", "tran") {
				score = 3
			} else if n == "date" {
				score = 2
			} else if has(n, "value") {
				score = 0
			}
			if score > dateScore {
				m.DateColumn, dateScore = i, score
			}
		case has(n, "balance", "bal."):
			setOnce(&m.BalanceColumn, i)
		case has(n, "dr/cr", "cr/dr", "dr / cr"):
			setOnce(&m.IndicatorColumn, i)
		case has(n, "debit", "withdrawal", "paid out", "money out") || n == "dr" || n == "dr.":
			setOnce(&m.DebitColumn, i)
		case has(n, "credit", "deposit", "paid in", "money in") || n == "cr" || n == "cr.":
			setOnce(&m.CreditColumn, i)
		case has(n, "amount", "amt"):
			setOnce(&m.AmountColumn, i)
		case has(n, "description", "narration", "particulars", "details", "remarks", "payee", "memo", "merchant", "transaction remarks"):
			m.DescriptionColumns = append(m.DescriptionColumns, i)
		case has(n, "reference", "ref", "chq", "cheque", "utr"):
			setOnce(&m.ReferenceColumn, i)
		case has(n, "currency", "ccy"):
			setOnce(&m.CurrencyColumn, i)
		}
	}
	if m.DebitColumn != nil && m.CreditColumn != nil {
		m.AmountColumn = nil // separate debit/credit columns win over a generic amount column
	} else {
		m.DebitColumn, m.CreditColumn = nil, nil
	}
	if m.DateColumn >= 0 {
		m.DateFormat, s.Notes = detectDateFormat(sample, m.DateColumn, s.Notes)
	}
	var amountCols []int
	for _, p := range []*int{m.AmountColumn, m.DebitColumn, m.CreditColumn, m.BalanceColumn} {
		if p != nil {
			amountCols = append(amountCols, *p)
		}
	}
	commas, dots := 0, 0
	for _, r := range sample {
		for _, c := range amountCols {
			if c < len(r) {
				v := strings.TrimSpace(r[c])
				v = strings.TrimSpace(strings.TrimSuffix(strings.TrimSuffix(strings.ToUpper(v), "CR"), "DR"))
				switch {
				case commaDecimal.MatchString(v):
					commas++
				case dotDecimal.MatchString(v):
					dots++
				}
			}
		}
	}
	if commas > dots {
		m.DecimalSeparator = ","
		s.Notes = append(s.Notes, Note{Code: NoteDecimalComma, Text: "Amounts use a decimal comma."})
	}
	s.Complete = m.DateColumn >= 0 && m.DateFormat != "" && (m.AmountColumn != nil || (m.DebitColumn != nil && m.CreditColumn != nil))
	if !s.Complete {
		m.DateColumn = max(m.DateColumn, 0)
		s.Notes = append(s.Notes, Note{Code: NoteMappingIncomplete, Text: "Some required columns were not recognized; complete the mapping."})
	}
	if m.AmountColumn != nil {
		s.Notes = append(s.Notes, Note{Code: NoteCheckSignConvention, Text: "Check whether negative amounts are money out (default) or money in."})
	}
	return s
}

// detectDateFormat picks the format that parses the most sample values;
// day/month ambiguity defaults to day-first and is reported.
func detectDateFormat(sample [][]string, col int, notes []Note) (string, []Note) {
	best, bestN := "", 0
	counts := map[string]int{}
	values := 0
	for _, r := range sample {
		if col >= len(r) || strings.TrimSpace(r[col]) == "" {
			continue
		}
		values++
		for _, f := range DateFormats {
			if _, ok := ParseDate(r[col], f); ok {
				counts[f]++
			}
		}
	}
	for _, f := range DateFormats { // stable preference order
		if counts[f] > bestN {
			best, bestN = f, counts[f]
		}
	}
	pairs := map[string]string{"DD/MM/YYYY": "MM/DD/YYYY", "DD-MM-YYYY": "MM-DD-YYYY", "DD/MM/YY": "MM/DD/YY"}
	for dm, md := range pairs {
		if best == dm && counts[md] == counts[dm] && values > 0 {
			notes = append(notes, Note{Code: NoteAmbiguousDateOrder, Text: "Dates could be day-first or month-first; day-first (" + dm + ") was assumed.",
				Params: map[string]string{"assumed_date_format": dm, "alternative_date_format": md}})
		}
		if best == md && counts[dm] == counts[md] {
			best = dm
		}
	}
	if bestN == 0 {
		notes = append(notes, Note{Code: NoteUnknownDateFormat, Text: "The date format was not recognized."})
	}
	return best, notes
}
