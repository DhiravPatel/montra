package statement

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"errors"
	"io"
	"path"
	"strconv"
	"strings"
	"time"
)

// parseXLSX reads the first worksheet of an Office Open XML workbook using
// cached cell values only (formulas are never evaluated). Total
// uncompressed size is bounded to defeat zip bombs.
func parseXLSX(data []byte, lim Limits) (*Table, error) {
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return nil, fail("malformed", "The spreadsheet could not be opened.")
	}
	var total uint64
	files := map[string]*zip.File{}
	for _, f := range zr.File {
		total += f.UncompressedSize64
		if total > uint64(lim.MaxXLSXUncompressed) {
			return nil, fail("too_large", "The spreadsheet expands to more data than allowed.")
		}
		files[path.Clean(f.Name)] = f
	}
	read := func(name string) ([]byte, error) {
		f, ok := files[name]
		if !ok {
			return nil, errNotFound
		}
		rc, err := f.Open()
		if err != nil {
			return nil, err
		}
		defer func() { _ = rc.Close() }()
		return io.ReadAll(io.LimitReader(rc, lim.MaxXLSXUncompressed))
	}
	sheet, date1904, err := firstSheet(read)
	if err != nil {
		return nil, err
	}
	shared, err := sharedStrings(read, lim)
	if err != nil {
		return nil, err
	}
	dateStyles, err := dateStyleSet(read)
	if err != nil {
		return nil, err
	}
	raw, err := read(sheet)
	if err != nil {
		return nil, fail("malformed", "The first worksheet could not be read.")
	}
	t := &Table{Format: "xlsx", ParserVersion: XLSXParserVersion, Encoding: "utf-8"}
	dec := xml.NewDecoder(bytes.NewReader(raw))
	var row []string
	var inRow bool
	rowNum := 0
	for {
		tok, err := dec.Token()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, fail("malformed", "The worksheet XML is malformed.")
		}
		switch el := tok.(type) {
		case xml.StartElement:
			switch el.Name.Local {
			case "row":
				row, inRow = nil, true
				rowNum++
				for _, a := range el.Attr {
					if a.Name.Local == "r" {
						if n, err := strconv.Atoi(a.Value); err == nil && n > 0 {
							rowNum = n
						}
					}
				}
			case "c":
				if !inRow {
					continue
				}
				var c xlsxCell
				if err := dec.DecodeElement(&c, &el); err != nil {
					return nil, fail("malformed", "A worksheet cell is malformed.")
				}
				col := columnIndex(c.Ref)
				if col < 0 {
					col = len(row)
				}
				if col >= lim.MaxColumns {
					return nil, fail("too_many_columns", "Rows may have at most %d columns.", lim.MaxColumns)
				}
				for len(row) <= col {
					row = append(row, "")
				}
				row[col] = c.value(shared, dateStyles, date1904)
			}
		case xml.EndElement:
			if el.Name.Local == "row" && inRow {
				inRow = false
				if err := addRow(t, row, rowNum, lim); err != nil {
					return nil, err
				}
			}
		}
	}
	return t, nil
}

var errNotFound = errors.New("not found")

type xlsxCell struct {
	Ref   string `xml:"r,attr"`
	Type  string `xml:"t,attr"`
	Style string `xml:"s,attr"`
	V     string `xml:"v"`
	IS    struct {
		T string `xml:"t"`
		R []struct {
			T string `xml:"t"`
		} `xml:"r"`
	} `xml:"is"`
}

func (c xlsxCell) value(shared []string, dateStyles map[int]bool, date1904 bool) string {
	switch c.Type {
	case "s":
		i, err := strconv.Atoi(strings.TrimSpace(c.V))
		if err != nil || i < 0 || i >= len(shared) {
			return ""
		}
		return shared[i]
	case "inlineStr":
		if c.IS.T != "" {
			return c.IS.T
		}
		var sb strings.Builder
		for _, r := range c.IS.R {
			sb.WriteString(r.T)
		}
		return sb.String()
	case "str", "e":
		return c.V // cached formula result / error text; formulas themselves are ignored
	case "b":
		if c.V == "1" {
			return "TRUE"
		}
		return "FALSE"
	}
	v := strings.TrimSpace(c.V)
	if v == "" {
		return ""
	}
	if s, err := strconv.Atoi(c.Style); err == nil && dateStyles[s] {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return excelDate(f, date1904)
		}
	}
	return v
}

// excelDate converts a serial date (1900 or 1904 system) to YYYY-MM-DD.
func excelDate(serial float64, date1904 bool) string {
	days := int(serial)
	if date1904 {
		return time.Date(1904, 1, 1, 0, 0, 0, 0, time.UTC).AddDate(0, 0, days).Format("2006-01-02")
	}
	// 1899-12-30 base absorbs Excel's fictitious 1900-02-29 for serials > 60.
	return time.Date(1899, 12, 30, 0, 0, 0, 0, time.UTC).AddDate(0, 0, days).Format("2006-01-02")
}

// columnIndex turns "AB12" into 27 (0-based), or -1.
func columnIndex(ref string) int {
	n := 0
	seen := false
	for _, r := range ref {
		if r >= 'A' && r <= 'Z' {
			n = n*26 + int(r-'A'+1)
			seen = true
			continue
		}
		break
	}
	if !seen {
		return -1
	}
	return n - 1
}

func firstSheet(read func(string) ([]byte, error)) (string, bool, error) {
	wb, err := read("xl/workbook.xml")
	if err != nil {
		return "", false, fail("malformed", "This is not an Excel workbook.")
	}
	var w struct {
		Pr struct {
			Date1904 string `xml:"date1904,attr"`
		} `xml:"workbookPr"`
		Sheets []struct {
			RID string `xml:"http://schemas.openxmlformats.org/officeDocument/2006/relationships id,attr"`
		} `xml:"sheets>sheet"`
	}
	if err := xml.Unmarshal(wb, &w); err != nil || len(w.Sheets) == 0 {
		return "", false, fail("malformed", "The workbook has no worksheets.")
	}
	date1904 := w.Pr.Date1904 == "1" || strings.EqualFold(w.Pr.Date1904, "true")
	rels, err := read("xl/_rels/workbook.xml.rels")
	if err == nil {
		var r struct {
			Rels []struct {
				ID     string `xml:"Id,attr"`
				Target string `xml:"Target,attr"`
			} `xml:"Relationship"`
		}
		if xml.Unmarshal(rels, &r) == nil {
			for _, rel := range r.Rels {
				if rel.ID == w.Sheets[0].RID {
					target := strings.TrimPrefix(rel.Target, "/")
					if !strings.HasPrefix(target, "xl/") {
						target = "xl/" + target
					}
					return path.Clean(target), date1904, nil
				}
			}
		}
	}
	return "xl/worksheets/sheet1.xml", date1904, nil
}

func sharedStrings(read func(string) ([]byte, error), lim Limits) ([]string, error) {
	raw, err := read("xl/sharedStrings.xml")
	if errors.Is(err, errNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, fail("malformed", "Shared strings could not be read.")
	}
	var sst struct {
		SI []struct {
			T string `xml:"t"`
			R []struct {
				T string `xml:"t"`
			} `xml:"r"`
		} `xml:"si"`
	}
	if err := xml.Unmarshal(raw, &sst); err != nil {
		return nil, fail("malformed", "Shared strings are malformed.")
	}
	out := make([]string, 0, len(sst.SI))
	for _, si := range sst.SI {
		s := si.T
		if s == "" && len(si.R) > 0 {
			var sb strings.Builder
			for _, r := range si.R {
				sb.WriteString(r.T)
			}
			s = sb.String()
		}
		if len([]rune(s)) > lim.MaxCellRunes {
			s = string([]rune(s)[:lim.MaxCellRunes])
		}
		out = append(out, s)
	}
	return out, nil
}

// dateStyleSet returns cell style indexes whose number format is a date.
func dateStyleSet(read func(string) ([]byte, error)) (map[int]bool, error) {
	raw, err := read("xl/styles.xml")
	if errors.Is(err, errNotFound) {
		return map[int]bool{}, nil
	}
	if err != nil {
		return nil, fail("malformed", "Styles could not be read.")
	}
	var st struct {
		NumFmts []struct {
			ID   int    `xml:"numFmtId,attr"`
			Code string `xml:"formatCode,attr"`
		} `xml:"numFmts>numFmt"`
		Xfs []struct {
			NumFmtID int `xml:"numFmtId,attr"`
		} `xml:"cellXfs>xf"`
	}
	if err := xml.Unmarshal(raw, &st); err != nil {
		return nil, fail("malformed", "Styles are malformed.")
	}
	custom := map[int]bool{}
	for _, f := range st.NumFmts {
		custom[f.ID] = isDateFormat(f.Code)
	}
	out := map[int]bool{}
	for i, xf := range st.Xfs {
		id := xf.NumFmtID
		if (id >= 14 && id <= 22) || (id >= 45 && id <= 47) || custom[id] {
			out[i] = true
		}
	}
	return out, nil
}

func isDateFormat(code string) bool {
	// Drop quoted literals and bracketed sections (colors, locales).
	var sb strings.Builder
	inQuote, inBracket := false, false
	for _, r := range code {
		switch {
		case r == '"':
			inQuote = !inQuote
		case r == '[' && !inQuote:
			inBracket = true
		case r == ']' && !inQuote:
			inBracket = false
		case !inQuote && !inBracket:
			sb.WriteRune(r)
		}
	}
	c := strings.ToLower(sb.String())
	return strings.ContainsAny(c, "dy") && !strings.Contains(c, "0.0")
}
