package api_test

import (
	"net/http"
	"testing"

	"github.com/google/uuid"

	"montra/backend/internal/testutil/apitest"
)

// GET /legal publishes the consent versions POST /me/consents checks;
// exports can be listed (with status and expiry) and their notification
// deep-links to the export; the deletion disclosure and the fair-use note
// carry codes beside their English text.
func TestLegalConsentVersionsExportsListDeletionCodesAndLimitsNote(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "privacycodes")
	c, _ := s.Login(t, addr)
	uid := userID(t, s, addr)

	legal := s.NewClient("web").Do(t, http.MethodGet, "/legal", nil).Expect(t, http.StatusOK).Data()
	byType := map[string]map[string]any{}
	for _, x := range legal["consents"].([]any) {
		m := x.(map[string]any)
		byType[m["type"].(string)] = m
	}
	if len(byType) != 9 || byType["terms"]["required"] != true || byType["terms"]["version"] != legal["terms_version"] ||
		byType["privacy_policy"]["version"] != legal["privacy_version"] || byType["ai_processing"]["required"] != false || byType["push_notifications"] == nil {
		t.Fatalf("legal consents: %v", legal)
	}
	version := byType["ai_processing"]["version"].(string)
	if r := c.Do(t, http.MethodPost, "/me/consents", map[string]any{"consent_type": "ai_processing", "version": "1999-01-01"}); r.Status != http.StatusUnprocessableEntity ||
		detail(t, r)["code"] != "consent_version_outdated" || detail(t, r)["field"] != "body.version" || detail(t, r)["params"].(map[string]any)["version"] != version {
		t.Fatalf("outdated consent version: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/me/consents", map[string]any{"consent_type": "ai_processing", "version": version}).Expect(t, http.StatusCreated)

	// Exports: listed newest first with status and expiry; the ready
	// notification opens that export.
	if l := c.Do(t, http.MethodGet, "/me/exports", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("exports before any request: %v", l)
	}
	ageReauth(s, t)
	c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password}).Expect(t, http.StatusOK)
	id := c.Do(t, http.MethodPost, "/me/export", nil).Expect(t, http.StatusAccepted).Data()["id"].(string)
	s.RunJobs(t)
	list := c.Do(t, http.MethodGet, "/me/exports", nil).Expect(t, http.StatusOK).List()
	if len(list) != 1 || list[0].(map[string]any)["id"] != id || list[0].(map[string]any)["status"] != "completed" ||
		list[0].(map[string]any)["expires_at"] == nil || list[0].(map[string]any)["file_id"] == nil {
		t.Fatalf("exports: %v", list)
	}
	var link string
	for _, n := range c.Do(t, http.MethodGet, "/notifications?category=export", nil).Expect(t, http.StatusOK).List() {
		if m := n.(map[string]any); m["event_type"] == "data_export_ready" {
			link, _ = m["deep_link"].(string)
		}
	}
	if link != "/settings/privacy?export="+id {
		t.Fatalf("export deep link: %q", link)
	}
	s.Env.ExecWorker(t, `update data_exports set expires_at = now() - interval '1 minute' where id = $1`, id)
	if st := c.Do(t, http.MethodGet, "/me/exports", nil).Expect(t, http.StatusOK).List()[0].(map[string]any)["status"]; st != "expired" {
		t.Fatalf("expired export listed as %v", st)
	}
	if st := c.Do(t, http.MethodGet, "/me/export/"+id, nil).Expect(t, http.StatusOK).Data()["status"]; st != "expired" {
		t.Fatalf("expired export read as %v", st)
	}
	if l := s.NewClient("android").Do(t, http.MethodGet, "/me/exports", nil); l.Status != http.StatusUnauthorized {
		t.Fatalf("anonymous exports list: %d", l.Status)
	}

	// Deletion disclosure: codes beside the text, group impact with params.
	friend := userID(t, s, s.Register(t, "flatmate"))
	shared, solo := uuid.New(), uuid.New()
	s.Env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Flat','roommates','INR','Asia/Kolkata'),
		($3,$2,'Solo trip','trip','INR','Asia/Kolkata')`, shared, uid, solo)
	s.Env.ExecWorker(t, `insert into group_members (group_id, user_id, role, joined_at) values ($1,$2,'owner', now() - interval '2 days'),
		($1,$3,'member', now() - interval '1 day'), ($4,$2,'owner', now())`, shared, uid, friend, solo)
	d := c.Do(t, http.MethodGet, "/me/deletion-request", nil).Expect(t, http.StatusOK).Data()
	if len(d["consequence_codes"].([]any)) != len(d["consequences"].([]any)) || len(d["consequence_codes"].([]any)) != 5 ||
		len(d["retained_codes"].([]any)) != len(d["retained"].([]any)) || d["retained_codes"].([]any)[0] != "shared_group_records_anonymized" {
		t.Fatalf("deletion codes: %v", d)
	}
	items := d["group_impact_details"].([]any)
	if len(items) != 2 || len(d["group_impact"].([]any)) != 2 {
		t.Fatalf("group impact: %v", d)
	}
	byGroup := map[string]map[string]any{}
	for _, x := range items {
		m := x.(map[string]any)
		byGroup[m["params"].(map[string]any)["group_name"].(string)] = m
	}
	flat, trip := byGroup["Flat"], byGroup["Solo trip"]
	if flat["code"] != "ownership_transfer" || flat["params"].(map[string]any)["group_id"] != shared.String() ||
		flat["params"].(map[string]any)["outcome"] != "ownership_transfer" || flat["text"] == "" ||
		trip["code"] != "group_deleted" || trip["params"].(map[string]any)["outcome"] != "deleted" || trip["params"].(map[string]any)["group_id"] != solo.String() {
		t.Fatalf("group impact details: %v", items)
	}
	if d["group_impact"].([]any)[0] != items[0].(map[string]any)["text"] {
		t.Fatalf("group_impact text order differs from details: %v", d)
	}

	// Fair-use note code.
	l := c.Do(t, http.MethodGet, "/limits", nil).Expect(t, http.StatusOK).Data()
	if l["note_code"] != "fair_use_same_for_everyone" || l["note"] == "" || l["support_requests_per_day"] != float64(10) {
		t.Fatalf("limits note: %v", l)
	}
}
