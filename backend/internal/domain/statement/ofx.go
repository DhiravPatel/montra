package statement

import (
	"regexp"
	"strings"
)

// OFXHeader is the fixed column order produced for OFX/QFX statements.
var OFXHeader = []string{"date", "amount", "description", "memo", "reference", "type", "fitid"}

var (
	ofxTxnRe = regexp.MustCompile(`(?is)<STMTTRN>(.*?)</STMTTRN>`)
	ofxTagRe = regexp.MustCompile(`(?i)<([A-Z0-9.]+)>([^<\r\n]*)`)
)

// ofxFields reads SGML-style (unclosed) or XML tags from a block.
func ofxFields(block string) map[string]string {
	out := map[string]string{}
	for _, m := range ofxTagRe.FindAllStringSubmatch(block, -1) {
		k := strings.ToUpper(m[1])
		if _, seen := out[k]; !seen {
			out[k] = strings.TrimSpace(decodeOFXEntities(m[2]))
		}
	}
	return out
}

func decodeOFXEntities(s string) string {
	return strings.NewReplacer("&amp;", "&", "&lt;", "<", "&gt;", ">", "&quot;", `"`, "&apos;", "'", "&nbsp;", " ").Replace(s)
}

// ofxDate keeps the YYYYMMDD part of an OFX datetime as YYYY-MM-DD.
func ofxDate(v string) string {
	d := strings.TrimSpace(v)
	if len(d) < 8 {
		return d
	}
	for _, r := range d[:8] {
		if r < '0' || r > '9' {
			return d
		}
	}
	return d[0:4] + "-" + d[4:6] + "-" + d[6:8]
}

// parseOFX extracts STMTTRN records (bank and credit-card statements) from
// OFX 1.x SGML or OFX 2.x XML. Signed amounts: negative = money out.
func parseOFX(data []byte, lim Limits) (*Table, error) {
	text, _ := Decode(data)
	upper := strings.ToUpper(text)
	if !strings.Contains(upper, "<OFX>") {
		return nil, fail("malformed", "This is not an OFX/QFX statement.")
	}
	t := &Table{Format: "ofx", ParserVersion: OFXParserVersion, Encoding: "utf-8", HeaderRow: 0}
	t.Rows = append(t.Rows, OFXHeader)
	t.Source = append(t.Source, 0)
	blocks := ofxTxnRe.FindAllStringSubmatch(text, -1)
	if len(blocks) == 0 {
		return nil, fail("empty", "The statement has no transactions.")
	}
	for _, b := range blocks {
		f := ofxFields(b[1])
		desc := f["NAME"]
		if desc == "" {
			desc = f["PAYEE"]
		}
		ref := f["CHECKNUM"]
		if ref == "" {
			ref = f["REFNUM"]
		}
		row := []string{ofxDate(f["DTPOSTED"]), strings.ReplaceAll(f["TRNAMT"], ",", "."), desc, f["MEMO"], ref, f["TRNTYPE"], f["FITID"]}
		if len(t.Rows) > lim.MaxRows {
			return nil, fail("too_many_rows", "Statements may have at most %d transactions.", lim.MaxRows)
		}
		for i, c := range row {
			if len([]rune(c)) > lim.MaxCellRunes {
				row[i] = string([]rune(c)[:lim.MaxCellRunes])
			}
		}
		t.Rows = append(t.Rows, row)
		t.Source = append(t.Source, len(t.Rows)-1)
	}
	head := ofxFields(ofxTxnRe.ReplaceAllString(text, ""))
	info := &StatementInfo{Currency: strings.ToUpper(head["CURDEF"]), Start: ofxDate(head["DTSTART"]), End: ofxDate(head["DTEND"])}
	if i := strings.Index(upper, "<LEDGERBAL>"); i >= 0 {
		lb := ofxFields(text[i:min(len(text), i+400)])
		info.ClosingBalance, info.ClosingAsOf = strings.ReplaceAll(lb["BALAMT"], ",", "."), ofxDate(lb["DTASOF"])
	}
	t.Statement = info
	return t, nil
}

// OFXMapping is the mapping for OFX tables (signed amount column).
func OFXMapping() ColumnMapping {
	ref, fit := 4, 6
	amt := 1
	return ColumnMapping{HeaderRow: 0, DateColumn: 0, DateFormat: "YYYY-MM-DD", AmountColumn: &amt, SignConvention: SignNegativeIsOutflow,
		DecimalSeparator: ".", DescriptionColumns: []int{2, 3}, ReferenceColumn: &ref, ExternalIDColumn: &fit}
}
