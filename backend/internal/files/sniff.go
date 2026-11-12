package files

import (
	"archive/zip"
	"bytes"
	"image"
	_ "image/jpeg" // register decoders for DecodeConfig
	_ "image/png"
	"io"
	"os"
	"strings"
	"unicode/utf8"

	_ "golang.org/x/image/webp"
)

// Kind is a validated content type.
type Kind struct {
	MIME string
	Ext  string
}

// Known kinds.
var (
	KindJPEG = Kind{"image/jpeg", "jpg"}
	KindPNG  = Kind{"image/png", "png"}
	KindWEBP = Kind{"image/webp", "webp"}
	KindHEIC = Kind{"image/heic", "heic"}
	KindPDF  = Kind{"application/pdf", "pdf"}
	KindCSV  = Kind{"text/csv", "csv"}
	KindXLSX = Kind{"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx"}
	KindOFX  = Kind{"application/x-ofx", "ofx"}
	KindJSON = Kind{"application/json", "json"}
	KindZIP  = Kind{"application/zip", "zip"}
)

// Limits protect parsers from resource exhaustion.
const (
	maxImagePixels = 50_000_000
	maxImageSide   = 12_000
	maxZipEntries  = 2_000
	maxZipRatio    = 100 // uncompressed/compressed
)

// Detected describes sniffed content.
type Detected struct {
	Kind      Kind
	Width     int
	Height    int
	Encrypted bool
	Problem   string // non-empty → reject with this safe reason
}

// Sniff detects the real type from file content (client MIME types and
// extensions are untrusted, spec §20B.10).
func Sniff(path string, size int64) (Detected, error) {
	f, err := os.Open(path) //nolint:gosec // server-created temp file
	if err != nil {
		return Detected{}, err
	}
	defer func() { _ = f.Close() }()
	head := make([]byte, 512)
	n, _ := io.ReadFull(f, head)
	head = head[:n]
	switch {
	case bytes.HasPrefix(head, []byte{0xFF, 0xD8, 0xFF}):
		return imageInfo(f, KindJPEG)
	case bytes.HasPrefix(head, []byte{0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A}):
		return imageInfo(f, KindPNG)
	case len(head) >= 12 && string(head[0:4]) == "RIFF" && string(head[8:12]) == "WEBP":
		return imageInfo(f, KindWEBP)
	case len(head) >= 12 && string(head[4:8]) == "ftyp" && isHEIFBrand(string(head[8:12])):
		return Detected{Kind: KindHEIC}, nil // dimensions not decodable in pure Go; size limit applies
	case bytes.HasPrefix(head, []byte("%PDF-")):
		return pdfInfo(f, size)
	case bytes.HasPrefix(head, []byte("PK\x03\x04")):
		return zipInfo(path, size)
	}
	text := strings.TrimLeft(string(head), "\ufeff \t\r\n")
	if bytes.IndexByte(head, 0) >= 0 && !isUTF16(head) {
		return Detected{Problem: "unsupported binary file"}, nil
	}
	if isUTF16(head) {
		return Detected{Kind: KindCSV}, nil // UTF-16 text exports (decoded by the import parser)
	}
	upper := strings.ToUpper(text)
	if strings.HasPrefix(upper, "OFXHEADER") || strings.Contains(upper, "<OFX>") {
		return Detected{Kind: KindOFX}, nil
	}
	if strings.HasPrefix(text, "{") || strings.HasPrefix(text, "[") {
		return Detected{Kind: KindJSON}, nil
	}
	if utf8.Valid(head) || looksLikeLatin1Text(head) {
		return Detected{Kind: KindCSV}, nil
	}
	return Detected{Problem: "unsupported file type"}, nil
}

func isHEIFBrand(b string) bool {
	switch b {
	case "heic", "heix", "hevc", "hevx", "mif1", "msf1", "heim", "heis":
		return true
	}
	return false
}

func isUTF16(h []byte) bool {
	return len(h) >= 2 && ((h[0] == 0xFF && h[1] == 0xFE) || (h[0] == 0xFE && h[1] == 0xFF))
}

func looksLikeLatin1Text(h []byte) bool {
	for _, c := range h {
		if c < 0x09 || (c > 0x0D && c < 0x20) {
			return false
		}
	}
	return true
}

func imageInfo(f *os.File, k Kind) (Detected, error) {
	if _, err := f.Seek(0, io.SeekStart); err != nil {
		return Detected{}, err
	}
	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		return Detected{Problem: "the image could not be read"}, nil
	}
	d := Detected{Kind: k, Width: cfg.Width, Height: cfg.Height}
	if cfg.Width <= 0 || cfg.Height <= 0 || cfg.Width > maxImageSide || cfg.Height > maxImageSide ||
		int64(cfg.Width)*int64(cfg.Height) > maxImagePixels {
		d.Problem = "the image dimensions are too large"
	}
	return d, nil
}

func pdfInfo(f *os.File, size int64) (Detected, error) {
	// Scan the tail for the trailer (encryption dictionary) and EOF marker.
	tail := int64(4096)
	if size < tail {
		tail = size
	}
	buf := make([]byte, tail)
	if _, err := f.ReadAt(buf, size-tail); err != nil && err != io.EOF {
		return Detected{}, err
	}
	d := Detected{Kind: KindPDF}
	if !bytes.Contains(buf, []byte("%%EOF")) {
		d.Problem = "the PDF appears to be incomplete"
	}
	if bytes.Contains(buf, []byte("/Encrypt")) {
		d.Encrypted = true
		d.Problem = "password-protected PDFs are not supported; export an unprotected copy"
	}
	return d, nil
}

func zipInfo(path string, size int64) (Detected, error) {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return Detected{Problem: "the archive could not be read"}, nil
	}
	defer func() { _ = zr.Close() }()
	if len(zr.File) > maxZipEntries {
		return Detected{Problem: "the file contains too many parts"}, nil
	}
	var total uint64
	hasContentTypes, hasWorkbook, hasMacros := false, false, false
	for _, f := range zr.File {
		total += f.UncompressedSize64
		switch {
		case f.Name == "[Content_Types].xml":
			hasContentTypes = true
		case strings.HasPrefix(f.Name, "xl/workbook"):
			hasWorkbook = true
		case strings.HasSuffix(strings.ToLower(f.Name), "vbaproject.bin"):
			hasMacros = true
		}
	}
	if size > 0 && total/uint64(size) > maxZipRatio {
		return Detected{Problem: "the file expands to an unsafe size"}, nil
	}
	if hasMacros {
		return Detected{Problem: "spreadsheets with macros are not accepted"}, nil
	}
	if hasContentTypes && hasWorkbook {
		return Detected{Kind: KindXLSX}, nil
	}
	return Detected{Kind: KindZIP}, nil
}

// SafeFilename returns a display-only filename (never used for paths).
func SafeFilename(name string) string {
	name = strings.ReplaceAll(name, "\\", "/")
	if i := strings.LastIndex(name, "/"); i >= 0 {
		name = name[i+1:]
	}
	var b strings.Builder
	for _, r := range name {
		if r < 0x20 || r == 0x7f || strings.ContainsRune(`<>:"|?*`, r) {
			continue
		}
		b.WriteRune(r)
	}
	out := strings.TrimSpace(b.String())
	out = strings.TrimLeft(out, ".")
	if len(out) > 200 {
		out = out[len(out)-200:]
	}
	if out == "" {
		out = "file"
	}
	return out
}
