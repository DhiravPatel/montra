package api_test

import (
	"net/http"
	"strings"
	"testing"

	"montra/backend/internal/testutil/apitest"
)

// Fair-use limits are the same for everyone and shown transparently; the
// storage allowance counts uploads in flight and refuses uploads beyond it
// with a coded reason (spec §0.2, §17).
func TestFairUseLimitsAndStorageAllowance(t *testing.T) {
	s := apitest.New(t, map[string]string{"STORAGE_USER_QUOTA_BYTES": "4000"})
	c, _ := s.Login(t, s.Register(t, "fairuse"))

	l := c.Do(t, http.MethodGet, "/limits", nil).Expect(t, http.StatusOK).Data()
	if l["storage_quota_bytes"].(float64) != 4000 || l["storage_used_bytes"].(float64) != 0 || l["ai_requests_per_day"].(float64) != 0 ||
		l["import_max_rows"].(float64) != 20000 || len(l["rate_limits"].([]any)) == 0 {
		t.Fatalf("limits: %v", l)
	}

	uploadFile(t, c, "receipt", "a.png", "image/png", pngBytes(t))
	used := c.Do(t, http.MethodGet, "/limits", nil).Expect(t, http.StatusOK).Data()["storage_used_bytes"].(float64)
	if used <= 0 {
		t.Fatalf("usage not counted: %v", used)
	}
	// An intent in flight counts at its declared size.
	c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": "receipt", "filename": "b.png", "content_type": "image/png",
		"size_bytes": 1000}).Expect(t, http.StatusCreated)
	r := c.Do(t, http.MethodPost, "/files/upload-intent", map[string]any{"purpose": "receipt", "filename": "c.png", "content_type": "image/png",
		"size_bytes": int(4000 - used)})
	if r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("quota not enforced: %d %s", r.Status, r.Raw)
	}
	det := r.Body["error"].(map[string]any)["details"].([]any)[0].(map[string]any)
	if det["code"] != "storage_quota_exceeded" || det["params"].(map[string]any)["quota_bytes"] != "4000" {
		t.Fatalf("quota detail: %v", det)
	}
}

// The operator dashboard is admin-only and returns aggregate counts only.
func TestAdminUsageDashboard(t *testing.T) {
	s := apitest.New(t, nil)
	user := newPerson(t, s, "member", nil)
	support := newPerson(t, s, "supporter", nil)
	admin := newPerson(t, s, "operator", nil)
	s.Env.ExecWorker(t, `update users set platform_role = 'support' where id = $1`, support.id)
	s.Env.ExecWorker(t, `update users set platform_role = 'admin' where id = $1`, admin.id)
	acct := createAccount(t, user.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR"})["id"].(string)
	createTx(t, user.c, map[string]any{"type": "expense", "account_id": acct, "amount": "10.00"})

	user.c.Do(t, http.MethodGet, "/admin/usage", nil).Expect(t, http.StatusForbidden)
	support.c.Do(t, http.MethodGet, "/admin/usage", nil).Expect(t, http.StatusForbidden)
	u := admin.c.Do(t, http.MethodGet, "/admin/usage?days=7", nil).Expect(t, http.StatusOK).Data()
	users := u["users"].(map[string]any)
	if u["window_days"].(float64) != 7 || users["active"].(float64) < 3 || users["new"].(float64) < 3 || u["transactions_created"].(float64) < 1 {
		t.Fatalf("usage: %v", u)
	}
	if daily := u["daily"].([]any); len(daily) < 7 || len(daily) > 8 {
		t.Fatalf("daily series: %d", len(daily))
	}
	// No identifiers or personal values leak into the payload.
	raw := string(admin.c.Do(t, http.MethodGet, "/admin/usage", nil).Raw)
	for _, leak := range []string{user.id, acct, "@example.com"} {
		if strings.Contains(raw, leak) {
			t.Fatalf("usage payload contains %s", leak)
		}
	}
}
