// Package statement parses untrusted bank statement files (CSV, XLSX,
// OFX/QFX) into plain text tables and normalizes mapped rows (spec §4.10,
// §20B.11). It is pure: no I/O beyond the byte slice it is given, strict
// size limits, and spreadsheet formulas are never evaluated (only cached
// cell values are read).
package statement

import (
	"bytes"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"strings"
	"unicode/utf16"
	"unicode/utf8"
)

// Parser versions (stored on each import batch).
const (
	CSVParserVersion  = "csv-1"
	XLSXParserVersion = "xlsx-1"
	OFXParserVersion  = "ofx-1"
)

// Limits bound the work done on an untrusted file.
type Limits struct {
	MaxRows             int
	MaxColumns          int
	MaxCellRunes        int
	MaxXLSXUncompressed int64
}

// DefaultLimits are used by the import worker.
var DefaultLimits = Limits{MaxRows: 20000, MaxColumns: 64, MaxCellRunes: 1000, MaxXLSXUncompressed: 64 << 20}

// Error is a user-facing parse failure.
type Error struct {
	Code    string // unsupported_format | too_large | too_many_rows | too_many_columns | malformed | empty
	Message string
}

func (e *Error) Error() string { return e.Code + ": " + e.Message }

func fail(code, format string, a ...any) error {
	return &Error{Code: code, Message: fmt.Sprintf(format, a...)}
}

// Table is a parsed file: text rows plus format metadata.
type Table struct {
	Format        string // csv | xlsx | ofx
	ParserVersion string
	Encoding      string // utf-8 | utf-8-bom | utf-16le | utf-16be | windows-1252 (csv)
	Delimiter     string // csv only
	Rows          [][]string
	Source        []int // 1-based source line (CSV), sheet row (XLSX) or record number (OFX) of each row
	HeaderRow     int   // index into Rows of the detected header row, -1 when none
	Statement     *StatementInfo
}

// StatementInfo carries statement-level facts when the format provides them.
type StatementInfo struct {
	Currency       string
	Start, End     string // YYYY-MM-DD
	ClosingBalance string // decimal text
	ClosingAsOf    string
}

// Parse dispatches on format ("csv", "xlsx" or "ofx").
func Parse(data []byte, format string, lim Limits) (*Table, error) {
	if len(bytes.TrimSpace(data)) == 0 {
		return nil, fail("empty", "The file is empty.")
	}
	var t *Table
	var err error
	switch format {
	case "csv":
		t, err = parseCSV(data, lim)
	case "xlsx":
		t, err = parseXLSX(data, lim)
	case "ofx":
		t, err = parseOFX(data, lim)
	default:
		return nil, fail("unsupported_format", "This file type cannot be imported. Use CSV, XLSX or OFX/QFX.")
	}
	if err != nil {
		return nil, err
	}
	if len(t.Rows) == 0 {
		return nil, fail("empty", "No rows were found in the file.")
	}
	if t.Format != "ofx" {
		t.HeaderRow = DetectHeader(t.Rows)
	}
	return t, nil
}

// Decode converts statement text to UTF-8, reporting the encoding found.
func Decode(data []byte) (string, string) {
	switch {
	case bytes.HasPrefix(data, []byte{0xEF, 0xBB, 0xBF}):
		return string(data[3:]), "utf-8-bom"
	case bytes.HasPrefix(data, []byte{0xFF, 0xFE}):
		return decodeUTF16(data[2:], false), "utf-16le"
	case bytes.HasPrefix(data, []byte{0xFE, 0xFF}):
		return decodeUTF16(data[2:], true), "utf-16be"
	case utf8.Valid(data):
		return string(data), "utf-8"
	}
	return decodeWindows1252(data), "windows-1252"
}

func decodeUTF16(b []byte, bigEndian bool) string {
	u := make([]uint16, 0, len(b)/2)
	for i := 0; i+1 < len(b); i += 2 {
		if bigEndian {
			u = append(u, uint16(b[i])<<8|uint16(b[i+1]))
		} else {
			u = append(u, uint16(b[i+1])<<8|uint16(b[i]))
		}
	}
	return string(utf16.Decode(u))
}

// cp1252 maps 0x80–0x9F; other bytes equal their Latin-1 code points.
var cp1252 = [32]rune{'€', '�', '‚', 'ƒ', '„', '…', '†', '‡', 'ˆ', '‰', 'Š', '‹', 'Œ', '�', 'Ž', '�',
	'�', '‘', '’', '“', '”', '•', '–', '—', '˜', '™', 'š', '›', 'œ', '�', 'ž', 'Ÿ'}

func decodeWindows1252(b []byte) string {
	var sb strings.Builder
	sb.Grow(len(b))
	for _, c := range b {
		switch {
		case c < 0x80:
			sb.WriteByte(c)
		case c < 0xA0:
			sb.WriteRune(cp1252[c-0x80])
		default:
			sb.WriteRune(rune(c))
		}
	}
	return sb.String()
}

// sniffDelimiter picks the delimiter with the most consistent per-line count.
func sniffDelimiter(text string) rune {
	lines := strings.Split(text, "\n")
	if len(lines) > 25 {
		lines = lines[:25]
	}
	best, bestScore := ',', -1
	for _, d := range []rune{',', ';', '\t', '|'} {
		counts := map[int]int{}
		for _, l := range lines {
			if strings.TrimSpace(l) == "" {
				continue
			}
			n, inQuote := 0, false
			for _, r := range l {
				switch {
				case r == '"':
					inQuote = !inQuote
				case r == d && !inQuote:
					n++
				}
			}
			if n > 0 {
				counts[n]++
			}
		}
		// Score: lines sharing the most common non-zero count.
		top := 0
		for _, c := range counts {
			top = max(top, c)
		}
		if top > bestScore {
			best, bestScore = d, top
		}
	}
	return best
}

func parseCSV(data []byte, lim Limits) (*Table, error) {
	text, enc := Decode(data)
	delim := sniffDelimiter(text)
	r := csv.NewReader(strings.NewReader(text))
	r.Comma = delim
	r.FieldsPerRecord = -1
	r.LazyQuotes = true
	r.TrimLeadingSpace = true
	t := &Table{Format: "csv", ParserVersion: CSVParserVersion, Encoding: enc, Delimiter: string(delim)}
	for {
		rec, err := r.Read()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			var pe *csv.ParseError
			if errors.As(err, &pe) {
				return nil, fail("malformed", "Line %d could not be read (%s).", pe.Line, pe.Err)
			}
			return nil, fail("malformed", "The file could not be read as CSV.")
		}
		line, _ := r.FieldPos(0)
		if err := addRow(t, rec, line, lim); err != nil {
			return nil, err
		}
	}
	return t, nil
}

// addRow trims cells, skips blank rows and enforces limits; source is the
// row's position in the original file (shown to users).
func addRow(t *Table, rec []string, source int, lim Limits) error {
	blank := true
	cells := make([]string, len(rec))
	for i, c := range rec {
		c = strings.TrimSpace(strings.ReplaceAll(c, " ", " "))
		if utf8.RuneCountInString(c) > lim.MaxCellRunes {
			c = string([]rune(c)[:lim.MaxCellRunes])
		}
		cells[i] = c
		if c != "" {
			blank = false
		}
	}
	if blank {
		return nil
	}
	// Trailing empty cells are not columns.
	for len(cells) > 0 && cells[len(cells)-1] == "" {
		cells = cells[:len(cells)-1]
	}
	if len(cells) > lim.MaxColumns {
		return fail("too_many_columns", "Rows may have at most %d columns.", lim.MaxColumns)
	}
	if len(t.Rows) >= lim.MaxRows {
		return fail("too_many_rows", "Files may have at most %d rows; split the statement into smaller periods.", lim.MaxRows)
	}
	t.Rows = append(t.Rows, cells)
	t.Source = append(t.Source, source)
	return nil
}

// headerWords are column names commonly used by bank statements.
var headerWords = []string{"date", "txn date", "transaction date", "value date", "posting date", "amount", "debit", "credit",
	"withdrawal", "deposit", "description", "narration", "particulars", "details", "remarks", "reference", "ref", "chq",
	"cheque", "balance", "currency", "type", "dr", "cr", "payee", "memo", "merchant"}

// DetectHeader returns the index of the first row (within the first 30)
// that looks like a header, or -1.
func DetectHeader(rows [][]string) int {
	for i := 0; i < len(rows) && i < 30; i++ {
		hits := 0
		for _, c := range rows[i] {
			lc := strings.ToLower(strings.TrimSpace(c))
			if lc == "" || looksNumeric(lc) {
				continue
			}
			for _, w := range headerWords {
				if lc == w || strings.HasPrefix(lc, w+" ") || strings.HasSuffix(lc, " "+w) || strings.Contains(lc, w+"(") ||
					strings.Contains(lc, " "+w+" ") || strings.HasPrefix(lc, w+".") || strings.HasPrefix(lc, w+"/") {
					hits++
					break
				}
			}
		}
		if hits >= 2 {
			return i
		}
	}
	return -1
}

func looksNumeric(s string) bool {
	digits := 0
	for _, r := range s {
		switch {
		case r >= '0' && r <= '9':
			digits++
		case strings.ContainsRune(".,-+()/ ₹$€£", r):
		default:
			return false
		}
	}
	return digits > 0
}
