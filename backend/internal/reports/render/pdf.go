package render

import (
	"bytes"
	"fmt"
	"io"
	"strings"
	"unicode/utf8"
)

// MaxPDFRows bounds PDF reports (larger exports should use CSV/XLSX).
const MaxPDFRows = 5000

const (
	pageW, pageH = 595.0, 842.0 // A4 in points
	margin       = 40.0
	bodySize     = 8.5
	lineH        = 11.5
)

// winAnsi maps a rune to a WinAnsiEncoding byte for the standard 14 fonts;
// unsupported characters become '?' and the rupee sign becomes "Rs".
func winAnsi(s string) string {
	var b strings.Builder
	for _, r := range s {
		switch {
		case r == '₹':
			b.WriteString("Rs")
		case r == '€':
			b.WriteByte(0x80)
		case r == '–' || r == '—':
			b.WriteByte('-')
		case r == '‘' || r == '’':
			b.WriteByte('\'')
		case r == '“' || r == '”':
			b.WriteByte('"')
		case r == '•':
			b.WriteByte(0x95)
		case r < 0x20:
			b.WriteByte(' ')
		case r < 0x7F || (r >= 0xA0 && r <= 0xFF):
			b.WriteByte(byte(r))
		default:
			b.WriteByte('?')
		}
	}
	return b.String()
}

func pdfEscape(s string) string {
	return strings.NewReplacer(`\`, `\\`, `(`, `\(`, `)`, `\)`).Replace(winAnsi(s))
}

// fit truncates text to roughly width points at the given size (Helvetica
// average glyph width ≈ 0.52 em).
func fit(s string, width, size float64) string {
	maxChars := int(width / (size * 0.52))
	if maxChars < 1 {
		return ""
	}
	if utf8.RuneCountInString(s) <= maxChars {
		return s
	}
	r := []rune(s)
	if maxChars <= 1 {
		return string(r[:maxChars])
	}
	return string(r[:maxChars-1]) + "…"
}

type pdfLine struct {
	font  string // F1 regular, F2 bold
	size  float64
	cells []string
	cols  []float64 // x offsets
	right []bool
}

// PDF writes a paginated A4 report with Helvetica text (no embedded fonts;
// characters outside Latin-1 are replaced).
func PDF(w io.Writer, d Document) error {
	if d.Rows() > MaxPDFRows {
		return fmt.Errorf("report has %d rows; PDF supports up to %d (use CSV or XLSX)", d.Rows(), MaxPDFRows)
	}
	var lines []pdfLine
	full := []float64{margin}
	lines = append(lines, pdfLine{font: "F2", size: 14, cells: []string{d.Title}, cols: full, right: []bool{false}})
	for _, m := range d.Meta {
		lines = append(lines, pdfLine{font: "F1", size: bodySize, cells: []string{m.Key + ": " + m.Value}, cols: full, right: []bool{false}})
	}
	usable := pageW - 2*margin
	for _, s := range d.Sections {
		lines = append(lines, pdfLine{size: bodySize}) // spacer
		lines = append(lines, pdfLine{font: "F2", size: 11, cells: []string{s.Title}, cols: full, right: []bool{false}})
		n := max(len(s.Columns), 1)
		cols := make([]float64, n)
		right := make([]bool, n)
		for i := range cols {
			cols[i] = margin + usable*float64(i)/float64(n)
			if i < len(s.Columns) {
				k := s.Columns[i].Kind
				right[i] = k == Money || k == Number || k == Percent
			}
		}
		head := make([]string, n)
		for i, c := range s.Columns {
			head[i] = c.Title
		}
		lines = append(lines, pdfLine{font: "F2", size: bodySize, cells: head, cols: cols, right: right})
		for _, r := range s.Rows {
			lines = append(lines, pdfLine{font: "F1", size: bodySize, cells: r, cols: cols, right: right})
		}
		for _, note := range s.Notes {
			lines = append(lines, pdfLine{font: "F1", size: bodySize, cells: []string{"Note: " + note}, cols: full, right: []bool{false}})
		}
	}
	usableH := pageH - 2*margin
	perPage := int(usableH / lineH)
	var pages []string
	for start := 0; start < len(lines); start += perPage {
		end := min(start+perPage, len(lines))
		var c strings.Builder
		y := pageH - margin
		for _, l := range lines[start:end] {
			y -= lineH
			for i, txt := range l.cells {
				if i >= len(l.cols) || txt == "" {
					continue
				}
				width := pageW - margin - l.cols[i]
				if i+1 < len(l.cols) {
					width = l.cols[i+1] - l.cols[i] - 6
				}
				t := fit(txt, width, l.size)
				x := l.cols[i]
				if i < len(l.right) && l.right[i] {
					x += width - float64(utf8.RuneCountInString(t))*l.size*0.52
				}
				fmt.Fprintf(&c, "BT /%s %.1f Tf %.2f %.2f Td (%s) Tj ET\n", l.font, l.size, x, y, pdfEscape(t))
			}
		}
		fmt.Fprintf(&c, "BT /F1 7 Tf %.2f %.2f Td (%s) Tj ET\n", margin, margin/2, pdfEscape(fmt.Sprintf("Page %d", len(pages)+1)))
		pages = append(pages, c.String())
	}
	var buf bytes.Buffer
	offsets := []int{}
	obj := func(body string) {
		offsets = append(offsets, buf.Len())
		fmt.Fprintf(&buf, "%d 0 obj\n%s\nendobj\n", len(offsets), body)
	}
	buf.WriteString("%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
	n := len(pages)
	// 1 catalog, 2 pages, 3 F1, 4 F2, then page/content pairs.
	obj("<< /Type /Catalog /Pages 2 0 R >>")
	kids := make([]string, n)
	for i := range pages {
		kids[i] = fmt.Sprintf("%d 0 R", 5+2*i)
	}
	obj(fmt.Sprintf("<< /Type /Pages /Kids [%s] /Count %d >>", strings.Join(kids, " "), n))
	obj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
	obj("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
	for i, content := range pages {
		obj(fmt.Sprintf("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.0f %.0f] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents %d 0 R >>",
			pageW, pageH, 6+2*i))
		obj(fmt.Sprintf("<< /Length %d >>\nstream\n%sendstream", len(content), content))
	}
	xref := buf.Len()
	fmt.Fprintf(&buf, "xref\n0 %d\n0000000000 65535 f \n", len(offsets)+1)
	for _, o := range offsets {
		fmt.Fprintf(&buf, "%010d 00000 n \n", o)
	}
	fmt.Fprintf(&buf, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(offsets)+1, xref)
	_, err := w.Write(buf.Bytes())
	return err
}
