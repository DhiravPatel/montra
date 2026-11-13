package api_test

import (
	"bytes"
	"net/http"
	"net/url"
	"testing"
	"time"

	"montra/backend/internal/testutil/apitest"
)

// Coverage for file upload and download through the API client, group and
// trip attachments (STOR-010) and access revocation after a member leaves
// or is removed from a group (STOR-006).

// cvSignedQuery issues a download link for a file and returns its query.
func cvSignedQuery(t *testing.T, c *apitest.Client, id string) string {
	t.Helper()
	acc := c.Do(t, http.MethodGet, "/files/"+id+"/access", nil).Expect(t, http.StatusOK).Data()
	u, err := url.Parse(acc["url"].(string))
	if err != nil || u.Path != "/api/v1/files/"+id+"/content" || u.Query().Get("sig") == "" || u.Query().Get("exp") == "" {
		t.Fatalf("access url = %v", acc["url"])
	}
	return u.RawQuery
}

// cvGroupIntent creates an upload intent for a group file.
func cvGroupIntent(t *testing.T, c *apitest.Client, purpose, gid, name string, body []byte) *apitest.Response {
	t.Helper()
	return c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": purpose, "filename": name, "content_type": "image/png",
		"size_bytes": len(body), "group_id": gid})
}

func TestCoverageFileUploadContentAndSignedDownload(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvupload"))
	other, _ := s.Login(t, s.Register(t, "cvuploadsnoop"))
	anon := s.NewClient("web")
	img := pngBytes(t)

	intent := intentFor(t, c, "transaction_attachment", "scan.png", img)
	id := intent["file"].(map[string]any)["id"].(string)
	tok := intent["headers"].(map[string]any)["X-Upload-Token"].(string)
	bogus := map[string]any{"not": "an image"}
	// The upload token is required and must match; others cannot upload.
	if r := c.Do(t, http.MethodPut, "/files/"+id+"/content", bogus); r.Status != http.StatusUnprocessableEntity || r.ErrorCode() != "VALIDATION_ERROR" ||
		detail(t, r)["field"] != "header.X-Upload-Token" {
		t.Fatalf("upload without a token: %d %s", r.Status, r.Raw)
	}
	if r := c.Do(t, http.MethodPut, "/files/"+id+"/content", bogus, "X-Upload-Token", "not-the-token"); r.Status != http.StatusGone || r.ErrorCode() != "GONE" {
		t.Fatalf("upload with a wrong token: %d %s", r.Status, r.Raw)
	}
	other.Do(t, http.MethodPut, "/files/"+id+"/content", bogus, "X-Upload-Token", tok).Expect(t, http.StatusNotFound)
	anon.Do(t, http.MethodPut, "/files/"+id+"/content", bogus, "X-Upload-Token", tok).Expect(t, http.StatusUnauthorized)
	// Nobody else can complete my upload (AUTHZ-014): 404, and it stays pending.
	other.Do(t, http.MethodPost, "/files/"+id+"/complete", nil).Expect(t, http.StatusNotFound)
	anon.Do(t, http.MethodPost, "/files/"+id+"/complete", nil).Expect(t, http.StatusUnauthorized)
	// Completing before content is a conflict; the file stays pending.
	if r := c.Do(t, http.MethodPost, "/files/"+id+"/complete", nil); r.Status != http.StatusConflict {
		t.Fatalf("complete before upload: %d %s", r.Status, r.Raw)
	}
	if f := c.Do(t, http.MethodGet, "/files/"+id, nil).Expect(t, http.StatusOK).Data(); f["status"] != "pending_upload" {
		t.Fatalf("file after failed attempts = %v", f)
	}
	// Content that is not what the intent declared is rejected and the
	// token is spent: the file is marked rejected with a reason.
	if r := c.Do(t, http.MethodPut, "/files/"+id+"/content", bogus, "X-Upload-Token", tok); r.Status != http.StatusUnprocessableEntity ||
		r.ErrorCode() != "UNSUPPORTED_MEDIA_TYPE" {
		t.Fatalf("JSON uploaded as an image: %d %s", r.Status, r.Raw)
	}
	if f := c.Do(t, http.MethodGet, "/files/"+id, nil).Expect(t, http.StatusOK).Data(); f["status"] != "rejected" || f["rejection_reason"] == nil {
		t.Fatalf("rejected file = %v", f)
	}
	putContent(t, c, intent, img).Expect(t, http.StatusGone)

	// A good upload: validated, sniffed, completed (audited), downloadable
	// through a signed link without a session, with safe headers.
	intent = intentFor(t, c, "transaction_attachment", "scan.png", img)
	id = intent["file"].(map[string]any)["id"].(string)
	up := putContent(t, c, intent, img).Expect(t, http.StatusOK).Data()
	if up["status"] != "uploaded" || up["size_bytes"] != float64(len(img)) || up["image_height"] != float64(3) || up["checksum_sha256"] == nil {
		t.Fatalf("uploaded = %v", up)
	}
	c.Do(t, http.MethodPost, "/files/"+id+"/complete", nil).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'file' and entity_id = $1 and action = 'uploaded'`, id); n != 1 {
		t.Fatalf("upload audit rows = %d", n)
	}
	q := cvSignedQuery(t, c, id)
	dl := anon.Do(t, http.MethodGet, "/files/"+id+"/content?"+q, nil).Expect(t, http.StatusOK)
	if !bytes.Equal(dl.Raw, img) || dl.Headers.Get("Content-Type") != "image/png" || dl.Headers.Get("X-Content-Type-Options") != "nosniff" ||
		dl.Headers.Get("Content-Security-Policy") == "" || dl.Headers.Get("Content-Disposition") != `inline; filename=scan.png` {
		t.Fatalf("download: %d %v", dl.Status, dl.Headers)
	}
	// The link is bound to its file, signature and expiry.
	other2 := intentFor(t, c, "transaction_attachment", "b.png", img)["file"].(map[string]any)["id"].(string)
	if r := anon.Do(t, http.MethodGet, "/files/"+other2+"/content?"+q, nil); r.Status != http.StatusGone || r.ErrorCode() != "GONE" {
		t.Fatalf("link reused for another file: %d %s", r.Status, r.Raw)
	}
	if r := anon.Do(t, http.MethodGet, "/files/"+id+"/content", nil); r.Status != http.StatusGone {
		t.Fatalf("download without a signature: %d %s", r.Status, r.Raw)
	}
	vals, _ := url.ParseQuery(q)
	vals.Set("sub", other2)
	if r := anon.Do(t, http.MethodGet, "/files/"+id+"/content?"+vals.Encode(), nil); r.Status != http.StatusGone {
		t.Fatalf("download with a swapped subject: %d %s", r.Status, r.Raw)
	}
	s.Svcs.Files.Now = func() time.Time { return time.Now().Add(s.Cfg.Storage.SignedURLTTL + time.Minute) }
	r := anon.Do(t, http.MethodGet, "/files/"+id+"/content?"+q, nil)
	s.Svcs.Files.Now = nil
	if r.Status != http.StatusGone || r.ErrorCode() != "GONE" {
		t.Fatalf("expired link: %d %s", r.Status, r.Raw)
	}
}

func TestCoverageGroupAndTripAttachmentsForMembersOnly(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "cvgfowner", nil)
	b := newPerson(t, s, "cvgfmember", nil)
	out := newPerson(t, s, "cvgfoutsider", nil)
	img := pngBytes(t)
	g := createGroup(t, o.c, map[string]any{"name": "Ladakh", "group_type": "trip", "base_currency": "INR", "timezone": "UTC",
		"start_date": "2026-12-01", "end_date": "2026-12-10", "destination": "Leh"})
	gid := g["id"].(string)
	joinByLink(t, o, b, gid)

	// Group purposes need a group the uploader belongs to; personal purposes
	// cannot name a group.
	gfField(t, out.c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": "group_attachment", "filename": "a.png",
		"content_type": "image/png", "size_bytes": len(img)}), "body.group_id")
	gfField(t, o.c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": "receipt", "filename": "a.png",
		"content_type": "image/png", "size_bytes": len(img), "group_id": gid}), "body.group_id")
	cvGroupIntent(t, out.c, "group_attachment", gid, "a.png", img).Expect(t, http.StatusNotFound)
	cvGroupIntent(t, out.c, "trip_document", gid, "a.png", img).Expect(t, http.StatusNotFound)

	// Members upload a group attachment and a trip document.
	ga := cvGroupIntent(t, o.c, "group_attachment", gid, "bill.png", img).Expect(t, http.StatusCreated).Data()
	gaID := ga["file"].(map[string]any)["id"].(string)
	if ga["file"].(map[string]any)["group_id"] != gid {
		t.Fatalf("group intent = %v", ga)
	}
	// Only the uploader can send the content, even to another member.
	b.c.Do(t, http.MethodPut, "/files/"+gaID+"/content", map[string]any{"x": 1}, "X-Upload-Token", ga["headers"].(map[string]any)["X-Upload-Token"].(string)).Expect(t, http.StatusNotFound)
	putContent(t, o.c, ga, img).Expect(t, http.StatusOK)
	o.c.Do(t, http.MethodPost, "/files/"+gaID+"/complete", nil).Expect(t, http.StatusOK)
	td := cvGroupIntent(t, b.c, "trip_document", gid, "boarding-pass.png", img).Expect(t, http.StatusCreated).Data()
	tdID := td["file"].(map[string]any)["id"].(string)
	putContent(t, b.c, td, img).Expect(t, http.StatusOK)
	b.c.Do(t, http.MethodPost, "/files/"+tdID+"/complete", nil).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'file' and group_id = $1 and action = 'uploaded'`, gid); n != 2 {
		t.Fatalf("group upload audit rows = %d", n)
	}

	// Every member reads both, by metadata and by signed link.
	for _, p := range []person{o, b} {
		for _, id := range []string{gaID, tdID} {
			f := p.c.Do(t, http.MethodGet, "/files/"+id, nil).Expect(t, http.StatusOK).Data()
			if f["group_id"] != gid || f["status"] != "ready" {
				t.Fatalf("member file view = %v", f)
			}
			dl := p.c.Do(t, http.MethodGet, "/files/"+id+"/content?"+cvSignedQuery(t, p.c, id), nil).Expect(t, http.StatusOK)
			if !bytes.Equal(dl.Raw, img) {
				t.Fatal("member download content differs")
			}
		}
	}
	// Only the uploader may delete a group file: other members, who can
	// see it, are refused.
	if r := b.c.Do(t, http.MethodDelete, "/files/"+gaID, nil); r.Status != http.StatusForbidden || r.ErrorCode() != "FORBIDDEN" {
		t.Fatalf("member deleting another member's group file: %d %s", r.Status, r.Raw)
	}
	// The attachment can be used as a group expense receipt by any member.
	e := gfExpense(t, b, gid, map[string]any{"description": "Taxi", "amount": "1200", "split_method": "equal", "participants": gfPeople(o, b), "receipt_file_id": gaID})
	if e["receipt_file_id"] != gaID {
		t.Fatalf("expense receipt = %v", e["receipt_file_id"])
	}

	// Outsiders see nothing: metadata, access, download with a member's
	// link re-signed for themselves, and expense receipts from other groups.
	for _, id := range []string{gaID, tdID} {
		out.c.Do(t, http.MethodGet, "/files/"+id, nil).Expect(t, http.StatusNotFound)
		out.c.Do(t, http.MethodGet, "/files/"+id+"/access", nil).Expect(t, http.StatusNotFound)
		out.c.Do(t, http.MethodDelete, "/files/"+id, nil).Expect(t, http.StatusNotFound)
	}
	og := createGroup(t, out.c, map[string]any{"name": "Elsewhere", "group_type": "household", "base_currency": "INR"})
	gfField(t, out.c.Do(t, http.MethodPost, "/groups/"+og["id"].(string)+"/expenses", map[string]any{"description": "x", "amount": "10", "split_method": "equal", "participants": gfPeople(out),
		"receipt_file_id": gaID}, "Idempotency-Key", key()), "body.receipt_file_id")
}

func TestCoverageGroupFileAccessRevokedOnRemoval(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "cvrvowner", nil)
	b := newPerson(t, s, "cvrvremoved", nil)
	l := newPerson(t, s, "cvrvleaver", nil)
	img := pngBytes(t)
	gid := createGroup(t, o.c, map[string]any{"name": "Flat 4B", "group_type": "household", "base_currency": "INR"})["id"].(string)
	joinByLink(t, o, b, gid)
	joinByLink(t, o, l, gid)
	upload := func(p person, purpose, name string) string {
		in := cvGroupIntent(t, p.c, purpose, gid, name, img).Expect(t, http.StatusCreated).Data()
		putContent(t, p.c, in, img).Expect(t, http.StatusOK)
		id := in["file"].(map[string]any)["id"].(string)
		p.c.Do(t, http.MethodPost, "/files/"+id+"/complete", nil).Expect(t, http.StatusOK)
		return id
	}
	ownerFile := upload(o, "group_attachment", "lease.png")
	removedOwn := upload(b, "group_attachment", "b-receipt.png")

	// Before removal b reads the owner's file and holds a still-valid link.
	b.c.Do(t, http.MethodGet, "/files/"+ownerFile, nil).Expect(t, http.StatusOK)
	bLink := cvSignedQuery(t, b.c, ownerFile)
	lLink := cvSignedQuery(t, l.c, ownerFile)
	anon := s.NewClient("web")
	anon.Do(t, http.MethodGet, "/files/"+ownerFile+"/content?"+bLink, nil).Expect(t, http.StatusOK)

	// Removal (admin) and leaving (self) both revoke access at once:
	// metadata, new links and links issued before, which are re-checked
	// against the subject's current membership on every download.
	o.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+b.id, nil).Expect(t, http.StatusOK)
	l.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+l.id, nil).Expect(t, http.StatusOK)
	for _, p := range []person{b, l} {
		p.c.Do(t, http.MethodGet, "/files/"+ownerFile, nil).Expect(t, http.StatusNotFound)
		p.c.Do(t, http.MethodGet, "/files/"+ownerFile+"/access", nil).Expect(t, http.StatusNotFound)
	}
	for _, q := range []string{bLink, lLink} {
		if r := anon.Do(t, http.MethodGet, "/files/"+ownerFile+"/content?"+q, nil); r.Status != http.StatusNotFound || bytes.Equal(r.Raw, img) {
			t.Fatalf("pre-removal signed link still downloads: %d", r.Status)
		}
	}
	// Remaining members keep access to everything, including the file the
	// removed member uploaded.
	o.c.Do(t, http.MethodGet, "/files/"+removedOwn+"/content?"+cvSignedQuery(t, o.c, removedOwn), nil).Expect(t, http.StatusOK)
	// Files a removed member uploaded stay theirs (owner access), so they
	// can still read and delete their own upload.
	if f := b.c.Do(t, http.MethodGet, "/files/"+removedOwn, nil).Expect(t, http.StatusOK).Data(); f["group_id"] != gid {
		t.Fatalf("removed member's own upload = %v", f)
	}
	// Re-joining restores access (membership is checked live, not cached).
	joinByLink(t, o, b, gid)
	b.c.Do(t, http.MethodGet, "/files/"+ownerFile+"/content?"+cvSignedQuery(t, b.c, ownerFile), nil).Expect(t, http.StatusOK)
	// The pre-removal link works again only because it has not expired yet
	// and b is a member again: it carries no membership snapshot.
	anon.Do(t, http.MethodGet, "/files/"+ownerFile+"/content?"+bLink, nil).Expect(t, http.StatusOK)
	// Nor can a removed member create group uploads.
	cvGroupIntent(t, l.c, "group_attachment", gid, "late.png", img).Expect(t, http.StatusNotFound)
}
