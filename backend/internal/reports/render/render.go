// Package render writes report documents as CSV, XLSX, PDF or JSON (spec
// §4.11, §20B.12). Untrusted text is escaped for every format: CSV cells
// that could start a spreadsheet formula are prefixed with an apostrophe,
// XLSX text is always written as inline strings (never formulas), and PDF
// text is escaped and limited to the standard font's character set.
package render

import (
	"archive/zip"
	"bytes"
	"encoding/csv"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf8"
)

// Column kinds.
const (
	Text    = "text"
	Money   = "money" // decimal string; a separate currency column carries the code
	Number  = "number"
	Date    = "date"
	Percent = "percent" // decimal percentage string, e.g. "12.50"
)

// Column describes one column.
type Column struct {
	Title string `json:"title"`
	Kind  string `json:"kind"`
}

// Section is a titled table.
type Section struct {
	Title   string     `json:"title"`
	Columns []Column   `json:"columns"`
	Rows    [][]string `json:"rows"`
	Notes   []string   `json:"notes,omitempty"`
}

// KV is a metadata entry.
type KV struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

// Document is a complete report.
type Document struct {
	Title    string    `json:"title"`
	Meta     []KV      `json:"meta"`
	Sections []Section `json:"sections"`
}

// Rows counts data rows across sections.
func (d Document) Rows() int {
	n := 0
	for _, s := range d.Sections {
		n += len(s.Rows)
	}
	return n
}

var plainNumber = regexp.MustCompile(`^-?\d+(\.\d+)?$`)

// SafeCell neutralizes spreadsheet formula injection (OWASP): text that
// starts with = + - @ tab or CR is prefixed with an apostrophe, except
// plain numbers.
func SafeCell(s string) string {
	if s == "" || plainNumber.MatchString(s) {
		return s
	}
	switch s[0] {
	case '=', '+', '-', '@', '\t', '\r':
		return "'" + s
	}
	return s
}

// CSV writes UTF-8 CSV with a BOM (for spreadsheet apps) and formula-safe
// cells: metadata, then each section with its header.
func CSV(w io.Writer, d Document) error {
	if _, err := w.Write([]byte{0xEF, 0xBB, 0xBF}); err != nil {
		return err
	}
	cw := csv.NewWriter(w)
	write := func(rec ...string) error {
		for i := range rec {
			rec[i] = SafeCell(rec[i])
		}
		return cw.Write(rec)
	}
	if err := write("Report", d.Title); err != nil {
		return err
	}
	for _, m := range d.Meta {
		if err := write(m.Key, m.Value); err != nil {
			return err
		}
	}
	for _, s := range d.Sections {
		if err := cw.Write(nil); err != nil {
			return err
		}
		if err := write(s.Title); err != nil {
			return err
		}
		head := make([]string, len(s.Columns))
		for i, c := range s.Columns {
			head[i] = c.Title
		}
		if err := write(head...); err != nil {
			return err
		}
		for _, r := range s.Rows {
			if err := write(append([]string(nil), r...)...); err != nil {
				return err
			}
		}
		for _, n := range s.Notes {
			if err := write("Note", n); err != nil {
				return err
			}
		}
	}
	cw.Flush()
	return cw.Error()
}

// JSON writes the document as JSON.
func JSON(w io.Writer, d Document) error {
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	return enc.Encode(d)
}

// xmlText escapes text and drops characters XML 1.0 forbids.
func xmlText(s string) string {
	var b strings.Builder
	for _, r := range s {
		if r == '\t' || r == '\n' || r == '\r' || (r >= 0x20 && r <= 0xD7FF) || (r >= 0xE000 && r <= 0xFFFD) || (r >= 0x10000 && r <= 0x10FFFF) {
			b.WriteRune(r)
		}
	}
	var out bytes.Buffer
	_ = xml.EscapeText(&out, []byte(b.String()))
	return out.String()
}

func colName(i int) string {
	name := ""
	for i++; i > 0; i = (i - 1) / 26 {
		name = string(rune('A'+(i-1)%26)) + name
	}
	return name
}

var sheetBad = regexp.MustCompile(`[\[\]:*?/\\]`)

func sheetName(title string, used map[string]bool) string {
	n := strings.TrimSpace(sheetBad.ReplaceAllString(title, " "))
	if n == "" {
		n = "Sheet"
	}
	if utf8.RuneCountInString(n) > 28 {
		n = string([]rune(n)[:28])
	}
	base, i := n, 2
	for used[strings.ToLower(n)] {
		n = fmt.Sprintf("%s %d", base, i)
		i++
	}
	used[strings.ToLower(n)] = true
	return n
}

// XLSX writes an Office Open XML workbook: a Summary sheet with metadata
// and one sheet per section. Text is stored as inline strings; money and
// number columns holding plain decimals are numeric cells.
func XLSX(w io.Writer, d Document) error {
	zw := zip.NewWriter(w)
	add := func(name, body string) error {
		f, err := zw.Create(name)
		if err != nil {
			return err
		}
		_, err = io.WriteString(f, body)
		return err
	}
	used := map[string]bool{}
	type sheet struct {
		name string
		rows [][]cell
	}
	summary := sheet{name: sheetName("Summary", used), rows: [][]cell{{{v: d.Title, bold: true}}}}
	for _, m := range d.Meta {
		summary.rows = append(summary.rows, []cell{{v: m.Key, bold: true}, {v: m.Value}})
	}
	sheets := []sheet{summary}
	for _, s := range d.Sections {
		sh := sheet{name: sheetName(s.Title, used)}
		head := make([]cell, len(s.Columns))
		for i, c := range s.Columns {
			head[i] = cell{v: c.Title, bold: true}
		}
		sh.rows = append(sh.rows, head)
		for _, r := range s.Rows {
			row := make([]cell, len(r))
			for i, v := range r {
				numeric := i < len(s.Columns) && (s.Columns[i].Kind == Money || s.Columns[i].Kind == Number || s.Columns[i].Kind == Percent) &&
					plainNumber.MatchString(v)
				row[i] = cell{v: v, number: numeric}
			}
			sh.rows = append(sh.rows, row)
		}
		for _, n := range s.Notes {
			sh.rows = append(sh.rows, []cell{{v: "Note", bold: true}, {v: n}})
		}
		sheets = append(sheets, sh)
	}
	var ct, wb, rels strings.Builder
	ct.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
		`<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>` +
		`<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>` +
		`<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>`)
	wb.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ` +
		`xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>`)
	rels.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">`)
	for i, sh := range sheets {
		n := i + 1
		fmt.Fprintf(&ct, `<Override PartName="/xl/worksheets/sheet%d.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`, n)
		fmt.Fprintf(&wb, `<sheet name="%s" sheetId="%d" r:id="rId%d"/>`, xmlText(sh.name), n, n)
		fmt.Fprintf(&rels, `<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet%d.xml"/>`, n, n)
		var sx strings.Builder
		sx.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>`)
		for ri, row := range sh.rows {
			fmt.Fprintf(&sx, `<row r="%d">`, ri+1)
			for ci, c := range row {
				ref := colName(ci) + strconv.Itoa(ri+1)
				style := ""
				if c.bold {
					style = ` s="1"`
				}
				if c.number {
					fmt.Fprintf(&sx, `<c r="%s"%s><v>%s</v></c>`, ref, style, c.v)
				} else {
					fmt.Fprintf(&sx, `<c r="%s" t="inlineStr"%s><is><t xml:space="preserve">%s</t></is></c>`, ref, style, xmlText(c.v))
				}
			}
			sx.WriteString(`</row>`)
		}
		sx.WriteString(`</sheetData></worksheet>`)
		if err := add(fmt.Sprintf("xl/worksheets/sheet%d.xml", n), sx.String()); err != nil {
			return err
		}
	}
	ct.WriteString(`</Types>`)
	wb.WriteString(`</sheets></workbook>`)
	fmt.Fprintf(&rels, `<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>`, len(sheets)+1)
	rels.WriteString(`</Relationships>`)
	parts := map[string]string{
		"[Content_Types].xml": ct.String(),
		"_rels/.rels": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
			`<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
		"xl/workbook.xml":            wb.String(),
		"xl/_rels/workbook.xml.rels": rels.String(),
		"xl/styles.xml": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">` +
			`<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>` +
			`<fills count="1"><fill><patternFill patternType="none"/></fill></fills><borders count="1"><border/></borders>` +
			`<cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="2"><xf fontId="0"/><xf fontId="1" applyFont="1"/></cellXfs></styleSheet>`,
	}
	for _, name := range []string{"[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels", "xl/styles.xml"} {
		if err := add(name, parts[name]); err != nil {
			return err
		}
	}
	return zw.Close()
}

type cell struct {
	v      string
	bold   bool
	number bool
}
