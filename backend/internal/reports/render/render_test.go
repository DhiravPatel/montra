package render

import (
	"archive/zip"
	"bytes"
	"encoding/csv"
	"encoding/json"
	"io"
	"strings"
	"testing"

	"montra/backend/internal/domain/statement"
)

func sample() Document {
	return Document{Title: "Monthly summary", Meta: []KV{{"Period", "2026-10-01 – 2026-10-31"}, {"Timezone", "Asia/Kolkata"}},
		Sections: []Section{{Title: "Transactions", Columns: []Column{{"Date", Date}, {"Description", Text}, {"Amount", Money}, {"Currency", Text}},
			Rows: [][]string{{"2026-10-02", "=HYPERLINK(\"http://evil\")", "-120.50", "INR"}, {"2026-10-03", "Café ₹ (special)", "75000.00", "INR"},
				{"2026-10-04", "@SUM(A1)", "1.5", "EUR"}}, Notes: []string{"Transfers excluded."}}}}
}

func TestSafeCell(t *testing.T) {
	for in, want := range map[string]string{"=1+1": "'=1+1", "+cmd": "'+cmd", "-120.50": "-120.50", "-x": "'-x", "@a": "'@a", "\tx": "'\tx",
		"normal": "normal", "": ""} {
		if got := SafeCell(in); got != want {
			t.Errorf("SafeCell(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestCSVIsFormulaSafeAndComplete(t *testing.T) {
	var b bytes.Buffer
	if err := CSV(&b, sample()); err != nil {
		t.Fatal(err)
	}
	raw := b.Bytes()
	if !bytes.HasPrefix(raw, []byte{0xEF, 0xBB, 0xBF}) {
		t.Fatal("missing BOM")
	}
	r := csv.NewReader(bytes.NewReader(raw[3:]))
	r.FieldsPerRecord = -1 // sections have different widths
	recs, err := r.ReadAll()
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(func() []string {
		var out []string
		for _, r := range recs {
			out = append(out, strings.Join(r, "|"))
		}
		return out
	}(), "\n")
	for _, want := range []string{"Report|Monthly summary", "Timezone|Asia/Kolkata", "'=HYPERLINK", "|-120.50|", "'@SUM(A1)", "Note|Transfers excluded."} {
		if !strings.Contains(joined, want) {
			t.Errorf("CSV lacks %q:\n%s", want, joined)
		}
	}
}

func TestXLSXIsReadableAndNeverWritesFormulas(t *testing.T) {
	var b bytes.Buffer
	if err := XLSX(&b, sample()); err != nil {
		t.Fatal(err)
	}
	// Round-trip through the import parser (cached values only).
	tb, err := statement.Parse(b.Bytes(), "xlsx", statement.DefaultLimits)
	if err != nil {
		t.Fatalf("generated workbook unreadable: %v", err)
	}
	if tb.Rows[0][0] != "Monthly summary" || tb.Rows[2][1] != "Asia/Kolkata" {
		t.Fatalf("summary sheet = %v", tb.Rows)
	}
	zr, _ := zip.NewReader(bytes.NewReader(b.Bytes()), int64(b.Len()))
	for _, f := range zr.File {
		rc, _ := f.Open()
		body, _ := io.ReadAll(rc)
		_ = rc.Close()
		if strings.Contains(string(body), "<f>") {
			t.Fatalf("%s contains a formula", f.Name)
		}
		if f.Name == "xl/worksheets/sheet2.xml" && (!strings.Contains(string(body), `<v>-120.50</v>`) || !strings.Contains(string(body), "=HYPERLINK")) {
			t.Fatalf("sheet2 = %s", body)
		}
	}
}

func TestPDFStructure(t *testing.T) {
	var b bytes.Buffer
	if err := PDF(&b, sample()); err != nil {
		t.Fatal(err)
	}
	s := b.String()
	if !strings.HasPrefix(s, "%PDF-1.4") || !strings.HasSuffix(s, "%%EOF\n") || !strings.Contains(s, "/Count 1") ||
		!strings.Contains(s, `Caf`) || !strings.Contains(s, `Rs \(special\)`) {
		t.Fatalf("pdf = %q", s[:min(len(s), 400)])
	}
	big := Document{Title: "Big", Sections: []Section{{Title: "Rows", Columns: []Column{{"N", Number}}}}}
	for i := 0; i < 200; i++ {
		big.Sections[0].Rows = append(big.Sections[0].Rows, []string{"1"})
	}
	b.Reset()
	if err := PDF(&b, big); err != nil || !strings.Contains(b.String(), "/Count 4") {
		t.Fatalf("pagination: %v", err)
	}
	big.Sections[0].Rows = make([][]string, MaxPDFRows+1)
	if err := PDF(io.Discard, big); err == nil {
		t.Fatal("oversized PDF accepted")
	}
}

func TestJSON(t *testing.T) {
	var b bytes.Buffer
	if err := JSON(&b, sample()); err != nil {
		t.Fatal(err)
	}
	var back Document
	if err := json.Unmarshal(b.Bytes(), &back); err != nil || back.Rows() != 3 || back.Sections[0].Columns[2].Kind != Money {
		t.Fatalf("json round trip: %v %+v", err, back)
	}
}
