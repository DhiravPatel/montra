package statement

import (
	"archive/zip"
	"bytes"
	"errors"
	"strings"
	"testing"
	"time"
	"unicode/utf16"
)

// Synthetic fixtures only (no real statements).
const bankCSV = `Statement of account,,,,,,
Account No: XXXXXXXX1234,,,,,,
,,,,,,
Txn Date,Narration,Chq./Ref.No.,Value Dt,Withdrawal Amt.,Deposit Amt.,Closing Balance
01/10/25,UPI-GROCER-PAYMENT,UPI123,01/10/25,"1,250.50",,"48,749.50"
02/10/25,SALARY CREDIT ACME,NEFT9,02/10/25,,"75,000.00","1,23,749.50"
02/10/25,UPI-GROCER-PAYMENT,UPI124,02/10/25,"1,250.50",,"1,22,499.00"
15/10/25,ATM WDL,,15/10/25,"2,000.00",,"1,20,499.00"
`

func mustParse(t *testing.T, data []byte, format string) *Table {
	t.Helper()
	tb, err := Parse(data, format, DefaultLimits)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	return tb
}

func normalizeAll(t *testing.T, tb *Table, m ColumnMapping, cur string) ([]NumberedRow, map[int]*RowError) {
	t.Helper()
	if err := m.Validate(len(tb.Rows[max(m.HeaderRow, 0)])); err != nil {
		t.Fatalf("mapping: %v", err)
	}
	var ok []NumberedRow
	bad := map[int]*RowError{}
	for i := m.HeaderRow + 1; i < len(tb.Rows); i++ {
		r, e := Normalize(tb.Rows[i], m, cur)
		if e != nil {
			bad[i+1] = e
			continue
		}
		ok = append(ok, NumberedRow{Number: i + 1, Row: r})
	}
	return ok, bad
}

func TestBankCSVWithPreambleDebitCreditAndBalances(t *testing.T) {
	tb := mustParse(t, []byte(bankCSV), "csv")
	// The blank preamble line is not a row; source line numbers are kept.
	if tb.HeaderRow != 2 || tb.Source[tb.HeaderRow] != 4 || tb.Source[3] != 5 || tb.Delimiter != "," || tb.Encoding != "utf-8" {
		t.Fatalf("header=%d delim=%q enc=%s", tb.HeaderRow, tb.Delimiter, tb.Encoding)
	}
	sg := Suggest(tb)
	m := sg.Mapping
	if !sg.Complete || m.DateColumn != 0 || m.DateFormat != "DD/MM/YY" || m.DebitColumn == nil || *m.DebitColumn != 4 ||
		m.CreditColumn == nil || *m.CreditColumn != 5 || m.BalanceColumn == nil || *m.BalanceColumn != 6 ||
		m.ReferenceColumn == nil || *m.ReferenceColumn != 2 || len(m.DescriptionColumns) != 1 || m.AmountColumn != nil {
		t.Fatalf("suggestion = %+v (notes %v)", m, sg.Notes)
	}
	rows, bad := normalizeAll(t, tb, m, "INR")
	if len(bad) != 0 || len(rows) != 4 {
		t.Fatalf("rows=%d bad=%v", len(rows), bad)
	}
	r0 := rows[0].Row
	if r0.AmountMinor != 125050 || r0.Direction != "outflow" || r0.Reference != "UPI123" || r0.Date != time.Date(2025, 10, 1, 0, 0, 0, 0, time.UTC) {
		t.Fatalf("row0 = %+v", r0)
	}
	if rows[1].Row.Direction != "inflow" || rows[1].Row.AmountMinor != 7500000 || *rows[1].Row.Balance != 12374950 {
		t.Fatalf("row1 = %+v", rows[1].Row)
	}
	tot, err := ComputeTotals(rows)
	if err != nil {
		t.Fatal(err)
	}
	if tot.BalanceCheck != "ok" || *tot.OpeningBalance != 5000000 || *tot.ClosingBalance != 12049900 || tot.InflowMinor != 7500000 ||
		tot.OutflowMinor != 450100 || tot.ChronologicalHint != "ascending" {
		t.Fatalf("totals = %+v", tot)
	}
	// Identical rows on different days and repeated imports: fingerprints.
	f1 := Fingerprint("acct", r0, 0)
	if f1 != Fingerprint("acct", r0, 0) || f1 == Fingerprint("acct", r0, 1) || f1 == Fingerprint("other", r0, 0) {
		t.Fatal("fingerprints must be deterministic per occurrence and account")
	}
}

func TestBalanceMismatchAndDescendingOrder(t *testing.T) {
	// Descending statement; the newest row's balance is off by 5.00.
	csv := "Date,Description,Amount,Balance\n2025-10-03,Coffee,-100.00,705.00\n2025-10-02,Refund,50.00,800.00\n2025-10-01,Book,-250.00,750.00\n"
	tb := mustParse(t, []byte(csv), "csv")
	m := Suggest(tb).Mapping
	rows, _ := normalizeAll(t, tb, m, "INR")
	tot, _ := ComputeTotals(rows)
	if tot.ChronologicalHint != "descending" || tot.BalanceCheck != "mismatch" || len(tot.MismatchedRows) != 1 || tot.MismatchedRows[0] != 2 ||
		tot.FirstDate != "2025-10-01" {
		t.Fatalf("totals = %+v", tot)
	}
}

func TestSemicolonDecimalCommaAndSigns(t *testing.T) {
	csv := "Date;Description;Amount\n05.11.2025;Bakery;-12,50\n06.11.2025;Gehalt;2.500,00\n"
	tb := mustParse(t, []byte(csv), "csv")
	sg := Suggest(tb)
	if tb.Delimiter != ";" || sg.Mapping.DecimalSeparator != "," || sg.Mapping.DateFormat != "DD.MM.YYYY" {
		t.Fatalf("delim=%q mapping=%+v", tb.Delimiter, sg.Mapping)
	}
	rows, bad := normalizeAll(t, tb, sg.Mapping, "EUR")
	if len(bad) != 0 || rows[0].Row.AmountMinor != 1250 || rows[0].Row.Direction != "outflow" || rows[1].Row.AmountMinor != 250000 ||
		rows[1].Row.Direction != "inflow" {
		t.Fatalf("rows = %+v bad = %v", rows, bad)
	}
	m := sg.Mapping
	m.SignConvention = SignPositiveIsOutflow
	r, _ := Normalize(tb.Rows[1], m, "EUR")
	if r.Direction != "inflow" {
		t.Fatalf("positive_is_outflow: %+v", r)
	}
}

func TestEncodings(t *testing.T) {
	text := "Date,Description,Amount\r\n2025-11-01,Café,-3.50\r\n"
	u := utf16.Encode([]rune(text))
	le := []byte{0xFF, 0xFE}
	for _, x := range u {
		le = append(le, byte(x), byte(x>>8))
	}
	tb := mustParse(t, le, "csv")
	if tb.Encoding != "utf-16le" || tb.Rows[1][1] != "Café" {
		t.Fatalf("utf-16: %s %v", tb.Encoding, tb.Rows)
	}
	cp := []byte("Date,Description,Amount\n2025-11-01,Caf\xe9 \x80,-3.50\n")
	tb = mustParse(t, cp, "csv")
	if tb.Encoding != "windows-1252" || tb.Rows[1][1] != "Café €" {
		t.Fatalf("cp1252: %s %q", tb.Encoding, tb.Rows[1][1])
	}
	bom := append([]byte{0xEF, 0xBB, 0xBF}, []byte(text)...)
	if tb := mustParse(t, bom, "csv"); tb.Encoding != "utf-8-bom" || tb.Rows[0][0] != "Date" {
		t.Fatalf("bom: %s %q", tb.Encoding, tb.Rows[0][0])
	}
}

func TestAmountParsing(t *testing.T) {
	cases := []struct {
		in, sep  string
		minor    int64
		sign     int
		implied  string
		ok       bool
		currency string
	}{
		{"1,234.56", ".", 123456, 1, "", true, "INR"},
		{"(1,234.56)", ".", 123456, -1, "", true, "INR"},
		{"1,234.56-", ".", 123456, -1, "", true, "INR"},
		{"₹1,23,456.00", ".", 12345600, 1, "", true, "INR"},
		{"Rs.1,234.56", ".", 123456, 1, "", true, "INR"},
		{"INR -42", ".", 4200, -1, "", true, "INR"},
		{"1.234,56", ",", 123456, 1, "", true, "EUR"},
		{"12.500", ".", 1250, 1, "", true, "INR"},
		{"12.505", ".", 0, 0, "", false, "INR"},
		{"1,234.56 Cr", ".", 123456, 1, "inflow", true, "INR"},
		{"500.00 DR", ".", 50000, 1, "outflow", true, "INR"},
		{"1500", ".", 1500, 1, "", true, "JPY"},
		{"abc", ".", 0, 0, "", false, "INR"},
		{"1-2", ".", 0, 0, "", false, "INR"},
		{"", ".", 0, 0, "", true, "INR"},
	}
	for _, c := range cases {
		m, s, imp, ok := ParseAmount(c.in, c.currency, c.sep)
		if ok != c.ok || (ok && (m != c.minor || s != c.sign || imp != c.implied)) {
			t.Errorf("ParseAmount(%q) = %d %d %q %v", c.in, m, s, imp, ok)
		}
	}
}

func TestRowErrorsAreExplained(t *testing.T) {
	m := ColumnMapping{HeaderRow: 0, DateColumn: 0, DateFormat: "YYYY-MM-DD", AmountColumn: ptr(1), SignConvention: SignNegativeIsOutflow,
		DescriptionColumns: []int{2}, CurrencyColumn: ptr(3)}
	for in, code := range map[string]string{
		",-5,x,INR":           "missing_date",
		"05/11/2025,-5,x,INR": "bad_date",
		"2025-11-05,abc,x,":   "bad_amount",
		"2025-11-05,0,x,":     "zero_amount",
		"2025-11-05,-5,x,USD": "currency_mismatch",
	} {
		_, e := Normalize(strings.Split(in, ","), m, "INR")
		if e == nil || e.Code != code {
			t.Errorf("%q → %v, want %s", in, e, code)
		}
	}
	both := ColumnMapping{HeaderRow: 0, DateColumn: 0, DateFormat: "YYYY-MM-DD", DebitColumn: ptr(1), CreditColumn: ptr(2)}
	if _, e := Normalize([]string{"2025-11-05", "5", "6"}, both, "INR"); e == nil || e.Code != "both_debit_credit" {
		t.Fatalf("both: %v", e)
	}
}

func ptr(i int) *int { return &i }

func codeOf(err error) string {
	var e *Error
	if errors.As(err, &e) {
		return e.Code
	}
	return ""
}

func xlsxFile(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for name, body := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := w.Write([]byte(body)); err != nil {
			t.Fatal(err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func sampleXLSX(t *testing.T) []byte {
	return xlsxFile(t, map[string]string{
		"xl/workbook.xml": `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">` +
			`<sheets><sheet name="Txns" sheetId="1" r:id="rId1"/></sheets></workbook>`,
		"xl/_rels/workbook.xml.rels": `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
			`<Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/></Relationships>`,
		"xl/sharedStrings.xml": `<sst><si><t>Date</t></si><si><t>Description</t></si><si><t>Amount</t></si><si><r><t>Tea </t></r><r><t>shop</t></r></si></sst>`,
		"xl/styles.xml":        `<styleSheet><cellXfs><xf numFmtId="0"/><xf numFmtId="14"/></cellXfs></styleSheet>`,
		"xl/worksheets/sheet1.xml": `<worksheet><sheetData>` +
			`<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c></row>` +
			`<row r="2"><c r="A2" s="1"><v>45962</v></c><c r="B2" t="s"><v>3</v></c><c r="C2"><f>-SUM(D2:E2)</f><v>-42.5</v></c></row>` +
			`<row r="3"><c r="A3" t="inlineStr"><is><t>2025-11-02</t></is></c><c r="C3"><v>100</v></c></row>` +
			`</sheetData></worksheet>`,
	})
}

func TestXLSXUsesCachedValuesAndDates(t *testing.T) {
	tb := mustParse(t, sampleXLSX(t), "xlsx")
	want := time.Date(1899, 12, 30, 0, 0, 0, 0, time.UTC).AddDate(0, 0, 45962).Format("2006-01-02")
	if tb.HeaderRow != 0 || tb.Rows[1][0] != want || tb.Rows[1][1] != "Tea shop" || tb.Rows[1][2] != "-42.5" || tb.Rows[2][1] != "" {
		t.Fatalf("rows = %v (want date %s)", tb.Rows, want)
	}
	sg := Suggest(tb)
	rows, bad := normalizeAll(t, tb, sg.Mapping, "INR")
	if len(bad) != 0 || rows[0].Row.AmountMinor != 4250 || rows[0].Row.Direction != "outflow" {
		t.Fatalf("xlsx rows = %+v bad = %v", rows, bad)
	}
	if _, err := Parse(sampleXLSX(t), "xlsx", Limits{MaxRows: 10, MaxColumns: 10, MaxCellRunes: 100, MaxXLSXUncompressed: 100}); err == nil ||
		codeOf(err) != "too_large" {
		t.Fatalf("zip expansion limit: %v", err)
	}
	if _, err := Parse([]byte("PK\x03\x04garbage"), "xlsx", DefaultLimits); err == nil || codeOf(err) != "malformed" {
		t.Fatalf("garbage xlsx: %v", err)
	}
}

const sampleOFX = `OFXHEADER:100
DATA:OFXSGML
VERSION:102

<OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><CURDEF>INR
<BANKTRANLIST><DTSTART>20251001<DTEND>20251031
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20251005120000[+5.5:IST]<TRNAMT>-499.00<FITID>FIT-1<NAME>STREAMING &amp; CO<MEMO>Monthly plan</STMTTRN>
<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20251007<TRNAMT>1200.50<FITID>FIT-2<NAME>REFUND</STMTTRN>
</BANKTRANLIST><LEDGERBAL><BALAMT>10701.50<DTASOF>20251031</LEDGERBAL></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>`

func TestOFXSGML(t *testing.T) {
	tb := mustParse(t, []byte(sampleOFX), "ofx")
	if len(tb.Rows) != 3 || tb.Statement.Currency != "INR" || tb.Statement.Start != "2025-10-01" || tb.Statement.ClosingBalance != "10701.50" {
		t.Fatalf("ofx = %v %+v", tb.Rows, tb.Statement)
	}
	sg := Suggest(tb)
	rows, bad := normalizeAll(t, tb, sg.Mapping, "INR")
	if len(bad) != 0 || rows[0].Row.Direction != "outflow" || rows[0].Row.AmountMinor != 49900 || rows[0].Row.ExternalID != "FIT-1" ||
		rows[0].Row.Description != "STREAMING & CO — Monthly plan" || rows[0].Row.Date != time.Date(2025, 10, 5, 0, 0, 0, 0, time.UTC) {
		t.Fatalf("ofx rows = %+v bad = %v", rows, bad)
	}
	if rows[1].Row.Direction != "inflow" || rows[1].Row.AmountMinor != 120050 {
		t.Fatalf("ofx credit = %+v", rows[1].Row)
	}
}

func TestLimitsAndUnsupported(t *testing.T) {
	big := "a,b\n" + strings.Repeat("1,2\n", 30)
	if _, err := Parse([]byte(big), "csv", Limits{MaxRows: 10, MaxColumns: 5, MaxCellRunes: 50, MaxXLSXUncompressed: 1 << 20}); err == nil ||
		codeOf(err) != "too_many_rows" {
		t.Fatalf("row limit: %v", err)
	}
	wide := strings.Repeat("x,", 100) + "x\n"
	if _, err := Parse([]byte(wide), "csv", DefaultLimits); err == nil || codeOf(err) != "too_many_columns" {
		t.Fatalf("column limit: %v", err)
	}
	if _, err := Parse([]byte("x"), "pdf", DefaultLimits); err == nil || codeOf(err) != "unsupported_format" {
		t.Fatalf("pdf: %v", err)
	}
	if _, err := Parse([]byte("  \n "), "csv", DefaultLimits); err == nil || codeOf(err) != "empty" {
		t.Fatalf("empty: %v", err)
	}
}

func TestSimilarity(t *testing.T) {
	if Similarity("UPI-GROCER-PAYMENT 123", "Grocer payment") < 600 || Similarity("Coffee", "Salary") != 0 {
		t.Fatal("similarity")
	}
}

func FuzzParseCSV(f *testing.F) {
	f.Add([]byte(bankCSV))
	f.Add([]byte("a;b\n\"x;y\";2\n"))
	f.Fuzz(func(t *testing.T, data []byte) {
		tb, err := Parse(data, "csv", Limits{MaxRows: 200, MaxColumns: 20, MaxCellRunes: 100, MaxXLSXUncompressed: 1 << 20})
		if err == nil {
			sg := Suggest(tb)
			for _, r := range tb.Rows {
				_, _ = Normalize(r, sg.Mapping, "INR")
			}
		}
	})
}

func FuzzParseAmount(f *testing.F) {
	for _, s := range []string{"1,234.56", "(9)", "12.500", "Rs.5", "1.234,5"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, s string) {
		for _, sep := range []string{".", ","} {
			if m, _, _, ok := ParseAmount(s, "INR", sep); ok && m < 0 {
				t.Fatalf("negative magnitude for %q", s)
			}
		}
	})
}

func FuzzParseXLSXAndOFX(f *testing.F) {
	f.Add([]byte(sampleOFX))
	f.Fuzz(func(t *testing.T, data []byte) {
		lim := Limits{MaxRows: 100, MaxColumns: 20, MaxCellRunes: 100, MaxXLSXUncompressed: 1 << 20}
		_, _ = Parse(data, "ofx", lim)
		_, _ = Parse(data, "xlsx", lim)
	})
}

func TestNotesAndRowErrorsCarryCodesAndParams(t *testing.T) {
	// Every date fits both day-first and month-first; amounts use a decimal comma.
	csv := "Date;Description;Amount;Currency\n01/02/2025;Bakery;-12,50;EUR\n03/04/2025;Tea;oops;EUR\n05/06/2025;Hotel;-80,00;USD\n"
	tb := mustParse(t, []byte(csv), "csv")
	sg := Suggest(tb)
	var codes []string
	for _, n := range sg.Notes {
		if n.Code == "" || n.Text == "" {
			t.Fatalf("note without code or text: %+v", n)
		}
		codes = append(codes, n.Code)
	}
	if strings.Join(codes, ",") != "ambiguous_date_order,decimal_comma,check_sign_convention" ||
		sg.Notes[0].Params["assumed_date_format"] != "DD/MM/YYYY" || sg.Notes[0].Params["alternative_date_format"] != "MM/DD/YYYY" {
		t.Fatalf("notes = %+v", sg.Notes)
	}
	_, bad := normalizeAll(t, tb, sg.Mapping, "EUR")
	if e := bad[3]; e == nil || e.Code != "bad_amount" || e.Params["currency"] != "EUR" {
		t.Fatalf("bad amount = %+v", e)
	}
	if e := bad[4]; e == nil || e.Code != "currency_mismatch" || e.Params["currency"] != "USD" || e.Params["account_currency"] != "EUR" {
		t.Fatalf("currency mismatch = %+v", e)
	}
	m := sg.Mapping
	m.DateFormat = "YYYY-MM-DD"
	if _, e := Normalize(tb.Rows[1], m, "EUR"); e == nil || e.Code != "bad_date" || e.Params["format"] != "YYYY-MM-DD" {
		t.Fatalf("bad date = %+v", e)
	}
	if sg := Suggest(&Table{HeaderRow: -1, Rows: [][]string{{"x"}}}); len(sg.Notes) != 1 || sg.Notes[0].Code != NoteNoHeaderRow {
		t.Fatalf("no header = %+v", sg.Notes)
	}
}
