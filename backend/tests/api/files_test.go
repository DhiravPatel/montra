package api_test

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"image"
	"image/color"
	"image/png"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"

	"montra/backend/internal/testutil/apitest"
)

func pngBytes(t *testing.T) []byte {
	img := image.NewRGBA(image.Rect(0, 0, 4, 3))
	img.Set(1, 1, color.RGBA{R: 200, A: 255})
	var b bytes.Buffer
	if err := png.Encode(&b, img); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

// putContent uploads bytes to the intent's URL using the client's auth.
func putContent(t *testing.T, c *apitest.Client, intent map[string]any, body []byte, extra ...string) *apitest.Response {
	t.Helper()
	u, _ := url.Parse(intent["upload_url"].(string))
	path := strings.TrimPrefix(u.Path, "/api/v1")
	hdrs := intent["headers"].(map[string]any)
	req, _ := http.NewRequest(http.MethodPut, c.S.URL+"/api/v1"+path, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("X-Upload-Token", hdrs["X-Upload-Token"].(string))
	req.Header.Set("X-Montra-Client", c.Kind)
	req.Header.Set("X-Forwarded-For", c.IP)
	req.Header.Set("Authorization", "Bearer "+c.Bearer)
	for i := 0; i+1 < len(extra); i += 2 {
		req.Header.Set(extra[i], extra[i+1])
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, _ := io.ReadAll(resp.Body)
	r := &apitest.Response{Status: resp.StatusCode, Raw: raw}
	_ = jsonUnmarshal(raw, &r.Body)
	return r
}

func intentFor(t *testing.T, c *apitest.Client, purpose, name string, body []byte) map[string]any {
	sum := sha256.Sum256(body)
	return c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": purpose, "filename": name,
		"content_type": "image/png", "size_bytes": len(body), "checksum_sha256": hex.EncodeToString(sum[:])}).Expect(t, http.StatusCreated).Data()
}

func TestFileUploadAccessAndDeletion(t *testing.T) {
	s := apitest.New(t, nil)
	owner, _ := s.Login(t, s.Register(t, "fileowner"))
	other, _ := s.Login(t, s.Register(t, "fileother"))
	content := pngBytes(t)

	intent := intentFor(t, owner, "receipt", "../../etc/receipt.png", content)
	file := intent["file"].(map[string]any)
	id := file["id"].(string)
	if file["original_filename"] != "receipt.png" {
		t.Fatalf("filename not sanitized: %v", file["original_filename"])
	}
	if file["status"] != "pending_upload" {
		t.Fatalf("status = %v", file["status"])
	}
	// Another user cannot upload into this intent even with the token.
	putContent(t, other, intent, content).Expect(t, http.StatusNotFound)

	up := putContent(t, owner, intent, content).Expect(t, http.StatusOK).Data()
	if up["content_type"] != "image/png" || up["image_width"] != float64(4) {
		t.Fatalf("content not validated/sniffed: %v", up)
	}
	putContent(t, owner, intent, content).Expect(t, http.StatusGone) // single-use token
	owner.Do(t, http.MethodPost, "/files/"+id+"/complete", nil).Expect(t, http.StatusOK)
	owner.Do(t, http.MethodPost, "/files/"+id+"/complete", nil).Expect(t, http.StatusOK) // idempotent

	other.Do(t, http.MethodGet, "/files/"+id, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodGet, "/files/"+id+"/access", nil).Expect(t, http.StatusNotFound)

	acc := owner.Do(t, http.MethodGet, "/files/"+id+"/access", nil).Expect(t, http.StatusOK).Data()
	signed := acc["url"].(string)
	resp, err := http.Get(strings.Replace(signed, s.Cfg.HTTP.PublicBaseURL, s.URL, 1))
	if err != nil {
		t.Fatal(err)
	}
	got, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusOK || !bytes.Equal(got, content) || resp.Header.Get("X-Content-Type-Options") != "nosniff" {
		t.Fatalf("download failed: %d %q", resp.StatusCode, resp.Header)
	}
	// Tampered signature or swapped subject is rejected.
	tampered := strings.Replace(signed, "sig=", "sig=AAAA", 1)
	resp, _ = http.Get(strings.Replace(tampered, s.Cfg.HTTP.PublicBaseURL, s.URL, 1))
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusGone {
		t.Fatalf("tampered URL status %d", resp.StatusCode)
	}

	owner.Do(t, http.MethodDelete, "/files/"+id, nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	owner.Do(t, http.MethodGet, "/files/"+id, nil).Expect(t, http.StatusNotFound)
	resp, _ = http.Get(strings.Replace(signed, s.Cfg.HTTP.PublicBaseURL, s.URL, 1))
	_ = resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		t.Fatal("deleted file still downloadable")
	}
}

func TestFileUploadRejectsSpoofedContentAndBadChecksum(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "spoof"))
	fake := []byte("<script>alert(1)</script> pretending to be a png")
	intent := intentFor(t, c, "receipt", "photo.png", fake)
	r := putContent(t, c, intent, fake)
	if r.Status != http.StatusUnprocessableEntity || r.ErrorCode() != "UNSUPPORTED_MEDIA_TYPE" {
		t.Fatalf("spoofed content accepted: %d %s", r.Status, r.Raw)
	}
	good := pngBytes(t)
	intent = intentFor(t, c, "receipt", "photo.png", good)
	corrupted := append(append([]byte{}, good...), 0x00)
	r = putContent(t, c, intent, corrupted)
	if r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("checksum mismatch accepted: %d %s", r.Status, r.Raw)
	}
	// Disallowed extension for purpose.
	bad := c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": "avatar", "filename": "doc.pdf",
		"content_type": "application/pdf", "size_bytes": 100})
	if bad.Status != http.StatusUnsupportedMediaType {
		t.Fatalf("pdf avatar accepted: %d %s", bad.Status, bad.Raw)
	}
	// Oversized declaration.
	big := c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": "avatar", "filename": "a.png",
		"content_type": "image/png", "size_bytes": 50 << 20})
	if big.Status != http.StatusRequestEntityTooLarge {
		t.Fatalf("oversized intent accepted: %d", big.Status)
	}
}
